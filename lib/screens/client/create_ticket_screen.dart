import 'package:flutter/material.dart';
import '../../config/presets.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/notification_service.dart';
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
  final _notificationService = NotificationService();

  // Form fields
  String? _selectedSiteId;
  String? _selectedProductType;
  String? _selectedProductIssue;
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<String> _imagePaths = []; // will be populated in a later sprint
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Auto-fill contact from user
    _contactNameController.text = widget.user.name;
    _contactPhoneController.text = widget.user.phone ?? '';
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSiteId == null) {
      _showError('Please select a site location');
      return;
    }

    setState(() => _isSubmitting = true);

    final site = Presets.sites.firstWhere((s) => s['id'] == _selectedSiteId);

    final ticket = await _ticketService.createTicket(...);

    if (ticket == null) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create ticket. Please check your connection.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Notify the creator
    await _notificationService.addNotification(
      userId: widget.user.email,
      ticketId: ticket.id,      // ✅ safe now
      title: 'Ticket Submitted',
      body: 'Your ticket ${ticket.id} has been received.',
      type: 'status_update',
    );

    // Notify ADSB team (mock — in real app, this would go to the team)
    await _notificationService.addNotification(
      userId: 'adsb@adsb.com',
      ticketId: ticket.id,
      title: 'New Ticket',
      body: '${widget.user.name} created ticket ${ticket.id}.',
      type: 'status_update',
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    // Show success and pop
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
            Text('Your ticket ID is:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              ticket.id,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
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
              Navigator.pop(context); // close dialog
              Navigator.pop(context, true); // return to list with refresh flag
            },
            child: const Text('OK'),
          ),
        ],
      ),
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
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionTitle('Site Location'),
              _buildSiteDropdown(),
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
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _buildTextInput(
                controller: _contactPhoneController,
                label: 'Phone',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              _sectionTitle('Issue Description (Optional)'),
              _buildTextArea(),
              const SizedBox(height: 20),

              _sectionTitle('Image Upload (Coming Soon)'),
              _buildImagePlaceholder(),
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
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSiteDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSiteId,
      decoration: const InputDecoration(
        hintText: 'Select site',
        prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.textSecondary),
      ),
      items: Presets.sites
          .map(
            (s) => DropdownMenuItem(
          value: s['id'],
          child: Text('${s['name']} — ${s['address']}'),
        ),
      )
          .toList(),
      onChanged: (v) => setState(() => _selectedSiteId = v),
    );
  }

  Widget _buildProductTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedProductType,
      decoration: const InputDecoration(
        hintText: 'Select product type',
        prefixIcon: Icon(Icons.build_outlined, color: AppColors.textSecondary),
      ),
      items: Presets.productTypes
          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
          .toList(),
      onChanged: (v) => setState(() => _selectedProductType = v),
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  Widget _buildProductIssueDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedProductIssue,
      decoration: const InputDecoration(
        hintText: 'Select issue',
        prefixIcon: Icon(Icons.report_problem_outlined, color: AppColors.textSecondary),
      ),
      items: Presets.productIssues
          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
          .toList(),
      onChanged: (v) => setState(() => _selectedProductIssue = v),
      validator: (v) => v == null ? 'Required' : null,
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

  Widget _buildImagePlaceholder() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Column(
        children: [
          Icon(Icons.image_outlined, size: 40, color: AppColors.textSecondary),
          SizedBox(height: 8),
          Text(
            'Image upload will be added in a future sprint',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}