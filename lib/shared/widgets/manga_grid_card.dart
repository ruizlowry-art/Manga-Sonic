import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MangaGridCard extends StatelessWidget {
  final String title;
  final String coverUrl;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool hasUpdate;
  final Color? selectionColor;

  const MangaGridCard({
    super.key,
    required this.title,
    required this.coverUrl,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.hasUpdate = false,
    this.selectionColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = selectionColor ?? theme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: coverUrl,
                fit: BoxFit.cover,
                memCacheWidth: 300,
                placeholder: (context, url) => Container(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                ),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.error, color: Colors.white24),
              ),
              Positioned(
                left: -5,
                right: -5,
                bottom: -5,
                child: Container(
                  height: 75,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.85),
                        Colors.black,
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isSelected)
                Positioned.fill(
                  child: Container(
                    color: accent.withValues(alpha: 0.4),
                    child: const Center(
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              if (hasUpdate && !isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
