import 'dart:convert';
import 'dart:typed_data';

import 'package:anime_watcher/features/catalog/data/jikan_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal [HttpClientAdapter] that answers every request with a canned
/// JSON body, so we can exercise [JikanRemoteDataSource]'s mapping without any
/// network access (Jikan is unreachable from CI sandboxes anyway).
class _CannedAdapter implements HttpClientAdapter {
  _CannedAdapter(this.bodyForPath);

  /// Maps a request path (e.g. `/watch/episodes`) to the JSON string to return.
  final String Function(String path) bodyForPath;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      bodyForPath(options.path),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

JikanRemoteDataSource _dataSource(String Function(String path) bodyForPath) {
  final dio = Dio(BaseOptions(responseType: ResponseType.json))
    ..httpClientAdapter = _CannedAdapter(bodyForPath);
  return JikanRemoteDataSource(dio: dio);
}

void main() {
  group('JikanRemoteDataSource.getLatestEpisodes', () {
    // Mirrors Jikan v4 `GET /watch/episodes`: grouped by title, each `entry`
    // carrying its most-recent `episodes`.
    const watchEpisodesJson = '''
{
  "data": [
    {
      "entry": {
        "mal_id": 52991,
        "title": "Sousou no Frieren",
        "images": { "jpg": { "image_url": "https://img/frieren.jpg" } }
      },
      "episodes": [
        { "mal_id": 28, "title": "Episode 28" },
        { "mal_id": 27, "title": "Episode 27" }
      ]
    },
    {
      "entry": {
        "mal_id": 21,
        "title": "One Piece",
        "images": { "jpg": { "image_url": "https://img/op.jpg" } }
      },
      "episodes": [
        { "mal_id": 1122, "title": "Episode 1122" }
      ]
    }
  ]
}
''';

    test('flattens grouped entries into ordered Episode rows', () async {
      final ds = _dataSource((_) => watchEpisodesJson);

      final episodes = await ds.getLatestEpisodes();

      expect(episodes, hasLength(3));

      final first = episodes.first;
      expect(first.id, '52991_28'); // stable composite key
      expect(first.animeId, '52991');
      expect(first.number, 28);
      expect(first.title, 'Sousou no Frieren'); // series name → tile subtitle
      expect(first.thumbnailUrl, 'https://img/frieren.jpg');

      expect(episodes.last.id, '21_1122');
      expect(episodes.last.number, 1122);
    });

    test('honours the limit across grouped entries', () async {
      final ds = _dataSource((_) => watchEpisodesJson);

      final episodes = await ds.getLatestEpisodes(limit: 2);

      expect(episodes, hasLength(2));
      expect(episodes.map((e) => e.id), ['52991_28', '52991_27']);
    });

    test('returns empty list when the payload has no data', () async {
      final ds = _dataSource((_) => jsonEncode({'data': null}));

      expect(await ds.getLatestEpisodes(), isEmpty);
    });
  });

  group('JikanRemoteDataSource.getCategories', () {
    test('maps genre names and drops blank ones', () async {
      const genresJson = '''
{
  "data": [
    { "mal_id": 1, "name": "Action", "count": 100 },
    { "mal_id": 2, "name": "Adventure", "count": 50 },
    { "mal_id": 4, "name": "", "count": 0 }
  ]
}
''';
      final ds = _dataSource((_) => genresJson);

      final categories = await ds.getCategories();

      expect(categories, ['Action', 'Adventure']);
    });

    test('returns empty list when the payload is not a list', () async {
      final ds = _dataSource((_) => jsonEncode({'data': {}}));

      expect(await ds.getCategories(), isEmpty);
    });
  });
}
