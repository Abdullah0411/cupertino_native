import 'dart:async';
import 'package:cupertino_native/utils/native_tabbar_dim_controller.dart';
import 'package:flutter/widgets.dart';

class NativeTabBarDimObserver extends NavigatorObserver {
  NativeTabBarDimObserver({this.fallbackBarrierColor = const Color(0x4D000000)});

  final Color fallbackBarrierColor;
  final Map<Route, VoidCallback> _listeners = {};

  bool _isDimRoute(Route<dynamic>? r) {
    if (r == null) return false;
    final t = r.runtimeType.toString();
    return r is PopupRoute || t.contains('ModalBottomSheet') || t.contains('CupertinoModalPopup') || t.contains('DialogRoute');
  }

  void _sync(Route route) {
    if (route is! ModalRoute) return;
    final p = route.animation?.value ?? 0.0;
    final color = route.barrierColor ?? fallbackBarrierColor;

    // Only show cover after animation started a bit (prevents flicker)
    final visibleP = p > 0.01 ? p : 0.0;

    NativeTabBarCoverController.instance.set(progressValue: visibleP, color: color);
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    if (_isDimRoute(route) && route is ModalRoute) {
      final listener = () => _sync(route);
      _listeners[route] = listener;
      route.animation?.addListener(listener);

      // Sync immediately too (some routes start with value > 0)
      scheduleMicrotask(() => _sync(route));
    }
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    final listener = _listeners.remove(route);
    if (listener != null && route is ModalRoute) {
      route.animation?.removeListener(listener);

      // If we popped a dim route, re-evaluate based on what's underneath.
      if (previousRoute != null && _isDimRoute(previousRoute)) {
        scheduleMicrotask(() => _sync(previousRoute));
      } else {
        NativeTabBarCoverController.instance.clear();
      }
    }
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    // Covers dismiss via system / replace sometimes
    final listener = _listeners.remove(route);
    if (listener != null && route is ModalRoute) {
      route.animation?.removeListener(listener);
      if (previousRoute != null && _isDimRoute(previousRoute)) {
        scheduleMicrotask(() => _sync(previousRoute));
      } else {
        NativeTabBarCoverController.instance.clear();
      }
    }
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (oldRoute != null) {
      final listener = _listeners.remove(oldRoute);
      if (listener != null && oldRoute is ModalRoute) oldRoute.animation?.removeListener(listener);
    }
    if (newRoute != null) didPush(newRoute, null);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
