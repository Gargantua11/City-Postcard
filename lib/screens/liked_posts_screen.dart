import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/discussion_service.dart';
import '../services/liked_postcard_service.dart';
import '../widgets/resolved_image.dart';
import 'post_comments_screen.dart';

class LikedPostsScreen extends StatefulWidget {
  const LikedPostsScreen({super.key});

  @override
  State<LikedPostsScreen> createState() => _LikedPostsScreenState();
}

class _LikedPostsScreenState extends State<LikedPostsScreen> {
  final LikedPostcardService _likedService = LikedPostcardService();

  bool _isLoading = true;
  bool _isSelectionMode = false;
  bool _isDeleting = false;
  int? _selectedDeleteIndex;
  List<DiscussionPost> _likedPosts = const [];

  @override
  void initState() {
    super.initState();
    _loadLikedPosts();
  }

  Future<void> _loadLikedPosts() async {
    setState(() {
      _isLoading = true;
    });

    final posts = await _likedService.getLikedPosts();
    if (!mounted) return;

    setState(() {
      _likedPosts = posts;
      if (_selectedDeleteIndex != null &&
          _selectedDeleteIndex! >= posts.length) {
        _selectedDeleteIndex = null;
      }
      if (posts.isEmpty) {
        _isSelectionMode = false;
        _selectedDeleteIndex = null;
      }
      _isLoading = false;
    });
  }

  void _toggleSelectionMode() {
    if (_likedPosts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无点赞帖子')));
      return;
    }

    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedDeleteIndex = null;
      }
    });
  }

  void _onTapPost(int index) {
    if (!_isSelectionMode) {
      _openPostComments(_likedPosts[index]);
      return;
    }

    setState(() {
      _selectedDeleteIndex = _selectedDeleteIndex == index ? null : index;
    });
  }

  Future<void> _deleteSelectedLike() async {
    final selectedIndex = _selectedDeleteIndex;
    if (selectedIndex == null || _isDeleting) return;
    if (selectedIndex < 0 || selectedIndex >= _likedPosts.length) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('取消点赞'),
          content: const Text('确认将这张明信片移出点赞列表吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final selectedPost = _likedPosts[selectedIndex];
    setState(() {
      _isDeleting = true;
    });

    try {
      await _likedService.removeLike(selectedPost);
      if (!mounted) return;
      await _loadLikedPosts();
      if (!mounted) return;

      setState(() {
        _isDeleting = false;
        _selectedDeleteIndex = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已移出点赞列表')));
    } catch (e, stackTrace) {
      debugPrint('删除点赞失败: $e\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
    }
  }

  Future<void> _openPostComments(DiscussionPost post) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostCommentsScreen(post: post)),
    );
    if (!mounted) return;
    await _loadLikedPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEDEDED),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '点赞帖子',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF30363B),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Text(
                    '共 ${_likedPosts.length} 张明信片',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6F7880),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isLoading ? null : _toggleSelectionMode,
                    child: Text(_isSelectionMode ? '完成' : '编辑'),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _loadLikedPosts,
                    child: const Text('刷新'),
                  ),
                ],
              ),
            ),
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _selectedDeleteIndex == null ? '点选要取消点赞的明信片' : '已选 1 张',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4F5A4A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            if (_selectedDeleteIndex != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _isDeleting ? null : _deleteSelectedLike,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE9A1A1),
                      disabledBackgroundColor: const Color(0xFFF2D6D6),
                      foregroundColor: const Color(0xFF5A2424),
                      disabledForegroundColor: const Color(0xFF977C7C),
                    ),
                    icon: _isDeleting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    label: Text(_isDeleting ? '删除中' : '删除'),
                  ),
                ),
              ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_likedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.thumb_up_alt_outlined,
              size: 54,
              color: Color(0xFF9AA2AA),
            ),
            SizedBox(height: 10),
            Text(
              '暂无点赞帖子',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF666D75),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '去讨论区逛逛，点赞喜欢的内容',
              style: TextStyle(fontSize: 12, color: Color(0xFF8F97A0)),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 680 ? 3 : 2;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
          itemCount: _likedPosts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.86,
          ),
          itemBuilder: (context, index) {
            final item = _likedPosts[index];
            return _LikedPostcardTile(
              item: item,
              selectable: _isSelectionMode,
              selected: _selectedDeleteIndex == index,
              onTap: () => _onTapPost(index),
            );
          },
        );
      },
    );
  }
}

class _LikedPostcardTile extends StatelessWidget {
  static const double _postcardAspectRatio = 400 / 258;

  final DiscussionPost item;
  final bool selectable;
  final bool selected;
  final VoidCallback onTap;

  const _LikedPostcardTile({
    required this.item,
    required this.selectable,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final createdAtText = DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFD75555) : const Color(0xFFDDE2E7),
            width: selected ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                  child: AspectRatio(
                    aspectRatio: _postcardAspectRatio,
                    child: _LikedPostcardImage(imageSource: item.imageUrl),
                  ),
                ),
                if (selectable)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFD75555)
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFD75555)
                              : const Color(0xFFB0BAA7),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        selected
                            ? Icons.check_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 15,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF8C9784),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Text(
                item.username.trim().isEmpty ? '匿名用户' : item.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF293241),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: Color(0xFF7A838D),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      createdAtText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF78818A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LikedPostcardImage extends StatelessWidget {
  final String imageSource;

  const _LikedPostcardImage({required this.imageSource});

  @override
  Widget build(BuildContext context) {
    return ResolvedImage(
      source: imageSource,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      fallbackBuilder: (_) => _buildFallback(),
      loadingBuilder: (_) => _buildFallback(showLoading: true),
    );
  }

  Widget _buildFallback({bool showLoading = false}) {
    return ColoredBox(
      color: const Color(0xFFD9DEE3),
      child: Center(
        child: showLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.image_not_supported_outlined,
                size: 34,
                color: Color(0xFF8A9198),
              ),
      ),
    );
  }
}
