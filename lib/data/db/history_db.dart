import 'package:hive/hive.dart';
import '../../services/sync_service.dart';
import '../models/models.dart';

class HistoryDB {
  static const String statusBoxName = 'chapter_statuses';

  static Future<void> init() async {
    await Hive.openBox(statusBoxName);
  }

  static bool isRead(String chapterUrl) {
    final box = Hive.box(statusBoxName);
    final data = box.get(chapterUrl);
    if (data == null) return false;
    return ChapterStatus.fromMap(data).isRead;
  }

  static Future<void> markAsRead(
    String chapterUrl, {
    bool isRead = true,
  }) async {
    final box = Hive.box(statusBoxName);
    final existing = box.get(chapterUrl);
    int lastPage = 0;
    double lastPageOffset = 0.0;
    if (existing != null) {
      final status = ChapterStatus.fromMap(existing);
      lastPage = status.lastPage;
      lastPageOffset = status.lastPageOffset;
    }
    final status = ChapterStatus(
      chapterUrl: chapterUrl,
      isRead: isRead,
      lastPage: lastPage,
      lastPageOffset: lastPageOffset,
      lastReadTimestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await box.put(chapterUrl, status.toMap());
    _queueSyncProgress(status);
  }

  static Future<void> saveProgress(
    String chapterUrl,
    int lastPage, {
    double lastPageOffset = 0.0,
  }) async {
    final box = Hive.box(statusBoxName);
    final existing = box.get(chapterUrl);
    bool read = false;
    if (existing != null) {
      read = ChapterStatus.fromMap(existing).isRead;
    }
    final status = ChapterStatus(
      chapterUrl: chapterUrl,
      isRead: read,
      lastPage: lastPage,
      lastPageOffset: lastPageOffset,
      lastReadTimestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await box.put(chapterUrl, status.toMap());
    _queueSyncProgress(status);
  }

  static int getLastPage(String chapterUrl) {
    final box = Hive.box(statusBoxName);
    final data = box.get(chapterUrl);
    if (data == null) return 0;
    return ChapterStatus.fromMap(data).lastPage;
  }

  static double getLastPageOffset(String chapterUrl) {
    final box = Hive.box(statusBoxName);
    final data = box.get(chapterUrl);
    if (data == null) return 0.0;
    return ChapterStatus.fromMap(data).lastPageOffset;
  }

  static int? getLastReadTimestamp(String chapterUrl) {
    final box = Hive.box(statusBoxName);
    final data = box.get(chapterUrl);
    if (data == null) return null;
    return ChapterStatus.fromMap(data).lastReadTimestamp;
  }

  static void _queueSyncProgress(ChapterStatus status) {
    try {
      final syncService = SyncService.instance;
      if (syncService.pendingProgressChangesCount >= 0) {
        syncService.queueProgressChange(status);
      }
    } catch (_) {
      // SyncService not initialized yet, ignore
    }
  }
}
