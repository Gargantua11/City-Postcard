import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'city_search_screen.dart';
import '../services/auth_provider.dart';
import '../widgets/custom_text_field.dart';

class RegisterStep2Screen extends StatefulWidget {
  final String phone;

  const RegisterStep2Screen({super.key, required this.phone});

  @override
  State<RegisterStep2Screen> createState() => _RegisterStep2ScreenState();
}

class _RegisterStep2ScreenState extends State<RegisterStep2Screen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  City? _selectedCity;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入用户名';
    }

    final usernameRegExp = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{3,19}$');
    if (!usernameRegExp.hasMatch(value)) {
      return '用户名需4-20位，以字母开头，仅支持字母数字下划线';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '请设置密码';
    }

    final passwordRegExp = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{6,24}$');
    if (!passwordRegExp.hasMatch(value)) {
      return '密码需6-24位，且同时包含字母和数字';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return '请确认密码';
    }
    if (value != _passwordController.text) {
      return '两次输入的密码不一致';
    }
    return null;
  }

  Future<void> _selectCity() async {
    if (_isSubmitting) {
      return;
    }

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

  Future<void> _complete() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    final cityCode = _selectedCity == null ? null : int.tryParse(_selectedCity!.code);

    setState(() {
      _isSubmitting = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.register(
      _usernameController.text.trim(),
      _passwordController.text,
      _confirmPasswordController.text,
      cityCode,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error ?? '注册失败，请稍后重试')),
      );
      return;
    }

    final code = result['code'];
    final msg = result['msg']?.toString() ?? (code == 0 ? '注册成功' : '注册失败');

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

    if (code == 0) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/注册2-背景.png'),
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
                  Navigator.pushReplacementNamed(context, '/register1');
                },
                child: Container(
                  width: 80,
                  height: 30,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/注册1-返回.png'),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
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
                      const SizedBox(height: 70),
                      Container(
                        height: 30,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/images/注册2-设置密码.png'),
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (widget.phone.isNotEmpty)
                        Text(
                          '已验证手机号：${widget.phone}',
                          style: const TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      const SizedBox(height: 18),
                      Center(
                        child: SizedBox(
                          width: 300,
                          child: CustomTextField(
                            controller: _usernameController,
                            hintText: '请输入用户名',
                            prefixIcon: Icons.person,
                            validator: _validateUsername,
                            enabled: !_isSubmitting,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: SizedBox(
                          width: 300,
                          child: CustomTextField(
                            controller: _passwordController,
                            hintText: '请设置6-24位密码',
                            obscureText: _obscurePassword,
                            prefixIcon: Icons.lock,
                            validator: _validatePassword,
                            enabled: !_isSubmitting,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
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
                      const SizedBox(height: 18),
                      Center(
                        child: SizedBox(
                          width: 300,
                          child: GestureDetector(
                            onTap: _selectCity,
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: _isSubmitting
                                    ? Colors.grey.shade100
                                    : const Color.fromARGB(255, 231, 242, 231),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: const Color(0xFF90EE90),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                        _selectedCity?.name ?? '请选择城市（可选）',
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
                      GestureDetector(
                        onTap: _isSubmitting ? null : _complete,
                        child: SizedBox(
                          height: 70,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage('assets/images/注册2-完成.png'),
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
