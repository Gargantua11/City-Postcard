import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';

class AuthService {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );
  static final String _baseUrl = _resolveBaseUrl();

  String? _lastError;

  String? get lastError => _lastError;
  String get baseUrl => _baseUrl;

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
        // Android emulator maps host loopback to 10.0.2.2.
        return 'http://10.0.2.2:8080';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        return 'http://localhost:8080';
    }
  }

  Future<bool> sendRegisterCode(String phone) async {
    _lastError = null;
    final response = await _postJson('/auth/register/code', <String, dynamic>{
      'phone': phone,
    });
    if (response == null) return false;

    final body = _decodeResponseBody(response);
    if (_isRequestSuccessful(response.statusCode, body)) {
      return true;
    }

    _lastError = _extractErrorMessage(body, fallback: '发送注册验证码失败');
    return false;
  }

  Future<String?> verifyRegisterCode(String phone, String code) async {
    _lastError = null;
    final response = await _postJson('/auth/register/verify', <String, dynamic>{
      'phone': phone,
      'verifyCode': code,
    });
    if (response == null) return null;

    final body = _decodeResponseBody(response);
    if (!_isRequestSuccessful(response.statusCode, body)) {
      _lastError = _extractErrorMessage(body, fallback: '校验注册验证码失败');
      return null;
    }

    final regToken = _extractStringField(body, const <String>[
      'regToken',
      'registerToken',
      'token',
    ]);
    if (regToken == null || regToken.isEmpty) {
      _lastError = '注册验证码校验成功，但未返回 regToken';
      return null;
    }
    return regToken;
  }

  Future<Map<String, dynamic>?> register(
    String phone,
    String username,
    String password,
    String confirmPassword,
    String regToken,
    int? cityCode,
  ) async {
    _lastError = null;
    final payload = <String, dynamic>{
      // Keep phone in method signature for flow coherence; API body follows Apifox.
      'username': username,
      'password': password,
      'confirmPassword': confirmPassword,
      if (cityCode != null) 'cityCode': cityCode.toString(),
      'regToken': regToken,
    };

    final response = await _postJson('/auth/register', payload);
    if (response == null) return null;

    final body = _decodeResponseBody(response);
    if (_isRequestSuccessful(response.statusCode, body)) {
      return body ?? <String, dynamic>{'code': 200, 'msg': '注册成功'};
    }

    _lastError = _extractErrorMessage(body, fallback: '注册失败');
    return body;
  }

  Future<User?> login(String phone, String password) async {
    _lastError = null;
    final response = await _postJson('/auth/login', <String, dynamic>{
      'phone': phone,
      'password': password,
    });
    if (response == null) return null;

    final body = _decodeResponseBody(response);
    if (!_isRequestSuccessful(response.statusCode, body)) {
      _lastError = _extractErrorMessage(body, fallback: '登录失败');
      return null;
    }

    final data = _extractDataMap(body);
    final accessToken = _extractStringField(data ?? body, const <String>[
      'accessToken',
      'token',
    ]);
    if (accessToken == null || accessToken.isEmpty) {
      _lastError = '登录成功，但响应中缺少 accessToken';
      return null;
    }

    final refreshToken = _extractStringField(data ?? body, const <String>[
      'refreshToken',
    ]);
    final tokenType = _extractStringField(data ?? body, const <String>[
      'tokenType',
    ]);
    final expiresInSeconds = _extractIntField(data ?? body, const <String>[
      'expiresInSeconds',
      'expiresIn',
    ]);

    return User(
      id:
          _extractStringField(data ?? body, const <String>['userId', 'id']) ??
          '',
      username:
          _extractStringField(data ?? body, const <String>['username']) ??
          phone,
      avatar: _extractStringField(data ?? body, const <String>['avatar']),
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType ?? 'Bearer',
      expiresInSeconds: expiresInSeconds ?? 1800,
    );
  }

  Future<bool> sendForgotPasswordCode(String phone) async {
    _lastError = null;
    final response = await _postJson(
      '/auth/password/forget/code',
      <String, dynamic>{'phone': phone},
    );
    if (response == null) return false;

    final body = _decodeResponseBody(response);
    if (_isRequestSuccessful(response.statusCode, body)) {
      return true;
    }

    _lastError = _extractErrorMessage(body, fallback: '发送找回密码验证码失败');
    return false;
  }

  Future<String?> verifyForgotPasswordCode(String phone, String code) async {
    _lastError = null;
    final response = await _postJson(
      '/auth/password/forget/verify',
      <String, dynamic>{'phone': phone, 'verifyCode': code},
    );
    if (response == null) return null;

    final body = _decodeResponseBody(response);
    if (!_isRequestSuccessful(response.statusCode, body)) {
      _lastError = _extractErrorMessage(body, fallback: '校验找回密码验证码失败');
      return null;
    }

    final resetToken = _extractStringField(body, const <String>[
      'resetToken',
      'token',
    ]);
    if (resetToken == null || resetToken.isEmpty) {
      _lastError = '验证码校验成功，但未返回 resetToken';
      return null;
    }
    return resetToken;
  }

  Future<bool> resetForgotPassword({
    required String password,
    required String confirmPassword,
    required String resetToken,
  }) async {
    _lastError = null;
    final response = await _putJson('/auth/password/forget', <String, dynamic>{
      'password': password,
      'confirmPassword': confirmPassword,
      'resetToken': resetToken,
    });
    if (response == null) return false;

    final body = _decodeResponseBody(response);
    if (_isRequestSuccessful(response.statusCode, body)) {
      return true;
    }

    _lastError = _extractErrorMessage(body, fallback: '重置密码失败');
    return false;
  }

  Future<User?> loginWithCode(String phone, String code) async {
    _lastError = '当前后端未提供验证码登录接口';
    return null;
  }

  Future<bool> logout(String token) async {
    // Apifox currently has no logout endpoint. Treat as local logout.
    _lastError = null;
    return true;
  }

  Future<bool> authPing(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ping/auth'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      );
      final body = _decodeResponseBody(response);
      if (_isRequestSuccessful(response.statusCode, body)) {
        return true;
      }
      _lastError = _extractErrorMessage(body, fallback: '认证状态校验失败');
      return false;
    } catch (_) {
      _lastError = '网络异常，请稍后重试';
      return false;
    }
  }

  Future<http.Response?> _postJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    return _sendJsonRequest('POST', path, payload);
  }

  Future<http.Response?> _putJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    return _sendJsonRequest('PUT', path, payload);
  }

  Future<http.Response?> _sendJsonRequest(
    String method,
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      if (method == 'POST') {
        return await http.post(
          uri,
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
      }
      if (method == 'PUT') {
        return await http.put(
          uri,
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
      }
      _lastError = '不支持的请求方法: $method';
      return null;
    } catch (_) {
      _lastError = '网络异常，请稍后重试';
      return null;
    }
  }

  Map<String, dynamic>? _decodeResponseBody(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      final dynamic raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) {
        return raw;
      }
      if (raw is Map) {
        return raw.cast<String, dynamic>();
      }
      return <String, dynamic>{'data': raw};
    } catch (_) {
      return null;
    }
  }

  bool _isRequestSuccessful(int statusCode, Map<String, dynamic>? body) {
    if (statusCode < 200 || statusCode >= 300) {
      return false;
    }
    if (body == null) {
      return true;
    }
    final code = _extractCode(body);
    if (code == null) {
      return true;
    }
    return code == 0 || code == 200;
  }

  int? _extractCode(Map<String, dynamic> body) {
    final dynamic code = body['code'];
    if (code is int) return code;
    if (code is String) return int.tryParse(code);
    return null;
  }

  String _extractErrorMessage(
    Map<String, dynamic>? body, {
    required String fallback,
  }) {
    if (body == null) {
      return fallback;
    }

    for (final key in const <String>['msg', 'message', 'error']) {
      final dynamic value = body[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }

    final data = _extractDataMap(body);
    if (data != null) {
      for (final key in const <String>['msg', 'message', 'error']) {
        final dynamic value = data[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }

    return fallback;
  }

  Map<String, dynamic>? _extractDataMap(Map<String, dynamic>? body) {
    if (body == null) return null;
    final dynamic data = body['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    return null;
  }

  String? _extractStringField(Map<String, dynamic>? body, List<String> keys) {
    if (body == null) return null;

    for (final key in keys) {
      final dynamic value = body[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }

    final data = _extractDataMap(body);
    if (data == null) return null;
    for (final key in keys) {
      final dynamic value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }

    return null;
  }

  int? _extractIntField(Map<String, dynamic>? body, List<String> keys) {
    if (body == null) return null;

    for (final key in keys) {
      final intValue = _toInt(body[key]);
      if (intValue != null) return intValue;
    }

    final data = _extractDataMap(body);
    if (data == null) return null;
    for (final key in keys) {
      final intValue = _toInt(data[key]);
      if (intValue != null) return intValue;
    }

    return null;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
