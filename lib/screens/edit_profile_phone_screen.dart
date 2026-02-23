import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../widgets/custom_text_field.dart';

class EditProfilePhoneScreen extends StatefulWidget {
  const EditProfilePhoneScreen({super.key});

  @override
  State<EditProfilePhoneScreen> createState() => _EditProfilePhoneScreenState();
}

class _EditProfilePhoneScreenState extends State<EditProfilePhoneScreen> {
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSendingCode = false;
  bool _canSendCode = true;
  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final phone = await _storageService.getProfilePhone();
    if (!mounted) return;

    _phoneController.text = (phone ?? '').trim();
    setState(() {
      _isLoading = false;
    });
  }

  String? _validatePhone(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return '请输入手机号';
    }
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(text)) {
      return '请输入正确的手机号';
    }
    return null;
  }

  String? _validateCode(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return '请输入验证码';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(text)) {
      return '验证码为6位数字';
    }
    return null;
  }

  Future<void> _sendCode() async {
    if (!_canSendCode || _isSendingCode || _isSaving) return;

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
          _countdown = 60;
          _canSendCode = true;
        });
      }
    });
  }

  Future<void> _save() async {
    if (_isSaving || _isSendingCode) return;
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();

    setState(() {
      _isSaving = true;
    });

    try {
      final regToken = await _authService.verifyRegisterCode(phone, code);
      if (!mounted) return;
      if (regToken == null || regToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_authService.lastError ?? '验证码校验失败，请重试')),
        );
        return;
      }

      await _storageService.saveProfilePhone(phone);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 56),
                            const Text(
                              '修改手机号',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2E3A2A),
                              ),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: 300,
                              child: CustomTextField(
                                controller: _phoneController,
                                hintText: '请输入11位手机号',
                                prefixIcon: Icons.phone,
                                keyboardType: TextInputType.phone,
                                maxLength: 11,
                                validator: _validatePhone,
                                enabled: !_isSaving,
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: 300,
                              child: CustomTextField(
                                controller: _codeController,
                                hintText: '请输入验证码',
                                prefixIcon: Icons.verified_user_outlined,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                validator: _validateCode,
                                enabled: !_isSaving,
                                suffixIcon: TextButton(
                                  onPressed:
                                      (_canSendCode &&
                                          !_isSendingCode &&
                                          !_isSaving)
                                      ? _sendCode
                                      : null,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    _canSendCode
                                        ? (_isSendingCode ? '发送中...' : '获取验证码')
                                        : '等待${_countdown}s',
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
                            const SizedBox(height: 28),
                            _ActionButton(isLoading: _isSaving, onTap: _save),
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

class _ActionButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: SizedBox(
        height: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/auth/注册2-完成.png'),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              child: SizedBox.expand(),
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
