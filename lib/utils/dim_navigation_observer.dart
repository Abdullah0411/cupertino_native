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
    if (r is PopupRoute) return true;
    final t = r.runtimeType.toString();
    return t.contains('ModalBottomSheet') || t.contains('CupertinoModalPopup') || t.contains('DialogRoute');
  }

  void _handleAnimation(Route route) {
    if (route is ModalRoute) {
      final progress = route.animation?.value ?? 0.0;
      final isVisible = progress > 0.001; // Avoid jitter at zero

      final color = route.barrierColor ?? fallbackBarrierColor;

      NativeTabBarDimController.instance.setDimmed(dimmed: isVisible, colorArgb: color.value, blurSigma: blurSigma * progress);
    }
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    if (_isDimRoute(route) && route is ModalRoute) {
      final listener = () => _handleAnimation(route);
      _listeners[route] = listener;
      route.animation?.addListener(listener);
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    final listener = _listeners.remove(route);
    if (listener != null && route is ModalRoute) {
      // Ensure it continues to sync while animating out
      route.animation?.removeListener(listener);
      // Final sync to clean up
      if (previousRoute == null || !_isDimRoute(previousRoute)) {
        NativeTabBarDimController.instance.setDimmed(dimmed: false, colorArgb: 0, blurSigma: 0);
      }
    }
  }
}
