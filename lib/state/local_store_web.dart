import 'package:web/web.dart' as web;

const String _key = 'segmented_bowl_designer.autosave';

/// Web autosave backed by `window.localStorage`.
class LocalStore {
  const LocalStore._();

  static Future<void> write(String json) async {
    try {
      web.window.localStorage.setItem(_key, json);
    } catch (_) {
      // Storage may be unavailable (private mode / quota) — ignore.
    }
  }

  static Future<String?> read() async {
    try {
      return web.window.localStorage.getItem(_key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      web.window.localStorage.removeItem(_key);
    } catch (_) {}
  }
}
