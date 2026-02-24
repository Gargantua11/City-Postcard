import 'backend_api_client.dart';

class PostcardComment {
  const PostcardComment({
    required this.id,
    required this.postcardId,
    required this.username,
    required this.location,
    required this.content,
    required this.createdAt,
    required this.liked,
  });

  final int id;
  final int postcardId;
  final String username;
  final String location;
  final String content;
  final DateTime createdAt;
  final bool liked;

  factory PostcardComment.fromJson(Map<String, dynamic> json, {int? cardId}) {
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
    final parsedUsername =
        BackendApiClient.readString(json, const ['username', 'nickname']) ??
        '匿名用户';
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

    return PostcardComment(
      id: parsedId,
      postcardId: parsedPostcardId,
      username: parsedUsername,
      location: parsedLocation,
      content: parsedContent,
      createdAt: _parseDateTime(parsedTimeText),
      liked: _parseLiked(json),
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
      comments.add(PostcardComment.fromJson(map, cardId: postcardId));
    }

    comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return comments;
  }

  Future<void> addComment({
    required int postcardId,
    required String content,
  }) async {
    final normalized = content.trim();
    if (normalized.isEmpty) return;

    await _apiClient.post(
      '/postcard/$postcardId/comment',
      body: <String, dynamic>{
        'content': normalized,
        'commentContent': normalized,
      },
      requireAuth: true,
    );
  }

  Future<void> likeComment(int commentId) async {
    await _apiClient.post(
      '/postcard/comment/$commentId/like',
      requireAuth: true,
    );
  }
}
