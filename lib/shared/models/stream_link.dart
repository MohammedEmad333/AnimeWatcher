import 'package:equatable/equatable.dart';

/// The direct, playable video link resolved by the backend for an episode.
///
/// The backend scrapes the source on the fly and returns a URL that is either a
/// progressive MP4 or an HLS (`.m3u8`) manifest, optionally with headers the
/// player must send (e.g. `Referer`) for the CDN to accept the request.
class StreamLink extends Equatable {
  const StreamLink({
    required this.url,
    required this.format,
    this.server = 'Default',
    this.headers = const {},
    this.quality = 'auto',
  });

  final String url;
  final StreamFormat format;

  /// Human-friendly server label shown in the server/quality picker
  /// (e.g. "VidStream", "MP4Upload"). Falls back to "Default" when the backend
  /// omits it.
  final String server;

  /// Headers the player must forward to the CDN (Referer, User-Agent, …).
  final Map<String, String> headers;

  /// Quality label, e.g. "1080p", or "auto" for adaptive HLS.
  final String quality;

  factory StreamLink.fromJson(Map<String, dynamic> json) {
    final url = (json['url'] ?? '') as String;
    final server = (json['server'] as String?)?.trim();
    return StreamLink(
      url: url,
      format: StreamFormat.fromValue(json['format'] as String?, url),
      server: (server == null || server.isEmpty) ? 'Default' : server,
      headers: (json['headers'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          const {},
      quality: (json['quality'] ?? 'auto') as String,
    );
  }

  /// A short label combining server and quality for the picker UI, e.g.
  /// "VidStream · 1080p".
  String get label => quality.isEmpty || quality == 'auto'
      ? server
      : '$server · $quality';

  @override
  List<Object?> get props => [url, format, server, quality];
}

/// Supported streaming container formats.
enum StreamFormat {
  mp4,
  hls;

  /// Resolves the format from an explicit backend value, falling back to
  /// inferring it from the URL extension.
  factory StreamFormat.fromValue(String? value, String url) {
    switch (value?.toLowerCase()) {
      case 'hls':
      case 'm3u8':
        return StreamFormat.hls;
      case 'mp4':
        return StreamFormat.mp4;
    }
    return url.toLowerCase().contains('.m3u8')
        ? StreamFormat.hls
        : StreamFormat.mp4;
  }
}
