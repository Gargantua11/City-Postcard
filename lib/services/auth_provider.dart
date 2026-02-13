import 'package:flutter/material.dart';
import '../models/user.dart';
import './auth_service.dart';
import './storage_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final savedUser = await _storageService.getUser();
      if (savedUser != null) {
        _user = savedUser;
      }
    } catch (e) {
      _error = '初始化认证状态失败';
      print('初始化认证状态失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> register(
    String username,
    String password,
    String confirmPassword,
    int? cityCode,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.register(
        username,
        password,
        confirmPassword,
        cityCode,
      );

      if (result == null) {
        _error = _authService.lastError ?? '注册失败，请稍后重试';
        return null;
      }

      if (result['code'] != 0) {
        _error = result['msg']?.toString() ?? _authService.lastError ?? '注册失败';
      }

      return result;
    } catch (e) {
      _error = '注册失败: $e';
      print('注册失败: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.login(username, password);
      if (user != null) {
        _user = user;
        await _storageService.saveUser(user);
        return true;
      }

      _error = _authService.lastError ?? '登录失败，请检查用户名和密码';
      return false;
    } catch (e) {
      _error = '登录失败: $e';
      print('登录失败: $e');
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
        _user = user;
        await _storageService.saveUser(user);
        return true;
      }

      _error = '登录失败，请检查验证码';
      return false;
    } catch (e) {
      _error = '登录失败: $e';
      print('登录失败: $e');
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
      _error = '登出失败';
      print('登出失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
