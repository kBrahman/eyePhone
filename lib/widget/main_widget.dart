// ignore_for_file: constant_identifier_names, unused_field

import 'package:eye_phone/repo/app_repo.dart';
import 'package:eye_phone/widget/cam_widget.dart';
import 'package:eye_phone/widget/mon_list_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cubit/cam_cubit.dart';
import '../cubit/main_cubit.dart';
import '../cubit/mon_list_cubit.dart';

class MainWidget extends StatelessWidget {
  static const _TAG = 'MainWidget';
  final SharedPreferences _sp;

  const MainWidget(this._sp, {super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
        create: (c) => AppRepo(_sp),
        child: BlocProvider(
            create: (mainCubCtx) => MainCubit(mainCubCtx.read<AppRepo>()),
            child: BlocBuilder<MainCubit, AppState>(builder: (ctx, state) {
              if (state.canPop) WidgetsBinding.instance.addPostFrameCallback((_) => SystemNavigator.pop());
              return DefaultTabController(
                  length: 2,
                  child: Scaffold(
                      bottomNavigationBar: state.appStatus == AppStatus.list
                          ? const TabBar(tabs: [Tab(text: 'Mon'), Tab(text: 'Cam')])
                          : null,
                      body: switch (state.appStatus) {
                        AppStatus.list => MultiBlocProvider(
                              providers: [
                                BlocProvider(
                                    create: (blocCtx) => MonListCubit(RepositoryProvider.of<AppRepo>(blocCtx))),
                                BlocProvider(
                                    lazy: false, create: (blocCtx) => CamCubit(RepositoryProvider.of<AppRepo>(blocCtx)))
                              ],
                              child: PopScope(
                                  canPop: state.canPop,
                                  onPopInvoked: (did) => state.canPop ? null : ctx.read<MainCubit>().closeWS(),
                                  child: TabBarView(
                                      physics: state.physics, children: const [MonListWidget(), CamWidget()]))),
                        AppStatus.no_internet => Center(
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Text('No internet access',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            TextButton(
                                onPressed: () => ctx.read<MainCubit>().checkConn(),
                                child: const Padding(
                                    padding: EdgeInsets.only(left: 30, right: 30),
                                    child:
                                        Text('REFRESH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))))
                          ]))
                      }));
            })));
  }
}
