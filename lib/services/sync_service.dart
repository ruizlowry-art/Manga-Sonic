import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../data/db/library_db.dart';
import '../data/db/history_db.dart';
import '../data/models/library_models.dart';
import '../data/models/models.dart';
import 'auth_service.dart';

/// Sync service for local-first synchronization with Supabase
/// 
/// Implements local-first architecture:
/// 1. All writes go to local DB first
/// 2. Changes are queued for sync to Supabase
/// 3. Sync runs when online and authenticated
/// 4. Conflicts resolved by last-write-wins (timestamp-based)
class SyncService extends ChangeNotifier {
  final SupabaseClient _client;
  final AuthService _authService;
  final Connectivity _connectivity;
  
  // Pending changes queues
  final List<PendingLibraryChange> _pendingLibraryChanges = [];
  final List<PendingProgressChange> _pendingProgressChanges = [];
  
  // Sync state
  bool _isSyncing = false;
  bool _isOnline = true;
  String? _lastSyncError;
  DateTime? _lastSuccessfulSync;
  Timer? _retryTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  // Conflict resolution: last-write-wins based on updated_at timestamp
  static const String _conflictPolicy = 'last_write_wins';

  SyncService._(this._client, this._authService, this._connectivity) {
    _initConnectivityListener();
    _authService.addListener(_onAuthStateChange);
    _loadPendingChanges();
  }

  /// Singleton instance
  static SyncService? _instance;
  
  /// Get the singleton instance
  static SyncService get instance {
    if (_instance == null) {
      throw StateError('SyncService not initialized. Call SyncService.initialize() first.');
    }
    return _instance!;
  }

  /// Initialize the sync service
  static Future<void> initialize() async {
    _instance = SyncService._(
      Supabase.instance.client,
      AuthService.instance,
      Connectivity(),
    );
  }

  /// Whether a sync is currently in progress
  bool get isSyncing => _isSyncing;

  /// Whether the device appears to be online
  bool get isOnline => _isOnline;

  /// Last sync error message (if any)
  String? get lastSyncError => _lastSyncError;

  /// Last successful sync timestamp
  DateTime? get lastSuccessfulSync => _lastSuccessfulSync;

  /// Number of pending library changes
  int get pendingLibraryChangesCount => _pendingLibraryChanges.length;

  /// Number of pending progress changes
  int get pendingProgressChangesCount => _pendingProgressChanges.length;

  /// Initialize connectivity listener
  void _initConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      // Check if any connectivity result is not none
      _isOnline = results.any((result) => result != ConnectivityResult.none);
      
      if (!wasOnline && _isOnline && _authService.isSignedIn) {
        // Came back online while signed in - trigger sync
        _scheduleSync();
      }
      notifyListeners();
    });
  }

  /// Listen for auth state changes
  void _onAuthStateChange() {
    if (_authService.isSignedIn) {
      _scheduleSync();
    } else {
      // Clear pending changes on sign out to prevent cross-account contamination
      _clearPendingChanges();
    }
    notifyListeners();
  }

  /// Load pending changes from local storage
  Future<void> _loadPendingChanges() async {
    // TODO: Implement persistent storage for pending changes
    // For now, we'll rely on re-syncing from local DB on startup
  }

  /// Schedule a sync with debouncing
  void _scheduleSync() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 2), () {
      if (_authService.isSignedIn && _isOnline && !_isSyncing) {
        sync();
      }
    });
  }

  /// Perform full sync: push local changes, pull remote changes
  Future<void> sync() async {
    if (!_authService.isSignedIn || !_isOnline || _isSyncing) return;
    
    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    try {
      // Push local changes first
      await _pushLibraryChanges();
      await _pushProgressChanges();
      
      // Then pull remote changes
      await _pullLibraryChanges();
      await _pullProgressChanges();
      
      _lastSuccessfulSync = DateTime.now();
    } catch (e) {
      _lastSyncError = 'Sync failed: $e';
      _scheduleRetry();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Schedule a retry with exponential backoff
  void _scheduleRetry() {
    _retryTimer?.cancel();
    // Start with 30 seconds, max 5 minutes
    int delaySeconds = 30;
    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_authService.isSignedIn && _isOnline && !_isSyncing) {
        sync();
      }
    });
  }

  // ========== LIBRARY SYNC ==========

  /// Queue a library item addition for sync
  void queueLibraryAdd(LibraryItem item) {
    _pendingLibraryChanges.add(PendingLibraryChange(
      type: SyncChangeType.add,
      item: item,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
    _scheduleSync();
  }

  /// Queue a library item removal for sync
  void queueLibraryRemove(String mangaUrl) {
    _pendingLibraryChanges.add(PendingLibraryChange(
      type: SyncChangeType.remove,
      mangaUrl: mangaUrl,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
    _scheduleSync();
  }

  /// Queue a library item update for sync
  void queueLibraryUpdate(LibraryItem item) {
    _pendingLibraryChanges.add(PendingLibraryChange(
      type: SyncChangeType.update,
      item: item,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
    _scheduleSync();
  }

  /// Push pending library changes to Supabase
  Future<void> _pushLibraryChanges() async {
    final userId = _authService.userId;
    if (userId == null) return;

    // Ensure session is set on client
    _authService.ensureSession();

    for (final change in _pendingLibraryChanges) {
      try {
        switch (change.type) {
          case SyncChangeType.add:
            if (change.item != null) {
              await _client.from('library_items').upsert({
                'user_id': userId,
                'manga_url': change.item!.mangaUrl,
                'title': change.item!.title,
                'cover_url': change.item!.coverUrl,
                'source_id': change.item!.sourceId,
                'category_id': change.item!.categoryId,
                'added_at': change.item!.addedAt,
                'updated_at': DateTime.now().toIso8601String(),
              }, onConflict: 'user_id,manga_url');
            }
            break;
            
          case SyncChangeType.remove:
            if (change.mangaUrl != null) {
              await _client.from('library_items')
                .delete()
                .eq('user_id', userId)
                .eq('manga_url', change.mangaUrl!);
            }
            break;
            
          case SyncChangeType.update:
            if (change.item != null) {
              await _client.from('library_items').upsert({
                'user_id': userId,
                'manga_url': change.item!.mangaUrl,
                'title': change.item!.title,
                'cover_url': change.item!.coverUrl,
                'source_id': change.item!.sourceId,
                'category_id': change.item!.categoryId,
                'added_at': change.item!.addedAt,
                'updated_at': DateTime.now().toIso8601String(),
              }, onConflict: 'user_id,manga_url');
            }
            break;
        }
        
        // Remove from pending only on success
        _pendingLibraryChanges.remove(change);
      } on PostgrestException catch (e) {
        debugPrint('Failed to push library change (Postgrest): ${e.message} (code: ${e.code})');
        if (e.code == '42501') {
          // RLS violation - session might be expired, try to refresh
          debugPrint('RLS violation detected, attempting session recovery...');
          await _tryRecoverSession();
        }
        // Keep in pending for retry
      } catch (e) {
        debugPrint('Failed to push library change: $e');
        // Keep in pending for retry
      }
    }
  }

  /// Pull library changes from Supabase and merge with local
  Future<void> _pullLibraryChanges() async {
    final userId = _authService.userId;
    if (userId == null) return;

    // Ensure session is set on client
    _authService.ensureSession();

    try {
      final response = await _client
          .from('library_items')
          .select()
          .eq('user_id', userId);

      final remoteItems = (response as List)
          .map((json) => _libraryItemFromJson(json))
          .toList();

      // Merge with local using conflict resolution
      await _mergeLibraryItems(remoteItems);
    } on PostgrestException catch (e) {
      debugPrint('Failed to pull library changes (Postgrest): ${e.message} (code: ${e.code})');
      if (e.code == '42501') {
        await _tryRecoverSession();
      }
    } catch (e) {
      debugPrint('Failed to pull library changes: $e');
    }
  }

  /// Merge remote library items with local using conflict resolution
  Future<void> _mergeLibraryItems(List<LibraryItem> remoteItems) async {
    final localItems = LibraryDB.getItems();
    final localMap = {for (var item in localItems) item.mangaUrl: item};
    final remoteMap = {for (var item in remoteItems) item.mangaUrl: item};

    // All unique manga URLs
    final allUrls = <String>{...localMap.keys, ...remoteMap.keys};

    for (final url in allUrls) {
      final local = localMap[url];
      final remote = remoteMap[url];

      if (local == null && remote != null) {
        // Only in remote - add to local
        await LibraryDB.saveItem(remote);
      } else if (local != null && remote == null) {
        // Only in local - will be pushed on next sync
      } else if (local != null && remote != null) {
        // In both - resolve conflict by updated_at (last write wins)
        // Since we don't have updated_at in local, we use addedAt as proxy
        // For true last-write-wins, we'd need to track local update timestamps
        final localTime = local.addedAt;
        final remoteTime = remote.addedAt;
        
        if (remoteTime > localTime) {
          await LibraryDB.saveItem(remote);
        }
        // If local is newer, it will be pushed on next sync
      }
    }
  }

  // ========== READING PROGRESS SYNC ==========

  /// Queue a reading progress change for sync
  void queueProgressChange(ChapterStatus status) {
    _pendingProgressChanges.add(PendingProgressChange(
      status: status,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
    _scheduleSync();
  }

  /// Push pending progress changes to Supabase
  Future<void> _pushProgressChanges() async {
    final userId = _authService.userId;
    if (userId == null) return;

    // Ensure session is set on client
    _authService.ensureSession();

    for (final change in _pendingProgressChanges) {
      try {
        await _client.from('reading_progress').upsert({
          'user_id': userId,
          'chapter_url': change.status.chapterUrl,
          'is_read': change.status.isRead,
          'last_page': change.status.lastPage,
          'last_page_offset': change.status.lastPageOffset,
          'last_read_timestamp': change.status.lastReadTimestamp,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,chapter_url');
        
        _pendingProgressChanges.remove(change);
      } on PostgrestException catch (e) {
        debugPrint('Failed to push progress change (Postgrest): ${e.message} (code: ${e.code})');
        if (e.code == '42501') {
          // RLS violation - session might be expired, try to refresh
          debugPrint('RLS violation detected, attempting session recovery...');
          await _tryRecoverSession();
        }
        // Keep in pending for retry
      } catch (e) {
        debugPrint('Failed to push progress change: $e');
      }
    }
  }

  /// Pull reading progress from Supabase and merge with local
  Future<void> _pullProgressChanges() async {
    final userId = _authService.userId;
    if (userId == null) return;

    // Ensure session is set on client
    _authService.ensureSession();

    try {
      final response = await _client
          .from('reading_progress')
          .select()
          .eq('user_id', userId);

      final remoteProgress = (response as List)
          .map((json) => _chapterStatusFromJson(json))
          .toList();

      await _mergeProgress(remoteProgress);
    } on PostgrestException catch (e) {
      debugPrint('Failed to pull progress changes (Postgrest): ${e.message} (code: ${e.code})');
      if (e.code == '42501') {
        await _tryRecoverSession();
      }
    } catch (e) {
      debugPrint('Failed to pull progress changes: $e');
    }
  }

  /// Merge remote reading progress with local using conflict resolution
  Future<void> _mergeProgress(List<ChapterStatus> remoteProgress) async {
    for (final remote in remoteProgress) {
      final localTimestamp = HistoryDB.getLastReadTimestamp(remote.chapterUrl);
      final remoteTimestamp = remote.lastReadTimestamp ?? 0;

      // Last write wins based on timestamp
      if (localTimestamp == null || remoteTimestamp > localTimestamp) {
        await HistoryDB.saveProgress(
          remote.chapterUrl,
          remote.lastPage,
          lastPageOffset: remote.lastPageOffset,
        );
        // Also update read status
        if (remote.isRead) {
          await HistoryDB.markAsRead(remote.chapterUrl, isRead: true);
        }
      }
      // If local is newer, it will be pushed on next sync
    }
  }

  // ========== HELPERS ==========

  LibraryItem _libraryItemFromJson(Map<String, dynamic> json) {
    return LibraryItem(
      mangaUrl: json['manga_url'] as String,
      title: json['title'] as String,
      coverUrl: json['cover_url'] as String,
      sourceId: json['source_id'] as String,
      categoryId: json['category_id'] as String? ?? '',
      addedAt: json['added_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  ChapterStatus _chapterStatusFromJson(Map<String, dynamic> json) {
    return ChapterStatus(
      chapterUrl: json['chapter_url'] as String,
      isRead: json['is_read'] as bool? ?? false,
      lastPage: json['last_page'] as int? ?? 0,
      lastPageOffset: (json['last_page_offset'] as num?)?.toDouble() ?? 0.0,
      lastReadTimestamp: json['last_read_timestamp'] as int?,
    );
  }

  /// Clear all pending changes (used on sign out)
  void _clearPendingChanges() {
    _pendingLibraryChanges.clear();
    _pendingProgressChanges.clear();
  }

  /// Force a sync now (for manual trigger)
  Future<void> forceSync() async {
    if (_authService.isSignedIn && _isOnline) {
      await sync();
    }
  }

  /// Try to recover the session by refreshing the auth token
  Future<void> _tryRecoverSession() async {
    try {
      debugPrint('Attempting to recover session...');
      final session = await _client.auth.refreshSession();
      if (session != null && session.user != null) {
        debugPrint('Session recovered for user: ${session.user!.email}');
        _authService.ensureSession();
      } else {
        debugPrint('Failed to recover session - no session returned');
      }
    } catch (e) {
      debugPrint('Session recovery failed: $e');
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _connectivitySubscription?.cancel();
    _authService.removeListener(_onAuthStateChange);
    super.dispose();
  }
}

/// Types of sync changes
enum SyncChangeType { add, remove, update }

/// Pending library change for sync queue
class PendingLibraryChange {
  final SyncChangeType type;
  final LibraryItem? item;
  final String? mangaUrl;
  final int timestamp;

  PendingLibraryChange({
    required this.type,
    this.item,
    this.mangaUrl,
    required this.timestamp,
  });
}

/// Pending progress change for sync queue
class PendingProgressChange {
  final ChapterStatus status;
  final int timestamp;

  PendingProgressChange({
    required this.status,
    required this.timestamp,
  });
}