// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:eye_phone/repo/app_repo.dart';
import 'package:flutter/src/widgets/scroll_physics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../util/util.dart';

class MainCubit extends Cubit<AppState> {
  static const _TAG = 'MainCubit';
  final AppRepo _repo;

  MainCubit(this._repo) : super(const AppState()) {
    checkConn();
    _listenToConn();
  }

  Future<void> _listenToConn() async {
    ConnectivityResult? lastCR;
    await for (final cr in Connectivity().onConnectivityChanged) {
      appLog(_TAG, 'onConnectivityChanged:$cr');
      if (cr != lastCR)
        emit(state.copyWith(appStatus: cr == ConnectivityResult.none ? AppStatus.no_internet : AppStatus.list));
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
    emit(state.copyWith(appStatus: inetOk ? AppStatus.list : AppStatus.no_internet));
  }

  closeWS() => _repo.close().then((ws) => emit(state.copyWith(canPop: true)));

  void setPhysics(ScrollPhysics? physics) => emit(state.copyWith(physics: physics));
}

class AppState {
  final bool canPop;
  final AppStatus appStatus;
  final ScrollPhysics? physics;

  const AppState({this.physics, this.canPop = false, this.appStatus = AppStatus.list});

  AppState copyWith({AppStatus? appStatus, bool? canPop, ScrollPhysics? physics}) =>
      AppState(appStatus: appStatus ?? this.appStatus, canPop: canPop ?? this.canPop, physics: physics);
}

enum AppStatus { no_internet, list }
