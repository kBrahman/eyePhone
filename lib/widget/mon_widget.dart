// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'package:eye_phone/util/util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../cubit/mon_cubit.dart';

class MonWidget extends StatelessWidget {
  static const _TAG = 'MonWidget';
  final MonCubit _cubit;

  const MonWidget(this._cubit, {super.key});

  @override
  Widget build(BuildContext context) => BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<MonCubit, MonState>(builder: (ctx, state) {
        final monStatus = state.monStatus;
        appLog(_TAG, 'build');
        return Scaffold(
            floatingActionButton: monStatus == MonStatus.live
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    if (state.torchOn != null)
                      FloatingActionButton(
                          heroTag: null,
                          mini: true,
                          onPressed: () => _cubit.toggleTorch(),
                          child: Icon(Icons.flashlight_on, color: state.torchOn! ? amber : null)),
                    StreamBuilder<int>(
                        initialData: 0,
                        stream: state.sirenOn ? Stream.periodic(const Duration(milliseconds: 300), (i) => i + 1) : null,
                        builder: (context, snapshot) {
                          final forward = snapshot.data! % 2 == 0;
                          return TweenAnimationBuilder(
                              tween: ColorTween(
                                  begin: forward ? null : Colors.red.shade800,
                                  end: forward ? Colors.red.shade800 : Colors.deepPurple.shade100),
                              duration: const Duration(milliseconds: 250),
                              child: const Icon(Icons.speaker_phone),
                              builder: (ctx, col, ch) => FloatingActionButton(
                                  backgroundColor: state.sirenOn ? col : null,
                                  heroTag: null,
                                  mini: true,
                                  onPressed: () => _cubit.toggleSiren(),
                                  child: ch));
                        }),
                    FloatingActionButton(
                        heroTag: null,
                        mini: true,
                        onPressed: () => _cubit.toggleScreen(),
                        child: Icon(Icons.light_mode, color: state.screenOn ? amber : null)),
                    FloatingActionButton(
                        heroTag: null,
                        mini: true,
                        onPressed: () => _cubit.switchCamera(),
                        child: const Icon(Icons.switch_camera_outlined))
                  ])
                : null,
            appBar: AppBar(
                toolbarHeight: kToolbarHeight * .7,
                titleSpacing: 0,
                actions: state.monStatus != MonStatus.disconnected
                    ? [
                        IconButton(
                            onPressed: () => _cubit.turnOnOff(),
                            icon: Icon(Icons.power_settings_new_rounded,
                                color: state.monStatus == MonStatus.turned_off ? Colors.grey : Colors.red.shade800)),
                        if (state.monStatus == MonStatus.live) ...[
                          IconButton(
                              onPressed: () => _cubit.toggleSound(),
                              icon: Icon(state.soundOn ? Icons.volume_up_outlined : Icons.volume_off_outlined)),
                          IconButton(
                              onPressed: () => _cubit.toggleMic(), icon: Icon(state.micOn ? Icons.mic : Icons.mic_off))
                        ]
                      ]
                    : null,
                title: Text(getName(_cubit.peerId), style: const TextStyle(fontSize: 20))),
            body: monStatus == MonStatus.loading
                ? const Center(child: CircularProgressIndicator())
                : monStatus == MonStatus.live
                    ? GestureDetector(
                        onScaleUpdate: (d) => d.pointerCount == 2 ? _cubit.sendScale(d.scale) : null,
                        child:
                            RTCVideoView(state.renderer!, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover))
                    : Container(
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: Text(
                            monStatus == MonStatus.offline
                                ? 'OFFLINE'
                                : monStatus == MonStatus.turned_off
                                    ? 'TURNED OFF'
                                    : monStatus == MonStatus.server_down
                                        ? 'SERVER IS DOWN'
                                        : 'DISCONNECTED',
                            style: const TextStyle(color: Colors.white))));
      }));
}
