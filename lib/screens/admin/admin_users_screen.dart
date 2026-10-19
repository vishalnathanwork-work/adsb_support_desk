import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chip_row.dart';
import 'widgets/user_form_sheet.dart';
import 'widgets/user_actions_sheet.dart';
import 'widgets/approval_sheet.dart';

class AdminUsersScreen extends StatefulWidget {
  final UserModel user;

  const AdminUsersScreen({super.key, required this.user});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _service = UserService();
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String _filterRole = 'all';
  String _filterStatus = 'active';
  final _searchController = TextEditingController();
  StreamSubscription<List<Map<String, dynamic>>>? _pendingSub;

  @override
  void initState() {
    super.initState();
    _load();
    _pendingSub = _service.streamPendingUsers().listen((pendingList) {
      if (!mounted) return;
      setState(() {
        _pending = pendingList;
      });
    });
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final list = await _service.getExternalUsers();
    final pending = await _service.getPendingUsers();

    if (!mounted) return;
    setState(() {
      _all = list;
      _pending = pending;
      _isLoading = false;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();
    _filtered = _all.where((u) {
      final roleMatch = _filterRole == 'all' || u['role'] == _filterRole;

      final isActive = u['is_active'] ?? true;
      final statusMatch = _filterStatus == 'active' ? isActive : !isActive;

      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final searchMatch =
          q.isEmpty || name.contains(q) || email.contains(q);

      return roleMatch && statusMatch && searchMatch;
    }).toList();
  }

  // ─── Safe parse: handles List, String, or null ───
  List<String> _siteIdsOf(Map<String, dynamic> u) {
    return _parseSiteIds(u['site_ids']);
  }

  // ─── Edit ───
  Future<void> _openEditForm(Map<String, dynamic> userData) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserFormSheet(
        allowedRoles: const ['owner', 'operator'],
        existingUser: userData,
      ),
    );
    if (updated == true) _load();
  }

  // ─── Actions ───
  Future<void> _openActions(Map<String, dynamic> userData) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => UserActionsSheet(
        userData: userData,
        currentAdminEmail: widget.user.email,
        isInternalTeam: false,
      ),
    );
    if (changed == true) _load();
  }

  // ─── Approve pending ───
  Future<void> _openApproval(Map<String, dynamic> userData) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ApprovalSheet(
        userData: userData,
        adminEmail: widget.user.email,
      ),
    );
    if (result != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _all.where((u) => u['is_active'] == true).length;
    final inactiveCount =
        _all.where((u) => u['is_active'] == false).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // ─── Search ───
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(_applyFilters),
              decoration: const InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: Icon(Icons.search),
                filled: true,
              ),
            ),
          ),

          // ─── Role filter ───
          FilterChipRow(
            selectedValue: _filterRole,
            onSelected: (v) {
              setState(() {
                _filterRole = v;
                _applyFilters();
              });
            },
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            options: const [
              FilterOption(label: 'All Roles', value: 'all'),
              FilterOption(label: 'Site Owners', value: 'owner'),
              FilterOption(label: 'Site Operators', value: 'operator'),
            ],
          ),

          // ─── Status filter ───
          FilterChipRow(
            selectedValue: _filterStatus,
            onSelected: (v) {
              setState(() {
                _filterStatus = v;
                _applyFilters();
              });
            },
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            options: [
              FilterOption(
                label: 'Active',
                value: 'active',
                count: activeCount,
              ),
              FilterOption(
                label: 'Inactive',
                value: 'inactive',
                count: inactiveCount,
              ),
            ],
          ),

          // ─── Pending banner ───
          if (_pending.isNotEmpty)
            InkWell(
              onTap: () => _showPendingList(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 12,
                ),
                color: AppColors.warning.withOpacity(0.12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.pending_actions,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_pending.length} pending '
                                'registration${_pending.length == 1 ? "" : "s"}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Text(
                            'Tap to review and approve',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),

          // ─── List ───
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? const EmptyState(
              icon: Icons.people_outline,
              title: 'No users found',
              subtitle: 'Users appear here after self-registration + approval',            )
                : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  80,
                ),
                itemCount: _filtered.length,
                itemBuilder: (context, i) =>
                    _userCard(_filtered[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Pending list popup ───
  Future<void> _showPendingList() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PendingListSheet(pending: _pending),
    );

    if (picked != null) {
      await _openApproval(picked);
    }
  }

  Widget _userCard(Map<String, dynamic> u) {
    final isActive = u['is_active'] ?? true;
    final role = u['role'] ?? 'owner';
    final color = role == 'operator' ? AppColors.accent : AppColors.primary;
    final siteCount = _siteIdsOf(u).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openEditForm(u),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              boxShadow: AppShadows.soft,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isActive
                      ? color.withOpacity(0.15)
                      : AppColors.divider,
                  child: Text(
                    (u['name'] ?? '?')
                        .toString()
                        .substring(0, 1)
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isActive ? color : AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              u['name'] ?? '—',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (!isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.errorLight,
                                borderRadius:
                                BorderRadius.circular(AppRadii.pill),
                              ),
                              child: const Text(
                                'INACTIVE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        u['email'] ?? '—',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _badge(
                            role == 'owner'
                                ? 'Site Owner'
                                : 'Site Operator',
                            color,
                          ),
                          if (siteCount > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '· $siteCount site(s)',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => _openActions(u),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// PENDING LIST SHEET
// ═══════════════════════════════════════════════

class _PendingListSheet extends StatelessWidget {
  final List<Map<String, dynamic>> pending;

  const _PendingListSheet({required this.pending});

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
            'Pending Approvals (${pending.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap a user to review and assign client + sites',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: pending.length,
              itemBuilder: (context, i) {
                final p = pending[i];
                final role = p['role'] ?? 'owner';
                final siteCount = _parseSiteIds(p['site_ids']).length;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor:
                    AppColors.warning.withOpacity(0.15),
                    child: const Icon(
                      Icons.pending_actions,
                      color: AppColors.warning,
                    ),
                  ),
                  title: Text(
                    p['name'] ?? '—',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${p['email'] ?? ''}\n'
                        '${role == 'owner' ? 'Site Owner' : 'Site Operator'} '
                        '· $siteCount site(s)',
                    style: const TextStyle(fontSize: 11),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// SAFE HELPERS — top-level
// ═══════════════════════════════════════════════

/// Safe parse: handles List, String, or null.
List<String> _parseSiteIds(dynamic value) {
  if (value == null) return [];
  if (value is List) return value.map((e) => e.toString()).toList();
  if (value is String) return value.isEmpty ? [] : [value];
  return [];
}