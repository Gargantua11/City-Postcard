import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/custom_text_field.dart';
import 'register_step2_screen.dart';

class RegisterStep1Screen extends StatefulWidget {
  const RegisterStep1Screen({super.key});

  @override
  State<RegisterStep1Screen> createState() => _RegisterStep1ScreenState();
}

class _RegisterStep1ScreenState extends State<RegisterStep1Screen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  bool _canSendCode = true;
  bool _isSendingCode = false;
  bool _isVerifying = false;
  int _countdown = 60;

  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
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

  Future<void> _sendCode() async {
    if (!_canSendCode || _isSendingCode || _isVerifying) return;

    final phone = _phoneController.text.trim();
    final phoneError = _validatePhone(phone);
    if (phoneError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(phoneError)));
      return;
    }

    setState(() {
      _isSendingCode = true;
    });

    final sent = await _authService.sendRegisterCode(phone);
    if (!mounted) return;

    setState(() {
      _isSendingCode = false;
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

  Future<void> _nextStep() async {
    if (_isVerifying || _isSendingCode) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final phone = _phoneController.text.trim();
    final verifyCode = _codeController.text.trim();

    setState(() {
      _isVerifying = true;
    });

    final regToken = await _authService.verifyRegisterCode(phone, verifyCode);
    if (!mounted) return;

    setState(() {
      _isVerifying = false;
    });

    if (regToken == null || regToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authService.lastError ?? '验证码校验失败，请重试')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            RegisterStep2Screen(phone: phone, regToken: regToken),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('注册 - 第一步'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomTextField(
                      controller: _phoneController,
                      hintText: '请输入手机号',
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                      enabled: !_isVerifying,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _codeController,
                      hintText: '请输入验证码',
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      validator: _validateCode,
                      enabled: !_isVerifying,
                      suffixIcon: TextButton(
                        onPressed:
                            (_canSendCode && !_isSendingCode && !_isVerifying)
                            ? _sendCode
                            : null,
                        child: Text(
                          _canSendCode
                              ? (_isSendingCode ? '发送中...' : '获取验证码')
                              : '${_countdown}s',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: (_isVerifying || _isSendingCode)
                          ? null
                          : _nextStep,
                      child: _isVerifying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('下一步'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
