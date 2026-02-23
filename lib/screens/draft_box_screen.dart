import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/edited_postcard_service.dart';

class DraftBoxScreen extends StatefulWidget {
  const DraftBoxScreen({super.key});

  @override
  State<DraftBoxScreen> createState() => _DraftBoxScreenState();
}

class _DraftBoxScreenState extends State<DraftBoxScreen> {
  final EditedPostcardService _editedPostcardService = EditedPostcardService();

  bool _isLoading = true;
  List<EditedPostcard> _drafts = const [];

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    setState(() {
      _isLoading = true;
    });

    final drafts = await _editedPostcardService.getDraftPostcards();
    if (!mounted) return;

    setState(() {
      _drafts = drafts;
      _isLoading = false;
    });
  }

  Future<void> _openCreatePost() async {
    await Navigator.pushNamed(context, '/create_post');
    if (!mounted) return;
    await _loadDrafts();
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
          '草稿箱',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF30363B),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Text(
                    '共 ${_drafts.length} 张未发布明信片',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6F7880),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isLoading ? null : _loadDrafts,
                    child: const Text('刷新'),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_drafts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.drafts_outlined, size: 54, color: Color(0xFF9AA2AA)),
            SizedBox(height: 10),
            Text(
              '暂无未发布草稿',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF666D75),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '先编辑明信片，或去发帖页发布已选明信片',
              style: TextStyle(fontSize: 12, color: Color(0xFF8F97A0)),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 680 ? 3 : 2;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
          itemCount: _drafts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.86,
          ),
          itemBuilder: (context, index) {
            final item = _drafts[index];
            return _DraftPostcardTile(item: item, onTap: _openCreatePost);
          },
        );
      },
    );
  }
}

class _DraftPostcardTile extends StatelessWidget {
  static const double _postcardAspectRatio = 400 / 258;

  final EditedPostcard item;
  final VoidCallback onTap;

  const _DraftPostcardTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final editedAtText = DateFormat('yyyy-MM-dd HH:mm').format(item.editedAt);
    final location = _resolveLocation(item);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDDE2E7)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              child: AspectRatio(
                aspectRatio: _postcardAspectRatio,
                child: _DraftPostcardImage(imageSource: item.imageUrl),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF293241),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: Color(0xFF7A838D),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      editedAtText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF78818A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveLocation(EditedPostcard postcard) {
    final city = postcard.cityName?.trim();
    if (city != null && city.isNotEmpty) return city;

    final province = postcard.provinceName?.trim();
    if (province != null && province.isNotEmpty) return province;

    final code = postcard.cityCode?.trim();
    if (code != null && code.isNotEmpty) return '城市代码$code';

    return '未知地点';
  }
}

class _DraftPostcardImage extends StatelessWidget {
  final String imageSource;

  const _DraftPostcardImage({required this.imageSource});

  @override
  Widget build(BuildContext context) {
    final source = imageSource.trim();
    if (source.isEmpty) {
      return _buildFallback();
    }

    if (source.startsWith('assets/')) {
      return Image.asset(
        source,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => _buildFallback(),
      );
    }

    final uri = Uri.tryParse(source);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return _buildFallback();
    }

    return Image.network(
      source,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => _buildFallback(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _buildFallback(showLoading: true);
      },
    );
  }

  Widget _buildFallback({bool showLoading = false}) {
    return ColoredBox(
      color: const Color(0xFFD9DEE3),
      child: Center(
        child: showLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.image_not_supported_outlined,
                size: 34,
                color: Color(0xFF8A9198),
              ),
      ),
    );
  }
}
