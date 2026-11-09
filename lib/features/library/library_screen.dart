import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manga_sonic/data/db/library_db.dart';
import 'package:manga_sonic/data/db/history_db.dart';
import 'package:manga_sonic/data/db/manga_cache_db.dart';
import 'package:manga_sonic/data/models/library_models.dart';
import 'package:manga_sonic/features/library/manga_screen.dart';
import 'package:manga_sonic/features/library/widgets/library_hero.dart';
import 'package:manga_sonic/features/library/widgets/library_manga_card.dart';
import 'package:manga_sonic/features/library/chapter_reader_screen.dart';
import 'package:manga_sonic/utils/library_update_service.dart';
import 'package:manga_sonic/utils/recently_read_resolver.dart';
import 'package:manga_sonic/services/theme_service.dart';
import 'package:manga_sonic/shared/mixins/selection_mode_mixin.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SelectionModeMixin {
  late List<LibraryCategory> _categories;
  late List<LibraryItem> _items;
  String _selectedCategoryId = 'all';
  bool _showOnlyUnread = false;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      final dbCategories = LibraryDB.getCategories();
      _categories = [
        LibraryCategory(id: 'all', name: 'All'),
        ...dbCategories,
      ];
      _items = LibraryDB.getItems();

      if (!_categories.any((c) => c.id == _selectedCategoryId)) {
        _selectedCategoryId = 'all';
      }
    });
  }

  void _addCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Category Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final id = DateTime.now().millisecondsSinceEpoch.toString();
                await LibraryDB.addCategory(LibraryCategory(
                  id: id,
                  name: controller.text,
                ));
                _loadData();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteSelected() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected?'),
        content: Text('Remove ${selectedIds.length} items from library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              for (final id in selectedIds) {
                await LibraryDB.removeItem(id);
              }
              exitSelectionMode();
              _loadData();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = _searchController.text.toLowerCase();

    final recentlyRead = RecentlyReadResolver.resolve(_items);
    final recentlyReadUrl = recentlyRead?.manga.url;

    final filteredItems = _items.where((i) {
      final matchesCategory =
          _selectedCategoryId == 'all' || i.categoryId == _selectedCategoryId;
      final matchesSearch = i.title.toLowerCase().contains(searchQuery);
      final isNotRecentlyRead = i.mangaUrl != recentlyReadUrl;
      
      bool matchesUnread = true;
      if (_showOnlyUnread) {
        matchesUnread = LibraryUpdateService.hasUpdate(i.mangaUrl);
      }

      return matchesCategory && matchesSearch && isNotRecentlyRead && matchesUnread;
    }).toList();

    final List<LibraryItem> currentItems;
    if (_selectedCategoryId == 'all') {
      final seenUrls = <String>{};
      currentItems =
          filteredItems.where((item) => seenUrls.add(item.mangaUrl)).toList();
    } else {
      currentItems = filteredItems;
    }

    // Sort by date added (latest first)
    currentItems.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    context.watch<LibraryUpdateService>(); // Trigger rebuild on updates
    
    // Update theme based on recently read manga
    if (recentlyRead != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ThemeService>().updateThemeFromImage(recentlyRead.manga.coverUrl);
      });
    }

    final themeService = Provider.of<ThemeService>(context);
    final accentColor = themeService.primaryColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _isSearching || isSelecting
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: _isSearching
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() {
                          _isSearching = false;
                          _searchController.clear();
                        });
                      },
                    )
                  : null,
              centerTitle: true,
              title: isSelecting
                  ? Text('${selectedIds.length} Selected')
                  : _isSearching
                      ? TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Search library...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.white54),
                          ),
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                          onChanged: (_) => setState(() {}),
                        )
                      : null,
              actions: isSelecting
                  ? [
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _deleteSelected,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: exitSelectionMode,
                      ),
                    ]
                  : [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _isSearching = false;
                            _searchController.clear();
                          });
                        },
                      ),
                    ],
            )
          : null,
      body: CustomScrollView(
        slivers: [
          if (!_isSearching && !isSelecting)
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  if (recentlyRead != null)
                    LibraryHero(
                      manga: recentlyRead.manga,
                      lastChapter: recentlyRead.chapter,
                      lastPage: recentlyRead.lastPage,
                      description: recentlyRead.description.isEmpty
                          ? recentlyRead.genres.join(', ')
                          : recentlyRead.description,
                      onResume: () {
                        final manga = recentlyRead.manga;
                        final details = MangaCacheDB.getDetails(manga.url);
                        if (details != null) {
                          final chapter = recentlyRead.chapter;
                          final index = details.chapters
                              .indexWhere((c) => c.url == chapter.url);
                          if (index != -1) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChapterReaderScreen(
                                  allChapters: details.chapters,
                                  initialIndex: index,
                                  initialPage: recentlyRead.lastPage,
                                  initialOffset: HistoryDB.getLastPageOffset(
                                    chapter.url,
                                  ),
                                  sourceId: manga.sourceId,
                                ),
                              ),
                            ).then((_) => _loadData());
                          }
                        } else {
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
                          ).then((_) => _loadData());
                        }
                      },
                    ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Library',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: ClipOval(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: IconButton(
                                  icon: Icon(Icons.search,
                                      color: accentColor, size: 22),
                                  onPressed: () => setState(() => _isSearching = true),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          if (_isSearching) const SliverToBoxAdapter(child: SizedBox(height: 100)),
          
          // Unified Collection Header & Controls
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 40, 24, 20),
                  child: Text(
                    'Your Collection',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      // Filter Group
                      _buildFilterChip('ALL', !_showOnlyUnread, accentColor, () {
                        setState(() => _showOnlyUnread = false);
                      }),
                      const SizedBox(width: 8),
                      _buildFilterChip('UNREAD', _showOnlyUnread, accentColor, () {
                        setState(() => _showOnlyUnread = true);
                      }),
                      
                      // Divider
                      Container(
                        height: 20,
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      
                      // Category Group
                      ..._categories.map((cat) {
                        final isSelected = cat.id == _selectedCategoryId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildCategoryChip(cat.name, isSelected, accentColor, () {
                            if (isSelecting) return;
                            setState(() => _selectedCategoryId = cat.id);
                          }),
                        );
                      }),
                      
                      // Add Category Button in section
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
                        onPressed: _addCategoryDialog,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = currentItems[index];
                  final isSelected = selectedIds.contains(item.mangaUrl);

                  return LibraryMangaCard(
                    title: item.title,
                    coverUrl: item.coverUrl,
                    mangaUrl: item.mangaUrl,
                    isSelected: isSelected,
                    hasUpdate: LibraryUpdateService.hasUpdate(item.mangaUrl),
                    isUnread: LibraryUpdateService.hasUpdate(item.mangaUrl),
                    accentColor: accentColor,
                    onTap: () {
                      if (isSelecting) {
                        toggleSelection(item.mangaUrl);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MangaScreen(
                              mangaTitle: item.title,
                              mangaUrl: item.mangaUrl,
                              coverUrl: item.coverUrl,
                              sourceId: item.sourceId,
                            ),
                          ),
                        ).then((value) => _loadData());
                      }
                    },
                    onLongPress: () => toggleSelection(item.mangaUrl),
                  );
                },
                childCount: currentItems.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected, Color accentColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isSelected ? accentColor : Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, Color accentColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white60,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
