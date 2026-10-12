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
            title: 'Product Type',
            loadFn: _service.getProductTypes,
            saveFn: _service.saveProductTypes,
          ),
          _ProductIssuesEditor(
            loadProductTypes: _service.getProductTypes,
            loadFn: _service.getProductIssues,
            saveFn: _service.saveProductIssues,
          ),
          _SitesEditor(
            loadFn: _service.getSites,
            saveFn: _service.saveSites,
          ),
          _StringListEditor(
            title: 'Root Cause',
            loadFn: _service.getRootCauses,
            saveFn: _service.saveRootCauses,
          ),
          _StringListEditor(
            title: 'Solution',
            loadFn: _service.getSolutions,
            saveFn: _service.saveSolutions,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// STRING LIST EDITOR
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
    final text = await _showInputDialog(
      context,
      'Add ${widget.title}',
    );
    if (text != null && text.trim().isNotEmpty) {
      setState(() => _items.add(text.trim()));
    }
  }

  Future<void> _editItem(int index) async {
    final text = await _showInputDialog(
      context,
      'Edit item',
      initial: _items[index],
    );
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
                    const Icon(
                      Icons.drag_indicator,
                      color: AppColors.textSecondary,
                    ),
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
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.error,
                      ),
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
// PRODUCT ISSUES EDITOR (map: product type → list of issues)
// ══════════════════════════════════════════════════════════════

class _ProductIssuesEditor extends StatefulWidget {
  final Future<List<String>> Function() loadProductTypes;
  final Future<Map<String, List<String>>> Function() loadFn;
  final Future<bool> Function(Map<String, List<String>>) saveFn;

  const _ProductIssuesEditor({
    required this.loadProductTypes,
    required this.loadFn,
    required this.saveFn,
  });

  @override
  State<_ProductIssuesEditor> createState() => _ProductIssuesEditorState();
}

class _ProductIssuesEditorState extends State<_ProductIssuesEditor> {
  Map<String, List<String>> _map = {};
  List<String> _productTypes = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final types = await widget.loadProductTypes();
    final data = await widget.loadFn();
    if (!mounted) return;
    setState(() {
      _productTypes = types;
      _map = data;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final ok = await widget.saveFn(_map);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Saved successfully' : 'Save failed'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  Future<void> _addGroup() async {
    // Pick a product type that doesn't already have an entry
    final available = _productTypes
        .where((t) => !_map.containsKey(t))
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All product types already have issue lists'),
        ),
      );
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add group for product type'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: available.length,
            itemBuilder: (context, i) {
              return ListTile(
                title: Text(available[i]),
                onTap: () => Navigator.pop(context, available[i]),
              );
            },
          ),
        ),
      ),
    );

    if (selected == null) return;
    setState(() {
      _map[selected] = [];
    });
  }

  Future<void> _renameGroup(String oldKey) async {
    final newKey = await _showInputDialog(
      context,
      'Rename product type',
      initial: oldKey,
    );
    if (newKey == null || newKey.trim().isEmpty) return;
    if (newKey == oldKey) return;
    if (!mounted) return;
    if (_map.containsKey(newKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That key already exists')),
      );
      return;
    }
    setState(() {
      _map[newKey.trim()] = _map.remove(oldKey)!;
    });
  }

  void _removeGroup(String key) {
    setState(() => _map.remove(key));
  }

  Future<void> _addIssue(String key) async {
    final text = await _showInputDialog(context, 'Add issue for "$key"');
    if (text != null && text.trim().isNotEmpty) {
      setState(() {
        _map[key] = [...(_map[key] ?? []), text.trim()];
      });
    }
  }

  Future<void> _editIssue(String key, int index) async {
    final text = await _showInputDialog(
      context,
      'Edit issue',
      initial: _map[key]![index],
    );
    if (text != null && text.trim().isNotEmpty) {
      setState(() {
        _map[key]![index] = text.trim();
      });
    }
  }

  void _removeIssue(String key, int index) {
    setState(() => _map[key]!.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final keys = _map.keys.toList()..sort();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${keys.length} product types',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _addGroup,
                icon: const Icon(Icons.add),
                label: const Text('Add Type'),
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
          child: keys.isEmpty
              ? const Center(
            child: Text('No product types configured yet'),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: keys.length,
            itemBuilder: (context, i) => _groupCard(keys[i]),
          ),
        ),
      ],
    );
  }

  Widget _groupCard(String key) {
    final issues = _map[key] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Theme(
        // Turn off the ExpansionTile's default dividers.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            key,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${issues.length} issues',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _renameGroup(key),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.error,
                ),
                onPressed: () => _removeGroup(key),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (issues.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No issues yet',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    ...issues.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final issue = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                issue,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              onPressed: () => _editIssue(key, idx),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: AppColors.error,
                              ),
                              onPressed: () => _removeIssue(key, idx),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => _addIssue(key),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add issue'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SITES EDITOR
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
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                    ),
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
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.error,
                      ),
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