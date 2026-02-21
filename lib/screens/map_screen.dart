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
  static const String _headerAsset = 'assets/images/\u5730\u56FE.png';

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
      return '\u4EE3\u7801$normalizedCityCode';
    }
    return '\u672A\u77E5\u57CE\u5E02';
  }

  String? _normalizeProvinceName(String? raw) {
    if (raw == null) return null;
    var text = raw.trim();
    if (text.isEmpty) return null;

    final alias = _provinceAlias[text];
    if (alias != null) return alias;

    const suffixes = [
      '\u7279\u522B\u884C\u653F\u533A',
      '\u58EE\u65CF\u81EA\u6CBB\u533A',
      '\u56DE\u65CF\u81EA\u6CBB\u533A',
      '\u7EF4\u543E\u5C14\u81EA\u6CBB\u533A',
      '\u81EA\u6CBB\u533A',
      '\u7701',
      '\u5E02',
    ];

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

    const suffixes = [
      '\u81EA\u6CBB\u5DDE',
      '\u5730\u533A',
      '\u7701\u76F4\u8F96\u53BF\u7EA7\u884C\u653F\u533A\u5212',
      '\u7701\u76F4\u8F96\u884C\u653F\u5355\u4F4D',
      '\u76DF',
      '\u5E02',
    ];

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
                '\u5730\u56FE',
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
              tooltip: '\u5237\u65B0\u5730\u56FE',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
                  defaultCountryColor: const Color(0xFFE8EDF4),
                  defaultSelectedCountryColor: const Color(0xFF88B6FF),
                  borderColor: Colors.white,
                  borderWidth: 1.2,
                  selectedBorderWidth: 1.8,
                  backgroundColor: Colors.transparent,
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
        ? '\u6B63\u5728\u8BFB\u53D6\u5DF2\u7F16\u8F91\u660E\u4FE1\u7247\u5730\u70B9...'
        : selectedProvinceName != null
        ? '\u5F53\u524D\u9009\u4E2D\uff1A$selectedProvinceName\uff0C\u5DF2\u6807\u6CE8 $selectedProvinceCityCount \u4E2A\u57CE\u5E02'
        : '\u5DF2\u70B9\u4EAE $provinceCount \u4E2A\u7701\u4EFD\uff0c\u6807\u6CE8 $cityCount \u4E2A\u57CE\u5E02';

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
            '\u6682\u65E0\u70B9\u4EAE\u7701\u4EFD',
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
            '\u6682\u65E0\u57CE\u5E02\u6807\u6CE8',
            style: TextStyle(fontSize: 12, color: Color(0xFF7A8291)),
          ),
        ),
      );
    }

    final title = selectedProvinceName == null
        ? '\u5DF2\u6807\u6CE8\u57CE\u5E02'
        : '$selectedProvinceName \u57CE\u5E02';

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
  '\u5317\u4EAC': 'CN-11',
  '\u5929\u6D25': 'CN-12',
  '\u6CB3\u5317': 'CN-13',
  '\u5C71\u897F': 'CN-14',
  '\u5185\u8499\u53E4': 'CN-15',
  '\u8FBD\u5B81': 'CN-21',
  '\u5409\u6797': 'CN-22',
  '\u9ED1\u9F99\u6C5F': 'CN-23',
  '\u4E0A\u6D77': 'CN-31',
  '\u6C5F\u82CF': 'CN-32',
  '\u6D59\u6C5F': 'CN-33',
  '\u5B89\u5FBD': 'CN-34',
  '\u798F\u5EFA': 'CN-35',
  '\u6C5F\u897F': 'CN-36',
  '\u5C71\u4E1C': 'CN-37',
  '\u6CB3\u5357': 'CN-41',
  '\u6E56\u5317': 'CN-42',
  '\u6E56\u5357': 'CN-43',
  '\u5E7F\u4E1C': 'CN-44',
  '\u5E7F\u897F': 'CN-45',
  '\u6D77\u5357': 'CN-46',
  '\u91CD\u5E86': 'CN-50',
  '\u56DB\u5DDD': 'CN-51',
  '\u8D35\u5DDE': 'CN-52',
  '\u4E91\u5357': 'CN-53',
  '\u897F\u85CF': 'CN-54',
  '\u9655\u897F': 'CN-61',
  '\u7518\u8083': 'CN-62',
  '\u9752\u6D77': 'CN-63',
  '\u5B81\u590F': 'CN-64',
  '\u65B0\u7586': 'CN-65',
  '\u53F0\u6E7E': 'CN-71',
  '\u9999\u6E2F': 'CN-91',
  '\u6FB3\u95E8': 'CN-92',
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
  'CN-11': '\u5317\u4EAC',
  'CN-12': '\u5929\u6D25',
  'CN-13': '\u6CB3\u5317',
  'CN-14': '\u5C71\u897F',
  'CN-15': '\u5185\u8499\u53E4',
  'CN-21': '\u8FBD\u5B81',
  'CN-22': '\u5409\u6797',
  'CN-23': '\u9ED1\u9F99\u6C5F',
  'CN-31': '\u4E0A\u6D77',
  'CN-32': '\u6C5F\u82CF',
  'CN-33': '\u6D59\u6C5F',
  'CN-34': '\u5B89\u5FBD',
  'CN-35': '\u798F\u5EFA',
  'CN-36': '\u6C5F\u897F',
  'CN-37': '\u5C71\u4E1C',
  'CN-41': '\u6CB3\u5357',
  'CN-42': '\u6E56\u5317',
  'CN-43': '\u6E56\u5357',
  'CN-44': '\u5E7F\u4E1C',
  'CN-45': '\u5E7F\u897F',
  'CN-46': '\u6D77\u5357',
  'CN-50': '\u91CD\u5E86',
  'CN-51': '\u56DB\u5DDD',
  'CN-52': '\u8D35\u5DDE',
  'CN-53': '\u4E91\u5357',
  'CN-54': '\u897F\u85CF',
  'CN-61': '\u9655\u897F',
  'CN-62': '\u7518\u8083',
  'CN-63': '\u9752\u6D77',
  'CN-64': '\u5B81\u590F',
  'CN-65': '\u65B0\u7586',
  'CN-71': '\u53F0\u6E7E',
  'CN-91': '\u9999\u6E2F',
  'CN-92': '\u6FB3\u95E8',
};

const Map<String, String> _provinceAlias = {
  '\u5185\u8499\u53E4\u81EA\u6CBB\u533A': '\u5185\u8499\u53E4',
  '\u897F\u85CF\u81EA\u6CBB\u533A': '\u897F\u85CF',
  '\u5E7F\u897F\u58EE\u65CF\u81EA\u6CBB\u533A': '\u5E7F\u897F',
  '\u5B81\u590F\u56DE\u65CF\u81EA\u6CBB\u533A': '\u5B81\u590F',
  '\u65B0\u7586\u7EF4\u543E\u5C14\u81EA\u6CBB\u533A': '\u65B0\u7586',
  '\u9999\u6E2F\u7279\u522B\u884C\u653F\u533A': '\u9999\u6E2F',
  '\u6FB3\u95E8\u7279\u522B\u884C\u653F\u533A': '\u6FB3\u95E8',
  '\u53F0\u6E7E\u7701': '\u53F0\u6E7E',
  '\u5E7F\u897F\u58EE\u65CF': '\u5E7F\u897F',
  '\u5B81\u590F\u56DE\u65CF': '\u5B81\u590F',
  '\u65B0\u7586\u7EF4\u543E\u5C14': '\u65B0\u7586',
};

const Map<String, String> _provinceByCity = {
  '\u5317\u4EAC': '\u5317\u4EAC',
  '\u5929\u6D25': '\u5929\u6D25',
  '\u4E0A\u6D77': '\u4E0A\u6D77',
  '\u91CD\u5E86': '\u91CD\u5E86',
  '\u5E7F\u5DDE': '\u5E7F\u4E1C',
  '\u6DF1\u5733': '\u5E7F\u4E1C',
  '\u73E0\u6D77': '\u5E7F\u4E1C',
  '\u4E1C\u839E': '\u5E7F\u4E1C',
  '\u4F5B\u5C71': '\u5E7F\u4E1C',
  '\u676D\u5DDE': '\u6D59\u6C5F',
  '\u5B81\u6CE2': '\u6D59\u6C5F',
  '\u5357\u4EAC': '\u6C5F\u82CF',
  '\u82CF\u5DDE': '\u6C5F\u82CF',
  '\u6210\u90FD': '\u56DB\u5DDD',
  '\u6B66\u6C49': '\u6E56\u5317',
  '\u897F\u5B89': '\u9655\u897F',
  '\u957F\u6C99': '\u6E56\u5357',
  '\u90D1\u5DDE': '\u6CB3\u5357',
  '\u6D4E\u5357': '\u5C71\u4E1C',
  '\u9752\u5C9B': '\u5C71\u4E1C',
  '\u53A6\u95E8': '\u798F\u5EFA',
  '\u798F\u5DDE': '\u798F\u5EFA',
  '\u6606\u660E': '\u4E91\u5357',
  '\u8D35\u9633': '\u8D35\u5DDE',
  '\u5357\u5B81': '\u5E7F\u897F',
  '\u6D77\u53E3': '\u6D77\u5357',
  '\u4E09\u4E9A': '\u6D77\u5357',
  '\u4E4C\u9C81\u6728\u9F50': '\u65B0\u7586',
  '\u62C9\u8428': '\u897F\u85CF',
  '\u547C\u548C\u6D69\u7279': '\u5185\u8499\u53E4',
  '\u6C88\u9633': '\u8FBD\u5B81',
  '\u957F\u6625': '\u5409\u6797',
  '\u54C8\u5C14\u6EE8': '\u9ED1\u9F99\u6C5F',
  '\u5408\u80A5': '\u5B89\u5FBD',
  '\u5357\u660C': '\u6C5F\u897F',
  '\u77F3\u5BB6\u5E84': '\u6CB3\u5317',
  '\u592A\u539F': '\u5C71\u897F',
  '\u5170\u5DDE': '\u7518\u8083',
  '\u897F\u5B81': '\u9752\u6D77',
  '\u94F6\u5DDD': '\u5B81\u590F',
  '\u53F0\u5317': '\u53F0\u6E7E',
  '\u9AD8\u96C4': '\u53F0\u6E7E',
  '\u9999\u6E2F': '\u9999\u6E2F',
  '\u6FB3\u95E8': '\u6FB3\u95E8',
};
