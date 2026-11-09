import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';

class PaletteUtils {
  static final Map<String, Color?> _cache = {};

  /// Extracts the dominant color from an image URL, preferring vibrant color.
  static Future<Color?> extractDominantColor(String imageUrl) async {
    if (_cache.containsKey(imageUrl)) {
      return _cache[imageUrl];
    }

    try {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(imageUrl),
        maximumColorCount: 20,
      );

      // Prefer vibrant color, fall back to dominant color
      final color = paletteGenerator.vibrantColor?.color ?? paletteGenerator.dominantColor?.color;
      _cache[imageUrl] = color;
      return color;
    } catch (_) {
      return null;
    }
  }

  /// Clears the palette color cache.
  static void clearCache() {
    _cache.clear();
  }
}
