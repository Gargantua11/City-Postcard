import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/discussion_service.dart';
import '../services/backend_api_client.dart';
import '../services/favorite_postcard_service.dart';
import '../services/postcard_comment_service.dart';
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
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  List<_CommentItem> _comments = <_CommentItem>[];

  int? _replyingCommentId;
  String? _replyToUsername;
  final Set<int> _expandedReplyCommentIds = <int>{};
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
    _loadCommentsFromApi();
    _loadFavoriteState();
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
      messenger?.showSnackBar(SnackBar(content: Text('收藏失败：${e.runtimeType}')));
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
    final roots = <_CommentItem>[];
    final rootById = <int, _CommentItem>{};
    final replies = <PostcardComment>[];

    for (final item in raw) {
      if (item.isReply) {
        replies.add(item);
        continue;
      }

      final root = _CommentItem(
        id: item.id,
        username: item.username,
        avatar: item.avatar,
        location: item.location,
        content: item.content,
        createdAt: item.createdAt,
        liked: item.liked,
        replies: <_ReplyItem>[],
      );
      roots.add(root);
      if (item.id > 0) {
        rootById[item.id] = root;
      }
    }

    for (final item in replies) {
      final parentId = item.parentCommentId;
      final parent = parentId == null ? null : rootById[parentId];
      if (parent != null) {
        parent.replies.add(
          _ReplyItem(
            id: item.id,
            username: item.username,
            avatar: item.avatar,
            content: item.content,
            createdAt: item.createdAt,
            replyToUsername: item.replyToUsername,
          ),
        );
        continue;
      }

      roots.add(
        _CommentItem(
          id: item.id,
          username: item.username,
          avatar: item.avatar,
          location: item.location,
          content: item.content,
          createdAt: item.createdAt,
          liked: item.liked,
          replies: <_ReplyItem>[],
        ),
      );
    }

    roots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final root in roots) {
      root.replies.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return roots;
  }

  Future<void> _toggleLike(_CommentItem item) async {
    final next = !item.liked;
    setState(() {
      item.liked = next;
    });

    if (!next || item.id <= 0) {
      return;
    }

    try {
      await _commentService.likeComment(item.id);
    } catch (e, stackTrace) {
      debugPrint('点赞评论失败: $e\n$stackTrace');
    }
  }

  void _startReply({
    required _CommentItem comment,
    required String targetUsername,
  }) {
    setState(() {
      _replyingCommentId = comment.id;
      _replyToUsername = targetUsername;
    });
    _inputFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingCommentId = null;
      _replyToUsername = null;
    });
  }

  void _toggleReplySection(_CommentItem comment) {
    if (comment.replies.length <= 2) return;

    setState(() {
      if (_expandedReplyCommentIds.contains(comment.id)) {
        _expandedReplyCommentIds.remove(comment.id);
      } else {
        _expandedReplyCommentIds.add(comment.id);
      }
    });
  }

  Future<void> _submitInput() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _isCommentSubmitting) return;

    if (widget.post.id <= 0) {
      _showHint('该明信片尚未同步到服务器');
      return;
    }

    final parentCommentId = _replyingCommentId;
    final replyToUsername = _replyToUsername;

    setState(() {
      _isCommentSubmitting = true;
    });

    try {
      await _commentService.addComment(
        postcardId: widget.post.id,
        content: content,
        parentCommentId: parentCommentId,
        replyToUsername: replyToUsername,
      );
      if (!mounted) return;

      _inputController.clear();
      setState(() {
        _replyingCommentId = null;
        _replyToUsername = null;
      });
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
                      if (_replyToUsername != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
                          child: Container(
                            height: 30,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD7DFC9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '正在回复：$_replyToUsername',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF55604D),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: _cancelReply,
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Color(0xFF66735E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                                  return _CommentCard(
                                    item: item,
                                    repliesExpanded: _expandedReplyCommentIds
                                        .contains(item.id),
                                    onReplyAreaTap: () =>
                                        _toggleReplySection(item),
                                    onLikeTap: () {
                                      _toggleLike(item);
                                    },
                                    onReplyCommentTap: () => _startReply(
                                      comment: item,
                                      targetUsername: item.username,
                                    ),
                                    onReplyToUserTap: (username) => _startReply(
                                      comment: item,
                                      targetUsername: username,
                                    ),
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
                              hintText: _replyToUsername == null
                                  ? '输入您的评论吧'
                                  : '回复 $_replyToUsername',
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
  final bool repliesExpanded;
  final VoidCallback onReplyAreaTap;
  final VoidCallback onLikeTap;
  final VoidCallback onReplyCommentTap;
  final ValueChanged<String> onReplyToUserTap;

  const _CommentCard({
    required this.item,
    required this.repliesExpanded,
    required this.onReplyAreaTap,
    required this.onLikeTap,
    required this.onReplyCommentTap,
    required this.onReplyToUserTap,
  });

  @override
  Widget build(BuildContext context) {
    final canExpandReplies = item.replies.length > 2;
    final displayedReplies = canExpandReplies && !repliesExpanded
        ? item.replies.take(2).toList(growable: false)
        : item.replies;

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
              const SizedBox(width: 20),
              InkWell(
                onTap: onReplyCommentTap,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    '回复',
                    style: TextStyle(fontSize: 16 / 1.8, color: Colors.black87),
                  ),
                ),
              ),
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
          if (item.replies.isNotEmpty)
            GestureDetector(
              onTap: canExpandReplies ? onReplyAreaTap : null,
              child: Container(
                margin: const EdgeInsets.only(left: 20, top: 2),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE1D5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < displayedReplies.length; i++) ...[
                      _ReplyCard(
                        reply: displayedReplies[i],
                        onReplyTap: () =>
                            onReplyToUserTap(displayedReplies[i].username),
                      ),
                      if (i != displayedReplies.length - 1)
                        const SizedBox(height: 8),
                    ],
                    if (canExpandReplies && !repliesExpanded) ...[
                      const SizedBox(height: 4),
                      const Text(
                        '...',
                        style: TextStyle(
                          fontSize: 18,
                          color: Color(0xFF5E605A),
                          height: 1.0,
                        ),
                      ),
                    ],
                    if (canExpandReplies) ...[
                      const SizedBox(height: 4),
                      Text(
                        repliesExpanded ? '收回' : '展开全部回复',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF4C5A45),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  final _ReplyItem reply;
  final VoidCallback onReplyTap;

  const _ReplyCard({required this.reply, required this.onReplyTap});

  @override
  Widget build(BuildContext context) {
    final prefix = reply.replyToUsername == null
        ? ''
        : '回复 ${reply.replyToUsername}：';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 2),
          child: _AvatarBubble(imageUrl: reply.avatar, radius: 11),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reply.username,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 2),
              Text(
                '$prefix${reply.content}',
                style: const TextStyle(fontSize: 12.5, color: Colors.black87),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    _formatRelativeTime(reply.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF5E605A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: onReplyTap,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      child: Text(
                        '回复',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF30322E),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
  final String username;
  final String? avatar;
  final String location;
  final String content;
  final DateTime createdAt;
  bool liked;
  final List<_ReplyItem> replies;

  _CommentItem({
    required this.id,
    required this.username,
    this.avatar,
    required this.location,
    required this.content,
    required this.createdAt,
    required this.liked,
    required this.replies,
  });
}

class _ReplyItem {
  final int id;
  final String username;
  final String? avatar;
  final String content;
  final DateTime createdAt;
  final String? replyToUsername;

  _ReplyItem({
    required this.id,
    required this.username,
    this.avatar,
    required this.content,
    required this.createdAt,
    this.replyToUsername,
  });
}
