import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/mab_theme.dart';
import 'settings_provider.dart';

Future<void> showAppearanceSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 620),
      builder: (_) => const _AppearanceSheet(),
    );

class _AppearanceSheet extends ConsumerWidget {
  const _AppearanceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appSettingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final label = Theme.of(context).textTheme.titleSmall;

    Widget choices(String title, Map<String, String> opts, String value,
            ValueChanged<String> onPick) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 18),
          Text(title, style: label),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in opts.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: e.key == value,
                onSelected: (_) => onPick(e.key),
              ),
          ]),
        ]);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tampilan', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          Text('Tema', style: label),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final p in mabPalettes)
              _ThemeTile(
                palette: p,
                selected: p.id == s.theme,
                onTap: () => n.pickTheme(p.id),
              ),
          ]),
          choices(
            'Tata letak musik',
            const {
              'auto': 'Otomatis',
              'split': 'Split',
              'stage': 'Stage',
              'compact': 'Compact',
            },
            s.layout,
            (v) => n.save(s.copyWith(layout: v)),
          ),
          choices(
            'Gaya cover',
            const {'square': 'Persegi', 'circle': 'Bulat', 'vinyl': 'Vinyl'},
            s.art,
            (v) => n.save(s.copyWith(art: v)),
          ),
          choices(
            'Gaya waveform',
            const {'bars': 'Batang', 'mirror': 'Cermin', 'line': 'Garis'},
            s.wave,
            (v) => n.save(s.copyWith(wave: v)),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Animasi'),
            subtitle: const Text('Matikan untuk menghemat CPU/baterai'),
            value: s.anim,
            onChanged: (v) => n.save(s.copyWith(anim: v)),
          ),
        ]),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.palette, required this.selected, required this.onTap});
  final MabPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final fg = p.light ? const Color(0xFF14151F) : const Color(0xFFEDEDF7);
    final bar = p.gradient ?? [p.primary, p.secondary];
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 116,
        height: 78,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: p.backdrop.length > 1 ? p.backdrop : [p.bg, p.bg],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? p.primary : fg.withAlpha(40),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(colors: bar.length > 1 ? bar : [bar.first, bar.first]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 16, color: selected ? p.primary : fg.withAlpha(90)),
          ]),
          const Spacer(),
          Text(p.name,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }
}
