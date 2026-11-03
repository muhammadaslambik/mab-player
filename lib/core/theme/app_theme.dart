import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C5CFF),
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0B0B10),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFF111118),
        indicatorColor: Color(0x337C5CFF),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFF111118),
      ),
    );
  }
}
