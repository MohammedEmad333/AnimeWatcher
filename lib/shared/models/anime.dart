import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

/// Core catalog entity representing a single anime title.
///
/// Used across Home, Details and Favorites. Because favorites are persisted
/// locally, [Anime] carries a hand-written [TypeAdapter] (see
/// [AnimeAdapter]) rather than relying on generated code, keeping the project
/// buildable without running `build_runner`.
class Anime extends Equatable {
  const Anime({
    required this.id,
    required this.title,
    required this.coverUrl,
    this.synopsis = '',
    this.rating = 0.0,
    this.genres = const [],
    this.episodeCount = 0,
  });

  final String id;
  final String title;
  final String coverUrl;
  final String synopsis;

  /// Score on a 0–10 scale.
  final double rating;
  final List<String> genres;
  final int episodeCount;

  factory Anime.fromJson(Map<String, dynamic> json) {
    return Anime(
      id: json['id'].toString(),
      title: (json['title'] ?? '') as String,
      coverUrl: (json['cover_url'] ?? json['coverUrl'] ?? '') as String,
      synopsis: (json['synopsis'] ?? '') as String,
      rating: _toDouble(json['rating']),
      genres: _toStringList(json['genres']),
      episodeCount: _toInt(json['episode_count'] ?? json['episodeCount']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cover_url': coverUrl,
        'synopsis': synopsis,
        'rating': rating,
        'genres': genres,
        'episode_count': episodeCount,
      };

  @override
  List<Object?> get props => [id];

  // --- JSON parsing helpers (defensive against loosely-typed backends) -------
  static double _toDouble(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  static int _toInt(Object? v) =>
      v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  static List<String> _toStringList(Object? v) =>
      v is List ? v.map((e) => e.toString()).toList() : const [];
}

/// Hive [TypeAdapter] for persisting favorited [Anime] entities.
class AnimeAdapter extends TypeAdapter<Anime> {
  @override
  final int typeId = 1;

  @override
  Anime read(BinaryReader reader) {
    final fields = reader.readMap().cast<int, dynamic>();
    return Anime(
      id: fields[0] as String,
      title: fields[1] as String,
      coverUrl: fields[2] as String,
      synopsis: (fields[3] as String?) ?? '',
      rating: (fields[4] as num?)?.toDouble() ?? 0.0,
      genres: (fields[5] as List?)?.cast<String>() ?? const [],
      episodeCount: (fields[6] as int?) ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, Anime obj) {
    writer.writeMap(<int, dynamic>{
      0: obj.id,
      1: obj.title,
      2: obj.coverUrl,
      3: obj.synopsis,
      4: obj.rating,
      5: obj.genres,
      6: obj.episodeCount,
    });
  }
}
