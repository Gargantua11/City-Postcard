import 'package:flutter/material.dart';
import '../widgets/app_bottom_nav_bar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double maxWidth = constraints.maxWidth;
            final double contentWidth = (maxWidth - 24).clamp(320.0, 440.0);
            final double headerHeight = contentWidth * (236 / 440);
            final double rowWidth = contentWidth * (397 / 440);
            final double rowHeight = rowWidth * (48 / 397);

            return Center(
              child: SizedBox(
                width: contentWidth,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: contentWidth,
                        height: headerHeight,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                'assets/images/profile/用户-画面.png',
                                fit: BoxFit.fill,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                            Align(
                              alignment: const Alignment(0, -0.1),
                              child: Container(
                                width: 128,
                                height: 128,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFC9C9C9),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _NameChip(width: 150, height: 40, text: '嘻嘻嘻'),
                      const SizedBox(height: 22),
                      _ProfileMenuItem(
                        width: rowWidth,
                        height: rowHeight,
                        icon: Icons.location_city_outlined,
                        text: '城市：山东',
                      ),
                      const SizedBox(height: 16),
                      _ProfileMenuItem(
                        width: rowWidth,
                        height: rowHeight,
                        icon: Icons.brush_outlined,
                        text: '已创作：N张明信片',
                      ),
                      const SizedBox(height: 16),
                      _ProfileMenuItem(
                        width: rowWidth,
                        height: rowHeight,
                        icon: Icons.thumb_up_outlined,
                        text: '获得点赞数：N',
                      ),
                      const SizedBox(height: 16),
                      _ProfileMenuItem(
                        width: rowWidth,
                        height: rowHeight,
                        icon: Icons.edit_outlined,
                        text: '编辑个人信息',
                      ),
                      const SizedBox(height: 16),
                      _ProfileMenuItem(
                        width: rowWidth,
                        height: rowHeight,
                        icon: Icons.drafts_outlined,
                        text: '草稿箱',
                      ),
                      const SizedBox(height: 16),
                      _ProfileMenuItem(
                        width: rowWidth,
                        height: rowHeight,
                        icon: Icons.folder_open_outlined,
                        text: '收藏夹',
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentTab: AppTab.profile,
        backgroundColor: const Color(0xFFE7E7E7),
        onHomeTap: () {
          Navigator.pushNamed(context, '/home');
        },
        onMapTap: () {
          Navigator.pushNamed(context, '/map');
        },
        onCommentTap: () {
          Navigator.pushNamed(context, '/comment_section');
        },
        onProfileTap: () {
          debugPrint('当前在我的');
        },
      ),
    );
  }
}

class _NameChip extends StatelessWidget {
  final double width;
  final double height;
  final String text;

  const _NameChip({
    required this.width,
    required this.height,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFD0D9C4),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20 / 1.8,
          color: Color(0xFF5F685F),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final double width;
  final double height;
  final IconData icon;
  final String text;

  const _ProfileMenuItem({
    required this.width,
    required this.height,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: const Color(0xFFD9DDD2),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 34, color: Colors.black87),
          const Spacer(),
          Text(
            text,
            style: const TextStyle(
              fontSize: 32 / 3,
              color: Color(0xFF4C5450),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 18),
          const Icon(Icons.chevron_right, size: 28, color: Color(0xFF7D817D)),
        ],
      ),
    );
  }
}
