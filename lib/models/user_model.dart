class UserModel {
  final String email;
  final String name;
  final String role; // owner | operator | adsb | technician | onsite | admin
  final String? phone;
  final String? company;
  final bool isActive;
  final List<String> siteIds;
  final String? clientId;
  final String? clientName;

  UserModel({
    required this.email,
    required this.name,
    required this.role,
    this.phone,
    this.company,
    this.isActive = true,
    this.siteIds = const [],
    this.clientId,
    this.clientName,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'name': name,
    'role': role,
    'phone': phone,
    'company': company,
    'is_active': isActive,
    'site_ids': siteIds,
    'client_id': clientId,
    'client_name': clientName,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    email: json['email'] ?? '',
    name: json['name'] ?? '',
    role: json['role'] ?? 'owner',
    phone: json['phone'],
    company: json['company'],
    isActive: json['is_active'] ?? true,
    siteIds: _parseStringList(json['site_ids']),
    clientId: json['client_id'],
    clientName: json['client_name'],
  );

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is String) return value.isEmpty ? [] : [value];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  // ─── Role helpers ───
  bool get isOwner => role == 'owner';
  bool get isOperator => role == 'operator';
  bool get isAdsbTeam => role == 'adsb';
  bool get isTechnician => role == 'technician';
  bool get isOnsiteTeam => role == 'onsite';
  bool get isAdmin => role == 'admin';

  /// External = owner or operator.
  bool get isExternal => isOwner || isOperator;

  /// Internal = ADSB, TT, On-Site, Admin.
  bool get isInternal =>
      isAdsbTeam || isTechnician || isOnsiteTeam || isAdmin;

  /// Anyone who can claim/complete on-site jobs.
  bool get canDoOnsite => isOnsiteTeam || isAdsbTeam || isAdmin;

  /// Display name for the role.
  String get roleDisplayName {
    switch (role) {
      case 'owner':
        return 'Site Owner';
      case 'operator':
        return 'Site Operator';
      case 'adsb':
        return 'ADSB Support Team';
      case 'technician':
        return 'Technical Advisor';
      case 'onsite':
        return 'On-Site Team';
      case 'admin':
        return 'Administrator';
      default:
        return 'User';
    }
  }

  /// Chat bubble label.
  /// Internal roles (adsb/technician/onsite/admin) all show "ADSB Support".
  String get chatLabel {
    switch (role) {
      case 'owner':
        return 'Site Owner';
      case 'operator':
        return 'Site Operator';
      case 'adsb':
      case 'technician':
      case 'onsite':
      case 'admin':
        return 'ADSB Support';
      default:
        return 'User';
    }
  }
}