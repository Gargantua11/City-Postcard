import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';

class AuthService {
  static const String _baseUrl = 'http://localhost:8080'; // 后端API地址

  // 发送验证码
  Future<bool> sendVerificationCode(String phone) async {
    try {
      // 模拟API调用
      await Future.delayed(Duration(seconds: 1));
      print('验证码已发送到 $phone');
      return true;
    } catch (e) {
      print('发送验证码失败: $e');
      return false;
    }
  }

  // 验证验证码
  Future<bool> verifyCode(String phone, String code) async {
    try {
      // 模拟API调用
      await Future.delayed(Duration(seconds: 1));
      // 模拟验证成功
      return code == '123456';
    } catch (e) {
      print('验证验证码失败: $e');
      return false;
    }
  }

  // 注册
  Future<Map<String, dynamic>?> register(
    String username,
    String password,
    String confirmPassword,
    int? cityCode,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'confirmPassword': confirmPassword,
          if (cityCode != null) 'cityCode': cityCode,
        }),
      );

      final data = jsonDecode(response.body);
      print('注册响应: $data');

      return data;
    } catch (e) {
      print('注册失败: $e');
      return null;
    }
  }

  // 登录
  Future<User?> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = jsonDecode(response.body);
      print('登录响应: $data');

      if (data['code'] == 0 && data['data'] != null) {
        return User(
          id: data['data']['userId']?.toString() ?? '',
          username: data['data']['username'] ?? username,
          avatar: null,
          accessToken: data['data']['accessToken'],
          refreshToken: data['data']['refreshToken'],
          tokenType: data['data']['tokenType'],
          expiresInSeconds: data['data']['expiresInSeconds'],
        );
      }
      return null;
    } catch (e) {
      print('登录失败: $e');
      return null;
    }
  }

  // 验证码登录
  Future<User?> loginWithCode(String phone, String code) async {
    try {
      // 模拟API调用
      await Future.delayed(Duration(seconds: 1));

      // 模拟返回数据
      final mockUser = User(
        id: '1',
        username: phone,
        avatar: null,
        accessToken: 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
        refreshToken: null,
        tokenType: 'Bearer',
        expiresInSeconds: 1800,
      );

      return mockUser;
    } catch (e) {
      print('验证码登录失败: $e');
      return null;
    }
  }

  // 登出
  Future<bool> logout(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      print('登出响应: $data');

      return data['code'] == 0;
    } catch (e) {
      print('登出失败: $e');
      return false;
    }
  }
}
