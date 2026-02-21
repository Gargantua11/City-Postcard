import 'package:flutter/material.dart';

import '../widgets/app_bottom_nav_bar.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  static const String _headerAsset = 'assets/images/地图.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Column(children: [const SizedBox(height: 8), _buildHeader()]),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentTab: AppTab.map,
        backgroundColor: Colors.white,
        onHomeTap: () => Navigator.pushReplacementNamed(context, '/home'),
        onMapTap: () {},
        onCommentTap: () =>
            Navigator.pushReplacementNamed(context, '/comment_section'),
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 60,
      child: Center(
        child: Image.asset(
          _headerAsset,
          height: 52,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => const Text(
            '地图',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E2430),
            ),
          ),
        ),
      ),
    );
  }
}
