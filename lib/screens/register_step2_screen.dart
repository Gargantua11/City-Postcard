import 'package:flutter/material.dart';
import 'city_search_screen.dart';
import '../widgets/custom_text_field.dart';

class RegisterStep2Screen extends StatefulWidget {
  final String phone;

  const RegisterStep2Screen({super.key, required this.phone});

  @override
  State<RegisterStep2Screen> createState() => _RegisterStep2ScreenState();
}

class _RegisterStep2ScreenState extends State<RegisterStep2Screen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // 选中的城市
  City? _selectedCity;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 密码验证
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '请设置密码';
    }
    if (value.length < 6 || value.length > 24) {
      return '密码长度6-24位';
    }
    return null;
  }

  // 确认密码验证
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return '请确认密码';
    }
    if (value != _passwordController.text) {
      return '两次输入的密码不一致';
    }
    return null;
  }

  // 选择城市
  void _selectCity() async {
    final City? selected = await Navigator.push<City>(
      context,
      MaterialPageRoute(
        builder: (context) => CitySearchScreen(
          selectedCity: _selectedCity?.name,
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedCity = selected;
      });
    }
  }

  // 完成注册
  void _complete() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('注册成功')));
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/注册2-背景.png'),
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
                  Navigator.pushReplacementNamed(context, '/register1');
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
                      const SizedBox(height: 70),

                      // 设置密码
                      Container(
                        height: 30,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/images/注册2-设置密码.png'),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 56),

                      // 密码输入
                      Center(
                        child: SizedBox(
                          width: 300,
                          child: CustomTextField(
                            controller: _passwordController,
                            hintText: '请设置6-24位密码',
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
                      const SizedBox(height: 30),

                      // 确认密码输入
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
                      const SizedBox(height: 30),

                      // 城市选择按钮
                      Center(
                        child: SizedBox(
                          width: 300,
                          child: GestureDetector(
                            onTap: _selectCity,
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 231, 242, 231),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                    color: const Color(0xFF90EE90), width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_city,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _selectedCity?.name ?? '请选择城市',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: _selectedCity != null
                                              ? Colors.black87
                                              : Colors.grey,
                                          fontWeight: _selectedCity != null
                                              ? FontWeight.w500
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (_selectedCity != null) ...[
                                      Text(
                                        _selectedCity!.code,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey.shade400,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // 完成按钮
                      GestureDetector(
                        onTap: _complete,
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
