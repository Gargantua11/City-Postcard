import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/custom_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _canSendCode = true;
  bool _isSubmitting = false;
  int _countdown = 60;

  Timer? _timer;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '请输入手机号';
    }
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(text)) {
      return '请输入正确的手机号';
    }
    return null;
  }

  String? _validateCode(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '请输入验证码';
    }
    if (text.length != 6) {
      return '验证码应为6位';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return '请输入新密码';
    }
    if (text.length < 6 || text.length > 24) {
      return '密码长度应为6-24位';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return '请再次输入密码';
    }
    if (text != _passwordController.text) {
      return '两次输入的密码不一致';
    }
    return null;
  }

  Future<void> _sendCode() async {
    if (!_canSendCode || _isSubmitting) {
      return;
    }

    final phoneError = _validatePhone(_phoneController.text.trim());
    if (phoneError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(phoneError)));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final sent = await _authService.sendForgotPasswordCode(
      _phoneController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (!sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authService.lastError ?? '验证码发送失败，请稍后重试')),
      );
      return;
    }

    setState(() {
      _canSendCode = false;
      _countdown = 60;
    });

    _startCountdown();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('验证码已发送')));
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _countdown -= 1;
      });

      if (_countdown <= 0) {
        timer.cancel();
        setState(() {
          _canSendCode = true;
          _countdown = 60;
        });
      }
    });
  }

  Future<void> _resetPassword() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      _isSubmitting = true;
    });

    final resetToken = await _authService.verifyForgotPasswordCode(phone, code);
    if (!mounted) return;

    if (resetToken == null || resetToken.isEmpty) {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authService.lastError ?? '验证码校验失败')),
      );
      return;
    }

    final resetSuccess = await _authService.resetForgotPassword(
      password: password,
      confirmPassword: confirmPassword,
      resetToken: resetToken,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (!resetSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authService.lastError ?? '重置密码失败，请重试')),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('密码已重置，请登录')));
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/auth/注册1-背景.png'),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 20,
              left: 5,
              child: GestureDetector(
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: Container(
                  width: 80,
                  height: 30,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/auth/注册2-返回.png'),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 30),
                      Container(
                        width: 150,
                        height: 50,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/images/auth/找回密码.png'),
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: SizedBox(
                          width: 300,
                          child: CustomTextField(
                            controller: _phoneController,
                            hintText: '请输入手机号',
                            keyboardType: TextInputType.phone,
                            validator: _validatePhone,
                            enabled: !_isSubmitting,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Center(
                        child: SizedBox(
                          width: 300,
                          child: CustomTextField(
                            controller: _codeController,
                            hintText: '请输入验证码',
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            validator: _validateCode,
                            enabled: !_isSubmitting,
                            suffixIcon: TextButton(
                              onPressed: (_canSendCode && !_isSubmitting)
                                  ? _sendCode
                                  : null,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                _canSendCode ? '获取验证码' : '等待${_countdown}s',
                                style: TextStyle(
                                  color: _canSendCode
                                      ? Colors.blue
                                      : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Center(
                        child: SizedBox(
                          width: 300,
                          child: CustomTextField(
                            controller: _passwordController,
                            hintText: '请输入新密码',
                            obscureText: _obscurePassword,
                            prefixIcon: Icons.lock,
                            validator: _validatePassword,
                            enabled: !_isSubmitting,
                            suffixIcon: IconButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Center(
                        child: SizedBox(
                          width: 300,
                          child: CustomTextField(
                            controller: _confirmPasswordController,
                            hintText: '请再次输入密码',
                            obscureText: _obscureConfirmPassword,
                            prefixIcon: Icons.lock_outline,
                            validator: _validateConfirmPassword,
                            enabled: !_isSubmitting,
                            suffixIcon: IconButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      GestureDetector(
                        onTap: _isSubmitting ? null : _resetPassword,
                        child: SizedBox(
                          height: 70,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage(
                                      'assets/images/auth/注册2-完成.png',
                                    ),
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                                child: SizedBox.expand(),
                              ),
                              if (_isSubmitting)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
