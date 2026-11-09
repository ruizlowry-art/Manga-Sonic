import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class CloudflareInterceptor {
  static const String defaultUserAgent =
      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  static String? _userAgent;
  // Store cookies per domain (host)
  static final Map<String, String> _cookiesByDomain = {};
  // Track which domains have been bypassed
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

  static Future<void> bypass(String url) async {
    final uri = Uri.parse(url);
    final domain = uri.host;

    // If already bypassed this domain, skip
    if (_bypassedDomains.contains(domain)) {
      debugPrint('CloudflareInterceptor: Domain $domain already bypassed, skipping');
      return;
    }

    // If already bypassing, just wait for that one.
    if (_currentBypassCompleter != null && !_currentBypassCompleter!.isCompleted) {
      // If it's the same URL, wait for it
      if (_currentBypassUrl == url) {
        debugPrint('CloudflareInterceptor: Already bypassing $url, waiting...');
        return _currentBypassCompleter!.future;
      }
      // Different URL - wait for current to complete, then bypass this one
      debugPrint('CloudflareInterceptor: Waiting for current bypass to complete before starting $url');
      await _currentBypassCompleter!.future;
    }

    _currentBypassCompleter = Completer<void>();
    _currentBypassUrl = url;
    HeadlessInAppWebView? headless;
    Timer? safetyTimer;
    Timer? pollTimer;

    void cleanup() {
      safetyTimer?.cancel();
      pollTimer?.cancel();
      if (!(_currentBypassCompleter?.isCompleted ?? true)) {
        _currentBypassCompleter?.complete();
      }
      try {
        headless?.dispose();
      } catch (e) {
        debugPrint('CloudflareInterceptor: Error disposing headless: $e');
      }
      headless = null;
      _currentBypassCompleter = null;
      _currentBypassUrl = null;
    }

    // Safety timeout: 30 seconds for the WHOLE process
    safetyTimer = Timer(const Duration(seconds: 30), () {
      debugPrint('CloudflareInterceptor: GLOBAL BYPASS TIMEOUT (30s) for $url');
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
        userAgent: _userAgent ?? defaultUserAgent,
      ),
      onLoadStop: (controller, currentUri) async {
        debugPrint('CloudflareInterceptor: Page load finished ($currentUri)');

        int attempts = 0;
        pollTimer?.cancel();
        pollTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
          attempts++;
          if (headless == null) {
            timer.cancel();
            return;
          }

          try {
            final activeUri = await controller.getUrl() ?? currentUri ?? webUri;
            final cookieManager = CookieManager.instance();

            final cookiesList = await cookieManager.getCookies(url: activeUri);
            if (activeUri.host != webUri.host) {
              final origCookies = await cookieManager.getCookies(url: webUri);
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
              final raw = jsCookies.toString().replaceAll('"', '');
              for (var pair in raw.split(';')) {
                final parts = pair.trim().split('=');
                if (parts.length >= 2) {
                  cookieMap[parts[0].trim()] = parts.sublist(1).join('=').trim();
                }
              }
            }

            final hasClearance = cookieMap.containsKey('cf_clearance');
            final title = await controller.getTitle();
            final isChallengeTitle = title != null &&
                (title.contains('Just a moment') || title.contains('Cloudflare'));

            if (hasClearance || (!isChallengeTitle && attempts >= 4) || attempts >= 12) {
              timer.cancel();

              final ua = await controller.evaluateJavascript(
                source: 'navigator.userAgent',
              );

              if (ua != null && ua.toString().isNotEmpty) {
                _userAgent = ua.toString().replaceAll('"', '');
              }

              if (cookieMap.isNotEmpty) {
                // Store cookies for this domain
                _cookiesByDomain[domain] = cookieMap.entries
                    .map((e) => '${e.key}=${e.value}')
                    .join('; ');
                _bypassedDomains.add(domain);
                debugPrint(
                  'CloudflareInterceptor: Bypass successful for $domain (attempts: $attempts, cookies: ${cookieMap.keys.toList()})',
                );
              } else {
                debugPrint('CloudflareInterceptor: No cookies extracted for $domain');
              }
              cleanup();
            }
          } catch (e) {
            debugPrint('CloudflareInterceptor: Poll error: $e');
            if (attempts >= 12) {
              timer.cancel();
              cleanup();
            }
          }
        });
      },
      onReceivedError: (controller, request, error) {
        debugPrint('CloudflareInterceptor: Load error for $url: $error');
      },
      onReceivedHttpError: (controller, request, errorResponse) {
        debugPrint('CloudflareInterceptor: HTTP error (${errorResponse.statusCode}): ${errorResponse.reasonPhrase} for $url');
      },
    );

    try {
      await headless?.run();
      debugPrint('CloudflareInterceptor: Headless instance running for $url...');
    } catch (e) {
      debugPrint('CloudflareInterceptor: Failed to start headless for $url: $e');
      cleanup();
    }

    return _currentBypassCompleter!.future;
  }

  static bool isDomainBypassed(String domain) => _bypassedDomains.contains(domain);

  static bool get isReady => _bypassedDomains.isNotEmpty;
}