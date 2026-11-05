import 'package:flutter/material.dart';

import '../../services/audio_handler.dart';

/// Mewarnai aksen (tombol, waveform, lagu aktif) mengikuti cover lagu.
/// Struktur widget selalu sama agar state di bawahnya tidak hilang.
class AccentScope extends StatelessWidget {
  const AccentScope({super.key, required this.handler, required this.child});
  final MabAudioHandler handler;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color?>(
      valueListenable: handler.accent,
      child: child,
      builder: (context, c, ch) {
        final t = Theme.of(context);
        return Theme(
          data: c == null
              ? t
              : t.copyWith(
                  colorScheme: t.colorScheme
                      .copyWith(primary: c, onPrimary: const Color(0xFF111114))),
          child: ch!,
        );
      },
    );
  }
}
