import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:manga_sonic/data/models/models.dart';
import 'package:manga_sonic/shared/widgets/safe_blurred_cover_background.dart';
import 'dart:ui';

class BrowseHero extends StatelessWidget {
  final MangaDetails details;
  final String mangaUrl;
  final String sourceId;
  final Color? accentColor;
  final VoidCallback onAdd;
  final VoidCallback onTap;
  final bool isSaved;

  const BrowseHero({
    super.key,
    required this.details,
    required this.mangaUrl,
    required this.sourceId,
    this.accentColor,
    required this.onAdd,
    required this.onTap,
    required this.isSaved,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? Colors.deepPurpleAccent;
    final theme = Theme.of(context);
    
    // Split title for Arcane Chrome effect
    final words = details.title.split(' ');
    String firstPart = '';
    String lastPart = '';
    if (words.length > 1) {
      lastPart = words.removeLast();
      firstPart = words.join(' ') + ' ';
    } else {
      firstPart = details.title;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 480,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(),
        child: Stack(
          children: [
            // Background
            SafeBlurredCoverBackground(
              imageUrl: details.coverUrl,
              dominantColor: accentColor,
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Hero Cover
                      Hero(
                        tag: 'browse-hero-${mangaUrl}',
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: details.coverUrl,
                              width: 140,
                              height: 210,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Meta Info logic
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: effectiveAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: effectiveAccent.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                '${details.chapters.length} CHAPTERS',
                                style: TextStyle(
                                  color: effectiveAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            RichText(
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                  letterSpacing: -0.5,
                                  color: Colors.white,
                                ),
                                children: [
                                  TextSpan(text: firstPart),
                                  if (lastPart.isNotEmpty)
                                    WidgetSpan(
                                      child: ShaderMask(
                                        shaderCallback: (bounds) => const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          stops: [0.0, 0.4, 0.5, 0.6, 1.0],
                                          colors: [
                                            Color(0xFFC0C0C0),
                                            Colors.white,
                                            Colors.white,
                                            Color(0xFFE0E0E0),
                                            Color(0xFFC0C0C0),
                                          ],
                                        ).createShader(bounds),
                                        child: ShaderMask(
                                          shaderCallback: (bounds) => LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              effectiveAccent.withValues(alpha: 0.9),
                                              effectiveAccent.withValues(alpha: 0.4),
                                            ],
                                          ).createShader(bounds),
                                          child: Text(
                                            lastPart,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 29,
                                              fontWeight: FontWeight.w900,
                                              height: 1.1,
                                              letterSpacing: -1.0,
                                              shadows: [
                                                Shadow(
                                                  color: effectiveAccent.withValues(alpha: 0.8),
                                                  blurRadius: 15,
                                                ),
                                                const Shadow(
                                                  color: Colors.black54,
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Description
                  Text(
                    details.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const Spacer(),
                  // Action Button
                  Container(
                    height: 50,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          effectiveAccent.withValues(alpha: 0.8),
                          effectiveAccent.withValues(alpha: 0.4),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: effectiveAccent.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: isSaved ? null : onAdd,
                      icon: Icon(isSaved ? Icons.check : Icons.library_add),
                      label: Text(
                        isSaved ? 'IN LIBRARY' : 'ADD TO LIBRARY',
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white70,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
