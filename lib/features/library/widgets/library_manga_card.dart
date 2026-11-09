import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:manga_sonic/data/db/manga_cache_db.dart';

class LibraryMangaCard extends StatelessWidget {
  final String title;
  final String coverUrl;
  final String mangaUrl;
  final bool isNew;
  final bool hasUpdate;
  final bool isUnread;
  final bool isSelected;
  final Color? accentColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const LibraryMangaCard({
    super.key,
    required this.title,
    required this.coverUrl,
    required this.mangaUrl,
    this.isNew = false,
    this.hasUpdate = false,
    this.isUnread = false,
    this.isSelected = false,
    this.accentColor,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccentColor = accentColor ?? const Color(0xFF1DB9B9);
    // Fetch genres from cache
    final details = MangaCacheDB.getDetails(mangaUrl);
    final genres = details?.genres ?? [];
    final genresText = genres.take(2).join(' • ').toUpperCase();

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover Image with Badges
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      memCacheWidth: 400, // Downsample for memory safety
                      placeholder: (context, url) => Container(
                        color: Colors.white12,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                  ),
                ),
                
                // Selection Overlay
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: effectiveAccentColor.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                
                // Badges
                if (isNew)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildBadge(
                      'NEW',
                      const Color(0xFFFF5A92),
                    ),
                  ),
                
                if (isUnread)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: effectiveAccentColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: effectiveAccentColor.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),

                if (hasUpdate)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: _buildBadge(
                      'UPDATE',
                      effectiveAccentColor,
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Title
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Genres
          Text(
            genresText.isEmpty ? 'MANGA' : genresText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
