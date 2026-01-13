import 'dart:async';
import 'package:flutter/widgets.dart';
import 'native_tabbar_dim_controller.dart';

class NativeTabBarDimObserver extends NavigatorObserver {
  NativeTabBarDimObserver({this.fallbackBarrierColor = const Color(0x4D000000), this.blurSigma = 5.0});

  final Color fallbackBarrierColor;
  final double blurSigma;

  final List<_DimState> _stack = [];

  bool _isDimRoute(Route<dynamic>? r) {
    if (r == null) return false;
    if (r is PopupRoute) return true;

    final t = r.runtimeType.toString();
    return t.contains('ModalBottomSheet') || t.contains('CupertinoModalPopup') || t.contains('DialogRoute') || t.contains('RawDialogRoute');
  }

  _DimState _stateFor(Route<dynamic> r) {
    Color c = fallbackBarrierColor;

    if (r is PopupRoute) {
      c = r.barrierColor ?? fallbackBarrierColor;
    } else if (r is ModalRoute) {
      c = r.barrierColor ?? fallbackBarrierColor;
    }

    return _DimState(colorArgb: c.value, blurSigma: blurSigma);
  }

  void _sync() {
    final active = _stack.isNotEmpty;
    final state = active ? _stack.last : const _DimState(colorArgb: 0, blurSigma: 0);

    scheduleMicrotask(() async {
      await NativeTabBarDimController.instance.setDimmed(dimmed: active, colorArgb: state.colorArgb, blurSigma: state.blurSigma);
    });
  }

  void _push(Route<dynamic> r) {
    if (!_isDimRoute(r)) return;
    _stack.add(_stateFor(r));
  }

  void _pop(Route<dynamic> r) {
    if (!_isDimRoute(r)) return;
    if (_stack.isNotEmpty) _stack.removeLast();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _push(route);
    _sync();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _pop(route);
    _sync();
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _pop(route);
    _sync();
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _pop(oldRoute);
    if (newRoute != null) _push(newRoute);
    _sync();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

class _DimState {
  const _DimState({required this.colorArgb, required this.blurSigma});
  final int colorArgb;
  final double blurSigma;
}
