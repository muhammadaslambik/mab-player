import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform.dart';
import '../../core/theme/mab_theme.dart';
import '../../providers.dart';

class AppSettings {
  const AppSettings({
    this.theme = 'midnight',
    this.layout = 'auto',
    this.art = 'square',
    this.wave = 'bars',
    this.anim = true,
  });

  final String theme; // id palet
  final String layout; // auto | split | stage | compact
  final String art; // square | vinyl | circle
  final String wave; // bars | mirror | line
  final bool anim;

  AppSettings copyWith({String? theme, String? layout, String? art, String? wave, bool? anim}) =>
      AppSettings(
        theme: theme ?? this.theme,
        layout: layout ?? this.layout,
        art: art ?? this.art,
        wave: wave ?? this.wave,
        anim: anim ?? this.anim,
      );

  Map<String, dynamic> toJson() =>
      {'theme': theme, 'layout': layout, 'art': art, 'wave': wave, 'anim': anim};

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    String s(Object? v, String d) => v is String ? v : d;
    return AppSettings(
      theme: s(j['theme'], 'midnight'),
      layout: s(j['layout'], 'auto'),
      art: s(j['art'], 'square'),
      wave: s(j['wave'], 'bars'),
      anim: j['anim'] is bool ? j['anim'] as bool : true,
    );
  }
}

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final raw = await ref.read(storeProvider).read('settings');
    if (raw is Map) return AppSettings.fromJson(Map<String, dynamic>.from(raw));
    return const AppSettings();
  }

  Future<void> save(AppSettings s) async {
    state = AsyncData(s);
    await ref.read(storeProvider).write('settings', s.toJson());
  }

  /// Memilih tema juga memasang gaya cover & waveform bawaan tema itu.
  Future<void> pickTheme(String id) {
    final p = paletteFor(id);
    final cur = state.value ?? const AppSettings();
    return save(cur.copyWith(theme: p.id, art: p.art, wave: p.wave));
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// Nilai sinkron (bawaan selama pengaturan belum terbaca).
final appSettingsProvider =
    Provider<AppSettings>((ref) => ref.watch(settingsProvider).value ?? const AppSettings());

/// Mode tata letak halaman musik: 'split' | 'stage' | 'compact'.
/// Ponsel selalu 'compact' (daftar + kartu mini); desktop/tablet memilih
/// sesuai pengaturan bila ruangnya cukup.
String resolveLayout(String setting, double width, FormFactor ff) {
  if (ff == FormFactor.phone || width < 820) return 'compact';
  return setting == 'auto' ? 'split' : setting;
}
