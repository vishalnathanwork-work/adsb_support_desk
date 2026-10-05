class UserModel {
  final String email;
  final String name;
  final String role;
  final String? phone;
  final String? company;

  UserModel({
    required this.email,
    required this.name,
    required this.role,
    this.phone,
    this.company,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'name': name,
    'role': role,
    'phone': phone,
    'company': company,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    email: json['email'],
    name: json['name'],
    role: json['role'],
    phone: json['phone'],
    company: json['company'],
  );

  // Helper getters for role checks
  bool get isClient => role == 'client';
  bool get isOperator => role == 'operator';
  bool get isAdsbTeam => role == 'adsb';
  bool get isTechnician => role == 'technician';
  bool get isAdmin => role == 'admin';

  // Display name for the role
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