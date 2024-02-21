// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:eye_phone/repo/app_repo.dart';
import 'package:flutter/src/widgets/scroll_physics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../util/util.dart';

class MainCubit extends Cubit<MainState> {
  static const _TAG = 'MainCubit';
  final AppRepo _repo;

  MainCubit(this._repo) : super(const MainState()) {
    checkConn();
    _listenToConn();
  }

  Future<void> _listenToConn() async {
    ConnectivityResult? lastCR;
    await for (final cr in Connectivity().onConnectivityChanged) {
      appLog(_TAG, 'onConnectivityChanged:$cr');
      if (cr != lastCR)
        emit(state.copyWith(mainUiState: cr == ConnectivityResult.none ? MainUiState.no_internet : MainUiState.list));
      lastCR = cr;
    }
  }

  checkConn() async {
    var inetOk = true;
    try {
      final result = await InternetAddress.lookup('google.com');
      inetOk = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      inetOk = false;
    }
    emit(state.copyWith(mainUiState: inetOk ? MainUiState.list : MainUiState.no_internet));
  }

  closeWS() => _repo.close().then((ws) => emit(state.copyWith(canPop: true)));

  void setPhysics(ScrollPhysics? physics) => emit(state.copyWith(physics: physics));
}

class MainState {
  final bool canPop;
  final MainUiState mainUiState;
  final ScrollPhysics? physics;

  const MainState({this.physics, this.canPop = false, this.mainUiState = MainUiState.list});

  MainState copyWith({MainUiState? mainUiState, bool? canPop, ScrollPhysics? physics}) =>
      MainState(mainUiState: mainUiState ?? this.mainUiState, canPop: canPop ?? this.canPop, physics: physics);
}

enum MainUiState { no_internet, list }
