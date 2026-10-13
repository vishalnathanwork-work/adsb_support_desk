import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/user_model.dart';

class MainNavigation extends StatefulWidget {
  final UserModel user;
  final List<NavTab> tabs;

  const MainNavigation({
    super.key,
    required this.user,
    required this.tabs,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class NavTab {
  final String label;
  final IconData icon;
  final Widget page;

  NavTab({
    required this.label,
    required this.icon,
    required this.page,
  });
}

class _MainNavigationState extends State<MainNavigation> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.tabs.length) _index = 0;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: widget.tabs.map((t) => t.page).toList(),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          destinations: widget.tabs
              .map(
                (t) => NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.icon, color: AppColors.primary),
              label: t.label,
            ),
          )
              .toList(),
        ),
      ),
    );
  }
}