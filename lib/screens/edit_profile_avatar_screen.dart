import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/backend_api_client.dart';
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
  final BackendApiClient _apiClient = BackendApiClient();
  final ImagePicker _imagePicker = ImagePicker();

  String? _avatarSource;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final avatar = await _storageService.getProfileAvatar();
    if (!mounted) return;

    setState(() {
      _avatarSource = (avatar ?? '').trim();
      _isLoading = false;
    });
  }

  Future<void> _pickLocalAvatar() async {
    if (_isSaving) return;

    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (!mounted || picked == null) return;
      final path = picked.path.trim();
      if (path.isEmpty) return;
      setState(() {
        _avatarSource = path;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('选择图片失败，请重试')));
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final source = _avatarSource?.trim() ?? '';
      var syncedRemote = false;

      final looksLikeLocalFile =
          source.isNotEmpty &&
          !source.startsWith('http://') &&
          !source.startsWith('https://');
      if (looksLikeLocalFile) {
        try {
          await _apiClient.putMultipartFile(
            '/me/avatar',
            fieldName: 'avatar',
            filePath: source,
            requireAuth: true,
          );
          syncedRemote = true;
        } catch (_) {
          syncedRemote = false;
        }
      }

      await _storageService.saveProfileAvatar(source.isEmpty ? null : source);
      if (!mounted) return;

      if (!syncedRemote && looksLikeLocalFile) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('头像未同步到服务器，已保存本地头像')));
      }

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
                            '点击选择本地照片，保存后立即生效',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: 300,
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
