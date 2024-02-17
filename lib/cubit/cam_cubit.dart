// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:eye_phone/repo/app_repo.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../util/util.dart';
import 'mon_cubit.dart';

class CamCubit extends Cubit<CamState> implements Observer {
  static const _TAG = 'CamCubit';
  final AppRepo _repo;
  var time = 0;
  int? _w;
  int? _h;
  late final timeStream =
      Stream.periodic(const Duration(seconds: 1), (sec) => state.live ? time++ : 0).asBroadcastStream();
  RTCPeerConnection? _pc;
  RTCDataChannel? _dataChannel;
  var zooming = false;
  var currScale = 1.0;
  var zoom = 1.0;
  final player = AudioPlayer()
    ..setSourceAsset('siren.wav')
    ..setReleaseMode(ReleaseMode.loop)
    ..setVolume(1);

  CamCubit(this._repo) : super(const CamState()) {
    _repo.register(this);
  }

  Future<void> init(int w, int h) async {
    if (_w != null) return;
    appLog(_TAG, 'init');
    _w = w;
    _h = h;
    emit(state.copyWith(
        camStatus: _repo.getBoolFromSp(CAM_ON) ?? true ? _fromPerm(await Permission.camera.status) : CamStatus.off));
    if (state.camStatus == CamStatus.generating) emit(await _initQrAndVideo(w, h, true));
  }

  CamStatus _fromPerm(PermissionStatus status) {
    if (status.isGranted) return CamStatus.generating;
    if (status.isDenied) return CamStatus.denied;
    if (status.isPermanentlyDenied) return CamStatus.permanently_denied;
    return CamStatus.permission_restricted;
  }

  setQrVisible(bool visible) {
    emit(state.copyWith(qrVisible: visible));
    _repo.saveBoolToSp(QR_VISIBLE, visible);
  }

  void goLive() async {
    time = 0;
    emit(state.copyWith(live: !state.live));
    if (_pc == null || _dataChannel == null) {
      appLog(_TAG, 'sending with ws: _pc is null:${_pc == null}, data chanel is null:${_dataChannel == null}');
      _repo.send({TYPE: state.live ? LIVE : OFFLINE, IS_BROADCAST: true});
    } else {
      appLog(_TAG, 'sending with data chanel');
      _dataChannel?.send(
          RTCDataChannelMessage(jsonEncode({TYPE: state.live ? LIVE : OFFLINE, PEER_ID: await _repo.getCamId()})));
    }
    appLog(_TAG, 'goLive');
  }

  Future<void> turn({required bool on}) async {
    if (!on) {
      _dataChannel?.send(RTCDataChannelMessage(jsonEncode({TYPE: TURNED_OFF})));
      state.renderer?.srcObject?.dispose();
      state.renderer?.dispose();
      _dataChannel?.close();
      _pc?.dispose();
      _pc = null;
      _dataChannel = null;
    }
    emit(on
        ? await _initQrAndVideo(_w!, _h!, true)
        : state.copyWith(camStatus: CamStatus.off, live: false, renderer: null));
    _repo.saveBoolToSp(CAM_ON, on);
    appLog(_TAG, 'turned on:$on');
  }

  void requestPermissions() async {
    final resMap = await [Permission.camera, Permission.microphone].request();
    final statusCam = resMap[Permission.camera]!;
    final statusMic = resMap[Permission.microphone]!;
    emit(state.copyWith(camStatus: _fromPerm(statusCam)));
    if (state.camStatus == CamStatus.generating) emit(await _initQrAndVideo(_w!, _h!));
  }

  Future<MediaStream> _getStream(w, h) => navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'environment',
          'mandatory': {'minWidth': w, 'minHeight': h, 'minFrameRate': '30'}
        }
      });

  Future<CamState> _initQrAndVideo(int w, int h, [blackScreenIssue = false]) async {
    appLog(_TAG, 'initQrAndVideo');
    final localRenderer = RTCVideoRenderer();
    await localRenderer.initialize();
    localRenderer.srcObject = await _getStream(w, h);
    final camId = await _repo.getCamId();
    if (blackScreenIssue)
      localRenderer.onFirstFrameRendered = () {
        localRenderer.srcObject?.getVideoTracks().forEach((_hasTorch));
        emit(state.copyWith(camStatus: CamStatus.cam));
        _repo.send({TYPE: state.live ? LIVE : OFFLINE, IS_BROADCAST: true});
      };
    return state.copyWith(
        camStatus: blackScreenIssue ? CamStatus.generating : CamStatus.cam,
        qr: camId,
        renderer: localRenderer,
        qrVisible: _repo.getBoolFromSp(QR_VISIBLE));
  }

  @override
  onData(Map<String, dynamic> map) {
    appLog(_TAG, 'on data:$map');
    final type = map[TYPE];
    final peerId = map[PEER_ID];
    switch (type) {
      case IS_SIGNED_IN:
        emit(state.copyWith());
        break;
      case TURN_ON_OFF:
        if (state.camStatus == CamStatus.off)
          turn(on: true).whenComplete(() => emit(state.copyWith(live: true)));
        else
          goLive();
        break;
      case GET_CAM_STATUS:
        _repo.send({TYPE: _stringify(state.camStatus), PEER_ID: peerId});
        break;
      case OFFER:
        _answer(Uri.decodeComponent(map[DESC]), peerId);
        break;
      case ICE:
        if (!_repo.getStringListFromSp(PEERS).contains(peerId)) {
          final ice = map[ICE];
          _pc?.addCandidate(RTCIceCandidate(ice['candidate'], ice['sdpMid'], ice['sdpMLineIndex']));
          appLog(_TAG, 'add ice o cam cubit');
        }
    }
  }

  void _answer(String desc, String peerId) => createPC(false).then((pc) => _onPeerConnection(pc, desc, peerId));

  _onPeerConnection(RTCPeerConnection pc, String desc, String peerId) async {
    _pc = pc;
    final mediaStream = state.renderer?.srcObject;
    mediaStream?.getTracks().forEach((t) => _pc?.addTrack(t, mediaStream));
    await pc.setRemoteDescription(RTCSessionDescription(desc, OFFER));
    final answer = await pc.createAnswer();
    _repo.send({TYPE: ANSWER, PEER_ID: peerId, DESC: Uri.encodeComponent(answer.sdp!)});
    pc
      ..setLocalDescription(answer)
      ..onTrack = (t) {
        appLog(_TAG, 'on track:${t.track.kind}');
      }
      ..onIceCandidate = (ice) {
        _repo.send({TYPE: ICE, ICE: ice.toMap(), PEER_ID: peerId});
      }
      ..onConnectionState = (state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          _pc?.close();
          _pc = null;
        }
      }
      ..onDataChannel = (ch) => _dataChannel = ch
        ..onMessage = (msg) async {
          final map = jsonDecode(msg.text);
          appLog(_TAG, 'on msg:$map');
          return switch (map[TYPE]) {
            TURN_ON_OFF => turn(on: false),
            SIREN => toggleSiren(),
            TORCH => toggleTorch(),
            SWITCH_CAM => Helper.switchCamera(state.renderer!.srcObject!.getVideoTracks().single),
            BRIGHTNESS => map[VALUE] == null
                ? ScreenBrightness().current.then((v) {
                    appLog(_TAG, 'send brightness:$v');
                    sendTypeAndValue(BRIGHTNESS, v > 0);
                    if (state.isTorchOn != null) {
                      appLog(_TAG, 'sending torch');
                      sendTypeAndValue(TORCH, state.isTorchOn!);
                    }
                  })
                : ScreenBrightness()
                    .setScreenBrightness(map[VALUE] == true ? await ScreenBrightness().system : 0)
                    .whenComplete(() => emit(state.copyWith(screenOn: map[VALUE] == true))),
            SCALE => onScaleUpdate(map[VALUE]),
            _ => throw 'unimpl'
          };
        };
  }

  String _stringify(CamStatus status) => status == CamStatus.cam ? (state.live ? LIVE : OFFLINE) : TURNED_OFF;

  void sendTypeAndValue(String type, bool value) =>
      _dataChannel?.send(RTCDataChannelMessage(jsonEncode({TYPE: type, VALUE: value})));

  void onScaleUpdate(double scale) {
    if (zooming) return;
    zooming = true;
    final sc = scale;
    final delta = sc - currScale;
    currScale = sc;
    Helper.setZoom(
            state.renderer!.srcObject!.getVideoTracks().single,
            zoom < 0
                ? zoom = 0
                : zoom += delta > 0
                    ? .05
                    : delta < 0
                        ? -.05
                        : 0)
        .whenComplete(() => zooming = false);
  }

  toggleTorch() => state.renderer?.srcObject
      ?.getVideoTracks()
      .first
      .setTorch(!state.isTorchOn!)
      .whenComplete(() => sendTypeAndValue(TORCH, !state.isTorchOn!))
      .whenComplete(() => emit(state.copyWith(isTorchOn: !state.isTorchOn!)));

  void _hasTorch(MediaStreamTrack track) => track.hasTorch().then((v) {
        appLog(_TAG, 'has torch');
        if (v) emit(state.copyWith(isTorchOn: false));
      });

  toggleScreenLight() {
    final screenBrightness = ScreenBrightness();
    screenBrightness.current.then((v) async {
      if (v == 0)
        screenBrightness.setScreenBrightness(await screenBrightness.system);
      else
        screenBrightness.setScreenBrightness(0);
      sendTypeAndValue(BRIGHTNESS, v == 0);
    });
  }

  toggleSiren() => player.state == PlayerState.playing ? player.stop() : player.resume();
}

class CamState {
  static const _TAG = 'CamState';
  final CamStatus camStatus;
  final bool live;
  final bool animate;
  final RTCVideoRenderer? renderer;
  final bool qrVisible;
  final String? qr;
  final bool? isTorchOn;

  final bool screenOn;

  const CamState(
      {this.camStatus = CamStatus.generating,
      this.live = false,
      this.animate = false,
      this.renderer,
      this.qrVisible = true,
      this.qr,
      this.isTorchOn,
      this.screenOn = true});

  CamState copyWith(
          {bool? qrVisible,
          CamStatus? camStatus,
          String? qr,
          RTCVideoRenderer? renderer,
          bool? live,
          bool? isTorchOn,
          bool? screenOn}) =>
      CamState(
          camStatus: camStatus ?? this.camStatus,
          live: live ?? this.live,
          animate: animate,
          renderer: renderer ?? this.renderer,
          qr: qr ?? this.qr,
          qrVisible: qrVisible ?? this.qrVisible,
          isTorchOn: isTorchOn ?? this.isTorchOn,
          screenOn: screenOn ?? this.screenOn);

  toLocMonState() => MonState(renderer: renderer, monStatus: _toMonStatus(camStatus));

  MonStatus _toMonStatus(CamStatus camStatus) {
    if (live) return MonStatus.live;
    if (camStatus == CamStatus.off) return MonStatus.turned_off;
    return MonStatus.offline;
  }
}

enum CamStatus { generating, permission_restricted, permanently_denied, cam, denied, off }
