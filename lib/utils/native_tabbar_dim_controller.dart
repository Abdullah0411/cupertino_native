import 'package:flutter/services.dart';

class NativeTabBarDimController {
  NativeTabBarDimController._();
  static final instance = NativeTabBarDimController._();

  MethodChannel? _channel;

  void attach(MethodChannel channel) {
    _channel = channel;
  }

  void detach(MethodChannel channel) {
    if (_channel == channel) _channel = null;
  }

  Future<void> setDimmed(bool dimmed, {double opacity = 0.45}) async {
    final ch = _channel;
    if (ch == null) return;
    try {
      await ch.invokeMethod('setModalDimmed', {'dimmed': dimmed, 'opacity': opacity});
    } catch (_) {}
  }
}
