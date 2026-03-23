import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/edited_postcard_service.dart';
import '../widgets/resolved_image.dart';
import 'postcard_edit_screen.dart';

class DraftBoxScreen extends StatefulWidget {
  const DraftBoxScreen({super.key});

  @override
  State<DraftBoxScreen> createState() => _DraftBoxScreenState();
}

class _DraftBoxScreenState extends State<DraftBoxScreen> {
  final EditedPostcardService _editedPostcardService = EditedPostcardService();

  bool _isLoading = true;
  bool _isSelectionMode = false;
  bool _isDeleting = false;
  int? _selectedDeleteIndex;
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
      if (_selectedDeleteIndex != null &&
          _selectedDeleteIndex! >= drafts.length) {
        _selectedDeleteIndex = null;
      }
      if (drafts.isEmpty) {
        _isSelectionMode = false;
        _selectedDeleteIndex = null;
      }
      _isLoading = false;
    });
  }

  Future<void> _openDraftEditor(EditedPostcard draft) async {
    if (_isDeleting || _isSelectionMode) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostcardEditScreen(initialDraft: draft),
      ),
    );
    if (!mounted) return;
    await _loadDrafts();
  }

  void _toggleSelectionMode() {
    if (_drafts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无草稿')));
      return;
    }

    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedDeleteIndex = null;
      }
    });
  }

  void _onTapDraft(int index) {
    if (_isDeleting) return;

    if (!_isSelectionMode) {
      _openDraftEditor(_drafts[index]);
      return;
    }

    setState(() {
      _selectedDeleteIndex = _selectedDeleteIndex == index ? null : index;
    });
  }

  Future<void> _deleteSelectedDraft() async {
    final selectedIndex = _selectedDeleteIndex;
    if (selectedIndex == null || _isDeleting) return;
    if (selectedIndex < 0 || selectedIndex >= _drafts.length) return;

    final selectedDraft = _drafts[selectedIndex];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除草稿'),
          content: const Text('确认删除这张草稿吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final deleted = await _editedPostcardService.deleteEditedPostcardById(
        selectedDraft.draftId,
      );
      if (!mounted) return;

      if (!deleted) {
        setState(() {
          _isDeleting = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
        return;
      }

      await _loadDrafts();
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _selectedDeleteIndex = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('草稿已删除')));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
    }
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
                    '共 ${_drafts.length} 张草稿',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6F7880),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isLoading ? null : _toggleSelectionMode,
                    child: Text(_isSelectionMode ? '完成' : '编辑'),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _loadDrafts,
                    child: const Text('刷新'),
                  ),
                ],
              ),
            ),
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _selectedDeleteIndex == null ? '请点击一张草稿' : '已选中，可点击删除',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4F5A4A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            if (_selectedDeleteIndex != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _isDeleting ? null : _deleteSelectedDraft,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE9A1A1),
                      disabledBackgroundColor: const Color(0xFFF2D6D6),
                      foregroundColor: const Color(0xFF5A2424),
                      disabledForegroundColor: const Color(0xFF977C7C),
                    ),
                    icon: _isDeleting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    label: Text(_isDeleting ? '删除中' : '删除'),
                  ),
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
              '暂无草稿',
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
            return _DraftPostcardTile(
              item: item,
              selectable: _isSelectionMode,
              selected: _selectedDeleteIndex == index,
              onTap: () => _onTapDraft(index),
            );
          },
        );
      },
    );
  }
}

class _DraftPostcardTile extends StatelessWidget {
  static const double _postcardAspectRatio = 400 / 258;

  final EditedPostcard item;
  final bool selectable;
  final bool selected;
  final VoidCallback onTap;

  const _DraftPostcardTile({
    required this.item,
    required this.selectable,
    required this.selected,
    required this.onTap,
  });

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
          border: Border.all(
            color: selected ? const Color(0xFFD75555) : const Color(0xFFDDE2E7),
            width: selected ? 2 : 1,
          ),
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
            Stack(
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
                if (selectable)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFD75555)
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFD75555)
                              : const Color(0xFFB0BAA7),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        selected
                            ? Icons.check_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 15,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF8C9784),
                      ),
                    ),
                  ),
              ],
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
    final detail = postcard.locationDetail?.trim();
    final city = postcard.cityName?.trim();
    if (city != null && city.isNotEmpty) {
      return _mergeLocationText(city, detail);
    }

    final province = postcard.provinceName?.trim();
    if (province != null && province.isNotEmpty) {
      return _mergeLocationText(province, detail);
    }

    final code = postcard.cityCode?.trim();
    if (code != null && code.isNotEmpty) {
      return _mergeLocationText('城市代码$code', detail);
    }

    if (detail != null && detail.isNotEmpty) return detail;

    return '未知地点';
  }

  String _mergeLocationText(String base, String? detail) {
    final normalizedBase = base.trim();
    final normalizedDetail = detail?.trim() ?? '';
    if (normalizedBase.isEmpty) return normalizedDetail;
    if (normalizedDetail.isEmpty) return normalizedBase;
    if (normalizedDetail.contains(normalizedBase)) return normalizedDetail;
    if (normalizedBase.contains(normalizedDetail)) return normalizedBase;
    return '$normalizedBase$normalizedDetail';
  }
}

class _DraftPostcardImage extends StatelessWidget {
  final String imageSource;

  const _DraftPostcardImage({required this.imageSource});

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
