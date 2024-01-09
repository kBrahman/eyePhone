// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eye_phone/manager/deep_link_manager.dart';
import 'package:eye_phone/util.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mon_bloc.dart';
import 'app_event.dart';
import 'git_ignored_config.dart';

class AppBloc {
  static const _TAG = 'AppBloc';
  final ctr = StreamController<AppEvent>();
  WebSocket? _ws;
  final pcs = <String, RTCPeerConnection>{};

  AppBloc(DeepLinkManager manager) {
    manager.init(ctr);
    appLog(_TAG, 'init');
  }

  Stream<AppData> getStream(int w, int h) async* {
    try {
      appLog(_TAG, 'w:$w, h:$h');
      final sp = await SharedPreferences.getInstance();
      var (data, needAudio) = (
        AppData(
            state: _fromPerm(await Permission.camera.status),
            mons: (sp.getStringList(PEERS) ?? []).map((id) => MonBloc(isLocal: false, id: id)).toList()),
        await Permission.microphone.isGranted
      );
      yield data;
      if (!(sp.getBool(CAM_ON) ?? true))
        yield data = data.copyWith(state: CamState.off);
      else if (data.state == CamState.generating) yield data = await _initQrAndVideo(needAudio, w, h, sp, data);

      StreamSubscription? subscription;
      var stopTimer = false;
      await for (final cmd in ctr.stream) {
        switch (cmd) {
          case QrVisible(value: final v):
            appLog(_TAG, 'qr visible:$v');
            yield data = data.copyWith(qrVisible: v);
            sp.setBool(QR_VISIBLE, v);
            break;
          case GoLive():
            yield data = data.copyWith(live: !data.live);
            if (data.live) {
              stopTimer = false;
              subscription = Stream.periodic(const Duration(seconds: 1), (i) => ctr.add(Tick(i))).listen(null);
              data.mons.first.ctr.add(const SetMonState(MonState.live));
              _registerOnCloud(sp, data);
            } else {
              subscription?.cancel();
              yield data = data.copyWith(liveSpan: 0);
              data.mons.first.ctr.add(const SetMonState(MonState.offline));
              _sendWSMSg({TYPE: OFFLINE_BROADCAST});
            }
            break;
          case Tick(sec: final s):
            if (!stopTimer) yield data = data.copyWith(liveSpan: s);
            break;
          case RequestPermission():
            (data, needAudio) = await _requestPermissions();
            yield data;
            if (data.state == CamState.generating)
              yield data = await _initQrAndVideo(needAudio, w, h, sp, data);
            else
              yield data;
            break;
          case Turn(on: final v):
            if (v)
              yield data = await _initQrAndVideo(needAudio, w, h, sp, data, true);
            else {
              appLog(_TAG, 'turned off, mons:${data.mons}');
              data.renderer?.srcObject = null;
              if (data.mons.isNotEmpty) {
                final locBloc = data.mons.first;
                if (locBloc.isLocal) locBloc.ctr.add(const SetMonState(MonState.turned_off));
              }
              data.renderer?.dispose();
              subscription?.cancel();
              yield data = data.copyWith(state: CamState.off, liveSpan: 0, live: false);
            }
            sp.setBool(CAM_ON, v);
            _sendWSMSg({TYPE: v ? OFFLINE_BROADCAST : TURNED_OFF_BROADCAST});
            break;
          case ShowCam():
            yield data = data.copyWith(state: CamState.cam);
            data.mons.first.ctr.add(const SetMonState(MonState.offline));
            break;
          case AddCam(id: final id, andOpen: final v):
            appLog(_TAG, 'add cam id:$id');
            yield data..mons.add(MonBloc(isLocal: false, id: id, openNow: v));
            break;
          case DeleteMon(index: final i):
            appLog(_TAG, 'del mon at $i');
            yield data..mons.removeAt(i);
            appLog(_TAG, 'removed mon at $i');
            sp.setStringList(PEERS, data.mons.map((m) => m.id).whereType<String>().toList(growable: false));
            break;
          case StopTimer(stop: final v):
            stopTimer = v;
        }
      }
    } catch (e) {
      appLog(_TAG, 'exc:$e');
    }
  }

  Future<AppData> _initQrAndVideo(bool needAudio, int w, int h, SharedPreferences sp, AppData data,
      [blackScreenIssue = false]) async {
    final localRenderer = RTCVideoRenderer();
    await localRenderer.initialize();
    localRenderer.srcObject = await _initStream(needAudio, w, h);
    appLog(_TAG, 'get stream');
    var camId = sp.getString(CAM_ID);
    appLog(_TAG, 'cam id from sp:$camId');
    if (camId == null) {
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
      FirebaseFirestore.instance.doc('$PATH_CAM/$camId').set({'ts': Timestamp.now()});
    } catch (e) {
      appLog(_TAG, 'exc:$e');
    }
    if (blackScreenIssue)
      localRenderer.onFirstFrameRendered = () {
        appLog(_TAG, 'on first frame');
        ctr.add(ShowCam());
      };
    return data.copyWith(
        state: blackScreenIssue ? CamState.generating : CamState.cam,
        qr: camId,
        renderer: localRenderer,
        mons: _getMons(data, localRenderer),
        qrVisible: sp.getBool(QR_VISIBLE));
  }

  List<MonBloc> _getMons(AppData data, RTCVideoRenderer localRenderer) {
    if (data.mons.isEmpty || !data.mons.first.isLocal)
      return [MonBloc(isLocal: true, renderer: localRenderer), ...data.mons];
    return data.mons..first.renderer = localRenderer;
  }

  Future<MediaStream> _initStream(bool needAudio, w, h) {
    final devices = navigator.mediaDevices;
    return devices.getUserMedia({
      'audio': needAudio,
      'video': {
        'facingMode': 'environment',
        'mandatory': {'minWidth': w, 'minHeight': h, 'minFrameRate': '30'}
      }
    });
  }

  Future<(AppData, bool)> _requestPermissions() async {
    final resMap = await [Permission.camera, Permission.microphone].request();
    final statusCam = resMap[Permission.camera]!;
    final statusMic = resMap[Permission.microphone]!;
    appLog(_TAG, 'status cam:$statusCam');
    return (AppData(state: _fromPerm(statusCam)), statusMic.isGranted);
  }

  CamState _fromPerm(PermissionStatus status) {
    if (status.isGranted) return CamState.generating;
    if (status.isDenied) return CamState.denied;
    if (status.isPermanentlyDenied) return CamState.permanently_denied;
    return CamState.permission_restricted;
  }

  Future<void> _registerOnCloud(SharedPreferences sp, AppData data) async {
    final camId = sp.getString(CAM_ID);
    appLog(_TAG, 'connecting ws');
    if (_ws != null)
      _sendWSMSg({TYPE: ONLINE_BROADCAST});
    else
      await for (final e in await WebSocket.connect(getURL(), headers: {CAM_ID: camId, NAME: await name}).then((ws) {
        _ws = ws;
        _sendWSMSg({TYPE: ONLINE_BROADCAST});
        return ws;
      })) {
        appLog(_TAG, 'event:$e');
        final map = jsonDecode(e);
        final type = map[TYPE];
        final peerId = map[ID];
        switch (type) {
          case OFFER:
            final desc = Uri.decodeComponent(map[DESC]);
            appLog(_TAG, "desc:$desc");
            if (pcs.isNotEmpty && !(sp.getBool(MULTI_STREAM) ?? false)) {
              _sendWSMSg({TYPE: OFFLINE, ID: peerId});
              break;
            }
            final pc = await createPC(false);
            pc
              ..onIceCandidate = (ice) {
                appLog(_TAG, 'on ice:$ice');
                _sendWSMSg({TYPE: ICE, ICE: ice.toMap(), ID: peerId});
              }
              ..onConnectionState = (state) => _onConnState(state, pc, peerId);

            data.renderer?.srcObject?.getTracks().forEach((track) => pc.addTrack(track, data.renderer!.srcObject!));
            pc.setRemoteDescription(RTCSessionDescription(desc, type));
            final answer = await pc.createAnswer();
            pc.setLocalDescription(answer);
            _sendWSMSg({TYPE: ANSWER, DESC: Uri.encodeComponent(answer.sdp!), ID: peerId});
            pcs[peerId] = pc;
            break;
          case ICE:
            final ice = map[ICE];
            pcs[peerId]?.addCandidate(RTCIceCandidate(ice['candidate'], ice['sdpMid'], ice['sdpMLineIndex']));
        }
      }
  }

  void _onConnState(RTCPeerConnectionState state, RTCPeerConnection pc, peerId) {
    if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected)
      appLog(_TAG, 'connected');
    else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
      pc.restartIce();
      appLog(_TAG, 'restarted ice');
    } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) pcs.remove(peerId);
  }

  void _sendWSMSg(msg) => _ws?.add(jsonEncode(msg));
}

class AppData {
  final CamState state;
  final bool animate;
  final String? qr;
  final RTCVideoRenderer? renderer;
  final List<MonBloc> mons;
  final bool qrVisible;
  final bool live;

  final int liveSpan;

  const AppData(
      {this.qrVisible = true,
      this.state = CamState.generating,
      this.animate = false,
      this.qr,
      this.renderer,
      this.mons = const [],
      this.live = false,
      this.liveSpan = 0});

  @override
  String toString() {
    return 'AppData{state: $state, animate: $animate, qr: $qr, renderer: $renderer, mons: $mons, qrVisible: $qrVisible, live: $live, liveSpan: $liveSpan}';
  }

  AppData copyWith(
          {String? qr,
          RTCVideoRenderer? renderer,
          List<MonBloc>? mons,
          bool? qrVisible,
          bool? live,
          int? liveSpan,
          CamState? state}) =>
      AppData(
          state: state ?? this.state,
          qr: qr ?? this.qr,
          renderer: renderer ?? this.renderer,
          mons: mons ?? this.mons,
          qrVisible: qrVisible ?? this.qrVisible,
          live: live ?? this.live,
          liveSpan: liveSpan ?? this.liveSpan);
}

enum CamState { generating, permission_restricted, permanently_denied, cam, denied, off }
