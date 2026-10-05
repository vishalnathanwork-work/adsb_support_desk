import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';

class AdminTeamManagementScreen extends StatefulWidget {
  final UserModel user;

  const AdminTeamManagementScreen({super.key, required this.user});

  @override
  State<AdminTeamManagementScreen> createState() =>
      _AdminTeamManagementScreenState();
}

class _AdminTeamManagementScreenState
    extends State<AdminTeamManagementScreen> {
  // In a real app, these come from backend
  final List<Map<String, String>> _members = [
    {
      'name': 'ADSB Support Agent',
      'email': 'adsb@adsb.com',
      'role': 'ADSB Support',
      'phone': '+60 12-345 6791',
    },
    {
      'name': 'TT Advisor',
      'email': 'tech@adsb.com',
      'role': 'Technical Advisor',
      'phone': '+60 12-345 6792',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add member coming soon')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Internal teams: ADSB Support (first line) and TT (Technical Advisor). Clients never see these distinctions.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ..._members.map(_memberCard),
        ],
      ),
    );
  }

  Widget _memberCard(Map<String, String> m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.15),
            child: Text(
              m['name']!.substring(0, 1),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m['name']!,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(m['email']!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(m['role']!,
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 20, color: AppColors.textSecondary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }
}