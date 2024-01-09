// ignore_for_file: constant_identifier_names

import 'package:eye_phone/manager/deep_link_manager.dart';
import 'package:eye_phone/util.dart';
import 'package:eye_phone/widget/main_widget.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'bloc/app/app_bloc.dart';
import 'firebase_options.dart';

void main() {
  appLog('main', 'main');
  runApp(App());
  Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // WidgetsBinding.instance.platformDispatcher.onError = (e, s) {
  //   appLog('PlatformDispatcher', 'exc:$e, stack:$s');
  //   return true;
  // };
}

class App extends StatelessWidget {
  static const _TAG = 'App';
  final _deepMan = DeepLinkManager();

  App({super.key});

  @override
  Widget build(BuildContext context) {
    appLog(_TAG, 'build');
    return MaterialApp(
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
        home: MainWidget(AppBloc(_deepMan)));
  }
}
