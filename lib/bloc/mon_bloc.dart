// ignore_for_file: curly_braces_in_flow_control_structures, constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eye_phone/util.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MonBloc {
  static const _TAG = 'MonBloc';
  final bool isLocal;
  RTCVideoRenderer? renderer;
  final String? id;
  bool openNow;
  final ctr = StreamController<MonEvent>.broadcast();
  MonData? data;
  WebSocket? _ws;
  RTCPeerConnection? pc;
  var connecting = false;

  MonBloc({required this.isLocal, this.renderer, this.id, this.openNow = false});

  Stream<MonData> getStream() async* {
    appLog(_TAG, 'get stream');
    final sp = await SharedPreferences.getInstance();
    data ??= MonData(
        state: isLocal ? MonState.offline : MonState.loading,
        name: isLocal ? "This device" : sp.getString('${id!}_$NAME') ?? '');
    yield data!;
    if (!isLocal && !connecting && _ws == null) _getRemoteStream(id!, sp).whenComplete(() => connecting = false);
    connecting = true;
    await for (final e in ctr.stream)
      switch (e) {
        case SetMonState(state: final s):
          appLog(_TAG, 'set mon state:$s');
          yield data = data!.copyWith(state: s);
          break;
        case SetMonName(name: final n):
          appLog(_TAG, 'set name:$n, hc:$hashCode');
          data = data?.copyWith(name: n);
          sp.setString('${id!}_$NAME', n);
      }
  }

  Future<void> _getRemoteStream(String peerId, SharedPreferences sp) async {
    appLog(_TAG, 'get remote stream');
    String? camId;
    if ((camId = sp.getString(CAM_ID)) == null) {
      try {
        final doc = await FirebaseFirestore.instance.collection(PATH_CAM).doc().get();
        camId = doc.id;
        appLog(_TAG, 'cam id from cloud:$camId');
      } catch (e) {
        appLog(_TAG, 'e:$e');
      }
      camId ??= generateRandomString(20);
      sp.setString(CAM_ID, camId);
    }
    try {
      pc = await createPC(true)
        ..onIceCandidate = (ice) {
          appLog(_TAG, 'ws:$_ws,ice:${ice.candidate}');
          _ws?.add(jsonEncode({TYPE: ICE, ICE: ice.toMap(), ID: peerId}));
        }
        ..onTrack = (t) {
          if (t.track.kind == 'video') {
            appLog(_TAG, 'got video Track');
            renderer = RTCVideoRenderer();
            renderer?.initialize().whenComplete(() {
              renderer?.srcObject = t.streams.single;
              ctr.add(const SetMonState(MonState.live));
            });
            final peers = sp.getStringList(PEERS);
            if (peers == null)
              sp.setStringList(PEERS, [peerId]);
            else if (!peers.contains(peerId)) sp.setStringList(PEERS, peers..add(peerId));
          }
        }
        ..onConnectionState = (state) {
          if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
            appLog(_TAG, 'connected');
          } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
            pc?.restartIce();
            appLog(_TAG, 'restarted ice');
          }
        };
      final offer = await pc!.createOffer();
      navigator.mediaDevices.getUserMedia({'audio': true, 'video': false}).then(
          (localStream) => localStream.getTracks().forEach((track) => pc?.addTrack(track, localStream)));
      await for (final e in (_ws = await WebSocket.connect(getURL(),
          headers: {CAM_ID: camId, ID: peerId, DESC: Uri.encodeComponent(offer.sdp!), NAME: await name}))) {
        appLog(_TAG, 'event:$e');
        final map = jsonDecode(e);
        final type = map[TYPE];
        switch (type) {
          case ANSWER:
            appLog(_TAG, 'answer hc:$hashCode');
            final desc = Uri.decodeComponent(map[DESC]);
            pc?.setLocalDescription(offer);
            pc?.setRemoteDescription(RTCSessionDescription(desc, type));
            ctr.add(SetMonName(map[NAME]));
            break;
          case ICE:
            final ice = map[ICE];
            pc?.addCandidate(RTCIceCandidate(ice['candidate'], ice['sdpMid'], ice['sdpMLineIndex']));
            break;
          case OFFLINE_BROADCAST:
            ctr.add(const SetMonState(MonState.offline));
            break;
          case ONLINE_BROADCAST:
            if (pc?.connectionState == null)
              _ws?.add(jsonEncode({TYPE: OFFER, ID: peerId, DESC: Uri.encodeComponent(offer.sdp!)}));
            else
              ctr.add(const SetMonState(MonState.live));
            break;
          case TURNED_OFF_BROADCAST:
            ctr.add(const SetMonState(MonState.turned_off));
            break;
          case DISCONNECTED_BROADCAST:
            ctr.add(const SetMonState(MonState.disconnected));
        }
      }
      if (_ws?.closeCode == CAMERA_OFFLINE) ctr.add(const SetMonState(MonState.offline));
    } on SocketException catch (e) {
      appLog(_TAG, 'exc:$e');
      ctr.add(const SetMonState(MonState.server_down));
    }
  }
}

class MonData {
  final MonState state;
  final String name;

  const MonData({this.state = MonState.loading, this.name = ''});

  MonData copyWith({MonState? state, String? name}) => MonData(state: state ?? this.state, name: name ?? this.name);

  @override
  String toString() {
    return 'MonData{state: $state, name: $name}';
  }
}

enum MonState { loading, live, offline, turned_off, disconnected, server_down }

sealed class MonEvent {
  const MonEvent();
}

class SetMonState extends MonEvent {
  final MonState state;

  const SetMonState(this.state);
}

class SetMonName extends MonEvent {
  final String name;

  const SetMonName(this.name);
}
