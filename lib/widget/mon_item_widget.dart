// ignore_for_file: constant_identifier_names

import 'package:eye_phone/util/util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../cubit/cam_cubit.dart';
import '../cubit/mon_cubit.dart';

class MonItemWidget extends StatelessWidget {
  static const _TAG = 'MonItemWidget';
  final MonCubit _cubit;

  const MonItemWidget(this._cubit, {super.key});

  @override
  Widget build(BuildContext context) {
    final isLocal = _cubit.isLocal;
    appLog(_TAG, 'build, is local:$isLocal, whc:$hashCode');
    return Card(
        clipBehavior: Clip.hardEdge,
        child: isLocal
            ? BlocSelector<CamCubit, CamState, MonState>(
                selector: (camState) => camState.toLocMonState(),
                builder: (ctx, monState) => _Content(monState, 'This device'))
            : BlocProvider.value(
                value: _cubit,
                child:
                    BlocBuilder<MonCubit, MonState>(builder: (ctx, state) => _Content(state, getName(_cubit.peerId)))));
  }
}

class _Content extends StatelessWidget {
  final MonState _state;
  final String _name;

  const _Content(this._state, this._name, {super.key});

  @override
  Widget build(BuildContext context) {
    final status = _state.monStatus;
    return status == MonStatus.loading
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
            status == MonStatus.live
                ? RTCVideoView(_state.renderer!, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                : Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: Text(
                        status == MonStatus.offline
                            ? 'OFFLINE'
                            : status == MonStatus.turned_off
                                ? 'TURNED OFF'
                                : status == MonStatus.server_down
                                    ? 'SERVER IS DOWN'
                                    : 'DISCONNECTED',
                        style: const TextStyle(color: Colors.white))),
            Positioned(
                left: 8,
                bottom: 4,
                child: Text(_name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
          ]);
  }
}
