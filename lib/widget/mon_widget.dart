import 'package:eye_phone/bloc/app/app_bloc.dart';
import 'package:eye_phone/bloc/mon_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class MonWidget extends StatelessWidget {
  final MonBloc _bloc;

  const MonWidget(this._bloc, {super.key});

  @override
  Widget build(BuildContext context) {
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
                                      : 'DISCONNECTED',
                              style: const TextStyle(color: Colors.white)));
            }));
  }
}
