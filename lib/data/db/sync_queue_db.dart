import 'package:hive/hive.dart';

/// Persistent storage for pending sync changes.
///
/// Changes are written here first so they survive app restarts. SyncService
/// loads them into memory on init and removes them once they are successfully
/// pushed to Supabase.
class SyncQueueDB {
  static const String _boxName = 'sync_pending';

  static const String _libPrefix = 'lib_';
  static const String _progPrefix = 'prog_';

  static Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  static Box _box() => Hive.box(_boxName);

  // ---------- Library changes ----------

  static Future<void> saveLibraryChange(
    String changeId,
    Map<String, dynamic> data,
  ) async {
    await _box().put('$_libPrefix$changeId', data);
  }

  static Future<void> removeLibraryChange(String changeId) async {
    await _box().delete('$_libPrefix$changeId');
  }

  static List<Map<String, dynamic>> getLibraryChanges() {
    final box = _box();
    return box.keys
        .where((k) => k is String && k.startsWith(_libPrefix))
        .map((k) => (box.get(k) as Map?)?.cast<String, dynamic>() ?? {})
        .toList();
  }

  // ---------- Progress changes ----------

  static Future<void> saveProgressChange(
    String changeId,
    Map<String, dynamic> data,
  ) async {
    await _box().put('$_progPrefix$changeId', data);
  }

  static Future<void> removeProgressChange(String changeId) async {
    await _box().delete('$_progPrefix$changeId');
  }

  static List<Map<String, dynamic>> getProgressChanges() {
    final box = _box();
    return box.keys
        .where((k) => k is String && k.startsWith(_progPrefix))
        .map((k) => (box.get(k) as Map?)?.cast<String, dynamic>() ?? {})
        .toList();
  }

  static Future<void> clearAll() async {
    await _box().clear();
  }
}
