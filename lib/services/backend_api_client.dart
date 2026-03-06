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
    } catch (error) {
      throw BackendApiException(
        '网络请求失败 [GET $path]: ${error.runtimeType}: $error',
      );
    }

    final body = _decodeBodyFromBytes(response.bodyBytes);
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
    return _sendMultipartFile(
      'PUT',
      path,
      fieldName: fieldName,
      filePath: filePath,
      fields: fields,
      queryParameters: queryParameters,
      requireAuth: requireAuth,
    );
  }

  Future<Map<String, dynamic>> postMultipartFile(
    String path, {
    required String fieldName,
    required String filePath,
    Map<String, String>? fields,
    Map<String, String>? queryParameters,
    bool requireAuth = true,
  }) async {
    return _sendMultipartFile(
      'POST',
      path,
      fieldName: fieldName,
      filePath: filePath,
      fields: fields,
      queryParameters: queryParameters,
      requireAuth: requireAuth,
    );
  }

  Future<Map<String, dynamic>> _sendMultipartFile(
    String method,
    String path, {
    required String fieldName,
    required String filePath,
    Map<String, String>? fields,
    Map<String, String>? queryParameters,
    required bool requireAuth,
  }) async {
    final uri = _buildUri(path, queryParameters: queryParameters);
    final headers = await _buildHeaders(requireAuth: requireAuth);

    final request = http.MultipartRequest(method, uri);
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
      throw const BackendApiException('上传文件路径无效。');
    }

    http.Response response;
    try {
      final streamed = await request.send();
      response = await http.Response.fromStream(streamed);
    } catch (error) {
      throw BackendApiException(
        '网络请求失败 [${method.toUpperCase()} $path]: '
        '${error.runtimeType}: $error',
      );
    }

    final decoded = _decodeBodyFromBytes(response.bodyBytes);
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
      String? tokenType;
      try {
        tokenType = (await _storageService.getUser())?.tokenType;
      } catch (_) {
        tokenType = null;
      }
      headers['Authorization'] = _buildAuthorizationValue(
        token,
        tokenType: tokenType,
      );
    }
    return headers;
  }

  static String _buildAuthorizationValue(String rawToken, {String? tokenType}) {
    final token = rawToken.trim();
    if (token.isEmpty) return '';

    // Keep a full "<scheme> <credential>" token untouched.
    if (RegExp(r'^[A-Za-z][A-Za-z0-9_-]*\s+.+$').hasMatch(token)) {
      return token;
    }

    final scheme = tokenType?.trim().isNotEmpty == true
        ? tokenType!.trim()
        : 'Bearer';
    return '$scheme $token';
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
          throw const BackendApiException('不支持的请求方法。');
      }
    } catch (error) {
      throw BackendApiException(
        '网络请求失败 [${method.toUpperCase()} $path]: '
        '${error.runtimeType}: $error',
      );
    }

    final decoded = _decodeBodyFromBytes(response.bodyBytes);
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
      return '登录已过期，请重新登录。';
    }
    return _extractMessage(body) ?? '请求失败（$statusCode）';
  }

  static Map<String, dynamic>? _decodeBodyFromBytes(List<int> bodyBytes) {
    if (bodyBytes.isEmpty) {
      return null;
    }

    final candidates = <String>[];
    try {
      candidates.add(utf8.decode(bodyBytes));
    } catch (_) {
      candidates.add(utf8.decode(bodyBytes, allowMalformed: true));
    }
    candidates.add(latin1.decode(bodyBytes, allowInvalid: true));

    for (final raw in candidates) {
      final decoded = _decodeBody(raw);
      if (decoded != null) {
        return decoded;
      }
    }

    return null;
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

    for (final key in const ['msg', 'message', 'error', 'detail']) {
      final value = body[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return _decodeEscapedText(value);
      }
    }

    final data = extractData(body);
    final map = asMap(data);
    if (map == null) return null;

    for (final key in const ['msg', 'message', 'error', 'detail']) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return _decodeEscapedText(value);
      }
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
      if (text.isNotEmpty) return _decodeEscapedText(text);
    }

    return null;
  }

  static String _decodeEscapedText(String raw) {
    if (!raw.contains(r'\')) {
      return raw;
    }

    var current = raw;
    for (var i = 0; i < 2; i++) {
      final decoded = _tryDecodeEscapedText(current);
      if (decoded == null || decoded == current) {
        break;
      }
      current = decoded;
    }
    return current;
  }

  static String? _tryDecodeEscapedText(String input) {
    final escaped = input.replaceAll('"', r'\"');
    try {
      final decoded = jsonDecode('"$escaped"');
      return decoded is String ? decoded : null;
    } catch (_) {
      return null;
    }
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
