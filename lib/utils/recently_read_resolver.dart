import 'package:hive/hive.dart';
import 'package:manga_sonic/data/models/models.dart';
import 'package:manga_sonic/data/models/library_models.dart';
import 'package:manga_sonic/data/db/manga_cache_db.dart';

class RecentlyReadResult {
  final Manga manga;
  final Chapter chapter;
  final int lastPage;
  final String description;
  final List<String> genres;

  RecentlyReadResult({
    required this.manga,
    required this.chapter,
    required this.lastPage,
    required this.description,
    required this.genres,
  });
}

class RecentlyReadResolver {
  /// Resolves the most recently read manga from the chapter statuses and library items.
  static RecentlyReadResult? resolve(List<LibraryItem> items) {
    final statusBox = Hive.box('chapter_statuses');
    if (statusBox.isEmpty) return null;

    String? bestChapterUrl;
    int maxTimestamp = -1;
    ChapterStatus? bestStatus;

    // 1. Find the absolute latest read chapter
    for (var key in statusBox.keys) {
      final data = statusBox.get(key);
      if (data == null) continue;
      final status = ChapterStatus.fromMap(data);
      
      int ts = status.lastReadTimestamp ?? (status.isRead ? 1 : -1);
      
      if (ts > maxTimestamp) {
        maxTimestamp = ts;
        bestChapterUrl = key as String;
        bestStatus = status;
      }
    }

    if (bestChapterUrl == null || bestStatus == null) return null;

    // 2. Resolve Bibliographic Info
    LibraryItem? matchedItem;
    MangaDetails? matchedDetails;
    String? mangaUrl;

    for (final item in items) {
      if (bestChapterUrl == item.mangaUrl || 
          bestChapterUrl.startsWith(item.mangaUrl) ||
          bestChapterUrl.contains(item.mangaUrl.replaceAll('manga/', ''))) {
        matchedItem = item;
        mangaUrl = item.mangaUrl;
        break;
      }
    }

    if (mangaUrl == null) {
      final cacheBox = Hive.box('manga_details_cache');
      for (var key in cacheBox.keys) {
        final detailsMap = cacheBox.get(key);
        if (detailsMap == null) continue;
        final details = MangaDetails.fromMap(detailsMap);
        if (details.chapters.any((c) => c.url == bestChapterUrl)) {
          matchedDetails = details;
          mangaUrl = key as String;
          break;
        }
      }
    }

    if (mangaUrl == null && matchedItem == null) return null;

    final title = matchedItem?.title ?? matchedDetails?.title ?? 'Manga';
    final cover = matchedItem?.coverUrl ?? matchedDetails?.coverUrl ?? '';
    final source = matchedItem?.sourceId ?? (matchedDetails != null ? 'unknown' : 'unknown'); 

    final details = matchedDetails ?? MangaCacheDB.getDetails(mangaUrl!);
    final chapter = details?.chapters.firstWhere(
      (c) => c.url == bestChapterUrl,
      orElse: () => Chapter(
        title: 'Last Chapter',
        url: bestChapterUrl!,
        mangaUrl: mangaUrl ?? '',
      ),
    ) ?? Chapter(
        title: 'Last Chapter',
        url: bestChapterUrl,
        mangaUrl: mangaUrl ?? '',
      );

    return RecentlyReadResult(
      manga: Manga(
        title: title,
        url: mangaUrl ?? '',
        coverUrl: cover,
        sourceId: source,
      ),
      chapter: chapter,
      lastPage: bestStatus.lastPage,
      description: details?.description ?? '',
      genres: details?.genres ?? [],
    );
  }
}
