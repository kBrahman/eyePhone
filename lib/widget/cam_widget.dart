// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'package:eye_phone/util/util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';

import '../cubit/cam_cubit.dart';
import '../cubit/main_cubit.dart';
import '../repo/app_repo.dart';

class CamWidget extends StatelessWidget {
  static const _TAG = 'CamWidget';

  const CamWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQueryData = MediaQuery.of(context);
    final orientation = mediaQueryData.orientation;
    final windowHeight = mediaQueryData.size.height;
    appLog(_TAG, 'window height:$windowHeight');
    RepositoryProvider.of<AppRepo>(context).notify({TYPE: DISABLE});
    return BlocBuilder<CamCubit, CamState>(builder: (ctx, state) {
      final cubit = BlocProvider.of<CamCubit>(ctx);
      final screenNotifier = ValueNotifier(true);
      return Scaffold(
          floatingActionButton: state.camStatus == CamStatus.cam
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  if (state.isTorchOn != null)
                    FloatingActionButton(
                        mini: true,
                        onPressed: () => cubit.toggleTorch(),
                        child: Icon(Icons.flashlight_on, color: state.isTorchOn! ? amber : null)),
                  FloatingActionButton(
                      mini: true,
                      onPressed: () => cubit.toggleScreenLight(),
                      child: Icon(Icons.light_mode, color: state.screenOn ? amber : null)),
                  FloatingActionButton(
                      mini: true,
                      onPressed: () => Helper.switchCamera(state.renderer!.srcObject!.getVideoTracks().single),
                      child: const Icon(Icons.switch_camera_outlined))
                ])
              : null,
          appBar: _hideBarInCamWidget(orientation, windowHeight)
              ? null
              : AppBar(title: const Text('Camera', style: TextStyle(color: Colors.deepPurple)), actions: [
                  state.live
                      ? StreamBuilder<int>(
                          initialData: cubit.time,
                          stream: cubit.timeStream,
                          builder: (context, snap) =>
                              Text(_getTime(snap.data!), style: const TextStyle(color: Colors.red)))
                      : Text(state.camStatus == CamStatus.cam ? 'offline' : 'turned off',
                          style: const TextStyle(color: Colors.grey)),
                  IconButton(
                      onPressed: () => cubit.setQrVisible(true),
                      icon: const Icon(Icons.share, color: Colors.deepPurple))
                ]),
          body: _getBody(ctx, state, cubit));
    });
  }

  _hideBarInCamWidget(Orientation orientation, double windowHeight) =>
      orientation == Orientation.landscape && windowHeight < 393;

  _getBody(BuildContext context, CamState state, CamCubit cubit) {
    final camState = state.camStatus;
    appLog(_TAG, 'cam camState:$camState');
    if (state.animate)
      WidgetsBinding.instance.addPostFrameCallback((_) => DefaultTabController.of(context).animateTo(0));
    switch (camState) {
      case CamStatus.generating:
        return LayoutBuilder(builder: (ctx, cnts) {
          cubit.init(cnts.maxWidth.toInt(), cnts.maxHeight.toInt());
          return const Center(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [CircularProgressIndicator(), Text('Initializing the camera')]));
        });
      case CamStatus.permission_restricted:
        return const Center(
            child: Text('It seems like someone restricted your access to the camera. You can not use your camera'));
      case CamStatus.permanently_denied:
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
      case CamStatus.cam:
        var lastPointerTs = 0;
        final mainCubit = context.read<MainCubit>();
        return Stack(alignment: AlignmentDirectional.center, children: [
          GestureDetector(
              child: Listener(
                  child: RTCVideoView(state.renderer!, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                  onPointerDown: (p) {
                    if (DateTime.now().millisecondsSinceEpoch - lastPointerTs < 299)
                      mainCubit.setPhysics(const NeverScrollableScrollPhysics());
                    lastPointerTs = DateTime.now().millisecondsSinceEpoch;
                  }),
              onScaleEnd: (_) => mainCubit.setPhysics(null),
              onScaleUpdate: (det) {
                if (det.pointerCount == 1) return;
                cubit.onScaleUpdate(det.scale);
              }),
          if (state.qrVisible)
            Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.white),
                width: 200,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                      padding: const EdgeInsets.only(left: 9, right: 9),
                      child: Row(children: [
                        const Expanded(child: Text("Scan this QR code with your 'monitor' phone")),
                        IconButton(
                            onPressed: () => BlocProvider.of<CamCubit>(context).setQrVisible(false),
                            icon: const Icon(Icons.close_outlined))
                      ])),
                  QrImageView(data: state.qr!, version: QrVersions.auto, backgroundColor: Colors.white),
                  Padding(
                      padding: const EdgeInsets.only(left: 9, right: 9),
                      child: Row(children: [
                        const Expanded(child: Text("Or, share the link with your 'monitor' phone")),
                        IconButton(
                            onPressed: () =>
                                Share.share('https://eye-phone.top/?$CAM_ID=${state.qr}', subject: 'Camera link'),
                            icon: const Icon(Icons.share))
                      ]))
                ])),
          Positioned(
              bottom: 8,
              child: GestureDetector(
                  child: CircleAvatar(backgroundColor: state.live ? Colors.red : null), onTap: () => cubit.goLive())),
          Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                  onTap: () => cubit.turn(on: false),
                  child: Container(
                      margin: const EdgeInsets.all(1),
                      color: const Color(0xFFF6F1FC),
                      child: const Icon(Icons.close, color: Colors.deepPurple))))
        ]);
      case CamStatus.denied:
        return ConstrainedBox(
            constraints: const BoxConstraints.expand(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('You must grant access your camera in order to use this device as a camera',
                      style: TextStyle(fontSize: 15))),
              ElevatedButton(onPressed: () => cubit.requestPermissions(), child: const Text('Grant permission'))
            ]));
      case CamStatus.off:
        return Center(child: ElevatedButton(onPressed: () => cubit.turn(on: true), child: const Text('Turn on')));
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
