import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/city_code_name.dart';
import '../models/user.dart';
import '../services/avatar_upload_service.dart';
import '../services/auth_provider.dart';
import '../services/backend_api_client.dart';
import '../services/edited_postcard_service.dart';
import '../services/storage_service.dart';
import 'city_search_screen.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/resolved_image.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final BackendApiClient _apiClient = BackendApiClient();
  final StorageService _storageService = StorageService();
  final EditedPostcardService _editedPostcardService = EditedPostcardService();
  final AvatarUploadService _avatarUploadService = AvatarUploadService();

  String _username = '嘻嘻嘻';
  String? _avatarSource;
  String? _cityName;
  String? _cityCode;
  int _createdPostcardCount = 0;
  bool _isSavingCity = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final results = await Future.wait<dynamic>([
      _storageService.getUser(),
      _storageService.getProfileNickname(),
      _storageService.getProfileAvatar(),
      _storageService.getProfileCityName(),
      _storageService.getProfileCityCode(),
      _editedPostcardService.getEditedPostcards(),
    ]);
    final storedAvatar = AvatarUploadService.normalizeAvatarStorageSource(
      (results[2] as String?)?.trim() ?? '',
    );
    final displayAvatar = await _resolveAvatarDisplaySource(storedAvatar);

    if (!mounted) return;
    setState(() {
      final user = results[0] as User?;
      final nickname = (results[1] as String?)?.trim() ?? '';
      final cityName = results[3] as String?;
      final cityCode = results[4] as String?;
      final editedPostcards = results[5] as List<EditedPostcard>;
      final username = nickname.isNotEmpty
          ? nickname
          : (user?.username.trim() ?? '');
      _username = username.isEmpty ? '嘻嘻嘻' : username;
      final storedAvatarDisplay =
          AvatarUploadService.isRenderableImageSource(storedAvatar)
          ? storedAvatar
          : null;
      _avatarSource = displayAvatar.isEmpty
          ? storedAvatarDisplay
          : displayAvatar;
      _cityName = cityName;
      _cityCode = cityCode;
      _createdPostcardCount = editedPostcards.length;
    });

    await _syncProfileFromBackend();
  }

  Future<void> _syncProfileFromBackend() async {
    String? remoteCityName;
    String? remoteCityCode;
    String? remoteAvatarSource;

    try {
      final cityBody = await _apiClient.get('/me/city', requireAuth: true);
      remoteCityName = _extractCityName(cityBody);
      remoteCityCode = _extractCityCode(cityBody);
    } on BackendApiException catch (e) {
      if (e.isUnauthorized) {
        return;
      }
    } catch (_) {}

    try {
      final avatarBody = await _apiClient.get('/me/avatar', requireAuth: true);
      remoteAvatarSource = _extractAvatarSource(avatarBody);
    } on BackendApiException catch (e) {
      if (e.isUnauthorized) {
        return;
      }
    } catch (_) {}

    var normalizedCityName = remoteCityName?.trim();
    var resolvedCityCode = remoteCityCode?.trim();
    final normalizedAvatarStorage =
        AvatarUploadService.normalizeAvatarStorageSource(
          (remoteAvatarSource ?? '').trim(),
        );

    if ((resolvedCityCode == null || resolvedCityCode.isEmpty) &&
        normalizedCityName != null &&
        normalizedCityName.isNotEmpty) {
      resolvedCityCode = _findCityCodeByName(normalizedCityName);
    }
    if ((normalizedCityName == null || normalizedCityName.isEmpty) &&
        resolvedCityCode != null &&
        resolvedCityCode.isNotEmpty) {
      normalizedCityName = kCityCodeNames[resolvedCityCode]?.trim();
    }

    if (normalizedCityName != null && normalizedCityName.isNotEmpty) {
      if (resolvedCityCode != null) {
        await _storageService.saveProfileCity(
          cityName: normalizedCityName,
          cityCode: resolvedCityCode,
        );
      } else {
        await _storageService.saveProfileCityNameOnly(normalizedCityName);
        await _storageService.clearProfileCityCode();
      }
    }

    if (normalizedAvatarStorage.isNotEmpty) {
      await _storageService.saveProfileAvatar(normalizedAvatarStorage);
    }

    if (!mounted) return;
    final displayAvatar = await _resolveAvatarDisplaySource(
      normalizedAvatarStorage,
    );
    setState(() {
      if (normalizedCityName != null && normalizedCityName.isNotEmpty) {
        _cityName = normalizedCityName;
        _cityCode = resolvedCityCode;
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

  String? _extractCityName(Map<String, dynamic> body) {
    final data = BackendApiClient.extractData(body);
    final map = BackendApiClient.asMap(data) ?? body;

    final cityName = BackendApiClient.readString(map, const [
      'cityName',
      'city',
      'location',
      'address',
      'value',
    ]);
    if (cityName != null && cityName.trim().isNotEmpty) {
      return cityName.trim();
    }

    final cityCode = _extractCityCode(body);
    if (cityCode == null || cityCode.isEmpty) {
      return null;
    }
    return kCityCodeNames[cityCode]?.trim();
  }

  String? _extractCityCode(Map<String, dynamic> body) {
    final data = BackendApiClient.extractData(body);
    final map = BackendApiClient.asMap(data) ?? body;

    final codeText = BackendApiClient.readString(map, const [
      'cityCode',
      'code',
      'adCode',
      'value',
    ]);
    final codeInt = BackendApiClient.readInt(map, const [
      'cityCode',
      'code',
      'adCode',
      'value',
    ]);

    final raw = codeText ?? (codeInt?.toString() ?? '');
    final digits = raw.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return digits;
  }

  String? _extractAvatarSource(Map<String, dynamic> body) {
    final data = BackendApiClient.extractData(body);
    final map = BackendApiClient.asMap(data) ?? body;
    final avatar = BackendApiClient.readString(map, const [
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
    final text = avatar?.trim() ?? '';
    if (text.isEmpty) return null;
    return text;
  }

  String? _findCityCodeByName(String cityName) {
    final normalized = cityName.trim();
    if (normalized.isEmpty) return null;

    for (final entry in kCityCodeNames.entries) {
      final candidate = entry.value.trim();
      if (candidate == normalized) {
        return entry.key;
      }
    }

    for (final entry in kCityCodeNames.entries) {
      final candidate = entry.value.trim();
      if (candidate.isEmpty) continue;
      if (candidate.contains(normalized) || normalized.contains(candidate)) {
        return entry.key;
      }
    }

    return null;
  }

  Future<void> _openPostcardOverview() async {
    await Navigator.pushNamed(context, '/postcard_overview');
    if (!mounted) return;
    await _refreshCreatedPostcardCount();
  }

  Future<void> _refreshCreatedPostcardCount() async {
    final postcards = await _editedPostcardService.getEditedPostcards();
    if (!mounted) return;
    setState(() {
      _createdPostcardCount = postcards.length;
    });
  }

  Future<void> _openEditProfile() async {
    await Navigator.pushNamed(context, '/edit_profile');
    if (!mounted) return;
    await _loadProfileData();
  }

  Future<void> _selectCity() async {
    if (_isSavingCity) return;

    final selected = await Navigator.push<City>(
      context,
      MaterialPageRoute(
        builder: (_) => CitySearchScreen(selectedCity: _cityName),
      ),
    );

    if (!mounted || selected == null) return;

    setState(() {
      _isSavingCity = true;
    });

    var syncedRemote = false;
    try {
      final normalizedCode = selected.code.trim();
      await _apiClient.put(
        '/me/city',
        body: <String, dynamic>{
          'city': selected.name,
          'cityName': selected.name,
          'cityCode': normalizedCode,
        },
        requireAuth: true,
      );
      syncedRemote = true;
    } on BackendApiException catch (_) {
      syncedRemote = false;
    } catch (_) {
      syncedRemote = false;
    }

    try {
      await _storageService.saveProfileCity(
        cityName: selected.name,
        cityCode: selected.code,
      );
      if (!mounted) return;
      setState(() {
        _cityName = selected.name;
        _cityCode = selected.code;
        _isSavingCity = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            syncedRemote
                ? '已同步城市：${selected.name}'
                : '网络未同步，已更新本地城市：${selected.name}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSavingCity = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('城市更新失败，请重试')));
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cityLabel = _buildProvinceCityLabel();

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double maxWidth = constraints.maxWidth;
            final double contentWidth = (maxWidth - 24).clamp(320.0, 440.0);
            final double headerHeight = contentWidth * (236 / 440);
            final double rowWidth = contentWidth * (397 / 440);
            final double rowHeight = rowWidth * (48 / 397);

            return Center(
              child: SizedBox(
                width: contentWidth,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: contentWidth,
                        height: headerHeight,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                'assets/images/profile/用户-画面.png',
                                fit: BoxFit.fill,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                            Align(
                              alignment: const Alignment(0, -0.1),
                              child: _ProfileAvatar(
                                imageSource: _avatarSource,
                                size: 128,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _NameChip(width: 150, height: 40, text: _username),
                      const SizedBox(height: 22),
                      _ProfileMenuItem(
                        width: rowWidth,
                        height: rowHeight,
                        icon: Icons.location_city_outlined,
                        text: cityLabel,
                        onTap: _selectCity,
                      ),
                      const SizedBox(height: 16),
                      _ProfileMenuItem(
                        width: rowWidth,
                        height: rowHeight,
                        icon: Icons.brush_outlined,
                        text: '已创作：$_createdPostcardCount张明信片',
                        onTap: _openPostcardOverview,
                      ),
                      const SizedBox(height: 16),
                      _ProfileMenuItem(
                        width: rowWidth,
                        height: rowHeight,
                        icon: Icons.edit_outlined,
                        text: '编辑个人信息',
                        onTap: _openEditProfile,
                      ),
                      const SizedBox(height: 16),
                      _ProfileMenuItem(
                        width: rowWidth,
                        height: rowHeight,
                        icon: Icons.drafts_outlined,
                        text: '草稿箱',
                        onTap: () => Navigator.pushNamed(context, '/draft_box'),
                      ),
                      const SizedBox(height: 16),
                      _ProfileMenuItem(
                        width: rowWidth,
                        height: rowHeight,
                        icon: Icons.folder_open_outlined,
                        text: '收藏夹',
                        onTap: () => Navigator.pushNamed(context, '/favorites'),
                      ),
                      const SizedBox(height: 16),
                      _ProfileMenuItem(
                        width: rowWidth,
                        height: rowHeight,
                        icon: Icons.thumb_up_alt_outlined,
                        text: '点赞帖子',
                        onTap: () => Navigator.pushNamed(context, '/liked_posts'),
                      ),
                      const SizedBox(height: 16),
                      _ProfileMenuItem(
                        width: rowWidth,
                        height: rowHeight,
                        icon: Icons.logout_outlined,
                        text: _isLoggingOut ? '退出登录中...' : '退出登录',
                        onTap: _logout,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentTab: AppTab.profile,
        backgroundColor: const Color(0xFFE7E7E7),
        onHomeTap: () {
          Navigator.pushNamed(context, '/home');
        },
        onMapTap: () {
          Navigator.pushNamed(context, '/map');
        },
        onCommentTap: () {
          Navigator.pushNamed(context, '/comment_section');
        },
        onProfileTap: () {
          debugPrint('当前在我的');
        },
      ),
    );
  }

  String _buildProvinceCityLabel() {
    if (_isSavingCity) return '城市：保存中...';

    final province = _resolveProvinceName(_cityCode);
    final city = _resolveCityName(_cityName, _cityCode);

    if ((province == null || province.isEmpty) &&
        (city == null || city.isEmpty)) {
      return '城市：未设置';
    }
    if (province == null || province.isEmpty) {
      return '城市：$city';
    }
    if (city == null || city.isEmpty) {
      return '城市：$province';
    }
    if (province == city) {
      return '城市：$city';
    }

    return '城市：$province $city';
  }

  String? _resolveCityName(String? cityName, String? cityCode) {
    final name = cityName?.trim() ?? '';
    if (name.isNotEmpty) return name;

    final code = cityCode?.trim() ?? '';
    if (code.isEmpty) return null;
    return kCityCodeNames[code];
  }

  String? _resolveProvinceName(String? cityCode) {
    final code = cityCode?.trim() ?? '';
    if (code.length < 2) return null;

    final prefix = code.substring(0, 2);
    return _provinceNameByPrefix[prefix];
  }
}

const Map<String, String> _provinceNameByPrefix = {
  '11': '北京市',
  '12': '天津市',
  '13': '河北省',
  '14': '山西省',
  '15': '内蒙古自治区',
  '21': '辽宁省',
  '22': '吉林省',
  '23': '黑龙江省',
  '31': '上海市',
  '32': '江苏省',
  '33': '浙江省',
  '34': '安徽省',
  '35': '福建省',
  '36': '江西省',
  '37': '山东省',
  '41': '河南省',
  '42': '湖北省',
  '43': '湖南省',
  '44': '广东省',
  '45': '广西壮族自治区',
  '46': '海南省',
  '50': '重庆市',
  '51': '四川省',
  '52': '贵州省',
  '53': '云南省',
  '54': '西藏自治区',
  '61': '陕西省',
  '62': '甘肃省',
  '63': '青海省',
  '64': '宁夏回族自治区',
  '65': '新疆维吾尔自治区',
  '71': '台湾省',
  '81': '香港特别行政区',
  '82': '澳门特别行政区',
};

class _NameChip extends StatelessWidget {
  final double width;
  final double height;
  final String text;

  const _NameChip({
    required this.width,
    required this.height,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFD0D9C4),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20 / 1.8,
          color: Color(0xFF5F685F),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? imageSource;
  final double size;

  const _ProfileAvatar({required this.imageSource, required this.size});

  @override
  Widget build(BuildContext context) {
    final source = imageSource?.trim() ?? '';
    final radius = size / 2;

    if (source.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFC9C9C9),
        child: Icon(Icons.person, size: size * 0.46, color: Colors.white),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFC9C9C9),
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: ResolvedImage(
            source: source,
            fit: BoxFit.cover,
            fallbackBuilder: (_) =>
                Icon(Icons.person, size: size * 0.46, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final double width;
  final double height;
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _ProfileMenuItem({
    required this.width,
    required this.height,
    required this.icon,
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: const Color(0xFFD9DDD2),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x20000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 34, color: Colors.black87),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 32 / 3,
                  color: Color(0xFF4C5450),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 18),
            const Icon(Icons.chevron_right, size: 28, color: Color(0xFF7D817D)),
          ],
        ),
      ),
    );
  }
}
