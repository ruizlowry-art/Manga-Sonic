import 'package:html/parser.dart' as parser;
import 'package:manga_sonic/config/supabase_config.dart';
import 'package:manga_sonic/data/models/models.dart';
import 'package:manga_sonic/utils/cloudflare_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'base_parser.dart';
import 'dart:async';

/// ManhuaTop (manhuatop.org) — Next.js site behind aggressive Cloudflare.
///
/// Strategy:
///   • All platforms: CloudflareInterceptor.bypass() via getRequest()
///     solves the Cloudflare JS challenge and stores cf_clearance cookies.
///   • Fallback: Supabase Edge Function proxy if direct bypass fails.
///
/// The Edge Function (supabase/functions/fetch-manga) runs server-side in
/// Deno and fetches manhuatop.org with browser-like headers, so Cloudflare
/// challenges are solved on the server, not the client.
class ManhuaTopParser extends BaseParser {
  static const String _edgeFunctionBase =
      '${SupabaseConfig.projectUrl}/functions/v1/fetch-manga';

  ManhuaTopParser()
    : super(siteName: 'ManhuaTop', baseUrl: 'https://manhuatop.org');

  /// Fetch HTML — 4-layer fallback chain for maximum reliability.
  ///
  /// Layer 1: Direct HTTP via BaseParser.getRequest()
  ///   On Android, this triggers CloudflareInterceptor.bypass() (headless WebView)
  ///   which solves the Cloudflare JS challenge, stores cf_clearance cookies,
  ///   then retries the request with cookies attached.
  ///
  /// Layer 2: Direct HTTP retry with force-bypass
  ///   If Layer 1 gets a Cloudflare block again (stale cookies), force a fresh
  ///   bypass and retry once more.
  ///
  /// Layer 3: Jina.ai reader proxy
  ///   Server-side fetch that may bypass Cloudflare without JS execution.
  ///
  /// Layer 4: Supabase Edge Function proxy
  ///   Server-side Deno fetch as last resort.
  Future<String> _fetchHtml(String url) async {
    // --- Layer 1: Direct HTTP with Cloudflare bypass (headless WebView) ---
    try {
      final response = await getRequest(url);
      _logResponse('Layer1 direct HTTP', response);
      if (_hasUsableContent(response.body)) {
        debugPrint('ManhuaTopParser: Layer 1 succeeded for $url');
        return response.body;
      }
      debugPrint(
          'ManhuaTopParser: Layer 1 returned non-usable content for $url');
    } catch (e) {
      debugPrint('ManhuaTopParser: Layer 1 error for $url: $e');
    }

    // --- Layer 2: Force fresh bypass + retry ---
    // If Layer 1 got blocked again, cookies may be stale — force a new bypass.
    try {
      await CloudflareInterceptor.bypass(url, force: true);
      final response = await getRequest(url);
      _logResponse('Layer2 force-bypass retry', response);
      if (_hasUsableContent(response.body)) {
        debugPrint('ManhuaTopParser: Layer 2 succeeded for $url');
        return response.body;
      }
      debugPrint(
          'ManhuaTopParser: Layer 2 returned non-usable content for $url');
    } catch (e) {
      debugPrint('ManhuaTopParser: Layer 2 error for $url: $e');
    }

    // --- Layer 3: Jina.ai reader proxy ---
    try {
      final html = await CloudflareInterceptor.fetchViaJinaAi(url);
      if (html != null && html.isNotEmpty && _hasUsableContent(html)) {
        debugPrint('ManhuaTopParser: Layer 3 (Jina.ai) succeeded for $url');
        return html;
      }
      debugPrint(
          'ManhuaTopParser: Layer 3 (Jina.ai) returned unusable content for $url');
    } catch (e) {
      debugPrint('ManhuaTopParser: Layer 3 (Jina.ai) error for $url: $e');
    }

    // --- Layer 4: Supabase Edge Function proxy ---
    try {
      final html = await _fetchViaEdgeFunction(url);
      if (html.isNotEmpty && _hasUsableContent(html)) {
        debugPrint('ManhuaTopParser: Layer 4 (Edge Function) succeeded for $url');
        return html;
      }
      debugPrint(
          'ManhuaTopParser: Layer 4 (Edge Function) returned unusable content for $url');
    } catch (e) {
      debugPrint('ManhuaTopParser: Layer 4 (Edge Function) error for $url: $e');
    }

    debugPrint('ManhuaTopParser: All 4 layers failed for $url');
    return '';
  }

  /// Calls the Supabase Edge Function proxy to fetch a URL server-side.
  Future<String> _fetchViaEdgeFunction(String targetUrl) async {
    final encoded = Uri.encodeComponent(targetUrl);
    final proxyUrl = '$_edgeFunctionBase?url=$encoded';

    try {
      final response = await http.Client().get(
        Uri.parse(proxyUrl),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
          'apikey': SupabaseConfig.anonKey,
        },
      );

      _logResponse('Edge Function proxy', response);

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        return response.body;
      }

      debugPrint(
          'ManhuaTopParser: Edge Function returned status ${response.statusCode}');
      return '';
    } catch (e) {
      debugPrint('ManhuaTopParser: Edge Function request failed: $e');
      return '';
    }
  }

  /// Log response details for debugging
  void _logResponse(String label, http.Response response) {
    debugPrint(
        'ManhuaTopParser: $label status=${response.statusCode} len=${response.body.length} '
        'body=${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
  }

  /// Check if HTML body contains usable content markers (not Cloudflare challenge)
  bool _hasUsableContent(String body) {
    if (body.isEmpty) return false;

    final lower = body.toLowerCase();
    if (lower.contains('just a moment') ||
        (lower.contains('cloudflare') && lower.contains('challenge')) ||
        lower.contains('challenges.cloudflare.com') ||
        lower.contains('cf-browser-verification') ||
        lower.contains('id="cf-challenge"') ||
        lower.contains('data-ray=')) {
      debugPrint('ManhuaTopParser: Rejecting Cloudflare challenge page');
      return false;
    }

    // Check for manga content markers (HTML classes or Jina.ai cleaned text markers)
    return body.contains('manga-card') ||
        body.contains('/chapter/') ||
        body.contains('/series/') ||
        body.contains('manga-title') ||
        body.contains('Chapter') ||
        body.contains('manga');
  }

  /// Parses manga cards from HTML — handles both raw HTML and Jina.ai cleaned HTML.
  List<Manga> _parseMangaCards(String html) {
    if (html.isEmpty) return [];

    final document = parser.parse(html);
    debugPrint('ManhuaTopParser: Parsing HTML (len=${html.length})');

    // --- Attempt 1: Look for .manga-card elements (raw HTML) ---
    final cards = document.querySelectorAll('.manga-card');
    debugPrint('ManhuaTopParser: Found ${cards.length} .manga-card elements');

    if (cards.isNotEmpty) {
      return _parseCardsFromElements(cards);
    }

    // --- Attempt 2: Jina.ai cleaned HTML — look for links with /series/ or /chapter/ ---
    final seriesLinks = document.querySelectorAll('a[href*="/series/"]');
    debugPrint('ManhuaTopParser: Found ${seriesLinks.length} /series/ links');

    if (seriesLinks.isNotEmpty) {
      return _parseCardsFromLinks(seriesLinks);
    }

    // --- Attempt 3: Any link with manga/chapter keywords ---
    final mangaLinks = document.querySelectorAll(
      'a[href*="/manga/"], a[href*="/manhwa/"], a[href*="/manhua/"], a[href*="/chapter/"]',
    );
    debugPrint('ManhuaTopParser: Found ${mangaLinks.length} manga/chapter links');

    if (mangaLinks.isNotEmpty) {
      return _parseCardsFromLinks(mangaLinks);
    }

    // --- Attempt 4: Debug - log all links found ---
    final allLinks = document.querySelectorAll('a');
    debugPrint('ManhuaTopParser: Total ${allLinks.length} <a> tags found');
    final debugLimit = allLinks.length < 10 ? allLinks.length : 10;
    for (int i = 0; i < debugLimit; i++) {
      final link = allLinks[i];
      debugPrint(
          'ManhuaTopParser: Link ${i + 1}: href=${link.attributes['href']} text="${link.text.trim()}"');
    }

    return [];
  }

  /// Parse manga cards from .manga-card elements
  List<Manga> _parseCardsFromElements(List<dynamic> cards) {
    List<Manga> list = [];
    for (var card in cards) {
      try {
        final linkEl = card.querySelector('a[href*="/series/"]');
        if (linkEl == null) continue;

        final href = linkEl.attributes['href'] ?? '';
        if (href.isEmpty ||
            href == '/series/' ||
            href.contains('/series/?') ||
            href.contains('/series/page/')) {
          continue;
        }

        final url = Uri.parse(baseUrl).resolve(href).toString();

        String title = '';
        final titleEl =
            card.querySelector('.card-title-row, .manga-title, h3, h4');
        if (titleEl != null) {
          title = titleEl.text.trim();
        }

        if (title.isEmpty) {
          title = linkEl.attributes['aria-label'] ?? linkEl.text.trim();
        }

        String coverUrl = '';
        final imgEl =
            card.querySelector('.manga-cover img, .cover-portrait img, img');
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

    final seen = <String>{};
    return list.where((m) => seen.add(m.url)).toList();
  }

  /// Parse manga cards from <a> links (Jina.ai cleaned HTML fallback)
  List<Manga> _parseCardsFromLinks(List<dynamic> links) {
    List<Manga> list = [];
    final seen = <String>{};

    for (var link in links) {
      try {
        final href = link.attributes['href'] ?? '';
        if (href.isEmpty) continue;

        final url = Uri.parse(baseUrl).resolve(href).toString();
        if (!url.contains('/series/') && !url.contains('/chapter/')) continue;

        // Skip if it's a chapter link (we want series/manga links)
        if (url.contains('/chapter/')) continue;

        if (seen.contains(url)) continue;
        seen.add(url);

        final title = link.text.trim();
        debugPrint('ManhuaTopParser: Found link: title="$title" url=$url');
        if (title.isEmpty) continue;

        list.add(Manga(
          title: title,
          url: url,
          coverUrl: '', // Jina.ai cleaned HTML may not have cover images
          sourceId: 'manhuatop',
        ));
      } catch (e) {
        debugPrint('ManhuaTopParser: Error parsing link: $e');
      }
    }

    debugPrint('ManhuaTopParser: Parsed ${list.length} manga from ${links.length} links');
    return list;
  }

  @override
  Future<List<Manga>> fetchMangaList(int page) async {
    final url = page == 1
        ? '$baseUrl/series/'
        : '$baseUrl/series/page/$page/';

    debugPrint('ManhuaTopParser: Fetching manga list from $url');

    try {
      final html = await _fetchHtml(url);
      return _parseMangaCards(html);
    } catch (e) {
      debugPrint('ManhuaTopParser: Failed to fetch manga list: $e');
      return [];
    }
  }

  @override
  Future<List<Manga>> searchManga(String query, int page) async {
    final url = '$baseUrl/series/?q=${Uri.encodeComponent(query)}&page=$page';

    debugPrint('ManhuaTopParser: Searching manga at $url');

    try {
      final html = await _fetchHtml(url);
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
    try {
      final html = await _fetchHtml(mangaUrl);
      if (html.isEmpty) return [];
      final document = parser.parse(html);

      final chapterElements = document.querySelectorAll('a[href*="/chapter/"]');

      List<Chapter> chapters = [];
      final baseUri = Uri.parse(mangaUrl);

      for (var element in chapterElements) {
        final href = element.attributes['href'] ?? '';
        if (href.isEmpty) continue;

        final url = baseUri.resolve(href).toString();
        if (!url.contains('/chapter/')) continue;

        String title = element.text.trim().replaceAll(RegExp(r'\s+'), ' ');

        String? releaseDate;
        final parent = element.parent;
        if (parent != null) {
          final dateEl = parent.querySelector(
              'time, .chapter-date, .release-date, [datetime]');
          if (dateEl != null) {
            releaseDate = dateEl.attributes['datetime'] ?? dateEl.text.trim();
          }
        }

        if (title.isNotEmpty) {
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
    final match =
        RegExp(r'Chapter\s+(\d+)', caseSensitive: false).firstMatch(title);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '0') ?? 0;
    }
    final match2 =
        RegExp(r'(?:Ch\.?|#)\s*(\d+)', caseSensitive: false).firstMatch(title);
    if (match2 != null) {
      return int.tryParse(match2.group(1) ?? '0') ?? 0;
    }
    return 0;
  }

  @override
  Future<List<String>> fetchChapterImages(String chapterUrl) async {
    try {
      final html = await _fetchHtml(chapterUrl);
      if (html.isEmpty) return [];
      final document = parser.parse(html);

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
          if (url.contains('chapter') ||
              url.contains('manga') ||
              url.contains('image')) {
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
