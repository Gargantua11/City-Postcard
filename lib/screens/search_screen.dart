import 'package:flutter/material.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('搜索'),
        leading: IconButton(
          icon: Image.asset('assets/images/search/返回.png'), // 替换为实际的返回图标路径
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: '请输入搜索内容',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                suffixIcon: IconButton(
                  icon: Image.asset(
                    'assets/images/search/搜索框.png',
                  ), // 替换为实际的搜索按钮图标路径
                  onPressed: () {
                    // 处理搜索逻辑
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
