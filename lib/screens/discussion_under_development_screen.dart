import 'package:flutter/material.dart';

import '../widgets/app_bottom_nav_bar.dart';

class DiscussionUnderDevelopmentScreen extends StatelessWidget {
  const DiscussionUnderDevelopmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.forum_outlined, size: 68, color: Color(0xFF5D6B60)),
                SizedBox(height: 16),
                Text(
                  '讨论区正在开发中',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2F3A30),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '敬请期待',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6C7A6F)),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentTab: AppTab.comment,
        backgroundColor: const Color(0xFFE7E7E7),
        onHomeTap: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            Navigator.pushNamed(context, '/home');
          }
        },
        onMapTap: () => Navigator.pushNamed(context, '/map'),
        onCommentTap: () {},
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
      ),
    );
  }
}
