// ignore_for_file: constant_identifier_names


import 'package:app_links/app_links.dart';
import 'package:eye_phone/repo/app_repo.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../util/util.dart';
import 'mon_cubit.dart';

class MonListCubit extends Cubit<MonListState> implements Observer {
  static const _TAG = 'MonListCubit';
  final AppRepo _repo;

  MonListCubit(this._repo) : super(const MonListState(mons: [])) {
    appLog(_TAG, 'init');
    _init();
    AppLinks().allUriLinkStream.listen((uri) {
      final id = uri.queryParameters[CAM_ID];
      appLog(_TAG, 'id from app link:$id');
      if (id != null && !state.mons.any((m) => m.peerId == id)) {
        emit(state..mons.add(MonCubit(peerId: id, repo: _repo)));
        _saveMons();
      }
    });
    _repo.register(this);
  }

  addCam(String? camId) {
    if (camId == null || state.mons.any((m) => m.peerId == camId)) return;
    emit(state.copyWith(mons: state.mons..add(MonCubit(peerId: camId, repo: _repo)..getState(camId))));
    _saveMons();
  }

  deleteMon(int i) {
    emit(state.copyWith(mons: state.mons..removeAt(i)));
    _saveMons();
  }

  void _saveMons() =>
      _repo.saveStringListToSp(PEERS, state.mons.map((m) => m.peerId).whereType<String>().toList(growable: false));

  _init() => emit(
      state.copyWith(mons: _repo.getStringListFromSp(PEERS).map((id) => MonCubit(peerId: id, repo: _repo)).toList()));

  @override
  onData(Map<String, dynamic> map) {
    if (map[TYPE] == IS_SIGNED_IN) emit(state.copyWith());
  }
}

class MonListState {
  final List<MonCubit> mons;
  final bool loading;

  const MonListState({required this.mons, this.loading = true});

  MonListState copyWith({List<MonCubit>? mons, bool? loading}) =>
      MonListState(mons: mons ?? this.mons, loading: loading ?? false);
}
