import 'package:flutter/material.dart';

import '../data/city_code_name.dart';
import '../models/user.dart';
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
  final StorageService _storageService = StorageService();
  final EditedPostcardService _editedPostcardService = EditedPostcardService();

  String _username = '鍢诲樆鍢?;
  String? _avatarSource;
  String? _cityName;
  String? _cityCode;
  int _createdPostcardCount = 0;
  bool _isSavingCity = false;

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

    if (!mounted) return;
    setState(() {
      final user = results[0] as User?;
      final nickname = (results[1] as String?)?.trim() ?? '';
      final avatarSource = (results[2] as String?)?.trim();
      final cityName = results[3] as String?;
      final cityCode = results[4] as String?;
      final editedPostcards = results[5] as List<EditedPostcard>;
      final username = nickname.isNotEmpty
          ? nickname
          : (user?.username.trim() ?? '');
      _username = username.isEmpty ? '鍢诲樆鍢? : username;
      _avatarSource = (avatarSource == null || avatarSource.isEmpty)
          ? null
          : avatarSource;
      _cityName = cityName;
      _cityCode = cityCode;
      _createdPostcardCount = editedPostcards.length;
    });
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('宸叉洿鏂板煄甯傦細${selected.name}')));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSavingCity = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('鍩庡競鏇存柊澶辫触锛岃閲嶈瘯')));
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
                                'assets/images/profile/鐢ㄦ埛-鐢婚潰.png',
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
                        text: '宸插垱浣滐細$_createdPostcardCount寮犳槑淇＄墖',
                        onTap: _openPostcardOverview,
                      ),
                      const SizedBox(height: 16),
                      _ProfileMenuItem(
                        width: rowWidth,
                        height: rowHeight,
                        icon: Icons.edit_outlined,
                        text: '缂栬緫涓汉淇℃伅',
                        onTap: _openEditProfile,
                      ),
                      const SizedBox(height: 16),
                      _ProfileMenuItem(
                        width: rowWidth,
                        height: rowHeight,
                        icon: Icons.drafts_outlined,
                        text: '鑽夌绠?,
                        onTap: () => Navigator.pushNamed(context, '/draft_box'),
                      ),
                      const SizedBox(height: 16),
                      _ProfileMenuItem(
                        width: rowWidth,
                        height: rowHeight,
                        icon: Icons.folder_open_outlined,
                        text: '鏀惰棌澶?,
                        onTap: () => Navigator.pushNamed(context, '/favorites'),
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
          debugPrint('褰撳墠鍦ㄦ垜鐨?);
        },
      ),
    );
  }

  String _buildProvinceCityLabel() {
    if (_isSavingCity) return '鍩庡競锛氫繚瀛樹腑...';

    final province = _resolveProvinceName(_cityCode);
    final city = _resolveCityName(_cityName, _cityCode);

    if ((province == null || province.isEmpty) &&
        (city == null || city.isEmpty)) {
      return '鍩庡競锛氭湭璁剧疆';
    }
    if (province == null || province.isEmpty) {
      return '鍩庡競锛?city';
    }
    if (city == null || city.isEmpty) {
      return '鍩庡競锛?province';
    }
    if (province == city) {
      return '鍩庡競锛?city';
    }

    return '鍩庡競锛?province $city';
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
  '11': '鍖椾含甯?,
  '12': '澶╂触甯?,
  '13': '娌冲寳鐪?,
  '14': '灞辫タ鐪?,
  '15': '鍐呰挋鍙よ嚜娌诲尯',
  '21': '杈藉畞鐪?,
  '22': '鍚夋灄鐪?,
  '23': '榛戦緳姹熺渷',
  '31': '涓婃捣甯?,
  '32': '姹熻嫃鐪?,
  '33': '娴欐睙鐪?,
  '34': '瀹夊窘鐪?,
  '35': '绂忓缓鐪?,
  '36': '姹熻タ鐪?,
  '37': '灞变笢鐪?,
  '41': '娌冲崡鐪?,
  '42': '婀栧寳鐪?,
  '43': '婀栧崡鐪?,
  '44': '骞夸笢鐪?,
  '45': '骞胯タ澹棌鑷不鍖?,
  '46': '娴峰崡鐪?,
  '50': '閲嶅簡甯?,
  '51': '鍥涘窛鐪?,
  '52': '璐靛窞鐪?,
  '53': '浜戝崡鐪?,
  '54': '瑗胯棌鑷不鍖?,
  '61': '闄曡タ鐪?,
  '62': '鐢樿們鐪?,
  '63': '闈掓捣鐪?,
  '64': '瀹佸鍥炴棌鑷不鍖?,
  '65': '鏂扮枂缁村惥灏旇嚜娌诲尯',
  '71': '鍙版咕鐪?,
  '81': '棣欐腐鐗瑰埆琛屾斂鍖?,
  '82': '婢抽棬鐗瑰埆琛屾斂鍖?,
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
