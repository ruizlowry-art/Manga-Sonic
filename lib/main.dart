import 'package:flutter/material.dart';
import 'package:manga_sonic/app/bootstrap.dart';
import 'package:manga_sonic/app/app.dart';

void main() async {
  final services = await AppBootstrap.initialize();

  runApp(
    MangaSonicApp(
      themeService: services.themeService,
      downloadManager: services.downloadManager,
      updateService: services.updateService,
      authService: services.authService,
      syncService: services.syncService,
    ),
  );
}
