import 'package:flutter/material.dart';

import '../services/backend_api_client.dart';
import '../services/profile_account_service.dart';
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
  final ProfileAccountService _profileAccountService = ProfileAccountService();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateOldPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return '请输入旧密码';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return '请输入新密码';
    }

    final passwordRegExp = RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{6,24}$',
    );
    if (!passwordRegExp.hasMatch(text)) {
      return '密码需 6-24 位，且同时包含字母和数字';
    }

    return null;
  }

  String? _validateConfirm(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return '请确认新密码';
    }
    if (text != _newPasswordController.text) {
      return '两次输入的新密码不一致';
    }
    return null;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmController.text;

    try {
      await _profileAccountService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      await _storageService.saveProfilePassword(newPassword);
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
      ).showSnackBar(const SnackBar(content: Text('修改失败，请重试')));
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
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: CustomTextField(
                          controller: _oldPasswordController,
                          hintText: '请输入旧密码',
                          prefixIcon: Icons.lock_clock_outlined,
                          obscureText: _obscureOldPassword,
                          validator: _validateOldPassword,
                          enabled: !_isSaving,
                          suffixIcon: IconButton(
                            onPressed: _isSaving
                                ? null
                                : () {
                                    setState(() {
                                      _obscureOldPassword =
                                          !_obscureOldPassword;
                                    });
                                  },
                            icon: Icon(
                              _obscureOldPassword
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
                          controller: _newPasswordController,
                          hintText: '请输入新密码（6-24 位）',
                          prefixIcon: Icons.lock,
                          obscureText: _obscureNewPassword,
                          validator: _validateNewPassword,
                          enabled: !_isSaving,
                          suffixIcon: IconButton(
                            onPressed: _isSaving
                                ? null
                                : () {
                                    setState(() {
                                      _obscureNewPassword =
                                          !_obscureNewPassword;
                                    });
                                  },
                            icon: Icon(
                              _obscureNewPassword
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
                        text: '',
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
