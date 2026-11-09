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
    if (response.statusCode == 200 &&
        (response.body.contains('Just a moment') ||
            response.body.contains('challenges.cloudflare.com') ||
            response.body.contains('cf-browser-verification') ||
            response.body.contains('cf-challenge-running') ||
            response.body.contains('id="cf-challenge"') ||
            response.body.contains('data-ray="') ||
            (response.body.contains('cloudflare') && response.body.contains('challenge')))) {
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
        return await getRequest(url, isRetry: true);
      }
      throw Exception(
        'Cloudflare block detected (Status ${response.statusCode})',
      );
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
        return await postRequest(url, body: body, headers: headers, isRetry: true);
      }
      throw Exception(
        'Cloudflare block detected (Status ${response.statusCode})',
      );
    }

    return response;
  }
}
