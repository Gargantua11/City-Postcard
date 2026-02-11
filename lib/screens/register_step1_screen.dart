import 'dart:async';
import 'package:flutter/material.dart';
import 'register_step2_screen.dart';
import 'login_screen.dart';

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
  // bool _agreedToTerms = false;

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

    // if (!_agreedToTerms) {
    //   ScaffoldMessenger.of(
    //     context,
    //   ).showSnackBar(const SnackBar(content: Text('请先同意用户协议和隐私政策')));
    //   return;
    // }

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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/images/注册1-手机号.png'),
                            fit: BoxFit.contain,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '请输入手机号',
                                  hintStyle: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 30,
                                    vertical: 18,
                                  ),
                                ),
                                validator: _validatePhone,
                              ),
                            ),
                            Container(
                              width: 100,
                              child: TextButton(
                                onPressed: _canSendCode ? _sendCode : null,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  _canSendCode ? '获取验证码' : '${_countdown}s',
                                  style: TextStyle(
                                    color: _canSendCode
                                        ? Colors.blue
                                        : Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // 验证码输入
                      Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/images/注册1-验证码.png'),
                            fit: BoxFit.contain,
                          ),
                        ),
                        child: TextFormField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            counterText: '',
                            hintText: '请输入验证码',
                            hintStyle: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 18,
                            ),
                          ),
                          validator: _validateCode,
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

                      // // 协议勾选 - 页面底部
                      // Row(
                      //   children: [
                      //     Checkbox(
                      //       value: _agreedToTerms,
                      //       onChanged: (value) {
                      //         setState(() {
                      //           _agreedToTerms = value ?? false;
                      //         });
                      //       },
                      //       activeColor: Colors.blue,
                      //     ),
                      //     Expanded(
                      //       child: Wrap(
                      //         children: [
                      //           const Text(
                      //             '我已阅读并同意',
                      //             style: TextStyle(
                      //               color: Colors.black87,
                      //               fontSize: 12,
                      //             ),
                      //           ),
                      //           TextButton(
                      //             onPressed: () {
                      //               // 打开用户协议
                      //             },
                      //             style: TextButton.styleFrom(
                      //               padding: EdgeInsets.zero,
                      //               minimumSize: Size.zero,
                      //               tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      //             ),
                      //             child: const Text(
                      //               '《用户协议》',
                      //               style: TextStyle(
                      //                 color: Colors.blue,
                      //                 fontSize: 12,
                      //                 decoration: TextDecoration.underline,
                      //               ),
                      //             ),
                      //           ),
                      //           const Text(
                      //             '和',
                      //             style: TextStyle(
                      //               color: Colors.black87,
                      //               fontSize: 12,
                      //             ),
                      //           ),
                      //           TextButton(
                      //             onPressed: () {
                      //               // 打开隐私政策
                      //             },
                      //             style: TextButton.styleFrom(
                      //               padding: EdgeInsets.zero,
                      //               minimumSize: Size.zero,
                      //               tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      //             ),
                      //             child: const Text(
                      //               '《隐私政策》',
                      //               style: TextStyle(
                      //                 color: Colors.blue,
                      //                 fontSize: 12,
                      //                 decoration: TextDecoration.underline,
                      //               ),
                      //             ),
                      //           ),
                      //         ],
                      //       ),
                      //     ),
                      //   ],
                      // ),
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
