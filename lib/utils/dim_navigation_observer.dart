import 'dart:async';
import 'package:flutter/widgets.dart';
import 'native_tabbar_dim_controller.dart';

class NativeTabBarDimObserver extends NavigatorObserver {
  NativeTabBarDimObserver({this.fallbackBarrierColor = const Color(0x4D000000), this.blurSigma = 5.0});

  final Color fallbackBarrierColor;
  final double blurSigma;
  final Map<Route, VoidCallback> _listeners = {};

  bool _isDimRoute(Route<dynamic>? r) {
    if (r == null) return false;
    final t = r.runtimeType.toString();
    return r is PopupRoute || t.contains('ModalBottomSheet') || t.contains('CupertinoModalPopup') || t.contains('DialogRoute');
  }

  void _sync(Route route) {
    if (route is ModalRoute) {
      final progress = route.animation?.value ?? 0.0;
      // We only send 'dimmed: true' if the animation has actually started
      final isVisible = progress > 0.01;
      final color = route.barrierColor ?? fallbackBarrierColor;

      NativeTabBarDimController.instance.setDimmed(
        dimmed: isVisible,
        colorArgb: color.toARGB32(),
        blurSigma: blurSigma * progress, // Sync blur intensity to animation
      );
    }
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    if (_isDimRoute(route) && route is ModalRoute) {
      final listener = () => _sync(route);
      _listeners[route] = listener;
      route.animation?.addListener(listener);
    }
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    final listener = _listeners.remove(route);
    if (listener != null && route is ModalRoute) {
      route.animation?.removeListener(listener);
      // Ensure we clear the dim if we are returning to a non-dimmed screen
      if (previousRoute == null || !_isDimRoute(previousRoute)) {
        NativeTabBarDimController.instance.setDimmed(dimmed: false, colorArgb: 0, blurSigma: 0);
      }
    }
    super.didPop(route, previousRoute);
  }
}
