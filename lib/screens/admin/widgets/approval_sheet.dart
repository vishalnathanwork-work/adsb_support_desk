import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/client_model.dart';
import '../../../models/site_model.dart';
import '../../../services/owner_service.dart';
import '../../../services/site_service.dart';
import '../../../services/user_service.dart';

class ApprovalSheet extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String adminEmail;

  const ApprovalSheet({
    super.key,
    required this.userData,
    required this.adminEmail,
  });

  @override
  State<ApprovalSheet> createState() => _ApprovalSheetState();
}

class _ApprovalSheetState extends State<ApprovalSheet> {
  final _userService = UserService();
  final _siteService = SiteService();
  final _clientService = ClientService();

  List<ClientModel> _allClients = [];
  List<SiteModel> _clientSites = [];
  ClientModel? _selectedClient;
  Set<String> _selectedSiteIds = {};

  // ─── Role selection ───
  String _selectedRole = 'owner';

  bool _loading = true;
  bool _loadingSites = false;
  bool _saving = false;
  bool _rejecting = false;

  String get _uid => widget.userData['uid'] as String;
  String get _name => widget.userData['name'] ?? '—';
  String get _email => widget.userData['email'] ?? '—';
  String get _username => (widget.userData['username'] ?? '').toString();
  String get _phone => widget.userData['phone'] ?? '—';
  String get _remark =>
      widget.userData['remark'] ?? widget.userData['company'] ?? '—';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    final clients = await _clientService.getAllClients();
    if (!mounted) return;
    setState(() {
      _allClients = clients;
      _loading = false;
    });
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

  // ─── When role changes, adjust site selection ───
  void _setRole(String role) {
    setState(() {
      _selectedRole = role;
      // Operator can only have 1 site — trim if switching from owner
      if (role == 'operator' && _selectedSiteIds.length > 1) {
        _selectedSiteIds = {_selectedSiteIds.first};
      }
    });
  }

  Future<void> _approve() async {
    if (_selectedClient == null) {
      _snack('Please select a client', AppColors.error);
      return;
    }
    if (_selectedSiteIds.isEmpty) {
      _snack('Please assign at least one site', AppColors.error);
      return;
    }
    if (_selectedRole == 'operator' && _selectedSiteIds.length != 1) {
      _snack('Operator can only have one site', AppColors.error);
      return;
    }

    setState(() => _saving = true);

    final ok = await _userService.approveUser(
      uid: _uid,
      clientId: _selectedClient!.id,
      clientName: _selectedClient!.name,
      siteIds: _selectedSiteIds.toList(),
      adminEmail: widget.adminEmail,
      role: _selectedRole,   // ← pass selected role
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      _snack(
        'User approved as '
            '${_selectedRole == 'owner' ? 'Site Owner' : 'Site Operator'}',
        AppColors.success,
      );
      Navigator.pop(context, 'approved');
    } else {
      _snack('Approval failed', AppColors.error);
    }
  }

  Future<void> _reject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject and delete?'),
        content: Text(
          '$_name will be permanently deleted. '
              'Their login account will also be removed.\n\n'
              'If they were registered by mistake, they can sign up again '
              'with the same username.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Reject & Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _rejecting = true);
    final ok = await _userService.rejectUser(_uid);
    if (!mounted) return;
    setState(() => _rejecting = false);

    if (ok) {
      _snack(
        'User rejected and deleted. They can register again.',
        AppColors.warning,
      );
      Navigator.pop(context, 'rejected');
    } else {
      _snack('Reject failed', AppColors.error);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

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
      child: _loading
          ? const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      )
          : SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handle(),
            const SizedBox(height: 20),
            const Text(
              'Review Registration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // ─── User info card ───
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  _infoRow('Name', _name),
                  _infoRow('Username', _username.isEmpty ? '—' : _username),
                  _infoRow('Phone', _phone),
                  _infoRow('Company (remark)', _remark),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ═══ ROLE SELECTION ═══
            _label('Assign Role'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _roleCard(
                    role: 'owner',
                    title: 'Site Owner',
                    subtitle: 'Multi-site access',
                    icon: Icons.business_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _roleCard(
                    role: 'operator',
                    title: 'Site Operator',
                    subtitle: 'One site only',
                    icon: Icons.badge_outlined,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ─── Client picker ───
            _label('Assign to Client (Company)'),
            DropdownButtonFormField<String>(
              initialValue: _selectedClient?.id,
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
            ),
            const SizedBox(height: 16),

            // ─── Site picker ───
            if (_selectedClient != null) ...[
              _label(
                _selectedRole == 'owner'
                    ? 'Assign Sites (multi)'
                    : 'Assign Site (exactly 1)',
              ),
              _buildSiteSelector(),
            ],

            const SizedBox(height: 24),

            // ─── Actions ───
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _rejecting ? null : _reject,
                    icon: _rejecting
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.error,
                      ),
                    )
                        : const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.error,
                    ),
                    label: const Text(
                      'Reject',
                      style: TextStyle(color: AppColors.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      side:
                      const BorderSide(color: AppColors.error),
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _approve,
                    icon: _saving
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.check, size: 18),
                    label: Text(
                      'Approve as ${_selectedRole == 'owner' ? 'Owner' : 'Operator'}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // ROLE CARD
  // ═══════════════════════════════════════════════

  Widget _roleCard({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _selectedRole == role;

    return InkWell(
      onTap: () => _setRole(role),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const Spacer(),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.primary,
                    size: 18,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.primary
                    : AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
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
                'This client has no sites yet. Add sites in Firestore first.',
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

          if (_selectedRole == 'operator') {
            return RadioListTile<String>(
              value: site.id,
              groupValue: _selectedSiteIds.isEmpty
                  ? null
                  : _selectedSiteIds.first,
              onChanged: (v) {
                setState(() {
                  _selectedSiteIds = {v!};
                });
              },
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
              title: Text(
                site.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                site.address,
                style: const TextStyle(fontSize: 11),
              ),
            );
          }

          return CheckboxListTile(
            value: selected,
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _selectedSiteIds.add(site.id);
                } else {
                  _selectedSiteIds.remove(site.id);
                }
              });
            },
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            title: Text(
              site.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              site.address,
              style: const TextStyle(fontSize: 11),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
}