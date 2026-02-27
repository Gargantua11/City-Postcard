import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'post_comments_screen.dart';
import '../services/discussion_service.dart';
import '../widgets/resolved_image.dart';
import '../widgets/app_bottom_nav_bar.dart';

class CommentSectionScreen extends StatefulWidget {
  const CommentSectionScreen({super.key});

  @override
  State<CommentSectionScreen> createState() => _CommentSectionScreenState();
}

class _CommentSectionScreenState extends State<CommentSectionScreen> {
  static const String _devMessage =
      '\u8ba8\u8bba\u533a\u529f\u80fd\u5f00\u53d1\u4e2d';

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isOfflineMode = false;
  bool _isPostBallExpanded = false;
  String? _errorMessage;
  String? _offlineNotice;
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

  Future<void> _openPostComments(DiscussionPost post) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostCommentsScreen(post: post)),
    );
  }

  Future<void> _openCreatePost() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(_devMessage)));
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _offlineNotice = null;
    });

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isOfflineMode = false;
      _offlineNotice = null;
      _posts = const <DiscussionPost>[];
      _errorMessage = _devMessage;
    });
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
    const postButtonBottomGap = 18.0;

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _loadPosts,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 56),
                children: [
                  const Center(
                    child: Text(
                      '\u8ba8\u8bba\u533a',
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
                              hintText:
                                  '\u8f93\u5165\u6635\u79f0\u3001\u5730\u70b9\u6216\u70ed\u8bc4',
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
                  if (_isOfflineMode && _offlineNotice != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFE082)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cloud_off_outlined,
                            size: 16,
                            color: Color(0xFF8D6E63),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _offlineNotice!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6D4C41),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_errorMessage != null)
                    _ErrorSection(message: _errorMessage!, onRetry: _loadPosts)
                  else if (_visiblePosts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          '\u6682\u65e0\u5e16\u5b50',
                          style: TextStyle(
                            color: Color(0xFF6D7680),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._visiblePosts.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _DiscussionPostCard(
                          item: item,
                          onCommentTap: () => _openPostComments(item),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              right: 16,
              bottom: postButtonBottomGap,
              child: _PostActionButton(
                expanded: _isPostBallExpanded,
                onToggle: () {
                  setState(() {
                    _isPostBallExpanded = !_isPostBallExpanded;
                  });
                },
                onPostTap: _openCreatePost,
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
          Navigator.pushNamed(context, '/map');
        },
        onCommentTap: () {},
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
      ),
    );
  }
}

class _ErrorSection extends StatelessWidget {
  const _ErrorSection({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDDE3D9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCEAD5), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF43505C)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('\u91cd\u8bd5')),
        ],
      ),
    );
  }
}

class _DiscussionPostCard extends StatelessWidget {
  const _DiscussionPostCard({required this.item, required this.onCommentTap});

  static const double _postcardAspectRatio = 400 / 258;

  final DiscussionPost item;
  final VoidCallback onCommentTap;

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
                          _PostAvatar(imageUrl: item.avatar),
                          const SizedBox(height: 5),
                          Text(
                            item.username,
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
                            item.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF1D1D1D),
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            borderRadius: BorderRadius.circular(17),
                            onTap: onCommentTap,
                            child: Container(
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
              "\u70ed\u8bc4\uff1a${item.hotComment.isEmpty ? '\u6682\u65e0\u70ed\u8bc4' : item.hotComment}",
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

class _PostAvatar extends StatelessWidget {
  const _PostAvatar({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final source = imageUrl?.trim() ?? '';
    if (source.isEmpty) {
      return const CircleAvatar(radius: 16, backgroundColor: Color(0xFFD2D2D2));
    }

    return ClipOval(
      child: SizedBox(
        width: 32,
        height: 32,
        child: ResolvedImage(
          source: source,
          fit: BoxFit.cover,
          fallbackBuilder: (_) => const ColoredBox(color: Color(0xFFD2D2D2)),
          loadingBuilder: (_) => const ColoredBox(color: Color(0xFFD2D2D2)),
        ),
      ),
    );
  }
}

class _PostImage extends StatelessWidget {
  const _PostImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ResolvedImage(
      source: imageUrl,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      fallbackBuilder: (_) => const ColoredBox(color: Color(0xFFD2D2D2)),
      loadingBuilder: (_) => const ColoredBox(color: Color(0xFFD2D2D2)),
    );
  }
}

class _PostActionButton extends StatelessWidget {
  const _PostActionButton({
    required this.expanded,
    required this.onToggle,
    required this.onPostTap,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onPostTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: expanded ? 122 : 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2E2E2E), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: expanded
          ? Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: onPostTap,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 19, color: Colors.black),
                        SizedBox(width: 4),
                        Text(
                          '\u53d1\u5e16',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2C2C2C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 20, color: const Color(0xFFDDDDDD)),
                InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: onToggle,
                  child: const SizedBox(
                    width: 36,
                    height: 44,
                    child: Icon(
                      Icons.keyboard_arrow_right,
                      size: 20,
                      color: Color(0xFF656565),
                    ),
                  ),
                ),
              ],
            )
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: onToggle,
                child: const Center(
                  child: Icon(Icons.add, size: 24, color: Colors.black),
                ),
              ),
            ),
    );
  }
}
