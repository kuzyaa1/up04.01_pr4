import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StoreReadResult {
  final List<Map<String, dynamic>> items;
  final bool persisted;
  const StoreReadResult(this.items, this.persisted);
}

class VersionedStore {
  static const int currentVersion = 3;
  static const String prefix = 'focus_frame_';
  static const String noticeKey = '${prefix}migration_notice';

  static String key(String name, int version) => '$prefix${name}_v$version';
  static StoreReadResult read(
    SharedPreferences prefs,
    String name, {
    required Map<String, dynamic> Function(Map<String, dynamic> json) parse,
    required Map<String, dynamic> Function(Map<String, dynamic> json) migrate,
    required List<Map<String, dynamic>> seed,
  }) {
    final current = prefs.getString(key(name, currentVersion));
    if (current != null) {
      final parsed = _decodeList(current, parse);
      if (parsed != null) return StoreReadResult(parsed, false);
      writeSync(prefs, name, seed);
      _notify(prefs, 'Данные «$name» были повреждены и восстановлены');
      return StoreReadResult(seed, true);
    }
    for (var version = currentVersion - 1; version >= 1; version--) {
      final oldKey = key(name, version);
      final old = prefs.getString(oldKey);
      if (old == null) continue;
      try {
        final raw = _decodeList(old, (json) => json);
        if (raw == null) {
          prefs.remove(oldKey);
          continue;
        }
        final migrated = raw.map(migrate).toList();
        writeSync(prefs, name, migrated);
        prefs.remove(oldKey);
        _notify(prefs,
            'Данные «$name» обновлены с версии $version до версии $currentVersion');
        return StoreReadResult(migrated.map(parse).toList(), true);
      } catch (_) {
        prefs.remove(oldKey);
      }
    }
    writeSync(prefs, name, seed);
    return StoreReadResult(seed, true);
  }

  static Future<void> write(SharedPreferences prefs, String name,
      List<Map<String, dynamic>> items) async {
    try {
      await prefs.setString(key(name, currentVersion), jsonEncode(items));
    } catch (_) {}
  }

  static void writeSync(
      SharedPreferences prefs, String name, List<Map<String, dynamic>> items) {
    try {
      // ignore: discarded_futures
      prefs.setString(key(name, currentVersion), jsonEncode(items));
    } catch (_) {}
  }

  static String? takeNotice(SharedPreferences prefs) {
    final notice = prefs.getString(noticeKey);
    if (notice != null) prefs.remove(noticeKey);
    return notice;
  }

  static List<Map<String, dynamic>>? _decodeList(
    String raw,
    Map<String, dynamic> Function(Map<String, dynamic>) parse,
  ) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .map((item) => item is Map<String, dynamic> ? parse(item) : null)
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return null;
    }
  }

  static void _notify(SharedPreferences prefs, String text) {
    try {
      prefs.setString(noticeKey, text);
    } catch (_) {}
  }
}
