import 'package:flutter/material.dart';

import '../screens/AI_Plan.dart';
import '../screens/Bonder.dart';
import '../screens/DestinationLandingPage.dart';
import '../screens/plans_list.dart';
import '../screens/profile.dart';

enum AppNavTab {
  home,
  search,
  plan,
  bonders,
  profile,
}

class AppBottomNav extends StatelessWidget {
  final AppNavTab currentTab;
  final WidgetBuilder? planBuilder;

  const AppBottomNav({
    super.key,
    required this.currentTab,
    this.planBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 70,
        decoration: const BoxDecoration(
          color: Color(0xFF4675B8),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(
              width: 50,
              child: _NavIcon(
                icon: Icons.home,
                active: currentTab == AppNavTab.home,
                onTap: () => _navigateTo(context, AppNavTab.home),
              ),
            ),
            SizedBox(
              width: 50,
              child: _NavIcon(
                icon: Icons.search,
                active: currentTab == AppNavTab.search,
                onTap: () => _navigateTo(context, AppNavTab.search),
              ),
            ),
            SizedBox(
              width: 50,
              child: _NavIcon(
                icon: Icons.airplanemode_active,
                active: currentTab == AppNavTab.plan,
                onTap: () => _navigateTo(context, AppNavTab.plan),
              ),
            ),
            SizedBox(
              width: 50,
              child: _NavIcon(
                icon: Icons.group_outlined,
                active: currentTab == AppNavTab.bonders,
                onTap: () => _navigateTo(context, AppNavTab.bonders),
              ),
            ),
            SizedBox(
              width: 50,
              child: _NavIcon(
                icon: Icons.person_outline,
                active: currentTab == AppNavTab.profile,
                onTap: () => _navigateTo(context, AppNavTab.profile),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, AppNavTab tab) {
    if (tab == currentTab) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => _buildScreen(context, tab)),
    );
  }

  Widget _buildScreen(BuildContext context, AppNavTab tab) {
    switch (tab) {
      case AppNavTab.home:
        return const DestinationLandingPage();
      case AppNavTab.search:
        return const PlansList(source: 'home');
      case AppNavTab.plan:
        return planBuilder?.call(context) ?? const AI_Plan();
      case AppNavTab.bonders:
        return const Bonders();
      case AppNavTab.profile:
        return const Profile();
    }
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: Colors.white),
          if (active) ...[
            const SizedBox(height: 4),
            Container(
              width: 20,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
