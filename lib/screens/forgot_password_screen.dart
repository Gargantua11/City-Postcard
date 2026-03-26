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
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isSendingCode = false;
  bool _isVerifying = false;
  bool _canSendCode = true;
  int _countdown = 60;
  Timer? _timer;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '请输入手机号';
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(text)) return '请输入正确的手机号';
    return null;
  }

  String? _validateCode(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '请输入验证码';
    if (!RegExp(r'^\d{6}$').hasMatch(text)) return '验证码为6位数字';
    return null;
  }

  Future<void> _sendCode() async {
    if (_isSendingCode || _isVerifying || !_canSendCode) return;

    final phone = _phoneController.text.trim();
    final phoneError = _validatePhone(phone);
    if (phoneError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(phoneError)),
      );
      return;
    }

    setState(() {
      _isSendingCode = true;
    });

    final success = await _authService.sendForgotPasswordCode(phone);
    if (!mounted) return;

    if (!success) {
      setState(() {
        _isSendingCode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authService.lastError ?? '验证码发送失败，请稍后重试')),
      );
      return;
    }

    setState(() {
      _isSendingCode = false;
      _canSendCode = false;
      _countdown = 60;
    });
    _startCountdown();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('验证码已发送')),
    );
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
          _countdown = 60;
          _canSendCode = true;
        });
      }
    });
  }

  Future<void> _verifyCodeAndNext() async {
    if (_isVerifying || _isSendingCode) return;
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();

    setState(() {
      _isVerifying = true;
    });

    final resetToken = await _authService.verifyForgotPasswordCode(phone, code);
    if (!mounted) return;

    setState(() {
      _isVerifying = false;
    });

    if (resetToken == null || resetToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authService.lastError ?? '验证码校验失败')),
      );
      return;
    }

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ForgotPasswordResetScreen(
          phone: phone,
          resetToken: resetToken,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/auth/注册2-背景.png'),
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
                onTap: () => Navigator.pop(context),
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
                      const SizedBox(height: 56),
                      const Text(
                        '找回密码',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E3A2A),
                        ),
                      ),
                      const SizedBox(height: 28),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: CustomTextField(
                          controller: _phoneController,
                          hintText: '请输入手机号',
                          keyboardType: TextInputType.phone,
                          maxLength: 11,
                          prefixIcon: Icons.phone,
                          validator: _validatePhone,
                          enabled: !_isVerifying,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: CustomTextField(
                          controller: _codeController,
                          hintText: '请输入验证码',
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          prefixIcon: Icons.verified_user_outlined,
                          validator: _validateCode,
                          enabled: !_isVerifying,
                          suffixIcon: TextButton(
                            onPressed:
                                (_canSendCode && !_isSendingCode && !_isVerifying)
                                ? _sendCode
                                : null,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              _canSendCode
                                  ? (_isSendingCode ? '发送中...' : '获取验证码')
                                  : '等待${_countdown}s',
                              style: TextStyle(
                                color: _canSendCode ? Colors.blue : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _ImageActionButton(
                        imageAssetPath: 'assets/images/auth/注册1-下一步.png',
                        isLoading: _isVerifying,
                        onTap: _verifyCodeAndNext,
                      ),
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

class _ForgotPasswordResetScreen extends StatefulWidget {
  const _ForgotPasswordResetScreen({
    required this.phone,
    required this.resetToken,
  });

  final String phone;
  final String resetToken;

  @override
  State<_ForgotPasswordResetScreen> createState() =>
      _ForgotPasswordResetScreenState();
}

class _ForgotPasswordResetScreenState extends State<_ForgotPasswordResetScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return '请输入新密码';
    if (text.length < 6 || text.length > 24) return '密码长度应为6-24位';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return '请再次输入密码';
    if (text != _passwordController.text) return '两次输入的密码不一致';
    return null;
  }

  Future<void> _submitReset() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final success = await _authService.resetForgotPassword(
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      resetToken: widget.resetToken,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authService.lastError ?? '重置密码失败，请重试')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('密码重置成功，请重新登录')),
    );
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  String _maskedPhone(String phone) {
    final normalized = phone.trim();
    if (normalized.length != 11) return normalized;
    return '${normalized.substring(0, 3)}****${normalized.substring(7)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/auth/注册2-背景.png'),
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
                onTap: () => Navigator.pop(context),
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
                      const SizedBox(height: 56),
                      const Text(
                        '设置新密码',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E3A2A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '账号：${_maskedPhone(widget.phone)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF5A6554),
                        ),
                      ),
                      const SizedBox(height: 28),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: CustomTextField(
                          controller: _passwordController,
                          hintText: '请输入新密码',
                          prefixIcon: Icons.lock,
                          obscureText: _obscurePassword,
                          validator: _validatePassword,
                          enabled: !_isSaving,
                          suffixIcon: IconButton(
                            onPressed: _isSaving
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
                      const SizedBox(height: 14),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: CustomTextField(
                          controller: _confirmPasswordController,
                          hintText: '请再次输入密码',
                          prefixIcon: Icons.lock_outline,
                          obscureText: _obscureConfirmPassword,
                          validator: _validateConfirmPassword,
                          enabled: !_isSaving,
                          suffixIcon: IconButton(
                            onPressed: _isSaving
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
                      const SizedBox(height: 28),
                      _ImageActionButton(
                        imageAssetPath: 'assets/images/auth/注册2-完成.png',
                        isLoading: _isSaving,
                        onTap: _submitReset,
                      ),
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

class _ImageActionButton extends StatelessWidget {
  const _ImageActionButton({
    required this.imageAssetPath,
    required this.isLoading,
    required this.onTap,
  });

  final String imageAssetPath;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: SizedBox(
        height: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(imageAssetPath),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              child: const SizedBox.expand(),
            ),
            if (isLoading)
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
    );
  }
}
