import 'package:flutter/services.dart';

class NativeTabBarDimController {
  NativeTabBarDimController._();
  static final instance = NativeTabBarDimController._();

  MethodChannel? _channel;

  void attach(MethodChannel channel) => _channel = channel;

  void detach(MethodChannel channel) {
    if (_channel == channel) _channel = null;
  }

  Future<void> setDimmed({required bool dimmed, required int colorArgb, required double blurSigma}) async {
    final ch = _channel;
    if (ch == null) return;
    try {
      await ch.invokeMethod('setModalDimmed', {'dimmed': dimmed, 'color': colorArgb, 'blurSigma': blurSigma});
    } catch (_) {}
  }
}
