import 'package:flutter/material.dart';
import '../../config/presets.dart';
import '../../config/theme.dart';

class AdminPresetsScreen extends StatelessWidget {
  const AdminPresetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Presets')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Product Types', Presets.productTypes),
          const SizedBox(height: 20),
          _section('Product Issues', Presets.productIssues),
          const SizedBox(height: 20),
          _section('Site Locations',
              Presets.sites.map((s) => '${s['name']} — ${s['address']}').toList()),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.drag_indicator,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(i, style: const TextStyle(fontSize: 13)),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 16, color: AppColors.textSecondary),
                  onPressed: () {},
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}