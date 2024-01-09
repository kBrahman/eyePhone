// ignore_for_file: constant_identifier_names,

import 'dart:async';
import 'package:app_links/app_links.dart';
import '../bloc/app/app_event.dart';
import '../util.dart';

class DeepLinkManager {
  static const _TAG = 'DeepLinkManager';
  late var ctr = StreamController();
  var initialized = false;

  void init(StreamController<AppEvent> ctr) {
    if (initialized) return;
    initialized = true;
    AppLinks().allUriLinkStream.listen((uri) {
      final id = uri.queryParameters[CAM_ID];
      appLog(_TAG, 'id from app link:$id');
      if (id != null) ctr.add(AddCam(id: id, andOpen: true));
    });
  }
}
