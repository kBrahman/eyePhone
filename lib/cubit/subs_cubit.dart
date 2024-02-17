// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../repo/app_repo.dart';
import '../util/util.dart';

class SubsCubit extends Cubit<SubsState> {
  static const _TAG = 'PremiumCubit';
  final AppRepo _repo;
  final TextEditingController loginCtr = TextEditingController();
  final TextEditingController smsCtr = TextEditingController();
  String? _verId;

  SubsCubit(this._repo) : super(const SubsState());

  bool isPremium() => _repo.getBoolFromSp(IS_PREMIUM) ?? false;

  upgrade() {
    if (state.loading) return;
    if (_repo.getBoolFromSp(IS_SIGNED_IN) ?? false)
      _buy();
    else
      emit(state.copyWith(uiState: SubsUiState.sign_in));
  }

  void _buy() => InAppPurchase.instance.isAvailable().then((v) {
        appLog(_TAG, 'store avail:$v');
        if (!v)
          emit(state.copyWith(storeAvailable: false));
        else
          _repo.subscribe();
      });

  void phoneSignIn() {
    appLog(_TAG, 'phoneSignIn');
    emit(state.copyWith(uiState: SubsUiState.sign_in_phone));
  }

  void emailSignIn() {}

  void googleSignIn() {}

  void appleSignIn() {}

  void phoneSignInNext() {
    final login = loginCtr.text;
    if (login.isEmpty) return;
    if (login.length < 5 || login.length > 20)
      emit(state.copyWith(loginInvalid: true));
    else {
      emit(state.copyWith(uiState: SubsUiState.sms));
    }
  }

  void verify() => loginCtr.text.length < 5 || loginCtr.text.length > 25
      ? emit(state.copyWith(loginInvalid: true))
      : FirebaseAuth.instance
          .verifyPhoneNumber(
              phoneNumber: _correctIfNeeded(),
              verificationCompleted: _autoComplete,
              verificationFailed: _failed,
              codeSent: _smsSent,
              codeAutoRetrievalTimeout: _timeOut)
          .whenComplete(_startTimer)
          .whenComplete(() => emit(state.copyWith(loading: true, uiState: SubsUiState.sms)));

  _smsSent(String id, int? tok) {
    _verId = id;
    appLog(_TAG, 'sms sent');
  }

  void _timeOut(vId) {
    appLog(_TAG, 'timeout:$vId');
  }

  void _failed(FirebaseAuthException error) {
    appLog(_TAG, 'failed:$error');
    if (error.code == 'invalid-phone-number') {
    } else if (error.code == 'too-many-requests') {}
  }

  void toState(SubsUiState uiState) => emit(state.copyWith(uiState: uiState));

  void _autoComplete(PhoneAuthCredential cred) => FirebaseFirestore.instance
      .doc('$USER/${loginCtr.text}')
      .set({})
      .whenComplete(() => _repo.saveBoolToSp(IS_SIGNED_IN, true))
      .whenComplete(() {
        smsCtr.text = cred.smsCode!;
        emit(state.copyWith(uiState: SubsUiState.offer, loading: false));
      });

  FutureOr<void> _startTimer() => Timer.periodic(const Duration(seconds: 1), (timer) {
        const timeOut = 83;
        final stop = timer.tick > timeOut || state.uiState == SubsUiState.offer;
        emit(state.copyWith(timerTime: stop ? null : (timeOut - timer.tick).toString(), loading: !stop));
        if (stop) timer.cancel();
      });

  void sendSms() => smsCtr.text.isEmpty
      ? null
      : _verId == null || smsCtr.text.length != 6
          ? emit(state.copyWith(smsWrong: true))
          : _sendSms();

  _sendSms() async {
    appLog(_TAG, '_sendSms');
    try {
      await FirebaseAuth.instance
          .signInWithCredential(PhoneAuthProvider.credential(verificationId: _verId!, smsCode: smsCtr.text));
      emit(state.copyWith(uiState: SubsUiState.offer, loading: false));
      _buy();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') emit(state.copyWith(smsWrong: true));
      appLog(_TAG, 'exception:${e.code}');
    }
  }

  _correctIfNeeded() {
    if (loginCtr.text.startsWith('7') && loginCtr.text.length == 10) loginCtr.text = '7${loginCtr.text}';
    return '+${loginCtr.text}';
  }
}

class SubsState {
  final bool storeAvailable;
  final bool loading;
  final SubsUiState uiState;
  final bool loginInvalid;
  final String? timerTime;
  final bool smsWrong;

  const SubsState(
      {this.storeAvailable = true,
      this.loading = false,
      this.uiState = SubsUiState.offer,
      this.loginInvalid = false,
      this.timerTime,
      this.smsWrong = false});

  get mustAuth => uiState == SubsUiState.sign_in || uiState == SubsUiState.sign_in_phone || uiState == SubsUiState.sms;

  SubsState copyWith(
          {bool? storeAvailable,
          bool? loading,
          SubsUiState? uiState,
          bool? loginInvalid,
          String? timerTime,
          bool? smsWrong}) =>
      SubsState(
          storeAvailable: storeAvailable ?? this.storeAvailable,
          loading: loading ?? this.loading,
          uiState: uiState ?? this.uiState,
          loginInvalid: loginInvalid ?? false,
          timerTime: timerTime,
          smsWrong: smsWrong ?? this.smsWrong);
}

enum SubsUiState { offer, sign_in, sign_in_phone, sms }
