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
      _isLoading = false;
    });
  }

  Future<void> _openPostcardEditor() async {
    final result = await Navigator.pushNamed(context, '/postcard_edit');
    if (result == true) {
      await _loadEditedPostcards();
    }
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
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/city_search'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9EEDB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFB8BDAE)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search, size: 18, color: Colors.black87),
                      SizedBox(width: 4),
                      Text(
                        '搜索',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            _AddPostcardCard(onTap: _openPostcardEditor),
            const SizedBox(height: 22),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else if (_editedPostcards.isNotEmpty)
              Column(
                children: _editedPostcards
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: _EditedPostcardCard(item: item),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _HomeBottomNavigationBar(
        onCommentTap: () => Navigator.pushNamed(context, '/comment_section'),
      ),
    );
  }
}

class _HomeBottomNavigationBar extends StatelessWidget {
  final VoidCallback onCommentTap;

  const _HomeBottomNavigationBar({required this.onCommentTap});

  @override
  Widget build(BuildContext context) {
    return AppBottomNavBar(
      currentTab: AppTab.home,
      backgroundColor: Colors.white,
      onHomeTap: () {
        debugPrint('当前在首页');
      },
      onMapTap: () {
        debugPrint('切换到地图');
      },
      onCommentTap: onCommentTap,
      onProfileTap: () => Navigator.pushNamed(context, '/profile'),
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

class _EditedPostcardCard extends StatelessWidget {
  final EditedPostcard item;

  const _EditedPostcardCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFCBE6BB),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF9EB694)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(31),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _PostcardImage(imageSource: item.imageUrl),
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
