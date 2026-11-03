import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'data/models/media_entry.dart';
import 'data/repositories/history_repo.dart';
import 'data/services/json_store.dart';
import 'data/services/library_scanner.dart';
import 'services/audio_handler.dart';

final audioHandlerProvider =
    Provider<MabAudioHandler>((_) => throw UnimplementedError('Di-override di main()'));

final storeProvider = Provider((_) => JsonStore());
final historyProvider = Provider((ref) => HistoryRepo(ref.read(storeProvider)));

final libraryProvider =
    AsyncNotifierProvider<LibraryNotifier, List<MediaEntry>>(LibraryNotifier.new);

final audioLibraryProvider = Provider<List<MediaEntry>>((ref) =>
    ref.watch(libraryProvider).value?.where((e) => e.kind == MediaKind.audio).toList() ??
    const []);

final videoLibraryProvider = Provider<List<MediaEntry>>((ref) =>
    ref.watch(libraryProvider).value?.where((e) => e.kind == MediaKind.video).toList() ??
    const []);

class LibraryNotifier extends AsyncNotifier<List<MediaEntry>> {
  JsonStore get _store => ref.read(storeProvider);

  @override
  Future<List<MediaEntry>> build() async {
    final cached = await _store.read('library');
    if (cached is List) {
      return cached
          .map((e) => MediaEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return const [];
  }

  Future<List<String>> roots() async {
    final saved = await _store.read('roots');
    if (saved is List && saved.isNotEmpty) return saved.cast<String>();
    return LibraryScanner.defaultRoots();
  }

  Future<void> rescan() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (Platform.isAndroid) {
        await [Permission.audio, Permission.videos, Permission.storage].request();
      }
      final items = await LibraryScanner().scan(await roots());
      await _store.write('library', items.map((e) => e.toJson()).toList());
      return items;
    });
  }

  Future<void> addFolder() async {
    final dir = await FilePicker.getDirectoryPath();
    if (dir == null) return;
    final current = await roots();
    await _store.write('roots', {...current, dir}.toList());
    await rescan();
  }
}
