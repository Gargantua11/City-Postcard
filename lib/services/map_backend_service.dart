import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  MapBackendService({BackendApiClient? apiClient})
    : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;

  Future<MapLightedCitiesResult>
  fetchLightedCityCodesWithOfflineFallback() async {
    try {
      final codes = await fetchLightedCityCodes();
      await _saveLightedCityCodesCache(codes);
      return MapLightedCitiesResult(cityCodes: codes, isOffline: false);
    } catch (_) {
      final cached = await _readLightedCityCodesCache();
      if (cached.isNotEmpty) {
        return MapLightedCitiesResult(
          cityCodes: cached,
          isOffline: true,
          notice: '网络异常，已展示离线缓存地图',
        );
      }
      return MapLightedCitiesResult(
        cityCodes: _offlineSeedCityCodes,
        isOffline: true,
        notice: '网络异常，已展示离线示例地图',
      );
    }
  }

  Future<ProvincePostcardsResult> fetchProvincePostcardsWithOfflineFallback(
    String provinceCodePrefix,
  ) async {
    try {
      final cards = await fetchProvincePostcards(provinceCodePrefix);
      await _saveProvincePostcardsCache(provinceCodePrefix, cards);
      return ProvincePostcardsResult(postcards: cards, isOffline: false);
    } catch (_) {
      final cached = await _readProvincePostcardsCache(provinceCodePrefix);
      if (cached.isNotEmpty) {
        return ProvincePostcardsResult(
          postcards: cached,
          isOffline: true,
          notice: '网络异常，已展示离线缓存省份数据',
        );
      }
      final seedCards = _offlineSeedProvincePostcards(provinceCodePrefix);
      return ProvincePostcardsResult(
        postcards: seedCards,
        isOffline: true,
        notice: '网络异常，已展示离线示例省份数据',
      );
    }
  }

  Future<List<String>> fetchLightedCityCodes() async {
    final body = await _apiClient.get(
      '/map/lighted-cities',
      requireAuth: false,
    );

    final data = BackendApiClient.extractData(body);
    final rawList = BackendApiClient.extractList(data);

    final codes = <String>[];
    for (final item in rawList) {
      final code = _extractCode(item);
      if (code == null || code.isEmpty) continue;
      codes.add(code);
    }

    return codes;
  }

  Future<List<MapProvincePostcard>> fetchProvincePostcards(
    String provinceCodePrefix,
  ) async {
    final body = await _apiClient.get(
      '/map/province-postcard/$provinceCodePrefix',
      requireAuth: false,
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

  String? _normalizeCode(String? raw) {
    if (raw == null) return null;
    final digits = raw.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return digits;
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

  static const List<String> _offlineSeedCityCodes = <String>[
    '1101',
    '3101',
    '3201',
    '3301',
    '3701',
    '4101',
    '4201',
    '4301',
    '4401',
    '4403',
    '5001',
    '5101',
    '6101',
  ];

  List<MapProvincePostcard> _offlineSeedProvincePostcards(
    String provinceCodePrefix,
  ) {
    final now = DateTime.now();

    switch (provinceCodePrefix) {
      case '11':
        return <MapProvincePostcard>[
          MapProvincePostcard(
            cityCode: '1101',
            cityName: '北京市',
            provinceName: '北京',
            latitude: null,
            longitude: null,
            createdAt: now.subtract(const Duration(hours: 3)),
          ),
        ];
      case '31':
        return <MapProvincePostcard>[
          MapProvincePostcard(
            cityCode: '3101',
            cityName: '上海市',
            provinceName: '上海',
            latitude: null,
            longitude: null,
            createdAt: now.subtract(const Duration(hours: 4)),
          ),
        ];
      case '32':
        return <MapProvincePostcard>[
          MapProvincePostcard(
            cityCode: '3201',
            cityName: '南京市',
            provinceName: '江苏',
            latitude: null,
            longitude: null,
            createdAt: now.subtract(const Duration(hours: 6)),
          ),
        ];
      case '33':
        return <MapProvincePostcard>[
          MapProvincePostcard(
            cityCode: '3301',
            cityName: '杭州市',
            provinceName: '浙江',
            latitude: null,
            longitude: null,
            createdAt: now.subtract(const Duration(hours: 8)),
          ),
        ];
      case '37':
        return <MapProvincePostcard>[
          MapProvincePostcard(
            cityCode: '3701',
            cityName: '济南市',
            provinceName: '山东',
            latitude: null,
            longitude: null,
            createdAt: now.subtract(const Duration(hours: 5)),
          ),
        ];
      case '41':
        return <MapProvincePostcard>[
          MapProvincePostcard(
            cityCode: '4101',
            cityName: '郑州市',
            provinceName: '河南',
            latitude: null,
            longitude: null,
            createdAt: now.subtract(const Duration(hours: 7)),
          ),
        ];
      case '42':
        return <MapProvincePostcard>[
          MapProvincePostcard(
            cityCode: '4201',
            cityName: '武汉市',
            provinceName: '湖北',
            latitude: null,
            longitude: null,
            createdAt: now.subtract(const Duration(hours: 2)),
          ),
        ];
      case '43':
        return <MapProvincePostcard>[
          MapProvincePostcard(
            cityCode: '4301',
            cityName: '长沙市',
            provinceName: '湖南',
            latitude: null,
            longitude: null,
            createdAt: now.subtract(const Duration(hours: 9)),
          ),
        ];
      case '44':
        return <MapProvincePostcard>[
          MapProvincePostcard(
            cityCode: '4401',
            cityName: '广州市',
            provinceName: '广东',
            latitude: null,
            longitude: null,
            createdAt: now.subtract(const Duration(hours: 1)),
          ),
          MapProvincePostcard(
            cityCode: '4403',
            cityName: '深圳市',
            provinceName: '广东',
            latitude: null,
            longitude: null,
            createdAt: now.subtract(const Duration(hours: 10)),
          ),
        ];
      case '50':
        return <MapProvincePostcard>[
          MapProvincePostcard(
            cityCode: '5001',
            cityName: '重庆市',
            provinceName: '重庆',
            latitude: null,
            longitude: null,
            createdAt: now.subtract(const Duration(hours: 11)),
          ),
        ];
      case '51':
        return <MapProvincePostcard>[
          MapProvincePostcard(
            cityCode: '5101',
            cityName: '成都市',
            provinceName: '四川',
            latitude: null,
            longitude: null,
            createdAt: now.subtract(const Duration(minutes: 40)),
          ),
        ];
      case '61':
        return <MapProvincePostcard>[
          MapProvincePostcard(
            cityCode: '6101',
            cityName: '西安市',
            provinceName: '陕西',
            latitude: null,
            longitude: null,
            createdAt: now.subtract(const Duration(hours: 12)),
          ),
        ];
      default:
        return const <MapProvincePostcard>[];
    }
  }
}
