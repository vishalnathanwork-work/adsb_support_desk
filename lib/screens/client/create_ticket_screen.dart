import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site_model.dart';
import '../../models/user_model.dart';
import '../../services/preset_service.dart';
import '../../services/site_service.dart';
import '../../services/ticket_service.dart';
import '../../widgets/primary_button.dart';

class CreateTicketScreen extends StatefulWidget {
  final UserModel user;

  const CreateTicketScreen({super.key, required this.user});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ticketService = TicketService();
  final _presetService = PresetService();
  final _siteService = SiteService();

  SiteModel? _selectedSite;
  Lane? _selectedLane;
  String? _selectedDirection;
  String? _selectedProductType;
  String? _selectedProductIssue;

  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<SiteModel> _sites = [];
  List<String> _productTypes = [];
  List<String> _productIssues = [];

  bool _loading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _contactNameController.text = widget.user.name;
    _contactPhoneController.text = widget.user.phone ?? '';
    _load();
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final sites = await _siteService.getSitesForUser(widget.user.siteIds);
    final types = await _presetService.getProductTypes();
    final issues = await _presetService.getProductIssues();

    if (!mounted) return;
    setState(() {
      _sites = sites;
      _productTypes = types;
      _productIssues = issues;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSite == null) {
      _showError('Please select a site location');
      return;
    }
    if (_selectedLane == null) {
      _showError('Please select a parking label');
      return;
    }
    if (_selectedDirection == null) {
      _showError('Please choose what is affected');
      return;
    }

    setState(() => _isSubmitting = true);

    final ticket = await _ticketService.createTicket(
      createdBy: widget.user.email,
      createdByName: widget.user.name,
      createdByRole: widget.user.role,
      siteId: _selectedSite!.id,
      siteName: _selectedSite!.name,
      siteLocation: _selectedSite!.address,
      laneId: _selectedLane!.id,
      laneName: _selectedLane!.name,
      laneDirection: _selectedDirection!,
      productType: _selectedProductType!,
      productIssue: _selectedProductIssue!,
      contactName: _contactNameController.text.trim(),
      contactPhone: _contactPhoneController.text.trim(),
      description: _descriptionController.text.trim(),
      imageUrls: const [],
    );

    if (ticket == null) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError('Failed to create ticket. Check your connection.');
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 10),
            Text('Ticket Submitted'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your ticket ID is:',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text(ticket.id,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryRow('Site', ticket.siteName),
                  const SizedBox(height: 6),
                  _summaryRow('Parking', ticket.laneName),
                  const SizedBox(height: 6),
                  _summaryRow('Affected', ticket.laneDirectionDisplay),
                  const SizedBox(height: 6),
                  _summaryRow('Product', ticket.productType),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Our team will verify your issue and get back to you shortly.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Ticket')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionTitle('Location'),
              _buildSiteDropdown(),
              const SizedBox(height: 12),
              _buildLaneDropdown(),
              const SizedBox(height: 12),
              _buildDirectionSelector(),
              const SizedBox(height: 20),

              _sectionTitle('Product Details'),
              _buildProductTypeDropdown(),
              const SizedBox(height: 12),
              _buildProductIssueDropdown(),
              const SizedBox(height: 20),

              _sectionTitle('Contact Person'),
              _buildTextInput(
                controller: _contactNameController,
                label: 'Name',
                icon: Icons.person_outline,
                validator: (v) =>
                v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _buildTextInput(
                controller: _contactPhoneController,
                label: 'Phone',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              _sectionTitle('Issue Description (Optional)'),
              _buildTextArea(),
              const SizedBox(height: 32),

              PrimaryButton(
                label: 'Submit Ticket',
                onPressed: _submit,
                isLoading: _isSubmitting,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
    );
  }

  Widget _buildSiteDropdown() {
    if (_sites.isEmpty) {
      return _emptyMessage('No sites assigned to your account. Contact admin.');
    }

    return DropdownButtonFormField<String>(
      value: _selectedSite?.id,
      isExpanded: true,
      decoration: const InputDecoration(
        hintText: 'Select site',
        prefixIcon:
        Icon(Icons.location_on_outlined, color: AppColors.textSecondary),
      ),
      items: _sites.map((s) {
        return DropdownMenuItem(
          value: s.id,
          child: Text(s.displayName, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (id) {
        if (id == null) return;
        setState(() {
          _selectedSite = _sites.firstWhere((s) => s.id == id);
          _selectedLane = null;
          _selectedDirection = null;
        });
      },
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  Widget _buildLaneDropdown() {
    if (_selectedSite == null) {
      return _disabledHint('Select a site first');
    }

    final lanes = _selectedSite!.lanes;
    if (lanes.isEmpty) {
      return _emptyMessage('This site has no parking labels configured.');
    }

    return DropdownButtonFormField<String>(
      value: _selectedLane?.id,
      isExpanded: true,
      decoration: const InputDecoration(
        hintText: 'Select parking label',
        prefixIcon:
        Icon(Icons.local_parking_outlined, color: AppColors.textSecondary),
      ),
      items: lanes.map((lane) {
        return DropdownMenuItem(
          value: lane.id,
          child: Text(lane.name),
        );
      }).toList(),
      onChanged: (id) {
        if (id == null) return;
        setState(() {
          _selectedLane = lanes.firstWhere((l) => l.id == id);
          _selectedDirection = null;
        });
      },
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  Widget _buildDirectionSelector() {
    if (_selectedLane == null) {
      return _disabledHint('Select a parking label first');
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedDirection == null
              ? AppColors.divider
              : AppColors.primary.withOpacity(0.4),
          width: _selectedDirection == null ? 1 : 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'What is affected at ${_selectedLane!.name}?',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _directionOption(
                  label: 'Entry',
                  value: 'entry',
                  icon: Icons.login,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _directionOption(
                  label: 'Exit',
                  value: 'exit',
                  icon: Icons.logout,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _directionOption(
                  label: 'Both',
                  value: 'both',
                  icon: Icons.swap_horiz,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _directionOption({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final selected = _selectedDirection == value;

    return InkWell(
      onTap: () => setState(() => _selectedDirection = value),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 20,
                color: selected ? color : AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? color : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductTypeDropdown() {
    if (_productTypes.isEmpty) {
      return _emptyMessage('No product types loaded. Contact admin.');
    }
    return DropdownButtonFormField<String>(
      value: _selectedProductType,
      isExpanded: true,
      decoration: const InputDecoration(
        hintText: 'Select product type',
        prefixIcon: Icon(Icons.build_outlined, color: AppColors.textSecondary),
      ),
      items: _productTypes
          .map((p) => DropdownMenuItem(
          value: p, child: Text(p, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (v) => setState(() => _selectedProductType = v),
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  Widget _buildProductIssueDropdown() {
    if (_productIssues.isEmpty) {
      return _emptyMessage('No product issues loaded. Contact admin.');
    }
    return DropdownButtonFormField<String>(
      value: _selectedProductIssue,
      isExpanded: true,
      decoration: const InputDecoration(
        hintText: 'Select issue',
        prefixIcon: Icon(Icons.report_problem_outlined,
            color: AppColors.textSecondary),
      ),
      items: _productIssues
          .map((p) => DropdownMenuItem(
          value: p, child: Text(p, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (v) => setState(() => _selectedProductIssue = v),
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  Widget _emptyMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _disabledHint(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.divider.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(message,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildTextArea() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 4,
      decoration: const InputDecoration(
        hintText: 'Describe the issue in detail (optional)',
      ),
    );
  }
}