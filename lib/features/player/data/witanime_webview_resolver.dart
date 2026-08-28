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

/// Result of a resolve attempt: either a stream, or null + a human-readable
/// trace of what happened (so failures can be shown on-device when there's no
/// console to read).
class ResolveResult {
  final ResolvedStream? stream;
  final List<String> trace;
  const ResolveResult(this.stream, this.trace);
  bool get ok => stream != null;
}

/// Resolves a WitAnime episode into a direct .m3u8/.mp4 URL using a headless
/// WebView that runs on the user's device (residential IP → Cloudflare clears).
class WitAnimeWebViewResolver {
  WitAnimeWebViewResolver({
    this.baseUrl = 'https://witanime.you',
    this.serverPreference = const ['mp4upload', 'streamwish', 'videa', 'vidbom', 'dood', 'yonaplay'],
    this.overallTimeout = const Duration(seconds: 60),
    this.cloudflareTimeout = const Duration(seconds: 25),
  });

  final String baseUrl;
  final List<String> serverPreference;
  final Duration overallTimeout;
  final Duration cloudflareTimeout;

  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Mobile Safari/537.36';

  String buildWatchUrl(String slug, int episodeNumber) {
    final b = baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$b/episode/$slug-\u0627\u0644\u062d\u0644\u0642\u0629-$episodeNumber/';
  }

  /// Convenience: returns just the stream (or null), discarding the trace.
  Future<ResolvedStream?> resolve({
    required String slug,
    required int episodeNumber,
  }) async {
    final r = await resolveWithTrace(slug: slug, episodeNumber: episodeNumber);
    return r.stream;
  }

  Future<ResolveResult> resolveWithTrace({
    required String slug,
    required int episodeNumber,
  }) {
    return resolveUrlWithTrace(buildWatchUrl(slug, episodeNumber));
  }

  Future<ResolveResult> resolveUrlWithTrace(String watchUrl) async {
    final trace = <String>[];
    void log(String m) => trace.add(m);

    final completer = Completer<ResolveResult>();
    HeadlessInAppWebView? headless;
    Timer? overallTimer;

    String referer = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/';
    var completed = false;
    var resourcesSeen = 0;

    void finish(ResolvedStream? result) {
      if (completed) return;
      completed = true;
      overallTimer?.cancel();
      headless?.dispose();
      if (!completer.isCompleted) completer.complete(ResolveResult(result, trace));
    }

    bool isMedia(String url) =>
        RegExp(r'\.m3u8(\?|$)', caseSensitive: false).hasMatch(url) ||
        RegExp(r'\.mp4(\?|$)', caseSensitive: false).hasMatch(url);
    String formatOf(String url) =>
        RegExp(r'\.m3u8', caseSensitive: false).hasMatch(url) ? 'hls' : 'mp4';

    log('watch: $watchUrl');

    overallTimer = Timer(overallTimeout, () {
      log('TIMEOUT after ${overallTimeout.inSeconds}s (resources seen: $resourcesSeen)');
      finish(null);
    });

    headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(watchUrl)),
      initialSettings: InAppWebViewSettings(
        userAgent: _userAgent,
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        transparentBackground: true,
        allowsInlineMediaPlayback: true,
        cacheEnabled: true,
      ),
      onLoadResource: (controller, resource) {
        final url = resource.url?.toString() ?? '';
        if (url.isEmpty) return;
        resourcesSeen++;
        if (isMedia(url)) {
          log('MEDIA: $url');
          finish(ResolvedStream(
            url: url,
            format: formatOf(url),
            headers: {'Referer': referer, 'User-Agent': _userAgent},
          ));
        }
      },
      onLoadStop: (controller, url) async {
        try {
          log('loadStop: $url');
          final cleared = await _waitForCloudflare(controller, log);
          log('cloudflare cleared: $cleared');
          if (!cleared) {
            finish(null);
            return;
          }

          await Future.delayed(const Duration(milliseconds: 1500));

          final clicked = await controller.evaluateJavascript(
            source: _clickServerJs(serverPreference),
          );
          log('clicked server: ${clicked ?? "(none)"}');

          await Future.delayed(const Duration(milliseconds: 1200));
          final iframeSrc = await controller.evaluateJavascript(
            source: "document.querySelector('iframe') ? document.querySelector('iframe').src : ''",
          );
          if (iframeSrc is String && iframeSrc.startsWith('http')) {
            final u = Uri.tryParse(iframeSrc);
            if (u != null) referer = '${u.scheme}://${u.host}/';
            log('iframe: $iframeSrc');
          } else {
            log('iframe: (none found)');
          }
        } catch (e) {
          log('onLoadStop error: $e');
        }
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame ?? false) {
          log('nav error: ${error.description}');
          finish(null);
        }
      },
    );

    log('launching webview...');
    await headless.run();
    return completer.future;
  }

  Future<bool> _waitForCloudflare(
    InAppWebViewController controller,
    void Function(String) log,
  ) async {
    final deadline = DateTime.now().add(cloudflareTimeout);
    final challenge = RegExp(
      r'just a moment|attention required|cloudflare|checking your browser',
      caseSensitive: false,
    );
    var lastTitle = '';
    while (DateTime.now().isBefore(deadline)) {
      final title = await controller.getTitle() ?? '';
      if (title != lastTitle) {
        log('title: "$title"');
        lastTitle = title;
      }
      if (!challenge.hasMatch(title)) return true;
      await Future.delayed(const Duration(milliseconds: 1200));
    }
    final title = await controller.getTitle() ?? '';
    return !challenge.hasMatch(title);
  }

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
        var any = document.querySelector('.server, [class*="server"] a, ul li a, .WatchList a');
        if (any) { try { any.click(); return 'default'; } catch(e) {} }
        return '';
      })();
    ''';
  }
}
