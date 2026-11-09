import 'package:flutter/foundation.dart';
import 'package:manga_sonic/data/models/models.dart';
import 'package:manga_sonic/data/models/library_models.dart';
import 'package:manga_sonic/data/db/history_db.dart';
import 'package:manga_sonic/data/db/library_db.dart';
import 'package:manga_sonic/utils/chapter_utils.dart';

class MigrationUtils {

  static Future<void> transferProgress({
    required Manga oldManga,
    required Manga newManga,
    required List<Chapter> oldChapters,
    required List<Chapter> newChapters,
  }) async {
    debugPrint('Starting migration from ${oldManga.sourceId} to ${newManga.sourceId}');

    // 1. Map old chapters by number
    final Map<double, String> oldProgress = {};
    for (var ch in oldChapters) {
      final num = ChapterUtils.extractNumber(ch.title);
      if (num > 0) {
        oldProgress[num] = ch.url;
      }
    }

    // 2. Match new chapters and copy status
    int transferredCount = 0;
    for (var ch in newChapters) {
      final num = ChapterUtils.extractNumber(ch.title);
      if (num > 0 && oldProgress.containsKey(num)) {
        final oldUrl = oldProgress[num]!;
        
        // Copy Read status
        if (HistoryDB.isRead(oldUrl)) {
          await HistoryDB.markAsRead(ch.url, isRead: true);
        }

        // Copy page progress
        final page = HistoryDB.getLastPage(oldUrl);
        final offset = HistoryDB.getLastPageOffset(oldUrl);
        if (page > 0 || offset > 0) {
          await HistoryDB.saveProgress(ch.url, page, lastPageOffset: offset);
        }
        transferredCount++;
      }
    }

    debugPrint('Transferred progress for $transferredCount chapters');

    // 3. Update Library if needed
    if (LibraryDB.isSaved(oldManga.url)) {
      final items = LibraryDB.getItems();
      final oldItem = items.firstWhere((i) => i.mangaUrl == oldManga.url);
      
      // Save new source entry in same category
      await LibraryDB.saveItem(LibraryItem(
        mangaUrl: newManga.url,
        title: newManga.title,
        coverUrl: newManga.coverUrl,
        sourceId: newManga.sourceId,
        categoryId: oldItem.categoryId,
        addedAt: DateTime.now().millisecondsSinceEpoch,
      ));

      // Remove old source entry
      await LibraryDB.removeItem(oldManga.url);
      debugPrint('Updated Library: Replaced ${oldManga.sourceId} with ${newManga.sourceId}');
    }
  }
}
