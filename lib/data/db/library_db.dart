import 'package:hive/hive.dart';
import '../../services/sync_service.dart';
import '../models/library_models.dart';

class LibraryDB {
  static const String categoryBoxName = 'categories';
  static const String itemBoxName = 'library_items';

  static Future<void> init() async {
    await Hive.openBox(categoryBoxName);
    await Hive.openBox(itemBoxName);

    // Ensure Default category exists
    final box = Hive.box(categoryBoxName);
    if (box.isEmpty) {
      await addCategory(LibraryCategory(id: 'default', name: 'Default'));
    }
  }

  // Categories
  static List<LibraryCategory> getCategories() {
    final box = Hive.box(categoryBoxName);
    return box.values.map((e) => LibraryCategory.fromMap(e)).toList();
  }

  static Future<void> addCategory(LibraryCategory cat) async {
    await Hive.box(categoryBoxName).put(cat.id, cat.toMap());
  }

  static Future<void> deleteCategory(String id) async {
    // Remove all items in this category or move to all (null category)
    final items = getItems();
    for (var item in items) {
      if (item.categoryId == id) {
        // Update item to have no category (falls into 'All')
        await saveItem(LibraryItem(
          mangaUrl: item.mangaUrl,
          title: item.title,
          coverUrl: item.coverUrl,
          sourceId: item.sourceId,
          categoryId: '',
          addedAt: item.addedAt,
        ));
      }
    }
    await Hive.box(categoryBoxName).delete(id);
  }

  // Items
  static List<LibraryItem> getItems() {
    final box = Hive.box(itemBoxName);
    return box.values.map((e) => LibraryItem.fromMap(e)).toList();
  }

  static bool isSaved(String mangaUrl) {
    return Hive.box(itemBoxName).containsKey(mangaUrl);
  }

  static Future<void> saveItem(LibraryItem item) async {
    await Hive.box(itemBoxName).put(item.mangaUrl, item.toMap());
    // Queue for sync if signed in
    _queueSyncAdd(item);
  }

  static Future<void> removeItem(String mangaUrl) async {
    await Hive.box(itemBoxName).delete(mangaUrl);
    // Queue for sync if signed in
    _queueSyncRemove(mangaUrl);
  }

  static void _queueSyncAdd(LibraryItem item) {
    try {
      final syncService = SyncService.instance;
      if (syncService.pendingLibraryChangesCount >= 0) { // Check if initialized
        syncService.queueLibraryAdd(item);
      }
    } catch (_) {
      // SyncService not initialized yet, ignore
    }
  }

  static void _queueSyncRemove(String mangaUrl) {
    try {
      final syncService = SyncService.instance;
      if (syncService.pendingLibraryChangesCount >= 0) {
        syncService.queueLibraryRemove(mangaUrl);
      }
    } catch (_) {
      // SyncService not initialized yet, ignore
    }
  }
}
