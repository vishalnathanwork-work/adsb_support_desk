import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/client_model.dart';
import '../../models/site_model.dart';
import '../../services/owner_service.dart';
import '../../services/site_service.dart';
import '../../widgets/empty_state.dart';
import 'widgets/site_form_sheet.dart';

class AdminSitesScreen extends StatefulWidget {
  const AdminSitesScreen({super.key});

  @override
  State<AdminSitesScreen> createState() => _AdminSitesScreenState();
}

class _AdminSitesScreenState extends State<AdminSitesScreen> {
  final _siteService = SiteService();
  final _clientService = ClientService();

  List<SiteModel> _allSites = [];
  List<ClientModel> _allClients = [];
  List<SiteModel> _filtered = [];

  ClientModel? _filterClient;
  String _filterStatus = 'active';
  final _searchController = TextEditingController();

  bool _isLoading = true;

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

    final sites = await _siteService.getAllSites();
    final clients = await _clientService.getAllClients();

    if (!mounted) return;
    setState(() {
      _allSites = sites;
      _allClients = clients;
      _isLoading = false;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();

    _filtered = _allSites.where((s) {
      if (_filterClient != null && s.clientId != _filterClient!.id) {
        return false;
      }
      if (_filterStatus == 'active' && !s.isActive) return false;
      if (_filterStatus == 'inactive' && s.isActive) return false;
      if (q.isEmpty) return true;
      return s.name.toLowerCase().contains(q) ||
          s.address.toLowerCase().contains(q);
    }).toList();

    _filtered.sort((a, b) {
      final clientCompare = a.clientId.compareTo(b.clientId);
      if (clientCompare != 0) return clientCompare;
      return a.name.compareTo(b.name);
    });
  }

  String _clientNameFor(String clientId) {
    try {
      return _allClients.firstWhere((c) => c.id == clientId).name;
    } catch (_) {
      return 'Unknown client';
    }
  }

  Future<void> _openCreate() async {
    if (_allClients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a client first before creating sites'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SiteFormSheet(
        clients: _allClients,
        initialClientId: _filterClient?.id,
      ),
    );
    if (created == true) _load();
  }

  Future<void> _openEdit(SiteModel site) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SiteFormSheet(
        clients: _allClients,
        existingSite: site,
      ),
    );
    if (updated == true) _load();
  }

  Future<void> _delete(SiteModel site) async {
    final ticketCount = await _siteService.countTicketsForSite(site.id);
    final userCount = await _siteService.countUsersForSite(site.id);

    if (!mounted) return;

    if (ticketCount > 0 || userCount > 0) {
      final blockers = <String>[];
      if (ticketCount > 0) blockers.add('$ticketCount ticket(s)');
      if (userCount > 0) blockers.add('$userCount user(s)');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot delete: this site has ${blockers.join(" and ")} '
                'linked to it.',
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete site?'),
        content: Text(
          'Delete "${site.name}" permanently?\n\n'
              'This site has no tickets or users, so it is safe to delete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await _siteService.deleteSite(site.id);

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Site deleted'),
          backgroundColor: AppColors.success,
        ),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delete failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _allSites.where((s) => s.isActive).length;
    final inactiveCount = _allSites.where((s) => !s.isActive).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sites'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add Site'),
      ),
      body: Column(
        children: [
          // Search
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(_applyFilters),
              decoration: const InputDecoration(
                hintText: 'Search sites by name or address...',
                prefixIcon: Icon(Icons.search),
                filled: true,
              ),
            ),
          ),

          // Client filter chips
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.only(bottom: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _clientChip(null, 'All Clients'),
                  const SizedBox(width: 8),
                  ..._allClients.map((c) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _clientChip(c, c.name),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Status filter
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _statusChip('Active', 'active', activeCount),
                const SizedBox(width: 8),
                _statusChip('Inactive', 'inactive', inactiveCount),
              ],
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? const EmptyState(
              icon: Icons.location_off_outlined,
              title: 'No sites found',
              subtitle: 'Try changing your filters',
            )
                : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: _filtered.length,
                itemBuilder: (context, i) =>
                    _siteCard(_filtered[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientChip(ClientModel? client, String label) {
    final selected = _filterClient?.id == client?.id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterClient = client;
          _applyFilters();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String label, String value, int count) {
    final selected = _filterStatus == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterStatus = value;
          _applyFilters();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _siteCard(SiteModel s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openEdit(s),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              boxShadow: AppShadows.soft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + status + delete
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: s.isActive
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (!s.isActive)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
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
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.error,
                      ),
                      onPressed: () => _delete(s),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Client badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _clientNameFor(s.clientId),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        s.address,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Zones summary
                if (s.zones.isNotEmpty)
                  _zonesRow(s)
                else
                  const Text(
                    'No zones configured',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _zonesRow(SiteModel s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.local_parking_outlined,
              size: 13,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 5),
            Text(
              '${s.zoneCount} zone${s.zoneCount == 1 ? "" : "s"} · '
                  '${s.totalEntries} Entr${s.totalEntries == 1 ? "y" : "ies"} · '
                  '${s.totalExits} Exit${s.totalExits == 1 ? "" : "s"}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: s.zones.map((z) {
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '📍',
                    style: TextStyle(fontSize: 10),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    z.name,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (z.entryCount > 0) ...[
                    const Icon(
                      Icons.login,
                      size: 10,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${z.entryCount}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                  if (z.entryCount > 0 && z.exitCount > 0)
                    const SizedBox(width: 6),
                  if (z.exitCount > 0) ...[
                    const Icon(
                      Icons.logout,
                      size: 10,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${z.exitCount}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}