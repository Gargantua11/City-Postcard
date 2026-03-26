import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:interactive_country_map/interactive_country_map.dart';
import 'package:intl/intl.dart';

import '../data/city_code_center.dart';
import '../data/city_code_name.dart';
import '../models/postcard_element_layer.dart';
import '../services/edited_postcard_service.dart';
import '../services/postcard_data_refresh_bus.dart';
import '../services/storage_service.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/postcard_layer_render_helper.dart';
import '../widgets/resolved_image.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String _headerAsset = 'assets/images/map/地图.png';

  final EditedPostcardService _editedPostcardService = EditedPostcardService();
  final StorageService _storageService = StorageService();

  bool _isLoading = true;
  bool _isPostcardsLoading = true;
  bool _isHome3dPreviewEnabled = true;
  Set<String> _litProvinceCodes = const {};
  Map<String, List<_CitySpot>> _citySpotsByProvince = const {};
  List<_CitySpot> _citySpots = const [];
  List<EditedPostcard> _editedPostcards = const [];
  String? _selectedProvinceCode;
  String? _selectedCityCode;
  String? _selectedCityLabel;
  String? _selectedCityProvinceCode;

  @override
  void initState() {
    super.initState();
    PostcardDataRefreshBus.listenable.addListener(_onPostcardSaved);
    _loadEditedPostcards();
    _loadHome3dPreviewSetting();
  }

  @override
  void dispose() {
    PostcardDataRefreshBus.listenable.removeListener(_onPostcardSaved);
    super.dispose();
  }

  void _onPostcardSaved() {
    if (!mounted) return;
    _loadEditedPostcards();
  }

  Future<void> _loadHome3dPreviewSetting() async {
    final saved = await _storageService.getHome3dPreviewEnabled();
    if (!mounted || saved == null) return;
    setState(() {
      _isHome3dPreviewEnabled = saved;
    });
  }

  Future<void> _loadEditedPostcards() async {
    setState(() {
      _isPostcardsLoading = true;
      _isLoading = true;
    });

    try {
      final postcards = await _editedPostcardService.getEditedPostcards();
      if (!mounted) return;
      _rebuildMapFromPostcards(postcards);
    } catch (_) {
      if (!mounted) return;
      _rebuildMapFromPostcards(const <EditedPostcard>[]);
    }
  }

  void _rebuildMapFromPostcards(List<EditedPostcard> postcards) {
    final litProvinces = <String>{};
    final latestByProvinceCity = <String, _CitySpot>{};

    for (final card in postcards) {
      final cityCode = _normalizeCityCode(card.cityCode);
      final provinceCode = _resolveProvinceCode(
        cityCode: cityCode,
        provinceName: card.provinceName,
      );
      if (provinceCode == null) continue;

      final coordinate = _resolveCityCoordinate(
        cityCode: cityCode,
        latitude: card.latitude,
        longitude: card.longitude,
      );
      final spot = _CitySpot(
        provinceCode: provinceCode,
        cityLabel: _resolveCityLabel(
          cityName: card.cityName,
          cityCode: cityCode,
        ),
        cityCode: cityCode,
        latitude: coordinate?.latitude,
        longitude: coordinate?.longitude,
        editedAt: card.editedAt,
      );

      final normalizedCityLabel = _normalizeCityName(spot.cityLabel);
      final dedupeKey =
          '${spot.provinceCode}_${spot.cityCode ?? normalizedCityLabel ?? spot.cityLabel}';
      final current = latestByProvinceCity[dedupeKey];
      if (current == null || spot.editedAt.isAfter(current.editedAt)) {
        latestByProvinceCity[dedupeKey] = spot;
      }
    }

    final citySpotsByProvince = <String, List<_CitySpot>>{};
    for (final spot in latestByProvinceCity.values) {
      litProvinces.add(spot.provinceCode);
      citySpotsByProvince.putIfAbsent(spot.provinceCode, () => []).add(spot);
    }
    for (final list in citySpotsByProvince.values) {
      list.sort((a, b) => b.editedAt.compareTo(a.editedAt));
    }

    final allSpots = _buildAllSpots(citySpotsByProvince);
    final retainedProvince = litProvinces.contains(_selectedProvinceCode)
        ? _selectedProvinceCode
        : null;
    final retainedCity = _findRetainedSelectedCity(
      provinceCode: retainedProvince,
      citySpotsByProvince: citySpotsByProvince,
    );

    setState(() {
      _editedPostcards = postcards;
      _litProvinceCodes = litProvinces;
      _citySpotsByProvince = citySpotsByProvince;
      _citySpots = allSpots;
      _selectedProvinceCode = retainedProvince;
      _selectedCityCode = retainedCity?.cityCode;
      _selectedCityLabel = retainedCity?.cityLabel;
      _selectedCityProvinceCode = retainedCity?.provinceCode;
      _isPostcardsLoading = false;
      _isLoading = false;
    });
  }

  _CitySpot? _findRetainedSelectedCity({
    required String? provinceCode,
    required Map<String, List<_CitySpot>> citySpotsByProvince,
  }) {
    if (provinceCode == null) return null;
    final selectedCityProvinceCode = _selectedCityProvinceCode;
    if (selectedCityProvinceCode == null || selectedCityProvinceCode.isEmpty) {
      return null;
    }
    if (selectedCityProvinceCode != provinceCode) return null;

    final spots = citySpotsByProvince[provinceCode];
    if (spots == null || spots.isEmpty) return null;

    final selectedCityCode = _normalizeCityCode(_selectedCityCode);
    final selectedCityLabel = _normalizeCityName(_selectedCityLabel);
    for (final spot in spots) {
      final spotCode = _normalizeCityCode(spot.cityCode);
      final spotLabel = _normalizeCityName(spot.cityLabel);
      final matchByCode =
          selectedCityCode != null &&
          spotCode != null &&
          selectedCityCode == spotCode;
      final matchByLabel =
          selectedCityCode == null &&
          selectedCityLabel != null &&
          spotLabel != null &&
          selectedCityLabel == spotLabel;
      if (matchByCode || matchByLabel) {
        return spot;
      }
    }

    return null;
  }

  String? _resolveProvinceCode({
    required String? cityCode,
    required String? provinceName,
  }) {
    final fromCityCode = _provinceCodeFromCityCode(cityCode);
    if (fromCityCode != null) return fromCityCode;

    final normalizedProvinceName = _normalizeCityName(provinceName);
    if (normalizedProvinceName == null || normalizedProvinceName.isEmpty) {
      return null;
    }

    for (final entry in _provinceNameByCode.entries) {
      final normalizedName = _normalizeCityName(entry.value);
      if (normalizedName == null || normalizedName.isEmpty) continue;
      if (normalizedName == normalizedProvinceName) {
        return entry.key;
      }
    }

    return null;
  }

  List<_CitySpot> _buildAllSpots(Map<String, List<_CitySpot>> byProvince) {
    final all = <_CitySpot>[];
    for (final spots in byProvince.values) {
      all.addAll(spots);
    }
    all.sort((a, b) => b.editedAt.compareTo(a.editedAt));
    return all;
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

  String? _provinceCodeFromCityCode(String? cityCode) {
    final normalized = _normalizeCityCode(cityCode);
    if (normalized == null || normalized.length < 2) return null;
    final provincePrefix = normalized.substring(0, 2);
    return _provinceCodeByCityPrefix[provincePrefix];
  }

  String? _provincePrefixFromCode(String code) {
    if (!code.startsWith('CN-')) return null;
    final prefix = code.substring(3);
    if (prefix.isEmpty) return null;
    return prefix;
  }

  String _resolveCityLabel({String? cityName, String? cityCode}) {
    final normalizedCity = _normalizeCityName(cityName);
    if (normalizedCity != null && normalizedCity.isNotEmpty) {
      return normalizedCity;
    }
    final normalizedCityCode = _normalizeCityCode(cityCode);
    if (normalizedCityCode != null) {
      final mappedName = kCityCodeNames[normalizedCityCode];
      if (mappedName != null && mappedName.trim().isNotEmpty) {
        return _normalizeCityName(mappedName) ?? mappedName;
      }
      return '城市$normalizedCityCode';
    }
    return '未知城市';
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
    return digits.length >= 4 ? digits.substring(0, 4) : digits;
  }

  List<EditedPostcard> _selectedPostcardsForPlace() {
    final selectedProvince = _selectedProvinceCode;
    if (selectedProvince == null) return const <EditedPostcard>[];

    final provincePrefix = _provincePrefixFromCode(selectedProvince);
    if (provincePrefix == null || provincePrefix.isEmpty) {
      return const <EditedPostcard>[];
    }

    final selectedProvinceName = _normalizeCityName(
      _provinceNameByCode[selectedProvince],
    );
    final selectedCityCode = _selectedCityCode;
    final selectedCityName = _normalizeCityName(_selectedCityLabel);
    final result = <EditedPostcard>[];

    for (final card in _editedPostcards) {
      final cityCode = _normalizeCityCode(card.cityCode);
      final inSelectedProvince = cityCode != null
          ? cityCode.startsWith(provincePrefix)
          : (selectedProvinceName != null &&
                selectedProvinceName.isNotEmpty &&
                _normalizeCityName(card.provinceName) == selectedProvinceName);
      if (!inSelectedProvince) {
        continue;
      }

      if (selectedCityCode != null && selectedCityCode.isNotEmpty) {
        final cardCity = _normalizeCityName(card.cityName);
        final matchByCode = cityCode != null && cityCode == selectedCityCode;
        final matchByName =
            selectedCityName != null &&
            selectedCityName.isNotEmpty &&
            cardCity != null &&
            cardCity == selectedCityName;
        if (!matchByCode && !matchByName) {
          continue;
        }
      } else if (selectedCityName != null && selectedCityName.isNotEmpty) {
        final cardCity = _normalizeCityName(card.cityName);
        if (cardCity == null || cardCity != selectedCityName) {
          continue;
        }
      }

      result.add(card);
    }

    result.sort((a, b) => b.editedAt.compareTo(a.editedAt));
    return result;
  }

  String? _resolvePostcardLocation(EditedPostcard postcard) {
    final city = _normalizeCityName(postcard.cityName);
    final province = _normalizeCityName(postcard.provinceName);
    final cityCode = _normalizeCityCode(postcard.cityCode);

    if (city != null &&
        city.isNotEmpty &&
        province != null &&
        province.isNotEmpty) {
      if (city == province) return city;
      return '$province $city';
    }
    if (city != null && city.isNotEmpty) return city;
    if (province != null && province.isNotEmpty) return province;
    if (cityCode != null && cityCode.isNotEmpty) return cityCode;
    return null;
  }

  void _onCityTap(_CitySpot spot) {
    final nextCityCode = _normalizeCityCode(spot.cityCode);
    final sameSelection =
        _selectedCityProvinceCode == spot.provinceCode &&
        _selectedCityCode == nextCityCode &&
        _selectedCityLabel == spot.cityLabel;

    setState(() {
      if (sameSelection) {
        _selectedCityCode = null;
        _selectedCityLabel = null;
        _selectedCityProvinceCode = null;
        return;
      }

      _selectedProvinceCode = spot.provinceCode;
      _selectedCityCode = nextCityCode;
      _selectedCityLabel = spot.cityLabel;
      _selectedCityProvinceCode = spot.provinceCode;
    });
  }

  void _onProvinceTap(String code) {
    final nextCode = _selectedProvinceCode == code ? null : code;
    setState(() {
      _selectedProvinceCode = nextCode;
      _selectedCityCode = null;
      _selectedCityLabel = null;
      _selectedCityProvinceCode = null;
    });
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
    final mapHeight = (MediaQuery.sizeOf(context).height * 0.34)
        .clamp(250.0, 320.0)
        .toDouble();

    final sortedProvinceCodes = _litProvinceCodes.toList()
      ..sort((a, b) {
        final aName = _provinceNameByCode[a] ?? a;
        final bName = _provinceNameByCode[b] ?? b;
        return aName.compareTo(bName);
      });

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildHeader(),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(height: mapHeight, child: _buildMapCard()),
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
              if (_selectedProvinceCode != null) ...[
                const SizedBox(height: 12),
                _buildSelectedPostcardsSection(),
              ],
              const SizedBox(height: 14),
            ],
          ),
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
              onPressed: _isLoading ? null : _loadEditedPostcards,
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
        color: const Color(0xFFCBE6BB),
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
                onCountrySelected: _onProvinceTap,
                markers: _buildMarkerGroups(),
                theme: InteractiveMapTheme(
                  defaultCountryColor: const Color.fromARGB(255, 170, 172, 174),
                  defaultSelectedCountryColor: const Color(0xFF88B6FF),
                  borderColor: Colors.white,
                  borderWidth: 1.2,
                  selectedBorderWidth: 1.8,
                  backgroundColor: const Color(0xFFCBE6BB),
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
        ? '正在读取地图数据...'
        : selectedProvinceName != null
        ? '当前选中：$selectedProvinceName，已标注 $selectedProvinceCityCount 个城市'
        : '已点亮 $provinceCount 个省份，标注 $cityCount 个城市';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFCBE6BB),
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
            onTap: () => _onProvinceTap(code),
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
              final normalizedSpotCode = _normalizeCityCode(spot.cityCode);
              final selected =
                  _selectedCityProvinceCode == spot.provinceCode &&
                  _selectedCityCode == normalizedSpotCode &&
                  _selectedCityLabel == spot.cityLabel;

              return GestureDetector(
                onTap: () => _onCityTap(spot),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFD9E8FF)
                        : const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF5C86D6)
                          : const Color(0xFFBBD2FF),
                    ),
                  ),
                  child: Text(
                    cityName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? const Color(0xFF1F3F7A)
                          : const Color(0xFF284B8D),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedPostcardsSection() {
    final selectedProvinceCode = _selectedProvinceCode;
    final selectedProvinceName = selectedProvinceCode == null
        ? null
        : _provinceNameByCode[selectedProvinceCode] ?? selectedProvinceCode;
    final selectedCityName = _selectedCityLabel?.trim();

    final title = selectedProvinceName == null
        ? '选中地点后显示明信片'
        : (selectedCityName != null && selectedCityName.isNotEmpty)
        ? '$selectedProvinceName · $selectedCityName'
        : '$selectedProvinceName 明信片';

    final postcards = _selectedPostcardsForPlace();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFCBE6BB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E4EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C3649),
            ),
          ),
          const SizedBox(height: 8),
          if (selectedProvinceCode == null)
            const Text(
              '请先在地图或城市标签中选中地点',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF788092),
                fontWeight: FontWeight.w500,
              ),
            )
          else if (_isPostcardsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            )
          else if (postcards.isEmpty)
            const Text(
              '该地点暂无明信片',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF788092),
                fontWeight: FontWeight.w500,
              ),
            )
          else ...[
            Text(
              '共 ${postcards.length} 张',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF5D6678),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ListView.separated(
              itemCount: postcards.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final postcard = postcards[index];
                return _MapPostcardCard(
                  postcard: postcard,
                  locationText: _resolvePostcardLocation(postcard),
                  enable3dPreview: _isHome3dPreviewEnabled,
                );
              },
            ),
          ],
        ],
      ),
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

class _MapPostcardCard extends StatelessWidget {
  static const double _postcardAspectRatio = 400 / 258;

  const _MapPostcardCard({
    required this.postcard,
    required this.enable3dPreview,
    this.locationText,
  });

  final EditedPostcard postcard;
  final bool enable3dPreview;
  final String? locationText;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = (constraints.maxWidth / _postcardAspectRatio).clamp(
          156.0,
          220.0,
        );

        return SizedBox(
          height: cardHeight,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFCBE6BB),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF9EB694)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _MapPostcardImage(
                    imageSource: postcard.imageUrl,
                    layers: postcard.layers,
                    enable3dPreview: enable3dPreview,
                  ),
                  Positioned(
                    right: 10,
                    left: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat(
                              'yyyy-MM-dd HH:mm',
                            ).format(postcard.editedAt),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          if (locationText != null &&
                              locationText!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.place_rounded,
                              size: 12,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                locationText!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MapPostcardImage extends StatefulWidget {
  const _MapPostcardImage({
    required this.imageSource,
    this.layers = const [],
    this.enable3dPreview = true,
  });

  final String imageSource;
  final List<PostcardElementLayer> layers;
  final bool enable3dPreview;

  @override
  State<_MapPostcardImage> createState() => _MapPostcardImageState();
}

class _MapPostcardImageState extends State<_MapPostcardImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _effectController;

  bool get _hasDynamicLayer {
    if (!widget.enable3dPreview) return false;
    return widget.layers.any((layer) => layer.is3dEnabled);
  }

  @override
  void initState() {
    super.initState();
    _effectController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _syncAnimationState();
  }

  @override
  void didUpdateWidget(covariant _MapPostcardImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimationState();
  }

  @override
  void dispose() {
    _effectController.dispose();
    super.dispose();
  }

  void _syncAnimationState() {
    if (_hasDynamicLayer) {
      if (!_effectController.isAnimating) {
        _effectController.repeat();
      }
      return;
    }

    if (_effectController.isAnimating) {
      _effectController.stop();
    }
    _effectController.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ResolvedImage(
          source: widget.imageSource,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          fallbackBuilder: (_) => _buildFallback(),
          loadingBuilder: (_) => _buildFallback(showProgress: true),
        ),
        if (widget.layers.isNotEmpty)
          if (_hasDynamicLayer)
            AnimatedBuilder(
              animation: _effectController,
              builder: (_, _) => _MapPostcardLayerOverlay(
                layers: widget.layers,
                animationProgress: _effectController.value,
                enable3dPreview: widget.enable3dPreview,
              ),
            )
          else
            _MapPostcardLayerOverlay(
              layers: widget.layers,
              animationProgress: 0,
              enable3dPreview: widget.enable3dPreview,
            ),
      ],
    );
  }

  Widget _buildFallback({bool showProgress = false}) {
    return ColoredBox(
      color: const Color(0xFFCBE6BB),
      child: Center(
        child: showProgress
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.image_not_supported_outlined,
                size: 34,
                color: Color(0xFF6E7E68),
              ),
      ),
    );
  }
}

class _MapPostcardLayerOverlay extends StatelessWidget {
  const _MapPostcardLayerOverlay({
    required this.layers,
    required this.animationProgress,
    required this.enable3dPreview,
  });

  final List<PostcardElementLayer> layers;
  final double animationProgress;
  final bool enable3dPreview;

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
    final layerSize = measurePostcardLayerSize(
      layer,
      previewWidth: width,
      previewHeight: height,
    );
    final offset = resolvePostcardLayerOffset(
      layer,
      previewWidth: width,
      previewHeight: height,
    );
    final left = width / 2 + offset.dx - layerSize.width / 2;
    final top = height / 2 + offset.dy - layerSize.height / 2;

    final visual = buildPostcardLayerVisual(
      layer,
      previewWidth: width,
      previewHeight: height,
      silentAssetError: true,
    );

    Widget transformed = visual;
    if (enable3dPreview && layer.isAsset && layer.is3dEnabled) {
      final speed = layer.rotationSpeed <= 0 ? 1.0 : layer.rotationSpeed;
      final directionSign = layer.rotationDirection == 'counterclockwise'
          ? -1.0
          : 1.0;
      final cycleAngle =
          animationProgress * math.pi * 2 * speed * directionSign;

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
      width: layerSize.width,
      height: layerSize.height,
      child: transformed,
    );
  }
}

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
