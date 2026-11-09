import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:manga_sonic/data/db/download_db.dart';
import 'package:manga_sonic/data/db/queue_db.dart';
import 'package:manga_sonic/utils/parser_factory.dart';

import 'package:http/io_client.dart';

typedef DownloadTask = QueuedTask;

class DownloadStatus {
  final double progress;
  final bool isDownloading;
  final int downloadedImages;
  final int totalImages;

  DownloadStatus({
    this.progress = 0.0,
    this.isDownloading = false,
    this.downloadedImages = 0,
    this.totalImages = 0,
  });
}

class DownloadManager extends ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final List<DownloadTask> _queue = [];
  bool _isProcessing = false;
  bool _isOffline = false;
  // Custom HttpClient with higher connection pool limit for parallel downloads
  late final http.Client _client = IOClient(
    HttpClient()..maxConnectionsPerHost = 20,
  );
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Tracks which chapter URLs have been requested to cancel
  final Set<String> _cancelledChapters = {};

  // Debouncing for connectivity changes to avoid false positives
  DateTime? _lastConnectivityChange;
  static const _connectivityDebounce = Duration(seconds: 3);

  Future<void> init() async {
    // Load persisted queue
    final savedQueue = QueueDB.getQueue();
    _queue.addAll(savedQueue);

    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _isOffline = result.contains(ConnectivityResult.none);

    // Listen for changes with debouncing
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      _lastConnectivityChange = DateTime.now();
      final changeTime = _lastConnectivityChange;

      // Debounce: wait 3 seconds before acting on connectivity change
      Future.delayed(_connectivityDebounce, () {
        // Only process if this is still the most recent change
        if (_lastConnectivityChange != changeTime) return;

        final wasOffline = _isOffline;
        _isOffline = results.contains(ConnectivityResult.none);

        if (wasOffline && !_isOffline && _queue.isNotEmpty && !_isProcessing) {
          debugPrint('Internet restored, resuming downloads...');
          _processQueue();
        } else if (_isOffline) {
          debugPrint(
            'Internet lost, downloads will pause after current chunk...',
          );
        }
        notifyListeners();
      });
    });

    if (!_isOffline && _queue.isNotEmpty) {
      _processQueue();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // Progress tracking: chapterUrl -> DownloadStatus
  final Map<String, DownloadStatus> _statuses = {};

  List<DownloadTask> get queue => List.unmodifiable(_queue);
  Map<String, DownloadStatus> get statuses => Map.unmodifiable(_statuses);

  DownloadStatus getStatus(String chapterUrl) {
    if (_statuses.containsKey(chapterUrl)) {
      return _statuses[chapterUrl] ?? DownloadStatus();
    }
    // If not in statuses but in queue, it's pending/queued
    if (_queue.any((t) => t.chapterUrl == chapterUrl)) {
      return DownloadStatus(isDownloading: false, progress: 0.0);
    }
    // Default empty status
    return DownloadStatus();
  }

  Future<void> downloadChapter({
    required String chapterUrl,
    required String chapterTitle,
    required String mangaTitle,
    required String mangaUrl,
    required String coverUrl,
    required String author,
    required List<String> genres,
    required String sourceId,
  }) async {
    if (DownloadDB.isDownloaded(chapterUrl)) return;

    // Check if already in queue
    if (_queue.any((task) => task.chapterUrl == chapterUrl)) return;

    final task = DownloadTask(
      chapterUrl: chapterUrl,
      chapterTitle: chapterTitle,
      mangaTitle: mangaTitle,
      mangaUrl: mangaUrl,
      coverUrl: coverUrl,
      author: author,
      genres: genres,
      sourceId: sourceId,
    );

    _queue.add(task);
    await QueueDB.addToQueue(task);

    // The task is now queued. Status will be picked up dynamically by `getStatus()`.
    notifyListeners();

    if (!_isProcessing && !_isOffline) {
      _processQueue();
    }
  }

  // Concurrency limits
  static const int _maxConcurrentManga = 3;
  static const int _maxChaptersPerManga = 4;

  // Tracks which chapter URLs are actively being downloaded
  final Set<String> _activeChapters = {};

  Future<void> _processQueue() async {
    if (_queue.isEmpty || _isOffline) {
      _isProcessing = false;
      return;
    }

    _isProcessing = true;

    // Group pending (non-active) tasks by manga URL
    final Map<String, List<DownloadTask>> byManga = {};
    for (var task in _queue) {
      if (_activeChapters.contains(task.chapterUrl)) continue;
      byManga.putIfAbsent(task.mangaUrl, () => []).add(task);
    }

    if (byManga.isEmpty) return; // All queued items are already active

    // Pick up to _maxConcurrentManga manga groups
    final mangaGroups = byManga.entries.take(_maxConcurrentManga).toList();

    // Collect tasks to launch
    final List<DownloadTask> tasksToLaunch = [];
    for (var entry in mangaGroups) {
      final chapters = entry.value.take(_maxChaptersPerManga);
      tasksToLaunch.addAll(chapters);
    }

    // Mark them all as active
    for (var task in tasksToLaunch) {
      _activeChapters.add(task.chapterUrl);
    }

    // Launch all tasks in parallel
    await Future.wait(tasksToLaunch.map((task) => _executeSafe(task)));

    // Re-evaluate the queue for more work
    if (_queue.isNotEmpty && !_isOffline) {
      _processQueue();
    } else {
      _isProcessing = false;
    }
  }

  Future<void> cancelChapter(String chapterUrl) async {
    if (_activeChapters.contains(chapterUrl)) {
      _cancelledChapters.add(chapterUrl);
    } else {
      _queue.removeWhere((t) => t.chapterUrl == chapterUrl);
      await QueueDB.removeFromQueue(chapterUrl);
    }
    notifyListeners();
  }

  Future<void> cancelMangaDownloads(String mangaUrl) async {
    // Cancel queued ones first
    _queue.removeWhere((t) {
      if (t.mangaUrl == mangaUrl && !_activeChapters.contains(t.chapterUrl)) {
        QueueDB.removeFromQueue(t.chapterUrl);
        return true;
      }
      return false;
    });

    // Mark active ones for cancellation
    for (var chapterUrl in _activeChapters) {
      final task = _queue.firstWhere((t) => t.chapterUrl == chapterUrl);
      if (task.mangaUrl == mangaUrl) {
        _cancelledChapters.add(chapterUrl);
      }
    }
    notifyListeners();
  }

  Future<void> _executeSafe(DownloadTask task) async {
    try {
      await _executeTask(task);
    } catch (e) {
      debugPrint('Error processing task ${task.chapterTitle}: $e');
      _statuses.remove(task.chapterUrl);
      notifyListeners();
    } finally {
      _activeChapters.remove(task.chapterUrl);
      _cancelledChapters.remove(task.chapterUrl);

      // If it was cancelled, we don't necessarily want it removed from queue
      // if we want to retry later, but "Cancel" usually means "Remove from list".
      // Let's remove it.
      _queue.removeWhere((t) => t.chapterUrl == task.chapterUrl);
      await QueueDB.removeFromQueue(task.chapterUrl);
    }
  }

  Future<void> _executeTask(DownloadTask task) async {
    final parser = getParserForSite(task.sourceId);
    final imageUrls = await parser.fetchChapterImages(task.chapterUrl);

    if (imageUrls.isEmpty) {
      _statuses.remove(task.chapterUrl);
      notifyListeners();
      return;
    }

    _statuses[task.chapterUrl] = DownloadStatus(
      isDownloading: true,
      totalImages: imageUrls.length,
      downloadedImages: 0,
      progress: 0.0,
    );
    notifyListeners();

    final appDir = await getApplicationDocumentsDirectory();

    // Improved sanitization for Windows and cross-platform safety
    String sanitize(String name) {
      // Remove reserved characters: \ / : * ? " < > |
      String sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      // Remove trailing dots and spaces which are problematic on Windows
      sanitized = sanitized.trim().replaceAll(RegExp(r'\.+$'), '');
      // Handle reserved names (CON, PRN, AUX, NUL, COM1-9, LPT1-9)
      final reservedNames = [
        'CON',
        'PRN',
        'AUX',
        'NUL',
        'COM1',
        'COM2',
        'COM3',
        'COM4',
        'COM5',
        'COM6',
        'COM7',
        'COM8',
        'COM9',
        'LPT1',
        'LPT2',
        'LPT3',
        'LPT4',
        'LPT5',
        'LPT6',
        'LPT7',
        'LPT8',
        'LPT9',
      ];
      if (reservedNames.contains(sanitized.toUpperCase())) {
        sanitized = '${sanitized}_';
      }
      return sanitized.isEmpty ? 'unnamed' : sanitized;
    }

    final safeMangaTitle = sanitize(task.mangaTitle);
    final safeChapterTitle = sanitize(task.chapterTitle);

    final dirPath = p.join(
      appDir.path,
      'downloads',
      task.sourceId,
      safeMangaTitle,
      safeChapterTitle,
    );
    debugPrint('Downloading to: $dirPath');

    final directory = Directory(dirPath);
    if (!await directory.exists()) {
      try {
        await directory.create(recursive: true);
      } catch (e) {
        debugPrint('Failed to create directory $dirPath: $e');
        _statuses.remove(task.chapterUrl);
        notifyListeners();
        return;
      }
    }

    int successCount = 0;
    const int concurrency = 3; // Reduced for better stability

    for (int i = 0; i < imageUrls.length; i += concurrency) {
      if (_cancelledChapters.contains(task.chapterUrl)) {
        debugPrint('Cancellation detected for ${task.chapterTitle}');
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
        return;
      }

      final end = (i + concurrency > imageUrls.length)
          ? imageUrls.length
          : i + concurrency;
      final chunk = imageUrls.sublist(i, end);
      final indexOffset = i;

      final results = await Future.wait(
        chunk.asMap().entries.map((entry) async {
          if (_isOffline) return false;
          final imgUrl = entry.value;
          final imgIndex = indexOffset + entry.key;
          return _downloadImage(imgUrl, dirPath, imgIndex, parser.baseUrl);
        }),
      );

      if (_isOffline) {
        debugPrint('Download paused due to no internet.');
        _isProcessing = false;
        return; // Current task remains at head of queue
      }

      successCount += results.where((r) => r).length;

      // Update progress
      _statuses[task.chapterUrl] = DownloadStatus(
        isDownloading: true,
        totalImages: imageUrls.length,
        downloadedImages: successCount,
        progress: successCount / imageUrls.length,
      );
      notifyListeners();
    }

    if (successCount > 0) {
      await DownloadDB.saveDownload(
        DownloadedChapter(
          chapterUrl: task.chapterUrl,
          chapterTitle: task.chapterTitle,
          mangaTitle: task.mangaTitle,
          mangaUrl: task.mangaUrl,
          coverUrl: task.coverUrl,
          author: task.author,
          genres: task.genres,
          directoryPath: dirPath,
          imageCount: successCount,
        ),
      );
    } else {
      if (await directory.exists()) await directory.delete(recursive: true);
    }

    _statuses.remove(task.chapterUrl);
    notifyListeners();
  }

  Future<bool> _downloadImage(
    String url,
    String dirPath,
    int index,
    String referer,
  ) async {
    int retries = 3;
    while (retries > 0) {
      try {
        final res = await _client
            .get(
              Uri.parse(url),
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Referer': referer,
              },
            )
            .timeout(const Duration(seconds: 30));

        if (res.statusCode == 200) {
          final filePath = p.join(
            dirPath,
            '${index.toString().padLeft(4, '0')}.jpg',
          );
          final file = File(filePath);
          await file.writeAsBytes(res.bodyBytes);
          return true;
        }
      } catch (e) {
        debugPrint('Retry $retries for $url: $e');
      }
      retries--;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  Future<void> deleteChapter(String chapterUrl) async {
    final download = DownloadDB.getDownload(chapterUrl);
    if (download != null) {
      final directory = Directory(download.directoryPath);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      await DownloadDB.removeDownload(chapterUrl);
      notifyListeners();
    }
  }
}
