// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:math';
import 'package:eye_phone/cubit/subs_cubit.dart';
import 'package:eye_phone/repo/app_repo.dart';
import 'package:eye_phone/util/util.dart';
import 'package:eye_phone/widget/mon_widget.dart';
import 'package:eye_phone/widget/subs_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../cubit/main_cubit.dart';
import '../cubit/mon_cubit.dart';
import '../cubit/mon_list_cubit.dart';
import 'mon_item_widget.dart';

class MonListWidget extends StatelessWidget {
  static const _TAG = 'MonListWidget';

  const MonListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final repo = RepositoryProvider.of<AppRepo>(context)..notify({TYPE: ENABLE});
    return BlocBuilder<MonListCubit, MonListState>(builder: (ctx, state) {
      appLog(_TAG, 'bloc build');
      final cubit = BlocProvider.of<MonListCubit>(ctx);
      return Scaffold(
          floatingActionButton: FloatingActionButton(
              onPressed: () async => state.mons.isEmpty || (repo.getBoolFromSp(IS_PREMIUM) ?? false)
                  ? cubit.addCam(await _showQrScanWidget(ctx))
                  : showModalBottomSheet(context: context, builder: (ctx) => SubsWidget(repo)),
              child: const Icon(Icons.qr_code)),
          appBar: AppBar(
              title: const Text('Monitors', style: TextStyle(color: Colors.deepPurple)),
              actions: [IconButton(onPressed: () => context.read<MainCubit>().auth(), icon: const Icon(Icons.login))]),
          body: state.loading
              ? const Center(child: CircularProgressIndicator())
              : GridView.builder(
                  itemCount: state.mons.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _getAxisCount(w)),
                  itemBuilder: (ctx, i) {
                    var lastProg = .0;
                    appLog(_TAG, 'item builder');
                    final mon = state.mons[i];
                    final bloc = BlocProvider.of<MonListCubit>(ctx);
                    return Dismissible(
                        key: ValueKey(mon.peerId),
                        dismissThresholds: const {DismissDirection.endToStart: 1.0},
                        onUpdate: (det) {
                          if (det.direction == DismissDirection.endToStart &&
                              det.progress - lastProg > 0 &&
                              det.progress > .1) DefaultTabController.of(ctx).animateTo(1);
                          lastProg = det.progress;
                        },
                        confirmDismiss: (dir) => showDialog(
                            context: ctx,
                            builder: (c) => AlertDialog(
                                    title: const Text('Delete monitor'),
                                    content: const Text('Are you sure you want to delete this monitor?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('YES')),
                                      TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('NO'))
                                    ])),
                        background: const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                                padding: EdgeInsets.only(left: 9), child: Icon(Icons.delete, color: Colors.red))),
                        onDismissed: (dir) => bloc.deleteMon(i),
                        child: GestureDetector(
                            onTap: () => _openMon(ctx, i, mon), child: Hero(tag: i, child: MonItemWidget(mon))));
                  }));
    });
  }

  _openMon(BuildContext ctx, int i, MonCubit cub) {
    appLog(_TAG, 'open mon');
    Navigator.of(ctx).push(MaterialPageRoute(builder: (c) => Hero(tag: i, child: MonWidget(cub))));
  }

  Future<String?> _showQrScanWidget(BuildContext context) => showModalBottomSheet(
      useSafeArea: true,
      isScrollControlled: true,
      context: context,
      builder: (ctx) {
        var detected = false;
        return Scaffold(
            appBar: AppBar(
                title: const Text('Add Camera', style: TextStyle(color: Colors.deepPurple)),
                leading: const Icon(Icons.qr_code_outlined, color: Colors.deepPurple),
                backgroundColor: const Color(0xFFF6F1FC),
                actions: [
                  IconButton(
                      onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.deepPurple))
                ]),
            body: MobileScanner(
                onDetect: (cap) {
                  if (detected) return;
                  detected = true;
                  final id = cap.barcodes.single.rawValue;
                  appLog(_TAG, 'on detect, id:$id');
                  Navigator.of(context).pop(id);
                },
                overlay: CustomPaint(size: const Size.square(250), painter: _LineWithRadiusPainter(250))));
      });

  int _getAxisCount(double w) => w < 768 ? 2 : 3;
}

class _LineWithRadiusPainter extends CustomPainter {
  final double _w;

  _LineWithRadiusPainter(this._w);

  @override
  void paint(Canvas canvas, Size size) {
    const rect = Rect.fromLTRB(0, 0, 24, 24);
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const len = 50.0;
    canvas.drawArc(rect, pi, pi / 2, false, paint);
    canvas.drawLine(const Offset(0, 12), const Offset(0, len), paint);
    canvas.drawLine(const Offset(12, 0), const Offset(len, 0), paint);
    canvas.drawArc(rect.translate(_w - 24, 0), 3 * pi / 2, pi / 2, false, paint);
    canvas.drawLine(Offset(_w, 12), Offset(_w, len), paint);
    canvas.drawLine(Offset(_w - len, 0), Offset(_w - 12, 0), paint);
    canvas.drawArc(rect.translate(0, _w - 24), pi / 2, pi / 2, false, paint);
    canvas.drawLine(Offset(12, _w), Offset(len, _w), paint);
    canvas.drawLine(Offset(0, _w - len), Offset(0, _w - 12), paint);
    canvas.drawArc(rect.translate(_w - 24, _w - 24), 0, pi / 2, false, paint);
    canvas.drawLine(Offset(_w - len, _w), Offset(_w - 12, _w), paint);
    canvas.drawLine(Offset(_w, _w - len), Offset(_w, _w - 12), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
