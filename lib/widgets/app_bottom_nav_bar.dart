import 'package:flutter/material.dart';

enum AppTab { home, map, comment, profile }

class AppBottomNavBar extends StatelessWidget {
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
        height: 76,
        color: backgroundColor,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                iconAsset: 'assets/images/首页-首页（无色）.png',
                active: currentTab == AppTab.home,
                onTap: onHomeTap,
              ),
            ),
            Expanded(
              child: _NavItem(
                iconAsset: 'assets/images/首页-地图.png',
                active: currentTab == AppTab.map,
                onTap: onMapTap,
              ),
            ),
            Expanded(
              child: _NavItem(
                iconAsset: 'assets/images/首页-讨论区.png',
                active: currentTab == AppTab.comment,
                onTap: onCommentTap,
              ),
            ),
            Expanded(
              child: _NavItem(
                iconAsset: 'assets/images/首页-我的.png',
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
  final String iconAsset;
  final bool active;
  final VoidCallback? onTap;

  const _NavItem({
    required this.iconAsset,
    required this.active,
    this.onTap,
  });

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
            width: 76,
            height: 72,
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
