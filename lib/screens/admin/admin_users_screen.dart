import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';

class AdminUsersScreen extends StatelessWidget {
  final UserModel user;

  const AdminUsersScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final users = [
      {
        'name': 'Parken Client',
        'email': 'client@adsb.com',
        'role': 'Client',
        'company': 'Parken Sdn Bhd',
      },
      {
        'name': 'Parken Operator',
        'email': 'operator@adsb.com',
        'role': 'Operator',
        'company': 'Parken Sdn Bhd',
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: users.map((u) => _userCard(context, u)).toList(),
      ),
    );
  }

  Widget _userCard(BuildContext context, Map<String, String> u) {
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
            backgroundColor: AppColors.warning.withOpacity(0.15),
            child: Text(
              u['name']!.substring(0, 1),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u['name']!,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(u['email']!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text('${u['company']} — ${u['role']}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}