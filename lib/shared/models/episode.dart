import 'package:equatable/equatable.dart';

/// A single watchable episode.
///
/// Note: an [Episode] does not carry a video URL. The direct, playable link is
/// resolved on demand by the backend (scraping) via the streaming service when
/// the user taps to play. See `StreamLink`.
class Episode extends Equatable {
  const Episode({
    required this.id,
    required this.animeId,
    required this.number,
    required this.title,
    this.thumbnailUrl = '',
    this.durationLabel = '',
    this.airedLabel = '',
    this.synopsis = '',
    this.isFiller = false,
  });

  final String id;
  final String animeId;

  /// Episode number within the series (1-based).
  final int number;
  final String title;
  final String thumbnailUrl;

  /// Human-readable duration, e.g. "24 min".
  final String durationLabel;

  /// Human-readable air date, e.g. "Sep 29, 2023" (empty when unknown).
  final String airedLabel;

  /// Episode synopsis, when a metadata source provides one (often empty for
  /// bulk episode listings).
  final String synopsis;

  /// Whether the metadata source flags this as a filler episode.
  final bool isFiller;

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'].toString(),
      animeId: (json['anime_id'] ?? json['animeId'] ?? '').toString(),
      number: json['number'] is num
          ? (json['number'] as num).toInt()
          : int.tryParse('${json['number']}') ?? 0,
      title: (json['title'] ?? 'Episode') as String,
      thumbnailUrl:
          (json['thumbnail_url'] ?? json['thumbnailUrl'] ?? '') as String,
      durationLabel:
          (json['duration_label'] ?? json['durationLabel'] ?? '') as String,
      airedLabel: (json['aired_label'] ?? json['airedLabel'] ?? '') as String,
      synopsis: (json['synopsis'] ?? '') as String,
      isFiller: json['is_filler'] == true || json['filler'] == true,
    );
  }

  @override
  List<Object?> get props => [id];
}
