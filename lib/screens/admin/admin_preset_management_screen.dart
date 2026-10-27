import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/localized_preset.dart';
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
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.presetsTitle),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black,
          indicatorColor: Colors.black,
          tabs: [
            Tab(text: t.presetsProductTypes),
            Tab(text: t.presetsIssues),
            Tab(text: t.presetsRootCauses),
            Tab(text: t.presetsSolutions),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _StringListEditor(
            title: t.presetsProductTypes,
            loadFn: _service.getProductTypes,
            saveFn: _service.saveProductTypes,
          ),
          _ProductIssuesEditor(
            loadProductTypes: _service.getProductTypes,
            loadFn: _service.getProductIssues,
            saveFn: _service.saveProductIssues,
          ),
          _StringListEditor(
            title: t.presetsRootCauses,
            loadFn: _service.getRootCauses,
            saveFn: _service.saveRootCauses,
          ),
          _StringListEditor(
            title: t.presetsSolutions,
            loadFn: _service.getSolutions,
            saveFn: _service.saveSolutions,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// STRING LIST EDITOR (dual language)
// ══════════════════════════════════════════════════════════════

class _StringListEditor extends StatefulWidget {
  final String title;
  final Future<List<LocalizedPreset>> Function() loadFn;
  final Future<bool> Function(List<LocalizedPreset>) saveFn;

  const _StringListEditor({
    required this.title,
    required this.loadFn,
    required this.saveFn,
  });

  @override
  State<_StringListEditor> createState() => _StringListEditorState();
}

class _StringListEditorState extends State<_StringListEditor> {
  List<LocalizedPreset> _items = [];
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
    final t = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    final ok = await widget.saveFn(_items);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? t.presetsSaved : t.presetsSaveFailed),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  Future<void> _addItem() async {
    final t = AppLocalizations.of(context)!;
    final result = await _showDualDialog(
      context,
      '${t.presetsAdd} ${widget.title}',
    );
    if (result != null) {
      setState(() {
        final key = _slugify(result.en);
        _items.add(LocalizedPreset(key: key, en: result.en, ms: result.ms));
      });
    }
  }

  Future<void> _editItem(int index) async {
    final t = AppLocalizations.of(context)!;
    final existing = _items[index];
    final result = await _showDualDialog(
      context,
      t.presetsEditItem,
      initialEn: existing.en,
      initialMs: existing.ms,
    );
    if (result != null) {
      setState(() {
        _items[index] = LocalizedPreset(
          key: existing.key, // key stays stable
          en: result.en,
          ms: result.ms,
        );
      });
    }
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

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
                  t.itemsCount('${_items.length}'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: Text(t.presetsAdd),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.save),
                label: Text(t.presetsSave),
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
              ? Center(child: Text(t.presetsNoItems))
              : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _items.length,
            itemBuilder: (context, i) => _itemCard(i),
          ),
        ),
      ],
    );
  }

  Widget _itemCard(int index) {
    final p = _items[index];
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.en,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'MS: ${p.ms}',
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
            onPressed: () => _editItem(index),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: AppColors.error,
            ),
            onPressed: () => _removeItem(index),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PRODUCT ISSUES EDITOR (dual language)
// ══════════════════════════════════════════════════════════════

class _ProductIssuesEditor extends StatefulWidget {
  final Future<List<LocalizedPreset>> Function() loadProductTypes;
  final Future<Map<String, List<LocalizedPreset>>> Function() loadFn;
  final Future<bool> Function(Map<String, List<LocalizedPreset>>) saveFn;

  const _ProductIssuesEditor({
    required this.loadProductTypes,
    required this.loadFn,
    required this.saveFn,
  });

  @override
  State<_ProductIssuesEditor> createState() => _ProductIssuesEditorState();
}

class _ProductIssuesEditorState extends State<_ProductIssuesEditor> {
  Map<String, List<LocalizedPreset>> _map = {};
  List<LocalizedPreset> _productTypes = [];
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
    final t = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    final ok = await widget.saveFn(_map);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? t.presetsSaved : t.presetsSaveFailed),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  Future<void> _addGroup() async {
    final t = AppLocalizations.of(context)!;
    final available =
    _productTypes.where((p) => !_map.containsKey(p.key)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.noProductTypesLoaded)),
      );
      return;
    }

    final locale = Localizations.localeOf(context);
    final selected = await showDialog<LocalizedPreset>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${t.presetsAdd} ${t.presetsProductTypes}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: available.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(available[i].localized(locale)),
              onTap: () => Navigator.pop(context, available[i]),
            ),
          ),
        ),
      ),
    );
    if (selected != null) {
      setState(() => _map[selected.key] = []);
    }
  }

  Future<void> _addIssue(String key) async {
    final t = AppLocalizations.of(context)!;
    final result = await _showDualDialog(
      context,
      '${t.presetsAdd} ${t.presetsIssues}',
    );
    if (result != null) {
      setState(() {
        final issueKey = _slugify(result.en);
        _map[key] = [
          ...(_map[key] ?? []),
          LocalizedPreset(key: issueKey, en: result.en, ms: result.ms),
        ];
      });
    }
  }

  Future<void> _editIssue(String key, int index) async {
    final t = AppLocalizations.of(context)!;
    final existing = _map[key]![index];
    final result = await _showDualDialog(
      context,
      t.presetsEditItem,
      initialEn: existing.en,
      initialMs: existing.ms,
    );
    if (result != null) {
      setState(() {
        _map[key]![index] = LocalizedPreset(
          key: existing.key,
          en: result.en,
          ms: result.ms,
        );
      });
    }
  }

  void _removeIssue(String key, int index) {
    setState(() => _map[key]!.removeAt(index));
  }

  void _removeGroup(String key) {
    setState(() => _map.remove(key));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final keys = _map.keys.toList()..sort();
    final locale = Localizations.localeOf(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.productTypesCount('${keys.length}'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _addGroup,
                icon: const Icon(Icons.add),
                label: Text(t.presetsAdd),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.save),
                label: Text(t.presetsSave),
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
              ? Center(child: Text(t.presetsNoItems))
              : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: keys.length,
            itemBuilder: (context, i) {
              final key = keys[i];
              final productType = _productTypes.firstWhere(
                    (p) => p.key == key,
                orElse: () =>
                    LocalizedPreset(key: key, en: key, ms: key),
              );
              final issues = _map[key] ?? [];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(
                      productType.localized(locale),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${productType.en} · ${t.issuesCount('${issues.length}')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppColors.error,
                      ),
                      onPressed: () => _removeGroup(key),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (issues.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  t.presetsNoItems,
                                  style: const TextStyle(
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
                                  margin: const EdgeInsets.only(
                                    bottom: 6,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius:
                                    BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              issue.en,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight:
                                                FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              'MS: ${issue.ms}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors
                                                    .textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 16,
                                        ),
                                        onPressed: () =>
                                            _editIssue(key, idx),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 16,
                                          color: AppColors.error,
                                        ),
                                        onPressed: () =>
                                            _removeIssue(key, idx),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            const SizedBox(height: 4),
                            TextButton.icon(
                              onPressed: () => _addIssue(key),
                              icon: const Icon(Icons.add, size: 16),
                              label: Text(t.presetsAdd),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
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
// SHARED DUAL-LANGUAGE DIALOG
// ══════════════════════════════════════════════════════════════

Future<({String en, String ms})?> _showDualDialog(
    BuildContext context,
    String title, {
      String? initialEn,
      String? initialMs,
    }) async {
  final t = AppLocalizations.of(context)!;
  final enController = TextEditingController(text: initialEn ?? '');
  final msController = TextEditingController(text: initialMs ?? '');

  return showDialog<({String en, String ms})>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: enController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'English',
              hintText: 'e.g. Barrier',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: msController,
            decoration: const InputDecoration(
              labelText: 'Bahasa Melayu',
              hintText: 'cth. Palang',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.adminCancel),
        ),
        TextButton(
          onPressed: () {
            final en = enController.text.trim();
            final ms = msController.text.trim();
            if (en.isEmpty) return;
            Navigator.pop(
              context,
              (en: en, ms: ms.isEmpty ? en : ms),
            );
          },
          child: Text(t.ok),
        ),
      ],
    ),
  );
}

String _slugify(String s) {
  return s
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}