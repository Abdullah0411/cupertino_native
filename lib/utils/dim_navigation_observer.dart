import 'dart:async';
import 'package:flutter/widgets.dart';
import 'native_tabbar_dim_controller.dart';

class NativeTabBarDimObserver extends NavigatorObserver {
  NativeTabBarDimObserver({this.opacity = 0.45, this.debugLogs = false});

  final double opacity;
  final bool debugLogs;

  int _modalDepth = 0;
  bool _lastDimmed = false;

  bool _isDimRoute(Route<dynamic>? route) {
    if (route == null) return false;

    // Dialogs, cupertino modal popups, menus, etc.
    if (route is PopupRoute) return true;

    // Bottom sheets & some custom modal routes
    final t = route.runtimeType.toString();
    return t.contains('ModalBottomSheet') || t.contains('CupertinoModalPopup') || t.contains('DialogRoute') || t.contains('RawDialogRoute');
  }

  void _sync() {
    final dim = _modalDepth > 0;
    if (_lastDimmed == dim) return;
    _lastDimmed = dim;

    scheduleMicrotask(() async {
      if (debugLogs) {
        // ignore: avoid_print
        print('[NativeTabBarDimObserver] dim=$dim depth=$_modalDepth');
      }
      await NativeTabBarDimController.instance.setDimmed(dim, opacity: opacity);
    });
  }

  void _incIfNeeded(Route<dynamic>? route) {
    if (_isDimRoute(route)) _modalDepth++;
  }

  void _decIfNeeded(Route<dynamic>? route) {
    if (_isDimRoute(route)) {
      _modalDepth = (_modalDepth - 1).clamp(0, 1 << 30);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _incIfNeeded(route);
    _sync();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _decIfNeeded(route);
    _sync();
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _decIfNeeded(route);
    _sync();
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _decIfNeeded(oldRoute);
    _incIfNeeded(newRoute);
    _sync();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
