import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/theme.dart';
import '../../../models/client_model.dart';
import '../../../models/site_model.dart';
import '../../../services/site_service.dart';

class SiteFormSheet extends StatefulWidget {
  final List<ClientModel> clients;
  final SiteModel? existingSite;
  final String? initialClientId;

  const SiteFormSheet({
    super.key,
    required this.clients,
    this.existingSite,
    this.initialClientId,
  });

  @override
  State<SiteFormSheet> createState() => _SiteFormSheetState();
}

/// Internal editable representation of a zone during form editing.
class _ZoneDraft {
  String id;
  String name;
  int entryCount;
  int exitCount;
  List<Lane> existingLanes;

  _ZoneDraft({
    required this.id,
    required this.name,
    required this.entryCount,
    required this.exitCount,
    this.existingLanes = const [],
  });

  /// Build final Lane list. Reuses existing lane IDs where possible.
  List<Lane> buildLanes() {
    final existingEntries = existingLanes
        .where((l) => l.isEntry)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final existingExits = existingLanes
        .where((l) => l.isExit)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final lanes = <Lane>[];
    final ts = DateTime.now().millisecondsSinceEpoch;

    for (int i = 1; i <= entryCount; i++) {
      if (i <= existingEntries.length) {
        lanes.add(existingEntries[i - 1]);
      } else {
        lanes.add(Lane(
          id: 'lane_${ts}_${id}_e$i',
          name: 'Entry $i',
          type: 'entry',
          order: i,
        ));
      }
    }

    for (int i = 1; i <= exitCount; i++) {
      if (i <= existingExits.length) {
        lanes.add(existingExits[i - 1]);
      } else {
        lanes.add(Lane(
          id: 'lane_${ts}_${id}_x$i',
          name: 'Exit $i',
          type: 'exit',
          order: i,
        ));
      }
    }

    return lanes;
  }
}

class _SiteFormSheetState extends State<SiteFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _siteService = SiteService();

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;

  String? _selectedClientId;
  List<_ZoneDraft> _zones = [];
  bool _isActive = true;
  bool _isSaving = false;

  bool get isEditMode => widget.existingSite != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existingSite;

    _nameController = TextEditingController(text: s?.name ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _notesController = TextEditingController(text: s?.notes ?? '');

    _selectedClientId = s?.clientId ?? widget.initialClientId;
    _isActive = s?.isActive ?? true;

    if (_selectedClientId == null && widget.clients.length == 1) {
      _selectedClientId = widget.clients.first.id;
    }

    // Convert existing zones to drafts
    if (s != null && s.zones.isNotEmpty) {
      _zones = s.zones.map((z) {
        return _ZoneDraft(
          id: z.id,
          name: z.name,
          entryCount: z.entryCount,
          exitCount: z.exitCount,
          existingLanes: z.lanes,
        );
      }).toList();
    } else {
      // Fresh site → start with one blank zone
      _zones = [_newZoneDraft()];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  _ZoneDraft _newZoneDraft() {
    return _ZoneDraft(
      id: 'zone_${DateTime.now().microsecondsSinceEpoch}',
      name: '',
      entryCount: 0,
      exitCount: 0,
    );
  }

  // ─────────────────────────────────────────────
  // ZONE ACTIONS
  // ─────────────────────────────────────────────

  void _addZone() {
    setState(() {
      _zones.add(_newZoneDraft());
    });
  }

  void _removeZone(int index) {
    if (_zones.length <= 1) {
      _snack('Site must have at least one zone', AppColors.error);
      return;
    }
    setState(() {
      _zones.removeAt(index);
    });
  }

  /// Check if a name is already used by another zone (excluding given index).
  bool _isZoneNameDuplicate(String name, {int? excludeIndex}) {
    if (name.trim().isEmpty) return false;
    for (int i = 0; i < _zones.length; i++) {
      if (excludeIndex != null && i == excludeIndex) continue;
      if (_zones[i].name.trim().toLowerCase() ==
          name.trim().toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  // ─────────────────────────────────────────────
  // SAVE
  // ─────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClientId == null) {
      _snack('Please select a client', AppColors.error);
      return;
    }

    // Validate zones
    final seenNames = <String>{};
    for (int i = 0; i < _zones.length; i++) {
      final z = _zones[i];

      // Zone name required
      if (z.name.trim().isEmpty) {
        _snack('Zone ${i + 1}: name is required', AppColors.error);
        return;
      }

      // Duplicate check
      final lower = z.name.trim().toLowerCase();
      if (seenNames.contains(lower)) {
        _snack(
          'Zone "${z.name}" is duplicated. Zone names must be unique.',
          AppColors.error,
        );
        return;
      }
      seenNames.add(lower);

      // At least 1 lane
      if (z.entryCount == 0 && z.exitCount == 0) {
        _snack(
          'Zone "${z.name}": add at least one entry or exit',
          AppColors.error,
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    // Build final zones
    final zones = _zones.map((draft) {
      return Zone(
        id: draft.id,
        name: draft.name.trim(),
        lanes: draft.buildLanes(),
      );
    }).toList();

    final fields = {
      'client_id': _selectedClientId,
      'name': _nameController.text.trim(),
      'address': _addressController.text.trim(),
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'zones': zones.map((z) => z.toJson()).toList(),
      'is_active': _isActive,
    };

    bool ok;
    if (isEditMode) {
      ok = await _siteService.updateSite(
        siteId: widget.existingSite!.id,
        fields: fields,
      );
    } else {
      final site = SiteModel(
        id: '',
        clientId: _selectedClientId!,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        zones: zones,
        isActive: _isActive,
      );
      final newId = await _siteService.createSite(site);
      ok = newId != null;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      _snack('Failed to save site', AppColors.error);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _handle(),
              const SizedBox(height: 20),
              Text(
                isEditMode ? 'Edit Site' : 'Add Site',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Client
              _label('Client (Company)'),
              DropdownButtonFormField<String>(
                initialValue: _selectedClientId,
                isExpanded: true,
                decoration: const InputDecoration(
                  hintText: 'Select which client owns this site',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                items: widget.clients.map((c) {
                  return DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      c.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedClientId = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              // Name
              _label('Site Name'),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Hospital Melaka',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Required'
                    : null,
              ),
              const SizedBox(height: 14),

              // Address
              _label('Address'),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'e.g. Jalan Melaka, 75000 Melaka',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Required'
                    : null,
              ),
              const SizedBox(height: 14),

              // Notes
              _label('Notes (Optional)'),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Any internal notes about this site',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 24),

              // ─── PARKING ZONES ───
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parking Zones',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Name each zone (e.g. P1, P2) and specify '
                              'how many entry/exit points it has.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Zone list
              ...List.generate(_zones.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildZoneCard(i),
                );
              }),

              // Add zone button
              OutlinedButton.icon(
                onPressed: _addZone,
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Add Another Zone',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  minimumSize: const Size(double.infinity, 46),
                ),
              ),
              const SizedBox(height: 20),

              // Active toggle
              SwitchListTile(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _isActive
                      ? 'Site appears in registration + ticket creation'
                      : 'Site hidden from users',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(height: 16),

              // Save
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                      : Text(
                    isEditMode ? 'Save Changes' : 'Create Site',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ZONE CARD
  // ═══════════════════════════════════════════

  Widget _buildZoneCard(int index) {
    final zone = _zones[index];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: "Zone 1" + remove button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ZONE ${index + 1}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              if (_zones.length > 1)
                InkWell(
                  onTap: () => _removeZone(index),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Zone name
          TextFormField(
            initialValue: zone.name,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'e.g. P1, Basement, North Gate',
              prefixIcon: Icon(Icons.local_parking, size: 20),
              labelText: 'Zone name',
              fillColor: Colors.white,
            ),
            onChanged: (v) {
              zone.name = v;
              setState(() {});
            },
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (_isZoneNameDuplicate(v, excludeIndex: index)) {
                return 'Zone name already used';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Entry / Exit counts
          Row(
            children: [
              Expanded(
                child: _countField(
                  label: 'Entry points',
                  icon: Icons.login,
                  color: AppColors.success,
                  value: zone.entryCount,
                  onChanged: (v) {
                    setState(() => zone.entryCount = v);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _countField(
                  label: 'Exit points',
                  icon: Icons.logout,
                  color: AppColors.warning,
                  value: zone.exitCount,
                  onChanged: (v) {
                    setState(() => zone.exitCount = v);
                  },
                ),
              ),
            ],
          ),

          // Preview chips
          if (zone.entryCount > 0 || zone.exitCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'PREVIEW',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...List.generate(zone.entryCount, (i) {
                        return _previewChip(
                          'Entry ${i + 1}',
                          AppColors.success,
                          Icons.login,
                        );
                      }),
                      ...List.generate(zone.exitCount, (i) {
                        return _previewChip(
                          'Exit ${i + 1}',
                          AppColors.warning,
                          Icons.logout,
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _countField({
    required String label,
    required IconData icon,
    required Color color,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value > 0 ? value.toString() : '',
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          decoration: InputDecoration(
            hintText: '0',
            prefixIcon: Icon(icon, color: color, size: 18),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 12,
            ),
            fillColor: Colors.white,
          ),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          onChanged: (v) {
            final n = int.tryParse(v.trim()) ?? 0;
            onChanged(n);
          },
        ),
      ],
    );
  }

  Widget _previewChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _handle() => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
  );
}