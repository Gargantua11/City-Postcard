import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'backend_api_client.dart';

class PostcardComment {
  const PostcardComment({
    required this.id,
    required this.postcardId,
    required this.username,
    this.avatar,
    required this.location,
    required this.content,
    required this.createdAt,
    required this.liked,
    this.parentCommentId,
    this.replyToUsername,
  });

  final int id;
  final int postcardId;
  final String username;
  final String? avatar;
  final String location;
  final String content;
  final DateTime createdAt;
  final bool liked;
  final int? parentCommentId;
  final String? replyToUsername;

  bool get isReply => (parentCommentId ?? 0) > 0;

  factory PostcardComment.fromJson(
    Map<String, dynamic> json, {
    int? cardId,
    int? defaultParentCommentId,
    String? defaultReplyToUsername,
  }) {
    final parsedId =
        BackendApiClient.readInt(json, const ['id', 'commentId']) ?? 0;
    final parsedPostcardId =
        BackendApiClient.readInt(json, const ['postcardId', 'cardId']) ??
        (cardId ?? 0);
    final parsedContent =
        BackendApiClient.readString(json, const [
          'content',
          'commentContent',
          'text',
        ]) ??
        '';
    final parsedUsername = _extractUsername(json) ?? '匿名用户';
    final parsedAvatar =
        BackendApiClient.readString(json, const ['avatar', 'avatarUrl']) ??
        BackendApiClient.readString(
          BackendApiClient.asMap(json['user']),
          const ['avatar', 'avatarUrl'],
        );
    final parsedLocation =
        BackendApiClient.readString(json, const [
          'location',
          'cityName',
          'address',
        ]) ??
        '未知地点';
    final parsedTimeText =
        BackendApiClient.readString(json, const [
          'createdAt',
          'createTime',
          'commentTime',
          'time',
        ]) ??
        '';
    final parsedParentCommentId =
        BackendApiClient.readInt(json, const [
          'parentId',
          'parentCommentId',
          'replyToCommentId',
          'targetCommentId',
        ]) ??
        defaultParentCommentId;
    final parsedReplyToUsername =
        BackendApiClient.readString(json, const [
          'replyToUsername',
          'toUsername',
          'targetUsername',
        ]) ??
        BackendApiClient.readString(
          BackendApiClient.asMap(json['replyTo']),
          const ['username', 'nickname', 'displayName'],
        ) ??
        defaultReplyToUsername;

    return PostcardComment(
      id: parsedId,
      postcardId: parsedPostcardId,
      username: parsedUsername,
      avatar: parsedAvatar,
      location: parsedLocation,
      content: parsedContent,
      createdAt: _parseDateTime(parsedTimeText),
      liked: _parseLiked(json),
      parentCommentId: parsedParentCommentId,
      replyToUsername: parsedReplyToUsername,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'postcardId': postcardId,
      'username': username,
      'avatar': avatar,
      'location': location,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'liked': liked,
      'parentCommentId': parentCommentId,
      'replyToUsername': replyToUsername,
    };
  }

  PostcardComment copyWith({
    bool? liked,
  }) {
    return PostcardComment(
      id: id,
      postcardId: postcardId,
      username: username,
      avatar: avatar,
      location: location,
      content: content,
      createdAt: createdAt,
      liked: liked ?? this.liked,
      parentCommentId: parentCommentId,
      replyToUsername: replyToUsername,
    );
  }

  static DateTime _parseDateTime(String raw) {
    if (raw.trim().isEmpty) return DateTime.now();

    DateTime? parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;

    parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (parsed != null) return parsed;

    return DateTime.now();
  }

  static bool _parseLiked(Map<String, dynamic> json) {
    for (final key in const ['liked', 'isLiked', 'hasLiked', 'likeStatus']) {
      final value = _toBool(json[key]);
      if (value != null) return value;
    }
    return false;
  }

  static bool? _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return null;
  }

  static String? _extractUsername(Map<String, dynamic> json) {
    final directNickname = BackendApiClient.readString(json, const [
      'nickname',
      'nickName',
      'displayName',
      'userNickname',
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
      'displayName',
      'userNickname',
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
}

class PostcardCommentService {
  PostcardCommentService({BackendApiClient? apiClient})
    : _apiClient = apiClient ?? BackendApiClient();

  static const String _localCommentsKeyPrefix = 'postcard_local_comments_v1_';

  final BackendApiClient _apiClient;

  Future<List<PostcardComment>> fetchComments({
    required int postcardId,
    int page = 1,
    int size = 20,
  }) async {
    final localComments = await _readLocalComments(postcardId);

    try {
      final onlineComments = await _fetchCommentsOnline(
        postcardId: postcardId,
        page: page,
        size: size,
      );
      final merged = _mergeComments(onlineComments, localComments);
      await _saveLocalComments(postcardId, merged);
      return merged;
    } on BackendApiException {
      if (localComments.isNotEmpty) {
        return localComments;
      }
      final seeded = _buildOfflineSeedComments(postcardId);
      await _saveLocalComments(postcardId, seeded);
      return seeded;
    } catch (_) {
      if (localComments.isNotEmpty) {
        return localComments;
      }
      final seeded = _buildOfflineSeedComments(postcardId);
      await _saveLocalComments(postcardId, seeded);
      return seeded;
    }
  }

  Future<void> addComment({
    required int postcardId,
    required String content,
    int? parentCommentId,
    String? replyToUsername,
  }) async {
    final normalized = content.trim();
    if (normalized.isEmpty) return;

    final payload = <String, dynamic>{
      'content': normalized,
      'commentContent': normalized,
      'text': normalized,
      if (parentCommentId != null && parentCommentId > 0) ...{
        'parentId': parentCommentId,
        'parentCommentId': parentCommentId,
        'replyToCommentId': parentCommentId,
        'targetCommentId': parentCommentId,
      },
      if (replyToUsername != null && replyToUsername.trim().isNotEmpty)
        'replyToUsername': replyToUsername.trim(),
    };

    final endpoints = <String>[
      if (parentCommentId != null && parentCommentId > 0)
        '/postcard/comment/$parentCommentId/reply',
      if (parentCommentId != null && parentCommentId > 0)
        '/postcard/$postcardId/comment/reply',
      '/postcard/$postcardId/comment',
    ];

    BackendApiException? lastError;
    for (final path in endpoints) {
      try {
        await _apiClient.post(path, body: payload, requireAuth: true);
        return;
      } on BackendApiException catch (e) {
        lastError = e;
      } catch (_) {}
    }

    final now = DateTime.now();
    final localComment = PostcardComment(
      id: now.microsecondsSinceEpoch,
      postcardId: postcardId,
      username: '我',
      avatar: null,
      location: '离线',
      content: normalized,
      createdAt: now,
      liked: false,
      parentCommentId: parentCommentId,
      replyToUsername: replyToUsername,
    );

    try {
      await _upsertLocalComment(localComment);
      return;
    } catch (_) {
      if (lastError != null) {
        throw lastError;
      }
      throw const BackendApiException('评论发布失败');
    }
  }

  Future<void> likeComment(int commentId) async {
    final endpoints = <String>[
      '/postcard/comment/$commentId/like',
      '/comment/$commentId/like',
    ];

    for (final path in endpoints) {
      try {
        await _apiClient.post(path, requireAuth: true);
        return;
      } catch (_) {
        continue;
      }
    }

    await _markCommentLikedLocally(commentId);
  }

  Future<List<PostcardComment>> _fetchCommentsOnline({
    required int postcardId,
    required int page,
    required int size,
  }) async {
    final body = await _apiClient.get(
      '/postcard/$postcardId/comments',
      queryParameters: <String, String>{'page': '$page', 'size': '$size'},
      requireAuth: true,
    );

    final data = BackendApiClient.extractData(body);
    final rawList = BackendApiClient.extractList(data);
    final comments = <PostcardComment>[];
    for (final item in rawList) {
      final map = BackendApiClient.asMap(item);
      if (map == null) continue;
      comments.addAll(_flattenCommentRecord(map, postcardId: postcardId));
    }

    comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return comments;
  }

  Future<void> _upsertLocalComment(PostcardComment comment) async {
    final existing = await _readLocalComments(comment.postcardId);
    final merged = _mergeComments(<PostcardComment>[comment], existing);
    await _saveLocalComments(comment.postcardId, merged);
  }

  Future<void> _markCommentLikedLocally(int commentId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith(_localCommentsKeyPrefix));

    for (final key in keys) {
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) {
        continue;
      }

      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) continue;

        var changed = false;
        final next = <Map<String, dynamic>>[];
        for (final item in decoded) {
          final map = BackendApiClient.asMap(item);
          if (map == null) continue;

          final id = BackendApiClient.readInt(map, const ['id', 'commentId']);
          if (id == commentId) {
            map['liked'] = true;
            changed = true;
          }
          next.add(map);
        }

        if (changed) {
          await prefs.setString(key, jsonEncode(next));
        }
      } catch (_) {
        continue;
      }
    }
  }

  Future<List<PostcardComment>> _readLocalComments(int postcardId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localCommentsStorageKey(postcardId));
    if (raw == null || raw.trim().isEmpty) {
      return <PostcardComment>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <PostcardComment>[];
      }

      final comments = <PostcardComment>[];
      for (final item in decoded) {
        final map = BackendApiClient.asMap(item);
        if (map == null) continue;
        comments.add(PostcardComment.fromJson(map, cardId: postcardId));
      }

      comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return comments;
    } catch (_) {
      return <PostcardComment>[];
    }
  }

  Future<void> _saveLocalComments(
    int postcardId,
    List<PostcardComment> comments,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(comments.map((item) => item.toJson()).toList());
    await prefs.setString(_localCommentsStorageKey(postcardId), encoded);
  }

  String _localCommentsStorageKey(int postcardId) {
    return '$_localCommentsKeyPrefix$postcardId';
  }

  List<PostcardComment> _mergeComments(
    List<PostcardComment> primary,
    List<PostcardComment> secondary,
  ) {
    if (secondary.isEmpty) {
      final sorted = List<PostcardComment>.from(primary);
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sorted;
    }

    final merged = <PostcardComment>[];
    final seen = <String>{};

    for (final item in primary) {
      final key = _commentDedupKey(item);
      if (!seen.add(key)) continue;
      merged.add(item);
    }

    for (final item in secondary) {
      final key = _commentDedupKey(item);
      if (!seen.add(key)) continue;
      merged.add(item);
    }

    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  String _commentDedupKey(PostcardComment comment) {
    if (comment.id > 0) {
      return 'id:${comment.id}';
    }
    return 'sig:${comment.postcardId}:${comment.parentCommentId ?? 0}:${comment.username}:${comment.content}:${comment.createdAt.toIso8601String()}';
  }

  List<PostcardComment> _buildOfflineSeedComments(int postcardId) {
    final now = DateTime.now();
    final baseId = postcardId > 0
        ? postcardId * 100000
        : now.millisecondsSinceEpoch * 10;

    final rootId = baseId + 1;
    final secondRootId = baseId + 2;

    return <PostcardComment>[
      PostcardComment(
        id: rootId,
        postcardId: postcardId,
        username: 'Offline User A',
        avatar: null,
        location: 'Beijing',
        content: '离线模式下也可以浏览评论。',
        createdAt: now.subtract(const Duration(minutes: 8)),
        liked: false,
        parentCommentId: null,
        replyToUsername: null,
      ),
      PostcardComment(
        id: baseId + 3,
        postcardId: postcardId,
        username: 'Offline User B',
        avatar: null,
        location: 'Shanghai',
        content: '支持发评论和点赞的本地回退。',
        createdAt: now.subtract(const Duration(minutes: 5)),
        liked: false,
        parentCommentId: rootId,
        replyToUsername: 'Offline User A',
      ),
      PostcardComment(
        id: secondRootId,
        postcardId: postcardId,
        username: 'Offline User C',
        avatar: null,
        location: 'Chengdu',
        content: '联网后会优先展示线上评论。',
        createdAt: now.subtract(const Duration(minutes: 2)),
        liked: false,
        parentCommentId: null,
        replyToUsername: null,
      ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<PostcardComment> _flattenCommentRecord(
    Map<String, dynamic> raw, {
    required int postcardId,
    int? parentCommentId,
    String? replyToUsername,
  }) {
    final current = PostcardComment.fromJson(
      raw,
      cardId: postcardId,
      defaultParentCommentId: parentCommentId,
      defaultReplyToUsername: replyToUsername,
    );

    final result = <PostcardComment>[current];
    final nestedRaw = _extractNestedReplies(raw);
    if (nestedRaw.isEmpty) return result;

    final resolvedParentId = current.id > 0 ? current.id : parentCommentId;
    for (final entry in nestedRaw) {
      final childMap = BackendApiClient.asMap(entry);
      if (childMap == null) continue;
      result.addAll(
        _flattenCommentRecord(
          childMap,
          postcardId: postcardId,
          parentCommentId: resolvedParentId,
          replyToUsername: current.username,
        ),
      );
    }

    return result;
  }

  List<dynamic> _extractNestedReplies(Map<String, dynamic> raw) {
    for (final key in const ['replies', 'replyList', 'children']) {
      final value = raw[key];
      if (value is List) return value;
    }
    return const [];
  }
}
