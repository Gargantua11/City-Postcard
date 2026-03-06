import 'package:flutter/foundation.dart';

import '../data/city_code_name.dart';
import '../models/user.dart';
import 'auth_service.dart';
import 'storage_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

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
      if (savedUser != null && savedUser.accessToken.trim().isNotEmpty) {
        _user = savedUser;
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
        final hydrated = await _storageService.hydrateUserProfileForLogin(user);
        _user = hydrated;
        await _storageService.saveUser(hydrated);
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
        final hydrated = await _storageService.hydrateUserProfileForLogin(user);
        _user = hydrated;
        await _storageService.saveUser(hydrated);
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
}
