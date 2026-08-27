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

  group('JikanRemoteDataSource.getEpisodes', () {
    const episodesJson = '''
{
  "data": [
    {
      "mal_id": 1,
      "title": "The Journey's End",
      "aired": "2023-09-29T00:00:00+00:00",
      "filler": false,
      "recap": false
    },
    {
      "mal_id": 2,
      "title": "It Didn't Have to Be Magic",
      "aired": null,
      "filler": true,
      "recap": false
    }
  ]
}
''';

    test('maps titles, air dates, filler flags and stable ids', () async {
      final ds = _dataSource((_) => episodesJson);

      final episodes = await ds.getEpisodes('52991');

      expect(episodes, hasLength(2));

      final first = episodes.first;
      expect(first.id, '52991_1');
      expect(first.animeId, '52991');
      expect(first.number, 1);
      expect(first.title, "The Journey's End");
      expect(first.airedLabel, 'Sep 29, 2023');
      expect(first.isFiller, isFalse);

      final second = episodes[1];
      expect(second.airedLabel, ''); // null aired → blank, not a crash
      expect(second.isFiller, isTrue);
    });
  });

  group('JikanRemoteDataSource.getGenres', () {
    test('maps genres to id + name, dropping incomplete rows', () async {
      const genresJson = '''
{
  "data": [
    { "mal_id": 1, "name": "Action", "count": 100 },
    { "mal_id": 10, "name": "Fantasy", "count": 80 },
    { "mal_id": 99, "name": "" }
  ]
}
''';
      final ds = _dataSource((_) => genresJson);

      final genres = await ds.getGenres();

      expect(genres.map((g) => g.id), ['1', '10']);
      expect(genres.first.name, 'Action');
      expect(genres.first.count, 100);
    });
  });

  group('JikanRemoteDataSource.searchAnime', () {
    const searchJson = '''
{
  "data": [
    {
      "mal_id": 52991,
      "title": "Sousou no Frieren",
      "title_english": "Frieren: Beyond Journey's End",
      "images": { "jpg": { "large_image_url": "https://img/frieren.jpg" } },
      "score": 9.3,
      "episodes": 28,
      "genres": [ { "name": "Adventure" } ]
    }
  ]
}
''';

    test('maps search results into Anime', () async {
      final ds = _dataSource((_) => searchJson);

      final results = await ds.searchAnime(query: 'frieren');

      expect(results, hasLength(1));
      expect(results.first.id, '52991');
      expect(results.first.title, "Frieren: Beyond Journey's End");
      expect(results.first.rating, 9.3);
      expect(results.first.genres, ['Adventure']);
    });

    test('short-circuits to empty with no query and no genre (no network)',
        () async {
      var called = false;
      final ds = _dataSource((_) {
        called = true;
        return '{"data":[]}';
      });

      expect(await ds.searchAnime(), isEmpty);
      expect(called, isFalse); // never hit the adapter
    });

    test('searches by genre alone (no query)', () async {
      final ds = _dataSource((_) => searchJson);

      final results = await ds.searchAnime(genreId: '2');

      expect(results, hasLength(1));
    });
  });
}
