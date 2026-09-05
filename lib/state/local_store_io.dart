import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Desktop autosave backed by a JSON file in the app support directory.
class LocalStore {
  const LocalStore._();

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/autosave.sbowl');
  }

  static Future<void> write(String json) async {
    try {
      await (await _file()).writeAsString(json);
    } catch (_) {
      // Non-fatal: autosave is best-effort.
    }
  }

  static Future<String?> read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      return await f.readAsString();
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
