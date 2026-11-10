import 'package:manga_sonic/data/models/models.dart';
import 'package:http/http.dart' as http;
import 'package:manga_sonic/utils/cloudflare_interceptor.dart';

abstract class BaseParser {
  final String siteName;
  final String baseUrl;

  BaseParser({required this.siteName, required this.baseUrl});

  // Fetch frontpage latest or popular
  Future<List<Manga>> fetchMangaList(int page);

  // Search
  Future<List<Manga>> searchManga(String query, int page);

  // Fetch manga details (description, status, etc.)
  Future<MangaDetails> fetchMangaDetails(Manga manga);

  // Fetch chapters
  Future<List<Chapter>> fetchChapters(String mangaUrl);

  // Fetch chapter images
  Future<List<String>> fetchChapterImages(String chapterUrl);

  // Shared HTTP Client with generic User-Agent
  final http.Client client = http.Client();

  bool _isCloudflareBlock(http.Response response) {
    // Check status codes that definitely indicate Cloudflare block
    if (response.statusCode == 403 || response.statusCode == 429) {
      return true;
    }
    // Check for 503 with Cloudflare content
    if (response.statusCode == 503 &&
        (response.body.contains('cloudflare') ||
            response.body.contains('Just a moment') ||
            response.body.contains('challenges.cloudflare.com'))) {
      return true;
    }
    // Cloudflare often returns 200 with challenge page - check body content
    // Only flag as block if we see strong challenge indicators. Avoid the
    // broad "cloudflare + challenge" keyword combo which causes false positives
    // on normal pages that merely mention Cloudflare.
    if (response.statusCode == 200 &&
        (response.body.contains('Just a moment') ||
            response.body.contains('challenges.cloudflare.com') ||
            response.body.contains('cf-browser-verification') ||
            response.body.contains('cf-challenge-running') ||
            response.body.contains('id="cf-challenge"') ||
            response.body.contains('data-ray="') ||
            response.body.contains('cf-challenge-widget'))) {
      return true;
    }
    return false;
  }

  Future<http.Response> getRequest(String url, {bool isRetry = false}) async {
    final response = await client.get(
      Uri.parse(url),
      headers: CloudflareInterceptor.headersForUrl(url),
    );

    if (_isCloudflareBlock(response)) {
      if (!isRetry) {
        await CloudflareInterceptor.bypass(url);
        // If bypass didn't store cookies (e.g. HeadlessInAppWebView failed on
        // Android), retry without Cloudflare headers as a fallback.
        if (!CloudflareInterceptor.hasCookiesForUrl(url)) {
          print(
              'BaseParser: No Cloudflare cookies after bypass, retrying with default headers');
          final retryResponse = await client.get(Uri.parse(url));
          return retryResponse;
        }
        return await getRequest(url, isRetry: true);
      }
      // On retry, cookies may be stale — force a fresh bypass, then return
      // whatever we get rather than throwing (caller can handle the result).
      await CloudflareInterceptor.bypass(url, force: true);
      final retryResponse = await client.get(
        Uri.parse(url),
        headers: CloudflareInterceptor.headersForUrl(url),
      );
      return retryResponse;
    }

    return response;
  }

  Future<http.Response> postRequest(
    String url, {
    Object? body,
    Map<String, String>? headers,
    bool isRetry = false,
  }) async {
    final response = await client.post(
      Uri.parse(url),
      headers: {
        ...CloudflareInterceptor.headersForUrl(url),
        if (headers != null) ...headers,
      },
      body: body,
    );

    if (_isCloudflareBlock(response)) {
      if (!isRetry) {
        await CloudflareInterceptor.bypass(url);
        if (!CloudflareInterceptor.hasCookiesForUrl(url)) {
          print(
              'BaseParser: No Cloudflare cookies after bypass, retrying with default headers');
          final retryResponse = await client.post(Uri.parse(url), body: body);
          return retryResponse;
        }
        return await postRequest(url, body: body, headers: headers, isRetry: true);
      }
      await CloudflareInterceptor.bypass(url, force: true);
      final retryResponse = await client.post(
        Uri.parse(url),
        headers: {
          ...CloudflareInterceptor.headersForUrl(url),
          if (headers != null) ...headers,
        },
        body: body,
      );
      return retryResponse;
    }

    return response;
  }
}
