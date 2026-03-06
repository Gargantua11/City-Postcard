import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/postcard_element_layer.dart';
import '../services/edited_postcard_service.dart';
import '../widgets/resolved_image.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final EditedPostcardService _editedPostcardService = EditedPostcardService();
  final TextEditingController _searchController = TextEditingController();

  List<EditedPostcard> _postcards = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadPostcards();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPostcards() async {
    final postcards = await _editedPostcardService.getEditedPostcards();
    if (!mounted) return;
    setState(() {
      _postcards = postcards;
      _isLoading = false;
    });
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  List<EditedPostcard> get _visiblePostcards {
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) return _postcards;
    return _postcards
        .where((item) => _matches(item, keyword))
        .toList(growable: false);
  }

  bool _matches(EditedPostcard postcard, String keywordLower) {
    final timeTokens = <String>[
      DateFormat('yyyy-MM-dd HH:mm').format(postcard.editedAt),
      DateFormat('yyyy/MM/dd HH:mm').format(postcard.editedAt),
      DateFormat('yyyy-MM-dd').format(postcard.editedAt),
      DateFormat('MM-dd').format(postcard.editedAt),
      DateFormat('yyyyMMdd').format(postcard.editedAt),
    ];

    final locationTokens = <String>[
      postcard.cityName?.trim() ?? '',
      postcard.provinceName?.trim() ?? '',
      postcard.cityCode?.trim() ?? '',
      _resolveLocation(postcard),
    ];

    final elementTokens = <String>[
      for (final layer in postcard.layers) ..._extractElementKeywords(layer),
    ];

    final allTokens = <String>[
      ...timeTokens,
      ...locationTokens,
      ...elementTokens,
    ];

    for (final token in allTokens) {
      final normalized = token.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      if (normalized.contains(keywordLower)) {
        return true;
      }
    }
    return false;
  }

  List<String> _extractElementKeywords(PostcardElementLayer layer) {
    final elementKey = layer.elementKey.trim();
    final assetPath = layer.assetPath.trim();
    final filename = _filenameWithoutExtension(assetPath);
    return <String>[
      if (elementKey.isNotEmpty) elementKey,
      if (assetPath.isNotEmpty) assetPath,
      if (filename.isNotEmpty) filename,
    ];
  }

  String _filenameWithoutExtension(String path) {
    if (path.trim().isEmpty) return '';
    var filename = path.trim();
    final slash = filename.lastIndexOf('/');
    if (slash >= 0 && slash + 1 < filename.length) {
      filename = filename.substring(slash + 1);
    }
    final dot = filename.lastIndexOf('.');
    if (dot > 0) {
      filename = filename.substring(0, dot);
    }
    return filename;
  }

  String _resolveLocation(EditedPostcard postcard) {
    final city = postcard.cityName?.trim() ?? '';
    final province = postcard.provinceName?.trim() ?? '';
    final cityCode = postcard.cityCode?.trim() ?? '';

    if (province.isNotEmpty && city.isNotEmpty) {
      if (province == city) return city;
      return '$province $city';
    }
    if (city.isNotEmpty) return city;
    if (province.isNotEmpty) return province;
    return cityCode;
  }

  String _resolveElementSummary(EditedPostcard postcard) {
    if (postcard.layers.isEmpty) return '无元素';
    final names = <String>[];
    for (final layer in postcard.layers) {
      final key = layer.elementKey.trim();
      if (key.isNotEmpty) {
        names.add(key);
      } else {
        final fromPath = _filenameWithoutExtension(layer.assetPath);
        if (fromPath.isNotEmpty) {
          names.add(fromPath);
        }
      }
    }
    if (names.isEmpty) return '无元素';
    if (names.length <= 3) return names.join(' / ');
    return '${names.take(3).join(' / ')} 等${names.length}个';
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visiblePostcards;
    return Scaffold(
      backgroundColor: const Color(0xFFCBE6BB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFCBE6BB),
        elevation: 0,
        title: const Text(
          '搜索明信片',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Column(
            children: [
              _SearchInput(controller: _searchController),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '共 ${visible.length} 条结果',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF4C5A43),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isLoading ? null : _loadPostcards,
                    child: const Text('刷新'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(child: _buildBody(visible)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<EditedPostcard> visible) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_postcards.isEmpty) {
      return const Center(
        child: Text(
          '暂无已编辑明信片',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF4C5A43),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (visible.isEmpty) {
      return const Center(
        child: Text(
          '未找到匹配的明信片',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF4C5A43),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = visible[index];
        final location = _resolveLocation(item);
        final timeText = DateFormat('yyyy-MM-dd HH:mm').format(item.editedAt);
        final elementText = _resolveElementSummary(item);
        return _ResultCard(
          imageSource: item.imageUrl,
          timeText: timeText,
          locationText: location,
          elementText: elementText,
        );
      },
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEDB),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFB8BDAE)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, size: 18, color: Color(0xFF5B6455)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '按时间/地点/元素搜索',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF7D8873)),
                isCollapsed: true,
              ),
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          if (hasText)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: controller.clear,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.close, size: 16, color: Color(0xFF6F7869)),
              ),
            )
          else
            const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.imageSource,
    required this.timeText,
    required this.locationText,
    required this.elementText,
  });

  final String imageSource;
  final String timeText;
  final String locationText;
  final String elementText;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE5D5)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(15),
              bottomLeft: Radius.circular(15),
            ),
            child: SizedBox(
              width: 150,
              height: double.infinity,
              child: ResolvedImage(
                source: imageSource,
                fit: BoxFit.cover,
                fallbackBuilder: (_) => const ColoredBox(
                  color: Color(0xFFCBE6BB),
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 32,
                      color: Color(0xFF6E7E68),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Color(0xFF616A5A),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          timeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF44503F),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        size: 14,
                        color: Color(0xFF616A5A),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          locationText.isEmpty ? '未标记地点' : locationText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF44503F),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '元素：$elementText',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF56624E),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
