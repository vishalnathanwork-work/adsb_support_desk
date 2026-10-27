class UserModel {
  final String email;         // internal only — <username>@adsb.local
  final String username;      // what the user types to log in
  final String name;
  final String role; // owner | operator | adsb | technician | onsite | admin
  final String? phone;
  final String? company;
  final String? remark;
  final bool isActive;
  final List<String> siteIds;
  final String? clientId;
  final String? clientName;

  /// 'pending' | 'approved' | 'rejected'
  final String approvalStatus;

  final DateTime? registeredAt;
  final DateTime? approvedAt;
  final String? approvedBy;

  UserModel({
    required this.email,
    this.username = '',
    required this.name,
    required this.role,
    this.phone,
    this.company,
    this.remark,
    this.isActive = true,
    this.siteIds = const [],
    this.clientId,
    this.clientName,
    this.approvalStatus = 'approved',
    this.registeredAt,
    this.approvedAt,
    this.approvedBy,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'username': username,
    'name': name,
    'role': role,
    'phone': phone,
    'company': company,
    'remark': remark,
    'is_active': isActive,
    'site_ids': siteIds,
    'client_id': clientId,
    'client_name': clientName,
    'approval_status': approvalStatus,
    'registered_at': registeredAt?.toIso8601String(),
    'approved_at': approvedAt?.toIso8601String(),
    'approved_by': approvedBy,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    email: json['email'] ?? '',
    username: json['username'] ?? '',
    name: json['name'] ?? '',
    role: json['role'] ?? 'owner',
    phone: json['phone'],
    company: json['company'] ?? json['remark'],
    remark: json['remark'],
    isActive: json['is_active'] ?? true,
    siteIds: _parseStringList(json['site_ids']),
    clientId: json['client_id'],
    clientName: json['client_name'],
    approvalStatus: json['approval_status'] ?? 'approved',
    registeredAt: _parseDate(json['registered_at']),
    approvedAt: _parseDate(json['approved_at']),
    approvedBy: json['approved_by'],
  );

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is String) return value.isEmpty ? [] : [value];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  // ─── Approval helpers ───
  bool get isPendingApproval =>
      approvalStatus == 'pending' || !isActive;

  bool get isApproved =>
      approvalStatus == 'approved' && isActive;

  bool get isRejected => approvalStatus == 'rejected';

  // ─── Role helpers ───
  bool get isOwner => role == 'owner';
  bool get isOperator => role == 'operator';
  bool get isAdsbTeam => role == 'adsb';
  bool get isTechnician => role == 'technician';
  bool get isOnsiteTeam => role == 'onsite';
  bool get isAdmin => role == 'admin';

  bool get isExternal => isOwner || isOperator;

  bool get isInternal =>
      isAdsbTeam || isTechnician || isOnsiteTeam || isAdmin;

  bool get canDoOnsite => isOnsiteTeam || isAdsbTeam || isAdmin;

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