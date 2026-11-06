import 'package:flutter/material.dart';

import '../../services/audio_handler.dart';

/// Mewarnai aksen (tombol, lagu aktif) mengikuti cover lagu.
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
        final light = t.brightness == Brightness.light;
        var color = c;
        if (color != null && light) {
          color = HSLColor.fromColor(color).withLightness(0.42).toColor();
        }
        return Theme(
          data: color == null
              ? t
              : t.copyWith(
                  colorScheme: t.colorScheme.copyWith(
                    primary: color,
                    onPrimary: light ? Colors.white : const Color(0xFF111114),
                  ),
                ),
          child: ch!,
        );
      },
    );
  }
}
