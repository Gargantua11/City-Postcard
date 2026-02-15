import 'package:flutter/material.dart';
import '../services/edited_postcard_service.dart';

class PostcardEditScreen extends StatefulWidget {
  const PostcardEditScreen({super.key});

  @override
  State<PostcardEditScreen> createState() => _PostcardEditScreenState();
}

class _PostcardEditScreenState extends State<PostcardEditScreen> {
  static const List<String> _builtInAssets = [
    'assets/images/首页-背景.png',
    'assets/images/Group 21.png',
    'assets/images/Group 22.png',
    'assets/images/Group 67.png',
  ];

  final TextEditingController _imageController = TextEditingController();
  final EditedPostcardService _editedPostcardService = EditedPostcardService();

  bool _isSaving = false;

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _savePostcard() async {
    final imageSource = _imageController.text.trim();
    if (!_isValidImageSource(imageSource)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效图片地址（http/https）或 assets 路径')),
      );
      return;
    }

    setState(() => _isSaving = true);
    await _editedPostcardService.addEditedPostcard(imageSource);
    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.pop(context, true);
  }

  bool _isValidImageSource(String value) {
    if (value.isEmpty) return false;
    if (value.startsWith('assets/')) return true;
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    return uri.isScheme('http') || uri.isScheme('https');
  }

  @override
  Widget build(BuildContext context) {
    final imageSource = _imageController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('明信片编辑'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '输入明信片图片地址（网络图片）或选择内置图片，保存后会回到首页。',
            style: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _imageController,
            decoration: const InputDecoration(
              labelText: '图片地址或 assets 路径',
              hintText: '例如：https://example.com/postcard.jpg',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _builtInAssets.map((path) {
              return ActionChip(
                label: Text(path.split('/').last),
                onPressed: () {
                  _imageController.text = path;
                  setState(() {});
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2E8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFCBD5C0)),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageSource.isEmpty
                ? const Center(
                    child: Text(
                      '预览区域',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  )
                : _buildPreview(imageSource),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _savePostcard,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存明信片'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(String imageSource) {
    if (imageSource.startsWith('assets/')) {
      return Image.asset(
        imageSource,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _previewFallback(),
      );
    }
    return Image.network(
      imageSource,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _previewFallback(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
    );
  }

  Widget _previewFallback() {
    return const Center(
      child: Text(
        '图片加载失败',
        style: TextStyle(color: Color(0xFF6B7280)),
      ),
    );
  }
}
