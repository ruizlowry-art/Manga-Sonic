import 'package:html/parser.dart' as parser;
import 'package:manga_sonic/data/models/models.dart';
import 'base_parser.dart';
import 'dart:convert';

class AsuraComicParser extends BaseParser {
  AsuraComicParser()
    : super(siteName: 'AsuraComic', baseUrl: 'https://asurascans.com');

  /// The site rebranded and moved domains. The old domains now redirect to the
  /// homepage (dropping the path), which caused every request to parse the
  /// homepage's "Latest Updates" list instead of the requested page. Normalize
  /// any legacy URLs (e.g. from old library entries or cache) to the new domain.
  String _normalizeUrl(String url) {
    return url
        .replaceAll('asuracomic.net', 'asurascans.com')
        .replaceAll('asuracomics.com', 'asurascans.com')
        .replaceAll('asuracomic.com', 'asurascans.com');
  }

  /// Finds the main manga grid container by checking for the distinctive
  /// class combination: grid-cols-2 + md:grid-cols-5 + gap-3 + p-4.
  /// This filters out the sidebar "Popular" section and other grids.
  dynamic _findMainGrid(dynamic document) {
    // In the new Astro site, the grid doesn't have a single unique "grid-cols-X" container 
    // that's easy to target consistently. Instead, we'll look for the container 
    // that holds multiple manga link tags.
    final items = document.querySelectorAll('a[href*="/comics/"], a[href*="/series/"]');
    if (items.isNotEmpty) return document; // Return document as "container" and parse all links
    return null;
  }

  List<Manga> _parseMangaGrid(dynamic container) {
    if (container == null) return [];

    final List<Manga> list = [];

    // Prefer the dedicated card containers used by both the /comics listing and
    // the /browse search results.
    var cards = container.querySelectorAll('.series-card');
    if (cards.isEmpty) {
      cards = container.querySelectorAll('a[href*="/comics/"], a[href*="/series/"]');
    }

    for (var card in cards) {
      // Within a card the series link is the first non-chapter link; when the
      // passed element is already an <a>, use it directly.
      final links = card.localName == 'a'
          ? [card]
          : card.querySelectorAll('a[href*="/comics/"], a[href*="/series/"]');

      dynamic seriesLink;
      for (var link in links) {
        final href = link.attributes['href'] ?? '';
        if (href.isEmpty) continue;
        if (href.contains('/chapter/')) continue;
        if (href == '/comics' ||
            href == '/comics/' ||
            href.startsWith('/comics?')) {
          continue;
        }
        seriesLink = link;
        break;
      }
      if (seriesLink == null) continue;

      final href = seriesLink.attributes['href'] ?? '';
      final url = Uri.parse(baseUrl).resolve(href).toString();
      if (list.any((m) => m.url == url)) continue;

      // Title: prefer an <h3>, then the cover image's alt text, then a span.
      String title = '';
      final h3 = seriesLink.querySelector('h3') ?? card.querySelector('h3');
      if (h3 != null) title = h3.text.trim();

      final img = seriesLink.querySelector('img') ?? card.querySelector('img');
      if (title.isEmpty && img != null) {
        title = (img.attributes['alt'] ?? '').trim();
      }

      if (title.isEmpty) {
        final spans = card.querySelectorAll('span');
        for (var s in spans) {
          final t = s.text.trim();
          if (t.isEmpty ||
              t == 'Manga' ||
              t == 'Manhwa' ||
              t == 'Manhua' ||
              t.contains('.')) {
            continue;
          }
          title = t;
          break;
        }
      }

      if (title.isEmpty) continue;

      final coverUrl =
          img?.attributes['src'] ?? img?.attributes['data-src'] ?? '';

      list.add(
        Manga(
          title: title,
          url: url,
          coverUrl: coverUrl,
          sourceId: 'asuracomic',
        ),
      );
    }

    return list;
  }

  @override
  Future<List<Manga>> fetchMangaList(int page) async {
    // The new site uses /comics for listing
    final response = await getRequest('$baseUrl/comics?page=$page');
    final document = parser.parse(response.body);
    final grid = _findMainGrid(document);
    return _parseMangaGrid(grid);
  }

  @override
  Future<List<Manga>> searchManga(String query, int page) async {
    // The site's search lives at /browse?q=<query>. The old /comics?q= form
    // ignored the query and just returned the unfiltered listing.
    final encoded = Uri.encodeComponent(query);
    final response = await getRequest('$baseUrl/browse?q=$encoded&page=$page');
    final document = parser.parse(response.body);
    final grid = _findMainGrid(document);
    return _parseMangaGrid(grid);
  }

  @override
  Future<List<Chapter>> fetchChapters(String mangaUrl) async {
    final normalizedUrl = _normalizeUrl(mangaUrl);
    final response = await getRequest(normalizedUrl);
    final document = parser.parse(response.body);

    final chapterElements = document.querySelectorAll('a[href*="/chapter/"]');

    List<Chapter> chapters = [];
    final baseUri = Uri.parse(normalizedUrl);

    // The series path (e.g. "/comics/solo-leveling-f212c582"). Chapter links
    // fetched from any other series mean we did not get the requested page
    // (e.g. a domain redirect landed on the homepage) - skip those so we never
    // return another manga's chapters.
    final seriesPath = baseUri.path.replaceAll(RegExp(r'/$'), '');

    for (var element in chapterElements) {
      final href = element.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      if (href.contains('/chapter/') && !href.contains(seriesPath)) continue;

      final url = baseUri.resolve(href).toString();
      if (!url.contains('/chapter/')) continue;

      // Extract chapter info from the link element
      // Chapter number is in span.font-medium (e.g., "Chapter 200")
      // Chapter title is in span.block.truncate (e.g., "Side Story 21 { THE END }")
      // Release date is in span.text-sm.text-white/40 (e.g., "Jul 13, 2024")
      
      String chapterName = '';
      String? releaseDate;

      // Try to find chapter number from span.font-medium
      final chapterNumEl = element.querySelector('span.font-medium');
      if (chapterNumEl != null) {
        final text = chapterNumEl.text.trim();
        chapterName = text;
        // Chapter number is extracted in _extractChapterNumber during sorting
        RegExp(r'Chapter\s+(\d+)', caseSensitive: false).firstMatch(text);
      }

      // Get chapter subtitle/title from the truncate span
      final titleEl = element.querySelector('span.block.truncate');
      if (titleEl != null) {
        final subtitle = titleEl.text.trim();
        if (subtitle.isNotEmpty) {
          chapterName = '$chapterName: $subtitle';
        }
      }

      // Get release date
      final dateEl = element.querySelector('span.text-sm.text-white/40');
      if (dateEl != null) {
        releaseDate = dateEl.text.trim();
      }

      // Fallback: if no structured data found, use element text
      if (chapterName.isEmpty) {
        chapterName = element.text
            .trim()
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }

      // Skip promotional buttons ("First Chapter", "New Chapter")
      if (chapterName == 'First Chapter' || chapterName == 'New Chapter') {
        continue;
      }

      // Skip if chapter name is empty
      if (chapterName.isEmpty) continue;

      // Deduplicate by URL
      if (!chapters.any((c) => c.url == url)) {
        chapters.add(Chapter(
          title: chapterName,
          url: url,
          mangaUrl: normalizedUrl,
          releaseDate: releaseDate,
        ));
      }
    }

    // Sort chapters by chapter number (newest first - descending)
    // Chapter 0 is valid (some series start at 0), so use >= 0
    chapters.sort((a, b) {
      // Try to extract chapter numbers from titles
      int numA = _extractChapterNumber(a.title);
      int numB = _extractChapterNumber(b.title);
      
      if (numA >= 0 && numB >= 0) {
        return numB.compareTo(numA); // Descending: newest first (200, 199, ...)
      }
      
      // Fallback to release date comparison
      if (a.releaseDate != null && b.releaseDate != null) {
        try {
          final dateA = DateTime.parse(a.releaseDate!);
          final dateB = DateTime.parse(b.releaseDate!);
          return dateB.compareTo(dateA);
        } catch (e) {
          // If date parsing fails, keep original order
        }
      }
      
      return 0;
    });

    return chapters;
  }

  /// Extract chapter number from title like "Chapter 200" or "Chapter 200: Side Story"
  int _extractChapterNumber(String title) {
    final match = RegExp(r'Chapter\s+(\d+)', caseSensitive: false).firstMatch(title);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '0') ?? 0;
    }
    return 0;
  }

  @override
  Future<MangaDetails> fetchMangaDetails(Manga manga) async {
    final response = await getRequest(_normalizeUrl(manga.url));
    final document = parser.parse(response.body);

    // Description: Look for div with id="description-text"
    String description = '';
    final descDiv = document.querySelector('#description-text');
    if (descDiv != null) {
      description = descDiv.text.trim();
    } else {
      // Fallback to p tags with specific style
      final pTags = document.querySelectorAll('p');
      for (var p in pTags) {
        if (p.classes.any((c) => c.contains('text-white/80'))) {
          description = p.text.trim();
          break;
        }
      }
    }

    // Metadata
    String author = 'Unknown';
    String artist = 'Unknown';
    String status = 'Unknown';

    final textNodes = document.querySelectorAll('div, span, p');
    for (var node in textNodes) {
      final text = node.text.trim().toLowerCase();
      if (text == 'author' && node.nextElementSibling != null) {
        author = node.nextElementSibling!.text.trim();
      } else if (text == 'artist' && node.nextElementSibling != null) {
        artist = node.nextElementSibling!.text.trim();
      } else if (text == 'status' && node.nextElementSibling != null) {
        status = node.nextElementSibling!.text.trim();
      }
    }

    // Genres: tags with bg-white/5
    List<String> genres = [];
    final anchors = document.querySelectorAll('a');
    for (var a in anchors) {
      if (a.classes.any((c) => c.contains('bg-white/5')) || a.classes.any((c) => c.contains('rounded-lg'))) {
        final g = a.text.trim();
        if (g.length < 20 && !g.contains('Chapter') && !g.contains('Home')) {
          genres.add(g);
        }
      }
    }

    final chapters = await fetchChapters(manga.url);

    // Suggestions from the "Related Series" / sidebar. The new site links
    // series as /comics/<slug> (older builds used /series/).
    List<Manga> suggestions = [];
    final suggestionLinks = document.querySelectorAll(
      'a[href*="/comics/"], a[href*="/series/"]',
    );
    final requestPath = _normalizeUrl(manga.url).replaceAll(RegExp(r'/$'), '');
    for (var element in suggestionLinks) {
      final href = element.attributes['href'] ?? '';
      if (href.isEmpty || href.contains('/chapter/')) continue;
      if (href == '/comics' || href == '/comics/' || href.startsWith('/comics?')) {
        continue;
      }

      final url = Uri.parse(baseUrl).resolve(href).toString();
      if (url == requestPath || suggestions.any((m) => m.url == url)) continue;

      final title = (element.querySelector('h3')?.text.trim() ??
              element.querySelector('span.font-bold')?.text.trim() ??
              element.attributes['aria-label'] ??
              '')
          .trim();
      if (title.isEmpty) continue;

      final img = element.querySelector('img');
      final coverUrl =
          img?.attributes['src'] ?? img?.attributes['data-src'] ?? '';

      suggestions.add(
        Manga(
          title: title,
          url: url,
          coverUrl: coverUrl,
          sourceId: 'asuracomic',
        ),
      );
      if (suggestions.length >= 6) break;
    }

    return MangaDetails(
      title: manga.title,
      coverUrl: manga.coverUrl,
      description: description,
      author: author,
      artist: artist,
      status: status,
      genres: genres,
      chapters: chapters,
      suggestions: suggestions,
    );
  }

  @override
  Future<List<String>> fetchChapterImages(String chapterUrl) async {
    final response = await getRequest(_normalizeUrl(chapterUrl));
    final document = parser.parse(response.body);

    if (document.body?.text.contains('Login to continue reading') ?? false) {
      throw Exception('Login required to read this chapter');
    }

    // Look for the Astro component that contains the chapter images
    final List<String> imageUrls = [];
    
    // Find <astro-island> that likely contains the ChapterReader component
    final islands = document.querySelectorAll('astro-island');
    for (var island in islands) {
      final propsString = island.attributes['props'] ?? '';
      final componentUrl = island.attributes['component-url'] ?? '';
      final componentExport = island.attributes['component-export'] ?? '';
      
      if (propsString.isNotEmpty && (componentUrl.contains('ChapterReader') || componentExport == 'ChapterReader')) {
        try {
          // Astro props are HTML entities encoded JSON
          final decodedProps = _unescapeHtml(propsString);
          final Map<String, dynamic> props = json.decode(decodedProps);
          
          // Current Astro structure: pages[1][index][1].url[1]
          final pagesData = props['pages'];
          if (pagesData is List && pagesData.length > 1) {
            final pagesList = pagesData[1];
            if (pagesList is List) {
              for (var pageItem in pagesList) {
                if (pageItem is List && pageItem.length > 1) {
                  final pageObj = pageItem[1];
                  if (pageObj is Map && pageObj.containsKey('url')) {
                    final urlData = pageObj['url'];
                    String? url;
                    if (urlData is List && urlData.length > 1) {
                      url = urlData[1].toString();
                    } else if (urlData is String) {
                      url = urlData;
                    }
                    if (url != null && url.isNotEmpty) imageUrls.add(url);
                  }
                }
              }
            }
          }
        } catch (e) {
          // Silent or print if debugging
        }
      }
    }

    // Fallback 1: standard <img> tags
    if (imageUrls.isEmpty) {
      final imgs = document.querySelectorAll('img');
      for (var img in imgs) {
        final src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
        if (src.contains('/asura-images/chapters/') || src.contains('gg.asuracomic.net/storage/media/')) {
          imageUrls.add(src);
        }
      }
    }

    // Fallback 2: Regex search in the whole body text/html
    if (imageUrls.isEmpty) {
      final bodyHtml = response.body;
      final chapterImagePattern = RegExp(
        'https?://[^\\s"\'<>]+?/asura-images/chapters/[^\\s"\'<>]+?\\.webp',
        caseSensitive: false,
      );
      for (var match in chapterImagePattern.allMatches(bodyHtml)) {
        imageUrls.add(match.group(0)!);
      }
    }

    // Deduplicate and filter out empty
    return imageUrls.where((url) => url.isNotEmpty).toSet().toList();
  }

  String _unescapeHtml(String input) {
    return input
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&#x2F;', '/');
  }
}
