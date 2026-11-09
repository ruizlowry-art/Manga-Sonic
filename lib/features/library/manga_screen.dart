import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:manga_sonic/features/library/chapter_reader_screen.dart';
import 'package:manga_sonic/data/models/models.dart';
import 'package:manga_sonic/data/db/library_db.dart';
import 'package:manga_sonic/data/db/download_db.dart';
import 'package:manga_sonic/data/db/history_db.dart';
import 'package:manga_sonic/data/db/manga_cache_db.dart';
import 'package:manga_sonic/data/models/library_models.dart';
import 'package:manga_sonic/utils/parser_factory.dart';
import 'package:manga_sonic/utils/download_manager.dart';
import 'package:manga_sonic/shared/widgets/source_tag.dart';
import 'package:manga_sonic/shared/widgets/info_row.dart';
import 'package:manga_sonic/utils/cloudflare_interceptor.dart';
import 'package:manga_sonic/utils/palette_utils.dart';
import 'package:manga_sonic/utils/source_registry.dart';
import 'package:manga_sonic/shared/widgets/migration_preview_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:manga_sonic/shared/widgets/safe_blurred_cover_background.dart';
import 'package:manga_sonic/features/library/manga_screen_widgets.dart';

class MangaScreen extends StatefulWidget {
  final String mangaTitle;
  final String mangaUrl;
  final String coverUrl;
  final String sourceId;

  const MangaScreen({
    super.key,
    required this.mangaTitle,
    required this.mangaUrl,
    required this.coverUrl,
    required this.sourceId,
  });

  @override
  State<MangaScreen> createState() => _MangaScreenState();
}

class _MangaScreenState extends State<MangaScreen> {
  MangaDetails? _details;
  bool _isLoading = true;
  bool _isSaved = false;
  bool _isDescriptionExpanded = false;
  final ScrollController _scrollController = ScrollController();
  double _opacity = 0.0;
  Color? _dominantColor;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _isSaved = LibraryDB.isSaved(widget.mangaUrl);
    _fetchData();
    _scrollController.addListener(_onScroll);
    PaletteUtils.extractDominantColor(widget.coverUrl).then((color) {
      if (mounted && color != null) setState(() => _dominantColor = color);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset <= 200) {
      setState(() => _opacity = _scrollController.offset / 200);
    } else if (_opacity != 1.0) {
      setState(() => _opacity = 1.0);
    }
  }

  Future<void> _fetchData() async {
    final cachedDetails = MangaCacheDB.getDetails(widget.mangaUrl);

    if (cachedDetails != null) {
      if (mounted) {
        setState(() {
          _details = cachedDetails;
          _isLoading = false;
        });
      }
      _syncOnline();
    } else {
      setState(() {
        _isLoading = true;
        _isOffline = false;
      });
      await _syncOnline();
    }
  }

  Future<void> _syncOnline() async {
    try {
      final parser = getParserForSite(widget.sourceId);
      final manga = Manga(
        title: widget.mangaTitle,
        url: widget.mangaUrl,
        coverUrl: widget.coverUrl,
        sourceId: widget.sourceId,
      );
      final details = await parser.fetchMangaDetails(manga);

      await MangaCacheDB.saveDetails(widget.mangaUrl, details);

      if (mounted) {
        setState(() {
          _details = details;
          _isLoading = false;
          _isOffline = false;
        });
      }
    } catch (e) {
      debugPrint('Sync error: $e');

      if (e.toString().contains('403') || e.toString().contains('Cloudflare')) {
        if (mounted && _details == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Passing Cloudflare... Please wait.')),
          );
        }
        await CloudflareInterceptor.bypass(widget.mangaUrl);
        return _syncOnline();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_details != null) _isOffline = true;
        });

        if (_details == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Network error: $e')),
          );
        }
      }
    }
  }

  int _findContinueChapterIndex() {
    final chapters = _details?.chapters ?? [];
    if (chapters.isEmpty) return 0;
    for (int i = chapters.length - 1; i >= 0; i--) {
      if (!HistoryDB.isRead(chapters[i].url)) {
        return i;
      }
    }
    return 0;
  }

  void _navigateToChapter(
    int index, {
    int initialPage = 0,
    double initialOffset = 0.0,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterReaderScreen(
          allChapters: _details!.chapters,
          initialIndex: index,
          initialPage: initialPage,
          initialOffset: initialOffset,
          sourceId: widget.sourceId,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_details == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Failed to load manga details.')),
      );
    }

    final chapters = _details!.chapters;
    if (chapters.isEmpty) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: AnimatedOpacity(
            opacity: _opacity,
            duration: const Duration(milliseconds: 200),
            child: Text(widget.mangaTitle),
          ),
        ),
        body: Stack(
          children: [
            SafeBlurredCoverBackground(
              imageUrl: widget.coverUrl,
              dominantColor: _dominantColor,
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'No chapters available for this manga.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final hasStartedReading = chapters.any(
      (ch) => HistoryDB.isRead(ch.url) || HistoryDB.getLastPage(ch.url) > 0,
    );
    final continueIndex = _findContinueChapterIndex();
    final continueChapter = chapters[continueIndex];
    final lastPage = HistoryDB.getLastPage(continueChapter.url);
    final lastOffset = HistoryDB.getLastPageOffset(continueChapter.url);

    final buttonText = !hasStartedReading
        ? 'START READING'
        : 'CONTINUE CHAPTER ${continueChapter.title.replaceAll(RegExp(r'[^0-9.]'), '')}${lastPage > 0 ? ' (Page ${lastPage + 1})' : ''}';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 200),
          child: Text(widget.mangaTitle),
        ),
      ),
      body: Stack(
        children: [
          SafeBlurredCoverBackground(
            imageUrl: widget.coverUrl,
            dominantColor: _dominantColor,
          ),
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: widget.coverUrl,
                              width: 120,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.mangaTitle,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                SourceTag(
                                  sourceId: widget.sourceId,
                                  accentColor: _dominantColor ?? Colors.deepPurpleAccent,
                                ),
                                const SizedBox(height: 12),
                                InfoRow(
                                  icon: Icons.person_outline,
                                  text: _details!.author,
                                ),
                                InfoRow(
                                  icon: Icons.brush_outlined,
                                  text: _details!.artist,
                                ),
                                InfoRow(
                                  icon: Icons.info_outline,
                                  text: _details!.status,
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _details!.genres
                                      .map((g) => _genreTag(g))
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _actionButton(
                                icon: _isSaved
                                    ? Icons.bookmark
                                    : Icons.bookmark_add_outlined,
                                label: _isSaved ? 'In Library' : 'Add to Library',
                                isPrimary: _isSaved,
                                onTap: _toggleSave),
                            _actionButton(
                                icon: Icons.public,
                                label: 'Web View',
                                onTap: () => launchUrl(Uri.parse(widget.mangaUrl))),
                            _actionButton(
                                icon: Icons.sync,
                                label: 'Migration',
                                onTap: _showMigrationSheet),
                            _actionButton(
                              icon: Icons.download_for_offline,
                              label: 'Download Menu',
                              onTap: () => _showDownloadMenu(chapters),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => setState(
                          () => _isDescriptionExpanded = !_isDescriptionExpanded,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _details!.description,
                              maxLines: _isDescriptionExpanded ? null : 4,
                              overflow: _isDescriptionExpanded
                                  ? null
                                  : TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isDescriptionExpanded ? "Show Less" : "Show More",
                              style: TextStyle(
                                color: _dominantColor ?? Colors.deepPurpleAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Text(
                            'CHAPTERS',
                            style: TextStyle(
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white54,
                            ),
                          ),
                          if (_isOffline) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.5),
                                  width: 0.5,
                                ),
                              ),
                              child: const Text(
                                'OFFLINE',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            '${chapters.length} Chapters',
                            style: const TextStyle(color: Colors.white38),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final chapter = chapters[index];
                  final isRead = HistoryDB.isRead(chapter.url);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: Text(
                      chapter.title,
                      style: TextStyle(
                        color: isRead ? Colors.white38 : Colors.white,
                        fontSize: 15,
                        fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                    subtitle: chapter.releaseDate != null
                        ? Row(
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 12,
                                color: Colors.white38,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                chapter.releaseDate!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white38,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          )
                        : null,
                    trailing: DownloadDB.isDownloaded(chapter.url)
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          )
                        : IconButton(
                            icon: const Icon(
                              Icons.download,
                              size: 18,
                              color: Colors.white38,
                            ),
                            onPressed: () => _downloadChapters([chapter]),
                          ),
                    onTap: () => _navigateToChapter(index, initialPage: 0),
                    onLongPress: () => _showChapterMenu(chapter, index),
                  );
                }, childCount: chapters.length),
              ),
              if (_details!.suggestions.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'YOU MIGHT ALSO LIKE',
                      style: TextStyle(
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _details!.suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _details!.suggestions[index];
                        return _suggestionItem(suggestion);
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ],
          ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: (_dominantColor ?? Colors.deepPurpleAccent)
                        .withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _dominantColor ?? Colors.deepPurpleAccent,
                  foregroundColor:
                      ThemeData.estimateBrightnessForColor(
                            _dominantColor ?? Colors.deepPurpleAccent,
                          ) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                onPressed: () => _navigateToChapter(
                  continueIndex,
                  initialPage: lastPage,
                  initialOffset: lastOffset,
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _genreTag(String genre) {
    return GenreTag(genre: genre);
  }

  Widget _suggestionItem(Manga manga) {
    return SuggestionItem(manga: manga);
  }

  void _toggleSave() async {
    if (_isSaved) {
      await LibraryDB.removeItem(widget.mangaUrl);
      setState(() => _isSaved = false);
    } else {
      final categories = LibraryDB.getCategories();
      if (categories.isEmpty) {
        final item = LibraryItem(
          mangaUrl: widget.mangaUrl,
          title: widget.mangaTitle,
          coverUrl: widget.coverUrl,
          sourceId: widget.sourceId,
          categoryId: 'default',
          addedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await LibraryDB.saveItem(item);
        setState(() => _isSaved = true);
        return;
      }
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Add to Category'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return ListTile(
                    title: Text(cat.name),
                    onTap: () async {
                      final item = LibraryItem(
                        mangaUrl: widget.mangaUrl,
                        title: widget.mangaTitle,
                        coverUrl: widget.coverUrl,
                        sourceId: widget.sourceId,
                        categoryId: cat.id,
                        addedAt: DateTime.now().millisecondsSinceEpoch,
                      );
                      await LibraryDB.saveItem(item);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                      if (mounted) {
                        setState(() => _isSaved = true);
                      }
                    },
                  );
                },
              ),
            ),
          );
        },
      );
    }
  }

  Future<void> _downloadChapters(List<Chapter> chapters) async {
    if (chapters.isEmpty) return;

    final downloadList = chapters.length > 1 ? chapters.reversed.toList() : chapters;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Adding ${downloadList.length} chapters to downloads...'),
      ),
    );

    for (var chapter in downloadList) {
      try {
        await DownloadManager().downloadChapter(
          chapterUrl: chapter.url,
          chapterTitle: chapter.title,
          mangaTitle: widget.mangaTitle,
          mangaUrl: widget.mangaUrl,
          coverUrl: widget.coverUrl,
          author: _details?.author ?? 'Unknown',
          genres: _details?.genres ?? [],
          sourceId: widget.sourceId,
        );
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('Error downloading ${chapter.title}: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Batch download task complete.')),
      );
    }
  }

  void _showMigrationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Migrate Manga',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Manga>>(
                  future: _searchAllSources(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final results = snapshot.data ?? [];
                    if (results.isEmpty) {
                      return const Center(
                        child: Text(
                          'No results found in other sources.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final manga = results[index];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(
                              imageUrl: manga.coverUrl,
                              width: 40,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(
                            manga.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (_dominantColor ?? Colors.deepPurpleAccent).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: (_dominantColor ?? Colors.deepPurpleAccent).withValues(alpha: 0.4),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    SourceRegistry.getDisplayName(manga.sourceId),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => MigrationPreviewSheet(
                                targetManga: manga,
                                sourceManga: Manga(
                                  title: widget.mangaTitle,
                                  url: widget.mangaUrl,
                                  coverUrl: widget.coverUrl,
                                  sourceId: widget.sourceId,
                                ),
                                sourceChapters: _details!.chapters,
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Manga>> _searchAllSources() async {
    final sources = ['asuracomic', 'manhuatop', 'manhuaplus'];
    List<Manga> allResults = [];

    for (var sourceId in sources) {
      if (sourceId == widget.sourceId) continue;
      try {
        final parser = getParserForSite(sourceId);
        final results = await parser.searchManga(widget.mangaTitle, 1);
        allResults.addAll(results);
      } catch (e) {
        debugPrint('Migration search error for $sourceId: $e');
      }
    }
    return allResults;
  }

  void _showChapterMenu(Chapter chapter, int index) {
    final chapters = _details?.chapters ?? [];
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('Mark as Read'),
                onTap: () async {
                  await HistoryDB.markAsRead(chapter.url, isRead: true);
                  if (context.mounted) Navigator.pop(context);
                  if (mounted) setState(() {});
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off),
                title: const Text('Mark as Unread'),
                onTap: () async {
                  await HistoryDB.markAsRead(chapter.url, isRead: false);
                  if (context.mounted) Navigator.pop(context);
                  if (mounted) setState(() {});
                },
              ),
              ListTile(
                leading: const Icon(Icons.vertical_align_bottom),
                title: const Text('Mark all previous as Read'),
                onTap: () async {
                  for (int i = index; i < chapters.length; i++) {
                    await HistoryDB.markAsRead(chapters[i].url, isRead: true);
                  }
                  if (context.mounted) Navigator.pop(context);
                  if (mounted) setState(() {});
                },
              ),
              ListTile(
                leading: const Icon(Icons.vertical_align_top),
                title: const Text('Mark all previous as Unread'),
                onTap: () async {
                  for (int i = index; i < chapters.length; i++) {
                    await HistoryDB.markAsRead(chapters[i].url, isRead: false);
                  }
                  if (context.mounted) Navigator.pop(context);
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return MangaActionButton(
      icon: icon,
      label: label,
      onTap: onTap,
      isPrimary: isPrimary,
      dominantColor: _dominantColor,
    );
  }

  void _showDownloadMenu(List<Chapter> chapters) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download all chapters'),
              onTap: () {
                Navigator.pop(context);
                _downloadChapters(chapters);
              },
            ),
            ListTile(
              leading: const Icon(Icons.unpublished_outlined),
              title: const Text('Download all unread'),
              onTap: () {
                Navigator.pop(context);
                _downloadChapters(
                  chapters.where((c) => !HistoryDB.isRead(c.url)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
