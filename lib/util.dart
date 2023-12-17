// ignore_for_file: avoid_print, constant_identifier_names
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'bloc/app/git_ignored_config.dart';

const _TAG = 'util';
const CAM_ID = 'cam_id';
const PATH_CAM = 'cam';
const QR_VISIBLE = 'qr_visible';
const CAM_ON = 'cam_on';
const TYPE = 'type';
const DESC = 'desc';
const ICE = 'ice';
const PEERS = 'peers';
const NAME = 'name';
const OFFER = 'offer';
const ANSWER = 'answer';
const ID = 'id';
const OFFLINE = 'offline';
const OFFLINE_BROADCAST = 'offline_broadcast';
const ONLINE_BROADCAST = 'online_broadcast';
const TURNED_OFF_BROADCAST = 'turned_off_broadcast';
const DISCONNECTED_BROADCAST = "disconnected_broadcast";
const MULTI_STREAM = 'multi_stream';

const CAMERA_OFFLINE = 3000;

const closeColor = Color(0xFFECDEFD);

appLog(tag, msg) => print('$tag:$msg');

String generateRandomString(int len) => String.fromCharCodes(List.generate(len, (index) => Random().nextInt(33) + 89));

Future<RTCPeerConnection> createPC(needVideo) async {
  final turnServers = TURNS.map((e) => 'turn:$e:3478');
  appLog(_TAG, 'turnUname:$TURN_USER, turnPass:$TURN_PASS, turnServers:$turnServers');
  return await createPeerConnection({
    'iceServers': [
      {'url': 'stun:stun1.l.google.com:19302'},
      {'url': 'stun:stun.ekiga.net'},
      // ...turnServers.map((e) => {'url': e, 'credential': TURN_PASS, 'username': TURN_USER})
    ],
    'sdpSemantics': 'unified-plan'
  }, {
    'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': needVideo},
    'optional': []
  });
}

Future<String> get name async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  return Platform.isAndroid
      ? (await deviceInfo.androidInfo).model
      : Platform.isIOS
          ? (await deviceInfo.iosInfo).model
          : throw 'unimpl';
}
