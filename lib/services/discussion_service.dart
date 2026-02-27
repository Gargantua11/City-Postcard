import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_api_client.dart';

class DiscussionFetchResult {
  final List<DiscussionPost> posts;
  final bool isOffline;
  final String? notice;

  const DiscussionFetchResult({
    required this.posts,
    required this.isOffline,
    this.notice,
  });
}

class DiscussionPost {
  final int id;
  final String username;
  final String? avatar;
  final String imageUrl;
  final DateTime createdAt;
  final String address;
  final int likeCount;
  final int commentCount;
  final String hotComment;

  const DiscussionPost({
    required this.id,
    required this.username,
    this.avatar,
    required this.imageUrl,
    required this.createdAt,
    required this.address,
    required this.likeCount,
    required this.commentCount,
    required this.hotComment,
  });

  factory DiscussionPost.fromJson(Map<String, dynamic> json) {
    final hotComment = _extractHotComment(json);

    return DiscussionPost(
      id:
          BackendApiClient.readInt(json, const [
            'postcardId',
            'cardId',
            'id',
            'postId',
          ]) ??
          0,
      username: _extractUsername(json) ?? '匿名用户',
      avatar: BackendApiClient.readString(json, const ['avatar', 'avatarUrl']),
      imageUrl:
          BackendApiClient.readString(json, const [
            'imageUrl',
            'image',
            'url',
          ]) ??
          '',
      createdAt: _parseDateTime(
        BackendApiClient.readString(json, const [
              'createdAt',
              'createTime',
              'publishTime',
              'time',
            ]) ??
            '',
      ),
      address:
          BackendApiClient.readString(json, const [
            'address',
            'location',
            'cityName',
          ]) ??
          '未知地点',
      likeCount:
          BackendApiClient.readInt(json, const [
            'likeCount',
            'likes',
            'likeNum',
          ]) ??
          0,
      commentCount:
          BackendApiClient.readInt(json, const [
            'commentCount',
            'comments',
            'commentNum',
          ]) ??
          0,
      hotComment: hotComment,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'username': username,
      'avatar': avatar,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'address': address,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'hotComment': hotComment,
    };
  }

  static String _extractHotComment(Map<String, dynamic> json) {
    final direct = BackendApiClient.readString(json, const [
      'hotComment',
      'hotCommentContent',
    ]);
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final nested = BackendApiClient.asMap(json['hotComment']);
    final nestedContent = BackendApiClient.readString(nested, const [
      'content',
      'commentContent',
    ]);
    return nestedContent ?? '';
  }

  static String? _extractUsername(Map<String, dynamic> json) {
    final directNickname = BackendApiClient.readString(json, const [
      'nickname',
      'nickName',
      'userNickname',
      'displayName',
    ]);
    if (directNickname != null && directNickname.isNotEmpty) {
      return directNickname;
    }

    final directUsername = BackendApiClient.readString(json, const [
      'username',
      'userName',
    ]);
    if (directUsername != null &&
        directUsername.isNotEmpty &&
        !_looksLikePhone(directUsername)) {
      return directUsername;
    }

    final nestedUser = BackendApiClient.asMap(
      json['user'] ?? json['author'] ?? json['publisher'],
    );
    final nestedNickname = BackendApiClient.readString(nestedUser, const [
      'nickname',
      'nickName',
      'userNickname',
      'displayName',
    ]);
    if (nestedNickname != null && nestedNickname.isNotEmpty) {
      return nestedNickname;
    }

    final nestedUsername = BackendApiClient.readString(nestedUser, const [
      'username',
      'userName',
    ]);
    if (nestedUsername != null &&
        nestedUsername.isNotEmpty &&
        !_looksLikePhone(nestedUsername)) {
      return nestedUsername;
    }

    return null;
  }

  static bool _looksLikePhone(String value) {
    final digits = value.trim().replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length == 11;
  }

  static DateTime _parseDateTime(String raw) {
    if (raw.trim().isEmpty) {
      return DateTime.now();
    }

    DateTime? parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;

    parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (parsed != null) return parsed;

    return DateTime.now();
  }
}

class DiscussionService {
  static const String _postsCacheKey = 'discussion_posts_cache_v1';
  static const String _localPostsKey = 'discussion_local_posts_v1';
  static const String _defaultHotComment = '分享一张明信片';
  static const List<String> _publishEndpoints = <String>[
    '/discussion/postcards',
    '/discussion/postcard',
    '/postcard/publish',
  ];

  DiscussionService({BackendApiClient? apiClient})
    : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;

  Future<void> publishPost({
    required String username,
    required String imageUrl,
    required String address,
    String hotComment = '',
    String? avatar,
    String? cityName,
    String? cityCode,
    String? provinceName,
    double? latitude,
    double? longitude,
  }) async {
    final source = imageUrl.trim();
    if (source.isEmpty) {
      throw ArgumentError('imageUrl cannot be empty');
    }

    final normalizedAddress = address.trim();
    final normalizedCityName = cityName?.trim();
    final normalizedCityCode = cityCode?.trim();
    final normalizedProvinceName = provinceName?.trim();
    final trimmedHotComment = hotComment.trim();
    final normalizedHotComment = trimmedHotComment.isEmpty
        ? _defaultHotComment
        : trimmedHotComment;

    final payload = <String, dynamic>{
      'imageUrl': source,
      'image': source,
      'url': source,
      'address': normalizedAddress.isEmpty ? '未知地点' : normalizedAddress,
      'location': normalizedAddress.isEmpty ? '未知地点' : normalizedAddress,
      'hotComment': normalizedHotComment,
      'hotCommentContent': normalizedHotComment,
      'content': normalizedHotComment,
      'username': username.trim().isEmpty ? '我' : username.trim(),
      'cityName': normalizedCityName,
      'cityCode': normalizedCityCode,
      'provinceName': normalizedProvinceName,
      'latitude': latitude,
      'longitude': longitude,
    };
    payload.removeWhere(
      (key, value) => value == null || (value is String && value.isEmpty),
    );

    for (final path in _publishEndpoints) {
      try {
        await _apiClient.post(path, body: payload, requireAuth: true);
        return;
      } on BackendApiException {
        continue;
      } catch (_) {
        continue;
      }
    }

    // Keep posting usable when backend publish API is unavailable.
    await publishLocalPost(
      username: username,
      avatar: avatar,
      imageUrl: source,
      address: normalizedAddress,
      hotComment: normalizedHotComment,
    );
  }

  Future<void> publishLocalPost({
    required String username,
    required String imageUrl,
    required String address,
    String hotComment = '',
    String? avatar,
  }) async {
    final source = imageUrl.trim();
    if (source.isEmpty) {
      throw ArgumentError('imageUrl cannot be empty');
    }

    final avatarText = avatar?.trim();
    final normalizedAvatar = avatarText == null || avatarText.isEmpty
        ? null
        : avatarText;

    final now = DateTime.now();
    final post = DiscussionPost(
      id: now.microsecondsSinceEpoch,
      username: username.trim().isEmpty ? '我' : username.trim(),
      avatar: normalizedAvatar,
      imageUrl: source,
      createdAt: now,
      address: address.trim().isEmpty ? '未知地点' : address.trim(),
      likeCount: 0,
      commentCount: 0,
      hotComment: hotComment.trim(),
    );

    final localPosts = List<DiscussionPost>.from(await _readLocalPosts());
    localPosts.insert(0, post);
    await _saveLocalPosts(localPosts);
  }

  Future<DiscussionFetchResult> fetchPostsWithOfflineFallback({
    DateTime? lastTime,
  }) async {
    final localPosts = await _readLocalPosts();

    try {
      final onlinePosts = await _fetchPostsOnline(lastTime: lastTime);
      await _savePostsCache(onlinePosts);
      return DiscussionFetchResult(
        posts: _mergePosts(onlinePosts, localPosts),
        isOffline: false,
      );
    } on BackendApiException catch (e) {
      final cachedPosts = await _readPostsCache();
      if (cachedPosts.isNotEmpty) {
        return DiscussionFetchResult(
          posts: _mergePosts(cachedPosts, localPosts),
          isOffline: true,
          notice: e.isUnauthorized ? '登录状态已失效，已展示本地缓存内容' : '网络异常，已展示离线缓存内容',
        );
      }

      return DiscussionFetchResult(
        posts: _mergePosts(_buildOfflineSeedPosts(), localPosts),
        isOffline: true,
        notice: e.isUnauthorized ? '登录状态已失效，已展示本地离线内容' : '网络异常，已展示离线示例内容',
      );
    } catch (_) {
      final cachedPosts = await _readPostsCache();
      if (cachedPosts.isNotEmpty) {
        return DiscussionFetchResult(
          posts: _mergePosts(cachedPosts, localPosts),
          isOffline: true,
          notice: '网络异常，已展示离线缓存内容',
        );
      }

      return DiscussionFetchResult(
        posts: _mergePosts(_buildOfflineSeedPosts(), localPosts),
        isOffline: true,
        notice: '网络异常，已展示离线示例内容',
      );
    }
  }

  Future<List<DiscussionPost>> fetchPosts({DateTime? lastTime}) async {
    final result = await fetchPostsWithOfflineFallback(lastTime: lastTime);
    return result.posts;
  }

  Future<List<DiscussionPost>> _fetchPostsOnline({DateTime? lastTime}) async {
    final safeTime = lastTime ?? DateTime.now();
    final formatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(safeTime);

    final body = await _apiClient.get(
      '/discussion/postcards',
      queryParameters: <String, String>{'lastTime': formatted},
      requireAuth: true,
    );

    final data = BackendApiClient.extractData(body);
    final records = BackendApiClient.extractList(data);

    final posts = <DiscussionPost>[];
    for (final item in records) {
      final map = BackendApiClient.asMap(item);
      if (map == null) continue;
      posts.add(DiscussionPost.fromJson(map));
    }

    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  Future<void> _savePostsCache(List<DiscussionPost> posts) async {
    if (posts.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(posts.map((post) => post.toJson()).toList());
    await prefs.setString(_postsCacheKey, encoded);
  }

  Future<void> _saveLocalPosts(List<DiscussionPost> posts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(posts.map((post) => post.toJson()).toList());
    await prefs.setString(_localPostsKey, encoded);
  }

  Future<List<DiscussionPost>> _readLocalPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localPostsKey);
    if (raw == null || raw.trim().isEmpty) {
      return <DiscussionPost>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final posts = <DiscussionPost>[];
      for (final item in decoded) {
        final map = BackendApiClient.asMap(item);
        if (map == null) continue;
        posts.add(DiscussionPost.fromJson(map));
      }
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    } catch (_) {
      return <DiscussionPost>[];
    }
  }

  List<DiscussionPost> _mergePosts(
    List<DiscussionPost> primary,
    List<DiscussionPost> secondary,
  ) {
    if (secondary.isEmpty) return primary;

    final merged = <DiscussionPost>[...primary];
    final existingIds = merged.map((item) => item.id).toSet();

    for (final post in secondary) {
      if (existingIds.contains(post.id)) continue;
      merged.add(post);
    }

    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  Future<List<DiscussionPost>> _readPostsCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_postsCacheKey);
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final posts = <DiscussionPost>[];
      for (final item in decoded) {
        final map = BackendApiClient.asMap(item);
        if (map == null) continue;
        posts.add(DiscussionPost.fromJson(map));
      }
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    } catch (_) {
      return const [];
    }
  }

  List<DiscussionPost> _buildOfflineSeedPosts() {
    final now = DateTime.now();
    return <DiscussionPost>[
      DiscussionPost(
        id: 9001,
        username: '离线用户A',
        imageUrl: '',
        createdAt: now.subtract(const Duration(minutes: 20)),
        address: '北京',
        likeCount: 18,
        commentCount: 6,
        hotComment: '这张明信片氛围感很强',
      ),
      DiscussionPost(
        id: 9002,
        username: '离线用户B',
        imageUrl: '',
        createdAt: now.subtract(const Duration(hours: 2)),
        address: '上海',
        likeCount: 12,
        commentCount: 3,
        hotComment: '配色很舒服',
      ),
      DiscussionPost(
        id: 9003,
        username: '离线用户C',
        imageUrl: '',
        createdAt: now.subtract(const Duration(hours: 5)),
        address: '成都',
        likeCount: 9,
        commentCount: 2,
        hotComment: '',
      ),
    ];
  }
}
