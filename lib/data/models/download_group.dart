import 'package:manga_sonic/data/db/download_db.dart';
import 'package:manga_sonic/utils/download_manager.dart';

class MangaDownloadGroup {
  final String mangaTitle;
  final String mangaUrl;
  final String coverUrl;
  final String author;
  final List<String> genres;
  final List<DownloadedChapter> completedChapters = [];
  final List<DownloadTask> activeTasks = [];

  MangaDownloadGroup({
    required this.mangaTitle,
    required this.mangaUrl,
    required this.coverUrl,
    required this.author,
    required this.genres,
  });
}
