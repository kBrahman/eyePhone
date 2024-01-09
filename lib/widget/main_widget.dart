// ignore_for_file: constant_identifier_names

import 'package:eye_phone/bloc/app/app_bloc.dart';
import 'package:eye_phone/util.dart';
import 'package:eye_phone/widget/cam_widget.dart';
import 'package:eye_phone/widget/mon_list_widget.dart';
import 'package:flutter/material.dart';

class MainWidget extends StatelessWidget {
  static const _TAG = 'MainWidget';
  final AppBloc _bloc;

  const MainWidget(this._bloc, {super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    appLog(_TAG, 'build, w:${size.width}, h:${size.height}');
    return Scaffold(
        body: DefaultTabController(
            length: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                  child: LayoutBuilder(
                      builder: (ctx, cnts) => StreamBuilder<AppData>(
                          initialData: const AppData(),
                          stream: _bloc.getStream(cnts.maxWidth.toInt(), cnts.maxHeight.toInt()),
                          builder: (ctx, snap) {
                            final data = snap.data;
                            appLog(_TAG, 'data:$data');
                            return TabBarView(children: [MonListWidget(data!, _bloc), CamWidget(data, _bloc)]);
                          }))),
              const TabBar(tabs: [Tab(text: 'Mon'), Tab(text: 'Cam')])
            ])));
  }
}
