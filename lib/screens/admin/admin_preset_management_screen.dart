import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/preset_service.dart';

class AdminPresetManagementScreen extends StatefulWidget {
  const AdminPresetManagementScreen({super.key});

  @override
  State<AdminPresetManagementScreen> createState() =>
      _AdminPresetManagementScreenState();
}

class _AdminPresetManagementScreenState
    extends State<AdminPresetManagementScreen>
    with SingleTickerProviderStateMixin {
  final _service = PresetService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Presets'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Product Types'),
            Tab(text: 'Issues'),
            Tab(text: 'Sites'),
            Tab(text: 'Root Causes'),
            Tab(text: 'Solutions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _StringListEditor(
            title: 'Product Types',
            loadFn: _service.getProductTypes,
            saveFn: _service.saveProductTypes,
          ),
          _StringListEditor(
            title: 'Product Issues',
            loadFn: _service.getProductIssues,
            saveFn: _service.saveProductIssues,
          ),
          _SitesEditor(
            loadFn: _service.getSites,
            saveFn: _service.saveSites,
          ),
          _StringListEditor(
            title: 'Root Causes',
            loadFn: _service.getRootCauses,
            saveFn: _service.saveRootCauses,
          ),
          _StringListEditor(
            title: 'Solutions',
            loadFn: _service.getSolutions,
            saveFn: _service.saveSolutions,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// STRING LIST EDITOR (for product types, issues, root causes, solutions)
// ══════════════════════════════════════════════════════════════

class _StringListEditor extends StatefulWidget {
  final String title;
  final Future<List<String>> Function() loadFn;
  final Future<bool> Function(List<String>) saveFn;

  const _StringListEditor({
    required this.title,
    required this.loadFn,
    required this.saveFn,
  });

  @override
  State<_StringListEditor> createState() => _StringListEditorState();
}

class _StringListEditorState extends State<_StringListEditor> {
  List<String> _items = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final list = await widget.loadFn();
    if (!mounted) return;
    setState(() {
      _items = list;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final ok = await widget.saveFn(_items);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Saved successfully' : 'Save failed'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  Future<void> _addItem() async {
    final text = await _showInputDialog(context, 'Add new ${widget.title.toLowerCase().replaceAll('s', '')}');
    if (text != null && text.trim().isNotEmpty) {
      setState(() => _items.add(text.trim()));
    }
  }

  Future<void> _editItem(int index) async {
    final text = await _showInputDialog(context, 'Edit item', initial: _items[index]);
    if (text != null && text.trim().isNotEmpty) {
      setState(() => _items[index] = text.trim());
    }
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Action bar
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_items.length} items',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
                    : const Icon(Icons.save),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _items.isEmpty
              ? const Center(child: Text('No items yet'))
              : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _items.length,
            itemBuilder: (context, i) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.drag_indicator,
                        color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _items[i],
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _editItem(i),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: AppColors.error),
                      onPressed: () => _removeItem(i),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SITES EDITOR (special — has name + address)
// ══════════════════════════════════════════════════════════════

class _SitesEditor extends StatefulWidget {
  final Future<List<Map<String, String>>> Function() loadFn;
  final Future<bool> Function(List<Map<String, String>>) saveFn;

  const _SitesEditor({required this.loadFn, required this.saveFn});

  @override
  State<_SitesEditor> createState() => _SitesEditorState();
}

class _SitesEditorState extends State<_SitesEditor> {
  List<Map<String, String>> _items = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final list = await widget.loadFn();
    if (!mounted) return;
    setState(() {
      _items = list;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final ok = await widget.saveFn(_items);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Saved successfully' : 'Save failed'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  Future<void> _addSite() async {
    final name = await _showInputDialog(context, 'Site name');
    if (name == null || name.trim().isEmpty) return;
    if (!mounted) return;
    final address = await _showInputDialog(context, 'Site address');
    if (address == null || address.trim().isEmpty) return;

    setState(() {
      _items.add({
        'id': 'SITE-${DateTime.now().millisecondsSinceEpoch}',
        'name': name.trim(),
        'address': address.trim(),
      });
    });
  }

  Future<void> _editSite(int index) async {
    final name = await _showInputDialog(
      context,
      'Site name',
      initial: _items[index]['name']!,
    );
    if (name == null || name.trim().isEmpty) return;
    if (!mounted) return;

    final address = await _showInputDialog(
      context,
      'Site address',
      initial: _items[index]['address']!,
    );
    if (address == null || address.trim().isEmpty) return;

    setState(() {
      _items[index] = {
        'id': _items[index]['id']!,
        'name': name.trim(),
        'address': address.trim(),
      };
    });
  }

  void _removeSite(int index) {
    setState(() => _items.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_items.length} sites',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _addSite,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
                    : const Icon(Icons.save),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _items.isEmpty
              ? const Center(child: Text('No sites yet'))
              : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _items.length,
            itemBuilder: (context, i) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _items[i]['name'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _items[i]['address'] ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _editSite(i),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: AppColors.error),
                      onPressed: () => _removeSite(i),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHARED INPUT DIALOG
// ══════════════════════════════════════════════════════════════

Future<String?> _showInputDialog(
    BuildContext context,
    String title, {
      String? initial,
    }) async {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Enter value'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}