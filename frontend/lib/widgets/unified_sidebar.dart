import 'package:flutter/material.dart';
import '../main.dart';
import '../screens/dashboard_screen.dart';
import '../screens/community_screen.dart';

class UnifiedSidebar extends StatelessWidget {
  final int activeIndex; // 0 for Home, 1 for Analysis

  const UnifiedSidebar({
    super.key,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      color: Colors.black,
      child: Column(
        children: [
          const SizedBox(height: 20),
          // 1. HOME ICON
          _SidebarIcon(
            icon: Icons.home,
            isActive: activeIndex == 0,
            onTap: () {
              if (activeIndex != 0) {
                Navigator.of(context).pushReplacement(
                  createSlideRoute(const LandingWrapper()),
                );
              }
            },
          ),
          const SizedBox(height: 20),
          // 2. BRAND SHIELD (Decorative)
          const Icon(
            Icons.shield_outlined,
            color: Color(0xFFD4AF37),
            size: 36,
          ),
          const SizedBox(height: 30),
          // 3. ANALYSIS ICON
          _SidebarIcon(
            icon: Icons.analytics,
            isActive: activeIndex == 1,
            onTap: () {
              if (activeIndex != 1) {
                Navigator.of(context).pushReplacement(
                  createSlideRoute(const DashboardScreen()),
                );
              }
            },
          ),
          const SizedBox(height: 10),
          // 4. COMMUNITY ICON
          _SidebarIcon(
            icon: Icons.groups,
            isActive: activeIndex == 2,
            onTap: () {
              if (activeIndex != 2) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CommunityScreen(),
                  ),
                );
              }
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _SidebarIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarIcon({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFD4AF37).withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isActive ? const Color(0xFFD4AF37) : Colors.white70,
            size: 26,
          ),
        ),
      ),
    );
  }
}
