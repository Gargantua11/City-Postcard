import 'dart:async';
import 'package:flutter/material.dart';
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

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _canSendCode = true;
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
    if (value == null || value.isEmpty) {
      return '请输入手机号';
    }
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(value)) {
      return '请输入正确的手机号';
    }
    return null;
  }

  String? _validateCode(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入验证码';
    }
    if (value != '123456') {
      return '验证码错误，默认123456';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入新密码';
    }
    if (value.length < 6 || value.length > 24) {
      return '密码长度应为6-24位';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return '请再次输入密码';
    }
    if (value != _passwordController.text) {
      return '两次密码不一致';
    }
    return null;
  }

  void _sendCode() {
    final phoneError = _validatePhone(_phoneController.text);
    if (phoneError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(phoneError)));
      return;
    }

    setState(() {
      _canSendCode = false;
      _countdown = 60;
    });

    _startCountdown();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('\u9a8c\u8bc1\u7801\u5df2\u53d1\u9001')),
    );
  }

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

  void _resetPassword() {
    if (!_formKey.currentState!.validate()) {
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
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/注册1-背景.png'),
            fit: BoxFit.cover,
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
                      image: AssetImage('assets/images/注册2-返回.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 30),
                      // const Text(
                      //   '找回密码',
                      //   style: TextStyle(
                      //     fontSize: 22,
                      //     fontWeight: FontWeight.bold,
                      //     color: Colors.black87,
                      //   ),
                      // ),
                      Container(
                        width: 150,
                        height: 50,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/images/找回密码.png'),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      //输入手机号
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
                      const SizedBox(height: 15),
                      Center(
                        child: SizedBox(
                          width: 300,
                          child: CustomTextField(
                            controller: _codeController,
                            hintText: '请输入验证码（默认123456）',
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
                                _canSendCode
                                    ? '\u83b7\u53d6\u9a8c\u8bc1\u7801'
                                    : '$_countdown s',
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
                      //设置密码
                      Center(
                        child: SizedBox(
                          width: 300,
                          child: CustomTextField(
                            controller: _passwordController,
                            hintText: '请输入新密码',
                            obscureText: _obscurePassword,
                            prefixIcon: Icons.lock,
                            validator: _validatePassword,
                            suffixIcon: IconButton(
                              onPressed: () {
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
                      //确认密码
                      Center(
                        child: SizedBox(
                          width: 300,
                          child: CustomTextField(
                            controller: _confirmPasswordController,
                            hintText: '请再次输入密码',
                            obscureText: _obscureConfirmPassword,
                            prefixIcon: Icons.lock_outline,
                            validator: _validateConfirmPassword,
                            suffixIcon: IconButton(
                              onPressed: () {
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
                        onTap: _resetPassword,
                        child: Container(
                          height: 70,
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/images/注册2-完成.png'),
                              fit: BoxFit.contain,
                            ),
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
