import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/client_model.dart';
import '../../models/site_model.dart';
import '../../models/user_model.dart';
import '../../services/client_service.dart';
import '../../services/site_service.dart';
import '../../widgets/empty_state.dart';

class OperatorSitesScreen extends StatefulWidget {
  final UserModel user;

  const OperatorSitesScreen({super.key, required this.user});

  @override
  State<OperatorSitesScreen> createState() => _OperatorSitesScreenState();
}

class _OperatorSitesScreenState extends State<OperatorSitesScreen> {
  final _siteService = SiteService();
  final _clientService = ClientService();

  ClientModel? _client;
  List<SiteModel> _sites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    ClientModel? client;
    if (widget.user.clientId != null && widget.user.clientId!.isNotEmpty) {
      client = await _clientService.getClientById(widget.user.clientId!);
    }

    final sites =
    await _siteService.getSitesForUser(widget.user.siteIds);

    if (!mounted) return;
    setState(() {
      _client = client;
      _sites = sites;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Sites'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_client != null) _clientHeader(_client!),
            const SizedBox(height: 16),
            if (_sites.isEmpty)
              const EmptyState(
                icon: Icons.location_off_outlined,
                title: 'No sites assigned',
                subtitle: 'Contact admin to assign sites to you',
              )
            else ...[
              Text(
                '${_sites.length} site${_sites.length == 1 ? '' : 's'} under your care',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ..._sites.map(_siteCard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _clientHeader(ClientModel client) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You are managing:',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            client.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (client.contactEmail != null) ...[
            const SizedBox(height: 6),
            Text(
              client.contactEmail!,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _siteCard(SiteModel site) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.location_on, color: AppColors.primary),
        ),
        title: Text(
          site.name,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          site.address,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          if (site.lanes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'No parking labels configured for this site.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${site.lanes.length} parking lot${site.lanes.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: site.lanes.map(_parkingChip).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _parkingChip(Lane lane) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                lane.name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}