import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:manga_sonic/data/models/models.dart';
import 'package:manga_sonic/features/library/manga_screen.dart';

/// A genre tag chip widget
class GenreTag extends StatelessWidget {
  final String genre;

  const GenreTag({super.key, required this.genre});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        genre,
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }
}

/// A suggestion item card for "You might also like" section
class SuggestionItem extends StatelessWidget {
  final Manga manga;

  const SuggestionItem({super.key, required this.manga});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MangaScreen(
              mangaTitle: manga.title,
              mangaUrl: manga.url,
              coverUrl: manga.coverUrl,
              sourceId: manga.sourceId,
            ),
          ),
        );
      },
      child: Container(
        width: 110,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: manga.coverUrl,
                width: 110,
                height: 150,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    Container(color: Colors.grey[900]),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              manga.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An action button used in manga detail screens
class MangaActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color? dominantColor;

  const MangaActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.dominantColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPrimary
        ? (dominantColor ?? Colors.deepPurpleAccent)
        : Colors.white.withValues(alpha: 0.05);

    final isDark =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    final textColor =
        isPrimary ? (isDark ? Colors.white : Colors.black) : Colors.white70;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minWidth: 80),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: textColor, size: 22),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
