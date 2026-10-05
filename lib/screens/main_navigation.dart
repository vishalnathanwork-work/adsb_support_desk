import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/user_model.dart';

class MainNavigation extends StatefulWidget {
  final UserModel user;
  final List<NavTab> tabs;

  const MainNavigation({super.key, required this.user, required this.tabs});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class NavTab {
  final String label;
  final IconData icon;
  final Widget page;

  NavTab({required this.label, required this.icon, required this.page});
}

class _MainNavigationState extends State<MainNavigation> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // Safely reset index if tabs list changes
    if (_index >= widget.tabs.length) _index = 0;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: widget.tabs.map((t) => t.page).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withOpacity(0.15),
        destinations: widget.tabs
            .map(
              (t) => NavigationDestination(
            icon: Icon(t.icon),
            label: t.label,
          ),
        )
            .toList(),
      ),
    );
  }
}