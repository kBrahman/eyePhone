// ignore_for_file: constant_identifier_names,curly_braces_in_flow_control_structures
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../util/util.dart';

class AppRepo extends WidgetsBindingObserver {
  static const _TAG = 'AppRepo';
  final SharedPreferences _sp;
  final _observers = <Observer>[];
  late final WebSocket _webSocket;
  ProductDetails? productDetails;

  AppRepo(this._sp) {
    _ws();
    _inApp();
  }

  Future<String> getCamId() async {
    var camId = _sp.getString(CAM_ID);
    if (camId == null) {
      try {
        final doc = await FirebaseFirestore.instance.collection(PATH_CAM).doc().get();
        camId = doc.id;
        appLog(_TAG, 'id from firebase:$camId');
      } catch (e) {
        appLog(_TAG, 'firebase could not create a doc id, reason:$e');
      }
      camId ??= generateRandomString(20);
      camId += '_${await name}';
      _sp.setString(CAM_ID, camId);
    }
    appLog(_TAG, 'cam id:$camId');
    return camId;
  }

  bool? getBoolFromSp(String key) => _sp.getBool(key);

  List<String> getStringListFromSp(String key) => (_sp.getStringList(PEERS) ?? []);

  void saveStringListToSp(String key, List<String> list) => _sp.setStringList(key, list);

  String? getStringFromSp(String key) => _sp.getString(key);

  void _ws() async =>
      WebSocket.connect(getURL(), headers: {CAM_ID: await getCamId()}).then(_onConnected).onError(_onError);

  _onConnected(WebSocket ws) async {
    _webSocket = ws;
    ws.pingInterval = const Duration(seconds: 99);
    notify({TYPE: CONNECTED});
    await for (final e in ws) {
      final map = jsonDecode(e);
      notify(map);
    }
  }

  void notify(map) {
    for (final o in _observers) o.onData(map);
  }

  void register(Observer observer) {
    _observers.add(observer);
  }

  void send(data) => _webSocket.add(jsonEncode(data));

  Future<bool> saveBoolToSp(String key, bool value) => _sp.setBool(key, value);

  FutureOr _onError(Object error, StackTrace stackTrace) {
    appLog(_TAG, 'ws error:$error');
  }

  Future close() => _webSocket.close(WebSocketStatus.normalClosure);

  Future<void> _inApp() async {
    InAppPurchase.instance.queryProductDetails({'eye_premium'}).then((det) {
      productDetails = det.productDetails.single;
    }).onError((error, stackTrace) => appLog(_TAG, 'in app err:$error'));
    await for (final p in InAppPurchase.instance.purchaseStream) appLog(_TAG, 'on purchase:$p');
  }

  void subscribe() =>
      InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: productDetails!));
}

abstract class Observer {
  onData(Map<String, dynamic> map);
}
