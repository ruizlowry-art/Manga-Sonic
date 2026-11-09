import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manga_sonic/services/theme_service.dart';
import 'package:manga_sonic/services/auth_service.dart';
import 'package:manga_sonic/services/sync_service.dart';
import 'package:manga_sonic/utils/download_manager.dart';
import 'package:manga_sonic/utils/library_update_service.dart';
import 'package:manga_sonic/features/auth/auth_wrapper.dart';

class MangaSonicApp extends StatelessWidget {
  final ThemeService themeService;
  final DownloadManager downloadManager;
  final LibraryUpdateService updateService;
  final AuthService authService;
  final SyncService syncService;

  const MangaSonicApp({
    super.key,
    required this.themeService,
    required this.downloadManager,
    required this.updateService,
    required this.authService,
    required this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeService),
        ChangeNotifierProvider.value(value: downloadManager),
        ChangeNotifierProvider.value(value: updateService),
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: syncService),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            title: 'MangaSonic',
            debugShowCheckedModeBanner: false,
            theme: themeService.themeData,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}
