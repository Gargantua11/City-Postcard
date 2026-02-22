import 'package:intl/intl.dart';

import 'backend_api_client.dart';

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
            'id',
            'postcardId',
            'cardId',
          ]) ??
          0,
      username:
          BackendApiClient.readString(json, const ['username', 'nickname']) ??
          '匿名用户',
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
  DiscussionService({BackendApiClient? apiClient})
    : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;

  Future<List<DiscussionPost>> fetchPosts({DateTime? lastTime}) async {
    final safeTime = lastTime ?? DateTime.now();
    final formatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(safeTime);

    final body = await _apiClient.get(
      '/discussion/postcards',
      queryParameters: <String, String>{'lastTime': formatted},
      requireAuth: false,
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
}
