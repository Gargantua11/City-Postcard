import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/edited_postcard_service.dart';
import '../widgets/resolved_image.dart';

class PostcardOverviewScreen extends StatefulWidget {
  const PostcardOverviewScreen({super.key});

  @override
  State<PostcardOverviewScreen> createState() => _PostcardOverviewScreenState();
}

class _PostcardOverviewScreenState extends State<PostcardOverviewScreen> {
  final EditedPostcardService _editedPostcardService = EditedPostcardService();

  bool _isLoading = true;
  List<EditedPostcard> _postcards = const [];

  @override
  void initState() {
    super.initState();
    _loadPostcards();
  }

  Future<void> _loadPostcards() async {
    setState(() {
      _isLoading = true;
    });

    final postcards = await _editedPostcardService.getEditedPostcards();
    if (!mounted) return;

    setState(() {
      _postcards = postcards;
      _isLoading = false;
    });
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
          '明信片总览',
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
                    '共 ${_postcards.length} 张明信片',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6F7880),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isLoading ? null : _loadPostcards,
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

    if (_postcards.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.photo_library_outlined,
              size: 54,
              color: Color(0xFF9AA2AA),
            ),
            SizedBox(height: 10),
            Text(
              '暂无已创作明信片',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF666D75),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '去首页编辑并保存明信片后会显示在这里',
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
          itemCount: _postcards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.86,
          ),
          itemBuilder: (context, index) {
            final item = _postcards[index];
            return _PostcardOverviewTile(item: item);
          },
        );
      },
    );
  }
}

class _PostcardOverviewTile extends StatelessWidget {
  static const double _postcardAspectRatio = 400 / 258;

  final EditedPostcard item;

  const _PostcardOverviewTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final editedAtText = DateFormat('yyyy-MM-dd HH:mm').format(item.editedAt);
    final location = _resolveLocation(item);
    final statusText = item.isPublished ? '已发布' : '未发布';
    final statusColor = item.isPublished
        ? const Color(0xFF5E9C5B)
        : const Color(0xFFAA7B39);
    final statusBg = item.isPublished
        ? const Color(0xFFE3F2E1)
        : const Color(0xFFF5E7D5);

    return Container(
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
              child: _PostcardImage(imageSource: item.imageUrl),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Row(
              children: [
                Expanded(
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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
    );
  }

  String _resolveLocation(EditedPostcard postcard) {
    final province = postcard.provinceName?.trim();
    final city = postcard.cityName?.trim();

    if (province != null &&
        province.isNotEmpty &&
        city != null &&
        city.isNotEmpty) {
      if (province == city) return city;
      return '$province $city';
    }
    if (city != null && city.isNotEmpty) return city;
    if (province != null && province.isNotEmpty) return province;

    final code = postcard.cityCode?.trim();
    if (code != null && code.isNotEmpty) return '城市代码$code';
    return '未标注地点';
  }
}

class _PostcardImage extends StatelessWidget {
  final String imageSource;

  const _PostcardImage({required this.imageSource});

  @override
  Widget build(BuildContext context) {
    return ResolvedImage(
      source: imageSource,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      fallbackBuilder: (_) => _buildFallback(),
      loadingBuilder: (_) => _buildFallback(showLoading: true),
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
