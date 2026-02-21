import 'package:flutter/material.dart';
import 'package:interactive_country_map/interactive_country_map.dart';

import '../data/city_code_center.dart';
import '../services/edited_postcard_service.dart';
import '../widgets/app_bottom_nav_bar.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String _headerAsset = 'assets/images/map/地图.png';

  final EditedPostcardService _editedPostcardService = EditedPostcardService();

  bool _isLoading = true;
  Set<String> _litProvinceCodes = const {};
  Map<String, List<_CitySpot>> _citySpotsByProvince = const {};
  List<_CitySpot> _citySpots = const [];
  String? _selectedProvinceCode;

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  Future<void> _loadMapData() async {
    setState(() => _isLoading = true);
    final postcards = await _editedPostcardService.getEditedPostcards();

    final litProvinces = <String>{};
    final latestByProvinceCity = <String, _CitySpot>{};

    for (final card in postcards) {
      final provinceCode = _resolveProvinceCode(
        provinceName: card.provinceName,
        cityName: card.cityName,
        cityCode: card.cityCode,
      );
      if (provinceCode == null) continue;
      litProvinces.add(provinceCode);

      final cityLabel = _resolveCityLabel(
        cityName: card.cityName,
        cityCode: card.cityCode,
      );
      final cityCode = _normalizeCityCode(card.cityCode);
      final coordinate = _resolveCityCoordinate(
        cityCode: cityCode,
        latitude: card.latitude,
        longitude: card.longitude,
      );

      final spot = _CitySpot(
        provinceCode: provinceCode,
        cityLabel: cityLabel,
        cityCode: cityCode,
        latitude: coordinate?.latitude,
        longitude: coordinate?.longitude,
        editedAt: card.editedAt,
      );

      final dedupeKey =
          '${spot.provinceCode}_${spot.cityCode ?? spot.cityLabel}';
      final current = latestByProvinceCity[dedupeKey];
      if (current == null || spot.editedAt.isAfter(current.editedAt)) {
        latestByProvinceCity[dedupeKey] = spot;
      }
    }

    final citySpotsByProvince = <String, List<_CitySpot>>{};
    for (final spot in latestByProvinceCity.values) {
      citySpotsByProvince.putIfAbsent(spot.provinceCode, () => []).add(spot);
    }
    for (final list in citySpotsByProvince.values) {
      list.sort((a, b) => b.editedAt.compareTo(a.editedAt));
    }

    final allSpots = latestByProvinceCity.values.toList()
      ..sort((a, b) => b.editedAt.compareTo(a.editedAt));

    if (!mounted) return;
    setState(() {
      _litProvinceCodes = litProvinces;
      _citySpotsByProvince = citySpotsByProvince;
      _citySpots = allSpots;
      _selectedProvinceCode = litProvinces.contains(_selectedProvinceCode)
          ? _selectedProvinceCode
          : null;
      _isLoading = false;
    });
  }

  bool _isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  CityCoordinate? _resolveCityCoordinate({
    required String? cityCode,
    required double? latitude,
    required double? longitude,
  }) {
    if (_isValidCoordinate(latitude, longitude)) {
      return CityCoordinate(longitude!, latitude!);
    }
    if (cityCode == null) return null;
    return kCityCodeCoordinates[cityCode];
  }

  String? _resolveProvinceCode({
    String? provinceName,
    String? cityName,
    String? cityCode,
  }) {
    final normalizedProvince = _normalizeProvinceName(provinceName);
    if (normalizedProvince != null) {
      final byProvince = _provinceCodeByName[normalizedProvince];
      if (byProvince != null) return byProvince;
    }

    final byCityCode = _provinceCodeFromCityCode(cityCode);
    if (byCityCode != null) return byCityCode;

    final normalizedCity = _normalizeCityName(cityName);
    if (normalizedCity != null) {
      final province = _provinceByCity[normalizedCity];
      if (province != null) {
        return _provinceCodeByName[province];
      }
    }
    return null;
  }

  String? _provinceCodeFromCityCode(String? cityCode) {
    final normalized = _normalizeCityCode(cityCode);
    if (normalized == null || normalized.length < 2) return null;
    final provincePrefix = normalized.substring(0, 2);
    return _provinceCodeByCityPrefix[provincePrefix];
  }

  String _resolveCityLabel({String? cityName, String? cityCode}) {
    final normalizedCity = _normalizeCityName(cityName);
    if (normalizedCity != null && normalizedCity.isNotEmpty) {
      return normalizedCity;
    }
    final normalizedCityCode = _normalizeCityCode(cityCode);
    if (normalizedCityCode != null) {
      return '代码$normalizedCityCode';
    }
    return '未知城市';
  }

  String? _normalizeProvinceName(String? raw) {
    if (raw == null) return null;
    var text = raw.trim();
    if (text.isEmpty) return null;

    final alias = _provinceAlias[text];
    if (alias != null) return alias;

    const suffixes = ['特别行政区', '壮族自治区', '回族自治区', '维吾尔自治区', '自治区', '省', '市'];

    for (final suffix in suffixes) {
      if (text.endsWith(suffix) && text.length > suffix.length) {
        text = text.substring(0, text.length - suffix.length);
        break;
      }
    }

    return _provinceAlias[text] ?? text;
  }

  String? _normalizeCityName(String? raw) {
    if (raw == null) return null;
    var text = raw.trim();
    if (text.isEmpty) return null;

    const suffixes = ['自治州', '地区', '省直辖县级行政区划', '省直辖行政单位', '盟', '市'];

    for (final suffix in suffixes) {
      if (text.endsWith(suffix) && text.length > suffix.length) {
        text = text.substring(0, text.length - suffix.length);
        break;
      }
    }

    return text;
  }

  String? _normalizeCityCode(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return digits;
  }

  Map<String, Color> _buildProvinceColorMap() {
    return {
      for (final code in _litProvinceCodes) code: const Color(0xFFFFD86A),
    };
  }

  List<MarkerGroup> _buildMarkerGroups() {
    final selected = _selectedProvinceCode;
    final source = selected == null
        ? _citySpots
        : (_citySpotsByProvince[selected] ?? const <_CitySpot>[]);

    final markersToDraw = source
        .where((e) => e.hasCoordinate)
        .take(80)
        .toList();
    if (markersToDraw.isEmpty) return const [];

    return [
      MarkerGroup(
        usePinMarker: true,
        markers: [
          for (final spot in markersToDraw)
            GeoMarker(lat: spot.latitude!, long: spot.longitude!),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sortedProvinceCodes = _litProvinceCodes.toList()
      ..sort((a, b) {
        final aName = _provinceNameByCode[a] ?? a;
        final bName = _provinceNameByCode[b] ?? b;
        return aName.compareTo(bName);
      });

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildHeader(),
            const SizedBox(height: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildMapCard(),
              ),
            ),
            const SizedBox(height: 10),
            _buildSummary(
              provinceCount: sortedProvinceCodes.length,
              cityCount: _citySpots.length,
            ),
            const SizedBox(height: 8),
            _buildProvinceChips(sortedProvinceCodes),
            const SizedBox(height: 8),
            _buildCityChips(),
            const SizedBox(height: 12),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentTab: AppTab.map,
        backgroundColor: Colors.white,
        onHomeTap: () => Navigator.pushReplacementNamed(context, '/home'),
        onMapTap: () {},
        onCommentTap: () =>
            Navigator.pushReplacementNamed(context, '/comment_section'),
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 56,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Image.asset(
              _headerAsset,
              height: 40,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => const Text(
                '地图',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E2430),
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: IconButton(
              onPressed: _isLoading ? null : _loadMapData,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: '刷新地图',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard() {
    return Container(
      decoration: BoxDecoration(
        //地图卡片底色
        color: const Color(0xFF3A3F47),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E7EF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: InteractiveMap(
                MapEntity.china,
                selectedCode: _selectedProvinceCode,
                onCountrySelected: (code) {
                  setState(() {
                    _selectedProvinceCode = _selectedProvinceCode == code
                        ? null
                        : code;
                  });
                },
                markers: _buildMarkerGroups(),
                theme: InteractiveMapTheme(
                  // 省份默认颜色
                  defaultCountryColor: const Color.fromARGB(255, 170, 172, 174),
                  defaultSelectedCountryColor: const Color(0xFF88B6FF),
                  borderColor: Colors.white,
                  borderWidth: 1.2,
                  selectedBorderWidth: 1.8,
                  // 地图主题背景
                  backgroundColor: const Color(0xFF3A3F47),
                  mappingCode: _buildProvinceColorMap(),
                ),
                loadingBuilder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              ),
            ),
            if (_isLoading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x99FFFFFF),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary({required int provinceCount, required int cityCount}) {
    final selectedProvinceCode = _selectedProvinceCode;
    final selectedProvinceName = selectedProvinceCode == null
        ? null
        : _provinceNameByCode[selectedProvinceCode];
    final selectedProvinceCityCount = selectedProvinceCode == null
        ? 0
        : (_citySpotsByProvince[selectedProvinceCode]?.length ?? 0);

    final text = _isLoading
        ? '正在读取已编辑明信片地点...'
        : selectedProvinceName != null
        ? '当前选中：$selectedProvinceName，已标注 $selectedProvinceCityCount 个城市'
        : '已点亮 $provinceCount 个省份，标注 $cityCount 个城市';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E4EA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.map_outlined, size: 18, color: Color(0xFF4A5667)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2B3140),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvinceChips(List<String> provinceCodes) {
    if (provinceCodes.isEmpty) {
      return const SizedBox(
        height: 34,
        child: Center(
          child: Text(
            '暂无点亮省份',
            style: TextStyle(fontSize: 12, color: Color(0xFF7A8291)),
          ),
        ),
      );
    }

    return SizedBox(
      height: 34,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: provinceCodes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final code = provinceCodes[index];
          final name = _provinceNameByCode[code] ?? code;
          final selected = code == _selectedProvinceCode;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedProvinceCode = selected ? null : code;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFFFE8A3)
                    : const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFFFB300)
                      : const Color(0xFFFFD54F),
                ),
              ),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7A4C00),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCityChips() {
    final selectedCode = _selectedProvinceCode;
    final selectedProvinceName = selectedCode == null
        ? null
        : _provinceNameByCode[selectedCode];
    final spots = selectedCode == null
        ? _citySpots.take(24).toList()
        : (_citySpotsByProvince[selectedCode] ?? const <_CitySpot>[]);

    if (spots.isEmpty) {
      return const SizedBox(
        height: 34,
        child: Center(
          child: Text(
            '暂无城市标注',
            style: TextStyle(fontSize: 12, color: Color(0xFF7A8291)),
          ),
        ),
      );
    }

    final title = selectedProvinceName == null
        ? '已标注城市'
        : '$selectedProvinceName 城市';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4C5667),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: spots.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final spot = spots[index];
              final cityName = selectedProvinceName == null
                  ? '${_provinceNameByCode[spot.provinceCode] ?? spot.provinceCode}-${spot.cityLabel}'
                  : spot.cityLabel;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFBBD2FF)),
                ),
                child: Text(
                  cityName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF284B8D),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CitySpot {
  final String provinceCode;
  final String cityLabel;
  final String? cityCode;
  final double? latitude;
  final double? longitude;
  final DateTime editedAt;

  const _CitySpot({
    required this.provinceCode,
    required this.cityLabel,
    required this.cityCode,
    required this.latitude,
    required this.longitude,
    required this.editedAt,
  });

  bool get hasCoordinate => latitude != null && longitude != null;
}

const Map<String, String> _provinceCodeByName = {
  '北京': 'CN-11',
  '天津': 'CN-12',
  '河北': 'CN-13',
  '山西': 'CN-14',
  '内蒙古': 'CN-15',
  '辽宁': 'CN-21',
  '吉林': 'CN-22',
  '黑龙江': 'CN-23',
  '上海': 'CN-31',
  '江苏': 'CN-32',
  '浙江': 'CN-33',
  '安徽': 'CN-34',
  '福建': 'CN-35',
  '江西': 'CN-36',
  '山东': 'CN-37',
  '河南': 'CN-41',
  '湖北': 'CN-42',
  '湖南': 'CN-43',
  '广东': 'CN-44',
  '广西': 'CN-45',
  '海南': 'CN-46',
  '重庆': 'CN-50',
  '四川': 'CN-51',
  '贵州': 'CN-52',
  '云南': 'CN-53',
  '西藏': 'CN-54',
  '陕西': 'CN-61',
  '甘肃': 'CN-62',
  '青海': 'CN-63',
  '宁夏': 'CN-64',
  '新疆': 'CN-65',
  '台湾': 'CN-71',
  '香港': 'CN-91',
  '澳门': 'CN-92',
};

const Map<String, String> _provinceCodeByCityPrefix = {
  '11': 'CN-11',
  '12': 'CN-12',
  '13': 'CN-13',
  '14': 'CN-14',
  '15': 'CN-15',
  '21': 'CN-21',
  '22': 'CN-22',
  '23': 'CN-23',
  '31': 'CN-31',
  '32': 'CN-32',
  '33': 'CN-33',
  '34': 'CN-34',
  '35': 'CN-35',
  '36': 'CN-36',
  '37': 'CN-37',
  '41': 'CN-41',
  '42': 'CN-42',
  '43': 'CN-43',
  '44': 'CN-44',
  '45': 'CN-45',
  '46': 'CN-46',
  '50': 'CN-50',
  '51': 'CN-51',
  '52': 'CN-52',
  '53': 'CN-53',
  '54': 'CN-54',
  '61': 'CN-61',
  '62': 'CN-62',
  '63': 'CN-63',
  '64': 'CN-64',
  '65': 'CN-65',
  '71': 'CN-71',
  '81': 'CN-91',
  '82': 'CN-92',
  '91': 'CN-91',
  '92': 'CN-92',
};

const Map<String, String> _provinceNameByCode = {
  'CN-11': '北京',
  'CN-12': '天津',
  'CN-13': '河北',
  'CN-14': '山西',
  'CN-15': '内蒙古',
  'CN-21': '辽宁',
  'CN-22': '吉林',
  'CN-23': '黑龙江',
  'CN-31': '上海',
  'CN-32': '江苏',
  'CN-33': '浙江',
  'CN-34': '安徽',
  'CN-35': '福建',
  'CN-36': '江西',
  'CN-37': '山东',
  'CN-41': '河南',
  'CN-42': '湖北',
  'CN-43': '湖南',
  'CN-44': '广东',
  'CN-45': '广西',
  'CN-46': '海南',
  'CN-50': '重庆',
  'CN-51': '四川',
  'CN-52': '贵州',
  'CN-53': '云南',
  'CN-54': '西藏',
  'CN-61': '陕西',
  'CN-62': '甘肃',
  'CN-63': '青海',
  'CN-64': '宁夏',
  'CN-65': '新疆',
  'CN-71': '台湾',
  'CN-91': '香港',
  'CN-92': '澳门',
};

const Map<String, String> _provinceAlias = {
  '内蒙古自治区': '内蒙古',
  '西藏自治区': '西藏',
  '广西壮族自治区': '广西',
  '宁夏回族自治区': '宁夏',
  '新疆维吾尔自治区': '新疆',
  '香港特别行政区': '香港',
  '澳门特别行政区': '澳门',
  '台湾省': '台湾',
  '广西壮族': '广西',
  '宁夏回族': '宁夏',
  '新疆维吾尔': '新疆',
};

const Map<String, String> _provinceByCity = {
  '北京': '北京',
  '天津': '天津',
  '上海': '上海',
  '重庆': '重庆',
  '广州': '广东',
  '深圳': '广东',
  '珠海': '广东',
  '东莞': '广东',
  '佛山': '广东',
  '杭州': '浙江',
  '宁波': '浙江',
  '南京': '江苏',
  '苏州': '江苏',
  '成都': '四川',
  '武汉': '湖北',
  '西安': '陕西',
  '长沙': '湖南',
  '郑州': '河南',
  '济南': '山东',
  '青岛': '山东',
  '厦门': '福建',
  '福州': '福建',
  '昆明': '云南',
  '贵阳': '贵州',
  '南宁': '广西',
  '海口': '海南',
  '三亚': '海南',
  '乌鲁木齐': '新疆',
  '拉萨': '西藏',
  '呼和浩特': '内蒙古',
  '沈阳': '辽宁',
  '长春': '吉林',
  '哈尔滨': '黑龙江',
  '合肥': '安徽',
  '南昌': '江西',
  '石家庄': '河北',
  '太原': '山西',
  '兰州': '甘肃',
  '西宁': '青海',
  '银川': '宁夏',
  '台北': '台湾',
  '高雄': '台湾',
  '香港': '香港',
  '澳门': '澳门',
};
