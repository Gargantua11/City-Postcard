import 'dart:async';
import 'package:flutter/material.dart';
import 'register_step2_screen.dart';
import '../widgets/custom_text_field.dart';

class RegisterStep1Screen extends StatefulWidget {
  const RegisterStep1Screen({super.key});

  @override
  State<RegisterStep1Screen> createState() => _RegisterStep1ScreenState();
}

class _RegisterStep1ScreenState extends State<RegisterStep1Screen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

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

  // 手机号验证
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入手机号';
    }
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(value)) {
      return '请输入正确的手机号';
    }
    return null;
  }

  // 验证码验证
  String? _validateCode(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入验证码';
    }
    if (value.length != 6) {
      return '验证码为6位数字';
    }
    return null;
  }

  // 发送验证码
  void _sendCode() {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先输入手机号')));
      return;
    }

    if (!_formKey.currentState!.validate()) {
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

  // 开始倒计时
  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdown--;
      });

      if (_countdown <= 0) {
        timer.cancel();
        setState(() {
          _canSendCode = true;
        });
      }
    });
  }

  // 下一步
  void _nextStep() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterStep2Screen(phone: _phoneController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/注册1-背景.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // 返回按钮 - 左上角
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
                      image: AssetImage('assets/images/注册1-返回.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            // 主内容区域
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 100),

                      // 注册账号
                      Container(
                        height: 30,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/images/注册1-注册账号.png'),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 80),

                      // 手机号输入
                      Center(
                        child: SizedBox(
                          width: 300,
                          child: CustomTextField(
                            controller: _phoneController,
                            hintText: '请输入手机号',
                            keyboardType: TextInputType.phone,
                            validator: _validatePhone,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // 验证码输入
                      Center(
                        child: SizedBox(
                          width: 300,
                          child: CustomTextField(
                            controller: _codeController,
                            hintText: '请输入验证码',
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            validator: _validateCode,
                            suffixIcon: TextButton(
                              onPressed: _canSendCode ? _sendCode : null,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                _canSendCode ? '获取验证码' : '$_countdown s',
                                style: TextStyle(
                                  color: _canSendCode ? Colors.blue : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // 下一步按钮
                      GestureDetector(
                        onTap: _nextStep,
                        child: Container(
                          height: 70,
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/images/注册1-下一步.png'),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

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
