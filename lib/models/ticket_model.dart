class Ticket {
  final String id;
  final String createdBy;       // user email
  final String createdByName;
  final String createdByRole;   // client | operator
  final String siteLocation;    // auto-filled
  final String siteName;        // which site
  final String productType;
  final String productIssue;
  final String contactName;
  final String contactPhone;
  final String description;     // optional
  final List<String> imagePaths; // local paths for now
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Resolution details (filled later by technicians)
  final String? rootCause;
  final String? solutionApplied;
  final String? resolutionNotes;
  final DateTime? resolvedAt;

  final String? assignedTo;       // ADSB agent email
  final String? assignedToName;   // ADSB agent name

  Ticket({
    required this.id,
    required this.createdBy,
    required this.createdByName,
    required this.createdByRole,
    required this.siteLocation,
    required this.siteName,
    required this.productType,
    required this.productIssue,
    required this.contactName,
    required this.contactPhone,
    required this.description,
    required this.imagePaths,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.rootCause,
    this.solutionApplied,
    this.resolutionNotes,
    this.resolvedAt,

    // Add to constructor:
    this.assignedTo,
    this.assignedToName,
  });

  Map<String, dynamic> toJson() => {
    'ticket_id': id,
    'created_by': createdBy,
    'created_by_name': createdByName,
    'created_by_role': createdByRole,
    'site_location': siteLocation,
    'site_name': siteName,
    'product_type': productType,
    'product_issue': productIssue,
    'contact_name': contactName,
    'contact_phone': contactPhone,
    'description': description,
    'status': status,
    'assigned_to': assignedTo,
    'assigned_to_name': assignedToName,
    'root_cause': rootCause,
    'solution_applied': solutionApplied,
    'resolution_notes': resolutionNotes,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'resolved_at': resolvedAt?.toIso8601String(),
  };

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
    id: json['ticket_id'] ?? json['id'] ?? '',
    createdBy: json['created_by'] ?? '',
    createdByName: json['created_by_name'] ?? '',
    createdByRole: json['created_by_role'] ?? 'client',
    siteLocation: json['site_location'] ?? '',
    siteName: json['site_name'] ?? '',
    productType: json['product_type'] ?? '',
    productIssue: json['product_issue'] ?? '',
    contactName: json['contact_name'] ?? '',
    contactPhone: json['contact_phone'] ?? '',
    description: json['description'] ?? '',
    imagePaths: [],
    status: json['status'] ?? 'pending',
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : DateTime.now(),
    updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'])
        : DateTime.now(),
    assignedTo: json['assigned_to'],
    assignedToName: json['assigned_to_name'],
    rootCause: json['root_cause'],
    solutionApplied: json['solution_applied'],
    resolutionNotes: json['resolution_notes'],
    resolvedAt: json['resolved_at'] != null
        ? DateTime.parse(json['resolved_at'])
        : null,
  );

  Ticket copyWith({
    String? status,
    String? rootCause,
    String? solutionApplied,
    String? resolutionNotes,

    // Update copyWith to include:
    String? assignedTo,
    String? assignedToName,

    DateTime? resolvedAt,
    DateTime? updatedAt,
  }) =>
      Ticket(
        id: id,
        createdBy: createdBy,
        createdByName: createdByName,
        createdByRole: createdByRole,
        siteLocation: siteLocation,
        siteName: siteName,
        productType: productType,
        productIssue: productIssue,
        contactName: contactName,
        contactPhone: contactPhone,
        description: description,
        imagePaths: imagePaths,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        rootCause: rootCause ?? this.rootCause,
        solutionApplied: solutionApplied ?? this.solutionApplied,
        resolutionNotes: resolutionNotes ?? this.resolutionNotes,
        resolvedAt: resolvedAt ?? this.resolvedAt,

        assignedTo: assignedTo ?? this.assignedTo,
        assignedToName: assignedToName ?? this.assignedToName,

      );

  // Status helpers
  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending Verification';
      case 'verified':
        return 'Verified — Pending On-Site';
      case 'in_progress':
        return 'On-Site In Progress';
      case 'resolved':
        return 'Resolved — Awaiting Confirmation';
      case 'closed':
        return 'Closed';
      case 'reopened':
        return 'Reopened';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  bool get isPending => status == 'pending';
  bool get isActive =>
      status == 'pending' ||
          status == 'verified' ||
          status == 'in_progress' ||
          status == 'reopened';
  bool get isResolved => status == 'resolved' || status == 'closed';

  bool get isUnassigned => assignedTo == null && status == 'pending';
  bool get isBeingVerified => assignedTo != null && status == 'pending';
  
}