import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'providers.dart';
import 'services/audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  if (isDesktop) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1100, 720),
        minimumSize: Size(420, 640),
        center: true,
        title: 'MAB-Player',
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  // audio_service mengurus notifikasi/lock-screen di Android, iOS, macOS.
  // Di Windows/Linux handler dipakai langsung (media key menyusul di fase berikutnya).
  final useService = Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  final MabAudioHandler handler = useService
      ? await AudioService.init(
          builder: () => MabAudioHandler(),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.muhammadaslambik.mab_player.audio',
            androidNotificationChannelName: 'MAB-Player',
            androidNotificationOngoing: true,
          ),
        )
      : MabAudioHandler();

  runApp(ProviderScope(
    overrides: [audioHandlerProvider.overrideWithValue(handler)],
    child: const MabApp(),
  ));
}
