// ignore_for_file: curly_braces_in_flow_control_structures, constant_identifier_names
import 'dart:convert';

import 'package:eye_phone/ext/StrExt.dart';
import 'package:eye_phone/repo/app_repo.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../util/util.dart';

class MonCubit extends Cubit<MonState> implements Observer {
  static const _TAG = 'MonCubit';
  final String peerId;
  final AppRepo repo;
  RTCPeerConnection? _pc;
  RTCSessionDescription? _offer;
  MediaStream? remoteAudioStream;
  MediaStream? localAudioStream;
  RTCDataChannel? _dch;
  var _sendingScale = false;

  bool get isLocal => repo.getStringFromSp(CAM_ID) == peerId;

  MonCubit({required this.peerId, required this.repo}) : super(const MonState()) {
    if (!isLocal) repo.register(this);
    appLog(_TAG, 'init');
  }

  _onTrack(MediaStream stream) async {
    appLog(_TAG, 'on track');
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = stream;
    emit(state.copyWith(renderer: renderer, monStatus: MonStatus.live));
  }

  @override
  onData(Map<String, dynamic> map) async {
    appLog(_TAG, 'on data:$map');
    final type = map[TYPE] as String;
    // start of broadcast section
    if (type == IS_SIGNED_IN)
      emit(state.copyWith());
    else if (type == CONNECTED)
      repo.send({TYPE: GET_CAM_STATUS, PEER_ID: peerId});
    else if (type == ENABLE || type == DISABLE) {
      appLog(_TAG, 'notify enable disable');
      _enableVideo(type == ENABLE);
      _enableAudio(type == ENABLE);
    }
    //end of broadcast section
    if (map[PEER_ID] != peerId || type == GET_CAM_STATUS) return;
    switch (type) {
      case DISCONNECTED || TURNED_OFF || OFFLINE:
        emit(state.copyWith(monStatus: type.toMonStatus()));
        break;
      case LIVE:
        localAudioStream ??= await mediaDevices.getUserMedia({'audio': true, 'video': false})
          ..getAudioTracks().forEach((t) => t.enabled = false);
        _sendOffer();
        break;
      case ANSWER:
        _pc
          ?..setLocalDescription(_offer!)
          ..setRemoteDescription(RTCSessionDescription(Uri.decodeComponent(map[DESC]), ANSWER));
        break;
      case ICE:
        final ice = map[ICE];
        _pc?.addCandidate(RTCIceCandidate(ice['candidate'], ice['sdpMid'], ice['sdpMLineIndex']));
    }
  }

  void _sendOffer() => createPC(true).then(_onPeerConnection);

  _initDataChanel(RTCPeerConnection pc) => pc.createDataChannel('ui', RTCDataChannelInit()).then((dch) => _dch = dch
    ..onMessage = (msg) {
      appLog(_TAG, 'on msg:${msg.text}');
      final map = jsonDecode(msg.text);
      final type = map[TYPE] as String;
      switch (type) {
        case TORCH:
          appLog(_TAG, 'on torch');
          emit(state.copyWith(torchOn: map[VALUE]));
          break;
        case BRIGHTNESS:
          emit(state.copyWith(screenOn: map[VALUE]));
          break;
        case OFFLINE || TURNED_OFF:
          _enableVideo(false);
          _enableAudio(false);
          emit(state.copyWith(monStatus: type.toMonStatus()));
          if (state.monStatus == MonStatus.turned_off) _dispose();
          break;
        case LIVE:
          _enableVideo(true);
          _enableAudio(state.soundOn);
          emit(state.copyWith(monStatus: MonStatus.live));
      }
    }
    ..onDataChannelState = (s) {
      appLog(_TAG, 'data channel state:$s');
      if (s == RTCDataChannelState.RTCDataChannelOpen) dch.send(RTCDataChannelMessage(jsonEncode({TYPE: BRIGHTNESS})));
    });

  void _enableVideo(bool enable) =>
      state.renderer?.srcObject?.getVideoTracks().forEach((element) => element.enabled = enable);

  _onPeerConnection(RTCPeerConnection pc) async {
    _initDataChanel(pc);
    localAudioStream?.getAudioTracks().forEach((t) => pc.addTrack(t, localAudioStream!));
    _pc = pc;
    _offer = await pc.createOffer();
    repo.send({TYPE: OFFER, PEER_ID: peerId, DESC: Uri.encodeComponent(_offer!.sdp!)});
    pc
      ..onIceCandidate = (ice) {
        repo.send({TYPE: ICE, ICE: ice.toMap(), PEER_ID: peerId});
      }
      ..onTrack = (t) {
        appLog(_TAG, 'on track, kind:${t.track}');
        if (t.track.kind == VIDEO)
          _onTrack(t.streams.single);
        else if (t.track.kind == AUDIO) {
          remoteAudioStream = t.streams.single;
          _enableAudio(false);
        }
      };
  }

  void getState(String camId) => repo.send({TYPE: GET_CAM_STATUS, PEER_ID: camId});

  void _enableAudio(bool v) => remoteAudioStream?.getAudioTracks().forEach((t) => t.enabled = v);

  void toggleMic() {
    localAudioStream?.getAudioTracks().forEach((t) => t.enabled = !state.micOn);
    emit(state.copyWith(micOn: !state.micOn));
  }

  void toggleSound() {
    _enableAudio(!state.soundOn);
    emit(state.copyWith(soundOn: !state.soundOn));
  }

  void switchCamera() => _dch?.send(RTCDataChannelMessage(jsonEncode({TYPE: SWITCH_CAM})));

  void reqBrightness() => _dch?.send(RTCDataChannelMessage(jsonEncode({TYPE: BRIGHTNESS})));

  toggleScreen() => _dch
      ?.send(RTCDataChannelMessage(jsonEncode({TYPE: BRIGHTNESS, VALUE: !state.screenOn})))
      .whenComplete(() => emit(state.copyWith(screenOn: !state.screenOn)));

  sendScale(double scale) {
    if (!_sendingScale) {
      _sendingScale = true;
      _dch
          ?.send(RTCDataChannelMessage(jsonEncode({TYPE: SCALE, VALUE: scale})))
          .whenComplete(() => _sendingScale = false);
    }
  }

  toggleTorch() => _dch
      ?.send(RTCDataChannelMessage(jsonEncode({TYPE: TORCH})))
      .whenComplete(() => emit(state.copyWith(torchOn: !state.torchOn!)));

  void toggleSiren() => _dch
      ?.send(RTCDataChannelMessage(jsonEncode({TYPE: SIREN})))
      .whenComplete(() => emit(state.copyWith(sirenOn: !state.sirenOn)));

  void turnOnOff() => state.monStatus == MonStatus.turned_off || state.monStatus == MonStatus.offline
      ? repo.send({TYPE: TURN_ON_OFF, PEER_ID: peerId})
      : _dch?.send(RTCDataChannelMessage(jsonEncode({TYPE: TURN_ON_OFF})));

  void _dispose() {
    state.renderer?.srcObject?.dispose();
    state.renderer?.dispose();
    _pc?.dispose();
    _dch?.close();
    _pc = null;
    _dch = null;
  }
}

class MonState {
  final MonStatus monStatus;
  final RTCVideoRenderer? renderer;
  final bool soundOn;
  final bool screenOn;
  final bool? torchOn;
  final bool micOn;
  final bool sirenOn;

  const MonState(
      {this.monStatus = MonStatus.loading,
      this.renderer,
      this.soundOn = false,
      this.screenOn = true,
      this.torchOn,
      this.micOn = false,
      this.sirenOn = false});

  MonState copyWith(
          {RTCVideoRenderer? renderer,
          MonStatus? monStatus,
          bool? soundOn,
          bool? screenOn,
          bool? torchOn,
          bool? micOn,
          bool? sirenOn}) =>
      MonState(
          monStatus: monStatus ?? this.monStatus,
          renderer: renderer ?? this.renderer,
          soundOn: soundOn ?? this.soundOn,
          screenOn: screenOn ?? this.screenOn,
          torchOn: torchOn ?? this.torchOn,
          micOn: micOn ?? this.micOn,
          sirenOn: sirenOn ?? this.sirenOn);
}

enum MonStatus { loading, live, offline, turned_off, disconnected, server_down }
