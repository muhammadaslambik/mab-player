import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/settings_provider.dart';
import 'mab_theme.dart';

/// Memasang tema pilihan pengguna di bawahnya (dengan transisi halus).
/// Dipakai di HomeShell dan halaman yang di-push (pemutar penuh, playlist).
class ThemedScope extends ConsumerWidget {
  const ThemedScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(appSettingsProvider.select((s) => s.theme));
    return AnimatedTheme(
      data: themeFor(id),
      duration: const Duration(milliseconds: 350),
      child: child,
    );
  }
}

/// Latar gradien statis (murah) di belakang halaman.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.mab.backdrop;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.length > 1 ? colors : [colors.first, colors.first],
        ),
      ),
      child: child,
    );
  }
}
