import 'package:equatable/equatable.dart';

/// An anime genre / category (e.g. Action, Slice of Life).
///
/// The [id] is MyAnimeList's genre id, required by Jikan's search endpoint
/// (`/anime?genres={id}`); [name] is the human-readable label shown in filter
/// chips. [count] is the number of titles in the genre when known (0 otherwise).
class Genre extends Equatable {
  const Genre({
    required this.id,
    required this.name,
    this.count = 0,
  });

  final String id;
  final String name;
  final int count;

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: (json['mal_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      count: json['count'] is num
          ? (json['count'] as num).toInt()
          : int.tryParse('${json['count']}') ?? 0,
    );
  }

  @override
  List<Object?> get props => [id];
}
