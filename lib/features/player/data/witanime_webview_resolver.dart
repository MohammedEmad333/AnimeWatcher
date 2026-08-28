import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// A stream resolved on-device from WitAnime.
class ResolvedStream {
  final String url;
  final String format; // 'hls' | 'mp4'
  final Map<String, String> headers;

  const ResolvedStream({
    required this.url,
    required this.format,
    required this.headers,
  });

  @override
  String toString() => 'ResolvedStream($format, $url)';
}

/// Resolves a WitAnime episode into a direct .m3u8/.mp4 URL using a headless
/// WebView that runs on the user's device.
///
/// Why on-device: WitAnime sits behind Cloudflare, which blocks datacenter
/// (server) IPs but trusts residential ones. Running the page on the phone uses
/// the user's residential IP, so Cloudflare clears — the same reason the site
/// works in the user's normal browser. The page's own JS (Cloudflare check,
/// server decoder) runs for us; we just click a server and capture the media
/// URL the player loads.
///
/// Usage:
///   final resolver = WitAnimeWebViewResolver();
///   final stream = await resolver.resolve(
///     slug: 'rakudai-kenja-...-boukenroku',
///     episodeNumber: 1,
///   );
///   if (stream != null) { /* feed stream.url + stream.headers to better_player */ }
class WitAnimeWebViewResolver {
  WitAnimeWebViewResolver({
    this.baseUrl = 'https://witanime.you',
    this.serverPreference = const ['mp4upload', 'streamwish', 'videa', 'vidbom', 'dood', 'yonaplay'],
    this.overallTimeout = const Duration(seconds: 45),
    this.cloudflareTimeout = const Duration(seconds: 20),
  });

  final String baseUrl;
  final List<String> serverPreference;
  final Duration overallTimeout;
  final Duration cloudflareTimeout;

  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Mobile Safari/537.36';

  /// Builds the WitAnime watch URL from a slug + episode number.
  /// Pattern: {base}/episode/{slug}-الحلقة-{n}/
  String buildWatchUrl(String slug, int episodeNumber) {
    final b = baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$b/episode/$slug-\u0627\u0644\u062d\u0644\u0642\u0629-$episodeNumber/';
  }

  Future<ResolvedStream?> resolve({
    required String slug,
    required int episodeNumber,
  }) {
    final watchUrl = buildWatchUrl(slug, episodeNumber);
    return resolveUrl(watchUrl);
  }

  Future<ResolvedStream?> resolveUrl(String watchUrl) async {
    final completer = Completer<ResolvedStream?>();
    HeadlessInAppWebView? headless;
    Timer? overallTimer;

    // The embed's origin (mp4upload/streamwish/...) — used as Referer for the
    // media request, which many CDNs require. Filled once we read the iframe.
    String referer = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/';
    var completed = false;

    void finish(ResolvedStream? result) {
      if (completed) return;
      completed = true;
      overallTimer?.cancel();
      headless?.dispose();
      if (!completer.isCompleted) completer.complete(result);
    }

    bool isMedia(String url) =>
        RegExp(r'\.m3u8(\?|$)', caseSensitive: false).hasMatch(url) ||
        RegExp(r'\.mp4(\?|$)', caseSensitive: false).hasMatch(url);

    String formatOf(String url) =>
        RegExp(r'\.m3u8', caseSensitive: false).hasMatch(url) ? 'hls' : 'mp4';

    overallTimer = Timer(overallTimeout, () => finish(null));

    headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(watchUrl)),
      initialSettings: InAppWebViewSettings(
        userAgent: _userAgent,
        javaScriptEnabled: true,
        // Allow the embedded player to start loading without a tap, so it
        // fetches the manifest/metadata and we can capture the URL.
        mediaPlaybackRequiresUserGesture: false,
        transparentBackground: true,
        // Helps some players; harmless otherwise.
        allowsInlineMediaPlayback: true,
        cacheEnabled: true,
      ),

      // Fires for every resource the page (and its frames) loads — this is how
      // we catch the real .m3u8 / .mp4 without reversing anything.
      onLoadResource: (controller, resource) {
        final url = resource.url?.toString() ?? '';
        if (url.isNotEmpty && isMedia(url)) {
          finish(ResolvedStream(
            url: url,
            format: formatOf(url),
            headers: {'Referer': referer, 'User-Agent': _userAgent},
          ));
        }
      },

      onLoadStop: (controller, url) async {
        try {
          // 1) Wait out Cloudflare's interstitial if present.
          final cleared = await _waitForCloudflare(controller);
          if (!cleared) return; // overall timer will finish(null)

          // 2) Give WitAnime's JS a moment to build the server buttons.
          await Future.delayed(const Duration(milliseconds: 1500));

          // 3) Click a server (same-origin main frame, so JS injection works).
          await controller.evaluateJavascript(source: _clickServerJs(serverPreference));

          // 4) Read the embed iframe src to set the correct Referer.
          await Future.delayed(const Duration(milliseconds: 1200));
          final iframeSrc = await controller.evaluateJavascript(
            source: "document.querySelector('iframe') ? document.querySelector('iframe').src : ''",
          );
          if (iframeSrc is String && iframeSrc.startsWith('http')) {
            final u = Uri.tryParse(iframeSrc);
            if (u != null) referer = '${u.scheme}://${u.host}/';
          }
          // The embedded player now loads its media → onLoadResource catches it.
        } catch (_) {
          // ignore; overall timer handles the failure path
        }
      },

      onReceivedError: (controller, request, error) {
        // Navigation-level error on the main frame → give up early.
        if (request.isForMainFrame ?? false) finish(null);
      },
    );

    await headless.run();
    return completer.future;
  }

  /// Polls the page title until Cloudflare's challenge clears (or times out).
  Future<bool> _waitForCloudflare(InAppWebViewController controller) async {
    final deadline = DateTime.now().add(cloudflareTimeout);
    final challenge = RegExp(
      r'just a moment|attention required|cloudflare|checking your browser',
      caseSensitive: false,
    );
    while (DateTime.now().isBefore(deadline)) {
      final title = await controller.getTitle() ?? '';
      if (!challenge.hasMatch(title)) return true;
      await Future.delayed(const Duration(milliseconds: 1200));
    }
    // Final check.
    final title = await controller.getTitle() ?? '';
    return !challenge.hasMatch(title);
  }

  /// JS that clicks the first server button matching the preference list,
  /// falling back to the first server-like element.
  String _clickServerJs(List<String> preference) {
    final prefsJson = '[' + preference.map((p) => "'$p'").join(',') + ']';
    return '''
      (function() {
        var prefs = $prefsJson;
        var nodes = Array.prototype.slice.call(
          document.querySelectorAll('a,button,li,span,div')
        );
        function textOf(el){ return (el.textContent || '').toLowerCase(); }
        for (var p = 0; p < prefs.length; p++) {
          for (var i = 0; i < nodes.length; i++) {
            if (textOf(nodes[i]).indexOf(prefs[p]) !== -1) {
              try { nodes[i].click(); return prefs[p]; } catch(e) {}
            }
          }
        }
        // Fallback: click something that looks like a server switcher.
        var any = document.querySelector('.server, [class*="server"] a, ul li a, .WatchList a');
        if (any) { try { any.click(); return 'default'; } catch(e) {} }
        return '';
      })();
    ''';
  }
}
