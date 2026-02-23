import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'discussion_service.dart';

class FavoritePostcardService {
  static const String _storageKey = 'favorite_postcards_v1';
  static bool _useVolatileMode = false;
  static List<DiscussionPost> _volatileFavorites = const <DiscussionPost>[];

  Future<List<DiscussionPost>> getFavorites() async {
    if (_useVolatileMode) {
      return _sortedCopy(_volatileFavorites);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.trim().isEmpty) {
        _volatileFavorites = const <DiscussionPost>[];
        return <DiscussionPost>[];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        await prefs.remove(_storageKey);
        _volatileFavorites = const <DiscussionPost>[];
        return <DiscussionPost>[];
      }

      final posts = <DiscussionPost>[];
      var hasInvalidRecord = false;
      for (final item in decoded) {
        final map = _asStringMap(item);
        if (map == null) {
          hasInvalidRecord = true;
          continue;
        }

        try {
          posts.add(DiscussionPost.fromJson(map));
        } catch (_) {
          hasInvalidRecord = true;
        }
      }

      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _volatileFavorites = List<DiscussionPost>.of(posts, growable: false);

      if (hasInvalidRecord) {
        await _persistToPrefs(prefs, posts);
      }

      return posts;
    } on FormatException {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_storageKey);
      } catch (_) {}
      _volatileFavorites = const <DiscussionPost>[];
      return <DiscussionPost>[];
    } catch (_) {
      _useVolatileMode = true;
      return _sortedCopy(_volatileFavorites);
    }
  }

  Future<bool> isFavorited(DiscussionPost post) async {
    final favorites = await getFavorites();
    return _findPostIndex(favorites, post) >= 0;
  }

  Future<bool> toggleFavorite(DiscussionPost post) async {
    final favorites = List<DiscussionPost>.of(await getFavorites());
    final index = _findPostIndex(favorites, post);

    if (index >= 0) {
      favorites.removeAt(index);
      await _saveFavorites(favorites);
      return false;
    }

    favorites.insert(0, post);
    await _saveFavorites(favorites);
    return true;
  }

  Future<void> removeFavorite(DiscussionPost post) async {
    final favorites = List<DiscussionPost>.of(await getFavorites());
    favorites.removeWhere((item) => _isSamePost(item, post));
    await _saveFavorites(favorites);
  }

  int _findPostIndex(List<DiscussionPost> posts, DiscussionPost target) {
    for (int i = 0; i < posts.length; i++) {
      if (_isSamePost(posts[i], target)) return i;
    }
    return -1;
  }

  bool _isSamePost(DiscussionPost a, DiscussionPost b) {
    if (a.id > 0 && b.id > 0) {
      return a.id == b.id;
    }

    return a.imageUrl.trim() == b.imageUrl.trim() &&
        a.username.trim() == b.username.trim() &&
        a.createdAt.isAtSameMomentAs(b.createdAt);
  }

  Future<void> _saveFavorites(List<DiscussionPost> favorites) async {
    _volatileFavorites = List<DiscussionPost>.of(favorites, growable: false);

    if (_useVolatileMode) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final ok = await _persistToPrefs(prefs, favorites);
      if (!ok) {
        _useVolatileMode = true;
      }
    } catch (_) {
      _useVolatileMode = true;
    }
  }

  Map<String, dynamic>? _asStringMap(dynamic item) {
    if (item is Map<String, dynamic>) {
      return item;
    }
    if (item is Map) {
      return item.cast<String, dynamic>();
    }
    return null;
  }

  List<DiscussionPost> _sortedCopy(List<DiscussionPost> source) {
    if (source.isEmpty) return <DiscussionPost>[];
    final copy = List<DiscussionPost>.of(source);
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

  Future<bool> _persistToPrefs(
    SharedPreferences prefs,
    List<DiscussionPost> favorites,
  ) async {
    final encoded = jsonEncode(
      favorites.map((item) => item.toJson()).toList(growable: false),
    );
    return prefs.setString(_storageKey, encoded);
  }
}
