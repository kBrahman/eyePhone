// ignore_for_file: avoid_print, constant_identifier_names, curly_braces_in_flow_control_structures
import 'dart:math';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../widget/subs_widget.dart';
import 'git_ignored_config.dart';

const amber = Color(0xFFECB805);
const IS_SIGNED_IN = 'is_signed_in';
const USER = 'user';
const _TAG = 'util';
const CAM_ID = 'cam_id';
const PATH_CAM = 'cam';
const QR_VISIBLE = 'qr_visible';
const CAM_ON = 'cam_on';
const TYPE = 'type';
const IS_BROADCAST = 'isBroadcast';
const DESC = 'desc';
const ICE = 'ice';
const PEERS = 'peers';
const OFFER = 'offer';
const GET_CAM_STATUS = 'get_cam_status';
const CAM_STATUS = 'cam_status';
const LIVE = 'live';
const CONNECTED = 'connected';
const ANSWER = 'answer';
const PEER_ID = 'peerId';
const OFFLINE = 'offline';
const VIDEO = 'video';
const AUDIO = 'audio';
const ENABLE = 'enable';
const DISABLE = 'disable';
const OFFLINE_BROADCAST = 'offline_broadcast';
const ONLINE_BROADCAST = 'online_broadcast';
const TURNED_OFF = 'turned_off';
const TURN_ON_OFF = 'turn_on_off';
const IS_PREMIUM = 'is_premium';
const DISCONNECTED = "disconnected";
const PRODUCT = 'product';
const SWITCH_CAM = 'switch_cam';
const BRIGHTNESS = 'brightness';
const SIREN = 'siren';
const TORCH = 'torch';
const VALUE = 'value';
const SCALE = 'scale';

appLog(tag, msg) => print('$tag:$msg');

String generateRandomString(int len) => String.fromCharCodes(List.generate(len, (index) {
      final random = Random();
      var i = random.nextInt(33);
      while (i == 3 || i == 6 || i == 4) i = random.nextInt(33);
      return i + 89;
    }));

Future<RTCPeerConnection> createPC(bool needVideo) async {
  final turnServers = TURNS.map((e) => 'turn:$e:3478');
  appLog(_TAG, 'turnUname:$TURN_USER, turnPass:$TURN_PASS, turnServers:$turnServers');
  return await createPeerConnection({
    'iceServers': [
      {'url': 'stun:stun1.l.google.com:19302'},
      {'url': 'stun:stun.ekiga.net'},
      ...turnServers.map((e) => {'url': e, 'credential': TURN_PASS, 'username': TURN_USER})
    ],
    'sdpSemantics': 'unified-plan'
  }, {
    'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': needVideo},
    'optional': []
  });
}

Future<String> get name => DeviceInfoPlugin().deviceInfo.then((m) => m is IosDeviceInfo
    ? m.model
    : m is AndroidDeviceInfo
        ? m.model
        : throw 'unimpl');

String getURL() => IP == 'eye-phone.top' ? 'wss://$IP/ws' : 'ws://$IP/ws';

String getName(String peerId) => peerId.substring(peerId.indexOf('_') + 1);
