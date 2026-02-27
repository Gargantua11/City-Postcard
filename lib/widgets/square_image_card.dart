import 'package:flutter/material.dart';

/// 方形图片卡片组件
/// 表现为方形图片，边框有15px的弧度，可点击进入编辑图片页面
class SquareImageCard extends StatelessWidget {
  final String imagePath;
  final double size;
  final String? placeholderText;

  const SquareImageCard({
    super.key,
    required this.imagePath,
    this.size = 150,
    this.placeholderText,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 点击进入编辑图片页面
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EditImagePage()),
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade300, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: imagePath.isNotEmpty
              ? Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade100,
                      alignment: Alignment.center,
                      child: Text(
                        placeholderText ?? '图片加载失败',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                )
              : Container(
                  color: Colors.grey.shade100,
                  alignment: Alignment.center,
                  child: Text(
                    placeholderText ?? '添加图片',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ),
        ),
      ),
    );
  }
}

/// 编辑图片页面
class EditImagePage extends StatelessWidget {
  const EditImagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑图片'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: const Center(
        child: Text(
          '编辑页面',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
