import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/client_model.dart';
import '../../../models/site_model.dart';
import '../../../services/owner_service.dart';
import '../../../services/site_service.dart';
import '../../../services/user_service.dart';

class UserFormSheet extends StatefulWidget {
  final List<String> allowedRoles;
  final Map<String, dynamic>? existingUser;

  const UserFormSheet({
    super.key,
    required this.allowedRoles,
    this.existingUser,
  });

  @override
  State<UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();
  final _siteService = SiteService();
  final _clientService = ClientService();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _phoneController;
  late TextEditingController _companyController;

  String? _selectedRole;
  ClientModel? _selectedClient;
  List<ClientModel> _allClients = [];
  List<SiteModel> _clientSites = [];
  Set<String> _selectedSiteIds = {};

  bool _loadingClients = true;
  bool _loadingSites = false;
  bool _isSaving = false;
  bool _obscurePassword = true;

  bool get isEditMode => widget.existingUser != null;

  bool get requiresClient {
    final r = _selectedRole ?? '';
    return r == 'owner' || r == 'operator';
  }

  bool get hasExternalRole => widget.allowedRoles.any(
        (r) => r == 'owner' || r == 'operator',
  );

  @override
  void initState() {
    super.initState();
    final u = widget.existingUser;

    _nameController = TextEditingController(text: u?['name'] ?? '');
    _emailController = TextEditingController(text: u?['email'] ?? '');
    _passwordController = TextEditingController();
    _phoneController = TextEditingController(text: u?['phone'] ?? '');
    _companyController = TextEditingController(text: u?['company'] ?? '');
    _selectedRole = u?['role'] ?? widget.allowedRoles.first;

    final siteIdsRaw = u?['site_ids'];
    if (siteIdsRaw is List) {
      _selectedSiteIds =
      Set<String>.from(siteIdsRaw.map((e) => e.toString()));
    } else if (siteIdsRaw is String && siteIdsRaw.isNotEmpty) {
      _selectedSiteIds = {siteIdsRaw};
    }

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!hasExternalRole) {
      setState(() => _loadingClients = false);
      return;
    }

    setState(() => _loadingClients = true);
    final clients = await _clientService.getAllClients();

    final existingClientId = widget.existingUser?['client_id'] as String?;
    ClientModel? preSelected;
    if (existingClientId != null) {
      for (final c in clients) {
        if (c.id == existingClientId) {
          preSelected = c;
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _allClients = clients;
      _selectedClient = preSelected;
      _loadingClients = false;
    });

    if (preSelected != null) {
      await _loadSitesFor(preSelected.id);
    }
  }

  Future<void> _loadSitesFor(String clientId) async {
    setState(() {
      _loadingSites = true;
      _clientSites = [];
    });
    final sites = await _siteService.getSitesByClientId(clientId);
    if (!mounted) return;
    setState(() {
      _clientSites = sites;
      _loadingSites = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _saveEdit() async {
    final t = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (requiresClient && _selectedClient == null) {
      _snack(t.approvalPleaseSelectClient, AppColors.error);
      return;
    }

    setState(() => _isSaving = true);
    final uid = widget.existingUser!['uid'] as String;

    final ok = await _userService.updateUser(
      uid: uid,
      fields: {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'company': _companyController.text.trim(),
        'role': _selectedRole,
        'client_id': requiresClient ? _selectedClient?.id : null,
        'client_name': requiresClient ? _selectedClient?.name : null,
        'site_ids':
        requiresClient ? _selectedSiteIds.toList() : <String>[],
      },
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      _snack(t.adminFailedSaveChanges, AppColors.error);
    }
  }

  Future<void> _saveCreate() async {
    final t = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (requiresClient && _selectedClient == null) {
      _snack(t.approvalPleaseSelectClient, AppColors.error);
      return;
    }

    setState(() => _isSaving = true);

    final result = await _userService.adminCreateUser(
      email: _emailController.text.trim().toLowerCase(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      role: _selectedRole!,
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      clientId: requiresClient ? _selectedClient?.id : null,
      clientName: requiresClient ? _selectedClient?.name : null,
      siteIds: requiresClient ? _selectedSiteIds.toList() : <String>[],
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.uid != null) {
      _snack(t.adminUserCreated, AppColors.success);
      Navigator.pop(context, true);
    } else {
      _snack(result.error ?? t.adminFailedCreateUser, AppColors.error);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  String _roleLabel(AppLocalizations t, String role) {
    switch (role) {
      case 'owner':
        return t.siteOwner;
      case 'operator':
        return t.siteOperator;
      case 'adsb':
        return t.supportTeam;
      case 'technician':
        return t.technicalAdvisor;
      case 'onsite':
        return t.onSiteTechnician;
      case 'admin':
        return t.administrator;
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: _loadingClients
          ? const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      )
          : SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _handle(),
              const SizedBox(height: 20),
              Text(
                isEditMode ? t.adminEditUser : t.adminAddNewUser,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              _label(t.fullName),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: t.fullNameHint,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? t.required
                    : null,
              ),
              const SizedBox(height: 16),

              _label(t.adminLoginEmail),
              TextFormField(
                controller: _emailController,
                enabled: !isEditMode,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: t.emailHintRegister,
                  prefixIcon: const Icon(Icons.email_outlined),
                  fillColor: isEditMode
                      ? Colors.grey.shade100
                      : Colors.white,
                  helperText: isEditMode
                      ? t.adminEmailImmutable
                      : t.adminEmailLoginHint,
                  helperStyle: const TextStyle(fontSize: 11),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return t.required;
                  }
                  if (!v.contains('@')) return t.invalidEmail;
                  return null;
                },
              ),
              const SizedBox(height: 16),

              if (!isEditMode) ...[
                _label(t.adminTempPassword),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: t.passwordMin6,
                    prefixIcon: const Icon(Icons.lock_outline),
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
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return t.required;
                    if (v.length < 6) return t.passwordMin6;
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              _label(t.adminRoleLabel),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: widget.allowedRoles
                    .map((r) => DropdownMenuItem(
                  value: r,
                  child: Text(_roleLabel(t, r)),
                ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedRole = v;
                    if (!requiresClient) {
                      _selectedClient = null;
                      _selectedSiteIds.clear();
                    }
                  });
                },
                validator: (v) => v == null ? t.required : null,
              ),
              const SizedBox(height: 16),

              if (requiresClient) ...[
                _label(t.clientLabel),
                DropdownButtonFormField<String>(
                  initialValue: _selectedClient?.id,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: t.adminSelectClientHint,
                    prefixIcon:
                    const Icon(Icons.business_outlined),
                  ),
                  items: _allClients.map((c) {
                    return DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        c.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (id) async {
                    if (id == null) return;
                    final client =
                    _allClients.firstWhere((c) => c.id == id);
                    setState(() {
                      _selectedClient = client;
                      _selectedSiteIds.clear();
                    });
                    await _loadSitesFor(id);
                  },
                  validator: (v) => v == null ? t.required : null,
                ),
                const SizedBox(height: 16),

                if (_selectedClient != null) ...[
                  _label(t.adminAssignSites),
                  _buildSiteSelector(t),
                  const SizedBox(height: 16),
                ],
              ],

              _label(t.adminPhoneOptional),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: t.phoneHint,
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),

              if (hasExternalRole) ...[
                _label(t.adminCompanyOptional),
                TextFormField(
                  controller: _companyController,
                  decoration: InputDecoration(
                    hintText: t.adminCompanyAutoFilled,
                    prefixIcon:
                    const Icon(Icons.apartment_outlined),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 8),

              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : (isEditMode ? _saveEdit : _saveCreate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                      : Text(
                    isEditMode
                        ? t.adminSaveChanges
                        : t.adminCreateUserBtn,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSiteSelector(AppLocalizations t) {
    if (_loadingSites) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_clientSites.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.warning),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_outlined,
                color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.adminClientNoSites,
                style: const TextStyle(fontSize: 13),
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
        children: _clientSites.map((site) {
          final selected = _selectedSiteIds.contains(site.id);
          return CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: selected,
            activeColor: AppColors.primary,
            title: Text(
              site.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              site.address,
              style: const TextStyle(fontSize: 11),
            ),
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedSiteIds.add(site.id);
                } else {
                  _selectedSiteIds.remove(site.id);
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _handle() => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
  );
}