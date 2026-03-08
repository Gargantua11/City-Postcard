import 'package:flutter/material.dart';

enum AppTab { home, map, comment, profile }

class AppBottomNavBar extends StatelessWidget {
  static const double _scale = 0.75;
  static const double _barHeight = 76 * _scale;

  final AppTab currentTab;
  final VoidCallback? onHomeTap;
  final VoidCallback? onMapTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onProfileTap;
  final Color backgroundColor;

  const AppBottomNavBar({
    super.key,
    required this.currentTab,
    this.onHomeTap,
    this.onMapTap,
    this.onCommentTap,
    this.onProfileTap,
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: _barHeight,
        color: backgroundColor,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                iconAsset: 'assets/images/navigation/首页-首页（无色）.png',
                active: currentTab == AppTab.home,
                onTap: onHomeTap,
              ),
            ),
            Expanded(
              child: _NavItem(
                iconAsset: 'assets/images/navigation/首页-地图.png',
                active: currentTab == AppTab.map,
                onTap: onMapTap,
              ),
            ),
            Expanded(
              child: _NavItem(
                iconAsset: 'assets/images/navigation/首页-讨论区.png',
                active: currentTab == AppTab.comment,
                onTap: onCommentTap,
              ),
            ),
            Expanded(
              child: _NavItem(
                iconAsset: 'assets/images/navigation/首页-我的.png',
                active: currentTab == AppTab.profile,
                onTap: onProfileTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  static const double _scale = 0.75;
  static const double _iconWidth = 76 * _scale;
  static const double _iconHeight = 72 * _scale;

  final String iconAsset;
  final bool active;
  final VoidCallback? onTap;

  const _NavItem({required this.iconAsset, required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFDCEFF6) : Colors.transparent,
          borderRadius: BorderRadius.zero,
        ),
        child: Center(
          child: Container(
            width: _iconWidth,
            height: _iconHeight,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(iconAsset),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
