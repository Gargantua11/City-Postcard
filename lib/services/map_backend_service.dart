import 'backend_api_client.dart';

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
  MapBackendService({BackendApiClient? apiClient})
    : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;

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
}
