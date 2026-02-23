import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../widgets/custom_text_field.dart';

class EditProfilePasswordScreen extends StatefulWidget {
  const EditProfilePasswordScreen({super.key});

  @override
  State<EditProfilePasswordScreen> createState() =>
      _EditProfilePasswordScreenState();
}

class _EditProfilePasswordScreenState extends State<EditProfilePasswordScreen> {
  final StorageService _storageService = StorageService();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    final text = (value ?? '').trim();
    if (text.length < 6) {
      return '密码至少6位';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    final text = (value ?? '').trim();
    if (text != _passwordController.text.trim()) {
      return '两次输入的密码不一致';
    }
    return null;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _storageService.saveProfilePassword(
        _passwordController.text.trim(),
      );
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
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 56),
                      const Text(
                        '修改密码',
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
                          controller: _passwordController,
                          hintText: '请输入新密码（至少6位）',
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
                      SizedBox(
                        width: 300,
                        child: CustomTextField(
                          controller: _confirmController,
                          hintText: '请再次输入新密码',
                          prefixIcon: Icons.lock_outline,
                          obscureText: _obscureConfirm,
                          validator: _validateConfirm,
                          enabled: !_isSaving,
                          suffixIcon: IconButton(
                            onPressed: _isSaving
                                ? null
                                : () {
                                    setState(() {
                                      _obscureConfirm = !_obscureConfirm;
                                    });
                                  },
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _ActionButton(
                        isLoading: _isSaving,
                        onTap: _save,
                        text: '保存密码',
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

class _ActionButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  final String text;

  const _ActionButton({
    required this.isLoading,
    required this.onTap,
    required this.text,
  });

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
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
