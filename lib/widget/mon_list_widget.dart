// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:math';

import 'package:eye_phone/bloc/app/app_bloc.dart';
import 'package:eye_phone/util.dart';
import 'package:eye_phone/widget/mon_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../bloc/app/app_event.dart';
import 'mon_item_widget.dart';

class MonListWidget extends StatelessWidget {
  static const _TAG = 'MonListWidget';
  final AppData _data;
  final AppBloc _bloc;

  const MonListWidget(this._data, this._bloc, {super.key});

  @override
  Widget build(BuildContext context) {
    _bloc.ctr.add(const StopTimer(true));
    final w = MediaQuery.of(context).size.width;
    appLog(_TAG, 'build, w:$w');
    return Scaffold(
        floatingActionButton: FloatingActionButton(
            onPressed: () => showModalBottomSheet(
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
                                onPressed: () => Navigator.pop(ctx),
                                icon: const Icon(Icons.close, color: Colors.deepPurple))
                          ]),
                      body: MobileScanner(
                          onDetect: (cap) {
                            if (detected) return;
                            detected = true;
                            Navigator.of(context).pop();
                            final id = cap.barcodes.single.rawValue;
                            appLog(_TAG, 'on detect, id:$id');
                            _bloc.ctr.add(AddCam(id: id!));
                          },
                          overlay: CustomPaint(size: const Size.square(250), painter: LineWithRadiusPainter(250))));
                }),
            child: const Icon(Icons.qr_code)),
        appBar: AppBar(title: const Text('Monitors')),
        body: _data.state == CamState.generating
            ? const Center(child: CircularProgressIndicator())
            : GridView.builder(
                itemCount: _data.mons.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _getAxisCount(w)),
                itemBuilder: (ctx, i) {
                  var lastProg = .0;
                  appLog(_TAG, 'item builder');
                  return Dismissible(
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
                                        TextButton(
                                            onPressed: () => Navigator.of(c).pop(true), child: const Text('YES')),
                                        TextButton(
                                            onPressed: () => Navigator.of(c).pop(false), child: const Text('NO'))
                                      ])).then((value) {
                            if (value) _bloc.ctr.add(DeleteMon(i));
                            return value;
                          }),
                      background: const Align(
                          alignment: Alignment.centerLeft,
                          child:
                              Padding(padding: EdgeInsets.only(left: 9), child: Icon(Icons.delete, color: Colors.red))),
                      onDismissed: (dir) => _bloc.ctr.add(DeleteMon(i)),
                      key: ValueKey(i),
                      child: GestureDetector(
                          onTap: () => Navigator.of(ctx)
                              .push(MaterialPageRoute(builder: (c) => Hero(tag: i, child: MonWidget(_data.mons[i])))),
                          child: Hero(tag: i, child: MonItemWidget(_data.mons[i]))));
                }));
  }

  int _getAxisCount(double w) => w < 768 ? 2 : 3;
}

class LineWithRadiusPainter extends CustomPainter {
  final double _w;

  LineWithRadiusPainter(this._w);

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
