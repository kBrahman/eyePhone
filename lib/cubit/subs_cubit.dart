// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../repo/app_repo.dart';
import '../util/util.dart';

class SubsCubit extends Cubit<SubsState> implements Observer {
  static const _TAG = 'PremiumCubit';
  final AppRepo _repo;
  final TextEditingController loginCtr = TextEditingController();
  final TextEditingController smsCtr = TextEditingController();
  String? _verId;
  int? _resendToken;
  final bool _signInOnly;

  SubsCubit(this._repo, this._signInOnly)
      : super(SubsState(uiState: _signInOnly ? SubsUiState.sign_in : SubsUiState.offer)) {
    // _repo.register(this);
    if (Platform.isAndroid)
      InAppPurchase.instance
          .isAvailable()
          .then((v) =>
              v ? InAppPurchase.instance.queryProductDetails({SUBS_ID}) : emit(state.copyWith(storeAvailable: false)))
          .then((dynamic det) {
        if (det is ProductDetailsResponse) emit(state.copyWith(price: det.productDetails.single.price));
      });
  }

  void upgrade() => _repo.getBoolFromSp(IS_SIGNED_IN) ?? false
      ? _repo.subscribe()
      : emit(state.copyWith(uiState: SubsUiState.sign_in));

  void phoneSignIn() {
    appLog(_TAG, 'phoneSignIn');
    emit(state.copyWith(uiState: SubsUiState.sign_in_phone));
  }

  Future<void> googleSignIn() async {
    GoogleSignIn googleSignIn = GoogleSignIn(scopes: <String>['email']);
    var login = googleSignIn.currentUser?.email;
    try {
      if (login == null && (login = (await googleSignIn.signInSilently())?.email) == null) {
        final acc = await googleSignIn.signIn();
        login = acc?.email;
      }
      if (login == null)
        emit(state.copyWith(googleErr: true));
      else
        _reg(login);
    } on PlatformException catch (e) {
      if (e.message == 'network_error') {
        // globalSink.add(GlobalEvent.ERR_CONN);
        // return data.copyWith(progress: false);
      }
      appLog(_TAG, 'google sign in exception:$e');
    }
  }

  Future<void> appleSignIn() => FirebaseAuth.instance
      .signInWithProvider(AppleAuthProvider())
      .then((cred) => cred.user?.uid == null ? emit(state.copyWith(appleErr: true)) : _reg(cred.user!.uid));

  void phoneSignInNext() {
    final login = loginCtr.text;
    if (login.isEmpty) return;
    if (login.length < 5 || login.length > 20)
      emit(state.copyWith(loginInvalid: true));
    else {
      emit(state.copyWith(uiState: SubsUiState.sms));
    }
  }

  void verifyPhone() => loginCtr.text.length < 5 || loginCtr.text.length > 25
      ? emit(state.copyWith(loginInvalid: true))
      : FirebaseAuth.instance
          .verifyPhoneNumber(
              timeout: const Duration(minutes: 2),
              phoneNumber: _correctIfNeeded(),
              verificationCompleted: _complete,
              verificationFailed: _failed,
              codeSent: _smsSent,
              forceResendingToken: _resendToken,
              codeAutoRetrievalTimeout: _timeOut)
          .whenComplete(_startTimer)
          .whenComplete(
              () => emit(state.copyWith(uiState: SubsUiState.sms, timerTime: TIME_OUT.toString(), canResend: false)));

  void _smsSent(String id, int? tok) {
    _verId = id;
    _resendToken = tok;
    appLog(_TAG, 'sms sent, tok:$tok');
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

  void _complete(PhoneAuthCredential cred) {
    smsCtr.text = cred.smsCode!;
    appLog(_TAG, 'completed');
    _reg(loginCtr.text);
    emit(state.copyWith(canResend: false));
  }

  FutureOr<void> _startTimer() => Timer.periodic(const Duration(seconds: 1), (timer) {
        final stop = timer.tick == TIME_OUT;
        if (!isClosed)
          emit(state.copyWith(timerTime: stop ? null : (TIME_OUT - timer.tick).toString(), canResend: stop));
        if (stop) timer.cancel();
      });

  void sendSms() => smsCtr.text.isEmpty
      ? null
      : _verId == null || smsCtr.text.length != 6
          ? emit(state.copyWith(smsWrong: true))
          : _sendSms();

  void _sendSms() async {
    appLog(_TAG, '_sendSms');
    emit(state.copyWith(loading: true));
    try {
      await FirebaseAuth.instance
          .signInWithCredential(PhoneAuthProvider.credential(verificationId: _verId!, smsCode: smsCtr.text));
      appLog(_TAG, 'sign in success');
      _reg(loginCtr.text);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') emit(state.copyWith(smsWrong: true, loading: false));
      appLog(_TAG, 'exception:${e.code}');
    }
  }

  String _correctIfNeeded() {
    if (loginCtr.text.startsWith('7') && loginCtr.text.length == 10) loginCtr.text = '7${loginCtr.text}';
    return '+${loginCtr.text}';
  }

  @override
  onData(Map<String, dynamic> map) {
    appLog(_TAG, 'on data:$map');
    if (map[TYPE] == PURCHASE_SUCCESS) {
      emit(state.copyWith(popModalSheet: true));
    }
  }

  void _reg(String login) => FirebaseFirestore.instance.doc('$USER/$login').get().then((doc) async => doc.exists
      ? _sync()
      : FirebaseFirestore.instance
          .doc('$USER/$login')
          .set({CAM_ID: await _repo.getCamId(), PEERS: _repo.getStringListFromSp(PEERS)}).whenComplete(() {
          _repo
            ..saveBoolToSp(IS_SIGNED_IN, true)
            ..savStringToSp(LOGIN, login);
          emit(state.copyWith(popModalSheet: true));
        }));

  void _sync() {}
}

class SubsState {
  final bool storeAvailable;
  final bool loading;
  final SubsUiState uiState;
  final bool loginInvalid;
  final String? timerTime;
  final bool smsWrong;
  final bool popModalSheet;
  final String? price;
  final bool canResend;
  final bool appleErr;
  final bool googleErr;

  const SubsState(
      {this.storeAvailable = true,
      this.loading = false,
      this.uiState = SubsUiState.offer,
      this.loginInvalid = false,
      this.timerTime,
      this.smsWrong = false,
      this.popModalSheet = false,
      this.price,
      this.canResend = true,
      this.appleErr = false,
      this.googleErr = false});

  get keyboardPadding => uiState == SubsUiState.sign_in_phone || uiState == SubsUiState.sms;

  SubsState copyWith(
          {bool? storeAvailable,
          bool? loading,
          SubsUiState? uiState,
          bool? loginInvalid,
          String? timerTime,
          bool? smsWrong,
          bool? popModalSheet,
          String? price,
          bool? canResend,
          bool? appleErr,
          bool? googleErr}) =>
      SubsState(
          storeAvailable: storeAvailable ?? this.storeAvailable,
          loading: loading ?? this.loading,
          uiState: uiState ?? this.uiState,
          loginInvalid: loginInvalid ?? false,
          timerTime: timerTime,
          smsWrong: smsWrong ?? this.smsWrong,
          popModalSheet: popModalSheet ?? false,
          price: price ?? this.price,
          canResend: canResend ?? this.canResend,
          appleErr: appleErr ?? false,
          googleErr: googleErr ?? false);
}

enum SubsUiState { offer, sign_in, sign_in_phone, sms, email_sent }
