import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chip_row.dart';
import 'widgets/user_form_sheet.dart';
import 'widgets/user_actions_sheet.dart';

class AdminUsersScreen extends StatefulWidget {
  final UserModel user;

  const AdminUsersScreen({super.key, required this.user});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
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
    final list = await _service.getExternalUsers();
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
      final company = (u['company'] ?? '').toString().toLowerCase();
      final searchMatch = q.isEmpty ||
          name.contains(q) ||
          email.contains(q) ||
          company.contains(q);

      return roleMatch && statusMatch && searchMatch;
    }).toList();
  }

  Future<void> _showAddInfo() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Create User'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'During development, users are created manually:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text('1. Open Firebase Console'),
              Text('2. Authentication → Add user'),
              Text('3. Copy the new UID'),
              Text('4. Firestore → users → Add document'),
              Text('5. Paste UID as document ID'),
              Text('6. Add fields (email, name, role, etc.)'),
              SizedBox(height: 12),
              Text(
                'Once Cloud Functions are enabled, this button will create users directly.',
                style: TextStyle(
                    fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final activeCount = _all.where((u) => u['is_active'] == true).length;
    final inactiveCount =
        _all.where((u) => u['is_active'] == false).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddInfo,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
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
                hintText: 'Search by name, email, or company...',
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

          // ─── List ───
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? const EmptyState(
              icon: Icons.people_outline,
              title: 'No users found',
              subtitle: 'Try adjusting your filters',
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
                    _userCard(_filtered[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _userCard(Map<String, dynamic> u) {
    final isActive = u['is_active'] ?? true;
    final role = u['role'] ?? 'owner';
    final color = role == 'operator' ? AppColors.accent : AppColors.primary;

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
                // ─── Avatar ───
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
                      color: isActive
                          ? color
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // ─── Info ───
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
                                borderRadius: BorderRadius.circular(
                                  AppRadii.pill,
                                ),
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
                            role == 'owner' ? 'Site Owner' : 'Site Operator',
                            color,
                          ),
                          if ((u['company'] ?? '')
                              .toString()
                              .isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                u['company'],
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // ─── Actions ───
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