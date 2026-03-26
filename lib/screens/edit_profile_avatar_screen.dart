import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../services/avatar_upload_service.dart';
import '../services/storage_service.dart';
import '../widgets/resolved_image.dart';

class EditProfileAvatarScreen extends StatefulWidget {
  const EditProfileAvatarScreen({super.key});

  @override
  State<EditProfileAvatarScreen> createState() =>
      _EditProfileAvatarScreenState();
}

class _EditProfileAvatarScreenState extends State<EditProfileAvatarScreen> {
  final StorageService _storageService = StorageService();
  final AvatarUploadService _avatarUploadService = AvatarUploadService();
  final ImagePicker _imagePicker = ImagePicker();

  String? _avatarSource;
  String? _avatarStorageSource;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final avatar = await _storageService.getProfileAvatar();
    final storageSource = AvatarUploadService.normalizeAvatarStorageSource(
      (avatar ?? '').trim(),
    );
    final displaySource = await _resolveDisplaySource(storageSource);
    if (!mounted) return;

    setState(() {
      _avatarStorageSource = storageSource.isEmpty ? null : storageSource;
      _avatarSource = displaySource.isEmpty ? null : displaySource;
      _isLoading = false;
    });
  }

  Future<String> _resolveDisplaySource(String source) async {
    final normalizedSource = source.trim();
    if (normalizedSource.isEmpty) return '';

    try {
      final resolved = await _avatarUploadService.resolveAvatarDisplaySource(
        normalizedSource,
      );
      return AvatarUploadService.isRenderableImageSource(resolved)
          ? resolved
          : '';
    } catch (_) {
      final normalizedStorage =
          AvatarUploadService.normalizeAvatarStorageSource(normalizedSource);
      final fallback = AvatarUploadService.normalizeAvatarSource(
        normalizedStorage,
      );
      return AvatarUploadService.isRenderableImageSource(fallback)
          ? fallback
          : '';
    }
  }

  Future<void> _pickLocalAvatar() async {
    if (_isSaving) return;

    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (!mounted || picked == null) return;
      final path = await _pickAndCropAvatarImage(picked.path);
      if (!mounted || path == null) return;
      final normalizedPath = path.trim();
      if (normalizedPath.isEmpty) return;
      setState(() {
        _avatarStorageSource = normalizedPath;
        _avatarSource = normalizedPath;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('选择图片失败，请重试')));
    }
  }

  Future<String?> _pickAndCropAvatarImage(String sourcePath) async {
    final normalizedSource = sourcePath.trim();
    if (normalizedSource.isEmpty) return null;
    if (!_supportsNativeCropper()) {
      return normalizedSource;
    }

    try {
      final croppedPath = await _cropAvatarImage(normalizedSource);
      final normalizedCropped = croppedPath?.trim() ?? '';
      if (normalizedCropped.isEmpty) return null;
      return normalizedCropped;
    } catch (error, stackTrace) {
      debugPrint('crop avatar failed: $error\n$stackTrace');
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('头像裁剪失败，请重试')));
      return null;
    }
  }

  bool _supportsNativeCropper() {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<String?> _cropAvatarImage(String sourcePath) async {
    final uiSettings = <PlatformUiSettings>[];
    if (kIsWeb) {
      uiSettings.add(
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(width: 520, height: 520),
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      uiSettings.add(
        AndroidUiSettings(
          toolbarTitle: '裁剪头像',
          toolbarColor: const Color(0xFF2F663A),
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          hideBottomControls: false,
          initAspectRatio: CropAspectRatioPreset.square,
          cropStyle: CropStyle.circle,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      uiSettings.add(
        IOSUiSettings(
          title: '裁剪头像',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          cropStyle: CropStyle.circle,
        ),
      );
    }

    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 92,
      uiSettings: uiSettings,
    );
    final path = cropped?.path.trim();
    if (path == null || path.isEmpty) return null;
    return path;
  }

  Future<void> _save() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final source =
          _avatarStorageSource?.trim() ?? (_avatarSource?.trim() ?? '');
      var nextStorageSource = source;

      final looksLikeLocalFile = _looksLikeLocalFilePath(source);
      if (looksLikeLocalFile) {
        try {
          nextStorageSource = await _avatarUploadService.uploadAvatarAndSync(
            _normalizeLocalUploadPath(source),
          );
        } catch (error) {
          if (!mounted) return;
          final text = error.toString().trim();
          final detail = text.isEmpty ? '头像上传失败，请重试' : '头像上传失败：$text';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(detail)));
          return;
        }
      }

      final normalizedStorageSource =
          AvatarUploadService.normalizeAvatarStorageSource(nextStorageSource);
      if (looksLikeLocalFile && normalizedStorageSource.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('头像上传失败，请重试')));
        return;
      }
      final resolvedDisplaySource = await _resolveDisplaySource(
        normalizedStorageSource,
      );
      await _storageService.saveProfileAvatar(
        normalizedStorageSource.isEmpty ? null : normalizedStorageSource,
      );
      if (!mounted) return;

      setState(() {
        _avatarStorageSource = normalizedStorageSource.isEmpty
            ? null
            : normalizedStorageSource;
        final storageDisplayFallback =
            AvatarUploadService.isRenderableImageSource(normalizedStorageSource)
            ? normalizedStorageSource
            : null;
        _avatarSource = resolvedDisplaySource.isEmpty
            ? storageDisplayFallback
            : resolvedDisplaySource;
      });
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  bool _looksLikeLocalFilePath(String source) {
    final text = source.trim();
    if (text.isEmpty) return false;
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return false;
    }
    if (text.startsWith('assets/')) return false;
    if (text.startsWith('file://')) return true;
    final windowsPath = RegExp(r'^[a-zA-Z]:[\\/]');
    return text.startsWith('/') || windowsPath.hasMatch(text);
  }

  String _normalizeLocalUploadPath(String source) {
    final text = source.trim();
    if (!text.startsWith('file://')) return text;
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'file') return text;
    return uri.toFilePath();
  }

  Future<void> _useDefaultAvatar() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _storageService.saveProfileAvatar(null);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewSource = _avatarSource?.trim();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/auth/注册2-背景.png'),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 20,
              left: 5,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 80,
                  height: 30,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/auth/注册2-返回.png'),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 56),
                          const Text(
                            '修改头像',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E3A2A),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _AvatarPreview(imageSource: previewSource),
                          const SizedBox(height: 8),
                          const Text(
                            '点击选择本地照片，裁剪后保存立即生效',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: _isSaving ? null : _pickLocalAvatar,
                                icon: const Icon(Icons.photo_library_outlined),
                                label: const Text('从相册选择头像'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2E3A2A),
                                  side: const BorderSide(
                                    color: Color(0xFF90EE90),
                                  ),
                                  backgroundColor: const Color(0xFFE7F2E7),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _isSaving ? null : _useDefaultAvatar,
                            child: const Text('恢复默认头像'),
                          ),
                          const SizedBox(height: 14),
                          _ActionButton(
                            isLoading: _isSaving,
                            onTap: _save,
                            text: '',
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  final String text;

  const _ActionButton({
    required this.isLoading,
    required this.onTap,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: SizedBox(
        height: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/auth/注册2-完成.png'),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              child: SizedBox.expand(),
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  final String? imageSource;

  const _AvatarPreview({required this.imageSource});

  @override
  Widget build(BuildContext context) {
    final source = imageSource?.trim() ?? '';

    Widget child = const Icon(Icons.person, size: 42, color: Colors.white);
    if (source.isNotEmpty) {
      child = ClipOval(
        child: SizedBox(
          width: 84,
          height: 84,
          child: ResolvedImage(
            source: source,
            fit: BoxFit.cover,
            fallbackBuilder: (_) =>
                const Icon(Icons.person, size: 42, color: Colors.white),
          ),
        ),
      );
    }

    return Container(
      width: 94,
      height: 94,
      decoration: BoxDecoration(
        color: const Color(0xFFE7F2E7),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF90EE90), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: CircleAvatar(
          radius: 42,
          backgroundColor: const Color(0xFFC9C9C9),
          child: child,
        ),
      ),
    );
  }
}
