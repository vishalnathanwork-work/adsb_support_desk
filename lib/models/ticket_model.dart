import 'package:cloud_firestore/cloud_firestore.dart';

class Ticket {
  final String id;
  final String createdBy;
  final String createdByName;
  final String createdByRole;

  // Site
  final String siteId;
  final String siteName;
  final String siteLocation;

  // Lane (parking label + user-chosen direction)
  final String laneId;
  final String laneName;       // "P1"
  final String laneDirection;  // "entry" | "exit"

  final String productType;
  final String productIssue;
  final String contactName;
  final String contactPhone;
  final String description;
  final List<String> imageUrls;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? rootCause;
  final String? solutionApplied;
  final String? resolutionNotes;
  final String? escalationReason;
  final DateTime? resolvedAt;
  final String? assignedTo;
  final String? assignedToName;

  // ─── Timestamp Logs ───
  final DateTime? adsbNotifiedAt;
  final DateTime? callStartedAt;
  final DateTime? callEndedAt;
  final DateTime? remoteFixAt;
  final DateTime? verifiedAt;
  final DateTime? ttNotifiedAt;
  final DateTime? ttSolutionProvidedAt;
  final DateTime? adsbPickupAt;
  final DateTime? dispatchAt;
  final DateTime? arrivedAt;
  final DateTime? workStartedAt;
  final DateTime? workCompletedAt;
  final DateTime? evidenceUploadedAt;
  final DateTime? clientConfirmedAt;
  final DateTime? reopenedAt;
  final DateTime? autoClosedAt;
  final DateTime? noShowAt;
  final DateTime? escalatedAt;

  Ticket({
    required this.id,
    required this.createdBy,
    required this.createdByName,
    required this.createdByRole,
    required this.siteId,
    required this.siteName,
    required this.siteLocation,
    required this.laneId,
    required this.laneName,
    required this.laneDirection,
    required this.productType,
    required this.productIssue,
    required this.contactName,
    required this.contactPhone,
    required this.description,
    required this.imageUrls,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.rootCause,
    this.solutionApplied,
    this.resolutionNotes,
    this.escalationReason,
    this.resolvedAt,
    this.assignedTo,
    this.assignedToName,
    this.adsbNotifiedAt,
    this.callStartedAt,
    this.callEndedAt,
    this.remoteFixAt,
    this.verifiedAt,
    this.ttNotifiedAt,
    this.ttSolutionProvidedAt,
    this.adsbPickupAt,
    this.dispatchAt,
    this.arrivedAt,
    this.workStartedAt,
    this.workCompletedAt,
    this.evidenceUploadedAt,
    this.clientConfirmedAt,
    this.reopenedAt,
    this.autoClosedAt,
    this.noShowAt,
    this.escalatedAt,
  });

  static DateTime? _ts(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  static List<String> _stringList(dynamic value) {
    if (value == null) return [];
    if (value is String) return value.isEmpty ? [] : [value];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
    id: json['ticket_id'] ?? json['id'] ?? '',
    createdBy: json['created_by'] ?? '',
    createdByName: json['created_by_name'] ?? '',
    createdByRole: json['created_by_role'] ?? 'client',

    siteId: json['site_id'] ?? '',
    siteName: json['site_name'] ?? '',
    siteLocation: json['site_location'] ?? '',

    laneId: json['lane_id'] ?? '',
    laneName: json['lane_name'] ?? '',
    laneDirection: json['lane_direction'] ??
        json['lane_type'] ?? // fallback for old tickets
        'entry',

    productType: json['product_type'] ?? '',
    productIssue: json['product_issue'] ?? '',
    contactName: json['contact_name'] ?? '',
    contactPhone: json['contact_phone'] ?? '',
    description: json['description'] ?? '',
    imageUrls: _stringList(json['image_urls']),
    status: json['status'] ?? 'pending',
    createdAt: _ts(json['created_at']) ?? DateTime.now(),
    updatedAt: _ts(json['updated_at']) ?? DateTime.now(),
    assignedTo: json['assigned_to'],
    assignedToName: json['assigned_to_name'],
    rootCause: json['root_cause'],
    solutionApplied: json['solution_applied'],
    resolutionNotes: json['resolution_notes'],
    escalationReason: json['escalation_reason'],
    resolvedAt: _ts(json['resolved_at']),
    adsbNotifiedAt: _ts(json['adsb_notified_at']),
    callStartedAt: _ts(json['call_started_at']),
    callEndedAt: _ts(json['call_ended_at']),
    remoteFixAt: _ts(json['remote_fix_at']),
    verifiedAt: _ts(json['verified_at']),
    ttNotifiedAt: _ts(json['tt_notified_at']),
    ttSolutionProvidedAt: _ts(json['tt_solution_provided_at']),
    adsbPickupAt: _ts(json['adsb_pickup_at']),
    dispatchAt: _ts(json['dispatch_at']),
    arrivedAt: _ts(json['arrived_at']),
    workStartedAt: _ts(json['work_started_at']),
    workCompletedAt: _ts(json['work_completed_at']),
    evidenceUploadedAt: _ts(json['evidence_uploaded_at']),
    clientConfirmedAt: _ts(json['client_confirmed_at']),
    reopenedAt: _ts(json['reopened_at']),
    autoClosedAt: _ts(json['auto_closed_at']),
    noShowAt: _ts(json['no_show_at']),
    escalatedAt: _ts(json['escalated_at']),
  );

  Ticket copyWith({
    String? status,
    String? rootCause,
    String? solutionApplied,
    String? resolutionNotes,
    String? escalationReason,
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
        siteId: siteId,
        siteName: siteName,
        siteLocation: siteLocation,
        laneId: laneId,
        laneName: laneName,
        laneDirection: laneDirection,
        productType: productType,
        productIssue: productIssue,
        contactName: contactName,
        contactPhone: contactPhone,
        description: description,
        imageUrls: imageUrls,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        rootCause: rootCause ?? this.rootCause,
        solutionApplied: solutionApplied ?? this.solutionApplied,
        resolutionNotes: resolutionNotes ?? this.resolutionNotes,
        escalationReason: escalationReason ?? this.escalationReason,
        resolvedAt: resolvedAt ?? this.resolvedAt,
        assignedTo: assignedTo ?? this.assignedTo,
        assignedToName: assignedToName ?? this.assignedToName,
        adsbNotifiedAt: adsbNotifiedAt,
        callStartedAt: callStartedAt,
        callEndedAt: callEndedAt,
        remoteFixAt: remoteFixAt,
        verifiedAt: verifiedAt,
        ttNotifiedAt: ttNotifiedAt,
        ttSolutionProvidedAt: ttSolutionProvidedAt,
        adsbPickupAt: adsbPickupAt,
        dispatchAt: dispatchAt,
        arrivedAt: arrivedAt,
        workStartedAt: workStartedAt,
        workCompletedAt: workCompletedAt,
        evidenceUploadedAt: evidenceUploadedAt,
        clientConfirmedAt: clientConfirmedAt,
        reopenedAt: reopenedAt,
        autoClosedAt: autoClosedAt,
        noShowAt: noShowAt,
        escalatedAt: escalatedAt,
      );

  // ─── Display helpers ───
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

  String get laneDirectionDisplay {
    switch (laneDirection) {
      case 'exit':
        return 'Exit';
      case 'both':
        return 'Entry + Exit';
      case 'entry':
      default:
        return 'Entry';
    }
  }

  String get fullLocationDisplay {
    if (laneName.isEmpty) return siteName;
    return '$siteName → $laneName ($laneDirectionDisplay)';
  }

  // ─── Duration Helpers ───
  Duration? get totalResolutionTime {
    final end = resolvedAt ?? autoClosedAt ?? clientConfirmedAt;
    if (end == null) return null;
    return end.difference(createdAt);
  }

  Duration? get onsiteWorkDuration {
    if (adsbPickupAt == null || workCompletedAt == null) return null;
    return workCompletedAt!.difference(adsbPickupAt!);
  }

  static String formatDuration(Duration? d) {
    if (d == null) return '—';
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}