import 'package:hive/hive.dart';

import '../../../core/error/exceptions.dart';
import '../../../shared/models/anime.dart';

/// Persists the user's favorited anime in a Hive box keyed by anime id.
///
/// The box is registered/opened once at startup (see `bootstrap`), so this
/// datasource assumes [Hive] is already initialized and the [AnimeAdapter]
/// registered.
class FavoritesLocalDataSource {
  static const String boxName = 'favorites';

  Box<Anime> get _box => Hive.box<Anime>(boxName);

  List<Anime> getAll() {
    try {
      // Newest first: Hive preserves insertion order via values.
      return _box.values.toList().reversed.toList();
    } catch (e) {
      throw CacheException('Failed to read favorites: $e');
    }
  }

  bool isFavorite(String animeId) => _box.containsKey(animeId);

  Future<void> add(Anime anime) async {
    try {
      await _box.put(anime.id, anime);
    } catch (e) {
      throw CacheException('Failed to save favorite: $e');
    }
  }

  Future<void> remove(String animeId) async {
    try {
      await _box.delete(animeId);
    } catch (e) {
      throw CacheException('Failed to remove favorite: $e');
    }
  }
}
