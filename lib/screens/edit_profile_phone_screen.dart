import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/backend_api_client.dart';
import '../services/storage_service.dart';
import '../widgets/custom_text_field.dart';

class EditProfilePhoneScreen extends StatefulWidget {
  const EditProfilePhoneScreen({super.key});

  @override
  State<EditProfilePhoneScreen> createState() => _EditProfilePhoneScreenState();
}

class _EditProfilePhoneScreenState extends State<EditProfilePhoneScreen> {
  final StorageService _storageService = StorageService();
  final _PhoneChangeApiService _apiService = _PhoneChangeApiService();
  final TextEditingController _oldPhoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isChecking = false;
  String _storedPhone = '';

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _oldPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final phone = (await _storageService.getProfilePhone())?.trim() ?? '';
    if (!mounted) return;
    setState(() {
      _storedPhone = phone;
      _isLoading = false;
    });
  }

  String? _validatePhone(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return '请输入原手机号';
    }
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(text)) {
      return '请输入正确的手机号';
    }
    return null;
  }

  String _maskPhone(String phone) {
    final normalized = phone.trim();
    if (normalized.length != 11) return normalized;
    return '${normalized.substring(0, 3)}****${normalized.substring(7)}';
  }

  Future<void> _goNext() async {
    if (_isChecking) return;
    if (!_formKey.currentState!.validate()) return;

    final oldPhone = _oldPhoneController.text.trim();
    if (_storedPhone.isNotEmpty && oldPhone != _storedPhone) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('输入手机号与当前账号手机号不一致')));
      return;
    }

    setState(() {
      _isChecking = true;
    });

    try {
      await _apiService.checkOriginalPhone(oldPhone);
      if (!mounted) return;

      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              _EditProfilePhoneChangeScreen(originalPhone: oldPhone),
        ),
      );
      if (!mounted) return;
      if (changed == true) {
        Navigator.pop(context, true);
      }
    } on BackendApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('校验原手机号失败，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
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
                              '验证原手机号',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2E3A2A),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_storedPhone.isNotEmpty)
                              Text(
                                '当前绑定：${_maskPhone(_storedPhone)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF5A6554),
                                ),
                              ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: 300,
                              child: CustomTextField(
                                controller: _oldPhoneController,
                                hintText: '请输入完整原手机号',
                                prefixIcon: Icons.phone,
                                keyboardType: TextInputType.phone,
                                maxLength: 11,
                                validator: _validatePhone,
                                enabled: !_isChecking,
                              ),
                            ),
                            const SizedBox(height: 28),
                            _ImageActionButton(
                              imageAssetPath: 'assets/images/auth/注册1-下一步.png',
                              isLoading: _isChecking,
                              onTap: _goNext,
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

class _EditProfilePhoneChangeScreen extends StatefulWidget {
  const _EditProfilePhoneChangeScreen({required this.originalPhone});

  final String originalPhone;

  @override
  State<_EditProfilePhoneChangeScreen> createState() =>
      _EditProfilePhoneChangeScreenState();
}

class _EditProfilePhoneChangeScreenState
    extends State<_EditProfilePhoneChangeScreen> {
  final StorageService _storageService = StorageService();
  final _PhoneChangeApiService _apiService = _PhoneChangeApiService();
  final TextEditingController _newPhoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  bool _isSendingCode = false;
  bool _canSendCode = true;
  int _countdown = 60;
  Timer? _timer;

  @override
  void dispose() {
    _newPhoneController.dispose();
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return '请输入新手机号';
    }
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(text)) {
      return '请输入正确的手机号';
    }
    if (text == widget.originalPhone) {
      return '新手机号不能与原手机号一致';
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

    final phone = _newPhoneController.text.trim();
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

    try {
      await _apiService.sendChangePhoneCode(phone);
      if (!mounted) return;

      setState(() {
        _isSendingCode = false;
        _canSendCode = false;
        _countdown = 60;
      });
      _startCountdown();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('验证码已发送')));
    } on BackendApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingCode = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSendingCode = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('验证码发送失败，请稍后重试')));
    }
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

  Future<void> _finishChange() async {
    if (_isSaving || _isSendingCode) return;
    if (!_formKey.currentState!.validate()) return;

    final newPhone = _newPhoneController.text.trim();
    final code = _codeController.text.trim();

    setState(() {
      _isSaving = true;
    });

    try {
      await _apiService.changePhone(
        originalPhone: widget.originalPhone,
        newPhone: newPhone,
        verifyCode: code,
      );
      await _storageService.saveProfilePhone(newPhone);

      if (!mounted) return;
      Navigator.pop(context, true);
    } on BackendApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('修改手机号失败，请稍后重试')));
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
              child: Padding(
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
                          controller: _newPhoneController,
                          hintText: '请输入要更改的手机号',
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
                                (_canSendCode && !_isSendingCode && !_isSaving)
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
                        imageAssetPath: 'assets/images/auth/注册2-完成.png',
                        isLoading: _isSaving,
                        onTap: _finishChange,
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

class _PhoneChangeApiService {
  final BackendApiClient _apiClient = BackendApiClient();

  Future<void> checkOriginalPhone(String phone) async {
    await _postWithFallback('/me/phone/check', <Map<String, dynamic>>[
      <String, dynamic>{'phone': phone},
      <String, dynamic>{'oldPhone': phone},
      <String, dynamic>{'originPhone': phone},
    ], defaultError: '原手机号校验失败');
  }

  Future<void> sendChangePhoneCode(String phone) async {
    await _postWithFallback('/me/phone/code', <Map<String, dynamic>>[
      <String, dynamic>{'phone': phone},
      <String, dynamic>{'newPhone': phone},
    ], defaultError: '验证码发送失败');
  }

  Future<void> changePhone({
    required String originalPhone,
    required String newPhone,
    required String verifyCode,
  }) async {
    final verifyResponse = await _postWithFallback(
      '/me/phone/verify',
      <Map<String, dynamic>>[
        <String, dynamic>{'phone': newPhone, 'verifyCode': verifyCode},
        <String, dynamic>{'newPhone': newPhone, 'verifyCode': verifyCode},
        <String, dynamic>{'phone': newPhone, 'code': verifyCode},
        <String, dynamic>{'newPhone': newPhone, 'code': verifyCode},
        <String, dynamic>{
          'oldPhone': originalPhone,
          'phone': newPhone,
          'verifyCode': verifyCode,
        },
      ],
      defaultError: '验证码校验失败',
    );

    final changeToken = _extractChangePhoneToken(verifyResponse);

    final completePayloads = <Map<String, dynamic>>[
      if (changeToken != null && changeToken.isNotEmpty)
        <String, dynamic>{'changePhoneToken': changeToken},
      if (changeToken != null && changeToken.isNotEmpty)
        <String, dynamic>{'token': changeToken},
      <String, dynamic>{'phone': newPhone, 'verifyCode': verifyCode},
      <String, dynamic>{'newPhone': newPhone, 'verifyCode': verifyCode},
      <String, dynamic>{'phone': newPhone, 'code': verifyCode},
      <String, dynamic>{'newPhone': newPhone, 'code': verifyCode},
    ];

    await _putWithFallback(
      '/me/phone',
      completePayloads,
      defaultError: '修改手机号失败',
    );
  }

  String? _extractChangePhoneToken(Map<String, dynamic> body) {
    final data = BackendApiClient.extractData(body);
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    final map = BackendApiClient.asMap(data) ?? body;
    return BackendApiClient.readString(map, const <String>[
      'changePhoneToken',
      'phoneChangeToken',
      'change_token',
      'verifyToken',
      'token',
      'value',
    ]);
  }

  Future<Map<String, dynamic>> _postWithFallback(
    String path,
    List<Map<String, dynamic>> payloads, {
    required String defaultError,
  }) async {
    BackendApiException? lastError;
    final seen = <String>{};

    for (final candidate in payloads) {
      final payload = _compactPayload(candidate);
      if (payload.isEmpty) continue;
      final fingerprint = jsonEncode(payload);
      if (!seen.add(fingerprint)) continue;

      try {
        return await _apiClient.post(path, body: payload, requireAuth: true);
      } on BackendApiException catch (e) {
        lastError = e;
      }
    }

    throw lastError ?? BackendApiException(defaultError);
  }

  Future<Map<String, dynamic>> _putWithFallback(
    String path,
    List<Map<String, dynamic>> payloads, {
    required String defaultError,
  }) async {
    BackendApiException? lastError;
    final seen = <String>{};

    for (final candidate in payloads) {
      final payload = _compactPayload(candidate);
      if (payload.isEmpty) continue;
      final fingerprint = jsonEncode(payload);
      if (!seen.add(fingerprint)) continue;

      try {
        return await _apiClient.put(path, body: payload, requireAuth: true);
      } on BackendApiException catch (e) {
        lastError = e;
      }
    }

    throw lastError ?? BackendApiException(defaultError);
  }

  Map<String, dynamic> _compactPayload(Map<String, dynamic> payload) {
    final normalized = <String, dynamic>{...payload};
    normalized.removeWhere((key, value) {
      if (value == null) return true;
      if (value is String && value.trim().isEmpty) return true;
      return false;
    });
    return normalized;
  }
}
