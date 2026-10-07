class UserModel {
  final String email;
  final String name;
  final String role;
  final String? phone;
  final String? company;
  final String? clientId;
  final bool isActive;
  final List<String> siteIds;

  UserModel({
    required this.email,
    required this.name,
    required this.role,
    this.phone,
    this.company,
    this.clientId,
    this.isActive = true,
    this.siteIds = const [],
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
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    email: json['email'] ?? '',
    name: json['name'] ?? '',
    role: json['role'] ?? 'client',
    phone: json['phone'],
    company: json['company'],
    clientId: json['client_id'],
    isActive: json['is_active'] ?? true,
    siteIds: _parseStringList(json['site_ids']),
  );

  /// Safely converts a Firestore value into a `List<String>`.
  /// Handles: null, String, `List<String>`, `List<dynamic>`.
  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];

    // Single string → wrap in list
    if (value is String) {
      return value.isEmpty ? [] : [value];
    }

    // Already a list → convert elements to String
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }

    // Fallback
    return [];
  }

  // ─── Role helpers ───
  bool get isClient => role == 'client';
  bool get isOperator => role == 'operator';
  bool get isAdsbTeam => role == 'adsb';
  bool get isTechnician => role == 'technician';
  bool get isAdmin => role == 'admin';
  bool get isInternal => isAdsbTeam || isTechnician || isAdmin;
  bool get hasClient => clientId != null && clientId!.isNotEmpty;

  String get roleDisplayName {
    switch (role) {
      case 'client':
        return 'Client';
      case 'operator':
        return 'Operator';
      case 'adsb':
        return 'ADSB Support Team';
      case 'technician':
        return 'Technical Advisor';
      case 'admin':
        return 'Administrator';
      default:
        return 'User';
    }
  }
}