import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/app_bottom_nav_bar.dart';

/// 讨论区页面：按设计稿显示帖子卡片、悬浮输入栏和底部导航。
class CommentSectionScreen extends StatefulWidget {
  const CommentSectionScreen({super.key});

  @override
  State<CommentSectionScreen> createState() => _CommentSectionScreenState();
}

class _CommentSectionScreenState extends State<CommentSectionScreen> {
  final TextEditingController _searchController = TextEditingController();

  static final List<_CommentPostData> _posts = [
    _CommentPostData(
      nickname: 'XXX(昵称)',
      createdAt: DateTime(2026, 2, 15, 10, 30),
      location: '明信片地点',
      hotComment: 'XXX',
      imageUrl: '',
    ),
    _CommentPostData(
      nickname: 'XXX(昵称)',
      createdAt: DateTime(2026, 2, 14, 22, 8),
      location: '明信片地点',
      hotComment: 'XXX',
      imageUrl: '',
    ),
    _CommentPostData(
      nickname: 'XXX(昵称)',
      createdAt: DateTime(2026, 2, 13, 18, 40),
      location: '明信片地点',
      hotComment: 'XXX',
      imageUrl: '',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 76 + bottomInset + 108),
              children: [
                const Center(
                  child: Text(
                    '讨论区',
                    style: TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDE3D9),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '输入您的目的地',
                            hintStyle: TextStyle(
                              color: Color(0xFFA7AEA2),
                              fontSize: 16,
                            ),
                            isCollapsed: true,
                          ),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.search, size: 34, color: Colors.black87),
                  ],
                ),
                const SizedBox(height: 20),
                ..._posts.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _DiscussionPostCard(item: item),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 76 + bottomInset + 10,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _InputPostBar(
                  onAddTap: () {
                    debugPrint('打开发帖编辑器');
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentTab: AppTab.comment,
        backgroundColor: const Color(0xFFE7E7E7),
        onHomeTap: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            Navigator.pushNamed(context, '/home');
          }
        },
        onMapTap: () {
          debugPrint('切换到地图');
        },
        onCommentTap: () {
          debugPrint('当前在讨论区');
        },
        onProfileTap: () {
          debugPrint('切换到我的');
        },
      ),
    );
  }
}

class _DiscussionPostCard extends StatelessWidget {
  final _CommentPostData item;
  static const double _postcardAspectRatio = 400 / 258;

  const _DiscussionPostCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FCF6),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFFDCEAD5), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A9FB7AF),
            blurRadius: 10,
            offset: Offset(2, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const sideWidth = 88.0;
              const gap = 12.0;
              final imageWidth = constraints.maxWidth - sideWidth - gap;
              final imageHeight = imageWidth / _postcardAspectRatio;

              return SizedBox(
                height: imageHeight,
                child: Row(
                  children: [
                    SizedBox(
                      width: imageWidth,
                      height: imageHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: _PostImage(imageUrl: item.imageUrl),
                      ),
                    ),
                    const SizedBox(width: gap),
                    SizedBox(
                      width: sideWidth,
                      height: imageHeight,
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(0xFFD2D2D2),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF111111),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('MM-dd HH:mm').format(item.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF1D1D1D),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF1D1D1D),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFF3A3A3A),
                                width: 2.5,
                              ),
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 19,
                              color: Color(0xFF3A3A3A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: const Color(0xFFD4DFC6),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Text(
              '热评：${item.hotComment}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostImage extends StatelessWidget {
  final String imageUrl;

  const _PostImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return const ColoredBox(color: Color(0xFFD2D2D2));
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFD2D2D2)),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(color: Color(0xFFD2D2D2));
      },
    );
  }
}

class _InputPostBar extends StatelessWidget {
  final VoidCallback onAddTap;

  const _InputPostBar({required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: const Color(0xB8D5E5EA),
        borderRadius: BorderRadius.circular(34),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          const Expanded(
            child: Center(
              child: Text(
                '输入您的帖子吧',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onAddTap,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black87, width: 2),
              ),
              child: const Icon(Icons.add, size: 40, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentPostData {
  final String nickname;
  final DateTime createdAt;
  final String location;
  final String hotComment;
  final String imageUrl;

  const _CommentPostData({
    required this.nickname,
    required this.createdAt,
    required this.location,
    required this.hotComment,
    required this.imageUrl,
  });
}
