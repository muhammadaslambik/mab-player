import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Penyimpanan JSON lokal di folder privat aplikasi.
/// Tulis ke file sementara lalu rename, supaya tidak korup kalau aplikasi crash.
class JsonStore {
  Future<File> _file(String name) async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, '$name.json'));
  }

  Future<Object?> read(String name) async {
    try {
      final f = await _file(name);
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString());
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String name, Object data) async {
    final f = await _file(name);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(f.path);
  }
}
