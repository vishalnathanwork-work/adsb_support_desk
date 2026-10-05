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
    'id': id,
    'createdBy': createdBy,
    'createdByName': createdByName,
    'createdByRole': createdByRole,
    'siteLocation': siteLocation,
    'siteName': siteName,
    'productType': productType,
    'productIssue': productIssue,
    'contactName': contactName,
    'contactPhone': contactPhone,
    'description': description,
    'imagePaths': imagePaths,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'rootCause': rootCause,
    'solutionApplied': solutionApplied,
    'resolutionNotes': resolutionNotes,
    'resolvedAt': resolvedAt?.toIso8601String(),

    'assignedTo': assignedTo,
    'assignedToName': assignedToName,
  };

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
    id: json['id'],
    createdBy: json['createdBy'],
    createdByName: json['createdByName'],
    createdByRole: json['createdByRole'],
    siteLocation: json['siteLocation'],
    siteName: json['siteName'],
    productType: json['productType'],
    productIssue: json['productIssue'],
    contactName: json['contactName'],
    contactPhone: json['contactPhone'],
    description: json['description'] ?? '',
    imagePaths: List<String>.from(json['imagePaths'] ?? []),
    status: json['status'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
    rootCause: json['rootCause'],
    solutionApplied: json['solutionApplied'],
    resolutionNotes: json['resolutionNotes'],
    resolvedAt: json['resolvedAt'] != null
        ? DateTime.parse(json['resolvedAt'])
        : null,

    // Add to fromJson():
    assignedTo: json['assignedTo'],
    assignedToName: json['assignedToName'],
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