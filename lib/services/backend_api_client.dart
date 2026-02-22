import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'storage_service.dart';

class BackendApiException implements Exception {
  final String message;
  final int? statusCode;

  const BackendApiException(this.message, {this.statusCode});

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

class BackendApiClient {
  BackendApiClient({StorageService? storageService})
    : _storageService = storageService ?? StorageService();

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

    if (kIsWeb) {
      return 'http://localhost:8080';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8080';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        return 'http://localhost:8080';
    }
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
      throw const BackendApiException('网络异常，请稍后重试');
    }

    final body = _decodeBody(response.body);
    final success = _isSuccessful(response.statusCode, body);
    if (!success) {
      throw BackendApiException(
        _extractMessage(body) ?? '请求失败(${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    return body ?? <String, dynamic>{};
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
