import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:manga_sonic/utils/palette_utils.dart';
import 'package:manga_sonic/data/models/models.dart';

enum HeroCardMode { reading, downloading }

class HeroCard extends StatefulWidget {
  final Manga manga;
  final Chapter? lastChapter;
  final int? lastPage;
  final String description;
  final List<String> genres;
  final VoidCallback onTap;
  final VoidCallback? onContinue;
  final HeroCardMode mode;

  // Download mode specifics
  final List<String>? completedChapters;
  final List<String>? queuedChapters;
  final double? overallProgress;
  final VoidCallback? onCancel;

  // Selection support for Download Mode
  final Set<String>? selectedChapterTitles;
  final Function(String)? onChapterTap;
  final Function(String)? onChapterLongPress;
  final VoidCallback? onSelectAll;
  final VoidCallback? onUnselectAll;

  const HeroCard({
    super.key,
    required this.manga,
    this.lastChapter,
    this.lastPage,
    required this.description,
    this.genres = const [],
    required this.onTap,
    this.onContinue,
    this.mode = HeroCardMode.reading,
    this.completedChapters,
    this.queuedChapters,
    this.overallProgress,
    this.onCancel,
    this.selectedChapterTitles,
    this.onChapterTap,
    this.onChapterLongPress,
    this.onSelectAll,
    this.onUnselectAll,
  });

  @override
  State<HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<HeroCard> {
  Color? _vibrantColor;
  bool _isChaptersExpanded = false;

  @override
  void initState() {
    super.initState();
    PaletteUtils.extractDominantColor(widget.manga.coverUrl).then((color) {
      if (mounted && color != null) setState(() => _vibrantColor = color);
    });
  }

  @override
  void didUpdateWidget(HeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manga.coverUrl != widget.manga.coverUrl) {
      PaletteUtils.extractDominantColor(widget.manga.coverUrl).then((color) {
        if (mounted && color != null) setState(() => _vibrantColor = color);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _vibrantColor ?? theme.primaryColor;
    final isReading = widget.mode == HeroCardMode.reading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: Container(
            height: isReading ? 220 : 200,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                // Dynamic glow effect on borders
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: accent.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 25,
                  spreadRadius: -10,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: widget.manga.coverUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Vertical gradient overlay: intensified black-only vignette
                  Positioned(
                    left: -8,
                    right: -8,
                    top: -8,
                    bottom: -8,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.85),
                            Colors.black.withValues(alpha: 0.65),
                            Colors.black.withValues(alpha: 0.5),
                            Colors.black.withValues(alpha: 0.35),
                            Colors.black.withValues(alpha: 0.35),
                            Colors.black.withValues(alpha: 0.5),
                            Colors.black.withValues(alpha: 0.65),
                            Colors.black.withValues(alpha: 0.85),
                          ],
                          stops: const [0.0, 0.12, 0.3, 0.45, 0.55, 0.7, 0.88, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Horizontal gradient overlay: black on left side (cover area)
                  Positioned(
                    left: -8,
                    right: -8,
                    top: -8,
                    bottom: -8,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            // Left (cover area): Strong black
                            Colors.black.withValues(alpha: 0.85),
                            // Center-left: Fading out
                            Colors.black.withValues(alpha: 0.5),
                            // Center: Lighter
                            Colors.black.withValues(alpha: 0.2),
                            // Right: Transparent
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.25, 0.45, 0.7],
                        ),
                      ),
                    ),
                  ),
                  // Horizontal gradient overlay: black on right side
                  Positioned(
                    left: -8,
                    right: -8,
                    top: -8,
                    bottom: -8,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            // Right: Strong black
                            Colors.black.withValues(alpha: 0.85),
                            // Center-right: Fading out
                            Colors.black.withValues(alpha: 0.5),
                            // Center: Lighter
                            Colors.black.withValues(alpha: 0.2),
                            // Left: Transparent
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.25, 0.45, 0.7],
                        ),
                      ),
                    ),
                  ),
                  // Stronger blur on middle section
                  Positioned(
                    left: -8,
                    right: -8,
                    top: 60,
                    bottom: 60,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'hero-cover-${widget.manga.url}-${widget.mode.name}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: widget.manga.coverUrl,
                              width: 90,
                              height: 135,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isReading ? 'RECENTLY READ' : 'DOWNLOADING',
                                style: TextStyle(
                                  color: accent.withValues(alpha: 0.8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.manga.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Text(
                                  widget.description,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isReading && widget.genres.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    widget.genres.join(' • '),
                                    style: TextStyle(
                                      color: accent.withValues(alpha: 0.6),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              const SizedBox(height: 12),
                              _buildActionArea(accent, theme),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isReading && _isChaptersExpanded) _buildChaptersList(accent),
      ],
    );
  }

  Widget _buildActionArea(Color accent, ThemeData theme) {
    if (widget.mode == HeroCardMode.reading) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.lastChapter?.title ?? 'Chapter Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Page ${widget.lastPage! + 1}',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: widget.onContinue,
            child: const Text('CONTINUE',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
          ),
        ],
      );
    } else {
      final total = (widget.completedChapters?.length ?? 0) +
          (widget.queuedChapters?.length ?? 0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: widget.overallProgress,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation(accent),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon:
                    const Icon(Icons.cancel, color: Colors.white54, size: 22),
                onPressed: widget.onCancel,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () =>
                    setState(() => _isChaptersExpanded = !_isChaptersExpanded),
                child: Row(
                  children: [
                    Text(
                      '${widget.completedChapters?.length ?? 0} / $total Chapters',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                    Icon(
                      _isChaptersExpanded
                          ? Icons.arrow_drop_up
                          : Icons.arrow_drop_down,
                      color: accent,
                      size: 18,
                    ),
                  ],
                ),
              ),
              Text(
                '${((widget.overallProgress ?? 0) * 100).toInt()}%',
                style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildChaptersList(Color accent) {
    final all = [
      ...widget.completedChapters ?? [],
      ...widget.queuedChapters ?? []
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxHeight: 150),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onSelectAll != null || widget.onUnselectAll != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.onSelectAll != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: widget.onSelectAll,
                      child: Text(
                        'Select All',
                        style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (widget.onUnselectAll != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: widget.onUnselectAll,
                      child: const Text(
                        'Unselect All',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: all.length,
              itemBuilder: (context, index) {
                final chap = all[index];
                final isDone =
                    widget.completedChapters?.contains(chap) ?? false;
                final isSelected =
                    widget.selectedChapterTitles?.contains(chap) ?? false;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      onTap: widget.onChapterTap != null
                          ? () => widget.onChapterTap!(chap)
                          : null,
                      onLongPress: widget.onChapterLongPress != null
                          ? () => widget.onChapterLongPress!(chap)
                          : null,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      tileColor:
                          isSelected ? accent.withValues(alpha: 0.15) : null,
                      leading: Icon(
                        isSelected
                            ? Icons.check_box
                            : (isDone
                                ? Icons.check_circle
                                : Icons.downloading),
                        size: 16,
                        color: isSelected
                            ? accent
                            : (isDone
                                ? Colors.greenAccent
                                : accent.withValues(alpha: 0.6)),
                      ),
                      title: Text(
                        chap,
                        style: TextStyle(
                          color:
                              isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check, color: accent, size: 14)
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
