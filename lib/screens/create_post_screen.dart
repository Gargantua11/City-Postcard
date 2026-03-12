import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/postcard_element_layer.dart';
import '../models/user.dart';
import '../services/backend_api_client.dart';
import '../services/discussion_service.dart';
import '../services/edited_postcard_service.dart';
import '../services/storage_service.dart';
import '../widgets/resolved_image.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const Color _lightGreenButtonColor = Color(0xFFCFE7BE);
  static const Color _lightGreenButtonDisabledColor = Color(0xFFE3ECDB);
  static const Color _lightGreenButtonTextColor = Color(0xFF2E5334);
  static const Color _lightGreenButtonDisabledTextColor = Color(0xFF90A08E);

  final EditedPostcardService _editedPostcardService = EditedPostcardService();
  final DiscussionService _discussionService = DiscussionService();
  final StorageService _storageService = StorageService();

  bool _isLoading = true;
  bool _isPublishing = false;
  int? _selectedIndex;
  User? _user;
  List<EditedPostcard> _postcards = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait<dynamic>([
        _editedPostcardService.getEditedPostcards(),
        _storageService.getUser(),
      ]);

      if (!mounted) return;
      final allPostcards = results[0] as List<EditedPostcard>;
      final user = results[1] as User?;
      final postcards = allPostcards
          .where((item) => !item.isPublished && !item.isDraft)
          .toList(growable: false);

      setState(() {
        _postcards = postcards;
        _user = user;
        _selectedIndex = postcards.isEmpty ? null : 0;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _postcards = const [];
        _selectedIndex = null;
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('加载发帖数据失败，请重试')));
    }
  }

  Future<void> _publish() async {
    if (_isPublishing || _selectedIndex == null) return;

    final postcard = _postcards[_selectedIndex!];
    if (postcard.imageUrl.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该明信片缺少图片，无法发布')));
      return;
    }

    setState(() {
      _isPublishing = true;
    });

    final profileNickname = (await _storageService.getProfileNickname())
        ?.trim();
    final username = profileNickname == null || profileNickname.isEmpty
        ? _user?.username.trim()
        : profileNickname;
    final avatar = _user?.avatar?.trim();

    final address = _resolveAddress(postcard);

    try {
      await _discussionService.publishPost(
        username: (username == null || username.isEmpty) ? '我' : username,
        avatar: avatar == null || avatar.isEmpty ? null : avatar,
        imageUrl: postcard.imageUrl,
        address: address,
        cityName: postcard.cityName,
        cityCode: postcard.cityCode,
        provinceName: postcard.provinceName,
        latitude: postcard.latitude,
        longitude: postcard.longitude,
        layers: postcard.layers,
      );
      try {
        await _editedPostcardService.markPostcardPublished(postcard.draftId);
      } catch (_) {
        // Ignore draft mark failures to avoid blocking successful publish.
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } on BackendApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e, stackTrace) {
      debugPrint('publish post failed: $e\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('发布失败，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }

  String _resolveAddress(EditedPostcard postcard) {
    final city = postcard.cityName?.trim();
    if (city != null && city.isNotEmpty) return city;

    final province = postcard.provinceName?.trim();
    if (province != null && province.isNotEmpty) return province;

    final cityCode = postcard.cityCode?.trim();
    if (cityCode != null && cityCode.isNotEmpty) return '城市代码$cityCode';

    return '未知地点';
  }

  ButtonStyle _filledButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: _lightGreenButtonColor,
      disabledBackgroundColor: _lightGreenButtonDisabledColor,
      foregroundColor: _lightGreenButtonTextColor,
      disabledForegroundColor: _lightGreenButtonDisabledTextColor,
    );
  }

  ButtonStyle _textButtonStyle() {
    return TextButton.styleFrom(
      backgroundColor: const Color(0xFFE8F2DF),
      foregroundColor: _lightGreenButtonTextColor,
      disabledForegroundColor: _lightGreenButtonDisabledTextColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      minimumSize: const Size(0, 34),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
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
          '发布帖子',
          style: TextStyle(
            color: Color(0xFF20262C),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _postcards.isEmpty
          ? _buildEmpty()
          : _buildEditor(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 56,
              color: Color(0xFF9AA2AA),
            ),
            const SizedBox(height: 12),
            const Text(
              '暂无可发布的明信片',
              style: TextStyle(
                fontSize: 17,
                color: Color(0xFF4B5563),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '请先在首页编辑并保存明信片，再来发布到讨论区',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6E7781)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: _filledButtonStyle(),
              onPressed: () => Navigator.pushNamed(context, '/postcard_edit'),
              child: const Text('去编辑明信片'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    final selected = _selectedIndex == null
        ? null
        : _postcards[_selectedIndex!];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Text(
                '选择明信片（${_postcards.length}）',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4A5561),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                style: _textButtonStyle(),
                onPressed: _isPublishing ? null : _loadData,
                child: const Text('刷新'),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _postcards.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.86,
            ),
            itemBuilder: (context, index) {
              final item = _postcards[index];
              final selected = _selectedIndex == index;
              return _SelectablePostcardTile(
                item: item,
                selected: selected,
                onTap: _isPublishing
                    ? null
                    : () {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF4F5F6),
            border: Border(top: BorderSide(color: Color(0xFFDADFE5))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '发布到：${selected == null ? '讨论区' : _resolveAddress(selected)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6D7680),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: _filledButtonStyle(),
                  onPressed: _isPublishing ? null : _publish,
                  child: _isPublishing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _lightGreenButtonTextColor,
                          ),
                        )
                      : const Text('发布到讨论区'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectablePostcardTile extends StatelessWidget {
  static const double _postcardAspectRatio = 400 / 258;

  final EditedPostcard item;
  final bool selected;
  final VoidCallback? onTap;

  const _SelectablePostcardTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final location = _resolveLocation(item);
    final timeText = DateFormat('MM-dd HH:mm').format(item.editedAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF4C8DFF) : const Color(0xFFDDE2E7),
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
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              child: AspectRatio(
                aspectRatio: _postcardAspectRatio,
                child: _PostcardImage(
                  imageSource: item.imageUrl,
                  layers: item.layers,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF293241),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off_outlined,
                    size: 18,
                    color: selected
                        ? const Color(0xFF4C8DFF)
                        : const Color(0xFFA0A8B1),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Text(
                timeText,
                style: const TextStyle(fontSize: 11, color: Color(0xFF78818A)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveLocation(EditedPostcard postcard) {
    final city = postcard.cityName?.trim();
    if (city != null && city.isNotEmpty) return city;

    final province = postcard.provinceName?.trim();
    if (province != null && province.isNotEmpty) return province;

    final code = postcard.cityCode?.trim();
    if (code != null && code.isNotEmpty) return '城市代码$code';

    return '未知地点';
  }
}

class _PostcardImage extends StatelessWidget {
  final String imageSource;
  final List<PostcardElementLayer> layers;

  const _PostcardImage({
    required this.imageSource,
    this.layers = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ResolvedImage(
          source: imageSource,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          fallbackBuilder: (_) => _buildFallback(),
          loadingBuilder: (_) => _buildFallback(showLoading: true),
        ),
        if (layers.isNotEmpty) _PostcardLayerOverlay(layers: layers),
      ],
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

class _PostcardLayerOverlay extends StatelessWidget {
  final List<PostcardElementLayer> layers;

  const _PostcardLayerOverlay({required this.layers});

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
    final path = layer.assetPath.trim();
    if (path.isEmpty) return const SizedBox.shrink();

    final rawScale = layer.scale <= 0 ? 1.0 : layer.scale;
    final itemSize = (width * 0.22 * rawScale).clamp(20.0, width * 0.45);
    final offset = _resolveLayerOffset(layer, width, height);
    final left = width / 2 + offset.dx - itemSize / 2;
    final top = height / 2 + offset.dy - itemSize / 2;

    final image = Image.asset(
      path,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );

    Widget transformed = image;
    if (layer.is3dEnabled) {
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
        child: image,
      );
    } else if (layer.rotation2d != 0) {
      transformed = Transform.rotate(angle: layer.rotation2d, child: image);
    }

    return Positioned(
      left: left,
      top: top,
      width: itemSize,
      height: itemSize,
      child: transformed,
    );
  }

  Offset _resolveLayerOffset(
    PostcardElementLayer layer,
    double previewWidth,
    double previewHeight,
  ) {
    final useFallbackOffset = layer.x == 0 && layer.y == 0;
    if (!useFallbackOffset) {
      return Offset(layer.x, layer.y);
    }

    final fallbackX = ((layer.zIndex % 4) - 1.5) * (previewWidth * 0.16);
    final fallbackY =
        (((layer.zIndex ~/ 4) % 3) - 1.0) * (previewHeight * 0.14);
    return Offset(fallbackX, fallbackY);
  }
}
