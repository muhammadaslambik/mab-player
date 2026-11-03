import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/library_screen.dart';
import '../music/mini_player.dart';
import '../music/music_screen.dart';
import '../video/video_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _dests = [
    (Icons.library_music_rounded, 'Music'),
    (Icons.video_library_rounded, 'Video'),
    (Icons.folder_rounded, 'Library'),
  ];

  // Hanya tab aktif yang dibangun -> hemat RAM.
  Widget get _page => switch (_index) {
        0 => const MusicScreen(),
        1 => const VideoScreen(),
        _ => const LibraryScreen(),
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 800;
      return Scaffold(
        body: SafeArea(
          child: Row(children: [
            if (wide)
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final d in _dests)
                    NavigationRailDestination(icon: Icon(d.$1), label: Text(d.$2)),
                ],
              ),
            Expanded(
              child: Column(children: [
                Expanded(child: _page),
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
    });
  }
}
