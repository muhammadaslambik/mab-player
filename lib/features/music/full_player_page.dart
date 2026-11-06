import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/themed_scope.dart';
import '../../providers.dart';
import '../settings/appearance_sheet.dart';
import 'accent_scope.dart';
import 'now_playing.dart';

/// Buka pemutar penuh dengan transisi geser-naik + pudar.
void openFullPlayer(BuildContext context) {
  Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, _, _) => const FullPlayerPage(),
    transitionsBuilder: (_, anim, _, child) {
      final curved = anim.drive(CurveTween(curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: curved.drive(Tween(begin: const Offset(0, 0.06), end: Offset.zero)),
          child: child,
        ),
      );
    },
  ));
}

/// Pemutar penuh, dibuka dengan mengetuk MiniPlayer.
class FullPlayerPage extends ConsumerWidget {
  const FullPlayerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(audioHandlerProvider);
    return ThemedScope(
      child: Backdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            centerTitle: true,
            title: const Text('Sedang diputar', style: TextStyle(fontSize: 14)),
            leading: IconButton(
              tooltip: 'Tutup',
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              Builder(
                builder: (ctx) => IconButton(
                  tooltip: 'Tampilan',
                  icon: const Icon(Icons.palette_outlined),
                  onPressed: () => showAppearanceSheet(ctx),
                ),
              ),
            ],
          ),
          body: AccentScope(
            handler: h,
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: NowPlaying(handler: h, big: true),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
