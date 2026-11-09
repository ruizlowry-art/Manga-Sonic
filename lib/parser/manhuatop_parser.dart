import 'package:html/parser.dart' as parser;
import 'package:manga_sonic/data/models/models.dart';
import 'package:manga_sonic/utils/cloudflare_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'base_parser.dart';
import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ManhuaTopParser extends BaseParser {
  ManhuaTopParser()
    : super(siteName: 'ManhuaTop', baseUrl: 'https://manhuatop.org');

  /// Fetches the fully rendered HTML using a headless browser
  /// This is needed because manhuatop.org is a Next.js site that renders content client-side
  Future<String> _fetchRenderedHtml(String url) async {
    final completer = Completer<String>();
    HeadlessInAppWebView? headless;
    Timer? safetyTimer;

    void cleanup() {
      safetyTimer?.cancel();
      try {
        headless?.dispose();
      } catch (e) {
        debugPrint('ManhuaTopParser: Error disposing headless: $e');
      }
      headless = null;
    }

    safetyTimer = Timer(const Duration(seconds: 30), () {
      debugPrint('ManhuaTopParser: Headless timeout for $url');
      if (!completer.isCompleted) {
        completer.completeError(Exception('Headless timeout'));
      }
      cleanup();
    });

    final webUri = WebUri(url);

    headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: webUri),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        thirdPartyCookiesEnabled: true,
        sharedCookiesEnabled: true,
        cacheEnabled: true,
        useWideViewPort: true,
        userAgent: CloudflareInterceptor.defaultUserAgent,
      ),
      onLoadStop: (controller, currentUri) async {
        debugPrint('ManhuaTopParser: Page load finished ($currentUri)');

        // Wait for the manga list to load - look for manga-card elements
        int attempts = 0;
        const maxAttempts = 15;
        
        while (attempts < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 1000));
          attempts++;
          
          try {
            final html = await controller.evaluateJavascript(
              source: 'document.documentElement.outerHTML',
            );
            
            if (html != null && html.toString().contains('manga-card')) {
              debugPrint('ManhuaTopParser: Manga cards found after $attempts attempts');
              completer.complete(html.toString());
              cleanup();
              return;
            }
          } catch (e) {
            debugPrint('ManhuaTopParser: Error checking for manga cards: $e');
          }
        }
        
        // If we couldn't find manga cards, return whatever we have
        try {
          final html = await controller.evaluateJavascript(
            source: 'document.documentElement.outerHTML',
          );
          completer.complete(html?.toString() ?? '');
        } catch (e) {
          completer.completeError(e);
        }
        cleanup();
      },
      onReceivedError: (controller, request, error) {
        debugPrint('ManhuaTopParser: Load error: $error');
        if (!completer.isCompleted) {
          completer.completeError(Exception('Load error: $error'));
        }
        cleanup();
      },
      onReceivedHttpError: (controller, request, errorResponse) {
        debugPrint('ManhuaTopParser: HTTP error (${errorResponse.statusCode}): ${errorResponse.reasonPhrase}');
      },
    );

    try {
      await headless?.run();
      debugPrint('ManhuaTopParser: Headless instance running for $url');
    } catch (e) {
      debugPrint('ManhuaTopParser: Failed to start headless: $e');
      cleanup();
      completer.completeError(e);
    }

    return completer.future;
  }

  /// Parses manga cards from the rendered HTML
  List<Manga> _parseMangaCards(String html) {
    final document = parser.parse(html);
    final cards = document.querySelectorAll('.manga-card');
    
    List<Manga> list = [];
    for (var card in cards) {
      try {
        // Get the link to the manga series
        final linkEl = card.querySelector('a[href*="/series/"]');
        if (linkEl == null) continue;
        
        final href = linkEl.attributes['href'] ?? '';
        if (href.isEmpty || href == '/series/' || href.contains('/series/?') || href.contains('/series/page/')) {
          continue; // Skip navigation links
        }
        
        final url = Uri.parse(baseUrl).resolve(href).toString();
        
        // Get title from card-title-row or similar
        String title = '';
        final titleEl = card.querySelector('.card-title-row, .manga-title, h3, h4');
        if (titleEl != null) {
          title = titleEl.text.trim();
        }
        
        // Fallback: get from link's aria-label or text
        if (title.isEmpty) {
          title = linkEl.attributes['aria-label'] ?? linkEl.text.trim();
        }
        
        // Get cover image
        String coverUrl = '';
        final imgEl = card.querySelector('.manga-cover img, .cover-portrait img, img');
        if (imgEl != null) {
          coverUrl = imgEl.attributes['src'] ?? 
                     imgEl.attributes['data-src'] ?? 
                     imgEl.attributes['data-lazy-src'] ?? 
                     '';
        }
        
        if (title.isNotEmpty && url.isNotEmpty) {
          list.add(Manga(
            title: title,
            url: url,
            coverUrl: coverUrl,
            sourceId: 'manhuatop',
          ));
        }
      } catch (e) {
        debugPrint('ManhuaTopParser: Error parsing card: $e');
      }
    }
    
    // Deduplicate by URL
    final seen = <String>{};
    return list.where((m) => seen.add(m.url)).toList();
  }

  @override
  Future<List<Manga>> fetchMangaList(int page) async {
    // The site uses /series/ for the manga listing with pagination
    final url = page == 1 
        ? '$baseUrl/series/' 
        : '$baseUrl/series/page/$page/';
    
    debugPrint('ManhuaTopParser: Fetching manga list from $url');
    
    try {
      final html = await _fetchRenderedHtml(url);
      return _parseMangaCards(html);
    } catch (e) {
      debugPrint('ManhuaTopParser: Failed to fetch manga list: $e');
      return [];
    }
  }

  @override
  Future<List<Manga>> searchManga(String query, int page) async {
    // Search uses the /series/ endpoint with query parameters
    final url = '$baseUrl/series/?q=${Uri.encodeComponent(query)}&page=$page';
    
    debugPrint('ManhuaTopParser: Searching manga at $url');
    
    try {
      final html = await _fetchRenderedHtml(url);
      return _parseMangaCards(html);
    } catch (e) {
      debugPrint('ManhuaTopParser: Failed to search manga: $e');
      return [];
    }
  }

  @override
  Future<MangaDetails> fetchMangaDetails(Manga manga) async {
    final chapters = await fetchChapters(manga.url);
    return MangaDetails(
      title: manga.title,
      coverUrl: manga.coverUrl,
      description: 'Description not supported yet for this source.',
      author: 'Unknown',
      artist: 'Unknown',
      status: 'Unknown',
      genres: [],
      chapters: chapters,
      suggestions: [],
    );
  }

  @override
  Future<List<Chapter>> fetchChapters(String mangaUrl) async {
    // For manga details/chapters, we also need to render the page
    try {
      final html = await _fetchRenderedHtml(mangaUrl);
      final document = parser.parse(html);
      
      // Find chapter links - they should be in the chapter list
      final chapterElements = document.querySelectorAll('a[href*="/chapter/"]');
      
      List<Chapter> chapters = [];
      final baseUri = Uri.parse(mangaUrl);
      
      for (var element in chapterElements) {
        final href = element.attributes['href'] ?? '';
        if (href.isEmpty) continue;
        
        final url = baseUri.resolve(href).toString();
        if (!url.contains('/chapter/')) continue;
        
        // Extract chapter title
        String title = element.text.trim().replaceAll(RegExp(r'\s+'), ' ');
        
        // Try to find release date in parent/sibling elements
        String? releaseDate;
        final parent = element.parent;
        if (parent != null) {
          final dateEl = parent.querySelector('time, .chapter-date, .release-date, [datetime]');
          if (dateEl != null) {
            releaseDate = dateEl.attributes['datetime'] ?? dateEl.text.trim();
          }
        }
        
        if (title.isNotEmpty) {
          // Deduplicate
          if (!chapters.any((c) => c.url == url)) {
            chapters.add(Chapter(
              title: title,
              url: url,
              mangaUrl: mangaUrl,
              releaseDate: releaseDate,
            ));
          }
        }
      }
      
      // Sort chapters by number (oldest first)
      chapters.sort((a, b) {
        int numA = _extractChapterNumber(a.title);
        int numB = _extractChapterNumber(b.title);
        if (numA > 0 && numB > 0) {
          return numA.compareTo(numB);
        }
        return 0;
      });
      
      return chapters;
    } catch (e) {
      debugPrint('ManhuaTopParser: Failed to fetch chapters: $e');
      return [];
    }
  }

  int _extractChapterNumber(String title) {
    final match = RegExp(r'Chapter\s+(\d+)', caseSensitive: false).firstMatch(title);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '0') ?? 0;
    }
    // Try other patterns like "Ch. 1" or "#1"
    final match2 = RegExp(r'(?:Ch\.?|#)\s*(\d+)', caseSensitive: false).firstMatch(title);
    if (match2 != null) {
      return int.tryParse(match2.group(1) ?? '0') ?? 0;
    }
    return 0;
  }

  @override
  Future<List<String>> fetchChapterImages(String chapterUrl) async {
    try {
      final html = await _fetchRenderedHtml(chapterUrl);
      final document = parser.parse(html);
      
      // Find images in the chapter reader
      final images = document.querySelectorAll(
        '.chapter-content img, .reading-content img, .page-break img, #chapter-images img',
      );
      
      List<String> list = [];
      for (var img in images) {
        final src = img.attributes['data-src'] ?? 
                    img.attributes['src'] ?? 
                    img.attributes['data-lazy-src'] ?? 
                    '';
        if (src.isNotEmpty) {
          list.add(src.trim());
        }
      }
      
      // Fallback: regex search for image URLs
      if (list.isEmpty) {
        final chapterImagePattern = RegExp(
          'https?://[^\\s"\'<>]+?\\.(?:jpg|jpeg|png|webp)(?:\\?[^\\s"\'<>]*)?',
          caseSensitive: false,
        );
        for (var match in chapterImagePattern.allMatches(html)) {
          final url = match.group(0)!;
          if (url.contains('chapter') || url.contains('manga') || url.contains('image')) {
            list.add(url);
          }
        }
      }
      
      return list.where((url) => url.isNotEmpty).toSet().toList();
    } catch (e) {
      debugPrint('ManhuaTopParser: Failed to fetch chapter images: $e');
      return [];
    }
  }
}
