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
    this.headers = const {},
    this.quality = 'auto',
  });

  final String url;
  final StreamFormat format;

  /// Headers the player must forward to the CDN (Referer, User-Agent, …).
  final Map<String, String> headers;

  /// Quality label, e.g. "1080p", or "auto" for adaptive HLS.
  final String quality;

  factory StreamLink.fromJson(Map<String, dynamic> json) {
    final url = (json['url'] ?? '') as String;
    return StreamLink(
      url: url,
      format: StreamFormat.fromValue(json['format'] as String?, url),
      headers: (json['headers'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          const {},
      quality: (json['quality'] ?? 'auto') as String,
    );
  }

  @override
  List<Object?> get props => [url, format, quality];
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
