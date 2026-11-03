import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_shell.dart';

class MabApp extends StatelessWidget {
  const MabApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MAB-Player',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const HomeShell(),
      );
}
