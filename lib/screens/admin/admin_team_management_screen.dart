import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chip_row.dart';
import 'widgets/user_form_sheet.dart';
import 'widgets/user_actions_sheet.dart';

class AdminTeamManagementScreen extends StatefulWidget {
  final UserModel user;

  const AdminTeamManagementScreen({super.key, required this.user});

  @override
  State<AdminTeamManagementScreen> createState() =>
      _AdminTeamManagementScreenState();
}

class _AdminTeamManagementScreenState
    extends State<AdminTeamManagementScreen> {
  final _service = UserService();
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String _filterRole = 'all';
  String _filterStatus = 'active';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final list = await _service.getInternalTeam();
    if (!mounted) return;
    setState(() {
      _all = list;
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
      final searchMatch = q.isEmpty || name.contains(q) || email.contains(q);

      return roleMatch && statusMatch && searchMatch;
    }).toList();
  }

  // ─── Create ───
  Future<void> _openCreateForm() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const UserFormSheet(
        allowedRoles: ['adsb', 'technician', 'onsite', 'admin'],
      ),
    );
    if (created == true) _load();
  }

  // ─── Edit ───
  Future<void> _openEditForm(Map<String, dynamic> userData) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserFormSheet(
        allowedRoles: const ['adsb', 'technician', 'onsite', 'admin'],
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
        isInternalTeam: true,
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _all.where((u) => u['is_active'] == true).length;
    final inactiveCount =
        _all.where((u) => u['is_active'] == false).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.group_add),
        label: const Text('Add Member'),
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
                hintText: 'Search team members...',
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
              FilterOption(label: 'All', value: 'all'),
              FilterOption(label: 'ADSB Support', value: 'adsb'),
              FilterOption(label: 'Tech Advisor', value: 'technician'),
              FilterOption(label: 'On-Site', value: 'onsite'),
              FilterOption(label: 'Admin', value: 'admin'),
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

          // ─── List ───
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? const EmptyState(
              icon: Icons.groups_outlined,
              title: 'No team members',
              subtitle: 'Tap + Add Member to create one',
            )
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
                    _memberCard(_filtered[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberCard(Map<String, dynamic> m) {
    final isActive = m['is_active'] ?? true;
    final role = m['role'] ?? 'adsb';
    final color = _roleColor(role);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openEditForm(m),
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
                    (m['name'] ?? '?')
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
                              m['name'] ?? '—',
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
                        m['email'] ?? '—',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _badge(_roleLabel(role), color),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => _openActions(m),
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

  String _roleLabel(String role) {
    switch (role) {
      case 'adsb':
        return 'ADSB Support';
      case 'technician':
        return 'Technical Advisor';
      case 'onsite':
        return 'On-Site Technician';
      case 'admin':
        return 'Administrator';
      default:
        return role;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'adsb':
        return AppColors.primary;
      case 'technician':
        return const Color(0xFF5E35B1);
      case 'onsite':
        return const Color(0xFFE65100);
      case 'admin':
        return AppColors.textPrimary;
      default:
        return AppColors.textSecondary;
    }
  }
}