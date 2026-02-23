import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/edited_postcard_service.dart';
import '../widgets/app_bottom_nav_bar.dart';

/// 首页：首张卡片用于新增明信片，后续卡片按编辑时间倒序展示
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final EditedPostcardService _editedPostcardService = EditedPostcardService();

  List<EditedPostcard> _editedPostcards = const [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  bool _isDeleting = false;
  int? _selectedDeleteIndex;

  @override
  void initState() {
    super.initState();
    _loadEditedPostcards();
  }

  Future<void> _loadEditedPostcards() async {
    final postcards = await _editedPostcardService.getEditedPostcards();
    if (!mounted) return;
    setState(() {
      _editedPostcards = postcards;
      if (_selectedDeleteIndex != null &&
          _selectedDeleteIndex! >= postcards.length) {
        _selectedDeleteIndex = null;
      }
      if (postcards.isEmpty) {
        _isSelectionMode = false;
        _selectedDeleteIndex = null;
      }
      _isLoading = false;
    });
  }

  Future<void> _openPostcardEditor() async {
    final result = await Navigator.pushNamed(context, '/postcard_edit');
    if (result == true) {
      await _loadEditedPostcards();
    }
  }

  void _toggleSelectionMode() {
    if (_editedPostcards.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无已编辑明信片')));
      return;
    }

    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedDeleteIndex = null;
      }
    });
  }

  void _onSelectPostcard(int index) {
    if (!_isSelectionMode) return;
    setState(() {
      _selectedDeleteIndex = _selectedDeleteIndex == index ? null : index;
    });
  }

  Future<void> _deleteSelectedPostcard() async {
    final deleteIndex = _selectedDeleteIndex;
    if (deleteIndex == null || _isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除明信片'),
          content: const Text('确认删除这张已编辑明信片吗？'),
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

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    final deleted = await _editedPostcardService.deleteEditedPostcardAt(
      deleteIndex,
    );
    if (!mounted) return;

    if (!deleted) {
      setState(() {
        _isDeleting = false;
        _selectedDeleteIndex = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
      return;
    }

    await _loadEditedPostcards();
    if (!mounted) return;

    setState(() {
      _isDeleting = false;
      _selectedDeleteIndex = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已删除明信片')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          top: 56,
          bottom: 24,
          left: 20,
          right: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '城市明信片',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w500,
                color: Colors.black,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TopActionButton(
                  icon: _isSelectionMode
                      ? Icons.check_circle_outline
                      : Icons.edit_outlined,
                  label: _isSelectionMode ? '完成' : '编辑',
                  onTap: _toggleSelectionMode,
                ),
                _TopActionButton(
                  icon: Icons.search,
                  label: '搜索',
                  onTap: () => Navigator.pushNamed(context, '/search_screen'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _AddPostcardCard(onTap: _openPostcardEditor),
            if (_isSelectionMode) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _selectedDeleteIndex == null ? '请点击一张已编辑明信片' : '已选中，可点击删除',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4F5A4A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            if (_selectedDeleteIndex != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _isDeleting ? null : _deleteSelectedPostcard,
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
            ],
            const SizedBox(height: 22),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else if (_editedPostcards.isNotEmpty)
              Column(
                children: _editedPostcards.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: _EditedPostcardCard(
                      item: item,
                      selectable: _isSelectionMode,
                      selected: _selectedDeleteIndex == index,
                      onTap: () => _onSelectPostcard(index),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentTab: AppTab.home,
        backgroundColor: Colors.white,
        onHomeTap: () {
          debugPrint('当前在首页');
        },
        onMapTap: () {
          Navigator.pushNamed(context, '/map');
        },
        onCommentTap: () {
          Navigator.pushNamed(context, '/comment_section');
        },
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
      ),
    );
  }
}

class _AddPostcardCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPostcardCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFCBE6BB),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFF9EB694)),
        ),
        child: Center(
          child: Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 7),
            ),
            child: const Icon(Icons.add, size: 72, color: Colors.black),
          ),
        ),
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9.33, vertical: 5.33),
        decoration: BoxDecoration(
          color: const Color(0xFFE9EEDB),
          borderRadius: BorderRadius.circular(13.33),
          border: Border.all(color: const Color(0xFFB8BDAE)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 5.33,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.black87),
            const SizedBox(width: 2.67),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditedPostcardCard extends StatelessWidget {
  final EditedPostcard item;
  final bool selectable;
  final bool selected;
  final VoidCallback onTap;

  const _EditedPostcardCard({
    required this.item,
    required this.selectable,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: selectable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFCBE6BB),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: selected ? const Color(0xFFD75555) : const Color(0xFF9EB694),
            width: selected ? 2.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(31),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _PostcardImage(imageSource: item.imageUrl),
              if (selectable)
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFD75555) : Colors.white,
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
                      size: 16,
                      color: selected ? Colors.white : const Color(0xFF8C9784),
                    ),
                  ),
                ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(item.editedAt),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostcardImage extends StatelessWidget {
  final String imageSource;

  const _PostcardImage({required this.imageSource});

  @override
  Widget build(BuildContext context) {
    if (imageSource.startsWith('assets/')) {
      return Image.asset(
        imageSource,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => _buildFallback(),
      );
    }

    final uri = Uri.tryParse(imageSource);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return _buildFallback();
    }

    return Image.network(
      imageSource,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => _buildFallback(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _buildFallback(showProgress: true);
      },
    );
  }

  Widget _buildFallback({bool showProgress = false}) {
    return ColoredBox(
      color: const Color(0xFFCBE6BB),
      child: Center(
        child: showProgress
            ? const CircularProgressIndicator(strokeWidth: 2)
            : const Icon(
                Icons.image_not_supported_outlined,
                size: 36,
                color: Color(0xFF6E7E68),
              ),
      ),
    );
  }
}
