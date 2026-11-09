import 'package:html/parser.dart' as parser;
import 'package:manga_sonic/data/models/models.dart';
import 'base_parser.dart';

class ManhuaPlusParser extends BaseParser {
  ManhuaPlusParser()
    : super(siteName: 'ManhuaPlus', baseUrl: 'https://manhuaplus.top');

  @override
  Future<List<Manga>> fetchMangaList(int page) async {
    final response = await getRequest(
      page == 1 ? '$baseUrl/all-manga/' : '$baseUrl/all-manga/$page/',
    );
    final document = parser.parse(response.body);
    final elements = document.querySelectorAll('.item');

    List<Manga> list = [];
    for (var element in elements) {
      final aTag = element.querySelector('.jtip');
      final imgTag = element.querySelector('img');
      if (aTag != null && imgTag != null) {
        var url = aTag.attributes['href'] ?? '';
        if (url.startsWith('/')) url = '$baseUrl$url';
        final title = aTag.text.trim();
        final coverUrl =
            imgTag.attributes['data-original'] ??
            imgTag.attributes['data-src'] ??
            imgTag.attributes['src'] ??
            '';

        if (url.isNotEmpty && title.isNotEmpty) {
          list.add(
            Manga(
              title: title,
              url: url,
              coverUrl: coverUrl,
              sourceId: 'manhuaplus',
            ),
          );
        }
      }
    }
    return list;
  }

  @override
  Future<List<Manga>> searchManga(String query, int page) async {
    // Search URL: https://manhuaplus.top/search?keyword=query&page=page
    final response = await getRequest(
      '$baseUrl/search?keyword=$query&page=$page',
    );
    final document = parser.parse(response.body);
    final elements = document.querySelectorAll('.item');

    List<Manga> list = [];
    for (var element in elements) {
      final aTag = element.querySelector('.jtip');
      final imgTag = element.querySelector('img');
      if (aTag != null && imgTag != null) {
        var url = aTag.attributes['href'] ?? '';
        if (url.startsWith('/')) url = '$baseUrl$url';
        final title = aTag.text.trim();
        final coverUrl =
            imgTag.attributes['data-original'] ??
            imgTag.attributes['data-src'] ??
            imgTag.attributes['src'] ??
            '';

        if (url.isNotEmpty && title.isNotEmpty) {
          list.add(
            Manga(
              title: title,
              url: url,
              coverUrl: coverUrl,
              sourceId: 'manhuaplus',
            ),
          );
        }
      }
    }
    return list;
  }

  @override
  Future<MangaDetails> fetchMangaDetails(Manga manga) async {
    final response = await getRequest(manga.url);
    final document = parser.parse(response.body);

    // Description
    final descElement = document.querySelector('.detail-content p');
    final description = descElement?.text.trim() ?? '';

    // Metadata
    String author = 'Updating';
    String status = 'Ongoing';
    List<String> genres = [];

    final infoItems = document.querySelectorAll('.list-info li');
    for (var item in infoItems) {
      final label = item.querySelector('.col-xs-4')?.text.trim() ?? '';
      final valueElement = item.querySelector('.col-xs-8');

      if (label.contains('Author') || label.contains('Tác giả')) {
        author = valueElement?.text.trim() ?? 'Updating';
      } else if (label.contains('Status') || label.contains('Tình trạng')) {
        status = valueElement?.text.trim() ?? 'Ongoing';
      } else if (label.contains('Genres') || label.contains('Thể loại')) {
        genres =
            valueElement
                ?.querySelectorAll('a')
                .map((e) => e.text.trim())
                .toList() ??
            [];
      }
    }

    final chapters = await fetchChapters(manga.url);

    return MangaDetails(
      title: manga.title,
      coverUrl: manga.coverUrl,
      description: description,
      author: author,
      artist: 'Unknown',
      status: status,
      genres: genres,
      chapters: chapters,
      suggestions: [], // Suggestions not easily accessible in same call
    );
  }

  @override
  Future<List<Chapter>> fetchChapters(String mangaUrl) async {
    final response = await getRequest(mangaUrl);
    final document = parser.parse(response.body);

    final chapterElements = document.querySelectorAll(
      '#nt_listchapter .chapter a',
    );

    List<Chapter> chapters = [];
    for (var element in chapterElements) {
      var url = element.attributes['href'] ?? '';
      if (url.startsWith('/')) url = '$baseUrl$url';

      final title = element.text.trim();
      String? releaseDate;

      // Madara-like structure has .post-on or .chapter-release-date
      final parent = element.parent?.parent;
      if (parent != null) {
        final dateEl = parent.querySelector('.post-on, .chapter-release-date');
        releaseDate = dateEl?.text.trim();
      }

      if (url.isNotEmpty) {
        chapters.add(Chapter(
          title: title,
          url: url,
          mangaUrl: mangaUrl,
          releaseDate: releaseDate,
        ));
      }
    }
    return chapters;
  }

  @override
  Future<List<String>> fetchChapterImages(String chapterUrl) async {
    final response = await getRequest(chapterUrl);
    final document = parser.parse(response.body);
    final images = document.querySelectorAll('.page-chapter img');

    List<String> list = [];
    for (var img in images) {
      var src =
          img.attributes['data-original'] ??
          img.attributes['data-src'] ??
          img.attributes['src'] ??
          '';
      if (src.startsWith('/')) src = '$baseUrl$src';

      if (src.isNotEmpty) {
        list.add(src.trim());
      }
    }
    return list;
  }
}
