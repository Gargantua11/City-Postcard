import 'package:flutter/foundation.dart';

import '../data/city_code_name.dart';
import '../models/user.dart';
import 'auth_service.dart';
import 'backend_api_client.dart';
import 'edited_postcard_service.dart';
import 'postcard_data_refresh_bus.dart';
import 'storage_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  final AuthService _authService = AuthService();
  final BackendApiClient _apiClient = BackendApiClient();
  final StorageService _storageService = StorageService();
  final EditedPostcardService _editedPostcardService = EditedPostcardService();

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  bool get isAuthenticated =>
      _user != null && _user!.accessToken.trim().isNotEmpty;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final savedUser = await _storageService.getUser();
      final savedToken = await _storageService.getToken();
      final normalizedToken = savedToken?.trim() ?? '';

      if (savedUser != null) {
        final userToken = savedUser.accessToken.trim();
        if (userToken.isNotEmpty) {
          _user = savedUser;
        } else if (normalizedToken.isNotEmpty) {
          _user = savedUser.copyWith(accessToken: normalizedToken);
          await _storageService.saveUser(_user!);
        }
      } else if (normalizedToken.isNotEmpty) {
        _user = User(
          id: '',
          username: '',
          accessToken: normalizedToken,
          tokenType: 'Bearer',
          expiresInSeconds: 1800,
        );
      }
    } catch (e) {
      _error = '初始化登录状态失败';
      debugPrint('初始化登录状态失败: $e');
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> register(
    String phone,
    String username,
    String password,
    String confirmPassword,
    String regToken,
    int? cityCode,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.register(
        phone,
        username,
        password,
        confirmPassword,
        regToken,
        cityCode,
      );

      if (result == null) {
        _error = _authService.lastError ?? '注册失败，请稍后重试';
        return null;
      }

      final code = _toInt(result['code']);
      final success = code == null || code == 0 || code == 200;
      if (!success) {
        _error = result['msg']?.toString() ?? _authService.lastError ?? '注册失败';
      } else {
        await _persistRegistrationProfile(
          phone: phone,
          username: username,
          cityCode: cityCode,
        );
      }

      return result;
    } catch (e) {
      _error = '注册失败: $e';
      debugPrint('注册失败: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.login(phone, password);
      if (user != null) {
        await _storageService.saveUser(user);
        final enriched = await _enrichUserFromBackend(user);
        final hydrated = await _storageService.hydrateUserProfileForLogin(
          enriched,
        );
        _user = hydrated;
        await _storageService.saveUser(hydrated);
        await _syncEditedPostcardsOnLogin(hydrated);
        return true;
      }

      _error = _authService.lastError ?? '登录失败，请检查手机号和密码';
      return false;
    } catch (e) {
      _error = '登录失败: $e';
      debugPrint('登录失败: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithCode(String phone, String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.loginWithCode(phone, code);
      if (user != null) {
        await _storageService.saveUser(user);
        final enriched = await _enrichUserFromBackend(user);
        final hydrated = await _storageService.hydrateUserProfileForLogin(
          enriched,
        );
        _user = hydrated;
        await _storageService.saveUser(hydrated);
        await _syncEditedPostcardsOnLogin(hydrated);
        return true;
      }

      _error = _authService.lastError ?? '登录失败，请检查验证码';
      return false;
    } catch (e) {
      _error = '登录失败: $e';
      debugPrint('登录失败: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_user != null) {
        await _authService.logout(_user!.accessToken);
      }
      await _storageService.clearUser();
      _user = null;
    } catch (e) {
      _error = '退出登录失败';
      debugPrint('退出登录失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _syncEditedPostcardsOnLogin(User user) async {
    try {
      final changed = await _editedPostcardService
          .syncOwnedPostcardsFromBackendOnLogin(
            userId: user.id,
            username: user.username,
          );
      if (changed > 0) {
        PostcardDataRefreshBus.notifySaved();
      }
    } catch (_) {}
  }

  Future<User> _enrichUserFromBackend(User baseUser) async {
    var nextUsername = baseUser.username.trim();
    var nextAvatar = baseUser.avatar?.trim() ?? '';
    var nextCityName = baseUser.cityName?.trim() ?? '';
    var nextCityCode = baseUser.cityCode?.trim() ?? '';

    try {
      final pingBody = await _apiClient.get('/ping/auth', requireAuth: true);
      final nickname = _extractNicknameFromAuthPing(pingBody);
      if (nickname != null && nickname.isNotEmpty) {
        nextUsername = nickname;
      }
    } catch (_) {}

    try {
      final cityBody = await _apiClient.get('/me/city', requireAuth: true);
      final cityName = _extractCityName(cityBody);
      final cityCode = _extractCityCode(cityBody);
      if (cityName != null && cityName.isNotEmpty) {
        nextCityName = cityName;
      }
      if (cityCode != null && cityCode.isNotEmpty) {
        nextCityCode = cityCode;
      } else if (nextCityCode.isEmpty && nextCityName.isNotEmpty) {
        final inferred = _findCityCodeByName(nextCityName);
        if (inferred != null && inferred.isNotEmpty) {
          nextCityCode = inferred;
        }
      }
    } catch (_) {}

    try {
      final avatarBody = await _apiClient.get('/me/avatar', requireAuth: true);
      final avatar = _extractAvatarSource(avatarBody);
      if (avatar != null && avatar.isNotEmpty) {
        nextAvatar = avatar;
      }
    } catch (_) {}

    return baseUser.copyWith(
      username: nextUsername,
      avatar: nextAvatar,
      cityName: nextCityName.isEmpty ? null : nextCityName,
      cityCode: nextCityCode.isEmpty ? null : nextCityCode,
    );
  }

  String? _extractNicknameFromAuthPing(Map<String, dynamic> body) {
    final direct = _extractMessageText(body);
    final fromDirect = _parseNicknameFromPingMessage(direct);
    if (fromDirect != null && fromDirect.isNotEmpty) {
      return fromDirect;
    }

    final data = BackendApiClient.extractData(body);
    if (data is String) {
      final fromData = _parseNicknameFromPingMessage(data);
      if (fromData != null && fromData.isNotEmpty) {
        return fromData;
      }
    }
    return null;
  }

  String? _parseNicknameFromPingMessage(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;

    final matched = RegExp(
      r'auth\s+ping\s+success,\s*\S+\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (matched != null) {
      final nickname = matched.group(1)?.trim() ?? '';
      if (nickname.isNotEmpty) return nickname;
    }

    final commaIndex = text.lastIndexOf(',');
    if (commaIndex >= 0 && commaIndex < text.length - 1) {
      final tail = text.substring(commaIndex + 1).trim();
      final parts = tail
          .split(RegExp(r'\s+'))
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false);
      if (parts.length >= 2) {
        final nickname = parts.sublist(1).join(' ').trim();
        if (nickname.isNotEmpty) return nickname;
      }
    }

    if (text.toLowerCase().contains('auth ping success')) {
      return null;
    }
    return text;
  }

  String _extractMessageText(Map<String, dynamic> body) {
    for (final key in const <String>['msg', 'message', 'detail']) {
      final value = body[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String? _extractCityName(Map<String, dynamic> body) {
    final data = BackendApiClient.extractData(body);
    if (data is String) {
      final text = data.trim();
      if (text.isNotEmpty) {
        final parsed = _parseCityCodeAndName(text);
        final parsedName = parsed.cityName?.trim() ?? '';
        if (parsedName.isNotEmpty) return parsedName;
        final parsedCode = parsed.cityCode?.trim() ?? '';
        if (parsedCode.isNotEmpty) {
          final mapped = kCityCodeNames[parsedCode]?.trim() ?? '';
          if (mapped.isNotEmpty) return mapped;
        }
        return text;
      }
    }

    final map = BackendApiClient.asMap(data) ?? body;
    final rawCityName = BackendApiClient.readString(map, const <String>[
      'cityName',
      'city',
      'location',
      'address',
      'value',
    ]);
    final normalizedRawName = rawCityName?.trim() ?? '';
    if (normalizedRawName.isNotEmpty) {
      final parsed = _parseCityCodeAndName(normalizedRawName);
      final parsedName = parsed.cityName?.trim() ?? '';
      if (parsedName.isNotEmpty) return parsedName;
    }
    return rawCityName;
  }

  String? _extractCityCode(Map<String, dynamic> body) {
    final data = BackendApiClient.extractData(body);
    if (data is String) {
      final parsed = _parseCityCodeAndName(data);
      if (parsed.cityCode != null && parsed.cityCode!.isNotEmpty) {
        return parsed.cityCode;
      }
    }

    final map = BackendApiClient.asMap(data) ?? body;

    final codeText = BackendApiClient.readString(map, const <String>[
      'cityCode',
      'code',
      'adCode',
      'value',
    ]);
    final codeInt = BackendApiClient.readInt(map, const <String>[
      'cityCode',
      'code',
      'adCode',
      'value',
    ]);
    final raw = codeText ?? (codeInt?.toString() ?? '');
    final digits = raw.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      return _normalizeCityCodeDigits(digits);
    }

    final rawCityName =
        BackendApiClient.readString(map, const <String>['cityName', 'city']) ??
        '';
    final parsed = _parseCityCodeAndName(rawCityName);
    return parsed.cityCode;
  }

  String? _extractAvatarSource(Map<String, dynamic> body) {
    final data = BackendApiClient.extractData(body);
    if (data is String) {
      final text = data.trim();
      if (text.isNotEmpty) return text;
    }

    final map = BackendApiClient.asMap(data) ?? body;
    return BackendApiClient.readString(map, const <String>[
      'avatarUrl',
      'avatar',
      'avatarKey',
      'key',
      'objectKey',
      'fileKey',
      'path',
      'url',
      'value',
    ]);
  }

  String? _findCityCodeByName(String cityName) {
    final parsed = _parseCityCodeAndName(cityName);
    final parsedCode = parsed.cityCode?.trim() ?? '';
    if (parsedCode.isNotEmpty) return parsedCode;

    final normalized = _sanitizeCityNameForMatch(cityName);
    if (normalized.isEmpty) return null;

    for (final entry in kCityCodeNames.entries) {
      if (_sanitizeCityNameForMatch(entry.value) == normalized) {
        return entry.key;
      }
    }
    for (final entry in kCityCodeNames.entries) {
      final candidate = _sanitizeCityNameForMatch(entry.value);
      if (candidate.isEmpty) continue;
      if (candidate.contains(normalized) || normalized.contains(candidate)) {
        return entry.key;
      }
    }
    return null;
  }

  Future<void> _persistRegistrationProfile({
    required String phone,
    required String username,
    required int? cityCode,
  }) async {
    final normalizedPhone = phone.trim();
    if (normalizedPhone.isNotEmpty) {
      await _storageService.saveProfilePhone(normalizedPhone);
    }

    final normalizedUsername = username.trim();
    if (normalizedUsername.isNotEmpty) {
      await _storageService.saveProfileNickname(normalizedUsername);
    }

    final cityCodeText = cityCode?.toString().trim() ?? '';
    if (cityCodeText.isEmpty) return;

    final cityName = kCityCodeNames[cityCodeText]?.trim() ?? '';
    if (cityName.isEmpty) return;

    await _storageService.saveProfileCity(
      cityName: cityName,
      cityCode: cityCodeText,
    );
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _normalizeCityCodeDigits(String rawDigits) {
    final digits = rawDigits.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';

    final candidates = <String>[];
    if (digits.length >= 6) {
      candidates.add(digits.substring(0, 6));
    }
    if (digits.length >= 4) {
      candidates.add(digits.substring(0, 4));
    }
    candidates.add(digits);

    for (final candidate in candidates) {
      if (kCityCodeNames.containsKey(candidate)) {
        return candidate;
      }
    }
    return candidates.first;
  }

  _ParsedCityCodeAndName _parseCityCodeAndName(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return const _ParsedCityCodeAndName(cityCode: null, cityName: null);
    }

    final directCode = RegExp(r'^\d{4,6}$').firstMatch(text);
    if (directCode != null) {
      final code = _normalizeCityCodeDigits(text);
      final mapped = kCityCodeNames[code]?.trim();
      return _ParsedCityCodeAndName(
        cityCode: code.isEmpty ? null : code,
        cityName: (mapped == null || mapped.isEmpty) ? null : mapped,
      );
    }

    final codeMatch = RegExp(r'(\d{4,6})').firstMatch(text);
    final rawCode = codeMatch?.group(1)?.trim() ?? '';
    final normalizedCode = rawCode.isEmpty ? '' : _normalizeCityCodeDigits(rawCode);
    final noCodeText = rawCode.isEmpty ? text : text.replaceFirst(rawCode, '');
    final name = _sanitizeCityNameForMatch(noCodeText);
    final mapped = normalizedCode.isEmpty
        ? null
        : (kCityCodeNames[normalizedCode]?.trim());

    return _ParsedCityCodeAndName(
      cityCode: normalizedCode.isEmpty ? null : normalizedCode,
      cityName: name.isNotEmpty ? name : ((mapped ?? '').isEmpty ? null : mapped),
    );
  }

  String _sanitizeCityNameForMatch(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '';
    value = value.replaceAll(RegExp(r'\d+'), '');
    value = value.replaceAll(RegExp(r'[\s,，;；:：/\\|_\-]+'), '');
    return value.trim();
  }
}

class _ParsedCityCodeAndName {
  const _ParsedCityCodeAndName({required this.cityCode, required this.cityName});

  final String? cityCode;
  final String? cityName;
}
