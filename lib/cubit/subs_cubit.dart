// ignore_for_file: constant_identifier_names
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../repo/app_repo.dart';
import '../util/util.dart';

class SubsCubit extends Cubit<PremiumState> {
  static const _TAG = 'PremiumCubit';
  final AppRepo _repo;

  SubsCubit(this._repo) : super(const PremiumState());

  bool isPremium() => _repo.getBoolFromSp(IS_PREMIUM) ?? false;

  upgrade() {
    if (state.loading) return;
    emit(state.copyWith(loading: true));
    InAppPurchase.instance.isAvailable().then((v) {
      appLog(_TAG, 'store avail:$v');
      if (!v) emit(state.copyWith(storeAvailable: false));
    });
  }
}

class PremiumState {
  final bool storeAvailable;

  final bool loading;

  const PremiumState({this.storeAvailable = true, this.loading = false});

  PremiumState copyWith({bool? storeAvailable, bool? loading}) =>
      PremiumState(storeAvailable: storeAvailable ?? this.storeAvailable, loading: loading ?? false);
}
