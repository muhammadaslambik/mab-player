import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform.dart';
import '../../core/theme/mab_theme.dart';
import '../../core/theme/themed_scope.dart';
import '../../providers.dart';
import '../../services/audio_handler.dart';
import '../settings/appearance_sheet.dart';
import 'accent_scope.dart';
import 'lyrics_panel.dart';
import 'now_playing.dart';
import 'queue_panel.dart';

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

/// Pemutar penuh. Ponsel: satu kolom (lirik/antrean lewat tombol). Desktop
/// atau tablet lebar: dua kolom, pemutar di kiri dan panel Lirik/Antrean di kanan.
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
            child: LayoutBuilder(builder: (context, box) {
              final wide = formFactorOf(context) != FormFactor.phone && box.maxWidth >= 900;
              // Cover mengecil di jendela pendek supaya kontrol tidak terpotong.
              final artSize = math.min(340.0, math.max(170.0, box.maxHeight - 360));
              final player = Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: NowPlaying(handler: h, big: true, artSize: artSize),
                  ),
                ),
              );
              if (!wide) return player;
              return Row(children: [
                Expanded(child: player),
                SizedBox(width: 400, child: _SidePanel(handler: h)),
              ]);
            }),
          ),
        ),
      ),
    );
  }
}

class _SidePanel extends StatefulWidget {
  const _SidePanel({required this.handler});
  final MabAudioHandler handler;

  @override
  State<_SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<_SidePanel> {
  late bool _lyrics = !widget.handler.lyrics.value.isEmpty;

  @override
  Widget build(BuildContext context) {
    final tk = context.mab;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tk.panel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: tk.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                ChoiceChip(
                  label: const Text('Lirik'),
                  selected: _lyrics,
                  onSelected: (_) => setState(() => _lyrics = true),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Antrean'),
                  selected: !_lyrics,
                  onSelected: (_) => setState(() => _lyrics = false),
                ),
              ]),
            ),
            Expanded(
              child: _lyrics
                  ? LyricsList(handler: widget.handler)
                  : QueueList(handler: widget.handler),
            ),
          ]),
        ),
      ),
    );
  }
}
