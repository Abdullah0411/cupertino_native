import 'package:flutter/widgets.dart';

class NativeTabBarCoverController {
  NativeTabBarCoverController._();
  static final instance = NativeTabBarCoverController._();

  /// 0..1 (route transition progress)
  final ValueNotifier<double> progress = ValueNotifier<double>(0.0);

  /// If you want to also sync the barrier color:
  final ValueNotifier<Color> barrierColor = ValueNotifier<Color>(const Color(0x00000000));

  void set({required double progressValue, required Color color}) {
    progress.value = progressValue.clamp(0.0, 1.0);
    barrierColor.value = color;
  }

  void clear() => set(progressValue: 0.0, color: const Color(0x00000000));
}
