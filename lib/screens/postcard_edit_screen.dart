import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../data/city_code_center.dart';
import '../models/postcard_element_layer.dart';
import '../services/backend_api_client.dart';
import '../services/edited_postcard_service.dart';
import '../services/postcard_data_refresh_bus.dart';
import '../widgets/postcard_layer_render_helper.dart';
import '../widgets/resolved_image.dart';
import 'add_text_screen.dart';
import 'city_search_screen.dart';
import 'dynamic_effect_screen.dart';
import 'location_annotation_screen.dart';

class PostcardEditScreen extends StatefulWidget {
  final EditedPostcard? initialDraft;

  const PostcardEditScreen({super.key, this.initialDraft});

  @override
  State<PostcardEditScreen> createState() => _PostcardEditScreenState();
}

class _PostcardEditScreenState extends State<PostcardEditScreen>
    with SingleTickerProviderStateMixin {
  static const String _defaultPreviewAsset = 'assets/images/edit/编辑-开始定制.png';
  static const int _maxUndoSteps = 30;
  static const double _postcardAspectRatio = 400 / 258;

  final EditedPostcardService _editedPostcardService = EditedPostcardService();
  final ImagePicker _imagePicker = ImagePicker();
  final PageController _templatePageController = PageController();
  final GlobalKey _sharePreviewKey = GlobalKey();
  final List<_EditorSnapshot> _undoStack = <_EditorSnapshot>[];
  List<PostcardElementLayer> _elementLayers = const [];
  List<EditedPostcard> _hotTemplates = const [];
  City? _selectedCity;
  String _locationDetail = '';
  String? _customPreviewImagePath;
  String? _editingDraftId;
  Timer? _templateAutoPlayTimer;
  bool _isLoadingHotTemplates = true;
  int _currentTemplateIndex = 0;
  bool _isSaving = false;
  bool _isSharing = false;
  late final AnimationController _effectController;

  @override
  void initState() {
    super.initState();
    _restoreInitialDraft();
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

  void _restoreInitialDraft() {
    final draft = widget.initialDraft;
    if (draft == null) return;

    final source = draft.imageUrl.trim();
    final draftId = draft.draftId.trim();
    final cityName = draft.cityName?.trim() ?? '';
    final cityCode = draft.cityCode?.trim() ?? '';
    final provinceName = draft.provinceName?.trim() ?? '';
    final resolvedName = cityName.isNotEmpty
        ? cityName
        : (provinceName.isNotEmpty ? provinceName : '未知地点');

    _customPreviewImagePath = source.isEmpty ? null : source;
    _editingDraftId = draftId.isEmpty ? null : draftId;
    _elementLayers = List<PostcardElementLayer>.from(draft.layers);
    _selectedCity = (cityName.isEmpty && cityCode.isEmpty)
        ? null
        : City(name: resolvedName, code: cityCode);
    _locationDetail = draft.locationDetail?.trim() ?? '';
  }

  Future<void> _savePostcard() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final cityCode = _normalizeCityCode(_selectedCity?.code);
    final cityName = _selectedCity?.name.trim();
    final provinceName = _resolveProvinceNameFromCityCode(cityCode);
    final coordinate = cityCode == null ? null : kCityCodeCoordinates[cityCode];

    try {
      final savedId = await _editedPostcardService.saveEditedPostcard(
        draftId: _editingDraftId,
        imageUrl: _currentPreviewSource,
        cityName: (cityName == null || cityName.isEmpty) ? null : cityName,
        cityCode: cityCode,
        provinceName: provinceName,
        locationDetail: _locationDetail,
        latitude: coordinate?.latitude,
        longitude: coordinate?.longitude,
        layers: _elementLayers,
        syncToBackend: false,
      );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _editingDraftId = savedId;
      });
      PostcardDataRefreshBus.notifySaved();
      Navigator.pop(context, true);
    } on BackendApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showHint(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showHint('保存失败，请重试');
    }
  }

  Future<bool> _saveAsDraft() async {
    if (_isSaving) return false;
    setState(() => _isSaving = true);

    final cityCode = _normalizeCityCode(_selectedCity?.code);
    final cityName = _selectedCity?.name.trim();
    final provinceName = _resolveProvinceNameFromCityCode(cityCode);
    final coordinate = cityCode == null ? null : kCityCodeCoordinates[cityCode];

    try {
      final draftId = await _editedPostcardService.saveDraftPostcard(
        draftId: _editingDraftId,
        imageUrl: _currentPreviewSource,
        cityName: (cityName == null || cityName.isEmpty) ? null : cityName,
        cityCode: cityCode,
        provinceName: provinceName,
        locationDetail: _locationDetail,
        latitude: coordinate?.latitude,
        longitude: coordinate?.longitude,
        layers: _elementLayers,
      );
      if (!mounted) return false;
      setState(() {
        _isSaving = false;
        _editingDraftId = draftId;
      });
      return true;
    } catch (_) {
      if (!mounted) return false;
      setState(() => _isSaving = false);
      _showHint('草稿保存失败，请重试');
      return false;
    }
  }

  Future<void> _saveDraftAndExit() async {
    final saved = await _saveAsDraft();
    if (!mounted || !saved) return;
    _showHint('草稿已保存');
    Navigator.pop(context, true);
  }

  Future<void> _onBackPressed() async {
    if (_isSaving) return;

    final action = await showDialog<_EditorExitAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('返回编辑'),
        content: const Text('请选择返回方式'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _EditorExitAction.discard),
            child: const Text('不保存返回'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _EditorExitAction.saveDraft),
            child: const Text('存为草稿'),
          ),
        ],
      ),
    );

    if (!mounted || action == null) return;
    if (action == _EditorExitAction.discard) {
      Navigator.pop(context, false);
      return;
    }
    await _saveDraftAndExit();
  }

  Future<void> _openLocationAnnotation() async {
    if (_isSaving) return;

    final result = await Navigator.push<LocationAnnotationResult>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationAnnotationScreen(
          initialCity: _cloneCity(_selectedCity),
          initialDetailAddress: _locationDetail,
        ),
      ),
    );

    if (!mounted || result == null) return;
    final nextCity = result.city;
    final nextLocationDetail = result.detailAddress.trim();
    if (_isSameCity(_selectedCity, nextCity) &&
        _isSameLocationDetail(_locationDetail, nextLocationDetail)) {
      return;
    }

    _pushUndoState();
    setState(() {
      _selectedCity = _cloneCity(nextCity);
      _locationDetail = nextLocationDetail;
    });
    final fullLocationText = _buildFullLocationText();
    _showHint(fullLocationText.isEmpty ? '已清除地点标注' : '已标注地点：$fullLocationText');
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

  bool _isSameLocationDetail(String? a, String? b) {
    return (a?.trim() ?? '') == (b?.trim() ?? '');
  }

  String _buildLocationCoreText() {
    final city = _selectedCity;
    if (city == null) return '';

    final name = city.name.trim();
    if (name.isNotEmpty) return name;

    final code = city.code.trim();
    if (code.isNotEmpty) return '城市代码$code';
    return '';
  }

  String _buildFullLocationText() {
    final core = _buildLocationCoreText();
    final detail = _locationDetail.trim();
    if (core.isEmpty) return detail;
    if (detail.isEmpty) return core;
    if (detail.contains(core)) return detail;
    if (core.contains(detail)) return core;
    return '$core$detail';
  }

  String _buildLocationTagText() {
    final text = _buildFullLocationText();
    if (text.isEmpty) return '未标注地点';
    return text;
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

  Widget _buildPreviewPlaceholder(double scale, {bool showLoading = false}) {
    const placeholderText =
        '开始定制你的专属明信片吧！\n'
        '上传照片，定制专属祝福！';
    return ColoredBox(
      color: const Color(0xFFEAF7E7),
      child: Center(
        child: showLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : Text(
                placeholderText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20 * scale,
                  height: 1.3,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  Future<void> _pickLocalPreviewImage() async {
    if (_isSaving) return;

    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (!mounted || picked == null) return;

      final nextPath = await _pickAndCropPostcardImage(picked.path);
      if (!mounted || nextPath == null) return;
      if (nextPath.isEmpty ||
          _isSamePreviewSource(_customPreviewImagePath, nextPath)) {
        return;
      }

      _pushUndoState();
      setState(() => _customPreviewImagePath = nextPath);
      _showHint('图片已更新');
    } catch (e, stackTrace) {
      debugPrint('选择明信片图片失败: $e\n$stackTrace');
      if (!mounted) return;
      _showHint('图片选择失败');
    }
  }

  Future<String?> _pickAndCropPostcardImage(String sourcePath) async {
    final normalizedSource = sourcePath.trim();
    if (normalizedSource.isEmpty) return null;
    if (!_supportsNativeCropper()) {
      return normalizedSource;
    }

    try {
      final croppedPath = await _cropPostcardImage(normalizedSource);
      return croppedPath ?? normalizedSource;
    } catch (e, stackTrace) {
      debugPrint('裁剪明信片失败，已回退原图: $e\n$stackTrace');
      if (mounted) {
        _showHint('裁剪失败，已使用原图');
      }
      return normalizedSource;
    }
  }

  bool _supportsNativeCropper() {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<String?> _cropPostcardImage(String sourcePath) async {
    final uiSettings = <PlatformUiSettings>[];
    if (kIsWeb) {
      uiSettings.add(
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(width: 920, height: 620),
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      uiSettings.add(
        AndroidUiSettings(
          toolbarTitle: '裁剪明信片',
          toolbarColor: const Color(0xFF2F663A),
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          hideBottomControls: false,
          initAspectRatio: CropAspectRatioPreset.original,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      uiSettings.add(
        IOSUiSettings(
          title: '裁剪明信片',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      );
    }

    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 400, ratioY: 258),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 92,
      uiSettings: uiSettings,
    );
    final path = cropped?.path.trim();
    if (path == null || path.isEmpty) return null;
    return path;
  }

  Future<void> _loadHotTemplates() async {
    List<EditedPostcard> templates = const <EditedPostcard>[];
    try {
      templates = await _editedPostcardService.getTopLikedPostcards(limit: 5);
    } catch (_) {
      templates = const <EditedPostcard>[];
    }

    if (!mounted) return;
    setState(() {
      _hotTemplates = templates;
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
      _showHint('模板已是当前内容');
      return;
    }

    _pushUndoState();
    setState(() {
      _customPreviewImagePath = nextImage.isEmpty ? null : nextImage;
      _elementLayers = nextLayers;
    });
    _showHint('已应用热门模板');
  }

  Widget _buildHotTemplateCarousel(double width, double height) {
    const baseColor = Color(0xFFEAF7E7);
    final borderRadius = BorderRadius.circular(14);

    Widget shell(Widget child) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: borderRadius,
          border: Border.all(color: const Color(0xFFA5CAA2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }

    if (_isLoadingHotTemplates) {
      return shell(
        const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_hotTemplates.isEmpty) {
      return shell(
        const Center(
          child: Text(
            '暂无热门模板',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF54634C),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return shell(
      Stack(
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
                    const ColoredBox(color: Color(0xFFEAF7E7)),
                    ResolvedImage(
                      source: template.imageUrl,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      fallbackBuilder: (_) =>
                          const ColoredBox(color: Color(0xFFEAF7E7)),
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
                          ? const Color(0xFF3F7C3F)
                          : const Color(0xFF8FB78F),
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
    final layerSize = measurePostcardLayerSize(
      layer,
      previewWidth: previewWidth,
      previewHeight: previewHeight,
    );
    final offset = _resolveLayerOffset(layer, previewWidth, previewHeight);
    final left = previewWidth / 2 + offset.dx - layerSize.width / 2;
    final top = previewHeight / 2 + offset.dy - layerSize.height / 2;

    final visual = buildPostcardLayerVisual(
      layer,
      previewWidth: previewWidth,
      previewHeight: previewHeight,
      silentAssetError: true,
    );

    Widget transformed = visual;
    if (layer.isAsset && layer.is3dEnabled) {
      final speed = layer.rotationSpeed <= 0 ? 1.0 : layer.rotationSpeed;
      final directionSign = layer.rotationDirection == 'counterclockwise'
          ? -1.0
          : 1.0;
      final cycleAngle =
          _effectController.value * math.pi * 2 * speed * directionSign;
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
        child: visual,
      );
    } else if (layer.rotation2d != 0.0) {
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
        a.type == b.type &&
        a.elementKey == b.elementKey &&
        a.assetPath == b.assetPath &&
        a.text == b.text &&
        mapEquals(a.style?.toJson(), b.style?.toJson()) &&
        mapEquals(a.box?.toJson(), b.box?.toJson()) &&
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
      locationDetail: _locationDetail,
      previewImagePath: _customPreviewImagePath,
    );
    if (_undoStack.isNotEmpty) {
      final last = _undoStack.last;
      if (_isSameLayerList(last.layers, snapshot.layers) &&
          _isSameCity(last.selectedCity, snapshot.selectedCity) &&
          _isSameLocationDetail(last.locationDetail, snapshot.locationDetail) &&
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
      _showHint('没有可撤回的操作');
      return;
    }
    final snapshot = _undoStack.removeLast();
    setState(() {
      _elementLayers = List<PostcardElementLayer>.from(snapshot.layers);
      _selectedCity = _cloneCity(snapshot.selectedCity);
      _locationDetail = snapshot.locationDetail;
      _customPreviewImagePath = snapshot.previewImagePath;
    });
    _showHint('已撤回到上一步');
  }

  // ignore: unused_element
  Future<void> _shareLegacyPlaceholder() async {
    _showHint('分享功能开发中');
  }

  Future<void> _share() async {
    if (_isSaving || _isSharing) return;

    setState(() => _isSharing = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final imageBytes = await _captureShareImageBytes();
      if (imageBytes == null || imageBytes.isEmpty) {
        if (mounted) _showHint('分享失败，请稍后重试');
        return;
      }

      final location = _buildFullLocationText().trim();
      final shareText = location.isEmpty
          ? '我在城市明信片制作了一张明信片，分享给你。'
          : '我在城市明信片制作了一张明信片，地点：$location';
      final fileName =
          'city_postcard_${DateTime.now().millisecondsSinceEpoch}.png';
      final shareFile = XFile.fromData(
        imageBytes,
        mimeType: 'image/png',
        name: fileName,
      );

      await Share.shareXFiles(
        <XFile>[shareFile],
        text: shareText,
        subject: '城市明信片',
      );
    } catch (e, stackTrace) {
      debugPrint('分享明信片失败: $e\n$stackTrace');
      if (mounted) _showHint('分享失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<Uint8List?> _captureShareImageBytes() async {
    final renderObject = _sharePreviewKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      return null;
    }

    final pixelRatio = (MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0)
        .clamp(2.0, 3.0)
        .toDouble();
    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return byteData.buffer.asUint8List();
  }

  Future<void> _openDynamicEffects() async {
    if (_isSaving) return;
    final assetLayers = _elementLayers
        .where((layer) => layer.isAsset)
        .toList(growable: false);
    final result = await Navigator.push<List<PostcardElementLayer>>(
      context,
      MaterialPageRoute(
        builder: (context) => DynamicEffectScreen(initialLayers: assetLayers),
      ),
    );
    if (!mounted || result == null) return;
    _applyLayerChanges(_mergeAssetsWithExistingText(result));
  }

  Future<void> _openAddElements() async {
    if (_isSaving) return;

    final result = await Navigator.pushNamed(context, '/add');
    if (!mounted || result == null) return;

    if (result is List<PostcardElementLayer>) {
      final changed = _applyLayerChanges(_mergeAssetsWithExistingText(result));
      if (changed) {
        _showHint('已应用元素：${_elementLayers.length} 个');
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
      final changed = _applyLayerChanges(_mergeAssetsWithExistingText(layers));
      if (changed) {
        _showHint('已应用元素：${_elementLayers.length} 个');
      }
    }
  }

  Future<void> _openAddText() async {
    if (_isSaving) return;

    var topZIndex = 0;
    for (final layer in _elementLayers) {
      if (layer.zIndex > topZIndex) {
        topZIndex = layer.zIndex;
      }
    }

    final textLayerCount = _elementLayers.where((layer) => layer.isText).length;
    final x = (0.5 + ((textLayerCount % 3) - 1) * 0.12).clamp(0.16, 0.84);
    final y = (0.5 + (((textLayerCount ~/ 3) % 3) - 1) * 0.1).clamp(0.16, 0.84);
    final initialLayer = PostcardElementLayer(
      id: _buildLayerId('text'),
      type: 'text',
      text: '',
      x: x.toDouble(),
      y: y.toDouble(),
      scale: 1,
      rotation2d: 0,
      zIndex: topZIndex + 1,
      style: const PostcardTextLayerStyle(),
      box: const PostcardTextLayerBox(),
    );

    final result = await Navigator.push<PostcardElementLayer>(
      context,
      MaterialPageRoute(
        builder: (context) => AddTextScreen(initialLayer: initialLayer),
      ),
    );
    if (!mounted || result == null) return;

    final normalizedText = result.text?.trim() ?? '';
    if (normalizedText.isEmpty) return;

    final textLayer = result.copyWith(
      type: 'text',
      text: normalizedText,
      elementKey: '',
      assetPath: '',
      style: result.style ?? const PostcardTextLayerStyle(),
      box: result.box ?? const PostcardTextLayerBox(),
      is3dEnabled: false,
      rotateX: 0,
      rotateY: 0,
      clearSpeedLevel: true,
    );
    final nextLayers = List<PostcardElementLayer>.from(_elementLayers)
      ..add(textLayer);
    final changed = _applyLayerChanges(nextLayers);
    if (changed) {
      _showHint('已添加文字');
    }
  }

  List<PostcardElementLayer> _mergeAssetsWithExistingText(
    List<PostcardElementLayer> incoming,
  ) {
    if (incoming.isEmpty) {
      return List<PostcardElementLayer>.from(_elementLayers);
    }
    if (incoming.any((item) => item.isText)) {
      return List<PostcardElementLayer>.from(incoming);
    }

    final merged = List<PostcardElementLayer>.from(incoming);
    final usedIds = merged.map((item) => item.id).toSet();
    final existingTextLayers = _elementLayers.where((item) => item.isText);
    for (final textLayer in existingTextLayers) {
      if (usedIds.add(textLayer.id)) {
        merged.add(textLayer);
      } else {
        merged.add(textLayer.copyWith(id: _buildLayerId('text', usedIds)));
      }
    }
    return merged;
  }

  String _buildLayerId(String prefix, [Set<String>? occupiedIds]) {
    final usedIds =
        occupiedIds ?? _elementLayers.map((item) => item.id).toSet();
    var seed = DateTime.now().microsecondsSinceEpoch;
    var candidate = '${prefix}_$seed';
    while (usedIds.contains(candidate)) {
      seed += 1;
      candidate = '${prefix}_$seed';
    }
    usedIds.add(candidate);
    return candidate;
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
    return resolvePostcardLayerOffset(
      layer,
      previewWidth: previewWidth,
      previewHeight: previewHeight,
    );
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
    final elementSize = measurePostcardLayerSize(
      current,
      previewWidth: previewWidth,
      previewHeight: previewHeight,
    );

    final minX = -previewWidth / 2 + elementSize.width / 2;
    final maxX = previewWidth / 2 - elementSize.width / 2;
    final minY = -previewHeight / 2 + elementSize.height / 2;
    final maxY = previewHeight / 2 - elementSize.height / 2;

    final nextX = (currentOffset.dx + delta.dx).clamp(minX, maxX).toDouble();
    final nextY = (currentOffset.dy + delta.dy).clamp(minY, maxY).toDouble();
    final normalizedX = ((nextX / previewWidth) + 0.5).clamp(0.0, 1.0);
    final normalizedY = ((nextY / previewHeight) + 0.5).clamp(0.0, 1.0);

    setState(() {
      _elementLayers[layerIndex] = current.copyWith(
        x: normalizedX.toDouble(),
        y: normalizedY.toDouble(),
      );
    });
  }

  Future<void> _removeLayer(String layerId) async {
    if (_isSaving) return;
    final layerIndex = _elementLayers.indexWhere(
      (layer) => layer.id == layerId,
    );
    if (layerIndex < 0) return;

    final target = _elementLayers[layerIndex];
    final label = target.isText ? '文字' : '元素';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('删除$label'),
        content: Text('确定删除该$label吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final latestIndex = _elementLayers.indexWhere(
      (layer) => layer.id == layerId,
    );
    if (latestIndex < 0) return;

    final removed = _elementLayers[latestIndex];
    _pushUndoState();
    setState(() {
      final nextLayers = List<PostcardElementLayer>.from(_elementLayers);
      nextLayers.removeAt(latestIndex);
      _elementLayers = nextLayers;
    });

    final removedLabel = removed.isText ? '文字' : '元素';
    _showHint('已删除$removedLabel，可撤销');
  }

  Widget _buildLayerOverlay(double previewWidth, double previewHeight) {
    final layers = _elementLayers.isEmpty
        ? const <PostcardElementLayer>[]
        : _sortedLayers();
    final locationText = _buildFullLocationText();
    if (layers.isEmpty && locationText.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget buildOverlayStack() {
      return Stack(
        fit: StackFit.expand,
        children: [
          for (final layer in layers)
            _buildSingleLayer(layer, previewWidth, previewHeight),
          if (locationText.isNotEmpty)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: _PreviewLocationBadge(text: locationText),
            ),
        ],
      );
    }

    if (layers.isEmpty) {
      return buildOverlayStack();
    }
    return AnimatedBuilder(
      animation: _effectController,
      builder: (context, child) => buildOverlayStack(),
    );
  }

  Widget _buildSingleLayer(
    PostcardElementLayer layer,
    double previewWidth,
    double previewHeight,
  ) {
    final layerSize = measurePostcardLayerSize(
      layer,
      previewWidth: previewWidth,
      previewHeight: previewHeight,
    );

    final offset = _resolveLayerOffset(layer, previewWidth, previewHeight);
    final offsetX = offset.dx;
    final offsetY = offset.dy;

    final left = previewWidth / 2 + offsetX - layerSize.width / 2;
    final top = previewHeight / 2 + offsetY - layerSize.height / 2;

    final visual = buildPostcardLayerVisual(
      layer,
      previewWidth: previewWidth,
      previewHeight: previewHeight,
    );

    Widget transformed = visual;
    if (layer.isAsset && layer.is3dEnabled) {
      final speed = layer.rotationSpeed <= 0 ? 1.0 : layer.rotationSpeed;
      final directionSign = layer.rotationDirection == 'counterclockwise'
          ? -1.0
          : 1.0;
      final cycleAngle =
          _effectController.value * math.pi * 2 * speed * directionSign;
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
        child: visual,
      );
    } else if (layer.rotation2d != 0) {
      transformed = Transform.rotate(angle: layer.rotation2d, child: visual);
    }

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: () => _removeLayer(layer.id),
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
        child: SizedBox(
          width: layerSize.width,
          height: layerSize.height,
          child: transformed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBackPressed();
      },
      child: Scaffold(
        body: Container(
          color: const Color(0xFFFFFFFF),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const double designWidth = 400;
                const double designHeight = 820;
                final double availableWidth = constraints.maxWidth - 24;
                final double availableHeight = constraints.maxHeight;

                double widthScale = availableWidth / designWidth;
                double heightScale = availableHeight / designHeight;
                double scale = widthScale < heightScale
                    ? widthScale
                    : heightScale;
                if (scale > 1.0) scale = 1.0;
                if (scale < 0.68) scale = 0.68;

                final double contentWidth = designWidth * scale;
                final double topButtonWidth = 94 * scale;
                final double topButtonHeight = 41 * scale;
                final double previewWidth = contentWidth - 16 * scale;
                final double previewHeight =
                    previewWidth / _postcardAspectRatio;
                final double actionHeight = 54 * scale;
                final double quickActionGap = 10 * scale;
                final double quickActionWidth =
                    (contentWidth - quickActionGap) / 2;
                final double saveWidth = 353 * scale;
                final double saveHeight = 87 * scale;

                return Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(0, 20 * scale, 0, 22 * scale),
                    child: SizedBox(
                      width: contentWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '城市明信片·编辑',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22 * scale,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 14 * scale),
                          SizedBox(
                            height: topButtonHeight,
                            child: Stack(
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _TopControlButton(
                                    icon: Icons.arrow_back_ios_new_rounded,
                                    label: '返回',
                                    width: topButtonWidth,
                                    height: topButtonHeight,
                                    onTap: _onBackPressed,
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.center,
                                  child: _TopControlButton(
                                    icon: Icons.undo_rounded,
                                    label: '撤回',
                                    width: topButtonWidth,
                                    height: topButtonHeight,
                                    onTap: _undo,
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _IconTextTopButton(
                                    iconAssetPath:
                                        'assets/images/edit/share_1.png',
                                    label: '分享',
                                    width: topButtonWidth,
                                    height: topButtonHeight,
                                    onTap: _isSharing ? null : _share,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16 * scale),
                          Container(
                            padding: EdgeInsets.all(8 * scale),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF7E7),
                              borderRadius: BorderRadius.circular(20 * scale),
                              border: Border.all(
                                color: const Color(0xFFB9D8B7),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1A5B875B),
                                  blurRadius: 14,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: GestureDetector(
                              onTap: _pickLocalPreviewImage,
                              child: RepaintBoundary(
                                key: _sharePreviewKey,
                                child: SizedBox(
                                  width: previewWidth,
                                  height: previewHeight,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (_customPreviewImagePath != null &&
                                          _customPreviewImagePath!
                                              .trim()
                                              .isNotEmpty)
                                        ResolvedImage(
                                          source: _customPreviewImagePath!,
                                          fit: BoxFit.cover,
                                          filterQuality: FilterQuality.high,
                                          fallbackBuilder: (_) =>
                                              _buildPreviewPlaceholder(scale),
                                          loadingBuilder: (_) =>
                                              _buildPreviewPlaceholder(
                                                scale,
                                                showLoading: true,
                                              ),
                                        )
                                      else
                                        _buildPreviewPlaceholder(scale),
                                      _buildLayerOverlay(
                                        previewWidth,
                                        previewHeight,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 8 * scale),
                          Text(
                            '点击明信片可更换图片',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12 * scale,
                              color: const Color(0xFF4D7A56),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 18 * scale),
                          Column(
                            children: [
                              Row(
                                children: [
                                  _EditorActionButton(
                                    icon: Icons.auto_awesome_outlined,
                                    label: '添加元素',
                                    width: quickActionWidth,
                                    height: actionHeight,
                                    onTap: _openAddElements,
                                  ),
                                  SizedBox(width: quickActionGap),
                                  _EditorActionButton(
                                    icon: Icons.text_fields_rounded,
                                    label: '添加文字',
                                    width: quickActionWidth,
                                    height: actionHeight,
                                    onTap: _openAddText,
                                  ),
                                ],
                              ),
                              SizedBox(height: quickActionGap),
                              Row(
                                children: [
                                  _EditorActionButton(
                                    icon: Icons.auto_mode_rounded,
                                    label: '动态效果',
                                    width: quickActionWidth,
                                    height: actionHeight,
                                    onTap: _openDynamicEffects,
                                  ),
                                  SizedBox(width: quickActionGap),
                                  _EditorActionButton(
                                    icon: Icons.place_rounded,
                                    label: '地点标注',
                                    width: quickActionWidth,
                                    height: actionHeight,
                                    onTap: _openLocationAnnotation,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 10 * scale),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14 * scale,
                              vertical: 12 * scale,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF7E7),
                              borderRadius: BorderRadius.circular(14 * scale),
                              border: Border.all(
                                color: const Color(0xFFAED0AE),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 18 * scale,
                                  color: const Color(0xFF3D7C45),
                                ),
                                SizedBox(width: 6 * scale),
                                Expanded(
                                  child: Text(
                                    _buildLocationTagText(),
                                    style: TextStyle(
                                      fontSize: 13 * scale,
                                      color: const Color(0xFF2D5D35),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 10 * scale),
                          Container(
                            padding: EdgeInsets.fromLTRB(
                              8 * scale,
                              8 * scale,
                              8 * scale,
                              10 * scale,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF7E7),
                              borderRadius: BorderRadius.circular(16 * scale),
                              border: Border.all(
                                color: const Color(0xFFAED0AE),
                              ),
                            ),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: previewWidth,
                                  height: previewHeight,
                                  child: _buildHotTemplateCarousel(
                                    previewWidth,
                                    previewHeight,
                                  ),
                                ),
                                SizedBox(height: 8 * scale),
                                Text(
                                  '热门模板',
                                  style: TextStyle(
                                    fontSize: 12 * scale,
                                    color: const Color(0xFF2D5D35),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16 * scale),
                          _AssetTapButton(
                            assetPath: 'assets/images/edit/编辑-保存.png',
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
                          SizedBox(height: 10 * scale),
                          Text(
                            '点击返回可选择不保存返回或存为草稿',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12 * scale,
                              color: const Color(0xFF5B7562),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

enum _EditorExitAction { discard, saveDraft }

const Map<String, String> _provinceNameByPrefix = {
  '11': '北京',
  '12': '天津',
  '13': '河北',
  '14': '山西',
  '15': '内蒙古',
  '21': '辽宁',
  '22': '吉林',
  '23': '黑龙江',
  '31': '上海',
  '32': '江苏',
  '33': '浙江',
  '34': '安徽',
  '35': '福建',
  '36': '江西',
  '37': '山东',
  '41': '河南',
  '42': '湖北',
  '43': '湖南',
  '44': '广东',
  '45': '广西',
  '46': '海南',
  '50': '重庆',
  '51': '四川',
  '52': '贵州',
  '53': '云南',
  '54': '西藏',
  '61': '陕西',
  '62': '甘肃',
  '63': '青海',
  '64': '宁夏',
  '65': '新疆',
  '71': '台湾',
  '81': '香港',
  '82': '澳门',
};

class _AssetTapButton extends StatelessWidget {
  final String assetPath;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final Widget? child;

  const _AssetTapButton({
    required this.assetPath,
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
            Image.asset(
              assetPath,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: Color(0xFFE5E5E5)),
            ),
            if (child case final Widget overlay) overlay,
          ],
        ),
      ),
    );
  }
}

class _TopControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const _TopControlButton({
    required this.icon,
    required this.label,
    required this.width,
    required this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.symmetric(horizontal: width * 0.14),
        decoration: BoxDecoration(
          color: const Color(0xFFEAEFE1),
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: const Color(0xFFAFB6A3)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
            BoxShadow(
              color: Color(0x18FFFFFF),
              blurRadius: 2,
              offset: Offset(0, -1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: height * 0.46, color: const Color(0xFF2F372D)),
            SizedBox(width: width * 0.08),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: height * 0.35,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2F372D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconTextTopButton extends StatelessWidget {
  final String iconAssetPath;
  final String label;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const _IconTextTopButton({
    required this.iconAssetPath,
    required this.label,
    required this.width,
    required this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.symmetric(horizontal: width * 0.14),
        decoration: BoxDecoration(
          color: const Color(0xFFEAEFE1),
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: const Color(0xFFAFB6A3)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
            BoxShadow(
              color: Color(0x18FFFFFF),
              blurRadius: 2,
              offset: Offset(0, -1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              iconAssetPath,
              width: height * 0.46,
              height: height * 0.46,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => Icon(
                Icons.share_outlined,
                size: height * 0.46,
                color: const Color(0xFF3E463A),
              ),
            ),
            SizedBox(width: width * 0.08),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: height * 0.38,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2F372D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const _EditorActionButton({
    required this.icon,
    required this.label,
    required this.width,
    required this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFF0FAEE),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFB3D4B3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: height * 0.42, color: const Color(0xFF2F663A)),
              SizedBox(width: width * 0.06),
              Text(
                label,
                style: TextStyle(
                  fontSize: height * 0.29,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2F663A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewLocationBadge extends StatelessWidget {
  final String text;

  const _PreviewLocationBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xB32A4D31),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorSnapshot {
  final List<PostcardElementLayer> layers;
  final City? selectedCity;
  final String locationDetail;
  final String? previewImagePath;

  const _EditorSnapshot({
    required this.layers,
    required this.selectedCity,
    required this.locationDetail,
    required this.previewImagePath,
  });
}
