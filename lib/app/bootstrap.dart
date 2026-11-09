import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:manga_sonic/data/db/library_db.dart';
import 'package:manga_sonic/data/db/download_db.dart';
import 'package:manga_sonic/data/db/history_db.dart';
import 'package:manga_sonic/data/db/queue_db.dart';
import 'package:manga_sonic/data/db/manga_cache_db.dart';
import 'package:manga_sonic/data/db/settings_db.dart';
import 'package:manga_sonic/utils/library_update_service.dart';
import 'package:manga_sonic/utils/memory_safety_manager.dart';
import 'package:manga_sonic/utils/download_manager.dart';
import 'package:manga_sonic/services/theme_service.dart';
import 'package:manga_sonic/services/auth_service.dart';
import 'package:manga_sonic/services/sync_service.dart';

/// Holds initialized services for the app
class AppServices {
  final ThemeService themeService;
  final DownloadManager downloadManager;
  final LibraryUpdateService updateService;
  final AuthService authService;
  final SyncService syncService;

  const AppServices({
    required this.themeService,
    required this.downloadManager,
    required this.updateService,
    required this.authService,
    required this.syncService,
  });
}

/// Handles all app initialization logic
class AppBootstrap {
  /// Initialize all app dependencies
  static Future<AppServices> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Hive
    await Hive.initFlutter();

    // Initialize databases in parallel where possible
    await _initDatabases();

    // Initialize Supabase and auth
    await AuthService.initialize();
    final authService = AuthService.instance;

    // Initialize sync service
    await SyncService.initialize();
    final syncService = SyncService.instance;

    // Initialize services
    await _initServices();

    // Initialize memory safety
    MemorySafetyManager().init();

    // Create service instances
    final themeService = ThemeService();
    final downloadManager = DownloadManager();
    await downloadManager.init();
    final updateService = LibraryUpdateService();

    return AppServices(
      themeService: themeService,
      downloadManager: downloadManager,
      updateService: updateService,
      authService: authService,
      syncService: syncService,
    );
  }

  /// Initialize all databases
  static Future<void> _initDatabases() async {
    // These can run in parallel as they're independent
    await Future.wait([
      LibraryDB.init(),
      DownloadDB.init(),
      HistoryDB.init(),
      MangaCacheDB.init(),
      SettingsDB.init(),
    ]);

    // QueueDB depends on DownloadDB being initialized
    await QueueDB.init();
  }

  /// Initialize services
  static Future<void> _initServices() async {
    await LibraryUpdateService.init();
  }
}
