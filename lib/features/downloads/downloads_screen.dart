import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manga_sonic/data/db/download_db.dart';
import 'package:manga_sonic/data/models/models.dart';
import 'package:manga_sonic/utils/download_manager.dart';
import 'package:manga_sonic/utils/chapter_utils.dart';
import 'package:manga_sonic/shared/mixins/selection_mode_mixin.dart';
import 'package:manga_sonic/data/models/download_group.dart';
import 'package:manga_sonic/shared/widgets/hero_card.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen>
    with SelectionModeMixin {
  void _selectAllChapters(List<MangaDownloadGroup> groups) {
    final ids = <String>[];
    for (var group in groups) {
      for (var ch in group.completedChapters) {
        ids.add(ch.chapterUrl);
      }
    }
    selectAll(ids);
  }

  Future<void> _deleteSelected(DownloadManager manager) async {
    final urls = List<String>.from(selectedIds);
    exitSelectionMode();
    for (var url in urls) {
      await manager.deleteChapter(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadManager>(
      builder: (context, manager, child) {
        final downloads = DownloadDB.getDownloads();
        final queue = manager.queue;
        final Map<String, MangaDownloadGroup> groups = {};

        for (var d in downloads) {
          groups
              .putIfAbsent(
                d.mangaUrl,
                () => MangaDownloadGroup(
                  mangaTitle: d.mangaTitle,
                  mangaUrl: d.mangaUrl,
                  coverUrl: d.coverUrl,
                  author: d.author,
                  genres: d.genres,
                ),
              )
              .completedChapters
              .add(d);
        }
        for (var q in queue) {
          groups
              .putIfAbsent(
                q.mangaUrl,
                () => MangaDownloadGroup(
                  mangaTitle: q.mangaTitle,
                  mangaUrl: q.mangaUrl,
                  coverUrl: q.coverUrl,
                  author: q.author,
                  genres: q.genres,
                ),
              )
              .activeTasks
              .add(q);
        }

        for (var g in groups.values) {
          g.completedChapters.sort((a, b) => ChapterUtils.extractNumber(
                  a.chapterTitle)
              .compareTo(ChapterUtils.extractNumber(b.chapterTitle)));
          g.activeTasks.sort((a, b) => ChapterUtils.extractNumber(
                  a.chapterTitle)
              .compareTo(ChapterUtils.extractNumber(b.chapterTitle)));
        }

        final sortedGroups = groups.values.toList();

        return PopScope(
          canPop: !isSelecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && isSelecting) exitSelectionMode();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(isSelecting
                  ? '${selectedIds.length} selected'
                  : 'Download Manager'),
              actions: [
                if (isSelecting) ...[
                  IconButton(
                      icon: const Icon(Icons.select_all),
                      onPressed: () => _selectAllChapters(sortedGroups)),
                  IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: selectedIds.isEmpty
                          ? null
                          : () => _showDeleteConfirmation(context, manager)),
                ] else if (queue.isNotEmpty) ...[
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                ],
              ],
            ),
            body: sortedGroups.isEmpty
                ? const Center(child: Text('No downloads'))
                : ListView.builder(
                    itemCount: sortedGroups.length,
                    itemBuilder: (context, index) {
                      final group = sortedGroups[index];
                      final dummyManga = Manga(
                        title: group.mangaTitle,
                        url: group.mangaUrl,
                        coverUrl: group.coverUrl,
                        sourceId: 'unknown',
                      );

                      double progress = 1.0;
                      if (group.activeTasks.isNotEmpty) {
                        final activeP = group.activeTasks.fold(
                                0.0,
                                (sum, t) =>
                                    sum +
                                    manager.getStatus(t.chapterUrl).progress) /
                            group.activeTasks.length;
                        progress = (group.completedChapters.length + activeP) /
                            (group.completedChapters.length +
                                group.activeTasks.length);
                      }

                      final completed = group.completedChapters
                          .map((c) => c.chapterTitle)
                          .toList();
                      final queued =
                          group.activeTasks.map((c) => c.chapterTitle).toList();

                      final List<dynamic> allInGroup = [
                        ...group.completedChapters,
                        ...group.activeTasks
                      ];

                      return HeroCard(
                        manga: dummyManga,
                        description: group.author,
                        mode: HeroCardMode.downloading,
                        overallProgress: progress,
                        completedChapters: completed,
                        queuedChapters: queued,
                        selectedChapterTitles: selectedIds
                            .map((url) {
                              final ch = allInGroup.firstWhere(
                                (c) => (c is DownloadedChapter
                                        ? c.chapterUrl
                                        : (c as DownloadTask).chapterUrl) ==
                                    url,
                                orElse: () => null,
                              );
                              return ch?.chapterTitle ?? '';
                            })
                            .where((title) => title.isNotEmpty)
                            .toSet()
                            .cast<String>(),
                        onChapterTap: (title) {
                          final ch = allInGroup.firstWhere(
                              (c) => c.chapterTitle == title);
                          final url = ch is DownloadedChapter
                              ? ch.chapterUrl
                              : (ch as DownloadTask).chapterUrl;
                          toggleSelection(url);
                        },
                        onChapterLongPress: (title) {
                          final ch = allInGroup.firstWhere(
                              (c) => c.chapterTitle == title);
                          final url = ch is DownloadedChapter
                              ? ch.chapterUrl
                              : (ch as DownloadTask).chapterUrl;
                          if (!isSelecting) toggleSelection(url);
                        },
                        onCancel: () =>
                            manager.cancelMangaDownloads(group.mangaUrl),
                        onSelectAll: () => selectAll(allInGroup.map((ch) =>
                            ch is DownloadedChapter
                                ? ch.chapterUrl
                                : (ch as DownloadTask).chapterUrl)),
                        onUnselectAll: () {
                          for (var ch in allInGroup) {
                            final url = ch is DownloadedChapter
                                ? ch.chapterUrl
                                : (ch as DownloadTask).chapterUrl;
                            if (selectedIds.contains(url)) toggleSelection(url);
                          }
                        },
                        onTap: () {},
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, DownloadManager manager) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Downloads'),
        content: Text('Delete ${selectedIds.length} selected chapters?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteSelected(manager);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}
