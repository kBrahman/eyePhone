
import '../cubit/mon_cubit.dart';
import '../util/util.dart';

extension StrExt on String {
  MonStatus toMonStatus() => this == DISCONNECTED
      ? MonStatus.disconnected
      : this == OFFLINE
          ? MonStatus.offline
          : MonStatus.turned_off;
}
