import 'dart:async';
import 'package:flutter/material.dart';
import 'package:manga_sonic/features/library/manga_screen.dart';
import 'package:manga_sonic/shared/widgets/manga_grid_card.dart';
import 'package:manga_sonic/data/models/models.dart';
import 'package:manga_sonic/data/db/library_db.dart';
import 'package:manga_sonic/data/db/manga_cache_db.dart';
import 'package:manga_sonic/data/models/library_models.dart';
import 'package:manga_sonic/utils/parser_factory.dart';
import 'package:manga_sonic/utils/cloudflare_interceptor.dart';
import 'package:manga_sonic/utils/palette_utils.dart';
import 'package:manga_sonic/features/browse/widgets/browse_hero.dart';

class SiteScreen extends StatefulWidget {
  final String siteName;
  final String siteUrl;

  const SiteScreen({super.key, required this.siteName, required this.siteUrl});

  @override
  State<SiteScreen> createState() => _SiteScreenState();
}

class _SiteScreenState extends State<SiteScreen> {
  final List<Manga> _mangas = [];
  final List<MangaDetails> _heroMangas = [];
  final Map<String, Color> _heroColors = {};
  bool _isLoading = true;
  bool _isHeroLoading = true;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  Timer? _autoScrollTimer;
  int _currentHeroIndex = 0;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 500 &&
          !_isLoading) {
        _currentPage++;
        _fetchData();
      }
    });
    _startAutoScroll();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _pageController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_heroMangas.length > 1 && !_isSearching) {
        final nextIndex = (_currentHeroIndex + 1) % _heroMangas.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final parser = getParserForSite(widget.siteName);
      List<Manga> newMangas;

      if (_isSearching && _searchQuery.isNotEmpty) {
        newMangas = await parser.searchManga(_searchQuery, _currentPage);
      } else {
        newMangas = await parser.fetchMangaList(_currentPage);
        
        // Populate Hero for the first page
        if (_currentPage == 1 && !_isSearching) {
          _fetchHeroDetails(newMangas.take(5).toList());
        }
      }

      if (!mounted) return;
      setState(() {
        _mangas.addAll(newMangas);
        _isLoading = false;
      });
    } catch (e) {
      if (e.toString().contains('403') || e.toString().contains('Cloudflare')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Passing Cloudflare... Please wait.')),
          );
        }
        await CloudflareInterceptor.bypass(widget.siteUrl);
        return _fetchData();
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _fetchHeroDetails(List<Manga> topMangas) async {
    setState(() => _isHeroLoading = true);
    final parser = getParserForSite(widget.siteName);
    
    List<MangaDetails> detailsList = [];
    for (var manga in topMangas) {
      try {
        final details = await parser.fetchMangaDetails(manga);
        detailsList.add(details);
        
        // Extract color in background
        PaletteUtils.extractDominantColor(manga.coverUrl).then((color) {
          if (mounted && color != null) {
            setState(() => _heroColors[manga.url] = color);
          }
        });
      } catch (e) {
        debugPrint('Hero detail fetch error: $e');
      }
    }

    if (mounted) {
      setState(() {
        _heroMangas.clear();
        _heroMangas.addAll(detailsList);
        _isHeroLoading = false;
      });
    }
  }

  void _addToLibrary(MangaDetails details, String url) async {
    final item = LibraryItem(
      mangaUrl: url,
      title: details.title,
      coverUrl: details.coverUrl,
      sourceId: widget.siteName,
      categoryId: 'default',
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await LibraryDB.saveItem(item);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${details.title} to Library')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: _isSearching ? 0 : 480,
            floating: false,
            pinned: true,
            backgroundColor: Colors.black,
            flexibleSpace: _isSearching
                ? null
                : FlexibleSpaceBar(
                    background: _isHeroLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Stack(
                            children: [
                              PageView.builder(
                                controller: _pageController,
                                itemCount: _heroMangas.length,
                                onPageChanged: (index) {
                                  setState(() => _currentHeroIndex = index);
                                  _startAutoScroll(); // Reset timer on manual scroll
                                },
                                itemBuilder: (context, index) {
                                  final details = _heroMangas[index];
                                  final mangaUrl = _mangas.firstWhere((m) => m.title == details.title).url;
                                  return BrowseHero(
                                    details: details,
                                    mangaUrl: mangaUrl,
                                    sourceId: widget.siteName,
                                    accentColor: _heroColors[mangaUrl],
                                    isSaved: LibraryDB.isSaved(mangaUrl),
                                    onAdd: () => _addToLibrary(details, mangaUrl),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MangaScreen(
                                            mangaTitle: details.title,
                                            mangaUrl: mangaUrl,
                                            coverUrl: details.coverUrl,
                                            sourceId: widget.siteName,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              // Page Indicator Dots
                              Positioned(
                                bottom: 85,
                                left: 20,
                                child: Row(
                                  children: List.generate(
                                    _heroMangas.length,
                                    (index) => AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      margin: const EdgeInsets.only(right: 6),
                                      height: 4,
                                      width: _currentHeroIndex == index ? 20 : 6,
                                      decoration: BoxDecoration(
                                        color: _currentHeroIndex == index
                                            ? (_heroColors[_mangas.firstWhere((m) => m.title == _heroMangas[index].title).url] ?? Colors.white)
                                            : Colors.white24,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search manga...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.white54),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (value) {
                      setState(() {
                        _searchQuery = value.trim();
                        _mangas.clear();
                        _currentPage = 1;
                        _heroMangas.clear();
                      });
                      _fetchData();
                    },
                  )
                : Text(widget.siteName),
            actions: [
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    if (_isSearching) {
                      _isSearching = false;
                      _searchController.clear();
                      _searchQuery = '';
                      _mangas.clear();
                      _currentPage = 1;
                      _fetchData();
                    } else {
                      _isSearching = true;
                    }
                  });
                },
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(8.0),
            sliver: _mangas.isEmpty
                ? SliverToBoxAdapter(
                    child: SizedBox(
                      height: 250,
                      child: Center(
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.menu_book_outlined,
                                    size: 48,
                                    color: Colors.white24,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _isSearching
                                        ? 'No manga found for "$_searchQuery"'
                                        : 'No manga loaded. Tap to retry.',
                                    style: const TextStyle(color: Colors.white54),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _fetchData,
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  )
                : SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= _mangas.length) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final manga = _mangas[index];
                        return MangaGridCard(
                          title: manga.title,
                          coverUrl: manga.coverUrl,
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
                        );
                      },
                      childCount: _mangas.length + (_isLoading ? 3 : 0),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

