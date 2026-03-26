import 'package:flutter/material.dart';

import '../services/avatar_upload_service.dart';
import '../services/backend_api_client.dart';
import '../services/storage_service.dart';
import '../widgets/resolved_image.dart';
import 'edit_profile_avatar_screen.dart';
import 'edit_profile_nickname_screen.dart';
import 'edit_profile_password_screen.dart';
import 'edit_profile_phone_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final StorageService _storageService = StorageService();
  final AvatarUploadService _avatarUploadService = AvatarUploadService();
  final BackendApiClient _apiClient = BackendApiClient();

  bool _isLoading = true;
  String _nickname = '用户';
  String _phone = '';
  String? _avatarSource;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    final results = await Future.wait<dynamic>([
      _storageService.getProfileNickname(),
      _storageService.getProfilePhone(),
      _storageService.getProfileAvatar(),
    ]);
    final storedAvatar = AvatarUploadService.normalizeAvatarStorageSource(
      (results[2] as String?)?.trim() ?? '',
    );
    final displayAvatar = await _resolveAvatarDisplaySource(storedAvatar);

    if (!mounted) return;
    setState(() {
      final nickname = (results[0] as String?)?.trim() ?? '';
      _nickname = nickname.isEmpty ? '用户' : nickname;
      _phone = ((results[1] as String?) ?? '').trim();
      final storedAvatarDisplay =
          AvatarUploadService.isRenderableImageSource(storedAvatar)
          ? storedAvatar
          : null;
      _avatarSource = displayAvatar.isEmpty
          ? storedAvatarDisplay
          : displayAvatar;
      _isLoading = false;
    });

    await _syncProfileFromBackend();
  }

  Future<void> _syncProfileFromBackend() async {
    String? remoteNickname;
    String? remoteAvatarSource;

    try {
      final pingBody = await _apiClient.get('/ping/auth', requireAuth: true);
      remoteNickname = _extractNicknameFromAuthPing(pingBody);
    } catch (_) {}

    try {
      final avatarBody = await _apiClient.get('/me/avatar', requireAuth: true);
      remoteAvatarSource = _extractAvatarSource(avatarBody);
    } catch (_) {}

    final normalizedNickname = remoteNickname?.trim() ?? '';
    final normalizedAvatarStorage =
        AvatarUploadService.normalizeAvatarStorageSource(
          (remoteAvatarSource ?? '').trim(),
        );
    if (normalizedNickname.isNotEmpty) {
      await _storageService.saveProfileNickname(normalizedNickname);
    }
    if (normalizedAvatarStorage.isNotEmpty) {
      await _storageService.saveProfileAvatar(normalizedAvatarStorage);
    }

    if (!mounted) return;
    final displayAvatar = await _resolveAvatarDisplaySource(
      normalizedAvatarStorage,
    );
    setState(() {
      if (normalizedNickname.isNotEmpty) {
        _nickname = normalizedNickname;
      }
      if (displayAvatar.isNotEmpty) {
        _avatarSource = displayAvatar;
      } else if (AvatarUploadService.isRenderableImageSource(
        normalizedAvatarStorage,
      )) {
        _avatarSource = normalizedAvatarStorage;
      }
    });
  }

  String? _extractNicknameFromAuthPing(Map<String, dynamic> body) {
    final data = BackendApiClient.extractData(body);
    final candidates = <String>[
      body['msg']?.toString() ?? '',
      body['message']?.toString() ?? '',
      if (data is String) data,
    ];

    for (final item in candidates) {
      final parsed = _parseNicknameFromPingMessage(item);
      if (parsed != null && parsed.isNotEmpty) {
        return parsed;
      }
    }
    return null;
  }

  String? _parseNicknameFromPingMessage(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final matched = RegExp(
      r'auth\s+ping\s+success,\s*\S+\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (matched != null) {
      final nickname = matched.group(1)?.trim() ?? '';
      if (nickname.isNotEmpty) return nickname;
    }

    final commaIndex = text.lastIndexOf(',');
    if (commaIndex >= 0 && commaIndex < text.length - 1) {
      final tail = text.substring(commaIndex + 1).trim();
      final parts = tail
          .split(RegExp(r'\s+'))
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false);
      if (parts.length >= 2) {
        final nickname = parts.sublist(1).join(' ').trim();
        if (nickname.isNotEmpty) return nickname;
      }
    }

    if (text.toLowerCase().contains('auth ping success')) {
      return null;
    }
    return text;
  }

  String? _extractAvatarSource(Map<String, dynamic> body) {
    final data = BackendApiClient.extractData(body);
    if (data is String) {
      final text = data.trim();
      if (text.isNotEmpty) return text;
    }

    final map = BackendApiClient.asMap(data) ?? body;
    return BackendApiClient.readString(map, const <String>[
      'avatarUrl',
      'avatar',
      'avatarKey',
      'key',
      'objectKey',
      'fileKey',
      'path',
      'url',
      'value',
    ]);
  }

  Future<String> _resolveAvatarDisplaySource(String source) async {
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

  Future<void> _openAvatarEdit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileAvatarScreen()),
    );
    if (!mounted || updated != true) return;
    await _loadProfile();
  }

  Future<void> _openNicknameEdit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileNicknameScreen()),
    );
    if (!mounted || updated != true) return;
    await _loadProfile();
  }

  Future<void> _openPhoneEdit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePhoneScreen()),
    );
    if (!mounted || updated != true) return;
    await _loadProfile();
  }

  Future<void> _openPasswordEdit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePasswordScreen()),
    );
    if (!mounted || updated != true) return;
    await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
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
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final maxWidth = constraints.maxWidth;
                        final rowWidth = (maxWidth - 20).clamp(0.0, 320.0);

                        return Center(
                          child: SizedBox(
                            width: rowWidth,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(
                                top: 26,
                                bottom: 20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    '编辑个人信息',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2E3A2A),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  GestureDetector(
                                    onTap: _openAvatarEdit,
                                    child: Container(
                                      width: 94,
                                      height: 94,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE7F2E7),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF90EE90),
                                          width: 1.2,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x14000000),
                                            blurRadius: 10,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: _InlineAvatar(
                                          imageSource: _avatarSource,
                                          radius: 42,
                                          iconSize: 34,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    '点击头像可修改',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 26),
                                  _EditProfileItem(
                                    width: rowWidth,
                                    icon: Icons.account_circle_outlined,
                                    text: '头像',
                                    value: '进入修改',
                                    valueWidget: _InlineAvatar(
                                      imageSource: _avatarSource,
                                      radius: 14,
                                      iconSize: 16,
                                    ),
                                    onTap: _openAvatarEdit,
                                  ),
                                  const SizedBox(height: 14),
                                  _EditProfileItem(
                                    width: rowWidth,
                                    icon: Icons.person_outline,
                                    text: '用户名',
                                    value: _nickname,
                                    onTap: _openNicknameEdit,
                                  ),
                                  const SizedBox(height: 14),
                                  _EditProfileItem(
                                    width: rowWidth,
                                    icon: Icons.phone,
                                    text: '手机号',
                                    value: _maskPhone(_phone),
                                    onTap: _openPhoneEdit,
                                  ),
                                  const SizedBox(height: 14),
                                  _EditProfileItem(
                                    width: rowWidth,
                                    icon: Icons.lock_outline,
                                    text: '密码',
                                    value: '进入修改',
                                    onTap: _openPasswordEdit,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _maskPhone(String phone) {
    final normalized = phone.trim();
    if (normalized.isEmpty) return '未设置';
    if (normalized.length != 11) return normalized;
    return '${normalized.substring(0, 3)}****${normalized.substring(7)}';
  }
}

class _EditProfileItem extends StatelessWidget {
  final double width;
  final IconData icon;
  final String text;
  final String value;
  final Widget? valueWidget;
  final VoidCallback onTap;

  const _EditProfileItem({
    required this.width,
    required this.icon,
    required this.text,
    required this.value,
    this.valueWidget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Container(
        width: width,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 231, 242, 231),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF90EE90), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF3D4B3A),
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (valueWidget != null) ...[
              valueWidget!,
              const SizedBox(width: 10),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF4C5450),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}

class _InlineAvatar extends StatelessWidget {
  final String? imageSource;
  final double radius;
  final double iconSize;

  const _InlineAvatar({
    required this.imageSource,
    this.radius = 14,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final source = imageSource?.trim() ?? '';
    if (source.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFC9C9C9),
        child: Icon(Icons.person, color: Colors.white, size: iconSize),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFC9C9C9),
      child: ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: ResolvedImage(
            source: source,
            fit: BoxFit.cover,
            fallbackBuilder: (_) =>
                Icon(Icons.person, color: Colors.white, size: iconSize),
          ),
        ),
      ),
    );
  }
}
