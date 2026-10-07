class Lane {
  final String id;
  final String name; // "P1", "P2", ...

  Lane({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
  };

  factory Lane.fromJson(Map<String, dynamic> json) => Lane(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
  );
}

class SiteModel {
  final String id;
  final String clientId;
  final String name;
  final String address;
  final String? notes;
  final List<Lane> lanes;
  final bool isActive;

  SiteModel({
    required this.id,
    required this.clientId,
    required this.name,
    required this.address,
    this.notes,
    this.lanes = const [],
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'client_id': clientId,
    'name': name,
    'address': address,
    'notes': notes,
    'lanes': lanes.map((l) => l.toJson()).toList(),
    'is_active': isActive,
  };

  factory SiteModel.fromJson(Map<String, dynamic> json) => SiteModel(
    id: json['id'] ?? '',
    clientId: json['client_id'] ?? '',
    name: json['name'] ?? '',
    address: json['address'] ?? '',
    notes: json['notes'],
    lanes: _parseLanes(json['lanes']),
    isActive: json['is_active'] ?? true,
  );

  static List<Lane> _parseLanes(dynamic value) {
    if (value == null || value is! List) return [];
    return value
        .whereType<Map>()
        .map((e) => Lane.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  String get displayName => '$name — $address';
}