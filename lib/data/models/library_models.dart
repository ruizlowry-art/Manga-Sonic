class LibraryCategory {
  final String id;
  final String name;

  LibraryCategory({required this.id, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};
  factory LibraryCategory.fromMap(Map<dynamic, dynamic> map) {
    return LibraryCategory(id: map['id'], name: map['name']);
  }
}

class LibraryItem {
  final String mangaUrl;
  final String title;
  final String coverUrl;
  final String sourceId;
  final String categoryId;
  final int addedAt;

  LibraryItem({
    required this.mangaUrl,
    required this.title,
    required this.coverUrl,
    required this.sourceId,
    required this.categoryId,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() => {
    'mangaUrl': mangaUrl,
    'title': title,
    'coverUrl': coverUrl,
    'sourceId': sourceId,
    'categoryId': categoryId,
    'addedAt': addedAt,
  };

  factory LibraryItem.fromMap(Map<dynamic, dynamic> map) {
    return LibraryItem(
      mangaUrl: map['mangaUrl'],
      title: map['title'],
      coverUrl: map['coverUrl'],
      sourceId: map['sourceId'],
      categoryId: map['categoryId'],
      addedAt: map['addedAt'] ?? 0,
    );
  }
}
