import 'dart:convert';

import 'package:http/http.dart' as http;

import 'storage_service.dart';

class BackendApiException implements Exception {
  final String message;
  final int? statusCode;
  final int? apiCode;

  const BackendApiException(this.message, {this.statusCode, this.apiCode});

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

class BackendApiClient {
  BackendApiClient({StorageService? storageService})
    : _storageService = storageService ?? StorageService();

  static const String _defaultBaseUrl = 'http://8.130.108.118:6000';
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );
  static final String baseUrl = _resolveBaseUrl();

  final StorageService _storageService;

  static String _resolveBaseUrl() {
    final configured = _configuredBaseUrl.trim();
    if (configured.isNotEmpty) {
      return configured;
    }
    return _defaultBaseUrl;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
    bool requireAuth = true,
  }) async {
    final uri = _buildUri(path, queryParameters: queryParameters);
    final headers = await _buildHeaders(requireAuth: requireAuth);

    http.Response response;
    try {
      response = await http.get(uri, headers: headers);
    } catch (_) {
      throw const BackendApiException('缃戠粶寮傚父锛岃绋嶅悗閲嶈瘯');
    }

    final body = _decodeBody(response.body);
    final success = _isSuccessful(response.statusCode, body);
    if (!success) {
      throw BackendApiException(
        _buildFailureMessage(response.statusCode, body),
        statusCode: response.statusCode,
        apiCode: _toInt(body?['code']),
      );
    }

    return body ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    bool requireAuth = true,
  }) async {
    return _send(
      'POST',
      path,
      body: body,
      queryParameters: queryParameters,
      requireAuth: requireAuth,
    );
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    bool requireAuth = true,
  }) async {
    return _send(
      'PUT',
      path,
      body: body,
      queryParameters: queryParameters,
      requireAuth: requireAuth,
    );
  }

  Future<Map<String, dynamic>> putMultipartFile(
    String path, {
    required String fieldName,
    required String filePath,
    Map<String, String>? fields,
    Map<String, String>? queryParameters,
    bool requireAuth = true,
  }) async {
    final uri = _buildUri(path, queryParameters: queryParameters);
    final headers = await _buildHeaders(requireAuth: requireAuth);

    final request = http.MultipartRequest('PUT', uri);
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'content-type') continue;
      request.headers[entry.key] = entry.value;
    }

    if (fields != null && fields.isNotEmpty) {
      for (final entry in fields.entries) {
        final key = entry.key.trim();
        final value = entry.value.trim();
        if (key.isEmpty || value.isEmpty) continue;
        request.fields[key] = value;
      }
    }

    try {
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
    } catch (_) {
      throw const BackendApiException('Invalid upload file path.');
    }

    http.Response response;
    try {
      final streamed = await request.send();
      response = await http.Response.fromStream(streamed);
    } catch (_) {
      throw const BackendApiException(
        'Network request failed. Please try again later.',
      );
    }

    final decoded = _decodeBody(response.body);
    final success = _isSuccessful(response.statusCode, decoded);
    if (!success) {
      throw BackendApiException(
        _buildFailureMessage(response.statusCode, decoded),
        statusCode: response.statusCode,
        apiCode: _toInt(decoded?['code']),
      );
    }

    return decoded ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    bool requireAuth = true,
  }) async {
    return _send(
      'DELETE',
      path,
      body: body,
      queryParameters: queryParameters,
      requireAuth: requireAuth,
    );
  }

  Future<Map<String, String>> _buildHeaders({required bool requireAuth}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
    };

    if (!requireAuth) {
      return headers;
    }

    final token = await _storageService.getToken();
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }
    return headers;
  }

  Uri _buildUri(String path, {Map<String, String>? queryParameters}) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$normalizedPath');

    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    final sanitized = <String, String>{};
    for (final entry in queryParameters.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();
      if (key.isEmpty || value.isEmpty) continue;
      sanitized[key] = value;
    }

    if (sanitized.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: sanitized);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    required bool requireAuth,
  }) async {
    final uri = _buildUri(path, queryParameters: queryParameters);
    final headers = await _buildHeaders(requireAuth: requireAuth);

    http.Response response;
    try {
      switch (method) {
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
          break;
        case 'PUT':
          response = await http.put(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
          break;
        case 'DELETE':
          response = await http.delete(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
          break;
        default:
          throw const BackendApiException('娑撳秵鏁幐浣烘畱鐠囬攱鐪伴弬瑙勭《');
      }
    } catch (_) {
      throw const BackendApiException(
        'Network request failed. Please try again later.',
      );
    }

    final decoded = _decodeBody(response.body);
    final success = _isSuccessful(response.statusCode, decoded);
    if (!success) {
      throw BackendApiException(
        _buildFailureMessage(response.statusCode, decoded),
        statusCode: response.statusCode,
        apiCode: _toInt(decoded?['code']),
      );
    }

    return decoded ?? <String, dynamic>{};
  }

  static String _buildFailureMessage(
    int statusCode,
    Map<String, dynamic>? body,
  ) {
    if (statusCode == 401 || statusCode == 403) {
      return '登录已失效，请重新登录';
    }
    return _extractMessage(body) ?? '请求失败($statusCode)';
  }

  static Map<String, dynamic>? _decodeBody(String raw) {
    if (raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
      return <String, dynamic>{'data': decoded};
    } catch (_) {
      return null;
    }
  }

  static bool _isSuccessful(int statusCode, Map<String, dynamic>? body) {
    if (statusCode < 200 || statusCode >= 300) {
      return false;
    }

    if (body == null || !body.containsKey('code')) {
      return true;
    }

    final code = _toInt(body['code']);
    if (code == null) {
      return true;
    }

    return code == 0 || code == 200;
  }

  static String? _extractMessage(Map<String, dynamic>? body) {
    if (body == null) return null;

    for (final key in const ['msg', 'message', 'error']) {
      final value = body[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    final data = extractData(body);
    final map = asMap(data);
    if (map == null) return null;

    for (final key in const ['msg', 'message', 'error']) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    return null;
  }

  static dynamic extractData(Map<String, dynamic> body) {
    if (body.containsKey('data')) return body['data'];
    if (body.containsKey('result')) return body['result'];
    if (body.containsKey('records')) return body['records'];
    return body;
  }

  static List<dynamic> extractList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) return raw;

    final map = asMap(raw);
    if (map == null) return const [];

    for (final key in const ['records', 'list', 'items', 'content', 'data']) {
      final value = map[key];
      if (value is List) return value;
    }

    return const [];
  }

  static Map<String, dynamic>? asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.cast<String, dynamic>();
    return null;
  }

  static String? readString(dynamic raw, List<String> keys) {
    final map = asMap(raw);
    if (map == null) return null;

    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }

    return null;
  }

  static int? readInt(dynamic raw, List<String> keys) {
    final map = asMap(raw);
    if (map == null) return null;

    for (final key in keys) {
      final value = _toInt(map[key]);
      if (value != null) return value;
    }

    return null;
  }

  static double? readDouble(dynamic raw, List<String> keys) {
    final map = asMap(raw);
    if (map == null) return null;

    for (final key in keys) {
      final value = _toDouble(map[key]);
      if (value != null) return value;
    }

    return null;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
