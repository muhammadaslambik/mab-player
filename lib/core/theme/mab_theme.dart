import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Token tambahan di luar ColorScheme (gradien, panel, backdrop, glow).
@immutable
class MabTokens extends ThemeExtension<MabTokens> {
  const MabTokens({
    this.gradient,
    required this.backdrop,
    required this.panel,
    required this.border,
    this.glow = false,
    this.light = false,
  });

  /// Gradien aksen (pelangi, dsb). null = pakai warna primary saja.
  final List<Color>? gradient;
  final List<Color> backdrop;
  final Color panel;
  final Color border;
  final bool glow;
  final bool light;

  static const fallback = MabTokens(
    backdrop: [Color(0xFF0B0B12), Color(0xFF0B0B12)],
    panel: Color(0xFF14141F),
    border: Color(0x14FFFFFF),
  );

  @override
  MabTokens copyWith({
    List<Color>? gradient,
    List<Color>? backdrop,
    Color? panel,
    Color? border,
    bool? glow,
    bool? light,
  }) =>
      MabTokens(
        gradient: gradient ?? this.gradient,
        backdrop: backdrop ?? this.backdrop,
        panel: panel ?? this.panel,
        border: border ?? this.border,
        glow: glow ?? this.glow,
        light: light ?? this.light,
      );

  @override
  MabTokens lerp(ThemeExtension<MabTokens>? other, double t) =>
      other is MabTokens ? (t < 0.5 ? this : other) : this;
}

extension MabContext on BuildContext {
  MabTokens get mab => Theme.of(this).extension<MabTokens>() ?? MabTokens.fallback;
}

/// Warna pada posisi [t] (0..1) di sepanjang gradien.
Color gradientAt(List<Color> g, double t) {
  if (g.length == 1) return g.first;
  final x = t.clamp(0.0, 1.0).toDouble() * (g.length - 1);
  final i = math.min(x.floor(), g.length - 2);
  return Color.lerp(g[i], g[i + 1], x - i)!;
}

class MabPalette {
  const MabPalette({
    required this.id,
    required this.name,
    required this.light,
    required this.bg,
    required this.surface,
    required this.surfaceHi,
    required this.primary,
    required this.secondary,
    required this.backdrop,
    this.gradient,
    this.glow = false,
    this.art = 'square',
    this.wave = 'bars',
  });

  final String id;
  final String name;
  final bool light;
  final Color bg;
  final Color surface;
  final Color surfaceHi;
  final Color primary;
  final Color secondary;
  final List<Color> backdrop;
  final List<Color>? gradient;
  final bool glow;

  /// Gaya cover & waveform yang dipasang saat tema dipilih.
  final String art;
  final String wave;
}

const mabPalettes = <MabPalette>[
  MabPalette(
    id: 'midnight',
    name: 'Midnight',
    light: false,
    bg: Color(0xFF0B0B12),
    surface: Color(0xFF14141F),
    surfaceHi: Color(0xFF1C1C2B),
    primary: Color(0xFF8B7BFF),
    secondary: Color(0xFF5EE1FF),
    backdrop: [Color(0xFF0B0B12), Color(0xFF130F26)],
    art: 'square',
    wave: 'bars',
  ),
  MabPalette(
    id: 'neon',
    name: 'Neon',
    light: false,
    bg: Color(0xFF05050A),
    surface: Color(0xFF0E0E18),
    surfaceHi: Color(0xFF171726),
    primary: Color(0xFF22E5FF),
    secondary: Color(0xFFFF3DDC),
    backdrop: [Color(0xFF05050A), Color(0xFF0D0820)],
    gradient: [
      Color(0xFFFF3DDC),
      Color(0xFF6C5CFF),
      Color(0xFF22E5FF),
      Color(0xFF7CFF6B),
      Color(0xFFFFD84D),
    ],
    glow: true,
    art: 'vinyl',
    wave: 'mirror',
  ),
  MabPalette(
    id: 'aurora',
    name: 'Aurora',
    light: false,
    bg: Color(0xFF0A0716),
    surface: Color(0xFF161029),
    surfaceHi: Color(0xFF21183B),
    primary: Color(0xFFB07CFF),
    secondary: Color(0xFF4FD8EB),
    backdrop: [Color(0xFF0A0716), Color(0xFF1B0F3A), Color(0xFF0B1B2E)],
    gradient: [Color(0xFFB07CFF), Color(0xFF4FD8EB)],
    glow: true,
    art: 'circle',
    wave: 'bars',
  ),
  MabPalette(
    id: 'tosca',
    name: 'Tosca',
    light: false,
    bg: Color(0xFF0C1114),
    surface: Color(0xFF141C21),
    surfaceHi: Color(0xFF1B262D),
    primary: Color(0xFF2EE6D0),
    secondary: Color(0xFF7A8CFF),
    backdrop: [Color(0xFF0C1114), Color(0xFF0F1A1E)],
    art: 'square',
    wave: 'line',
  ),
  MabPalette(
    id: 'pearl',
    name: 'Pearl',
    light: true,
    bg: Color(0xFFF4F6FB),
    surface: Color(0xFFFFFFFF),
    surfaceHi: Color(0xFFE9EDF7),
    primary: Color(0xFF2F5BEA),
    secondary: Color(0xFF7C5CFF),
    backdrop: [Color(0xFFF4F6FB), Color(0xFFE8EEFF)],
    gradient: [Color(0xFF2F5BEA), Color(0xFF7C5CFF)],
    art: 'square',
    wave: 'bars',
  ),
  MabPalette(
    id: 'prism',
    name: 'Prism',
    light: true,
    bg: Color(0xFFF7F4FF),
    surface: Color(0xFFFFFFFF),
    surfaceHi: Color(0xFFEFE9FF),
    primary: Color(0xFF9B3DFF),
    secondary: Color(0xFFFF4DA6),
    backdrop: [Color(0xFFF7F4FF), Color(0xFFFFF0F8), Color(0xFFEEF6FF)],
    gradient: [
      Color(0xFF9B3DFF),
      Color(0xFFFF4DA6),
      Color(0xFFFFA43D),
      Color(0xFF35D39A),
      Color(0xFF3D9BFF),
    ],
    glow: true,
    art: 'vinyl',
    wave: 'mirror',
  ),
];

MabPalette paletteFor(String id) =>
    mabPalettes.firstWhere((p) => p.id == id, orElse: () => mabPalettes.first);

final _cache = <String, ThemeData>{};

ThemeData themeFor(String id) {
  final p = paletteFor(id);
  return _cache.putIfAbsent(p.id, () => _build(p));
}

ThemeData _build(MabPalette p) {
  final onS = p.light ? const Color(0xFF14151F) : const Color(0xFFEDEDF7);
  final onP = p.light ? Colors.white : const Color(0xFF0B0B12);
  Color tint(Color c, int a) => Color.alphaBlend(c.withAlpha(a), p.surface);

  final cs = ColorScheme(
    brightness: p.light ? Brightness.light : Brightness.dark,
    primary: p.primary,
    onPrimary: onP,
    primaryContainer: tint(p.primary, 70),
    onPrimaryContainer: onS,
    secondary: p.secondary,
    onSecondary: onP,
    secondaryContainer: tint(p.secondary, 60),
    onSecondaryContainer: onS,
    error: const Color(0xFFFF5C7A),
    onError: Colors.white,
    surface: p.bg,
    onSurface: onS,
    onSurfaceVariant: onS.withAlpha(175),
    outline: onS.withAlpha(95),
    outlineVariant: onS.withAlpha(45),
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: p.bg,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surfaceHi,
    surfaceContainerHighest: p.surfaceHi,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: p.bg,
  );

  final tokens = MabTokens(
    gradient: p.gradient,
    backdrop: p.backdrop,
    panel: p.light ? p.surface.withAlpha(235) : p.surface.withAlpha(215),
    border: onS.withAlpha(p.light ? 28 : 22),
    glow: p.glow,
    light: p.light,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: onS, displayColor: onS),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: onS,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: tint(p.primary, 70),
      selectedIconTheme: IconThemeData(color: p.primary),
      unselectedIconTheme: IconThemeData(color: onS.withAlpha(175)),
      selectedLabelTextStyle:
          TextStyle(color: p.primary, fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelTextStyle: TextStyle(color: onS.withAlpha(175), fontSize: 12),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: tint(p.primary, 70),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.surfaceHi,
      contentTextStyle: TextStyle(color: onS),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14))),
    ),
    dividerTheme: DividerThemeData(color: onS.withAlpha(26), space: 1, thickness: 1),
    sliderTheme: SliderThemeData(
      trackHeight: 3,
      activeTrackColor: p.primary,
      inactiveTrackColor: onS.withAlpha(45),
      thumbColor: p.primary,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: SliderComponentShape.noOverlay,
    ),
    extensions: [tokens],
  );
}
