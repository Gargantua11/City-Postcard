import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'backend_api_client.dart';
import 'discussion_service.dart';

class LikedPostcardService {
  LikedPostcardService({BackendApiClient? apiClient})
    : _apiClient = apiClient ?? BackendApiClient();

  static const String _storageKey = 'liked_postcards_v1';
  static bool _useVolatileMode = false;
  static List<DiscussionPost> _volatileLikedPosts = const <DiscussionPost>[];

  final BackendApiClient _apiClient;

  Future<List<DiscussionPost>> getLikedPosts() async {
    try {
      final online = await _fetchLikedPostsOnline();
      await _saveLikedPosts(online);
      return online;
    } catch (_) {
      return _readLikedPostsLocal();
    }
  }

  Future<bool> isLiked(DiscussionPost post) async {
    if (post.id > 0) {
      for (final path in <String>[
        '/postcard/${post.id}/like/status',
        '/postcard/${post.id}/liked/status',
        '/postcard/${post.id}/like',
      ]) {
        try {
          final body = await _apiClient.get(path, requireAuth: true);
          final liked = _readLikedFlag(body);
          if (liked != null) {
            return liked;
          }
        } catch (_) {
          continue;
        }
      }
    }

    final likedPosts = await _readLikedPostsLocal();
    return _findPostIndex(likedPosts, post) >= 0;
  }

  Future<bool> toggleLike(DiscussionPost post) async {
    if (post.id <= 0) {
      return _toggleLocalLike(post);
    }

    try {
      final current = await isLiked(post);
      if (current) {
        await _requestUnlike(post.id);
      } else {
        await _requestLike(post.id);
      }

      final likedPosts = List<DiscussionPost>.of(await _readLikedPostsLocal());
      final index = _findPostIndex(likedPosts, post);
      if (current) {
        if (index >= 0) {
          likedPosts.removeAt(index);
        }
      } else if (index < 0) {
        likedPosts.insert(0, post);
      }
      await _saveLikedPosts(likedPosts);
      return !current;
    } catch (_) {
      return _toggleLocalLike(post);
    }
  }

  Future<void> removeLike(DiscussionPost post) async {
    if (post.id > 0) {
      try {
        await _requestUnlike(post.id);
      } catch (_) {}
    }

    final likedPosts = List<DiscussionPost>.of(await _readLikedPostsLocal());
    likedPosts.removeWhere((item) => _isSamePost(item, post));
    await _saveLikedPosts(likedPosts);
  }

  Future<List<DiscussionPost>> _fetchLikedPostsOnline() async {
    BackendApiException? lastBackendError;
    for (final path in const <String>[
      '/postcard/like',
      '/postcard/liked',
      '/postcard/likes',
    ]) {
      try {
        final body = await _apiClient.get(path, requireAuth: true);
        final data = BackendApiClient.extractData(body);
        final rawList = BackendApiClient.extractList(data);

        final posts = <DiscussionPost>[];
        for (final item in rawList) {
          final map = _asStringMap(item);
          if (map == null) continue;
          posts.add(DiscussionPost.fromJson(map));
        }

        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return posts;
      } on BackendApiException catch (e) {
        lastBackendError = e;
      }
    }

    if (lastBackendError != null) throw lastBackendError;
    throw const BackendApiException('加载点赞帖子失败');
  }

  Future<void> _requestLike(int postId) async {
    BackendApiException? lastBackendError;
    for (final path in <String>[
      '/postcard/$postId/like',
      '/postcard/$postId/like/add',
      '/postcard/$postId/thumb-up',
    ]) {
      try {
        await _apiClient.post(path, requireAuth: true);
        return;
      } on BackendApiException catch (e) {
        lastBackendError = e;
      } catch (_) {}
    }

    if (lastBackendError != null) throw lastBackendError;
    throw const BackendApiException('点赞失败');
  }

  Future<void> _requestUnlike(int postId) async {
    BackendApiException? lastBackendError;

    for (final path in <String>[
      '/postcard/$postId/like',
      '/postcard/$postId/thumb-up',
    ]) {
      try {
        await _apiClient.delete(path, requireAuth: true);
        return;
      } on BackendApiException catch (e) {
        lastBackendError = e;
      } catch (_) {}
    }

    for (final path in <String>[
      '/postcard/$postId/unlike',
      '/postcard/$postId/cancel-like',
      '/postcard/$postId/like/cancel',
      '/postcard/$postId/thumb-up/cancel',
    ]) {
      try {
        await _apiClient.post(path, requireAuth: true);
        return;
      } on BackendApiException catch (e) {
        lastBackendError = e;
      } catch (_) {}
    }

    if (lastBackendError != null) throw lastBackendError;
    throw const BackendApiException('取消点赞失败');
  }

  bool? _readLikedFlag(Map<String, dynamic> body) {
    dynamic raw = BackendApiClient.extractData(body);
    final direct = _toBool(raw);
    if (direct != null) return direct;

    final map = _asStringMap(raw) ?? body;
    for (final key in const [
      'liked',
      'isLiked',
      'hasLiked',
      'like',
      'status',
      'thumbUp',
      'thumbup',
    ]) {
      final parsed = _toBool(map[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  bool? _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return null;
  }

  Future<bool> _toggleLocalLike(DiscussionPost post) async {
    final likedPosts = List<DiscussionPost>.of(await _readLikedPostsLocal());
    final index = _findPostIndex(likedPosts, post);

    if (index >= 0) {
      likedPosts.removeAt(index);
      await _saveLikedPosts(likedPosts);
      return false;
    }

    likedPosts.insert(0, post);
    await _saveLikedPosts(likedPosts);
    return true;
  }

  Future<List<DiscussionPost>> _readLikedPostsLocal() async {
    if (_useVolatileMode) {
      return _sortedCopy(_volatileLikedPosts);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.trim().isEmpty) {
        _volatileLikedPosts = const <DiscussionPost>[];
        return <DiscussionPost>[];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        await prefs.remove(_storageKey);
        _volatileLikedPosts = const <DiscussionPost>[];
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
      _volatileLikedPosts = List<DiscussionPost>.of(posts, growable: false);

      if (hasInvalidRecord) {
        await _persistToPrefs(prefs, posts);
      }

      return posts;
    } on FormatException {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_storageKey);
      } catch (_) {}
      _volatileLikedPosts = const <DiscussionPost>[];
      return <DiscussionPost>[];
    } catch (_) {
      _useVolatileMode = true;
      return _sortedCopy(_volatileLikedPosts);
    }
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

  Future<void> _saveLikedPosts(List<DiscussionPost> likedPosts) async {
    _volatileLikedPosts = List<DiscussionPost>.of(likedPosts, growable: false);

    if (_useVolatileMode) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final ok = await _persistToPrefs(prefs, likedPosts);
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
    List<DiscussionPost> likedPosts,
  ) async {
    final encoded = jsonEncode(
      likedPosts.map((item) => item.toJson()).toList(growable: false),
    );
    return prefs.setString(_storageKey, encoded);
  }
}
