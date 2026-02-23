import 'package:flutter/material.dart';

import '../services/storage_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final StorageService _storageService = StorageService();

  bool _isLoading = true;
  String _nickname = '用户';
  String _phone = '';
  String? _avatarSource;
  bool _hasPassword = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    final results = await Future.wait<dynamic>([
      _storageService.getProfileNickname(),
      _storageService.getProfilePhone(),
      _storageService.getProfileAvatar(),
      _storageService.getProfilePassword(),
    ]);

    if (!mounted) return;
    setState(() {
      final nickname = (results[0] as String?)?.trim() ?? '';
      _nickname = nickname.isEmpty ? '用户' : nickname;
      _phone = ((results[1] as String?) ?? '').trim();
      _avatarSource = (results[2] as String?)?.trim();
      _hasPassword = ((results[3] as String?) ?? '').isNotEmpty;
      _isLoading = false;
    });
  }

  Future<void> _editAvatar() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('使用默认头像'),
                onTap: () => Navigator.pop(sheetContext, 'default'),
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('输入头像地址'),
                onTap: () => Navigator.pop(sheetContext, 'input'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'default') {
      await _storageService.saveProfileAvatar(null);
      if (!mounted) return;
      setState(() {
        _avatarSource = null;
      });
      _showHint('已恢复默认头像');
      return;
    }

    final controller = TextEditingController(text: _avatarSource ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('头像地址'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '输入 http(s) 或 assets/ 开头地址',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (!mounted || value == null) return;
    final normalized = value.trim();
    if (normalized.isEmpty) {
      _showHint('头像地址不能为空');
      return;
    }

    await _storageService.saveProfileAvatar(normalized);
    if (!mounted) return;
    setState(() {
      _avatarSource = normalized;
    });
    _showHint('头像已更新');
  }

  Future<void> _editNickname() async {
    final controller = TextEditingController(text: _nickname);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('修改昵称'),
          content: TextField(
            controller: controller,
            maxLength: 20,
            decoration: const InputDecoration(hintText: '请输入昵称（2-20字）'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (!mounted || value == null) return;
    final normalized = value.trim();
    if (normalized.length < 2 || normalized.length > 20) {
      _showHint('昵称长度需在2-20之间');
      return;
    }

    await _storageService.saveProfileNickname(normalized);
    if (!mounted) return;
    setState(() {
      _nickname = normalized;
    });
    _showHint('昵称已更新');
  }

  Future<void> _editPhone() async {
    final controller = TextEditingController(text: _phone);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('修改手机号'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            maxLength: 11,
            decoration: const InputDecoration(hintText: '请输入11位手机号'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (!mounted || value == null) return;
    final normalized = value.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(normalized)) {
      _showHint('请输入正确的11位手机号');
      return;
    }

    await _storageService.saveProfilePhone(normalized);
    if (!mounted) return;
    setState(() {
      _phone = normalized;
    });
    _showHint('手机号已更新');
  }

  Future<void> _editPassword() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('修改密码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '请输入新密码'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '请再次输入新密码'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    final password = passwordController.text.trim();
    final confirm = confirmController.text.trim();
    if (password.length < 6) {
      _showHint('密码至少6位');
      return;
    }
    if (password != confirm) {
      _showHint('两次输入的密码不一致');
      return;
    }

    await _storageService.saveProfilePassword(password);
    if (!mounted) return;
    setState(() {
      _hasPassword = true;
    });
    _showHint('密码已更新');
  }

  void _showHint(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEDEDED),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '编辑个人信息',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF30363B),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  final rowWidth = (maxWidth - 24).clamp(320.0, 440.0);
                  final rowHeight = rowWidth * (48 / 397);

                  return Center(
                    child: SizedBox(
                      width: rowWidth,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(top: 18, bottom: 16),
                        child: Column(
                          children: [
                            _EditProfileItem(
                              width: rowWidth,
                              height: rowHeight,
                              icon: Icons.account_circle_outlined,
                              text: '头像',
                              value: '点击修改',
                              valueWidget: _InlineAvatar(
                                imageSource: _avatarSource,
                              ),
                              onTap: _editAvatar,
                            ),
                            const SizedBox(height: 16),
                            _EditProfileItem(
                              width: rowWidth,
                              height: rowHeight,
                              icon: Icons.person_outline,
                              text: '昵称',
                              value: _nickname,
                              onTap: _editNickname,
                            ),
                            const SizedBox(height: 16),
                            _EditProfileItem(
                              width: rowWidth,
                              height: rowHeight,
                              icon: Icons.phone_outlined,
                              text: '手机号',
                              value: _maskPhone(_phone),
                              onTap: _editPhone,
                            ),
                            const SizedBox(height: 16),
                            _EditProfileItem(
                              width: rowWidth,
                              height: rowHeight,
                              icon: Icons.lock_outline,
                              text: '密码',
                              value: _hasPassword ? '已设置' : '未设置',
                              onTap: _editPassword,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  String _maskPhone(String phone) {
    final normalized = phone.trim();
    if (normalized.isEmpty) return '未设置';
    if (normalized.length != 11) return normalized;
    return '${normalized.substring(0, 3)}****${normalized.substring(7)}';
  }
}

class _EditProfileItem extends StatelessWidget {
  final double width;
  final double height;
  final IconData icon;
  final String text;
  final String value;
  final Widget? valueWidget;
  final VoidCallback onTap;

  const _EditProfileItem({
    required this.width,
    required this.height,
    required this.icon,
    required this.text,
    required this.value,
    this.valueWidget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: const Color(0xFFD9DDD2),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x20000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 30, color: Colors.black87),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF4C5450),
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (valueWidget != null) ...[
              valueWidget!,
              const SizedBox(width: 10),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4C5450),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right, size: 26, color: Color(0xFF7D817D)),
          ],
        ),
      ),
    );
  }
}

class _InlineAvatar extends StatelessWidget {
  final String? imageSource;

  const _InlineAvatar({required this.imageSource});

  @override
  Widget build(BuildContext context) {
    final source = imageSource?.trim() ?? '';
    if (source.isEmpty) {
      return const CircleAvatar(
        radius: 14,
        backgroundColor: Color(0xFFC9C9C9),
        child: Icon(Icons.person, color: Colors.white, size: 16),
      );
    }

    if (source.startsWith('assets/')) {
      return CircleAvatar(
        radius: 14,
        backgroundImage: AssetImage(source),
        onBackgroundImageError: (_, _) {},
      );
    }

    final uri = Uri.tryParse(source);
    if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
      return CircleAvatar(radius: 14, backgroundImage: NetworkImage(source));
    }

    return const CircleAvatar(
      radius: 14,
      backgroundColor: Color(0xFFC9C9C9),
      child: Icon(Icons.person, color: Colors.white, size: 16),
    );
  }
}
