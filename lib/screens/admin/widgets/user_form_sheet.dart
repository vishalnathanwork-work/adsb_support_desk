import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../config/theme.dart';
import '../../../models/client_model.dart';
import '../../../models/site_model.dart';
import '../../../services/client_service.dart';
import '../../../services/site_service.dart';
import '../../../services/user_service.dart';

class UserFormSheet extends StatefulWidget {
  final List<String> allowedRoles;
  final Map<String, dynamic>? existingUser;

  const UserFormSheet({
    super.key,
    required this.allowedRoles,
    this.existingUser,
  });

  @override
  State<UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();
  final _siteService = SiteService();
  final _clientService = ClientService();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _companyController;

  String? _selectedRole;
  ClientModel? _selectedClient;
  List<ClientModel> _allClients = [];
  List<SiteModel> _clientSites = [];
  Set<String> _selectedSiteIds = {};

  bool _loadingClients = true;
  bool _loadingSites = false;
  bool _isSaving = false;

  bool get isEditMode => widget.existingUser != null;
  bool get isExternalRole =>
      widget.allowedRoles.contains('client') ||
          widget.allowedRoles.contains('operator');
  bool get requiresClient => isExternalRole;

  @override
  void initState() {
    super.initState();
    final u = widget.existingUser;

    _nameController = TextEditingController(text: u?['name'] ?? '');
    _emailController = TextEditingController(text: u?['email'] ?? '');
    _phoneController = TextEditingController(text: u?['phone'] ?? '');
    _companyController = TextEditingController(text: u?['company'] ?? '');
    _selectedRole = u?['role'] ?? widget.allowedRoles.first;

    if (u?['site_ids'] is List) {
      _selectedSiteIds = Set<String>.from(
          (u!['site_ids'] as List).map((e) => e.toString()));
    }

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loadingClients = true);

    final clients = await _clientService.getAllClients();

    final existingClientId = widget.existingUser?['client_id'] as String?;
    ClientModel? preSelected;
    if (existingClientId != null) {
      for (final c in clients) {
        if (c.id == existingClientId) {
          preSelected = c;
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _allClients = clients;
      _selectedClient = preSelected;
      _loadingClients = false;
    });

    if (preSelected != null) {
      await _loadSitesFor(preSelected.id);
    }
  }

  Future<void> _loadSitesFor(String clientId) async {
    setState(() {
      _loadingSites = true;
      _clientSites = [];
    });

    final sites = await _siteService.getSitesByClientId(clientId);

    if (!mounted) return;
    setState(() {
      _clientSites = sites;
      _loadingSites = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // SAVE — Edit mode
  // ─────────────────────────────────────────────

  Future<void> _saveEdit() async {
    if (!_formKey.currentState!.validate()) return;
    if (requiresClient && _selectedClient == null) {
      _snack('Please select a client', AppColors.error);
      return;
    }
    if (requiresClient && _selectedSiteIds.isEmpty) {
      _snack('Please assign at least one site', AppColors.error);
      return;
    }

    setState(() => _isSaving = true);

    final uid = widget.existingUser!['uid'] as String;

    final ok = await _userService.updateUser(
      uid: uid,
      fields: {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'company': _companyController.text.trim(),
        'role': _selectedRole,
        'client_id': requiresClient ? _selectedClient?.id : null,
        'site_ids': _selectedSiteIds.toList(),
      },
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      _snack('Failed to save changes', AppColors.error);
    }
  }

  // ─────────────────────────────────────────────
  // SAVE — Create mode
  // ─────────────────────────────────────────────

  Future<void> _saveCreate() async {
    if (!_formKey.currentState!.validate()) return;
    if (requiresClient && _selectedClient == null) {
      _snack('Please select a client', AppColors.error);
      return;
    }
    if (requiresClient && _selectedSiteIds.isEmpty) {
      _snack('Please assign at least one site', AppColors.error);
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    final name = _nameController.text.trim();
    final role = _selectedRole!;
    final phone = _phoneController.text.trim();
    final company = _companyController.text.trim();
    final clientId = requiresClient ? _selectedClient!.id : null;
    final clientName = requiresClient ? _selectedClient!.name : null;
    final siteIds = _selectedSiteIds.toList();

    final suggestedPassword =
        '${email.split('@').first}@${DateTime.now().year}';

    final uid = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UidEntryDialog(
        email: email,
        name: name,
        role: role,
        phone: phone,
        company: company,
        clientId: clientId,
        clientName: clientName,
        siteIds: siteIds,
        suggestedPassword: suggestedPassword,
      ),
    );

    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': email,
        'name': name,
        'role': role,
        'phone': phone.isEmpty ? null : phone,
        'company': company.isEmpty ? null : company,
        'client_id': clientId,
        'client_name': clientName,
        'site_ids': siteIds,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _snack('User added successfully', AppColors.success);
      Navigator.pop(context, true);
    } catch (e) {
      _snack('Failed to save profile: $e', AppColors.error);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
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
      child: _loadingClients
          ? const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      )
          : SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                isEditMode ? 'Edit User' : 'Add New User',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Name
              _label('Full Name'),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Ahmad bin Abdullah',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Email
              _label('Login Email'),
              TextFormField(
                controller: _emailController,
                enabled: !isEditMode,
                decoration: InputDecoration(
                  hintText: 'user@example.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  fillColor:
                  isEditMode ? Colors.grey.shade100 : Colors.white,
                  helperText: isEditMode
                      ? 'Email cannot be changed'
                      : 'User will use this to log in',
                  helperStyle: const TextStyle(fontSize: 11),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Role
              _label('Role'),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: widget.allowedRoles
                    .map((r) => DropdownMenuItem(
                  value: r,
                  child: Text(_roleLabel(r)),
                ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedRole = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // ─── Client selection (external roles only) ───
              if (requiresClient) ...[
                _label('Client (Company)'),
                DropdownButtonFormField<String>(
                  value: _selectedClient?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Select which client this user belongs to',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  items: _allClients.map((c) {
                    return DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        c.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (id) async {
                    if (id == null) return;
                    final client =
                    _allClients.firstWhere((c) => c.id == id);
                    setState(() {
                      _selectedClient = client;
                      _selectedSiteIds.clear();
                    });
                    await _loadSitesFor(id);
                  },
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // ─── Site selection ───
                if (_selectedClient != null) ...[
                  _label('Assign Sites'),
                  _buildSiteSelector(),
                  const SizedBox(height: 16),
                ],
              ],

              // Phone
              _label('Phone (Optional)'),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '+60 12-345 6789',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Company (only external roles)
              if (isExternalRole) ...[
                _label('Company Name (Optional)'),
                TextFormField(
                  controller: _companyController,
                  decoration: const InputDecoration(
                    hintText: 'Auto-filled from selected client',
                    prefixIcon: Icon(Icons.apartment_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tip: leave blank to use the client name above.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 8),

              // Save
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : (isEditMode ? _saveEdit : _saveCreate),
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
                    isEditMode ? 'Save Changes' : 'Create User',
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

  Widget _buildSiteSelector() {
    if (_loadingSites) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_clientSites.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.warning),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: AppColors.warning),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This client has no sites. Add sites in Firebase Console first.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: _clientSites.map((site) {
          final selected = _selectedSiteIds.contains(site.id);
          return CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: selected,
            activeColor: AppColors.primary,
            title: Text(
              site.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  site.address,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (site.lanes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: site.lanes.map((lane) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            lane.name, // ← just "P1", "P2"
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedSiteIds.add(site.id);
                } else {
                  _selectedSiteIds.remove(site.id);
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
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

  String _roleLabel(String role) {
    switch (role) {
      case 'client':
        return 'Client';
      case 'operator':
        return 'Operator';
      case 'adsb':
        return 'ADSB Support Team';
      case 'technician':
        return 'Technical Advisor';
      case 'admin':
        return 'Administrator';
      default:
        return role;
    }
  }
}

// ═══════════════════════════════════════════════
// UID ENTRY DIALOG
// ═══════════════════════════════════════════════

class _UidEntryDialog extends StatefulWidget {
  final String email;
  final String name;
  final String role;
  final String phone;
  final String company;
  final String? clientId;
  final String? clientName;
  final List<String> siteIds;
  final String suggestedPassword;

  const _UidEntryDialog({
    required this.email,
    required this.name,
    required this.role,
    required this.phone,
    required this.company,
    required this.clientId,
    required this.clientName,
    required this.siteIds,
    required this.suggestedPassword,
  });

  @override
  State<_UidEntryDialog> createState() => _UidEntryDialogState();
}

class _UidEntryDialogState extends State<_UidEntryDialog> {
  final _uidController = TextEditingController();

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.vpn_key, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Create Login in Firebase'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Step 1 — Open Firebase Console → Authentication → Add user',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _copyRow('Email', widget.email),
            _copyRow('Password', widget.suggestedPassword),
            if (widget.clientName != null)
              _infoRow('Client', widget.clientName!),
            _infoRow('Role', widget.role),
            const SizedBox(height: 16),
            const Text(
              'Step 2 — Copy the new UID from Firebase and paste below:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _uidController,
              decoration: const InputDecoration(
                hintText: 'Paste UID here',
                prefixIcon: Icon(Icons.paste),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final uid = _uidController.text.trim();
            if (uid.isEmpty) return;
            Navigator.pop(context, uid);
          },
          child: const Text('Confirm & Save'),
        ),
      ],
    );
  }

  Widget _copyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}