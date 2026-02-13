import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 评论对象，字段对齐文档 3.3 获取评论列表 records[]。
class PostcardHotComment {
  final int? id;
  final int? userId;
  final String? username;
  final String? avatar;
  final String content;
  final String? createdAt;
  final int? likeCount;
  final bool? liked;
  final double? hotScore;
  final String? cursor;

  const PostcardHotComment({
    this.id,
    this.userId,
    this.username,
    this.avatar,
    required this.content,
    this.createdAt,
    this.likeCount,
    this.liked,
    this.hotScore,
    this.cursor,
  });

  factory PostcardHotComment.fromJson(Map<String, dynamic> json) {
    return PostcardHotComment(
      id: _toInt(json['id']),
      userId: _toInt(json['userId']),
      username: json['username']?.toString(),
      avatar: json['avatar']?.toString(),
      content: json['content']?.toString() ?? '',
      createdAt: json['createdAt']?.toString(),
      likeCount: _toInt(json['likeCount']),
      liked: json['liked'] as bool?,
      hotScore: _toDouble(json['hotScore']),
      cursor: json['cursor']?.toString(),
    );
  }
}

/// 明信片展示对象，字段对齐文档 4.1 讨论区明信片列表 records[]。
class PostcardDisplayCardData {
  final int id;
  final String username;
  final String? avatar;
  final String imageUrl;
  final String createdAt;
  final String address;
  final int likeCount;
  final int commentCount;
  final PostcardHotComment? hotComment;

  const PostcardDisplayCardData({
    required this.id,
    required this.username,
    this.avatar,
    required this.imageUrl,
    required this.createdAt,
    required this.address,
    required this.likeCount,
    required this.commentCount,
    this.hotComment,
  });

  factory PostcardDisplayCardData.fromJson(Map<String, dynamic> json) {
    final hotCommentJson = json['hotComment'];
    return PostcardDisplayCardData(
      id: _toInt(json['id']) ?? 0,
      username: json['username']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      imageUrl: json['imageUrl']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      likeCount: _toInt(json['likeCount']) ?? 0,
      commentCount: _toInt(json['commentCount']) ?? 0,
      hotComment: hotCommentJson is Map<String, dynamic>
          ? PostcardHotComment.fromJson(hotCommentJson)
          : null,
    );
  }
}

/// 方形明信片展示卡片。
/// - 整体 1:1，圆角 10
/// - 上部：左图右信息
/// - 下部：点赞按钮 + 热评（单行省略）
class PostcardDisplayCard extends StatelessWidget {
  final PostcardDisplayCardData data;
  final bool liked;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;

  const PostcardDisplayCard({
    super.key,
    required this.data,
    this.liked = false,
    this.onLikeTap,
    this.onCommentTap,
  });

  String get _hotCommentText {
    if ((data.hotComment?.content.trim().isEmpty ?? true)) {
      return '热评：暂无热评';
    }
    final username = data.hotComment?.username?.trim();
    if (username == null || username.isEmpty) {
      return '热评：${data.hotComment!.content}';
    }
    return '热评：$username ${data.hotComment!.content}';
  }

  @override
  Widget build(BuildContext context) {
    const radius = 10.0;

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: const Color(0xFFE7E9EE)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: _PostcardImage(imageUrl: data.imageUrl),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: _PublisherInfo(
                          avatarUrl: data.avatar,
                          username: data.username,
                          createdAt: data.createdAt,
                          address: data.address,
                          commentCount: data.commentCount,
                          onCommentTap: onCommentTap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFE7E9EE))),
                ),
                child: Row(
                  children: [
                    _MetricButton(
                      icon: liked ? Icons.favorite : Icons.favorite_border,
                      label: data.likeCount.toString(),
                      foregroundColor: liked
                          ? const Color(0xFFE05050)
                          : const Color(0xFF5B6472),
                      backgroundColor: liked
                          ? const Color(0xFFFFECEC)
                          : const Color(0xFFEFF2F7),
                      onTap: onLikeTap,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _hotCommentText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostcardImage extends StatelessWidget {
  final String imageUrl;

  const _PostcardImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: const Color(0xFFD1D5DB),
        child: imageUrl.trim().isEmpty
            ? const SizedBox.expand()
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.expand(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox.expand();
                },
              ),
      ),
    );
  }
}

class _PublisherInfo extends StatelessWidget {
  final String? avatarUrl;
  final String username;
  final String createdAt;
  final String address;
  final int commentCount;
  final VoidCallback? onCommentTap;

  const _PublisherInfo({
    required this.avatarUrl,
    required this.username,
    required this.createdAt,
    required this.address,
    required this.commentCount,
    this.onCommentTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(url: avatarUrl),
        const SizedBox(height: 6),
        Text(
          username.isEmpty ? '未知用户' : username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          _formatCreatedAt(createdAt),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              Icons.place_outlined,
              size: 12,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                address.isEmpty ? '未知地点' : address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ),
          ],
        ),
        const Spacer(),
        _MetricButton(
          icon: Icons.chat_bubble_outline,
          label: commentCount.toString(),
          foregroundColor: const Color(0xFF2F5D99),
          backgroundColor: const Color(0xFFEAF3FF),
          onTap: onCommentTap,
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;

  const _Avatar({this.url});

  @override
  Widget build(BuildContext context) {
    final validUrl = url?.trim() ?? '';
    if (validUrl.isEmpty) {
      return const CircleAvatar(
        radius: 14,
        backgroundColor: Color(0xFFD1D5DB),
        child: Icon(Icons.person, size: 14, color: Color(0xFF6B7280)),
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: const Color(0xFFD1D5DB),
      backgroundImage: NetworkImage(validUrl),
      onBackgroundImageError: (_, _) {},
    );
  }
}

class _MetricButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final VoidCallback? onTap;

  const _MetricButton({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foregroundColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCreatedAt(String createdAt) {
  if (createdAt.trim().isEmpty) return '未知时间';
  try {
    final dateTime = DateTime.parse(createdAt);
    return DateFormat('MM-dd HH:mm').format(dateTime);
  } catch (_) {
    return createdAt.replaceFirst('T', ' ');
  }
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString());
}
