import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/client_model.dart';
import '../../models/site_model.dart';
import '../../services/auth_service.dart';
import '../../services/owner_service.dart';
import '../../services/site_service.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/brand_background.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import 'widgets/site_picker_sheet.dart';
import 'pending_approval_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  final _authService = AuthService();
  final _siteService = SiteService();
  final _clientService = ClientService();

  String _role = 'owner'; // 'owner' | 'operator'

  List<ClientModel> _allClients = [];
  ClientModel? _selectedClient;

  List<SiteModel> _companySites = [];
  List<SiteModel> _selectedSites = [];

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _loadingClients = true;
  bool _loadingSites = false;
  String? _siteError;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() => _loadingClients = true);
    final clients = await _clientService.getAllClients();
    if (!mounted) return;
    setState(() {
      _allClients = clients.where((c) => c.isActive).toList();
      _loadingClients = false;
    });
  }

  Future<void> _onClientChanged(String? clientId) async {
    if (clientId == null) return;
    final client = _allClients.firstWhere((c) => c.id == clientId);

    setState(() {
      _selectedClient = client;
      _selectedSites = [];
      _companySites = [];
      _siteError = null;
      _loadingSites = true;
    });

    final sites = await _siteService.getSitesByClientId(clientId);
    if (!mounted) return;
    setState(() {
      _companySites = sites.where((s) => s.isActive).toList();
      _loadingSites = false;
    });
  }

  // ─────────────────────────────────────────────
  // SITE PICKER
  // ─────────────────────────────────────────────

  Future<void> _openSitePicker() async {
    if (_selectedClient == null) {
      _snack('Please select a company first', AppColors.warning);
      return;
    }

    if (_companySites.isEmpty) {
      _snack('No sites available for this company', AppColors.warning);
      return;
    }

    final isOwner = _role == 'owner';

    final picked = await showModalBottomSheet<List<SiteModel>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SitePickerSheet(
        allSites: _companySites,
        initialSelection: _selectedSites,
        allowMultiple: isOwner,
      ),
    );

    if (picked == null) return;

    setState(() {
      _selectedSites = picked;
      _siteError = null;
    });
  }

  void _removeSite(SiteModel site) {
    setState(() {
      _selectedSites.removeWhere((s) => s.id == site.id);
      _siteError = null;
    });
  }

  // ─────────────────────────────────────────────
  // SUBMIT
  // ─────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClient == null) {
      _snack('Please select your company', AppColors.error);
      return;
    }

    if (_selectedSites.isEmpty) {
      setState(() => _siteError = 'Please select at least one site');
      return;
    }

    if (_role == 'operator' && _selectedSites.length != 1) {
      setState(() => _siteError = 'Operator can only manage one site');
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim(),
      role: _role,
      siteIds: _selectedSites.map((s) => s.id).toList(),
      clientId: _selectedClient!.id,
      clientName: _selectedClient!.name,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success && result.user != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => PendingApprovalScreen(user: result.user!),
        ),
            (r) => false,
      );
    } else {
      _snack(result.message ?? 'Registration failed', AppColors.error);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BrandBackground(
        overlayOpacity: 0.65,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  boxShadow: AppShadows.large,
                ),
                child: _loadingClients
                    ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
                    : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: AppLogo(size: 64)),
                      const SizedBox(height: 16),
                      const Text(
                        'Create Account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your request will be reviewed by our team',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─── Name ───
                      CustomTextField(
                        label: 'Full Name',
                        hint: 'e.g. Ahmad bin Abdullah',
                        icon: Icons.person_outline,
                        controller: _nameController,
                        validator: (v) =>
                        v == null || v.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // ─── Email ───
                      CustomTextField(
                        label: 'Email',
                        hint: 'you@company.com',
                        icon: Icons.email_outlined,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Required';
                          }
                          if (!v.contains('@')) {
                            return 'Invalid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ─── Password ───
                      CustomTextField(
                        label: 'Password',
                        hint: 'Minimum 6 characters',
                        icon: Icons.lock_outline,
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => setState(() =>
                          _obscurePassword = !_obscurePassword),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Required';
                          }
                          if (v.length < 6) {
                            return 'Minimum 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ─── Phone (NEW) ───
                      CustomTextField(
                        label: 'Phone Number',
                        hint: '+60 12-345 6789',
                        icon: Icons.phone_outlined,
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Required';
                          }
                          // Basic phone validation: at least 8 digits
                          final digits =
                          v.replaceAll(RegExp(r'\D'), '');
                          if (digits.length < 8) {
                            return 'Enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ─── Company dropdown (NEW) ───
                      _buildClientDropdown(),
                      const SizedBox(height: 20),

                      // ─── Role picker ───
                      const Text(
                        'I am registering as:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _roleOption(
                        role: 'owner',
                        title: 'Site Owner',
                        subtitle: 'Manages multiple sites',
                        icon: Icons.business_outlined,
                      ),
                      const SizedBox(height: 8),
                      _roleOption(
                        role: 'operator',
                        title: 'Site Operator',
                        subtitle: 'Manages one site',
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 20),

                      // ─── Site selection ───
                      _buildSiteSection(),
                      const SizedBox(height: 24),

                      // ─── Submit ───
                      PrimaryButton(
                        label: 'Create Account',
                        onPressed: _isLoading ? null : _submit,
                        isLoading: _isLoading,
                      ),
                      const SizedBox(height: 16),

                      // ─── Back to login ───
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Already have an account? Sign in',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Company dropdown ───
  Widget _buildClientDropdown() {
    if (_allClients.isEmpty) {
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
                'No companies available. Contact ADSB support.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Company',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: _selectedClient?.id,
          isExpanded: true,
          decoration: const InputDecoration(
            hintText: 'Select your company',
            prefixIcon: Icon(Icons.business_outlined),
          ),
          items: _allClients.map((c) {
            return DropdownMenuItem(
              value: c.id,
              child: Text(
                c.name,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _onClientChanged,
          validator: (v) => v == null ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _roleOption({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _role == role;
    return InkWell(
      onTap: () {
        setState(() {
          _role = role;
          if (role == 'operator' && _selectedSites.length > 1) {
            _selectedSites = [_selectedSites.first];
          }
          _siteError = null;
        });
      },
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: role,
              groupValue: _role,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() {
                _role = v!;
                if (v == 'operator' && _selectedSites.length > 1) {
                  _selectedSites = [_selectedSites.first];
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteSection() {
    // If no client selected yet
    if (_selectedClient == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Which site(s) do you manage?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Select a company first',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    if (_loadingSites) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_companySites.isEmpty) {
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
                'This company has no sites yet. Contact ADSB support.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Which site(s) do you manage?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _role == 'owner'
              ? 'You can select multiple sites'
              : 'Select exactly one site',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),

        // Selected sites
        if (_selectedSites.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: _selectedSites.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              s.address,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => _removeSite(s),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

        if (_siteError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 14, color: AppColors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _siteError!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _openSitePicker,
          icon: const Icon(Icons.add_location_alt_outlined, size: 18),
          label: Text(
            _selectedSites.isEmpty ? 'Select Site(s)' : 'Add More',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}