import 'package:hive/hive.dart';
import '../models/models.dart';

class MangaCacheDB {
  static const String cacheBoxName = 'manga_details_cache';

  // Bump this whenever the cached shape/output of parsers changes so that
  // stale entries (e.g. bad chapter lists produced by an older parser) are
  // discarded automatically on the next launch.
  // 2 = fixed AsuraComic dead domain (asuracomic.net -> asurascans.com) that
  //     caused every manga to cache the homepage "Latest Updates" chapters.
  static const int schemaVersion = 2;
  static const String _versionKey = '__schema_version__';

  static Future<void> init() async {
    final box = await Hive.openBox(cacheBoxName);
    final storedVersion = box.get(_versionKey);
    if (storedVersion != schemaVersion) {
      // Wipe stale cache once; the next fetches repopulate it correctly.
      await box.clear();
      await box.put(_versionKey, schemaVersion);
    }
  }

  static Future<void> saveDetails(String mangaUrl, MangaDetails details) async {
    final box = Hive.box(cacheBoxName);
    await box.put(mangaUrl, details.toMap());
  }

  static MangaDetails? getDetails(String mangaUrl) {
    final box = Hive.box(cacheBoxName);
    final data = box.get(mangaUrl);
    if (data == null) return null;
    try {
      return MangaDetails.fromMap(data);
    } catch (e) {
      print('Error parsing cached manga details: $e');
      return null;
    }
  }

  static Future<void> clearCache() async {
    final box = Hive.box(cacheBoxName);
    await box.clear();
    await box.put(_versionKey, schemaVersion);
  }
}
