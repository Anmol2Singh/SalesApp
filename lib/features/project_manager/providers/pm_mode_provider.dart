import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PmRecordMode {
  sales,
  purchase;

  bool get isSales => this == PmRecordMode.sales;
  bool get isPurchase => this == PmRecordMode.purchase;
}

class PmRecordModeNotifier extends StateNotifier<PmRecordMode> {
  PmRecordModeNotifier() : super(PmRecordMode.sales);

  void setMode(PmRecordMode mode) {
    state = mode;
  }

  void toggle() {
    state = state == PmRecordMode.sales ? PmRecordMode.purchase : PmRecordMode.sales;
  }
}

final pmRecordModeProvider = StateNotifierProvider<PmRecordModeNotifier, PmRecordMode>((ref) {
  return PmRecordModeNotifier();
});
