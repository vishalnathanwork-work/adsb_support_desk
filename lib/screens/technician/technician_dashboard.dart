import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/session_service.dart';
import '../main_navigation.dart';
import '../client/client_profile_tab.dart';

class TechnicianDashboard extends StatelessWidget {
  final UserModel user;

  const TechnicianDashboard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return MainNavigation(
      user: user,
      tabs: [
        NavTab(
          label: 'Home',
          icon: Icons.home_outlined,
          page: _TTAdvisorHome(user: user),
        ),
        NavTab(
          label: 'Reviews',
          icon: Icons.rate_review_outlined,
          page: _TTReviewQueue(),
        ),
        NavTab(
          label: 'Profile',
          icon: Icons.person_outline,
          page: ClientProfileTab(
            user: user,
            onLogout: () async {
              await SessionService().clear();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (r) => false);
              }
            },
          ),
        ),
      ],
    );
  }
}

class _TTAdvisorHome extends StatelessWidget {
  final UserModel user;
  const _TTAdvisorHome({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Technical Advisor')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5E35B1), Color(0xFF4527A0)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Technical Advisor',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(user.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _statCard('Pending', '0', AppColors.warning)),
                const SizedBox(width: 12),
                Expanded(
                    child: _statCard('In Review', '0', AppColors.accent)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Advised', '0', AppColors.success)),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _actionTile(Icons.rate_review_outlined, 'Review Escalated Issue',
                'Analyze and diagnose', AppColors.primary),
            _actionTile(Icons.lightbulb_outline, 'Provide Solution to ADSB',
                'Send advice + request on-site', AppColors.accent),
            _actionTile(Icons.visibility_outlined, 'Monitor On-Site Progress',
                'Assist if needed', AppColors.warning),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _actionTile(
      IconData icon, String title, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _TTReviewQueue extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Queue')),
      body: const Center(
        child: Text('No escalated tickets',
            style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}