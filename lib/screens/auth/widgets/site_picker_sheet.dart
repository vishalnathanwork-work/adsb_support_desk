import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/site_model.dart';

class SitePickerSheet extends StatefulWidget {
  final List<SiteModel> allSites;
  final List<SiteModel> initialSelection;
  final bool allowMultiple;

  const SitePickerSheet({
    super.key,
    required this.allSites,
    required this.initialSelection,
    required this.allowMultiple,
  });

  @override
  State<SitePickerSheet> createState() => _SitePickerSheetState();
}

class _SitePickerSheetState extends State<SitePickerSheet> {
  final _searchController = TextEditingController();
  late Set<String> _selectedIds;
  late List<SiteModel> _filtered;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initialSelection.map((s) => s.id).toSet();
    _filtered = widget.allSites;
    _searchController.addListener(_applySearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.allSites;
      } else {
        _filtered = widget.allSites.where((s) {
          return s.name.toLowerCase().contains(q) ||
              s.address.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  void _toggle(SiteModel site) {
    setState(() {
      if (!widget.allowMultiple) {
        _selectedIds = {site.id};
      } else {
        if (_selectedIds.contains(site.id)) {
          _selectedIds.remove(site.id);
        } else {
          _selectedIds.add(site.id);
        }
      }
    });
  }

  void _confirm() {
    final picked =
    widget.allSites.where((s) => _selectedIds.contains(s.id)).toList();
    Navigator.pop(context, picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);

    return Container(
      height: media.size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.allowMultiple
                            ? t.pickerSelectSites
                            : t.pickerSelectOneSite,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.allowMultiple
                            ? t.pickerMultiHint
                            : t.pickerSingleHint,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      t.pickerSelectedCount('${_selectedIds.length}'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: t.pickerSearchHint,
                prefixIcon: const Icon(Icons.search),
                filled: true,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: _filtered.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_off_outlined,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t.pickerNoMatch,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filtered.length,
              itemBuilder: (context, i) {
                final site = _filtered[i];
                final selected = _selectedIds.contains(site.id);
                return _siteRow(site, selected);
              },
            ),
          ),

          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              media.viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: Text(t.adminCancel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _selectedIds.isEmpty ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      t.confirmLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _siteRow(SiteModel site, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _toggle(site),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withOpacity(0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: widget.allowMultiple
                    ? Checkbox(
                  value: selected,
                  onChanged: (_) => _toggle(site),
                  activeColor: AppColors.primary,
                  materialTapTargetSize:
                  MaterialTapTargetSize.shrinkWrap,
                )
                    : Radio<bool>(
                  value: true,
                  groupValue: selected ? true : null,
                  onChanged: (_) => _toggle(site),
                  activeColor: AppColors.primary,
                  materialTapTargetSize:
                  MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      site.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      site.address,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    if (site.zones.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: site.zones.take(6).map((z) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              '${z.name} (${z.entryCount}E / ${z.exitCount}X)',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (site.zones.length > 6)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+ ${site.zones.length - 6} more zones',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textTertiary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}