import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:manga_sonic/data/db/download_db.dart';
import 'package:manga_sonic/data/db/history_db.dart';
import 'package:manga_sonic/data/models/models.dart';
import 'package:manga_sonic/utils/parser_factory.dart';
import 'package:manga_sonic/utils/memory_safety_manager.dart';
import 'package:manga_sonic/utils/cloudflare_interceptor.dart';
import 'package:manga_sonic/features/library/reader_page.dart';
import 'package:manga_sonic/features/library/reader_widgets.dart';

class ChapterReaderScreen extends StatefulWidget {
  final List<Chapter> allChapters;
  final int initialIndex;
  final int initialPage;
  final double initialOffset;
  final String sourceId;

  const ChapterReaderScreen({
    super.key,
    required this.allChapters,
    required this.initialIndex,
    this.initialPage = 0,
    this.initialOffset = 0.0,
    required this.sourceId,
  });

  @override
  State<ChapterReaderScreen> createState() => _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  late ScrollController _scrollController;
  final GlobalKey _centerKey = GlobalKey();

  final List<ReaderPage> _forwardPages = [];
  final List<ReaderPage> _backwardPages = [];

  bool _isLoading = true;
  bool _isFetchingNext = false;
  bool _isFetchingPrev = false;

  int _topChapterIndex = 0;
  int _bottomChapterIndex = 0;

  StreamSubscription? _memoryPressureSub;
  bool _emergencyMode = false;

  final ValueNotifier<String> _chapterTitleNotifier = ValueNotifier('');
  final ValueNotifier<String> _pageInfoNotifier = ValueNotifier('');
  final ValueNotifier<bool> _showUINotifier = ValueNotifier(true);

  final ValueNotifier<({int start, int end})> _visibilityWindowNotifier =
      ValueNotifier((start: -1, end: -1));

  DateTime _lastSaveTime = DateTime.now();
  DateTime _lastVisibilityUpdate = DateTime.now();
  final Set<String> _loadedChapterUrls = {};

  @override
  void initState() {
    super.initState();
    _topChapterIndex = widget.initialIndex;
    _bottomChapterIndex = widget.initialIndex;
    _chapterTitleNotifier.value = widget.allChapters[widget.initialIndex].title;

    _scrollController = ScrollController();
    _scrollController.addListener(_onCombinedListener);

    _fetchInitialChapter();
    _listenToMemoryPressure();
    MemorySafetyManager().registerReaderVisible();
  }

  void _listenToMemoryPressure() {
    _memoryPressureSub = MemorySafetyManager().lowMemoryStream.listen((isLow) {
      if (mounted) {
        setState(() {
          _emergencyMode = isLow;
        });
        _updateVisibilityWindow();
      }
    });
  }

  void _onCombinedListener() {
    _onScroll();
    _updateVisibilityWindow();
  }

  void _updateVisibilityWindow() {
    if (!_scrollController.hasClients) return;

    final now = DateTime.now();
    if (now.difference(_lastVisibilityUpdate) <
        const Duration(milliseconds: 100)) {
      return;
    }
    _lastVisibilityUpdate = now;

    final allPages = [..._backwardPages.reversed, ..._forwardPages];
    if (allPages.isEmpty) return;

    final viewportHeight = _scrollController.position.viewportDimension;

    // Find the first visible page (top edge within viewport)
    int firstVisibleIndex = -1;
    int lastVisibleIndex = -1;

    for (int i = 0; i < allPages.length; i++) {
      final page = allPages[i];
      if (page.isSeparator) continue;
      final ctx = page.key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;

      final pos = box.localToGlobal(Offset.zero);
      final pageBottom = pos.dy + box.size.height;

      // Page is visible if any part is in viewport (0 to viewportHeight)
      if (pageBottom > 0 && pos.dy < viewportHeight) {
        if (firstVisibleIndex == -1) firstVisibleIndex = i;
        lastVisibleIndex = i;
      }
    }

    // Fallback to center-based calculation if no visible page found
    if (firstVisibleIndex == -1) {
      int centerIndex = -1;
      double closestToCenter = double.infinity;
      for (int i = 0; i < allPages.length; i++) {
        final page = allPages[i];
        if (page.isSeparator) continue;
        final ctx = page.key.currentContext;
        if (ctx == null) continue;
        final box = ctx.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) continue;
        final pos = box.localToGlobal(Offset.zero);
        final centerDelta = (pos.dy - (viewportHeight / 2)).abs();
        if (centerDelta < closestToCenter) {
          closestToCenter = centerDelta;
          centerIndex = i;
        }
      }
      if (centerIndex != -1) {
        firstVisibleIndex = centerIndex;
        lastVisibleIndex = centerIndex;
      }
    }

    if (firstVisibleIndex != -1) {
      // Keep extra buffer above viewport to prevent unloading visible images
      final backwardCount = _emergencyMode ? 3 : 8;
      final forwardCount = _emergencyMode ? 8 : 15;

      final newStart =
          (firstVisibleIndex - backwardCount).clamp(0, allPages.length - 1);
      final newEnd =
          (lastVisibleIndex + forwardCount).clamp(0, allPages.length - 1);

      if (_visibilityWindowNotifier.value.start != newStart ||
          _visibilityWindowNotifier.value.end != newEnd) {
        _visibilityWindowNotifier.value = (start: newStart, end: newEnd);
        // Trigger lazy resolution for the newly visible window
        _resolveWindowedRatios();
      }
    }
  }

  /// Resolve aspect ratios only for pages near the current viewport
  void _resolveWindowedRatios() {
    final window = _visibilityWindowNotifier.value;
    if (window.start == -1) return;

    final allPages = [..._backwardPages.reversed, ..._forwardPages];
    
    // Resolve a small window: current visibility range + 3 pages ahead
    final resolveStart = window.start;
    final resolveEnd = (window.end + 3).clamp(0, allPages.length - 1);

    for (int i = resolveStart; i <= resolveEnd; i++) {
      final page = allPages[i];
      if (page.isSeparator || page.aspectRatio != null) continue;
      _resolveSinglePageRatio(page);
    }
  }

  void _resolveSinglePageRatio(ReaderPage page) {
    if (page.aspectRatio != null || page.isSeparator) return;

    final imageUrl = page.url!;
      final referer = 'https://asurascans.com/';
      final provider = page.file != null
          ? FileImage(page.file!)
          : CachedNetworkImageProvider(
              imageUrl,
              headers: {
                ...CloudflareInterceptor.headersForUrl(imageUrl),
                'Referer': referer,
              },
            ) as ImageProvider;

    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      if (mounted) {
        final aspect = info.image.width / info.image.height;
        setState(() {
          page.aspectRatio = aspect;
        });
      }
      stream.removeListener(listener);
    });
    stream.addListener(listener);
  }

  @override
  void dispose() {
    MemorySafetyManager().unregisterReaderVisible();
    _memoryPressureSub?.cancel();
    _scrollController.removeListener(_onCombinedListener);
    _scrollController.dispose();
    _chapterTitleNotifier.dispose();
    _pageInfoNotifier.dispose();
    _showUINotifier.dispose();
    _visibilityWindowNotifier.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_forwardPages.isEmpty && _backwardPages.isEmpty) return;
    _trackProgress();
    _checkLoadThresholds();
  }

  void _trackProgress() {
    final now = DateTime.now();
    if (now.difference(_lastSaveTime) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastSaveTime = now;

    bool foundVisible = false;

    for (int i = _backwardPages.length - 1; i >= 0 && !foundVisible; i--) {
      final page = _backwardPages[i];
      if (page.isSeparator) continue;
      final ctx = page.key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final pos = box.localToGlobal(Offset.zero);
      foundVisible = _processPageForTracking(
        page,
        pos.dy,
        pos.dy + box.size.height,
        isForward: false,
        localIndex: i,
      );
    }

    for (int i = 0; i < _forwardPages.length && !foundVisible; i++) {
      final page = _forwardPages[i];
      if (page.isSeparator) continue;
      final ctx = page.key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final pos = box.localToGlobal(Offset.zero);
      foundVisible = _processPageForTracking(
        page,
        pos.dy,
        pos.dy + box.size.height,
        isForward: true,
        localIndex: i,
      );
    }
  }

  bool _processPageForTracking(
    ReaderPage page,
    double top,
    double bottom, {
    required bool isForward,
    required int localIndex,
  }) {
    if (bottom < 0) {
      bool isLastOfChapter;
      if (isForward) {
        isLastOfChapter = localIndex == _forwardPages.length - 1 ||
            _forwardPages[localIndex + 1].chapterUrl != page.chapterUrl;
      } else {
        isLastOfChapter = localIndex == 0 ||
            _backwardPages[localIndex - 1].chapterUrl != page.chapterUrl;
      }
      if (isLastOfChapter && !HistoryDB.isRead(page.chapterUrl)) {
        HistoryDB.markAsRead(page.chapterUrl, isRead: true);
      }
      return false;
    }

    if (bottom > 10) {
      final offsetWithinPage = top < 0 ? top.abs() : 0.0;

      int pageIndexInChapter = 0;
      if (isForward) {
        for (int k = localIndex - 1; k >= 0; k--) {
          final p = _forwardPages[k];
          if (p.isSeparator) continue;
          if (p.chapterUrl == page.chapterUrl) {
            pageIndexInChapter++;
          } else {
            break;
          }
        }
        if (localIndex == 0 ||
            (localIndex > 0 &&
                _forwardPages[0].chapterUrl == page.chapterUrl)) {
          for (final p in _backwardPages) {
            if (p.isSeparator) continue;
            if (p.chapterUrl == page.chapterUrl) {
              pageIndexInChapter++;
            }
          }
        }
      } else {
        for (int k = localIndex + 1; k < _backwardPages.length; k++) {
          final p = _backwardPages[k];
          if (p.isSeparator) continue;
          if (p.chapterUrl == page.chapterUrl) {
            pageIndexInChapter++;
          } else {
            break;
          }
        }
      }

      int totalPages = 0;
      for (final p in _backwardPages) {
        if (!p.isSeparator && p.chapterUrl == page.chapterUrl) totalPages++;
      }
      for (final p in _forwardPages) {
        if (!p.isSeparator && p.chapterUrl == page.chapterUrl) totalPages++;
      }

      _chapterTitleNotifier.value = page.chapterTitle;
      _pageInfoNotifier.value = '${pageIndexInChapter + 1} / $totalPages';

      HistoryDB.saveProgress(
        page.chapterUrl,
        pageIndexInChapter,
        lastPageOffset: offsetWithinPage,
      );
      return true;
    }

    return false;
  }

  void _checkLoadThresholds() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

    if (pos.pixels < pos.minScrollExtent + 3000) {
      if (!_isFetchingPrev &&
          _topChapterIndex < widget.allChapters.length - 1) {
        _loadPrevChapter();
      }
    }

    if (pos.pixels > pos.maxScrollExtent - 3000) {
      if (!_isFetchingNext && _bottomChapterIndex > 0) {
        _loadNextChapter();
      }
    }
  }

  Future<void> _fetchInitialChapter() async {
    final chapter = widget.allChapters[widget.initialIndex];
    final pages = await _fetchChapterPages(chapter);
    if (pages == null) return;

    _loadedChapterUrls.add(chapter.url);

    final splitIndex = widget.initialPage.clamp(0, pages.length);

    if (splitIndex > 0) {
      _backwardPages.addAll(pages.sublist(0, splitIndex).reversed);
    }
    _forwardPages.addAll(pages.sublist(splitIndex));

    setState(() => _isLoading = false);

    if (widget.initialOffset > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(widget.initialOffset.clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ));
        }
      });
    }


    _prefetchAdjacentChapters();
    // Removed: _startHeadlessResolution (we now use _resolveWindowedRatios lazily)
  }

  // Removed _startHeadlessResolution in favor of windowed lazy resolution

  Future<List<ReaderPage>?> _fetchChapterPages(Chapter chapter) async {
    List<ReaderPage> pages = [];

    if (DownloadDB.isDownloaded(chapter.url)) {
      final download = DownloadDB.getDownload(chapter.url);
      if (download != null) {
        final dir = Directory(download.directoryPath);
        if (await dir.exists()) {
          final files = dir.listSync().whereType<File>().toList();
          files.sort((a, b) => a.path.compareTo(b.path));
          pages = files
              .map((f) => ReaderPage(
                    chapterUrl: chapter.url,
                    chapterTitle: chapter.title,
                    file: f,
                  ))
              .toList();
        }
      }
    }

    if (pages.isEmpty) {
      final parser = getParserForSite(widget.sourceId);
      try {
        final urls = await parser.fetchChapterImages(chapter.url);
        pages = urls
            .map((url) => ReaderPage(
                  chapterUrl: chapter.url,
                  chapterTitle: chapter.title,
                  url: url,
                ))
            .toList();
      } catch (e) {
        debugPrint('Chapter fetch error: $e');
        if (mounted) _showOfflineDialog();
        return null;
      }
    }

    for (int i = 0; i < pages.length && i < 5; i++) {
      final url = pages[i].url;
      if (url != null) {
        try {
          CachedNetworkImageProvider(
            url,
            headers: {
              ...CloudflareInterceptor.headersForUrl(url),
              'Referer': 'https://asurascans.com/',
            },
          ).resolve(ImageConfiguration.empty);
        } catch (_) {}
      }
    }

    return pages;
  }

  void _showOfflineDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Offline'),
        content: const Text(
          'This chapter has not been downloaded and cannot be viewed offline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((_) {
      if (mounted && _forwardPages.isEmpty && _backwardPages.isEmpty) {
        Navigator.pop(context);
      }
    });
  }

  void _loadNextChapter() {
    if (_isFetchingNext) return;
    final nextIndex = _bottomChapterIndex - 1;
    if (nextIndex < 0) return;
    final chapter = widget.allChapters[nextIndex];
    if (_loadedChapterUrls.contains(chapter.url)) return;

    _isFetchingNext = true;

    _fetchChapterPages(chapter).then((pages) {
      if (pages != null && pages.isNotEmpty && mounted) {
        _loadedChapterUrls.add(chapter.url);
        _bottomChapterIndex = nextIndex;

        final separator = ReaderPage(
          chapterUrl: chapter.url,
          chapterTitle: chapter.title,
          isSeparator: true,
        );

        setState(() {
          _forwardPages.add(separator);
          _forwardPages.addAll(pages);
          _isFetchingNext = false;
        });
        // Removed: _startHeadlessResolution
      } else if (mounted) {
        _isFetchingNext = false;
      }
    });
  }

  void _loadPrevChapter() {
    if (_isFetchingPrev) return;
    final prevIndex = _topChapterIndex + 1;
    if (prevIndex >= widget.allChapters.length) return;
    final chapter = widget.allChapters[prevIndex];
    if (_loadedChapterUrls.contains(chapter.url)) return;

    _isFetchingPrev = true;

    _fetchChapterPages(chapter).then((pages) {
      if (pages != null && pages.isNotEmpty && mounted) {
        _loadedChapterUrls.add(chapter.url);
        _topChapterIndex = prevIndex;

        final separator = ReaderPage(
          chapterUrl: chapter.url,
          chapterTitle: chapter.title,
          isSeparator: true,
        );

        setState(() {
          _backwardPages.addAll(pages.reversed);
          _backwardPages.add(separator);
          _isFetchingPrev = false;
        });
        // Removed: _startHeadlessResolution
      } else if (mounted) {
        _isFetchingPrev = false;
      }
    });
  }

  void _prefetchAdjacentChapters() {
    if (_bottomChapterIndex > 0) {
      final nextChapter = widget.allChapters[_bottomChapterIndex - 1];
      if (DownloadDB.isDownloaded(nextChapter.url)) {
        _loadNextChapter();
      }
    }
    if (_topChapterIndex < widget.allChapters.length - 1) {
      final prevChapter = widget.allChapters[_topChapterIndex + 1];
      if (DownloadDB.isDownloaded(prevChapter.url)) {
        _loadPrevChapter();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GestureDetector(
                  onTap: () => _showUINotifier.value = !_showUINotifier.value,
                  child: CustomScrollView(
                    controller: _scrollController,
                    center: _centerKey,
                    cacheExtent: 1200, // Reduced from 2500 for low-RAM safety
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index >= _backwardPages.length) return null;
                            final page = _backwardPages[index];
                            return ValueListenableBuilder(
                              valueListenable: _visibilityWindowNotifier,
                              builder: (context, window, _) {
                                final globalIdx =
                                    _backwardPages.length - 1 - index;
                                final isNear = globalIdx >= window.start &&
                                    globalIdx <= window.end;

                                return MemoryManagedPage(
                                  key: page.key,
                                  page: page,
                                  isNear: isNear,
                                );
                              },
                            );
                          },
                          childCount: _backwardPages.length,
                          addAutomaticKeepAlives: true,
                          findChildIndexCallback: (Key key) {
                            final idx =
                                _backwardPages.indexWhere((p) => p.key == key);
                            return idx >= 0 ? idx : null;
                          },
                        ),
                      ),
                      SliverList(
                        key: _centerKey,
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index >= _forwardPages.length) return null;
                            final page = _forwardPages[index];
                            return ValueListenableBuilder(
                              valueListenable: _visibilityWindowNotifier,
                              builder: (context, window, _) {
                                final globalIdx =
                                    _backwardPages.length + index;
                                final isNear = globalIdx >= window.start &&
                                    globalIdx <= window.end;

                                return MemoryManagedPage(
                                  key: page.key,
                                  page: page,
                                  isNear: isNear,
                                );
                              },
                            );
                          },
                          childCount: _forwardPages.length,
                          addAutomaticKeepAlives: true,
                          findChildIndexCallback: (Key key) {
                            final idx =
                                _forwardPages.indexWhere((p) => p.key == key);
                            return idx >= 0 ? idx : null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _showUINotifier,
                  builder: (context, showUI, _) => Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      opacity: showUI ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !showUI,
                        child: ValueListenableBuilder<String>(
                          valueListenable: _chapterTitleNotifier,
                          builder: (context, title, _) => AppBar(
                            title: Text(title),
                            backgroundColor:
                                Colors.black.withValues(alpha: 0.7),
                            elevation: 0,
                            leading: IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _showUINotifier,
                  builder: (context, showUI, _) => Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      opacity: showUI ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Center(
                        child: ValueListenableBuilder<String>(
                          valueListenable: _pageInfoNotifier,
                          builder: (context, pageInfo, _) {
                            if (pageInfo.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                pageInfo,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
