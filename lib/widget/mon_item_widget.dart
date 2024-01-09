// ignore_for_file: constant_identifier_names

import 'package:eye_phone/bloc/mon_bloc.dart';
import 'package:eye_phone/util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class MonItemWidget extends StatelessWidget {
  static const _TAG = 'MonItemWidget';
  final MonBloc _bloc;

  MonItemWidget(this._bloc, {super.key}) {
    appLog(_TAG, 'init, hc:$hashCode');
  }

  @override
  Widget build(BuildContext context) {
    appLog(_TAG, 'build');
    return Card(
        clipBehavior: Clip.hardEdge,
        child: StreamBuilder<MonData>(
            initialData: _bloc.data ?? const MonData(),
            stream: _bloc.getStream(),
            builder: (ctx, snap) {
              if (snap.hasError) return Text(snap.error.toString());
              final data = snap.data!;
              final state = data.state;
              appLog(_TAG, 'data:$data');
              return state == MonState.loading
                  ? StreamBuilder<double>(
                      initialData: 0,
                      stream: Stream.periodic(const Duration(milliseconds: 50), (ms) => (ms * 50 % 1000) / 1000),
                      builder: (ctx, snap) => Container(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: const [Color(0xFFEBEBF4), Color(0xFFF4F4F4), Color(0xFFEBEBF4)],
                                  stops: [snap.data!, snap.data! + 0.2, snap.data! + 0.4],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight))))
                  : Stack(children: [
                      state == MonState.live
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
                                              ? 'SERVER IS DOWN'
                                              : 'DISCONNECTED',
                                  style: const TextStyle(color: Colors.white))),
                      Positioned(
                          left: 8,
                          bottom: 4,
                          child:
                              Text(data.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
                    ]);
            }));
  }
}
