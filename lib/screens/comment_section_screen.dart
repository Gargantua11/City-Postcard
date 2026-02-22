import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/backend_api_client.dart';
import '../services/discussion_service.dart';
import '../widgets/app_bottom_nav_bar.dart';

class CommentSectionScreen extends StatefulWidget {
  const CommentSectionScreen({super.key});

  @override
  State<CommentSectionScreen> createState() => _CommentSectionScreenState();
}

class _CommentSectionScreenState extends State<CommentSectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DiscussionService _discussionService = DiscussionService();

  bool _isLoading = true;
  String? _errorMessage;
  List<DiscussionPost> _posts = const [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadPosts();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final posts = await _discussionService.fetchPosts(
        lastTime: DateTime.now(),
      );
      if (!mounted) return;

      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } on BackendApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '加载讨论区失败，请稍后重试';
      });
    }
  }

  List<DiscussionPost> get _visiblePosts {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return _posts;

    return _posts.where((post) {
      return post.username.contains(keyword) ||
          post.address.contains(keyword) ||
          post.hotComment.contains(keyword);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _loadPosts,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  76 + bottomInset + 108,
                ),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Center(
                          child: Text(
                            '讨论区',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _isLoading ? null : _loadPosts,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                              hintText: '输入昵称 / 地点 / 热评关键字',
                              hintStyle: TextStyle(
                                color: Color(0xFFA7AEA2),
                                fontSize: 14,
                              ),
                              isCollapsed: true,
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.search, size: 30, color: Colors.black87),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_errorMessage != null)
                    _ErrorCard(message: _errorMessage!, onRetry: _loadPosts)
                  else if (_visiblePosts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          '暂无帖子',
                          style: TextStyle(color: Color(0xFF6D7680)),
                        ),
                      ),
                    )
                  else
                    ..._visiblePosts.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _DiscussionPostCard(item: item),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 76 + bottomInset + 10,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _InputPostBar(
                  onAddTap: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('发帖功能待接入')));
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
          Navigator.pushReplacementNamed(context, '/home');
        },
        onMapTap: () {
          Navigator.pushReplacementNamed(context, '/map');
        },
        onCommentTap: () {},
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FCF6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCEAD5), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: Color(0xFF43505C)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _DiscussionPostCard extends StatelessWidget {
  const _DiscussionPostCard({required this.item});

  static const double _postcardAspectRatio = 400 / 258;

  final DiscussionPost item;

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
              const sideWidth = 96.0;
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
                        borderRadius: BorderRadius.circular(6),
                        child: _PostImage(imageUrl: item.imageUrl),
                      ),
                    ),
                    const SizedBox(width: gap),
                    SizedBox(
                      width: sideWidth,
                      height: imageHeight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _UserAvatar(url: item.avatar),
                          const SizedBox(height: 6),
                          Text(
                            item.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF111111),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            DateFormat('MM-dd HH:mm').format(item.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF1D1D1D),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF1D1D1D),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              const Icon(
                                Icons.favorite_border,
                                size: 14,
                                color: Color(0xFF3A3A3A),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${item.likeCount}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 14,
                                color: Color(0xFF3A3A3A),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${item.commentCount}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
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
              '热评：${item.hotComment.isEmpty ? '暂无热评' : item.hotComment}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
  const _PostImage({required this.imageUrl});

  final String imageUrl;

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

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final safeUrl = url?.trim() ?? '';
    if (safeUrl.isEmpty) {
      return const CircleAvatar(
        radius: 16,
        backgroundColor: Color(0xFFD2D2D2),
        child: Icon(Icons.person, size: 14, color: Color(0xFF666666)),
      );
    }

    return CircleAvatar(
      radius: 16,
      backgroundColor: const Color(0xFFD2D2D2),
      backgroundImage: NetworkImage(safeUrl),
      onBackgroundImageError: (_, _) {},
    );
  }
}

class _InputPostBar extends StatelessWidget {
  const _InputPostBar({required this.onAddTap});

  final VoidCallback onAddTap;

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
