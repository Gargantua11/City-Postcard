import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/postcard_element_layer.dart';
import '../services/app_route_observer.dart';
import '../services/backend_api_client.dart';
import 'post_comments_screen.dart';
import '../services/discussion_service.dart';
import '../widgets/postcard_layer_render_helper.dart';
import '../widgets/resolved_image.dart';
import '../widgets/app_bottom_nav_bar.dart';

class CommentSectionScreen extends StatefulWidget {
  const CommentSectionScreen({super.key});

  @override
  State<CommentSectionScreen> createState() => _CommentSectionScreenState();
}

class _CommentSectionScreenState extends State<CommentSectionScreen>
    with RouteAware {
  final TextEditingController _searchController = TextEditingController();
  final DiscussionService _discussionService = DiscussionService();

  bool _isLoading = true;
  bool _isOfflineMode = false;
  bool _isPostBallExpanded = false;
  String? _errorMessage;
  String? _offlineNotice;
  List<DiscussionPost> _posts = const [];
  PageRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadPosts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _route) {
      if (_route != null) {
        appRouteObserver.unsubscribe(this);
      }
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _loadPosts();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
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
    setState(() {
      _isPostBallExpanded = false;
    });
    final result = await Navigator.pushNamed(context, '/create_post');
    if (!mounted) return;
    if (result == true) {
      await _loadPosts();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('发布成功')));
    }
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _offlineNotice = null;
    });

    try {
      final result = await _discussionService.fetchPostsWithOfflineFallback(
        lastTime: DateTime.now(),
      );
      if (!mounted) return;

      setState(() {
        _posts = result.posts;
        _isOfflineMode = result.isOffline;
        _offlineNotice = result.notice;
        _isLoading = false;
      });
    } on BackendApiException catch (e) {
      if (!mounted) return;
      final backendMessage = e.message.trim().toLowerCase();
      final isUnderDevelopment =
          backendMessage.contains('开发中') ||
          backendMessage.contains('under development');
      setState(() {
        _isLoading = false;
        _isOfflineMode = false;
        _errorMessage = e.isUnauthorized
            ? '登录状态失效，请重新登录'
            : (isUnderDevelopment ? '讨论区暂不可用，请稍后再试' : '加载讨论区失败，请稍后重试');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isOfflineMode = false;
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
                              hintText: '输入昵称、地点或热评',
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
                          '暂无帖子',
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
          Navigator.pushNamed(context, '/home');
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
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
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
                        child: _PostImage(
                          imageUrl: item.imageUrl,
                          layers: item.layers,
                        ),
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
              "热评：${item.hotComment.isEmpty ? '暂无热评' : item.hotComment}",
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
  const _PostImage({required this.imageUrl, this.layers = const []});

  final String imageUrl;
  final List<PostcardElementLayer> layers;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ResolvedImage(
          source: imageUrl,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          fallbackBuilder: (_) => const ColoredBox(color: Color(0xFFD2D2D2)),
          loadingBuilder: (_) => const ColoredBox(color: Color(0xFFD2D2D2)),
        ),
        if (layers.isNotEmpty) _PostcardLayerOverlay(layers: layers),
      ],
    );
  }
}

class _PostcardLayerOverlay extends StatelessWidget {
  const _PostcardLayerOverlay({required this.layers});

  final List<PostcardElementLayer> layers;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final sortedLayers = List<PostcardElementLayer>.from(layers)
            ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

          return Stack(
            fit: StackFit.expand,
            children: [
              for (final layer in sortedLayers)
                _buildLayer(layer, width: width, height: height),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLayer(
    PostcardElementLayer layer, {
    required double width,
    required double height,
  }) {
    final layerSize = measurePostcardLayerSize(
      layer,
      previewWidth: width,
      previewHeight: height,
    );
    final offset = resolvePostcardLayerOffset(
      layer,
      previewWidth: width,
      previewHeight: height,
    );
    final left = width / 2 + offset.dx - layerSize.width / 2;
    final top = height / 2 + offset.dy - layerSize.height / 2;

    final visual = buildPostcardLayerVisual(
      layer,
      previewWidth: width,
      previewHeight: height,
      silentAssetError: true,
    );

    Widget transformed = visual;
    if (layer.isAsset && layer.is3dEnabled) {
      final matrix = Matrix4.identity()..setEntry(3, 2, layer.perspective);
      if (layer.rotationAxis == 'horizontal') {
        matrix
          ..rotateX(layer.rotateX)
          ..rotateY(layer.rotateY);
      } else {
        matrix
          ..rotateY(layer.rotateY)
          ..rotateX(layer.rotateX);
      }
      transformed = Transform(
        alignment: Alignment.center,
        transform: matrix,
        child: visual,
      );
    } else if (layer.rotation2d != 0) {
      transformed = Transform.rotate(angle: layer.rotation2d, child: visual);
    }

    return Positioned(
      left: left,
      top: top,
      width: layerSize.width,
      height: layerSize.height,
      child: transformed,
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
                          '发帖',
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
