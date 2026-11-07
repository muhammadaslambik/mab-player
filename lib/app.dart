import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/mab_theme.dart';
import 'features/home/home_shell.dart';
import 'features/settings/settings_provider.dart';

class MabApp extends ConsumerWidget {
  const MabApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tema pilihan pengguna dipasang di MaterialApp, sehingga semua halaman
    // (folder, video, dialog) ikut tema yang sama.
    final id = ref.watch(appSettingsProvider.select((s) => s.theme));
    final data = themeFor(id);
    return MaterialApp(
      title: 'MAB-Player',
      debugShowCheckedModeBanner: false,
      theme: data,
      darkTheme: data,
      themeMode: ThemeMode.dark,
      home: const HomeShell(),
    );
  }
}
