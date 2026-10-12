import 'dart:io';
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../models/site_model.dart';
import '../../models/user_model.dart';
import '../../services/image_service.dart';
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
  final _imageService = ImageService();

  SiteModel? _selectedSite;
  Lane? _selectedLane;
  String? _selectedDirection;
  String? _selectedProductType;
  String? _selectedProductIssue;

  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customIssueController = TextEditingController();

  List<SiteModel> _sites = [];
  List<String> _productTypes = [];
  Map<String, List<String>> _productIssuesMap = {};

  final List<File> _selectedImages = [];

  bool _loading = true;
  bool _isSubmitting = false;

  static const String _otherValue = 'Other (please describe)';

  bool get _showCustomIssueField => _selectedProductIssue == _otherValue;

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
    _customIssueController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final sites = await _siteService.getSitesForUser(widget.user.siteIds);
    final types = await _presetService.getProductTypes();
    final issuesMap = await _presetService.getProductIssues();

    if (!mounted) return;
    setState(() {
      _sites = sites;
      _productTypes = types;
      _productIssuesMap = issuesMap;
      _loading = false;
    });
  }

  // ─────────────────────────────────────────
  // IMAGES
  // ─────────────────────────────────────────

  Future<void> _pickFromCamera() async {
    if (_selectedImages.length >= AppConfig.maxTicketImages) {
      _showError('Maximum ${AppConfig.maxTicketImages} photos');
      return;
    }
    final file = await _imageService.pickFromCamera();
    if (file != null && mounted) {
      setState(() => _selectedImages.add(file));
    }
  }

  Future<void> _pickFromGallery() async {
    final remaining =
        AppConfig.maxTicketImages - _selectedImages.length;
    if (remaining <= 0) {
      _showError('Maximum ${AppConfig.maxTicketImages} photos');
      return;
    }
    final files = await _imageService.pickFromGallery(limit: remaining);
    if (files.isNotEmpty && mounted) {
      setState(() => _selectedImages.addAll(files));
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // SUBMIT
  // ─────────────────────────────────────────

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
    if (_selectedProductType == null) {
      _showError('Please select a product type');
      return;
    }
    if (_selectedProductIssue == null) {
      _showError('Please select an issue');
      return;
    }
    if (_showCustomIssueField &&
        _customIssueController.text.trim().isEmpty) {
      _showError('Please describe the issue');
      return;
    }

    setState(() => _isSubmitting = true);

    final finalIssue = _showCustomIssueField
        ? _customIssueController.text.trim()
        : _selectedProductIssue!;

    // 1. Create the ticket
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
      productIssue: finalIssue,
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

    // 2. Process images (uploads to Firebase Storage only when enabled)
    if (_selectedImages.isNotEmpty) {
      final urls = await _imageService.uploadImages(
        files: _selectedImages,
        folder: 'ticket_images',
        ticketId: ticket.id,
      );

      if (urls.isNotEmpty) {
        await _ticketService.updateTicketFields(
          ticket.id,
          {'image_urls': urls},
        );
      }
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    _showSuccessDialog(ticket.id);
  }

  void _showSuccessDialog(String ticketId) {
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
            const Text(
              'Your ticket ID is:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ticketId,
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
              Navigator.pop(context);
              Navigator.pop(context, true);
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

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────

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
              if (_showCustomIssueField) ...[
                const SizedBox(height: 12),
                _buildCustomIssueField(),
              ],
              const SizedBox(height: 20),

              _sectionTitle('Photos (Optional)'),
              _buildImageSection(),
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
                onPressed: _isSubmitting ? null : _submit,
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

  // ═══════════════════════════════════════════════
  // IMAGE SECTION
  // ═══════════════════════════════════════════════

  Widget _buildImageSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedImages.length} / ${AppConfig.maxTicketImages} photos',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (_selectedImages.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedImages
                  .asMap()
                  .entries
                  .map((entry) => _imageThumbnail(
                file: entry.value,
                onRemove: () => _removeImage(entry.key),
              ))
                  .toList(),
            ),
          if (_selectedImages.length < AppConfig.maxTicketImages) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: _showImageSourceSheet,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined,
                        color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Add Photo',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _imageThumbnail({
    required File file,
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // SITE / LANE / DIRECTION — same as before
  // ═══════════════════════════════════════════════

  Widget _buildSiteDropdown() {
    if (_sites.isEmpty) {
      return _emptyMessage(
        'No sites assigned to your account. Contact admin.',
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedSite?.id,
      isExpanded: true,
      decoration: const InputDecoration(
        hintText: 'Select site',
        prefixIcon: Icon(
          Icons.location_on_outlined,
          color: AppColors.textSecondary,
        ),
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
        prefixIcon: Icon(
          Icons.local_parking_outlined,
          color: AppColors.textSecondary,
        ),
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
              const Icon(
                Icons.compare_arrows,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'What is affected at ${_selectedLane!.name}?',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
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
            Icon(
              icon,
              size: 20,
              color: selected ? color : AppColors.textSecondary,
            ),
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
        prefixIcon: Icon(
          Icons.build_outlined,
          color: AppColors.textSecondary,
        ),
      ),
      items: _productTypes
          .map((p) => DropdownMenuItem(
        value: p,
        child: Text(p, overflow: TextOverflow.ellipsis),
      ))
          .toList(),
      onChanged: (v) {
        setState(() {
          _selectedProductType = v;
          _selectedProductIssue = null;
          _customIssueController.clear();
        });
      },
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  Widget _buildProductIssueDropdown() {
    if (_selectedProductType == null) {
      return _disabledHint('Select a product type first');
    }

    final issues = _productIssuesMap[_selectedProductType] ?? [];
    if (issues.isEmpty) {
      return _emptyMessage(
        'No issues configured for "$_selectedProductType". Contact admin.',
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedProductIssue,
      isExpanded: true,
      decoration: const InputDecoration(
        hintText: 'Select issue',
        prefixIcon: Icon(
          Icons.report_problem_outlined,
          color: AppColors.textSecondary,
        ),
      ),
      items: issues
          .map((p) => DropdownMenuItem(
        value: p,
        child: Text(p, overflow: TextOverflow.ellipsis),
      ))
          .toList(),
      onChanged: (v) {
        setState(() {
          _selectedProductIssue = v;
          if (v != _otherValue) {
            _customIssueController.clear();
          }
        });
      },
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  Widget _buildCustomIssueField() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.edit_note,
                size: 16,
                color: AppColors.warning,
              ),
              SizedBox(width: 6),
              Text(
                'Describe the issue',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _customIssueController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Type the specific issue you are experiencing...',
              fillColor: Colors.white,
            ),
            validator: (v) {
              if (_showCustomIssueField &&
                  (v == null || v.trim().isEmpty)) {
                return 'Please describe the issue';
              }
              return null;
            },
          ),
        ],
      ),
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
          const Icon(
            Icons.warning_amber_outlined,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 13)),
          ),
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
          const Icon(
            Icons.info_outline,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
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