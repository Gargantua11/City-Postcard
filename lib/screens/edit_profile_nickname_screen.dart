import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../widgets/custom_text_field.dart';

class EditProfileNicknameScreen extends StatefulWidget {
  const EditProfileNicknameScreen({super.key});

  @override
  State<EditProfileNicknameScreen> createState() =>
      _EditProfileNicknameScreenState();
}

class _EditProfileNicknameScreenState extends State<EditProfileNicknameScreen> {
  final StorageService _storageService = StorageService();
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final nickname = await _storageService.getProfileNickname();
    if (!mounted) return;

    _controller.text = (nickname ?? '').trim();
    setState(() {
      _isLoading = false;
    });
  }

  String? _validateNickname(String? value) {
    final text = (value ?? '').trim();
    if (text.length < 2 || text.length > 20) {
      return '昵称长度需在2-20之间';
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
      await _storageService.saveProfileNickname(_controller.text.trim());
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
                              '修改昵称',
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
                                controller: _controller,
                                hintText: '请输入昵称（2-20字）',
                                prefixIcon: Icons.person,
                                maxLength: 20,
                                validator: _validateNickname,
                                enabled: !_isSaving,
                              ),
                            ),
                            const SizedBox(height: 28),
                            _ActionButton(
                              isLoading: _isSaving,
                              onTap: _save,
                              text: '保存昵称',
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
