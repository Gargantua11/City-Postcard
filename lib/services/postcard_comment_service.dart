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
    final parsedUsername = _extractUsername(json) ?? 'Anonymous';
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
        'Unknown location';
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

  final BackendApiClient _apiClient;

  Future<List<PostcardComment>> fetchComments({
    required int postcardId,
    int page = 1,
    int size = 20,
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
        if (e.isUnauthorized) rethrow;
      } catch (_) {}
    }

    if (lastError != null) {
      throw lastError;
    }
    throw const BackendApiException('comment publish failed');
  }

  Future<void> likeComment(int commentId) async {
    final endpoints = <String>[
      '/postcard/comment/$commentId/like',
      '/comment/$commentId/like',
    ];

    BackendApiException? lastError;
    for (final path in endpoints) {
      try {
        await _apiClient.post(path, requireAuth: true);
        return;
      } on BackendApiException catch (e) {
        lastError = e;
        if (e.isUnauthorized) rethrow;
      } catch (_) {}
    }

    if (lastError != null) {
      throw lastError;
    }
    throw const BackendApiException('like comment failed');
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
