import 'package:hive/hive.dart';

class QueuedTask {
  final String chapterUrl;
  final String chapterTitle;
  final String mangaTitle;
  final String mangaUrl;
  final String coverUrl;
  final String author;
  final List<String> genres;
  final String sourceId;

  QueuedTask({
    required this.chapterUrl,
    required this.chapterTitle,
    required this.mangaTitle,
    required this.mangaUrl,
    required this.coverUrl,
    required this.author,
    required this.genres,
    required this.sourceId,
  });

  Map<String, dynamic> toMap() => {
    'chapterUrl': chapterUrl,
    'chapterTitle': chapterTitle,
    'mangaTitle': mangaTitle,
    'mangaUrl': mangaUrl,
    'coverUrl': coverUrl,
    'author': author,
    'genres': genres,
    'sourceId': sourceId,
  };

  factory QueuedTask.fromMap(Map<dynamic, dynamic> map) {
    return QueuedTask(
      chapterUrl: map['chapterUrl'],
      chapterTitle: map['chapterTitle'],
      mangaTitle: map['mangaTitle'],
      mangaUrl: map['mangaUrl'],
      coverUrl: map['coverUrl'] ?? '',
      author: map['author'] ?? 'Unknown',
      genres: (map['genres'] as List?)?.cast<String>() ?? [],
      sourceId: map['sourceId'],
    );
  }
}

class QueueDB {
  static const String queueBoxName = 'download_queue';

  static Future<void> init() async {
    await Hive.openBox(queueBoxName);
  }

  static List<QueuedTask> getQueue() {
    final box = Hive.box(queueBoxName);
    return box.values.map((e) => QueuedTask.fromMap(e)).toList();
  }

  static Future<void> addToQueue(QueuedTask task) async {
    await Hive.box(queueBoxName).put(task.chapterUrl, task.toMap());
  }

  static Future<void> removeFromQueue(String chapterUrl) async {
    await Hive.box(queueBoxName).delete(chapterUrl);
  }

  static Future<void> clearQueue() async {
    await Hive.box(queueBoxName).clear();
  }
}
