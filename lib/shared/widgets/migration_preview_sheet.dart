import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:manga_sonic/data/models/models.dart';
import 'package:manga_sonic/utils/parser_factory.dart';
import 'package:manga_sonic/utils/migration_utils.dart';
import 'package:manga_sonic/utils/palette_utils.dart';
import 'package:manga_sonic/shared/widgets/source_tag.dart';
import 'package:manga_sonic/shared/widgets/info_row.dart';
import 'package:manga_sonic/shared/widgets/safe_blurred_cover_background.dart';
import 'package:manga_sonic/features/library/manga_screen.dart';

class MigrationPreviewSheet extends StatefulWidget {
  final Manga targetManga;
  final Manga sourceManga;
  final List<Chapter> sourceChapters;

  const MigrationPreviewSheet({
    super.key,
    required this.targetManga,
    required this.sourceManga,
    required this.sourceChapters,
  });

  @override
  State<MigrationPreviewSheet> createState() => _MigrationPreviewSheetState();
}

class _MigrationPreviewSheetState extends State<MigrationPreviewSheet> {
  MangaDetails? _details;
  bool _isLoading = true;
  Color? _dominantColor;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
    PaletteUtils.extractDominantColor(widget.targetManga.coverUrl).then((color) {
      if (mounted && color != null) setState(() => _dominantColor = color);
    });
  }

  Future<void> _fetchDetails() async {
    try {
      final parser = getParserForSite(widget.targetManga.sourceId);
      final details = await parser.fetchMangaDetails(widget.targetManga);
      if (mounted) {
        setState(() {
          _details = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _dominantColor ?? Colors.deepPurpleAccent;
    final isDark = ThemeData.estimateBrightnessForColor(accent) == Brightness.dark;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.grey[950],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          if (!_isLoading && _error == null)
            SafeBlurredCoverBackground(
              imageUrl: widget.targetManga.coverUrl,
              dominantColor: _dominantColor,
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_error != null)
                  Center(
                    child: Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  )
                else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: widget.targetManga.coverUrl,
                          width: 100,
                          height: 140,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.targetManga.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            SourceTag(
                              sourceId: widget.targetManga.sourceId,
                              accentColor: accent,
                              showIcon: false,
                            ),
                            const SizedBox(height: 12),
                            InfoRow(icon: Icons.person_outline, text: _details!.author),
                            InfoRow(icon: Icons.info_outline, text: _details!.status),
                            InfoRow(icon: Icons.list, text: '${_details!.chapters.length} Chapters'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _details!.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: isDark ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                        shadowColor: accent.withValues(alpha: 0.5),
                      ),
                      onPressed: () async {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const Center(child: CircularProgressIndicator()),
                        );

                        await MigrationUtils.transferProgress(
                          oldManga: widget.sourceManga,
                          newManga: widget.targetManga,
                          oldChapters: widget.sourceChapters,
                          newChapters: _details!.chapters,
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                          Navigator.pop(context);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MangaScreen(
                                mangaTitle: widget.targetManga.title,
                                mangaUrl: widget.targetManga.url,
                                coverUrl: widget.targetManga.coverUrl,
                                sourceId: widget.targetManga.sourceId,
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'MIGRATE NOW',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
