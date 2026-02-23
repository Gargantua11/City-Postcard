import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/city_code_center.dart';
import '../models/postcard_element_layer.dart';
import '../services/edited_postcard_service.dart';
import '../widgets/resolved_image.dart';
import 'city_search_screen.dart';
import 'dynamic_effect_screen.dart';

class PostcardEditScreen extends StatefulWidget {
  const PostcardEditScreen({super.key});

  @override
  State<PostcardEditScreen> createState() => _PostcardEditScreenState();
}

class _PostcardEditScreenState extends State<PostcardEditScreen>
    with SingleTickerProviderStateMixin {
  static const String _defaultPreviewAsset =
      'assets/images/edit/缂栬緫-寮€濮嬪畾鍒?png';
  static const int _maxUndoSteps = 30;

  final EditedPostcardService _editedPostcardService = EditedPostcardService();
  final ImagePicker _imagePicker = ImagePicker();
  final PageController _templatePageController = PageController();
  final List<_EditorSnapshot> _undoStack = <_EditorSnapshot>[];
  List<PostcardElementLayer> _elementLayers = const [];
  List<EditedPostcard> _hotTemplates = const [];
  City? _selectedCity;
  String? _customPreviewImagePath;
  Timer? _templateAutoPlayTimer;
  bool _isLoadingHotTemplates = true;
  int _currentTemplateIndex = 0;
  bool _isSaving = false;
  late final AnimationController _effectController;

  @override
  void initState() {
    super.initState();
    _effectController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _loadHotTemplates();
  }

  @override
  void dispose() {
    _templateAutoPlayTimer?.cancel();
    _templatePageController.dispose();
    _effectController.dispose();
    super.dispose();
  }

  Future<void> _savePostcard() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final cityCode = _normalizeCityCode(_selectedCity?.code);
    final cityName = _selectedCity?.name.trim();
    final provinceName = _resolveProvinceNameFromCityCode(cityCode);
    final coordinate = cityCode == null ? null : kCityCodeCoordinates[cityCode];

    await _editedPostcardService.addEditedPostcard(
      _currentPreviewSource,
      cityName: (cityName == null || cityName.isEmpty) ? null : cityName,
      cityCode: cityCode,
      provinceName: provinceName,
      latitude: coordinate?.latitude,
      longitude: coordinate?.longitude,
      layers: _elementLayers,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (cityName != null && cityName.isNotEmpty) {
      _showHint('宸蹭繚瀛樺苟鏍囨敞锛?cityName');
    }
    Navigator.pop(context, true);
  }

  Future<void> _selectLocationTag() async {
    if (_isSaving) return;

    final selectedCity = await Navigator.push<City>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CitySearchScreen(selectedCity: _selectedCity?.name),
      ),
    );

    if (!mounted || selectedCity == null) return;
    if (_isSameCity(_selectedCity, selectedCity)) return;
    _pushUndoState();
    setState(() => _selectedCity = selectedCity);
    _showHint('宸叉爣娉ㄥ湴鐐癸細${selectedCity.name}');
  }

  String? _normalizeCityCode(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return digits;
  }

  String? _resolveProvinceNameFromCityCode(String? cityCode) {
    if (cityCode == null || cityCode.length < 2) return null;
    return _provinceNameByPrefix[cityCode.substring(0, 2)];
  }

  void _showHint(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  String get _currentPreviewSource {
    final preview = _customPreviewImagePath?.trim();
    if (preview == null || preview.isEmpty) {
      return _defaultPreviewAsset;
    }
    return preview;
  }

  Future<void> _pickLocalPreviewImage() async {
    if (_isSaving) return;

    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (!mounted || picked == null) return;

      final nextPath = picked.path.trim();
      if (nextPath.isEmpty ||
          _isSamePreviewSource(_customPreviewImagePath, nextPath)) {
        return;
      }

      _pushUndoState();
      setState(() => _customPreviewImagePath = nextPath);
      _showHint('Local image selected');
    } catch (_) {
      if (!mounted) return;
      _showHint('Image pick failed');
    }
  }

  Future<void> _loadHotTemplates() async {
    final postcards = await _editedPostcardService.getEditedPostcards();
    if (!mounted) return;

    final templates = postcards
        .where((item) => item.imageUrl.trim().isNotEmpty)
        .toList(growable: false);

    List<EditedPostcard> selected = templates;
    if (templates.length > 5) {
      final shuffled = List<EditedPostcard>.from(templates)
        ..shuffle(math.Random());
      selected = shuffled.take(5).toList(growable: false);
    }

    setState(() {
      _hotTemplates = selected;
      _isLoadingHotTemplates = false;
      _currentTemplateIndex = 0;
    });

    _startTemplateAutoPlay();
  }

  void _startTemplateAutoPlay() {
    _templateAutoPlayTimer?.cancel();
    if (_hotTemplates.length <= 1) return;
    _templateAutoPlayTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_templatePageController.hasClients) return;
      final nextIndex = (_currentTemplateIndex + 1) % _hotTemplates.length;
      _templatePageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOut,
      );
    });
  }

  void _applyHotTemplate(EditedPostcard template) {
    if (_isSaving) return;

    final nextImage = template.imageUrl.trim();
    final nextLayers = List<PostcardElementLayer>.from(template.layers);
    if (_isSamePreviewSource(_customPreviewImagePath, nextImage) &&
        _isSameLayerList(_elementLayers, nextLayers)) {
      _showHint('妯℃澘宸叉槸褰撳墠鍐呭');
      return;
    }

    _pushUndoState();
    setState(() {
      _customPreviewImagePath = nextImage.isEmpty ? null : nextImage;
      _elementLayers = nextLayers;
    });
    _showHint('Template applied');
  }

  Widget _buildHotTemplateCarousel(double width, double height) {
    if (_isLoadingHotTemplates) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E8DE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD4C0)),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_hotTemplates.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E8DE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD4C0)),
        ),
        alignment: Alignment.center,
        child: const Text(
          '鏆傛棤鐑棬妯℃澘',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF54634C),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _templatePageController,
            itemCount: _hotTemplates.length,
            onPageChanged: (index) {
              if (!mounted) return;
              setState(() => _currentTemplateIndex = index);
            },
            itemBuilder: (context, index) {
              final template = _hotTemplates[index];
              return GestureDetector(
                onTap: () => _applyHotTemplate(template),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ResolvedImage(
                      source: template.imageUrl,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      fallbackBuilder: (_) =>
                          const ColoredBox(color: Color(0xFFE5E8DE)),
                    ),
                    if (template.layers.isNotEmpty)
                      AnimatedBuilder(
                        animation: _effectController,
                        builder: (_, _) => _buildTemplateLayerOverlay(
                          template.layers,
                          width,
                          height,
                        ),
                      ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '鐑棬妯℃澘',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_hotTemplates.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(_hotTemplates.length, (index) {
                  final selected = index == _currentTemplateIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: selected ? 8 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTemplateLayerOverlay(
    List<PostcardElementLayer> layers,
    double width,
    double height,
  ) {
    final sorted = List<PostcardElementLayer>.from(layers)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final layer in sorted)
            _buildTemplateSingleLayer(layer, width, height),
        ],
      ),
    );
  }

  Widget _buildTemplateSingleLayer(
    PostcardElementLayer layer,
    double previewWidth,
    double previewHeight,
  ) {
    final rawScale = layer.scale <= 0 ? 1.0 : layer.scale;
    final baseSize = (previewWidth * 0.22 * rawScale).clamp(
      20.0,
      previewWidth * 0.45,
    );

    final offset = _resolveLayerOffset(layer, previewWidth, previewHeight);
    final left = previewWidth / 2 + offset.dx - baseSize / 2;
    final top = previewHeight / 2 + offset.dy - baseSize / 2;

    final image = Image.asset(
      layer.assetPath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );

    final speed = layer.rotationSpeed <= 0 ? 1.0 : layer.rotationSpeed;
    final directionSign = layer.rotationDirection == 'counterclockwise'
        ? -1.0
        : 1.0;
    final cycleAngle =
        _effectController.value * math.pi * 2 * speed * directionSign;

    Widget transformed = image;
    if (layer.is3dEnabled) {
      final matrix = Matrix4.identity()..setEntry(3, 2, layer.perspective);
      if (layer.rotationAxis == 'horizontal') {
        matrix
          ..rotateX(layer.rotateX + cycleAngle)
          ..rotateY(layer.rotateY);
      } else {
        matrix
          ..rotateY(layer.rotateY + cycleAngle)
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
      width: baseSize,
      height: baseSize,
      child: transformed,
    );
  }

  City? _cloneCity(City? city) {
    if (city == null) return null;
    return City(name: city.name, code: city.code);
  }

  bool _isSameCity(City? a, City? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.name == b.name && a.code == b.code;
  }

  bool _isSamePreviewSource(String? a, String? b) {
    final aText = a?.trim() ?? '';
    final bText = b?.trim() ?? '';
    return aText == bText;
  }

  bool _isSameLayer(PostcardElementLayer a, PostcardElementLayer b) {
    return a.id == b.id &&
        a.elementKey == b.elementKey &&
        a.assetPath == b.assetPath &&
        a.x == b.x &&
        a.y == b.y &&
        a.scale == b.scale &&
        a.rotation2d == b.rotation2d &&
        a.zIndex == b.zIndex &&
        a.is3dEnabled == b.is3dEnabled &&
        a.rotateX == b.rotateX &&
        a.rotateY == b.rotateY &&
        a.rotationSpeed == b.rotationSpeed &&
        a.rotationAxis == b.rotationAxis &&
        a.rotationDirection == b.rotationDirection &&
        a.perspective == b.perspective &&
        a.speedLevel == b.speedLevel;
  }

  bool _isSameLayerList(
    List<PostcardElementLayer> a,
    List<PostcardElementLayer> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_isSameLayer(a[i], b[i])) return false;
    }
    return true;
  }

  void _pushUndoState() {
    final snapshot = _EditorSnapshot(
      layers: List<PostcardElementLayer>.from(_elementLayers),
      selectedCity: _cloneCity(_selectedCity),
      previewImagePath: _customPreviewImagePath,
    );
    if (_undoStack.isNotEmpty) {
      final last = _undoStack.last;
      if (_isSameLayerList(last.layers, snapshot.layers) &&
          _isSameCity(last.selectedCity, snapshot.selectedCity) &&
          _isSamePreviewSource(
            last.previewImagePath,
            snapshot.previewImagePath,
          )) {
        return;
      }
    }
    _undoStack.add(snapshot);
    if (_undoStack.length > _maxUndoSteps) {
      _undoStack.removeAt(0);
    }
  }

  bool _applyLayerChanges(List<PostcardElementLayer> nextLayers) {
    if (_isSameLayerList(_elementLayers, nextLayers)) {
      return false;
    }
    _pushUndoState();
    setState(() {
      _elementLayers = List<PostcardElementLayer>.from(nextLayers);
    });
    return true;
  }

  void _undo() {
    if (_undoStack.isEmpty) {
      _showHint('娌℃湁鍙挙鍥炵殑鎿嶄綔');
      return;
    }
    final snapshot = _undoStack.removeLast();
    setState(() {
      _elementLayers = List<PostcardElementLayer>.from(snapshot.layers);
      _selectedCity = _cloneCity(snapshot.selectedCity);
      _customPreviewImagePath = snapshot.previewImagePath;
    });
    _showHint('Undo applied');
  }

  void _share() {
    _showHint('鍒嗕韩鍔熻兘寮€鍙戜腑');
  }

  Future<void> _openDynamicEffects() async {
    if (_isSaving) return;
    final result = await Navigator.push<List<PostcardElementLayer>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DynamicEffectScreen(initialLayers: _elementLayers),
      ),
    );
    if (!mounted || result == null) return;
    _applyLayerChanges(result);
  }

  Future<void> _openAddElements() async {
    if (_isSaving) return;

    final result = await Navigator.pushNamed(context, '/add');
    if (!mounted || result == null) return;

    if (result is List<PostcardElementLayer>) {
      final changed = _applyLayerChanges(result);
      if (changed) {
        _showHint('Applied elements: ${_elementLayers.length}');
      }
      return;
    }

    if (result is List) {
      final layers = <PostcardElementLayer>[];
      for (final item in result) {
        if (item is PostcardElementLayer) {
          layers.add(item);
        }
      }
      if (layers.isEmpty) return;
      final changed = _applyLayerChanges(layers);
      if (changed) {
        _showHint('Applied elements: ${_elementLayers.length}');
      }
    }
  }

  List<PostcardElementLayer> _sortedLayers() {
    final layers = List<PostcardElementLayer>.from(_elementLayers);
    layers.sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return layers;
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

  void _bringLayerToFront(String layerId) {
    final layerIndex = _elementLayers.indexWhere(
      (layer) => layer.id == layerId,
    );
    if (layerIndex < 0) return;

    var topZIndex = 0;
    for (final layer in _elementLayers) {
      if (layer.zIndex > topZIndex) {
        topZIndex = layer.zIndex;
      }
    }

    final current = _elementLayers[layerIndex];
    if (current.zIndex == topZIndex) return;

    setState(() {
      _elementLayers[layerIndex] = current.copyWith(zIndex: topZIndex + 1);
    });
  }

  void _updateLayerPosition(
    String layerId,
    Offset delta,
    double previewWidth,
    double previewHeight,
  ) {
    final layerIndex = _elementLayers.indexWhere(
      (layer) => layer.id == layerId,
    );
    if (layerIndex < 0) return;

    final current = _elementLayers[layerIndex];
    final currentOffset = _resolveLayerOffset(
      current,
      previewWidth,
      previewHeight,
    );
    final rawScale = current.scale <= 0 ? 1.0 : current.scale;
    final elementSize = (previewWidth * 0.22 * rawScale).clamp(
      26.0,
      previewWidth * 0.45,
    );

    final minX = -previewWidth / 2 + elementSize / 2;
    final maxX = previewWidth / 2 - elementSize / 2;
    final minY = -previewHeight / 2 + elementSize / 2;
    final maxY = previewHeight / 2 - elementSize / 2;

    final nextX = (currentOffset.dx + delta.dx).clamp(minX, maxX).toDouble();
    final nextY = (currentOffset.dy + delta.dy).clamp(minY, maxY).toDouble();

    setState(() {
      _elementLayers[layerIndex] = current.copyWith(x: nextX, y: nextY);
    });
  }

  Widget _buildLayerOverlay(double previewWidth, double previewHeight) {
    if (_elementLayers.isEmpty) return const SizedBox.shrink();
    final layers = _sortedLayers();

    return AnimatedBuilder(
      animation: _effectController,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            for (final layer in layers)
              _buildSingleLayer(layer, previewWidth, previewHeight),
          ],
        );
      },
    );
  }

  Widget _buildSingleLayer(
    PostcardElementLayer layer,
    double previewWidth,
    double previewHeight,
  ) {
    final rawScale = layer.scale <= 0 ? 1.0 : layer.scale;
    final baseSize = (previewWidth * 0.22 * rawScale).clamp(
      26.0,
      previewWidth * 0.45,
    );

    final offset = _resolveLayerOffset(layer, previewWidth, previewHeight);
    final offsetX = offset.dx;
    final offsetY = offset.dy;

    final left = previewWidth / 2 + offsetX - baseSize / 2;
    final top = previewHeight / 2 + offsetY - baseSize / 2;

    final image = Image.asset(
      layer.assetPath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE5E5E5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFC8C8C8)),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported, size: 18),
        );
      },
    );

    final speed = layer.rotationSpeed <= 0 ? 1.0 : layer.rotationSpeed;
    final directionSign = layer.rotationDirection == 'counterclockwise'
        ? -1.0
        : 1.0;
    final cycleAngle =
        _effectController.value * math.pi * 2 * speed * directionSign;

    Widget transformed = image;
    if (layer.is3dEnabled) {
      final matrix = Matrix4.identity()..setEntry(3, 2, layer.perspective);
      if (layer.rotationAxis == 'horizontal') {
        matrix
          ..rotateX(layer.rotateX + cycleAngle)
          ..rotateY(layer.rotateY);
      } else {
        matrix
          ..rotateY(layer.rotateY + cycleAngle)
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
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) {
          _pushUndoState();
          _bringLayerToFront(layer.id);
        },
        onPanUpdate: (details) {
          _updateLayerPosition(
            layer.id,
            details.delta,
            previewWidth,
            previewHeight,
          );
        },
        child: SizedBox(width: baseSize, height: baseSize, child: transformed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const double designWidth = 400;
            const double designHeight = 770;
            final double availableWidth = constraints.maxWidth - 40;
            final double availableHeight = constraints.maxHeight;

            double widthScale = availableWidth / designWidth;
            double heightScale = availableHeight / designHeight;
            double scale = widthScale < heightScale ? widthScale : heightScale;
            if (scale > 1.0) scale = 1.0;
            if (scale < 0.72) scale = 0.72;

            final double contentWidth = designWidth * scale;
            final double topButtonWidth = 94 * scale;
            final double topButtonHeight = 41 * scale;
            final double previewHeight = 258 * scale;
            final double actionWidth = 166 * scale;
            final double actionHeight = 50 * scale;
            final double templateHeight = 180 * scale;
            final double saveWidth = 353 * scale;
            final double saveHeight = 87 * scale;
            double actionGap = contentWidth - actionWidth * 2;
            if (actionGap < 14 * scale) actionGap = 14 * scale;
            if (actionGap > 40 * scale) actionGap = 40 * scale;

            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(0, 24 * scale, 0, 26 * scale),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '鍩庡競鏄庝俊鐗?路 缂栬緫',
                        style: TextStyle(
                          fontSize: 22 * scale,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 18 * scale),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _AssetTapButton(
                            assetPath: 'assets/images/edit/缂栬緫-杩斿洖.png',
                            width: topButtonWidth,
                            height: topButtonHeight,
                            onTap: _undo,
                          ),
                          _AssetTapButton(
                            assetPath: 'assets/images/edit/缂栬緫-鍒嗕韩.png',
                            width: topButtonWidth,
                            height: topButtonHeight,
                            onTap: _share,
                          ),
                        ],
                      ),
                      SizedBox(height: 24 * scale),
                      _AssetTapButton(
                        assetPath: _defaultPreviewAsset,
                        imageSource: _currentPreviewSource,
                        width: contentWidth,
                        height: previewHeight,
                        onTap: _pickLocalPreviewImage,
                        child: _buildLayerOverlay(contentWidth, previewHeight),
                      ),
                      SizedBox(height: 30 * scale),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              _AssetTapButton(
                                assetPath: 'assets/images/edit/缂栬緫-娣诲姞鍏冪礌.png',
                                width: actionWidth,
                                height: actionHeight,
                                onTap: _openAddElements,
                              ),
                              SizedBox(height: 14 * scale),
                              _AssetTapButton(
                                assetPath: 'assets/images/edit/缂栬緫-鍔ㄦ€佹晥鏋?png',
                                width: actionWidth,
                                height: actionHeight,
                                onTap: _openDynamicEffects,
                              ),
                              SizedBox(height: 14 * scale),
                              _AssetTapButton(
                                assetPath: 'assets/images/edit/缂栬緫-鍦扮偣鏍囨敞.png',
                                width: actionWidth,
                                height: actionHeight,
                                onTap: _selectLocationTag,
                              ),
                            ],
                          ),
                          SizedBox(width: actionGap),
                          SizedBox(
                            width: actionWidth,
                            height: templateHeight,
                            child: _buildHotTemplateCarousel(
                              actionWidth,
                              templateHeight,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 14 * scale),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _selectedCity == null
                              ? 'Location not tagged'
                              : '宸叉爣娉ㄥ湴鐐癸細${_selectedCity!.name} (${_selectedCity!.code})',
                          style: TextStyle(
                            fontSize: 13 * scale,
                            color: const Color(0xFF3F4E63),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(height: 16 * scale),
                      _AssetTapButton(
                        assetPath: 'assets/images/edit/缂栬緫-淇濆瓨.png',
                        width: saveWidth,
                        height: saveHeight,
                        onTap: _isSaving ? null : _savePostcard,
                        child: _isSaving
                            ? const Center(
                                child: SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

const Map<String, String> _provinceNameByPrefix = {
  '11': '鍖椾含',
  '12': '澶╂触',
  '13': '娌冲寳',
  '14': '灞辫タ',
  '15': 'Inner Mongolia',
  '21': '杈藉畞',
  '22': '鍚夋灄',
  '23': 'Heilongjiang',
  '31': '涓婃捣',
  '32': '姹熻嫃',
  '33': '娴欐睙',
  '34': '瀹夊窘',
  '35': '绂忓缓',
  '36': '姹熻タ',
  '37': '灞变笢',
  '41': '娌冲崡',
  '42': '婀栧寳',
  '43': '婀栧崡',
  '44': '骞夸笢',
  '45': '骞胯タ',
  '46': '娴峰崡',
  '50': '閲嶅簡',
  '51': '鍥涘窛',
  '52': '璐靛窞',
  '53': '浜戝崡',
  '54': '瑗胯棌',
  '61': '闄曡タ',
  '62': '鐢樿們',
  '63': '闈掓捣',
  '64': '瀹佸',
  '65': '鏂扮枂',
  '71': '鍙版咕',
  '81': '棣欐腐',
  '82': '婢抽棬',
};

class _AssetTapButton extends StatelessWidget {
  final String assetPath;
  final String? imageSource;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final Widget? child;

  const _AssetTapButton({
    required this.assetPath,
    this.imageSource,
    required this.width,
    required this.height,
    this.onTap,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if ((imageSource?.trim().isNotEmpty ?? false))
              ResolvedImage(
                source: imageSource!,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                fallbackBuilder: (_) => Image.asset(
                  assetPath,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: Color(0xFFE5E5E5)),
                ),
              )
            else
              Image.asset(
                assetPath,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
            if (child case final Widget overlay) overlay,
          ],
        ),
      ),
    );
  }
}

class _EditorSnapshot {
  final List<PostcardElementLayer> layers;
  final City? selectedCity;
  final String? previewImagePath;

  const _EditorSnapshot({
    required this.layers,
    required this.selectedCity,
    required this.previewImagePath,
  });
}
