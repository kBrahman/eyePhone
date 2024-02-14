// ignore_for_file: constant_identifier_names

import 'package:eye_phone/widget/main_widget.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(App(await SharedPreferences.getInstance()));
  // WidgetsBinding.instance.platformDispatcher.onError = (e, s) {
  //   appLog('PlatformDispatcher', 'exc:$e, stack:$s');
  //   return true;
  // };
}

class App extends StatelessWidget {
  static const _TAG = 'App';

  final SharedPreferences _sp;

  const App(this._sp, {super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)), home: MainWidget(_sp));
}
