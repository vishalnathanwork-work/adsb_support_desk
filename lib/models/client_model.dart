class ClientModel {
  final String id;
  final String name;
  final String code;
  final String? contactEmail;
  final String? contactPhone;
  final bool isActive;

  ClientModel({
    required this.id,
    required this.name,
    required this.code,
    this.contactEmail,
    this.contactPhone,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'contact_email': contactEmail,
    'contact_phone': contactPhone,
    'is_active': isActive,
  };

  factory ClientModel.fromJson(Map<String, dynamic> json) => ClientModel(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    code: json['code'] ?? '',
    contactEmail: json['contact_email'],
    contactPhone: json['contact_phone'],
    isActive: json['is_active'] ?? true,
  );

  String get displayName => '$name ($code)';
}