import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manga_sonic/data/db/library_db.dart';
import 'package:manga_sonic/data/db/manga_cache_db.dart';
import 'package:manga_sonic/data/models/models.dart';
import 'package:manga_sonic/utils/parser_factory.dart';
import 'package:hive/hive.dart';

class LibraryUpdateService extends ChangeNotifier {
  static const String updateBoxName = 'unread_updates';
  bool _isUpdating = false;
  String _currentManga = '';

  bool get isUpdating => _isUpdating;
  String get currentManga => _currentManga;

  static Future<void> init() async {
    await Hive.openBox(updateBoxName);
  }

  Future<void> checkForUpdates() async {
    if (_isUpdating) return;
    _isUpdating = true;
    notifyListeners();

    try {
      final items = LibraryDB.getItems();
      final updateBox = Hive.box(updateBoxName);

      for (var item in items) {
        _currentManga = item.title;
        notifyListeners();

        late final dynamic parser;
        try {
          parser = getParserForSite(item.sourceId);
        } catch (e) {
          debugPrint('Unknown source for update: ${item.sourceId}');
          continue;
        }

        try {
          final manga = Manga(
            title: item.title,
            url: item.mangaUrl,
            coverUrl: item.coverUrl,
            sourceId: item.sourceId,
          );
          final freshDetails = await parser.fetchMangaDetails(manga);
          final cachedDetails = MangaCacheDB.getDetails(item.mangaUrl);

          if (cachedDetails != null) {
            // Check for new chapters
            final hasNew = freshDetails.chapters.length > cachedDetails.chapters.length;
            if (hasNew) {
              await updateBox.put(item.mangaUrl, true);
            }
          }
          
          // Always update cache with fresh data
          await MangaCacheDB.saveDetails(item.mangaUrl, freshDetails);
        } catch (e) {
          debugPrint('Error updating ${item.title}: $e');
        }
      }
    } finally {
      _isUpdating = false;
      _currentManga = '';
      notifyListeners();
    }
  }


  static bool hasUpdate(String mangaUrl) {
    return Hive.box(updateBoxName).get(mangaUrl, defaultValue: false) as bool;
  }

  static Future<void> markRead(String mangaUrl) async {
    await Hive.box(updateBoxName).delete(mangaUrl);
  }
}
