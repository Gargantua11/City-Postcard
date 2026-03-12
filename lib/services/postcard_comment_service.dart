import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'backend_api_client.dart';

class PostcardComment {
  const PostcardComment({
    required this.id,
    required this.postcardId,
    this.userId,
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
  final String? userId;
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
    final parsedUserId = _extractUserId(json);
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
    final parsedLocation = _extractCommenterLocation(json) ?? '未知地点';
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
      userId: parsedUserId,
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
      'userId': userId,
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
    String? userId,
  }) {
    return PostcardComment(
      id: id,
      postcardId: postcardId,
      userId: userId ?? this.userId,
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

  static String? _extractUserId(Map<String, dynamic> json) {
    final directString = BackendApiClient.readString(json, const [
      'userId',
      'user_id',
      'uid',
      'authorId',
      'publisherId',
    ]);
    if (directString != null && directString.isNotEmpty) {
      return directString.trim();
    }

    final directInt = BackendApiClient.readInt(json, const [
      'userId',
      'user_id',
      'uid',
      'authorId',
      'publisherId',
    ]);
    if (directInt != null) {
      return '$directInt';
    }

    final nestedUser = BackendApiClient.asMap(
      json['user'] ?? json['author'] ?? json['publisher'],
    );
    if (nestedUser != null) {
      final nestedString = BackendApiClient.readString(nestedUser, const [
        'id',
        'userId',
        'uid',
      ]);
      if (nestedString != null && nestedString.isNotEmpty) {
        return nestedString.trim();
      }

      final nestedInt = BackendApiClient.readInt(nestedUser, const [
        'id',
        'userId',
        'uid',
      ]);
      if (nestedInt != null) {
        return '$nestedInt';
      }
    }

    return null;
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

  static String? _extractCommenterLocation(Map<String, dynamic> json) {
    for (final userMap in <Map<String, dynamic>?>[
      BackendApiClient.asMap(json['user']),
      BackendApiClient.asMap(json['author']),
      BackendApiClient.asMap(json['publisher']),
      BackendApiClient.asMap(json['commenter']),
      BackendApiClient.asMap(json['commentUser']),
      BackendApiClient.asMap(json['userInfo']),
      BackendApiClient.asMap(json['profile']),
    ]) {
      final fromUser = _readLocationFromMap(
        userMap,
        preferUserKeys: true,
        onlyUserScopedKeys: false,
      );
      if (fromUser != null) {
        return fromUser;
      }
    }

    final fromRootUserFields = _readLocationFromMap(
      json,
      preferUserKeys: true,
      onlyUserScopedKeys: true,
    );
    if (fromRootUserFields != null) {
      return fromRootUserFields;
    }

    return _readLocationFromMap(
      json,
      preferUserKeys: false,
      onlyUserScopedKeys: false,
    );
  }

  static String? _readLocationFromMap(
    Map<String, dynamic>? map, {
    required bool preferUserKeys,
    required bool onlyUserScopedKeys,
  }) {
    if (map == null) return null;

    final province = _normalizeLocationCandidate(
      _readFirstString(
        map,
        onlyUserScopedKeys
            ? const <String>[
                'userProvinceName',
                'commenterProvinceName',
              ]
            : (preferUserKeys
                  ? const <String>[
                      'userProvinceName',
                      'commenterProvinceName',
                      'provinceName',
                      'province',
                      'state',
                    ]
                  : const <String>[
                      'provinceName',
                      'province',
                      'state',
                    ]),
      ),
    );
    final city = _normalizeLocationCandidate(
      _readFirstString(
        map,
        onlyUserScopedKeys
            ? const <String>[
                'userCityName',
                'commenterCityName',
                'userCity',
                'commenterCity',
              ]
            : (preferUserKeys
                  ? const <String>[
                      'userCityName',
                      'commenterCityName',
                      'userCity',
                      'commenterCity',
                      'cityName',
                      'city',
                    ]
                  : const <String>[
                      'cityName',
                      'city',
                    ]),
      ),
    );
    final district = _normalizeLocationCandidate(
      _readFirstString(
        map,
        onlyUserScopedKeys
            ? const <String>[
                'userDistrictName',
                'commenterDistrictName',
                'userDistrict',
                'commenterDistrict',
              ]
            : (preferUserKeys
                  ? const <String>[
                      'userDistrictName',
                      'commenterDistrictName',
                      'userDistrict',
                      'commenterDistrict',
                      'districtName',
                      'district',
                      'area',
                    ]
                  : const <String>[
                      'districtName',
                      'district',
                      'area',
                    ]),
      ),
    );

    final mergedRegion = _mergeLocationParts(province, city, district);
    if (mergedRegion != null) {
      return mergedRegion;
    }

    final direct = _normalizeLocationCandidate(
      _readFirstString(
        map,
        onlyUserScopedKeys
            ? const <String>[
                'userLocation',
                'commenterLocation',
                'userAddress',
                'commenterAddress',
              ]
            : (preferUserKeys
                  ? const <String>[
                      'userLocation',
                      'commenterLocation',
                      'userAddress',
                      'commenterAddress',
                      'location',
                      'address',
                      'region',
                      'ipLocation',
                    ]
                  : const <String>[
                      'location',
                      'address',
                      'region',
                      'ipLocation',
                    ]),
      ),
    );
    if (direct != null) {
      return direct;
    }

    return null;
  }

  static String? _mergeLocationParts(
    String? province,
    String? city,
    String? district,
  ) {
    final parts = <String>[];
    for (final item in <String?>[province, city, district]) {
      final text = item?.trim() ?? '';
      if (text.isEmpty) continue;
      if (parts.contains(text)) continue;
      parts.add(text);
    }

    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  static String? _normalizeLocationCandidate(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;

    final normalized = text.toLowerCase();
    if (normalized == '未知地点' ||
        normalized == 'unknown' ||
        normalized == 'null' ||
        normalized == '-') {
      return null;
    }
    return text;
  }

  static String? _readFirstString(
    Map<String, dynamic>? map,
    List<String> keys,
  ) {
    if (map == null) return null;
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isEmpty) continue;
      return text;
    }
    return null;
  }
}

class PostcardCommentService {
  PostcardCommentService({BackendApiClient? apiClient})
    : _apiClient = apiClient ?? BackendApiClient();

  static const String _localCommentsKeyPrefix = 'postcard_local_comments_v1_';
  static const Set<String> _offlineSeedUsernames = <String>{
    'offline user a',
    'offline user b',
    'offline user c',
  };

  final BackendApiClient _apiClient;

  Future<List<PostcardComment>> fetchComments({
    required int postcardId,
    int page = 1,
    int size = 20,
  }) async {
    final localCommentsRaw = await _readLocalComments(postcardId);
    final localComments = _removeOfflineSeedComments(localCommentsRaw);
    if (localComments.length != localCommentsRaw.length) {
      await _saveLocalComments(postcardId, localComments);
    }

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
      return <PostcardComment>[];
    } catch (_) {
      if (localComments.isNotEmpty) {
        return localComments;
      }
      return <PostcardComment>[];
    }
  }

  Future<void> addComment({
    required int postcardId,
    required String content,
    int? parentCommentId,
    String? replyToUsername,
    String? commenterCityName,
    String? commenterCityCode,
    String? commenterLocation,
  }) async {
    final normalized = content.trim();
    if (normalized.isEmpty) return;
    final isReply = parentCommentId != null && parentCommentId > 0;
    final normalizedCommenterCityName = commenterCityName?.trim() ?? '';
    final normalizedCommenterCityCode = commenterCityCode?.trim() ?? '';
    final normalizedCommenterLocation =
        (commenterLocation?.trim().isNotEmpty == true
            ? commenterLocation!.trim()
            : normalizedCommenterCityName);

    final fullPayload = <String, dynamic>{
      'content': normalized,
      'commentContent': normalized,
      'text': normalized,
      if (normalizedCommenterLocation.isNotEmpty) ...{
        'location': normalizedCommenterLocation,
        'address': normalizedCommenterLocation,
        'userLocation': normalizedCommenterLocation,
      },
      if (normalizedCommenterCityName.isNotEmpty) ...{
        'cityName': normalizedCommenterCityName,
        'userCityName': normalizedCommenterCityName,
      },
      if (normalizedCommenterCityCode.isNotEmpty) ...{
        'cityCode': normalizedCommenterCityCode,
        'userCityCode': normalizedCommenterCityCode,
      },
      if (isReply) ...{
        'parentId': parentCommentId,
        'parentCommentId': parentCommentId,
        'replyToCommentId': parentCommentId,
        'targetCommentId': parentCommentId,
      },
      if (replyToUsername != null && replyToUsername.trim().isNotEmpty)
        'replyToUsername': replyToUsername.trim(),
    };
    final minimalPayload = <String, dynamic>{
      'content': normalized,
      if (isReply) 'parentId': parentCommentId,
    };
    final payloads = <Map<String, dynamic>>[
      fullPayload,
      minimalPayload,
    ];

    final endpoints = isReply
        ? <String>[
            '/postcard/comment/$parentCommentId/reply',
            '/postcard/$postcardId/comment/reply',
            '/postcard/$postcardId/comment',
          ]
        : <String>[
            '/postcard/$postcardId/comment',
          ];

    BackendApiException? lastError;
    for (final path in endpoints) {
      for (final payload in payloads) {
        try {
          await _apiClient.post(path, body: payload, requireAuth: true);
          return;
        } on BackendApiException catch (e) {
          lastError = e;
        } catch (_) {}
      }
    }

    final now = DateTime.now();
    final localComment = PostcardComment(
      id: now.microsecondsSinceEpoch,
      postcardId: postcardId,
      userId: null,
      username: '我',
      avatar: null,
      location: normalizedCommenterLocation.isEmpty
          ? '离线'
          : normalizedCommenterLocation,
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

  Future<void> setCommentLiked(int commentId, bool liked) async {
    if (commentId <= 0) return;

    final likeEndpoints = <String>[
      '/postcard/comment/$commentId/like',
      '/comment/$commentId/like',
    ];

    final unlikeEndpoints = <String>[
      '/postcard/comment/$commentId/unlike',
      '/comment/$commentId/unlike',
      '/postcard/comment/$commentId/cancel-like',
      '/comment/$commentId/cancel-like',
    ];

    Future<bool> tryByMethod(String method, List<String> endpoints) async {
      for (final path in endpoints) {
        try {
          if (method == 'delete') {
            await _apiClient.delete(path, requireAuth: true);
          } else {
            await _apiClient.post(path, requireAuth: true);
          }
          return true;
        } catch (_) {
          continue;
        }
      }
      return false;
    }

    if (liked) {
      if (await tryByMethod('post', likeEndpoints)) {
        return;
      }
      await _markCommentLikeStatusLocally(commentId, true);
      return;
    }

    if (await tryByMethod('delete', likeEndpoints)) {
      return;
    }
    if (await tryByMethod('post', unlikeEndpoints)) {
      return;
    }
    if (await tryByMethod('delete', unlikeEndpoints)) {
      return;
    }
    // Some backends expose only one toggle endpoint.
    if (await tryByMethod('post', likeEndpoints)) {
      return;
    }

    await _markCommentLikeStatusLocally(commentId, false);
  }

  Future<void> deleteComment(int commentId) async {
    if (commentId <= 0) return;

    final deleteEndpoints = <String>[
      '/postcard/comment/$commentId',
      '/comment/$commentId',
    ];
    final postDeleteEndpoints = <String>[
      '/postcard/comment/$commentId/delete',
      '/comment/$commentId/delete',
    ];

    BackendApiException? lastBackendError;

    for (final path in deleteEndpoints) {
      try {
        await _apiClient.delete(path, requireAuth: true);
        await _removeCommentLocally(commentId);
        return;
      } on BackendApiException catch (e) {
        if (e.statusCode == 404) {
          await _removeCommentLocally(commentId);
          return;
        }
        lastBackendError = e;
      } catch (_) {}
    }

    for (final path in postDeleteEndpoints) {
      try {
        await _apiClient.post(path, requireAuth: true);
        await _removeCommentLocally(commentId);
        return;
      } on BackendApiException catch (e) {
        if (e.statusCode == 404) {
          await _removeCommentLocally(commentId);
          return;
        }
        lastBackendError = e;
      } catch (_) {}
    }

    final removedLocally = await _removeCommentLocally(commentId);
    if (removedLocally) {
      return;
    }

    if (lastBackendError != null) {
      throw lastBackendError;
    }
    throw const BackendApiException('评论删除失败');
  }

  Future<List<PostcardComment>> _fetchCommentsOnline({
    required int postcardId,
    required int page,
    required int size,
  }) async {
    BackendApiException? lastBackendError;
    for (final query in <Map<String, String>?>[
      <String, String>{'page': '$page', 'size': '$size'},
      null,
    ]) {
      try {
        final body = await _apiClient.get(
          '/postcard/$postcardId/comments',
          queryParameters: query,
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
      } on BackendApiException catch (e) {
        lastBackendError = e;
      }
    }

    if (lastBackendError != null) throw lastBackendError;
    throw const BackendApiException('评论加载失败');
  }

  Future<void> _upsertLocalComment(PostcardComment comment) async {
    final existing = await _readLocalComments(comment.postcardId);
    final merged = _mergeComments(<PostcardComment>[comment], existing);
    await _saveLocalComments(comment.postcardId, merged);
  }

  Future<void> _markCommentLikeStatusLocally(int commentId, bool liked) async {
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
            map['liked'] = liked;
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

  Future<bool> _removeCommentLocally(int commentId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith(_localCommentsKeyPrefix));

    var removed = false;
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
            changed = true;
            removed = true;
            continue;
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

    return removed;
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

  List<PostcardComment> _removeOfflineSeedComments(
    List<PostcardComment> comments,
  ) {
    if (comments.isEmpty) {
      return const <PostcardComment>[];
    }
    return comments
        .where((item) => !_isOfflineSeedComment(item))
        .toList(growable: false);
  }

  bool _isOfflineSeedComment(PostcardComment comment) {
    final normalizedUsername = comment.username.trim().toLowerCase();
    return _offlineSeedUsernames.contains(normalizedUsername);
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
