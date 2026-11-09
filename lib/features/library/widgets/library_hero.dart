import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:manga_sonic/data/models/models.dart';
import 'package:manga_sonic/services/theme_service.dart';
import 'package:provider/provider.dart';

class LibraryHero extends StatelessWidget {
  final Manga manga;
  final Chapter? lastChapter;
  final int lastPage;
  final String description;
  final VoidCallback onResume;

  const LibraryHero({
    super.key,
    required this.manga,
    this.lastChapter,
    this.lastPage = 0,
    required this.description,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final accentColor = themeService.primaryColor;

    // Split title for two-tone effect
    final titleParts = manga.title.split(' ');
    String firstPart = '';
    String lastPart = '';
    
    if (titleParts.length > 1) {
      lastPart = titleParts.last;
      firstPart = titleParts.take(titleParts.length - 1).join(' ') + ' ';
    } else {
      firstPart = manga.title;
    }

    return SizedBox(
      height: 420, // Increased height for better proportions
      width: double.infinity,
      child: Stack(
        children: [
          // Background Image with Cinematic Gradient
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: manga.coverUrl,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              placeholder: (context, url) => Container(color: Colors.black),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
          
          // Triple Gradient Layer for Depth
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.9),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.3, 0.6, 0.8, 1.0],
                ),
              ),
            ),
          ),
          
          // Left Radial/Linear Mix for text readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 0.8],
                ),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Badge & Chapter Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'CONTINUE READING',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (lastChapter != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '- ${lastChapter!.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                
                // Two-Tone Title
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      letterSpacing: -0.5,
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
                                Color(0xFFC0C0C0), // Silver edge
                                Colors.white,       // Peak reflection
                                Colors.white,       // Broad highlight
                                Color(0xFFE0E0E0), // Secondary sheen
                                Color(0xFFC0C0C0), // Bottom edge
                              ],
                            ).createShader(bounds),
                            child: ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  accentColor.withValues(alpha: 0.9),
                                  accentColor.withValues(alpha: 0.4),
                                ],
                              ).createShader(bounds),
                              child: Text(
                                lastPart,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 33, // Slightly larger for pop
                                  fontWeight: FontWeight.w900, // Thicker for metal feel
                                  height: 1.1,
                                  letterSpacing: -1.0, // Tighter for impact
                                  shadows: [
                                    // Layer 1: Arcane Glow (Bloom)
                                    Shadow(
                                      color: accentColor.withValues(alpha: 0.8),
                                      blurRadius: 15,
                                      offset: const Offset(0, 0),
                                    ),
                                    // Layer 2: Metallic Depth
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
                const SizedBox(height: 16),
                
                // Description with improved styling
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                
                // Professional Action Buttons
                Row(
                  children: [
                    // Resume Button with Gradient
                    GestureDetector(
                      onTap: onResume,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accentColor, accentColor.withValues(alpha: 0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                            SizedBox(width: 6),
                            Text(
                              'Resume',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
