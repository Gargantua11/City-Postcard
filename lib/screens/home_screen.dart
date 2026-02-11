import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('城市明信片'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () async {
              await authProvider.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '欢迎使用城市明信片',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (user != null)
              Column(
                children: [
                  Text('用户: ${user.username}'),
                  Text('ID: ${user.id}'),
                ],
              ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                // 这里可以添加跳转到其他功能页面的逻辑
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('功能开发中')));
              },
              child: const Text('浏览城市明信片'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // 这里可以添加跳转到发布页面的逻辑
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('功能开发中')));
              },
              child: const Text('发布明信片'),
            ),
          ],
        ),
      ),
    );
  }
}
