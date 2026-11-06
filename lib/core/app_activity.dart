import 'package:flutter/widgets.dart';

/// Apakah jendela aplikasi sedang aktif (fokus). Animasi hiasan (vinyl,
/// batang equalizer) dijeda saat tidak aktif supaya tidak membebani GPU/CPU
/// ketika Anda sedang memakai aplikasi lain.
class AppActivity with WidgetsBindingObserver {
  AppActivity._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final AppActivity instance = AppActivity._();

  final ValueNotifier<bool> active = ValueNotifier<bool>(true);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active.value = state == AppLifecycleState.resumed;
  }
}
