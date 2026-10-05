import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';

class DataInspectorScreen extends StatefulWidget {
  const DataInspectorScreen({super.key});

  @override
  State<DataInspectorScreen> createState() => _DataInspectorScreenState();
}

class _DataInspectorScreenState extends State<DataInspectorScreen> {
  Map<String, dynamic> _data = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    final result = <String, dynamic>{};
    for (final key in keys) {
      if (key.startsWith('flutter.')) continue; // skip internal

      final value = prefs.get(key);
      if (value is String) {
        try {
          result[key] = jsonDecode(value);
        } catch (_) {
          result[key] = value;
        }
      } else if (value is List) {
        result[key] = value.map((e) {
          try {
            return jsonDecode(e);
          } catch (_) {
            return e;
          }
        }).toList();
      } else {
        result[key] = value;
      }
    }

    if (!mounted) return;
    setState(() {
      _data = result;
      _isLoading = false;
    });
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear ALL local data?'),
        content: const Text(
            'This will delete every ticket, notification, and chat message. Cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Inspector'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _clearAll,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data.isEmpty
          ? const Center(child: Text('No local data'))
          : ListView(
        padding: const EdgeInsets.all(12),
        children: _data.entries.map((e) {
          final value = e.value;
          final count = value is List ? value.length : 1;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              title: Text(
                e.key,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              subtitle: Text(
                value is List
                    ? '${value.length} items'
                    : '1 item',
                style: const TextStyle(fontSize: 12),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    const JsonEncoder.withIndent('  ')
                        .convert(value),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}