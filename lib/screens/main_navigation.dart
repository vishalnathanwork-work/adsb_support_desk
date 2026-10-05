import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/user_model.dart';
import '../services/session_service.dart';

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
  final _session = SessionService();

  @override
  Widget build(BuildContext context) {
    final page = widget.tabs[_index].page;

    return Scaffold(
      body: page,
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