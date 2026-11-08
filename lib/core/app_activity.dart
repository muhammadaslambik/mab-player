import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Apakah jendela aplikasi sedang aktif (fokus & tidak diminimalkan). Animasi
/// hiasan (vinyl, batang equalizer) dijeda saat tidak aktif supaya tidak
/// membebani GPU/CPU ketika Anda memakai aplikasi lain.
/// Desktop memakai event fokus window_manager; ponsel memakai lifecycle Flutter.
class AppActivity with WidgetsBindingObserver {
  AppActivity._() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(_WinFocus(this));
    } else {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  static final AppActivity instance = AppActivity._();

  final ValueNotifier<bool> active = ValueNotifier<bool>(true);

  /// Untuk pengujian: MAB_ALWAYS_ACTIVE=1 membuat animasi tetap berjalan walau
  /// jendela tidak fokus (supaya beban bisa diukur tanpa harus menjaga fokus).
  static final bool _forceActive = Platform.environment['MAB_ALWAYS_ACTIVE'] == '1';

  void _set(bool v) {
    if (_forceActive) return;
    if (active.value != v) active.value = v;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _set(state == AppLifecycleState.resumed);
}

class _WinFocus with WindowListener {
  _WinFocus(this._a);
  final AppActivity _a;

  @override
  void onWindowFocus() => _a._set(true);
  @override
  void onWindowBlur() => _a._set(false);
  @override
  void onWindowMinimize() => _a._set(false);
  @override
  void onWindowRestore() => _a._set(true);
}
