import 'package:flutter/material.dart';
import 'package:manga_sonic/features/browse/site_list_tab.dart';
import 'package:manga_sonic/features/library/library_screen.dart';
import 'package:manga_sonic/features/downloads/downloads_screen.dart';
import 'package:manga_sonic/features/settings/settings_tab.dart';
import 'package:manga_sonic/shared/widgets/aero_ball.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1;

  // Lazy-loaded screens - only created when first accessed
  final Map<int, Widget> _screenCache = {};

  Widget _getScreen(int index) {
    // Return cached screen if available
    if (_screenCache.containsKey(index)) {
      return _screenCache[index]!;
    }

    // Create and cache the screen on first access
    late final Widget screen;
    switch (index) {
      case 0:
        screen = const SiteListTab();
      case 1:
        screen = const LibraryScreen();
      case 2:
        screen = const DownloadsScreen();
      case 3:
        screen = const SettingsTab();
      default:
        screen = const SizedBox.shrink();
    }

    _screenCache[index] = screen;
    return screen;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          _getScreen(_currentIndex),
          AeroBall(
            currentIndex: _currentIndex,
            onTabChanged: (index) {
              setState(() => _currentIndex = index);
            },
          ),
        ],
      ),
    );
  }
}
