import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ThemeService extends ChangeNotifier {
  static const String _boxName = 'themeBox';
  static const String _colorKey = 'primaryColor';
  static const String _bgColorKey = 'backgroundColor';

  late Box _box;
  Color _primaryColor = Colors.deepPurple;
  Color _backgroundColor = const Color(0xFF121212); // Default dark grey/black
  
  // Cache to avoid refetching palette for same image
  final Map<String, Color> _paletteCache = {};

  ThemeService() {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox(_boxName);
    final colorValue = _box.get(
      _colorKey,
      defaultValue: Colors.deepPurple.toARGB32(),
    ) as int;
    final bgColorValue = _box.get(
      _bgColorKey,
      defaultValue: const Color(0xFF121212).toARGB32(),
    ) as int;

    _primaryColor = Color(colorValue);
    // Safety check: handle fully transparent color by resetting to default
    if (_primaryColor.a == 0) _primaryColor = Colors.deepPurple;

    _backgroundColor = Color(bgColorValue);
    // Safety check: handle fully transparent color by resetting to default
    if (_backgroundColor.a == 0) _backgroundColor = const Color(0xFF121212);
    notifyListeners();
  }

  Color get primaryColor => _primaryColor;
  Color get backgroundColor => _backgroundColor;

  Future<void> updateThemeFromImage(String imageUrl) async {
    if (imageUrl.isEmpty) return;
    
    // Check cache
    if (_paletteCache.containsKey(imageUrl)) {
      setPrimaryColor(_paletteCache[imageUrl]!);
      return;
    }

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(imageUrl),
        maximumColorCount: 20,
      );

      // Prefer vibrant colors for the "Aero" look
      Color selectedColor = palette.vibrantColor?.color ?? 
                           palette.lightVibrantColor?.color ??
                           palette.dominantColor?.color ?? 
                           Colors.deepPurple;

      _paletteCache[imageUrl] = selectedColor;
      setPrimaryColor(selectedColor);
    } catch (e) {
      debugPrint('Error generating palette: $e');
    }
  }

  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    await _box.put(_colorKey, color.toARGB32());
    notifyListeners();
  }

  Future<void> setBackgroundColor(Color color) async {
    _backgroundColor = color;
    await _box.put(_bgColorKey, color.toARGB32());
    notifyListeners();
  }

  ThemeData get themeData {
    return ThemeData.dark().copyWith(
      primaryColor: _primaryColor,
      scaffoldBackgroundColor: _backgroundColor,
      canvasColor: _backgroundColor,
      colorScheme: ColorScheme.dark(
        primary: _primaryColor,
        secondary: _primaryColor,
        surface: _backgroundColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _backgroundColor == Colors.black
            ? Colors.grey[900]
            : _backgroundColor,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
      ),
    );
  }
}
