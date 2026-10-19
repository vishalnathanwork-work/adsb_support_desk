class Lane {
  final String id;
  final String name;        // "Entry 1", "Exit 2"
  final String type;        // "entry" | "exit"
  final int order;          // 1, 2, 3

  Lane({
    required this.id,
    required this.name,
    required this.type,
    required this.order,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'order': order,
  };

  factory Lane.fromJson(Map<String, dynamic> json) => Lane(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    type: json['type'] ?? 'entry',
    order: json['order'] is int ? json['order'] : 1,
  );

  bool get isEntry => type == 'entry';
  bool get isExit => type == 'exit';

  String get directionLabel => isEntry ? 'Entry' : 'Exit';

  /// Full label including type
  String get displayLabel => '$name ($directionLabel)';
}

class Zone {
  final String id;
  final String name;        // "P1", "P2", "Basement"
  final List<Lane> lanes;

  Zone({
    required this.id,
    required this.name,
    this.lanes = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lanes': lanes.map((l) => l.toJson()).toList(),
  };

  factory Zone.fromJson(Map<String, dynamic> json) => Zone(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    lanes: _parseLanes(json['lanes']),
  );

  static List<Lane> _parseLanes(dynamic value) {
    if (value == null || value is! List) return [];
    return value
        .whereType<Map>()
        .map((e) => Lane.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ─── Helpers ───

  List<Lane> get entryLanes =>
      lanes.where((l) => l.isEntry).toList();

  List<Lane> get exitLanes =>
      lanes.where((l) => l.isExit).toList();

  int get entryCount => entryLanes.length;
  int get exitCount => exitLanes.length;
  int get totalLanes => lanes.length;

  /// Short summary: "1 Entry, 2 Exits"
  String get lanesSummary {
    if (lanes.isEmpty) return 'No lanes';
    final parts = <String>[];
    if (entryCount > 0) {
      parts.add('$entryCount Entry${entryCount == 1 ? "" : "s"}');
    }
    if (exitCount > 0) {
      parts.add('$exitCount Exit${exitCount == 1 ? "" : "s"}');
    }
    return parts.join(', ');
  }
}

class SiteModel {
  final String id;
  final String clientId;
  final String name;
  final String address;
  final String? notes;
  final List<Zone> zones;
  final bool isActive;

  SiteModel({
    required this.id,
    required this.clientId,
    required this.name,
    required this.address,
    this.notes,
    this.zones = const [],
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'client_id': clientId,
    'name': name,
    'address': address,
    'notes': notes,
    'zones': zones.map((z) => z.toJson()).toList(),
    'is_active': isActive,
  };

  factory SiteModel.fromJson(Map<String, dynamic> json) => SiteModel(
    id: json['id'] ?? '',
    clientId: json['client_id'] ?? '',
    name: json['name'] ?? '',
    address: json['address'] ?? '',
    notes: json['notes'],
    zones: _parseZones(json['zones']),
    isActive: json['is_active'] ?? true,
  );

  static List<Zone> _parseZones(dynamic value) {
    if (value == null || value is! List) return [];
    return value
        .whereType<Map>()
        .map((e) => Zone.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  String get displayName => '$name — $address';

  // ─── Helpers ───

  int get zoneCount => zones.length;

  int get totalLanes =>
      zones.fold(0, (sum, z) => sum + z.totalLanes);

  int get totalEntries =>
      zones.fold(0, (sum, z) => sum + z.entryCount);

  int get totalExits =>
      zones.fold(0, (sum, z) => sum + z.exitCount);

  /// Zone names: "P1, P2, P3"
  String get zonesSummary {
    if (zones.isEmpty) return 'No zones';
    return zones.map((z) => z.name).join(', ');
  }

  /// Short overall summary: "2 zones · 3 Entries · 4 Exits"
  String get overallSummary {
    if (zones.isEmpty) return 'No zones';
    final parts = <String>[];
    parts.add('$zoneCount zone${zoneCount == 1 ? "" : "s"}');
    if (totalEntries > 0) {
      parts.add('$totalEntries Entr${totalEntries == 1 ? "y" : "ies"}');
    }
    if (totalExits > 0) {
      parts.add('$totalExits Exit${totalExits == 1 ? "" : "s"}');
    }
    return parts.join(' · ');
  }

  /// All lanes across all zones in this site.
  List<Lane> get lanes =>
      zones.expand((z) => z.lanes).toList();

  /// Find a zone by name (case-insensitive)
  Zone? zoneByName(String name) {
    try {
      return zones.firstWhere(
            (z) => z.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}