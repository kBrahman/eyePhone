// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'package:eye_phone/bloc/app/app_bloc.dart';
import 'package:eye_phone/bloc/app/git_ignored_config.dart';
import 'package:eye_phone/util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../bloc/app/app_event.dart';

class CamWidget extends StatelessWidget {
  static const _TAG = 'CamWidget';
  final AppData _data;
  final AppBloc _bloc;

  const CamWidget(this._data, this._bloc, {super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQueryData = MediaQuery.of(context);
    final orientation = mediaQueryData.orientation;
    final windowHeight = mediaQueryData.size.height;
    appLog(_TAG, 'window height:$windowHeight');
    _bloc.ctr.add(const StopTimer(false));
    return Scaffold(
        appBar: _hideBarInCamWidget(orientation, windowHeight)
            ? null
            : AppBar(title: const Text('Camera', style: TextStyle(color: Colors.deepPurple)), actions: [
                Text(
                    _data.live
                        ? _getTime(_data.liveSpan)
                        : _data.state == CamState.off
                            ? 'turned off'
                            : 'offline',
                    style: TextStyle(color: _data.live ? Colors.red : Colors.grey)),
                IconButton(
                    onPressed: () => _bloc.ctr.add(const QrVisible(true)),
                    icon: const Icon(Icons.share, color: Colors.deepPurple))
              ]),
        body: _getBody(context, _data));
  }

  _hideBarInCamWidget(Orientation orientation, double windowHeight) =>
      orientation == Orientation.landscape && windowHeight < 393;

  _getBody(context, AppData data) {
    final state = data.state;
    appLog(_TAG, 'cam state:$state');
    if (data.animate)
      WidgetsBinding.instance.addPostFrameCallback((_) => DefaultTabController.of(context).animateTo(0));
    switch (state) {
      case CamState.generating:
        return const Center(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [CircularProgressIndicator(), Text('Initializing the camera')]));
      case CamState.permission_restricted:
        return const Center(
            child: Text('It seems like someone restricted your access to the camera. You can not use your camera'));
      case CamState.permanently_denied:
        return Center(
            child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Column(children: [
                  const Text(
                      'You have permanently denied camera permission request. Now you must open settings and grant camera access'),
                  TextButton(
                      onPressed: () =>
                          openAppSettings().then((res) => res ? DefaultTabController.of(context).animateTo(0) : null),
                      child: const Text('Open app settings'))
                ])));
      case CamState.cam:
        return Stack(alignment: AlignmentDirectional.center, children: [
          RTCVideoView(_data.renderer!, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
          if (data.qrVisible)
            Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.white),
                width: 200,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                      padding: const EdgeInsets.only(left: 9, right: 9),
                      child: Row(children: [
                        const Expanded(child: Text("Scan this QR code with your 'monitor' phone")),
                        IconButton(
                            onPressed: () => _bloc.ctr.add(const QrVisible(false)),
                            icon: const Icon(Icons.close_outlined))
                      ])),
                  QrImageView(data: data.qr!, version: QrVersions.auto, backgroundColor: Colors.white),
                  Padding(
                      padding: const EdgeInsets.only(left: 9, right: 9),
                      child: Row(children: [
                        const Expanded(child: Text("Or, share the link with your 'monitor' phone")),
                        IconButton(
                            onPressed: () =>
                                Share.share('https://eye-phone.top/?$CAM_ID=${data.qr}', subject: 'Camera link'),
                            icon: const Icon(Icons.share))
                      ]))
                ])),
          Positioned(
              bottom: 8,
              child: GestureDetector(
                  child: CircleAvatar(backgroundColor: _data.live ? Colors.red : null),
                  onTap: () => _bloc.ctr.add(const GoLive()))),
          Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                  onTap: () => _bloc.ctr.add(const Turn(on: false)),
                  child: Container(
                      margin: const EdgeInsets.all(1),
                      color: const Color(0xFFF6F1FC),
                      child: const Icon(Icons.close, color: Colors.deepPurple))))
        ]);
      case CamState.denied:
        return ConstrainedBox(
            constraints: const BoxConstraints.expand(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('You must grant permission to use your camera in order to use this device as a camera')),
              ElevatedButton(onPressed: () => _bloc.ctr.add(RequestPermission()), child: const Text('Grant permission'))
            ]));
      case CamState.off:
        return Center(
            child: ElevatedButton(onPressed: () => _bloc.ctr.add(const Turn(on: true)), child: const Text('Turn on')));
    }
  }

  String _getTime(int i) {
    dynamic h = i ~/ 3600;
    if (h < 10) h = '0$h';
    dynamic m = (i % 3600) ~/ 60;
    if (m < 10) m = '0$m';
    dynamic s = (i % 3600) % 60;
    if (s < 10) s = '0$s';
    return '$h:$m:$s';
  }
}
