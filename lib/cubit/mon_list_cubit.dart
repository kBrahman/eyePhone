// ignore_for_file: constant_identifier_names

import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eye_phone/repo/app_repo.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../util/util.dart';
import 'mon_cubit.dart';

class MonListCubit extends Cubit<MonListState> {
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
        final mons = state.mons.map((m) => m.peerId).whereType<String>();
        appLog(_TAG, 'mos:$mons');
        _saveMons(mons);
      }
    });
  }

  addCam(String? camId) {
    if (camId == null || state.mons.any((m) => m.peerId == camId)) return;
    emit(state.copyWith(mons: state.mons..add(MonCubit(peerId: camId, repo: _repo)..getState(camId))));
    _saveMons(state.mons.map((m) => m.peerId).whereType<String>());
  }

  void deleteMon(int i) {
    emit(state.copyWith(mons: state.mons..removeAt(i)));
    _saveMons(state.mons.map((m) => m.peerId).whereType<String>());
  }

  void _saveMons(Iterable<String> mons) => _repo.saveStringListToSp(PEERS, mons.toList(growable: false)).whenComplete(
      () async => _repo.getBoolFromSp(IS_SIGNED_IN) ?? false
          ? FirebaseFirestore.instance.doc('$USER/${_repo.getStringFromSp(LOGIN)}').update({PEERS: mons})
          : null);

  void _init() => emit(
      state.copyWith(mons: _repo.getStringListFromSp(PEERS).map((id) => MonCubit(peerId: id, repo: _repo)).toList()));

  profile() {}
}

class MonListState {
  final List<MonCubit> mons;
  final bool loading;
  final bool openProfile;

  const MonListState({required this.mons, this.loading = true, this.openProfile = false});

  MonListState copyWith({List<MonCubit>? mons, bool? loading, bool? openProfile}) =>
      MonListState(mons: mons ?? this.mons, loading: loading ?? false, openProfile: openProfile ?? this.openProfile);
}
