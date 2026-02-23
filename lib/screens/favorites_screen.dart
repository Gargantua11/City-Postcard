import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/discussion_service.dart';
import '../services/favorite_postcard_service.dart';
import 'post_comments_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoritePostcardService _favoriteService = FavoritePostcardService();

  bool _isLoading = true;
  bool _isSelectionMode = false;
  bool _isDeleting = false;
  int? _selectedDeleteIndex;
  List<DiscussionPost> _favorites = const [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
    });

    final posts = await _favoriteService.getFavorites();
    if (!mounted) return;

    setState(() {
      _favorites = posts;
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
    if (_favorites.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无收藏明信片')));
      return;
    }

    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedDeleteIndex = null;
      }
    });
  }

  void _onTapFavorite(int index) {
    if (!_isSelectionMode) {
      _openPostComments(_favorites[index]);
      return;
    }

    setState(() {
      _selectedDeleteIndex = _selectedDeleteIndex == index ? null : index;
    });
  }

  Future<void> _deleteSelectedFavorite() async {
    final selectedIndex = _selectedDeleteIndex;
    if (selectedIndex == null || _isDeleting) return;
    if (selectedIndex < 0 || selectedIndex >= _favorites.length) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('取消收藏'),
          content: const Text('确认将这张明信片移出收藏夹吗？'),
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

    final selectedPost = _favorites[selectedIndex];
    setState(() {
      _isDeleting = true;
    });

    try {
      await _favoriteService.removeFavorite(selectedPost);
      if (!mounted) return;
      await _loadFavorites();
      if (!mounted) return;

      setState(() {
        _isDeleting = false;
        _selectedDeleteIndex = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已移出收藏夹')));
    } catch (e, stackTrace) {
      debugPrint('删除收藏失败: $e\n$stackTrace');
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
    await _loadFavorites();
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
          '收藏夹',
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
                    '共 ${_favorites.length} 张明信片',
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
                    onPressed: _isLoading ? null : _loadFavorites,
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
                    _selectedDeleteIndex == null ? '请点击一张收藏明信片' : '已选中，可点击删除',
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
                    onPressed: _isDeleting ? null : _deleteSelectedFavorite,
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

    if (_favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.collections_bookmark_outlined,
              size: 54,
              color: Color(0xFF9AA2AA),
            ),
            SizedBox(height: 10),
            Text(
              '暂无收藏明信片',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF666D75),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '去讨论区逛逛，收藏喜欢的内容',
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
          itemCount: _favorites.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.86,
          ),
          itemBuilder: (context, index) {
            final item = _favorites[index];
            return _FavoritePostcardTile(
              item: item,
              selectable: _isSelectionMode,
              selected: _selectedDeleteIndex == index,
              onTap: () => _onTapFavorite(index),
            );
          },
        );
      },
    );
  }
}

class _FavoritePostcardTile extends StatelessWidget {
  static const double _postcardAspectRatio = 400 / 258;

  final DiscussionPost item;
  final bool selectable;
  final bool selected;
  final VoidCallback onTap;

  const _FavoritePostcardTile({
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
                    child: _FavoritePostcardImage(imageSource: item.imageUrl),
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

class _FavoritePostcardImage extends StatelessWidget {
  final String imageSource;

  const _FavoritePostcardImage({required this.imageSource});

  @override
  Widget build(BuildContext context) {
    final source = imageSource.trim();
    if (source.isEmpty) {
      return _buildFallback();
    }

    if (source.startsWith('assets/')) {
      return Image.asset(
        source,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => _buildFallback(),
      );
    }

    final uri = Uri.tryParse(source);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return _buildFallback();
    }

    return Image.network(
      source,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => _buildFallback(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _buildFallback(showLoading: true);
      },
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
