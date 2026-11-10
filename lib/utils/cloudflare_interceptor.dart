import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:zikzak_inappwebview/zikzak_inappwebview.dart';
import 'package:http/http.dart' as http;

class CloudflareInterceptor {
  static const String defaultUserAgent =
      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  static String? _userAgent;
  // Store cookies per domain (host)
  static final Map<String, String> _cookiesByDomain = {};
  // Track which domains have been bypassed (or attempted)
  static final Set<String> _bypassedDomains = {};

  static Map<String, String> get headers {
    final Map<String, String> h = {
      'User-Agent': _userAgent ?? defaultUserAgent,
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Sec-Ch-Ua':
          '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
      'Sec-Ch-Ua-Mobile': '?1',
      'Sec-Ch-Ua-Platform': '"Android"',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none',
      'Sec-Fetch-User': '?1',
      'Upgrade-Insecure-Requests': '1',
    };
    return h;
  }

  /// Get headers with cookies for a specific URL
  static Map<String, String> headersForUrl(String url) {
    final headers = Map<String, String>.from(CloudflareInterceptor.headers);
    final uri = Uri.parse(url);
    final domain = uri.host;

    // Find matching cookies for this domain
    String? cookiesForDomain = _cookiesByDomain[domain];
    if (cookiesForDomain == null) {
      // Try to find a parent domain match (e.g., .asurascans.com for subdomains)
      for (final entry in _cookiesByDomain.entries) {
        if (domain.endsWith(entry.key) || entry.key.endsWith(domain)) {
          cookiesForDomain = entry.value;
          break;
        }
      }
    }

    if (cookiesForDomain != null && cookiesForDomain.isNotEmpty) {
      headers['Cookie'] = cookiesForDomain;
    }
    return headers;
  }

  static Completer<void>? _currentBypassCompleter;
  static String? _currentBypassUrl;

  /// Known image CDN domains that also need Cloudflare clearance cookies
  /// so chapter images don't get 403'd on Android.
  static const List<String> _imageCdnDomains = [
    'gg.asuracomic.net',
  ];

  /// Reader proxy that can fetch Cloudflare-protected pages server-side.
  /// Used as a fallback on all platforms where headless bypass fails.
  static const String _jinaAiReader = 'https://r.jina.ai/';

  static Future<void> bypass(String url, {bool force = false}) async {
    final uri = Uri.parse(url);
    final domain = uri.host;

    // If already bypassed this domain and not forcing, skip
    if (_bypassedDomains.contains(domain) && !force) {
      debugPrint(
          'CloudflareInterceptor: Domain $domain already bypassed, skipping');
      return;
    }

    // If already bypassing, just wait for that one.
    if (_currentBypassCompleter != null &&
        !_currentBypassCompleter!.isCompleted) {
      if (_currentBypassUrl == url) {
        debugPrint(
            'CloudflareInterceptor: Already bypassing $url, waiting...');
        return _currentBypassCompleter!.future;
      }
      debugPrint(
          'CloudflareInterceptor: Waiting for current bypass to complete before starting $url');
      await _currentBypassCompleter!.future;
    }

    _currentBypassCompleter = Completer<void>();
    _currentBypassUrl = url;
    HeadlessInAppWebView? headless;
    Timer? safetyTimer;
    Timer? pollTimer;

    void cleanup({bool markBypassed = false}) {
      safetyTimer?.cancel();
      pollTimer?.cancel();
      if (!(_currentBypassCompleter?.isCompleted ?? true)) {
        _currentBypassCompleter?.complete();
      }
      try {
        headless?.dispose();
      } catch (e) {
        debugPrint(
            'CloudflareInterceptor: Error disposing headless: $e');
      }
      headless = null;
      _currentBypassCompleter = null;
      _currentBypassUrl = null;
      if (markBypassed) {
        _bypassedDomains.add(domain);
        debugPrint(
            'CloudflareInterceptor: Marked $domain as bypassed (no cookies)');
      }
    }

    // Safety timeout: 45 seconds (Android networks can be slow)
    safetyTimer = Timer(const Duration(seconds: 45), () {
      debugPrint(
          'CloudflareInterceptor: GLOBAL BYPASS TIMEOUT (45s) for $url');
      cleanup(markBypassed: true);
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
        userAgent: _userAgent ?? defaultUserAgent,
      ),
      onLoadStop: (controller, currentUri) async {
        debugPrint(
            'CloudflareInterceptor: Page load finished ($currentUri)');

        int attempts = 0;
        pollTimer?.cancel();
        pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
          attempts++;
          if (headless == null) {
            timer.cancel();
            return;
          }

          try {
            final activeUri =
                await controller.getUrl() ?? currentUri ?? webUri;
            final cookieManager = CookieManager.instance();

            final cookiesList =
                await cookieManager.getCookies(url: activeUri);
            if (activeUri.host != webUri.host) {
              final origCookies =
                  await cookieManager.getCookies(url: webUri);
              cookiesList.addAll(origCookies);
            }

            final jsCookies = await controller.evaluateJavascript(
              source: 'document.cookie',
            );

            final cookieMap = <String, String>{};
            for (var c in cookiesList) {
              cookieMap[c.name] = c.value;
            }
            if (jsCookies != null && jsCookies.toString().isNotEmpty) {
              final raw =
                  jsCookies.toString().replaceAll('"', '');
              for (var pair in raw.split(';')) {
                final parts = pair.trim().split('=');
                if (parts.length >= 2) {
                  cookieMap[parts[0].trim()] =
                      parts.sublist(1).join('=').trim();
                }
              }
            }

            final hasClearance = cookieMap.containsKey('cf_clearance');
            final title = await controller.getTitle();
            final isChallengeTitle = title != null &&
                (title.contains('Just a moment') ||
                    title.contains('Cloudflare'));

            // Success conditions:
            // 1. Got cf_clearance cookie (definitive bypass)
            // 2. Page is no longer a challenge AND we've tried enough times
            // 3. Max attempts reached (give up, mark domain as attempted)
            if (hasClearance ||
                (!isChallengeTitle && attempts >= 5) ||
                attempts >= 20) {
              timer.cancel();

              final ua = await controller.evaluateJavascript(
                source: 'navigator.userAgent',
              );

              if (ua != null && ua.toString().isNotEmpty) {
                _userAgent = ua.toString().replaceAll('"', '');
              }

              if (cookieMap.isNotEmpty) {
                _cookiesByDomain[domain] = cookieMap.entries
                    .map((e) => '${e.key}=${e.value}')
                    .join('; ');
                _bypassedDomains.add(domain);
                debugPrint(
                  'CloudflareInterceptor: Bypass successful for $domain (attempts: $attempts, cookies: ${cookieMap.keys.toList()})',
                );

                // Also bypass known image CDN domains so chapter images get
                // Cloudflare clearance cookies.
                for (final cdn in _imageCdnDomains) {
                  if (!_bypassedDomains.contains(cdn)) {
                    debugPrint(
                        'CloudflareInterceptor: Bypassing image CDN $cdn');
                    await bypass('https://$cdn/');
                  }
                }
              } else {
                // No cookies but page loaded — mark as bypassed anyway so we
                // don't loop forever trying the same thing.
                debugPrint(
                    'CloudflareInterceptor: No cookies extracted for $domain, marking as attempted');
                _bypassedDomains.add(domain);
              }
              cleanup();
            }
          } catch (e) {
            debugPrint('CloudflareInterceptor: Poll error: $e');
            if (attempts >= 20) {
              timer.cancel();
              cleanup(markBypassed: true);
            }
          }
        });
      },
      onReceivedError: (controller, request, error) {
        debugPrint('CloudflareInterceptor: Load error for $url: $error');
      },
      onReceivedHttpError:
          (controller, request, errorResponse) {
        debugPrint(
            'CloudflareInterceptor: HTTP error (${errorResponse.statusCode}): ${errorResponse.reasonPhrase} for $url');
      },
    );

    try {
      await headless?.run();
      debugPrint(
          'CloudflareInterceptor: Headless instance running for $url...');
    } catch (e) {
      debugPrint(
          'CloudflareInterceptor: Failed to start headless for $url: $e');
      cleanup(markBypassed: true);
    }

    return _currentBypassCompleter!.future;
  }

  /// Fetch a URL through the r.jina.ai reader proxy.
  /// jina.ai reader fetches the page server-side and returns cleaned content.
  /// Setting x-respond-with: html returns raw HTML instead of markdown.
  static Future<String?> fetchViaJinaAi(String url) async {
    // Jina.ai expects the URL unencoded in the path: https://r.jina.ai/https://example.com/
    final proxyUrl = '$_jinaAiReader$url';

    try {
      final response = await http.Client().get(
        Uri.parse(proxyUrl),
        headers: {
          'x-respond-with': 'html', // Request HTML, not markdown
          'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
          'User-Agent': defaultUserAgent,
        },
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        debugPrint(
            'CloudflareInterceptor: Jina.ai proxy succeeded for $url (len=${response.body.length})');
        return response.body;
      }

      debugPrint(
          'CloudflareInterceptor: Jina.ai proxy returned status ${response.statusCode} for $url');
      return null;
    } catch (e) {
      debugPrint('CloudflareInterceptor: Jina.ai proxy error for $url: $e');
      return null;
    }
  }

  static bool isDomainBypassed(String domain) => _bypassedDomains.contains(domain);

  /// Whether Cloudflare clearance cookies were actually stored for this URL's
  /// domain. Returns false if bypass ran but no cookies were captured
  /// (common on Android when HeadlessInAppWebView fails).
  static bool hasCookiesForUrl(String url) {
    final uri = Uri.parse(url);
    final domain = uri.host;
    final cookies = _cookiesByDomain[domain];
    if (cookies == null || cookies.isEmpty) return false;
    // Must contain cf_clearance to be a valid Cloudflare bypass.
    return cookies.contains('cf_clearance');
  }

  static bool get isReady => _bypassedDomains.isNotEmpty;
}
