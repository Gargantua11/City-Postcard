import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/city_code_name.dart';
import 'edited_postcard_service.dart';
import 'backend_api_client.dart';

class MapLightedCitiesResult {
  final List<String> cityCodes;
  final bool isOffline;
  final String? notice;

  const MapLightedCitiesResult({
    required this.cityCodes,
    required this.isOffline,
    this.notice,
  });
}

class ProvincePostcardsResult {
  final List<MapProvincePostcard> postcards;
  final bool isOffline;
  final String? notice;

  const ProvincePostcardsResult({
    required this.postcards,
    required this.isOffline,
    this.notice,
  });
}

class MapProvincePostcard {
  final String? cityCode;
  final String? cityName;
  final String? provinceName;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  const MapProvincePostcard({
    required this.cityCode,
    required this.cityName,
    required this.provinceName,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  factory MapProvincePostcard.fromJson(Map<String, dynamic> json) {
    return MapProvincePostcard(
      cityCode: BackendApiClient.readString(json, const [
        'cityCode',
        'code',
        'adCode',
      ]),
      cityName: BackendApiClient.readString(json, const [
        'cityName',
        'city',
        'location',
        'address',
      ]),
      provinceName: BackendApiClient.readString(json, const [
        'provinceName',
        'province',
      ]),
      latitude: BackendApiClient.readDouble(json, const [
        'latitude',
        'lat',
        'y',
      ]),
      longitude: BackendApiClient.readDouble(json, const [
        'longitude',
        'lng',
        'lon',
        'x',
      ]),
      createdAt: _parseDateTime(
        BackendApiClient.readString(json, const [
              'createdAt',
              'createTime',
              'publishTime',
              'time',
            ]) ??
            '',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'cityCode': cityCode,
      'cityName': cityName,
      'provinceName': provinceName,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static DateTime _parseDateTime(String raw) {
    if (raw.trim().isEmpty) return DateTime.now();

    DateTime? parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;

    parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (parsed != null) return parsed;

    return DateTime.now();
  }
}

class MapBackendService {
  static const String _lightedCityCodesCacheKey =
      'map_lighted_city_codes_cache_v1';
  static const String _provincePostcardsCacheKeyPrefix =
      'map_province_postcards_cache_v1_';

  static final Map<String, String> _cityNameIndex = _buildCityNameIndex();

  MapBackendService({
    BackendApiClient? apiClient,
    EditedPostcardService? editedPostcardService,
  }) : _apiClient = apiClient ?? BackendApiClient(),
       _editedPostcardService =
           editedPostcardService ?? EditedPostcardService();

  final BackendApiClient _apiClient;
  final EditedPostcardService _editedPostcardService;

  Future<MapLightedCitiesResult>
  fetchLightedCityCodesWithOfflineFallback() async {
    try {
      final codes = await fetchLightedCityCodes();
      await _saveLightedCityCodesCache(codes);
      return MapLightedCitiesResult(
        cityCodes: codes,
        isOffline: false,
        notice: codes.isEmpty ? 'No map markers yet.' : null,
      );
    } on BackendApiException catch (e) {
      if (e.isUnauthorized) {
        rethrow;
      }

      final cached = await _readLightedCityCodesCache();
      if (cached.isNotEmpty) {
        return MapLightedCitiesResult(
          cityCodes: cached,
          isOffline: true,
          notice: 'Network unavailable. Showing cached map data.',
        );
      }
      return MapLightedCitiesResult(
        cityCodes: const <String>[],
        isOffline: true,
        notice: 'Network unavailable. No map marker data.',
      );
    } catch (_) {
      final cached = await _readLightedCityCodesCache();
      if (cached.isNotEmpty) {
        return MapLightedCitiesResult(
          cityCodes: cached,
          isOffline: true,
          notice: 'Network unavailable. Showing cached map data.',
        );
      }
      return MapLightedCitiesResult(
        cityCodes: const <String>[],
        isOffline: true,
        notice: 'Network unavailable. No map marker data.',
      );
    }
  }

  Future<ProvincePostcardsResult> fetchProvincePostcardsWithOfflineFallback(
    String provinceCodePrefix,
  ) async {
    try {
      final cards = await fetchProvincePostcards(provinceCodePrefix);
      await _saveProvincePostcardsCache(provinceCodePrefix, cards);
      return ProvincePostcardsResult(
        postcards: cards,
        isOffline: false,
        notice: cards.isEmpty ? 'No postcards in this province yet.' : null,
      );
    } on BackendApiException catch (e) {
      if (e.isUnauthorized) {
        rethrow;
      }

      final cached = await _readProvincePostcardsCache(provinceCodePrefix);
      if (cached.isNotEmpty) {
        return ProvincePostcardsResult(
          postcards: cached,
          isOffline: true,
          notice: 'Network unavailable. Showing cached province data.',
        );
      }
      return ProvincePostcardsResult(
        postcards: const <MapProvincePostcard>[],
        isOffline: true,
        notice: 'Network unavailable. No province marker data.',
      );
    } catch (_) {
      final cached = await _readProvincePostcardsCache(provinceCodePrefix);
      if (cached.isNotEmpty) {
        return ProvincePostcardsResult(
          postcards: cached,
          isOffline: true,
          notice: 'Network unavailable. Showing cached province data.',
        );
      }
      return ProvincePostcardsResult(
        postcards: const <MapProvincePostcard>[],
        isOffline: true,
        notice: 'Network unavailable. No province marker data.',
      );
    }
  }

  Future<List<String>> fetchLightedCityCodes() async {
    final localEdited = await _editedPostcardService.getEditedPostcards();
    if (localEdited.isNotEmpty) {
      final localCards = _mapLocalPostcards(localEdited);
      final localCodes = <String>{};
      for (final card in localCards) {
        final code = _normalizeCode(card.cityCode);
        if (code == null || code.isEmpty) continue;
        localCodes.add(code);
      }
      return localCodes.toList(growable: false);
    }

    try {
      final fromMap = await _fetchLightedCityCodesFromMap();
      if (fromMap.isNotEmpty) {
        return fromMap;
      }
    } on BackendApiException catch (e) {
      if (e.isUnauthorized) {
        rethrow;
      }
      if (!_isNoPostcardBusiness(e)) {
        rethrow;
      }
    }

    return _fetchLightedCityCodesFromDiscussion();
  }

  Future<List<MapProvincePostcard>> fetchProvincePostcards(
    String provinceCodePrefix,
  ) async {
    final localEdited = await _editedPostcardService.getEditedPostcards();
    if (localEdited.isNotEmpty) {
      final localCards = _mapLocalPostcards(
        localEdited,
        provinceCodePrefix: provinceCodePrefix,
      );
      return localCards;
    }

    try {
      final fromMap = await _fetchProvincePostcardsFromMap(provinceCodePrefix);
      if (fromMap.isNotEmpty) {
        return fromMap;
      }
    } on BackendApiException catch (e) {
      if (e.isUnauthorized) {
        rethrow;
      }
      if (!_isNoPostcardBusiness(e)) {
        rethrow;
      }
    }

    return _fetchProvincePostcardsFromDiscussion(provinceCodePrefix);
  }

  List<MapProvincePostcard> _mapLocalPostcards(
    List<EditedPostcard> postcards, {
    String? provinceCodePrefix,
  }) {
    final cards = <MapProvincePostcard>[];
    for (final postcard in postcards) {
      final cityCode =
          _normalizeCode(postcard.cityCode) ??
          _inferCityCodeFromText(postcard.cityName) ??
          _inferCityCodeFromText(postcard.provinceName);
      if (cityCode == null || cityCode.isEmpty) continue;

      if (provinceCodePrefix != null &&
          provinceCodePrefix.isNotEmpty &&
          !cityCode.startsWith(provinceCodePrefix)) {
        continue;
      }

      final provincePrefix = cityCode.length >= 2
          ? cityCode.substring(0, 2)
          : '';
      cards.add(
        MapProvincePostcard(
          cityCode: cityCode,
          cityName: postcard.cityName?.trim().isNotEmpty == true
              ? postcard.cityName!.trim()
              : _cityNameByCode(cityCode),
          provinceName: postcard.provinceName?.trim().isNotEmpty == true
              ? postcard.provinceName!.trim()
              : _provinceNameByPrefix[provincePrefix],
          latitude: postcard.latitude,
          longitude: postcard.longitude,
          createdAt: postcard.editedAt,
        ),
      );
    }

    cards.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return cards;
  }

  Future<List<String>> _fetchLightedCityCodesFromMap() async {
    final body = await _apiClient.get('/map/lighted-cities', requireAuth: true);

    final data = BackendApiClient.extractData(body);
    final rawList = BackendApiClient.extractList(data);

    final codes = <String>{};
    for (final item in rawList) {
      final code = _extractCode(item);
      if (code == null || code.isEmpty) continue;
      codes.add(code);
    }

    return codes.toList(growable: false);
  }

  Future<List<MapProvincePostcard>> _fetchProvincePostcardsFromMap(
    String provinceCodePrefix,
  ) async {
    final body = await _apiClient.get(
      '/map/province-postcard/$provinceCodePrefix',
      requireAuth: true,
    );

    final data = BackendApiClient.extractData(body);
    final rawList = BackendApiClient.extractList(data);

    final cards = <MapProvincePostcard>[];
    for (final item in rawList) {
      final map = BackendApiClient.asMap(item);
      if (map == null) continue;
      cards.add(MapProvincePostcard.fromJson(map));
    }

    return cards;
  }

  Future<List<String>> _fetchLightedCityCodesFromDiscussion() async {
    final records = await _fetchDiscussionRecords();

    final cityCodes = <String>{};
    for (final record in records) {
      final code = _extractCode(record) ?? _inferCityCode(record);
      if (code == null || code.isEmpty) continue;
      cityCodes.add(code);
    }

    return cityCodes.toList(growable: false);
  }

  Future<List<MapProvincePostcard>> _fetchProvincePostcardsFromDiscussion(
    String provinceCodePrefix,
  ) async {
    final records = await _fetchDiscussionRecords();
    final cards = <MapProvincePostcard>[];

    for (final record in records) {
      final card = _toProvincePostcard(record, provinceCodePrefix);
      if (card == null) continue;
      cards.add(card);
    }

    cards.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return cards;
  }

  Future<List<Map<String, dynamic>>> _fetchDiscussionRecords() async {
    final body = await _apiClient.get(
      '/discussion/postcards',
      requireAuth: true,
    );

    final data = BackendApiClient.extractData(body);
    final records = BackendApiClient.extractList(data);

    final result = <Map<String, dynamic>>[];
    for (final item in records) {
      final map = BackendApiClient.asMap(item);
      if (map == null) continue;
      result.add(map);
    }

    return result;
  }

  MapProvincePostcard? _toProvincePostcard(
    Map<String, dynamic> record,
    String provinceCodePrefix,
  ) {
    final cityCode = _extractCode(record) ?? _inferCityCode(record);
    if (cityCode == null || cityCode.length < 2) {
      return null;
    }

    if (!cityCode.startsWith(provinceCodePrefix)) {
      return null;
    }

    final cityName =
        BackendApiClient.readString(record, const ['cityName', 'city']) ??
        _cityNameByCode(cityCode) ??
        BackendApiClient.readString(record, const ['address', 'location']);

    final createdAtRaw =
        BackendApiClient.readString(record, const [
          'createdAt',
          'createTime',
          'publishTime',
          'time',
        ]) ??
        '';

    return MapProvincePostcard(
      cityCode: cityCode,
      cityName: cityName,
      provinceName: _provinceNameByPrefix[provinceCodePrefix],
      latitude: BackendApiClient.readDouble(record, const ['latitude', 'lat']),
      longitude: BackendApiClient.readDouble(record, const [
        'longitude',
        'lng',
      ]),
      createdAt: MapProvincePostcard._parseDateTime(createdAtRaw),
    );
  }

  String? _extractCode(dynamic item) {
    if (item == null) return null;

    if (item is String || item is num) {
      return _normalizeCode(item.toString());
    }

    final map = BackendApiClient.asMap(item);
    if (map == null) return null;

    final code = BackendApiClient.readString(map, const [
      'cityCode',
      'code',
      'adCode',
    ]);
    return _normalizeCode(code);
  }

  String? _inferCityCode(Map<String, dynamic> record) {
    final candidates = <String?>[
      BackendApiClient.readString(record, const ['cityName']),
      BackendApiClient.readString(record, const ['city']),
      BackendApiClient.readString(record, const ['address']),
      BackendApiClient.readString(record, const ['location']),
    ];

    for (final candidate in candidates) {
      final inferred = _inferCityCodeFromText(candidate);
      if (inferred != null) {
        return inferred;
      }
    }

    return null;
  }

  String? _inferCityCodeFromText(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    final normalizedCandidates = _normalizeLocationCandidates(raw);
    for (final key in normalizedCandidates) {
      final exact = _cityNameIndex[key];
      if (exact != null) {
        return exact;
      }
    }

    for (final key in normalizedCandidates) {
      for (final entry in _cityNameIndex.entries) {
        if (key.contains(entry.key)) {
          return entry.value;
        }
      }
    }

    return null;
  }

  String? _cityNameByCode(String cityCode) {
    final mapped = kCityCodeNames[cityCode]?.trim();
    if (mapped == null || mapped.isEmpty) {
      return null;
    }
    return mapped;
  }

  String? _normalizeCode(String? raw) {
    if (raw == null) return null;
    final digits = raw.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return digits.length >= 4 ? digits.substring(0, 4) : digits;
  }

  bool _isNoPostcardBusiness(BackendApiException error) {
    if (error.apiCode == 6000) {
      return true;
    }

    final text = error.message.trim().toLowerCase();
    if (text.isEmpty) {
      return false;
    }

    return text.contains('postcard') &&
            (text.contains('none') ||
                text.contains('empty') ||
                text.contains('not published') ||
                text.contains('no data')) ||
        text.contains('明信片') &&
            (text.contains('没有发布') ||
                text.contains('还没有发布') ||
                text.contains('未发布') ||
                text.contains('暂无'));
  }

  static Map<String, String> _buildCityNameIndex() {
    final index = <String, String>{};

    for (final entry in kCityCodeNames.entries) {
      final code = entry.key.trim();
      final normalizedCode = code.replaceAll(RegExp(r'[^0-9]'), '');
      if (normalizedCode.isEmpty) continue;

      final variants = _textVariants(entry.value);
      for (final variant in variants) {
        final key = _normalizeLocationKey(variant);
        if (key.isEmpty) continue;
        index.putIfAbsent(key, () => normalizedCode);
      }
    }

    return index;
  }

  Set<String> _normalizeLocationCandidates(String raw) {
    final result = <String>{};

    for (final variant in _textVariants(raw)) {
      final normalized = _normalizeLocationKey(variant);
      if (normalized.isNotEmpty) {
        result.add(normalized);
      }

      final parts = variant.split(RegExp(r'[\s,，、/|\-]+'));
      for (final part in parts) {
        final partKey = _normalizeLocationKey(part);
        if (partKey.isNotEmpty) {
          result.add(partKey);
        }
      }
    }

    return result;
  }

  static Set<String> _textVariants(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const <String>{};

    final variants = <String>{text};
    variants.add(_decodeLatin1AsUtf8(text));
    variants.add(_decodeUtf8AsLatin1(text));
    return variants.where((item) => item.trim().isNotEmpty).toSet();
  }

  static String _decodeLatin1AsUtf8(String text) {
    try {
      return utf8.decode(latin1.encode(text), allowMalformed: true);
    } catch (_) {
      return text;
    }
  }

  static String _decodeUtf8AsLatin1(String text) {
    try {
      return latin1.decode(utf8.encode(text), allowInvalid: true);
    } catch (_) {
      return text;
    }
  }

  static String _normalizeLocationKey(String text) {
    var value = text.trim().toLowerCase();
    if (value.isEmpty) return '';

    value = value.replaceAll(RegExp(r'\s+'), '');
    value = value.replaceAll(RegExp(r'[·,，.。/|\-_]'), '');

    const suffixes = <String>[
      '自治区',
      '自治州',
      '特别行政区',
      '地区',
      '省直辖县级行政区划',
      '省直辖行政单位',
      '盟',
      '省',
      '市',
      '区',
      '县',
      'province',
      'city',
      'district',
    ];

    var changed = true;
    while (changed) {
      changed = false;
      for (final suffix in suffixes) {
        if (value.endsWith(suffix) && value.length > suffix.length) {
          value = value.substring(0, value.length - suffix.length);
          changed = true;
          break;
        }
      }
    }

    return value;
  }

  Future<void> _saveLightedCityCodesCache(List<String> codes) async {
    if (codes.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lightedCityCodesCacheKey, jsonEncode(codes));
  }

  Future<List<String>> _readLightedCityCodesCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lightedCityCodesCacheKey);
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final codes = <String>[];
      for (final item in decoded) {
        final code = _extractCode(item);
        if (code == null || code.isEmpty) continue;
        codes.add(code);
      }
      return codes;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveProvincePostcardsCache(
    String provinceCodePrefix,
    List<MapProvincePostcard> cards,
  ) async {
    if (cards.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_provincePostcardsCacheKeyPrefix$provinceCodePrefix';
    await prefs.setString(
      key,
      jsonEncode(cards.map((card) => card.toJson()).toList()),
    );
  }

  Future<List<MapProvincePostcard>> _readProvincePostcardsCache(
    String provinceCodePrefix,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_provincePostcardsCacheKeyPrefix$provinceCodePrefix';
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final cards = <MapProvincePostcard>[];
      for (final item in decoded) {
        final map = BackendApiClient.asMap(item);
        if (map == null) continue;
        cards.add(MapProvincePostcard.fromJson(map));
      }
      return cards;
    } catch (_) {
      return const [];
    }
  }

  static const Map<String, String> _provinceNameByPrefix = <String, String>{
    '11': 'Beijing',
    '12': 'Tianjin',
    '13': 'Hebei',
    '14': 'Shanxi',
    '15': 'Inner Mongolia',
    '21': 'Liaoning',
    '22': 'Jilin',
    '23': 'Heilongjiang',
    '31': 'Shanghai',
    '32': 'Jiangsu',
    '33': 'Zhejiang',
    '34': 'Anhui',
    '35': 'Fujian',
    '36': 'Jiangxi',
    '37': 'Shandong',
    '41': 'Henan',
    '42': 'Hubei',
    '43': 'Hunan',
    '44': 'Guangdong',
    '45': 'Guangxi',
    '46': 'Hainan',
    '50': 'Chongqing',
    '51': 'Sichuan',
    '52': 'Guizhou',
    '53': 'Yunnan',
    '54': 'Tibet',
    '61': 'Shaanxi',
    '62': 'Gansu',
    '63': 'Qinghai',
    '64': 'Ningxia',
    '65': 'Xinjiang',
  };
}
