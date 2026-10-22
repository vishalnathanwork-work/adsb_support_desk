import 'dart:io';
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../models/site_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
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
  final _chatService = ChatService();

  SiteModel? _selectedSite;
  String? _selectedProductType;
  String? _selectedProductIssue;

  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<SiteModel> _sites = [];
  List<String> _productTypes = [];
  Map<String, List<String>> _productIssuesMap = {};

  final List<File> _selectedImages = [];

  bool _loading = true;
  bool _isSubmitting = false;

  /// True when product type = "Others"
  bool get _isOtherProductType {
    final t = _selectedProductType;
    if (t == null || t.isEmpty) return false;
    final lower = t.toLowerCase();
    return lower == 'other' ||
        lower == 'others' ||
        lower.startsWith('other ') ||
        lower.startsWith('others ');
  }

  /// True when the selected issue is "Other" style
  bool get _isOtherIssue {
    final issue = _selectedProductIssue;
    if (issue == null || issue.isEmpty) return false;
    final lower = issue.toLowerCase();
    return lower == 'other' ||
        lower == 'others' ||
        lower.startsWith('other ') ||
        lower.startsWith('others ') ||
        lower.startsWith('other(') ||
        lower.startsWith('others(');
  }

  /// Description is required when product type OR issue is "Other"
  bool get _requiresDescription => _isOtherProductType || _isOtherIssue;

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
    // Manual validations first (snackbar errors)
    if (_selectedSite == null) {
      _showError('Please select a site location');
      return;
    }
    if (_selectedProductType == null) {
      _showError('Please select a product type');
      return;
    }

    // Issue dropdown validation (hidden when product type = "Others")
    if (!_isOtherProductType) {
      if (_selectedProductIssue == null) {
        _showError('Please select an issue');
        return;
      }
    }

    // Description required when "Other" in either product type or issue
    if (_requiresDescription &&
        _descriptionController.text.trim().isEmpty) {
      _showError(
        'Please describe the issue in the description field '
            '(required when "Other" is selected)',
      );
      return;
    }

    // Form-level validate (phone, name, etc.)
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Build the final issue text
    final String finalIssue;
    if (_isOtherProductType) {
      // Product type = Others → description becomes the issue
      finalIssue = _descriptionController.text.trim();
    } else if (_isOtherIssue) {
      // Issue = Other → description becomes the issue
      finalIssue = _descriptionController.text.trim();
    } else {
      // Normal issue
      finalIssue = _selectedProductIssue!;
    }

    // Description — only save when NOT used as the issue text
    final String finalDescription;
    if (_isOtherProductType || _isOtherIssue) {
      finalDescription = '';
    } else {
      finalDescription = _descriptionController.text.trim();
    }

    final ticket = await _ticketService.createTicket(
      createdBy: widget.user.email,
      createdByName: widget.user.name,
      createdByRole: widget.user.role,
      siteId: _selectedSite!.id,
      siteName: _selectedSite!.name,
      siteLocation: _selectedSite!.address,
      lanes: const [],
      productType: _selectedProductType!,
      productIssue: finalIssue,
      contactName: _contactNameController.text.trim(),
      contactPhone: _contactPhoneController.text.trim(),
      description: finalDescription,
      imageUrls: const [],
    );

    if (ticket == null) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError('Failed to create ticket. Check your connection.');
      return;
    }

    // Upload images
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

        final updated =
        await _ticketService.getTicketById(ticket.id);
        if (updated != null) {
          await _chatService.refreshSummaryImages(
            updated.copyWith(imageUrls: urls),
          );
        }
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
              const SizedBox(height: 20),

              _sectionTitle('Product Details'),
              _buildProductTypeDropdown(),
              // Hide issue dropdown when product type = "Others"
              if (!_isOtherProductType) ...[
                const SizedBox(height: 12),
                _buildProductIssueDropdown(),
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

              _sectionTitle(
                _requiresDescription
                    ? 'Issue Description (Required)'
                    : 'Issue Description (Optional)',
              ),
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
  // SITE DROPDOWN
  // ═══════════════════════════════════════════════

  Widget _buildSiteDropdown() {
    if (_sites.isEmpty) {
      return _emptyMessage(
        'No sites assigned to your account. Contact admin.',
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedSite?.id,
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
        });
      },
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  // ═══════════════════════════════════════════════
  // PRODUCT TYPE DROPDOWN
  // ═══════════════════════════════════════════════

  Widget _buildProductTypeDropdown() {
    if (_productTypes.isEmpty) {
      return _emptyMessage('No product types loaded. Contact admin.');
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedProductType,
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
      initialValue: _selectedProductIssue,
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
        });
      },
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  // ═══════════════════════════════════════════════
  // IMAGES
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
  // HELPERS
  // ═══════════════════════════════════════════════

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
      decoration: InputDecoration(
        hintText: _requiresDescription
            ? 'Describe the issue in detail — required'
            : 'Describe the issue in detail (optional)',
      ),
      validator: (v) {
        if (_requiresDescription &&
            (v == null || v.trim().isEmpty)) {
          return 'Please describe the issue';
        }
        return null;
      },
    );
  }
}