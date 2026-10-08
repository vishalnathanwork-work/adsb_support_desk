import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../widgets/empty_state.dart';
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
      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final searchMatch =
          q.isEmpty || name.contains(q) || email.contains(q);
      return roleMatch && searchMatch;
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
            Text('Add Team Member'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'During development, team members are created manually:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text('1. Open Firebase Console'),
              Text('2. Authentication → Add user'),
              Text('3. Copy the new UID'),
              Text('4. Firestore → users → Add document'),
              Text('5. Paste UID as document ID'),
              Text('6. Set role:'),
              Padding(
                padding: EdgeInsets.only(left: 16, top: 4),
                child: Text('• adsb — ADSB Support'),
              ),
              Padding(
                padding: EdgeInsets.only(left: 16),
                child: Text('• technician — Technical Advisor'),
              ),
              Padding(
                padding: EdgeInsets.only(left: 16),
                child: Text('• onsite — On-Site Technician'),
              ),
              Padding(
                padding: EdgeInsets.only(left: 16),
                child: Text('• admin — Administrator'),
              ),
              SizedBox(height: 12),
              Text(
                'Once Cloud Functions are enabled, this button will create members directly.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
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
        allowedRoles: const ['adsb', 'technician', 'onsite', 'admin'],
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
        isInternalTeam: true,
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddInfo,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.group_add),
        label: const Text('Add Member'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: AppColors.primary.withOpacity(0.06),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Internal teams: ADSB Support, TT (Technical Advisor), On-Site Technicians, and Admins.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? const EmptyState(
              icon: Icons.groups_outlined,
              title: 'No team members',
              subtitle: 'Add your first team member',
            )
                : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding:
                const EdgeInsets.fromLTRB(16, 8, 16, 80),
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

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(_applyFilters),
            decoration: const InputDecoration(
              hintText: 'Search team members...',
              prefixIcon: Icon(Icons.search),
              filled: true,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('All', 'all'),
                _chip('ADSB Support', 'adsb'),
                _chip('Tech Advisor', 'technician'),
                _chip('On-Site', 'onsite'),
                _chip('Admin', 'admin'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = _filterRole == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _filterRole = value;
            _applyFilters();
          });
        },
        selectedColor: AppColors.primary.withOpacity(0.15),
      ),
    );
  }

  Widget _memberCard(Map<String, dynamic> m) {
    final isActive = m['is_active'] ?? true;
    final role = m['role'] ?? 'adsb';
    final color = _roleColor(role);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor:
          isActive ? color.withOpacity(0.15) : AppColors.divider,
          child: Text(
            (m['name'] ?? '?').toString().substring(0, 1).toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isActive ? color : AppColors.textSecondary,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                m['name'] ?? '—',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (!isActive)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'INACTIVE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text(m['email'] ?? '—',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            _badge(_roleLabel(role), color),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
          onPressed: () => _openActions(m),
        ),
        onTap: () => _openEditForm(m),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w600),
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