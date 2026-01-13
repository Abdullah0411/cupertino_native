import 'dart:async';
import 'package:flutter/widgets.dart';
import 'native_tabbar_dim_controller.dart';

class NativeTabBarDimObserver extends NavigatorObserver {
  NativeTabBarDimObserver({
    this.fallbackBarrierColor = const Color(0x8A000000), // black54-ish
  });

  final Color fallbackBarrierColor;

  final List<int> _barrierStack = []; // ARGB ints

  bool _isDimRoute(Route<dynamic>? r) {
    if (r == null) return false;
    if (r is PopupRoute) return true;

    final t = r.runtimeType.toString();
    return t.contains('ModalBottomSheet') || t.contains('CupertinoModalPopup') || t.contains('DialogRoute') || t.contains('RawDialogRoute');
  }

  int _barrierArgbFor(Route<dynamic> r) {
    if (r is PopupRoute) {
      final c = r.barrierColor ?? fallbackBarrierColor;
      return c.value; // ARGB
    }
    if (r is ModalRoute) {
      final c = r.barrierColor ?? fallbackBarrierColor;
      return c.value;
    }
    return fallbackBarrierColor.value;
  }

  Future<void> _sync() async {
    final dimmed = _barrierStack.isNotEmpty;
    final color = dimmed ? _barrierStack.last : 0;

    scheduleMicrotask(() async {
      await NativeTabBarDimController.instance.setDimmedWithColor(dimmed, color);
    });
  }

  void _pushIfNeeded(Route<dynamic> r) {
    if (!_isDimRoute(r)) return;
    _barrierStack.add(_barrierArgbFor(r));
  }

  void _popIfNeeded(Route<dynamic> r) {
    if (!_isDimRoute(r)) return;
    if (_barrierStack.isNotEmpty) _barrierStack.removeLast();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _pushIfNeeded(route);
    _sync();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _popIfNeeded(route);
    _sync();
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _popIfNeeded(route);
    _sync();
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _popIfNeeded(oldRoute);
    if (newRoute != null) _pushIfNeeded(newRoute);
    _sync();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
