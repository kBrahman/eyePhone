// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'package:eye_phone/bloc/mon_bloc.dart';
import 'package:eye_phone/util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class MonWidget extends StatelessWidget {
  static const _TAG = 'MonWidget';
  final MonBloc _bloc;

  const MonWidget(this._bloc, {super.key});

  @override
  Widget build(BuildContext context) {
    appLog(_TAG, 'build');
    return Scaffold(
        appBar: AppBar(title: Text(_bloc.data?.name ?? '')),
        body: StreamBuilder(
            initialData: _bloc.data,
            stream: _bloc.getStream(),
            builder: (ctx, snap) {
              final state = snap.data!.state;
              return state == MonState.loading
                  ? const Center(child: CircularProgressIndicator())
                  : state == MonState.live
                      ? RTCVideoView(_bloc.renderer!, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                      : Container(
                          color: Colors.black,
                          alignment: Alignment.center,
                          child: Text(
                              state == MonState.offline
                                  ? 'OFFLINE'
                                  : state == MonState.turned_off
                                      ? 'TURNED OFF'
                                      : state == MonState.server_down
                                          ? 'SERVER ID DOWN'
                                          : 'DISCONNECTED',
                              style: const TextStyle(color: Colors.white)));
            }));
  }
}
