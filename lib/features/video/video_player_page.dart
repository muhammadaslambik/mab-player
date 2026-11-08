import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/utils/format.dart';
import '../../data/models/media_entry.dart';
import '../../data/repositories/history_repo.dart';
import '../../providers.dart';

String? _hwdecOverride() {
  final v = Platform.environment['MAB_HWDEC'];
  return (v == null || v.isEmpty) ? null : v;
}

enum AspectMode {
  fit('Fit', BoxFit.contain, null),
  fill('Fill', BoxFit.cover, null),
  wide('16:9', BoxFit.contain, 16 / 9),
  classic('4:3', BoxFit.contain, 4 / 3),
  stretch('Stretch', BoxFit.fill, null);

  const AspectMode(this.label, this.boxFit, this.ratio);
  final String label;
  final BoxFit boxFit;
  final double? ratio;
}

class VideoPlayerPage extends ConsumerStatefulWidget {
  const VideoPlayerPage({super.key, required this.entry, this.startAt});
  final MediaEntry entry;
  final Duration? startAt;

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage> {
  late final Player _player;
  late final VideoController _controller;
  late final HistoryRepo _history;

  Timer? _hideTimer;
  DateTime _lastPoke = DateTime.fromMillisecondsSinceEpoch(0);
  bool _show = true;
  double _speed = 1.0;
  AspectMode _aspect = AspectMode.fit;

  bool get _mobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _history = ref.read(historyProvider);
    ref.read(audioHandlerProvider).pause(); // jangan putar musik di atas video

    // Player dibuat per halaman dan di-dispose saat keluar -> tidak bocor memori.
    _player = Player();
    unawaited(_tune());
    _controller = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: true,
        // Pengujian: MAB_HWDEC=d3d11va | d3d11va-copy | auto-safe | no
        // (kosong = bawaan media_kit).
        hwdec: _hwdecOverride(),
      ),
    );

    if (_mobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    WakelockPlus.enable();
    _open();
    _scheduleHide();
  }

  /// Batasi cache baca-ke-depan/belakang (cukup untuk file lokal; kualitas
  /// gambar dan suara tidak berubah, hanya memori yang lebih hemat).
  Future<void> _tune() async {
    try {
      final native = _player.platform as dynamic;
      await native.setProperty('demuxer-max-bytes', '24MiB');
      await native.setProperty('demuxer-max-back-bytes', '8MiB');
    } catch (_) {
      // Properti tidak tersedia: pakai bawaan.
    }
  }

  Future<void> _open() async {
    await _player.open(Media(widget.entry.path));
    try {
      final resume = widget.startAt ?? await _history.lastPosition(widget.entry.path);
      if (resume > const Duration(seconds: 5)) {
        await _player.stream.duration.firstWhere((d) => d > Duration.zero);
        await _player.seek(resume);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _history.record(widget.entry, _player.state.position);
    _player.dispose();
    WakelockPlus.disable();
    if (_mobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(const []);
    } else {
      windowManager.setFullScreen(false);
    }
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _player.state.playing) setState(() => _show = false);
    });
  }

  /// Dipanggil tiap gerak mouse: jadwal ulang auto-hide paling sering 4x/detik.
  void _poke() {
    if (!_show) setState(() => _show = true);
    final now = DateTime.now();
    if (now.difference(_lastPoke) > const Duration(milliseconds: 250)) {
      _lastPoke = now;
      _scheduleHide();
    }
  }

  void _seekBy(int seconds) {
    _player.seek(_player.state.position + Duration(seconds: seconds));
    _poke();
  }

  Future<void> _toggleFullscreen() async {
    if (_mobile) return;
    await windowManager.setFullScreen(!await windowManager.isFullScreen());
  }

  Future<void> _pickSubtitle() async {
    final r = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['srt', 'vtt', 'ass'],
    );
    final path = r?.path;
    if (path != null) await _player.setSubtitleTrack(SubtitleTrack.uri(path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): _player.playOrPause,
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _seekBy(-10),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _seekBy(10),
          const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullscreen,
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context),
        },
        child: Focus(
          autofocus: true,
          child: MouseRegion(
            cursor: _show ? SystemMouseCursors.basic : SystemMouseCursors.none,
            onHover: (_) => _poke(),
            child: GestureDetector(
              onTap: () => setState(() => _show = !_show),
              onDoubleTap: _player.playOrPause,
              child: Stack(fit: StackFit.expand, children: [
                RepaintBoundary(
                  child: Video(
                    controller: _controller,
                    fit: _aspect.boxFit,
                    aspectRatio: _aspect.ratio,
                    controls: NoVideoControls,
                  ),
                ),
                // Overlay hanya dibangun saat terlihat: saat tersembunyi tidak
                // ada widget yang ikut membangun ulang tiap detik video berjalan.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  layoutBuilder: (current, previous) => Stack(
                    fit: StackFit.expand,
                    children: [...previous, ?current],
                  ),
                  child: _show
                      ? RepaintBoundary(key: const ValueKey('overlay'), child: _overlay(context))
                      : const SizedBox.shrink(key: ValueKey('hidden')),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    const shade = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.black87, Colors.transparent, Colors.transparent, Colors.black87],
      stops: [0, 0.25, 0.7, 1],
    );
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: shade),
      child: SafeArea(
        child: Column(children: [
          Row(children: [
            BackButton(color: Colors.white, onPressed: () => Navigator.maybePop(context)),
            Expanded(
              child: Text(widget.entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
            IconButton(
              tooltip: 'Bookmark',
              icon: const Icon(Icons.bookmark_add_outlined, color: Colors.white),
              onPressed: () {
                _history.addBookmark(widget.entry, _player.state.position);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Bookmark disimpan')));
              },
            ),
            IconButton(
              tooltip: 'Subtitle',
              icon: const Icon(Icons.subtitles_rounded, color: Colors.white),
              onPressed: _pickSubtitle,
            ),
            PopupMenuButton<AspectMode>(
              tooltip: 'Aspect ratio',
              icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white),
              initialValue: _aspect,
              onSelected: (m) => setState(() => _aspect = m),
              itemBuilder: (_) => [
                for (final m in AspectMode.values)
                  PopupMenuItem(value: m, child: Text(m.label)),
              ],
            ),
            PopupMenuButton<double>(
              tooltip: 'Kecepatan',
              icon: const Icon(Icons.speed_rounded, color: Colors.white),
              initialValue: _speed,
              onSelected: (v) {
                setState(() => _speed = v);
                _player.setRate(v);
              },
              itemBuilder: (_) => [
                for (final s in const [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0])
                  PopupMenuItem(value: s, child: Text('${s}x')),
              ],
            ),
            if (!_mobile)
              IconButton(
                tooltip: 'Layar penuh (F)',
                icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
                onPressed: _toggleFullscreen,
              ),
          ]),
          const Spacer(),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                iconSize: 36,
                color: Colors.white,
                icon: const Icon(Icons.replay_10_rounded),
                onPressed: () => _seekBy(-10)),
            StreamBuilder<bool>(
              stream: _player.stream.playing,
              initialData: _player.state.playing,
              builder: (_, s) => IconButton(
                iconSize: 56,
                color: Colors.white,
                icon: Icon(s.data == true
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded),
                onPressed: () {
                  _player.playOrPause();
                  _poke();
                },
              ),
            ),
            IconButton(
                iconSize: 36,
                color: Colors.white,
                icon: const Icon(Icons.forward_10_rounded),
                onPressed: () => _seekBy(10)),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _SeekRow(player: _player, onTouch: _poke),
          ),
        ]),
      ),
    );
  }
}

/// Baris posisi video. Pembaruan dibatasi 4x/detik, dan video hanya di-seek
/// saat slider dilepas (bukan tiap piksel geseran, yang membuat decoder bekerja
/// keras tanpa perlu).
class _SeekRow extends StatefulWidget {
  const _SeekRow({required this.player, required this.onTouch});
  final Player player;
  final VoidCallback onTouch;

  @override
  State<_SeekRow> createState() => _SeekRowState();
}

class _SeekRowState extends State<_SeekRow> {
  final _pos = ValueNotifier<int>(0); // ms
  final _dur = ValueNotifier<int>(0); // ms
  double? _drag; // ms selama slider digeser
  final _subs = <StreamSubscription<Duration>>[];

  @override
  void initState() {
    super.initState();
    _pos.value = widget.player.state.position.inMilliseconds;
    _dur.value = widget.player.state.duration.inMilliseconds;
    _subs.add(widget.player.stream.position.listen((d) {
      final ms = d.inMilliseconds;
      if (_drag == null && (ms - _pos.value).abs() >= 250) _pos.value = ms;
    }));
    _subs.add(widget.player.stream.duration.listen((d) => _dur.value = d.inMilliseconds));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _pos.dispose();
    _dur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _dur,
      builder: (_, dur, _) => ValueListenableBuilder<int>(
        valueListenable: _pos,
        builder: (_, pos, _) {
          final total = dur.toDouble();
          final shown = _drag ?? pos.toDouble();
          final value = (total <= 0 ? 0.0 : shown.clamp(0.0, total)).toDouble();
          return Row(children: [
            Text(fmt(Duration(milliseconds: value.round())),
                style: const TextStyle(color: Colors.white)),
            Expanded(
              child: Slider(
                value: value,
                max: total <= 0 ? 1.0 : total,
                onChangeStart: (_) => widget.onTouch(),
                onChanged: (v) => setState(() => _drag = v),
                onChangeEnd: (v) {
                  widget.player.seek(Duration(milliseconds: v.round()));
                  _pos.value = v.round();
                  setState(() => _drag = null);
                  widget.onTouch();
                },
              ),
            ),
            Text(fmt(Duration(milliseconds: dur)),
                style: const TextStyle(color: Colors.white)),
          ]);
        },
      ),
    );
  }
}
