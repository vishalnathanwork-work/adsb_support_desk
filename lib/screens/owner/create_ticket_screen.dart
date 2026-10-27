import 'dart:io';
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/localized_preset.dart';
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
  LocalizedPreset? _selectedProductType;
  LocalizedPreset? _selectedProductIssue;

  /// Selected lanes — stored as maps for Firestore:
  /// { id, name, type, zone_id, zone_name }
  final List<Map<String, String>> _selectedLanes = [];

  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<SiteModel> _sites = [];
  List<LocalizedPreset> _productTypes = [];
  Map<String, List<LocalizedPreset>> _productIssuesMap = {};

  final List<File> _selectedImages = [];

  bool _loading = true;
  bool _isSubmitting = false;

  // ═══════════════════════════════════════════════
  // "OTHER" DETECTION
  // ═══════════════════════════════════════════════

  bool get _isOtherProductType {
    final p = _selectedProductType;
    if (p == null) return false;
    final lower = p.en.toLowerCase();
    return lower == 'other' ||
        lower == 'others' ||
        lower.startsWith('other ') ||
        lower.startsWith('others ');
  }

  bool get _isOtherIssue {
    final issue = _selectedProductIssue;
    if (issue == null) return false;
    final lower = issue.en.toLowerCase();
    return lower == 'other' ||
        lower == 'others' ||
        lower.startsWith('other ') ||
        lower.startsWith('others ') ||
        lower.startsWith('other(') ||
        lower.startsWith('others(');
  }

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

  // ═══════════════════════════════════════════════
  // LANE SELECTION
  // ═══════════════════════════════════════════════

  bool _isLaneSelected(String laneId) {
    return _selectedLanes.any((l) => l['id'] == laneId);
  }

  void _toggleLane({
    required String laneId,
    required String laneName,
    required String laneType,
    required String zoneId,
    required String zoneName,
  }) {
    setState(() {
      final existingIndex =
      _selectedLanes.indexWhere((l) => l['id'] == laneId);
      if (existingIndex >= 0) {
        _selectedLanes.removeAt(existingIndex);
      } else {
        _selectedLanes.add({
          'id': laneId,
          'name': laneName,
          'type': laneType,
          'zone_id': zoneId,
          'zone_name': zoneName,
        });
      }
    });
  }

  // ═══════════════════════════════════════════════
  // IMAGE PICKERS
  // ═══════════════════════════════════════════════

  Future<void> _pickFromCamera() async {
    final t = AppLocalizations.of(context)!;
    if (_selectedImages.length >= AppConfig.maxTicketImages) {
      _showError(t.maxPhotosReached('${AppConfig.maxTicketImages}'));
      return;
    }
    final file = await _imageService.pickFromCamera();
    if (file != null && mounted) {
      setState(() => _selectedImages.add(file));
    }
  }

  Future<void> _pickFromGallery() async {
    final t = AppLocalizations.of(context)!;
    final remaining = AppConfig.maxTicketImages - _selectedImages.length;
    if (remaining <= 0) {
      _showError(t.maxPhotosReached('${AppConfig.maxTicketImages}'));
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
    final t = AppLocalizations.of(context)!;
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
              title: Text(t.takePhoto),
              onTap: () {
                Navigator.pop(context);
                _pickFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t.chooseFromGallery),
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

  // ═══════════════════════════════════════════════
  // SUBMIT
  // ═══════════════════════════════════════════════

  Future<void> _submit() async {
    final t = AppLocalizations.of(context)!;

    if (_selectedSite == null) {
      _showError(t.pleaseSelectSite);
      return;
    }
    if (_selectedLanes.isEmpty) {
      _showError('Please select at least one lane or zone');
      return;
    }
    if (_selectedProductType == null) {
      _showError(t.pleaseSelectProductType);
      return;
    }
    if (!_isOtherProductType && _selectedProductIssue == null) {
      _showError(t.pleaseSelectIssue);
      return;
    }
    if (_requiresDescription &&
        _descriptionController.text.trim().isEmpty) {
      _showError(t.otherDescriptionRequired);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Canonical (English) values saved to Firestore
    final String finalIssue;
    if (_isOtherProductType || _isOtherIssue) {
      finalIssue = _descriptionController.text.trim();
    } else {
      finalIssue = _selectedProductIssue!.canonical;
    }

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
      lanes: _selectedLanes,                     // ← pass selected lanes
      productType: _selectedProductType!.canonical,
      productIssue: finalIssue,
      contactName: _contactNameController.text.trim(),
      contactPhone: _contactPhoneController.text.trim(),
      description: finalDescription,
      imageUrls: const [],
    );

    if (ticket == null) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError(t.somethingWentWrong);
      return;
    }

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

        final updated = await _ticketService.getTicketById(ticket.id);
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
    final t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 10),
            Text(t.ticketSubmitted),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.ticketIdLabel,
              style: const TextStyle(
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
            Text(
              t.ticketSubmittedMessage,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: Text(t.ok),
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

  // ═══════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(t.newTicket)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ═══ LOCATION ═══
              _sectionTitle(t.location),
              _buildSiteDropdown(t),

              // ═══ LANE PICKER (only shows after site selected) ═══
              if (_selectedSite != null) ...[
                const SizedBox(height: 16),
                _buildLanePicker(t),
              ],

              const SizedBox(height: 20),

              // ═══ PRODUCT DETAILS ═══
              _sectionTitle(t.productDetails),
              _buildProductTypeDropdown(t),
              if (!_isOtherProductType) ...[
                const SizedBox(height: 12),
                _buildProductIssueDropdown(t),
              ],

              const SizedBox(height: 20),

              // ═══ PHOTOS ═══
              _sectionTitle(t.photosOptional),
              _buildImageSection(t),

              const SizedBox(height: 20),

              // ═══ CONTACT ═══
              _sectionTitle(t.contactPerson),
              _buildTextInput(
                controller: _contactNameController,
                label: t.nameLabel,
                icon: Icons.person_outline,
                validator: (v) =>
                v == null || v.isEmpty ? t.required : null,
              ),
              const SizedBox(height: 12),
              _buildTextInput(
                controller: _contactPhoneController,
                label: t.phoneLabel,
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                v == null || v.isEmpty ? t.required : null,
              ),
              const SizedBox(height: 20),

              // ═══ DESCRIPTION ═══
              _sectionTitle(
                _requiresDescription
                    ? t.issueDescriptionRequired
                    : t.issueDescriptionOptional,
              ),
              _buildTextArea(t),

              const SizedBox(height: 32),
              PrimaryButton(
                label: t.submitTicket,
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

  Widget _buildSiteDropdown(AppLocalizations t) {
    if (_sites.isEmpty) {
      return _emptyMessage(t.noSitesAssigned);
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedSite?.id,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: t.selectSite,
        prefixIcon: const Icon(
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
          _selectedLanes.clear();   // ← clear lanes when site changes
        });
      },
      validator: (v) => v == null ? t.required : null,
    );
  }

  // ═══════════════════════════════════════════════
  // LANE PICKER
  // ═══════════════════════════════════════════════

  Widget _buildLanePicker(AppLocalizations t) {
    final site = _selectedSite!;

    if (site.zones.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.warning),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: AppColors.warning),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This site has no zones or lanes configured. Contact admin.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

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
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              const Text(
                'Select affected area(s)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (_selectedLanes.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_selectedLanes.length} selected',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap a zone to expand. Select one or more lanes.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // ═══ ZONES (expanded tiles) ═══
          ...site.zones.map((zone) => _zoneSection(zone, site)),
        ],
      ),
    );
  }

  Widget _zoneSection(Zone zone, SiteModel site) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: zone.lanes.any((l) => _isLaneSelected(l.id)),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  zone.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${zone.lanes.length} lane${zone.lanes.length == 1 ? "" : "s"}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          children: [
            if (zone.lanes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No lanes in this zone',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: zone.lanes.map((lane) {
                  final isSelected = _isLaneSelected(lane.id);
                  final color = lane.isEntry
                      ? AppColors.success
                      : AppColors.warning;

                  return InkWell(
                    onTap: () => _toggleLane(
                      laneId: lane.id,
                      laneName: lane.name,
                      laneType: lane.type,
                      zoneId: zone.id,
                      zoneName: zone.name,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.12)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : color.withOpacity(0.4),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            lane.isEntry ? Icons.login : Icons.logout,
                            size: 14,
                            color: color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            lane.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.check_circle,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // PRODUCT TYPE DROPDOWN
  // ═══════════════════════════════════════════════

  Widget _buildProductTypeDropdown(AppLocalizations t) {
    if (_productTypes.isEmpty) {
      return _emptyMessage(t.noProductTypesLoaded);
    }

    final locale = Localizations.localeOf(context);

    return DropdownButtonFormField<String>(
      initialValue: _selectedProductType?.key,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: t.selectProductType,
        prefixIcon: const Icon(
          Icons.build_outlined,
          color: AppColors.textSecondary,
        ),
      ),
      items: _productTypes.map((p) {
        return DropdownMenuItem(
          value: p.key,
          child: Text(
            p.localized(locale),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (key) {
        if (key == null) return;
        setState(() {
          _selectedProductType =
              _productTypes.firstWhere((p) => p.key == key);
          _selectedProductIssue = null;
        });
      },
      validator: (v) => v == null ? t.required : null,
    );
  }

  // ═══════════════════════════════════════════════
  // PRODUCT ISSUE DROPDOWN
  // ═══════════════════════════════════════════════

  Widget _buildProductIssueDropdown(AppLocalizations t) {
    if (_selectedProductType == null) {
      return _disabledHint(t.selectProductTypeFirst);
    }

    final issues =
        _productIssuesMap[_selectedProductType!.key] ?? <LocalizedPreset>[];
    if (issues.isEmpty) {
      return _emptyMessage(t.noIssuesConfigured);
    }

    final locale = Localizations.localeOf(context);

    return DropdownButtonFormField<String>(
      initialValue: _selectedProductIssue?.key,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: t.selectIssue,
        prefixIcon: const Icon(
          Icons.report_problem_outlined,
          color: AppColors.textSecondary,
        ),
      ),
      items: issues.map((p) {
        return DropdownMenuItem(
          value: p.key,
          child: Text(
            p.localized(locale),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (key) {
        if (key == null) return;
        setState(() {
          _selectedProductIssue =
              issues.firstWhere((p) => p.key == key);
        });
      },
      validator: (v) => v == null ? t.required : null,
    );
  }

  // ═══════════════════════════════════════════════
  // IMAGE SECTION
  // ═══════════════════════════════════════════════

  Widget _buildImageSection(AppLocalizations t) {
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
            t.photosCount(
              '${_selectedImages.length}',
              '${AppConfig.maxTicketImages}',
            ),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_a_photo_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t.addPhoto,
                      style: const TextStyle(
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
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
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

  Widget _buildTextArea(AppLocalizations t) {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: _requiresDescription
            ? t.issueDescriptionHintRequired
            : t.issueDescriptionHintOptional,
      ),
      validator: (v) {
        if (_requiresDescription && (v == null || v.trim().isEmpty)) {
          return t.pleaseDescribeIssue;
        }
        return null;
      },
    );
  }
}