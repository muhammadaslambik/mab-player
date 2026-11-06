import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding/mab_logo.dart';
import '../../core/platform.dart';
import '../../core/theme/themed_scope.dart';
import '../../providers.dart';
import '../../services/playback_memory.dart';
import '../library/library_screen.dart';
import '../music/mini_player.dart';
import '../music/music_screen.dart';
import '../settings/appearance_sheet.dart';
import '../video/video_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  PlaybackMemory? _memory;

  static const _dests = [
    (Icons.library_music_rounded, 'Music'),
    (Icons.video_library_rounded, 'Video'),
    (Icons.folder_rounded, 'Library'),
  ];

  @override
  void initState() {
    super.initState();
    // Batasi cache gambar (hemat RAM; cover hanya satu per lagu aktif).
    PaintingBinding.instance.imageCache
      ..maximumSizeBytes = 24 << 20
      ..maximumSize = 60;
    // Pulihkan lagu & posisi terakhir (dalam keadaan jeda).
    _memory = PlaybackMemory(ref.read(audioHandlerProvider), ref.read(storeProvider))
      ..start();
  }

  @override
  void dispose() {
    _memory?.dispose();
    super.dispose();
  }

  // Hanya tab aktif yang dibangun -> hemat RAM.
  Widget get _page => switch (_index) {
        0 => const MusicScreen(),
        1 => const VideoScreen(),
        _ => const LibraryScreen(),
      };

  @override
  Widget build(BuildContext context) {
    return ThemedScope(
      child: Backdrop(
        child: LayoutBuilder(builder: (context, box) {
          // Navigasi mengikuti platform: ponsel = bar bawah, desktop/tablet = rail samping.
          final wide = formFactorOf(context) != FormFactor.phone;
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Row(children: [
                if (wide)
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: (i) => setState(() => _index = i),
                    labelType: NavigationRailLabelType.all,
                    leading: const Padding(
                      padding: EdgeInsets.only(top: 12, bottom: 16),
                      child: _Logo(),
                    ),
                    trailing: Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Builder(
                            builder: (ctx) => IconButton(
                              tooltip: 'Tampilan',
                              icon: const Icon(Icons.palette_outlined),
                              onPressed: () => showAppearanceSheet(ctx),
                            ),
                          ),
                        ),
                      ),
                    ),
                    destinations: [
                      for (final d in _dests)
                        NavigationRailDestination(icon: Icon(d.$1), label: Text(d.$2)),
                    ],
                  ),
                Expanded(
                  child: Column(children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        layoutBuilder: (current, previous) => Stack(
                          fit: StackFit.expand,
                          children: [...previous, ?current],
                        ),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, 0.02), end: Offset.zero)
                                .animate(anim),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(key: ValueKey(_index), child: _page),
                      ),
                    ),
                    if (_index != 0) const MiniPlayer(),
                  ]),
                ),
              ]),
            ),
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: (i) => setState(() => _index = i),
                    destinations: [
                      for (final d in _dests)
                        NavigationDestination(icon: Icon(d.$1), label: d.$2),
                    ],
                  ),
          );
        }),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => const MabLogo(size: 40);
}
