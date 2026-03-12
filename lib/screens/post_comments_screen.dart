import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/discussion_service.dart';
import '../services/backend_api_client.dart';
import '../services/favorite_postcard_service.dart';
import '../services/postcard_comment_service.dart';
import '../services/storage_service.dart';
import '../widgets/resolved_image.dart';

class PostCommentsScreen extends StatefulWidget {
  final DiscussionPost post;

  const PostCommentsScreen({super.key, required this.post});

  @override
  State<PostCommentsScreen> createState() => _PostCommentsScreenState();
}

class _PostCommentsScreenState extends State<PostCommentsScreen> {
  static const double _postcardAspectRatio = 400 / 258;

  final FavoritePostcardService _favoriteService = FavoritePostcardService();
  final PostcardCommentService _commentService = PostcardCommentService();
  final StorageService _storageService = StorageService();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  List<_CommentItem> _comments = <_CommentItem>[];
  final Set<String> _currentUsernames = <String>{};
  String? _currentUserId;
  String? _currentUserAvatar;

  final Set<int> _deletingCommentIds = <int>{};
  bool _isCommentsLoading = true;
  bool _isCommentSubmitting = false;
  String? _commentsErrorMessage;
  bool _isPostFavorited = false;
  bool _isFavoriteBusy = false;
  bool _favoriteStateLoaded = false;
  bool _favoriteTouchedByUser = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserIdentity();
    _loadCommentsFromApi();
    _loadFavoriteState();
  }

  Future<void> _loadCurrentUserIdentity() async {
    try {
      final user = await _storageService.getUser();
      final profileNickname = await _storageService.getProfileNickname();
      final profileAvatar = await _storageService.getProfileAvatar();
      if (!mounted) return;

      final next = <String>{};
      final username = user?.username.trim() ?? '';
      if (username.isNotEmpty) {
        next.add(_normalizeName(username));
      }
      final nickname = profileNickname?.trim() ?? '';
      if (nickname.isNotEmpty) {
        next.add(_normalizeName(nickname));
      }
      next.add(_normalizeName('我'));
      final userId = user?.id.trim();
      final avatar = (user?.avatar?.trim().isNotEmpty == true
              ? user!.avatar!.trim()
              : (profileAvatar?.trim() ?? ''))
          .trim();
      final normalizedAvatar = _normalizeAvatar(avatar);

      setState(() {
        _currentUserId = (userId != null && userId.isNotEmpty) ? userId : null;
        _currentUserAvatar = normalizedAvatar.isEmpty ? null : normalizedAvatar;
        _currentUsernames
          ..clear()
          ..addAll(next);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentUserId = null;
        _currentUserAvatar = null;
        _currentUsernames
          ..clear()
          ..add(_normalizeName('我'));
      });
    }
  }

  String _normalizeName(String raw) {
    return raw.trim().toLowerCase();
  }

  String _normalizeAvatar(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final noQuery = text.split('?').first.trim();
    return noQuery.toLowerCase();
  }

  bool _isOwnComment(_CommentItem item) {
    final currentUserId = _currentUserId;
    final commentUserId = item.userId?.trim() ?? '';
    if (currentUserId != null &&
        currentUserId.isNotEmpty &&
        commentUserId.isNotEmpty &&
        commentUserId == currentUserId) {
      return true;
    }

    final currentAvatar = _currentUserAvatar;
    final commentAvatar = _normalizeAvatar(item.avatar ?? '');
    if (currentAvatar != null &&
        currentAvatar.isNotEmpty &&
        commentAvatar.isNotEmpty &&
        currentAvatar == commentAvatar) {
      return true;
    }

    final normalized = _normalizeName(item.username);
    return normalized.isNotEmpty && _currentUsernames.contains(normalized);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFavoriteState() async {
    try {
      final favorited = await _favoriteService.isFavorited(widget.post);
      if (!mounted || _favoriteTouchedByUser) return;
      setState(() {
        _isPostFavorited = favorited;
        _favoriteStateLoaded = true;
      });
    } catch (e, stackTrace) {
      debugPrint('加载收藏状态失败: $e\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _favoriteStateLoaded = true;
      });
    }
  }

  Future<void> _togglePostFavorite() async {
    if (_isFavoriteBusy || !_favoriteStateLoaded) return;

    setState(() {
      _isFavoriteBusy = true;
      _favoriteTouchedByUser = true;
    });

    try {
      final favorited = await _favoriteService.toggleFavorite(widget.post);
      if (!mounted) return;
      setState(() {
        _isPostFavorited = favorited;
      });

      final message = favorited ? '已收藏到收藏夹' : '已取消收藏';
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    } catch (e, stackTrace) {
      debugPrint('切换收藏失败: $e\n$stackTrace');
      if (!mounted) return;

      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(const SnackBar(content: Text('收藏失败，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() {
          _isFavoriteBusy = false;
        });
      }
    }
  }

  Future<void> _loadCommentsFromApi({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isCommentsLoading = true;
        _commentsErrorMessage = null;
      });
    }

    if (widget.post.id <= 0) {
      if (!mounted) return;
      setState(() {
        _isCommentsLoading = false;
        _commentsErrorMessage = '该明信片尚未同步到服务器，无法加载在线评论';
        _comments = const <_CommentItem>[];
      });
      return;
    }

    try {
      final comments = await _commentService.fetchComments(
        postcardId: widget.post.id,
        page: 1,
        size: 50,
      );
      if (!mounted) return;

      setState(() {
        _comments = _buildCommentItemsFromNetwork(comments);
        _isCommentsLoading = false;
        _commentsErrorMessage = null;
      });
    } on BackendApiException catch (e, stackTrace) {
      debugPrint('加载评论失败: $e\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _isCommentsLoading = false;
        _commentsErrorMessage = _friendlyCommentErrorMessage(e);
      });
    } catch (e, stackTrace) {
      debugPrint('加载评论失败: $e\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _isCommentsLoading = false;
        _commentsErrorMessage = '加载评论失败，请稍后重试';
      });
    }
  }

  String _friendlyCommentErrorMessage(
    BackendApiException error, {
    bool forSubmit = false,
  }) {
    if (error.isUnauthorized) {
      return '登录状态失效，请重新登录';
    }

    final lower = error.message.toLowerCase();
    final isNetworkError =
        lower.contains('network request failed') ||
        lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('failed host lookup') ||
        lower.contains('timed out') ||
        lower.contains('connection reset');
    if (isNetworkError) {
      return '网络连接失败，请检查网络后重试';
    }

    final isNotFound =
        lower.contains('not found') ||
        lower.contains('不存在') ||
        lower.contains('已删除');
    if (isNotFound) {
      return '明信片不存在或已被删除';
    }

    final isUnderDevelopment =
        lower.contains('开发中') || lower.contains('under development');
    if (isUnderDevelopment) {
      return '评论功能暂不可用，请稍后再试';
    }

    if (forSubmit) {
      return '发布评论失败，请稍后重试';
    }
    return '加载评论失败，请稍后重试';
  }

  List<_CommentItem> _buildCommentItemsFromNetwork(List<PostcardComment> raw) {
    final comments = <_CommentItem>[];
    for (final item in raw) {
      if (item.isReply) {
        continue;
      }

      comments.add(
        _CommentItem(
          id: item.id,
          userId: item.userId,
          username: item.username,
          avatar: item.avatar,
          location: item.location,
          content: item.content,
          createdAt: item.createdAt,
          liked: item.liked,
        ),
      );
    }

    comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return comments;
  }

  Future<void> _toggleLike(_CommentItem item) async {
    final previous = item.liked;
    final next = !previous;
    setState(() {
      item.liked = next;
    });

    if (item.id <= 0) {
      return;
    }

    try {
      await _commentService.setCommentLiked(item.id, next);
    } catch (e, stackTrace) {
      debugPrint('评论点赞操作失败: $e\n$stackTrace');
      if (!mounted) return;
      setState(() {
        item.liked = previous;
      });
    }
  }

  Future<void> _deleteComment(_CommentItem item) async {
    if (item.id <= 0 || _deletingCommentIds.contains(item.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除评论'),
          content: const Text('确认删除这条评论吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _deletingCommentIds.add(item.id);
    });

    try {
      await _commentService.deleteComment(item.id);
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((comment) => comment.id == item.id);
      });
      await _loadCommentsFromApi(showLoading: false);
      _showHint('评论已删除');
    } on BackendApiException catch (e, stackTrace) {
      debugPrint('删除评论失败: $e\n$stackTrace');
      if (!mounted) return;
      _showHint(
        e.isUnauthorized ? '登录状态失效，请重新登录' : '删除评论失败，请稍后重试',
      );
    } catch (e, stackTrace) {
      debugPrint('删除评论失败: $e\n$stackTrace');
      if (!mounted) return;
      _showHint('删除评论失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() {
          _deletingCommentIds.remove(item.id);
        });
      }
    }
  }

  Future<void> _submitInput() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _isCommentSubmitting) return;

    if (widget.post.id <= 0) {
      _showHint('该明信片尚未同步到服务器');
      return;
    }

    setState(() {
      _isCommentSubmitting = true;
    });

    try {
      await _commentService.addComment(
        postcardId: widget.post.id,
        content: content,
      );
      if (!mounted) return;

      _inputController.clear();
      await _loadCommentsFromApi(showLoading: false);
    } on BackendApiException catch (e, stackTrace) {
      debugPrint('发布评论失败: $e\n$stackTrace');
      if (!mounted) return;
      _showHint(_friendlyCommentErrorMessage(e, forSubmit: true));
    } catch (e, stackTrace) {
      debugPrint('发布评论失败: $e\n$stackTrace');
      if (!mounted) return;
      _showHint('发布评论失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() {
          _isCommentSubmitting = false;
        });
      }
    }
  }

  void _showHint(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCFE7BA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 52,
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD5E5C7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFB7C7AA)),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '返回',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF44553B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AspectRatio(
                      aspectRatio: _postcardAspectRatio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: _PostHeaderImage(imageUrl: widget.post.imageUrl),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      _PostOwnerInfo(
                        post: widget.post,
                        isFavorited: _isPostFavorited,
                        onFavoriteTap: _isFavoriteBusy || !_favoriteStateLoaded
                            ? null
                            : _togglePostFavorite,
                      ),
                      Expanded(
                        child: _isCommentsLoading
                            ? const Center(child: CircularProgressIndicator())
                            : (_commentsErrorMessage != null &&
                                  _comments.isEmpty)
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _commentsErrorMessage!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFF4C5A45),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      OutlinedButton(
                                        onPressed: _loadCommentsFromApi,
                                        child: const Text('重试'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : _comments.isEmpty
                            ? const Center(
                                child: Text(
                                  '暂无评论',
                                  style: TextStyle(color: Color(0xFF4C5A45)),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  8,
                                  14,
                                  88,
                                ),
                                itemCount: _comments.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = _comments[index];
                                  final canDelete = _isOwnComment(item);
                                  return _CommentCard(
                                    item: item,
                                    onLikeTap: () {
                                      _toggleLike(item);
                                    },
                                    canDelete: canDelete,
                                    deleting: _deletingCommentIds.contains(
                                      item.id,
                                    ),
                                    onDeleteTap: () => _deleteComment(item),
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFC9D6BC),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: TextField(
                            controller: _inputController,
                            focusNode: _inputFocusNode,
                            enabled: !_isCommentSubmitting,
                            decoration: InputDecoration(
                              hintText: '输入您的评论吧',
                              hintStyle: const TextStyle(
                                color: Color(0xFF97A190),
                                fontSize: 17,
                              ),
                              border: InputBorder.none,
                              isCollapsed: true,
                              suffixIcon: IconButton(
                                onPressed: _isCommentSubmitting
                                    ? null
                                    : _submitInput,
                                icon: const Icon(
                                  Icons.send_rounded,
                                  color: Color(0xFF7B8C72),
                                  size: 19,
                                ),
                                splashRadius: 18,
                              ),
                            ),
                            style: const TextStyle(fontSize: 15),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) {
                              if (!_isCommentSubmitting) {
                                _submitInput();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostHeaderImage extends StatelessWidget {
  final String imageUrl;

  const _PostHeaderImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ResolvedImage(
      source: imageUrl,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      fallbackBuilder: (_) => _buildFallback(),
      loadingBuilder: (_) => _buildFallback(showLoading: true),
    );
  }

  Widget _buildFallback({bool showLoading = false}) {
    return ColoredBox(
      color: const Color(0xFFC8C8C8),
      child: Center(
        child: showLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.image_outlined,
                color: Color(0xFF8C8C8C),
                size: 40,
              ),
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({required this.imageUrl, required this.radius});

  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final source = imageUrl?.trim() ?? '';
    if (source.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFC8C8C8),
      );
    }

    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: ResolvedImage(
          source: source,
          fit: BoxFit.cover,
          fallbackBuilder: (_) => const ColoredBox(color: Color(0xFFC8C8C8)),
          loadingBuilder: (_) => const ColoredBox(color: Color(0xFFC8C8C8)),
        ),
      ),
    );
  }
}

class _PostOwnerInfo extends StatelessWidget {
  final DiscussionPost post;
  final bool isFavorited;
  final VoidCallback? onFavoriteTap;

  const _PostOwnerInfo({
    required this.post,
    required this.isFavorited,
    required this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
      child: Row(
        children: [
          _AvatarBubble(imageUrl: post.avatar, radius: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        post.username.isEmpty ? 'XXX(昵称)' : post.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 30 / 1.8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: onFavoriteTap,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isFavorited
                              ? const Color(0xFFFAD89C)
                              : const Color(0xFFD5E5C7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isFavorited
                                ? const Color(0xFFD6A74F)
                                : const Color(0xFFB7C7AA),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFavorited ? Icons.star : Icons.star_border,
                              size: 13,
                              color: const Color(0xFF5A5233),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isFavorited ? '已收藏' : '收藏',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF5A5233),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  post.address.isEmpty ? '地点' : post.address,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final _CommentItem item;
  final VoidCallback onLikeTap;
  final bool canDelete;
  final bool deleting;
  final VoidCallback onDeleteTap;

  const _CommentCard({
    required this.item,
    required this.onLikeTap,
    required this.canDelete,
    required this.deleting,
    required this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AvatarBubble(imageUrl: item.avatar, radius: 17),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.username,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  Text(
                    item.location,
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.content,
            style: const TextStyle(fontSize: 31 / 1.8, height: 1.2),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _formatRelativeTime(item.createdAt),
                style: const TextStyle(
                  fontSize: 16 / 1.8,
                  color: Colors.black87,
                ),
              ),
              if (canDelete) ...[
                const SizedBox(width: 10),
                TextButton(
                  onPressed: deleting ? null : onDeleteTap,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    deleting ? '删除中' : '删除',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6F6F6F),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                onPressed: onLikeTap,
                icon: Icon(
                  item.liked ? Icons.favorite : Icons.favorite_border,
                  color: item.liked ? const Color(0xFFFF5757) : Colors.black87,
                  size: 38 / 1.8,
                ),
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatRelativeTime(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);

  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}分钟前';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}小时前';
  }
  return DateFormat('MM-dd HH:mm').format(time);
}

class _CommentItem {
  final int id;
  final String? userId;
  final String username;
  final String? avatar;
  final String location;
  final String content;
  final DateTime createdAt;
  bool liked;

  _CommentItem({
    required this.id,
    this.userId,
    required this.username,
    this.avatar,
    required this.location,
    required this.content,
    required this.createdAt,
    required this.liked,
  });
}
