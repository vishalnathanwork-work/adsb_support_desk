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

  /// Selected lanes for this ticket.
  /// Each entry is a Map with keys: id, name, type, zone_id, zone_name.
  /// Example: [
  ///   {id: 'l1', name: 'Entry 1', type: 'entry',
  ///    zone_id: 'z1', zone_name: 'P1'},
  ///   {id: 'l2', name: 'Exit 2', type: 'exit',
  ///    zone_id: 'z1', zone_name: 'P1'}
  /// ]
  final List<Map<String, String>> lanes;

  final String productType;
  final String productIssue;
  final String contactName;
  final String contactPhone;
  final String description;

  // ─── Images ───
  final List<String> imageUrls;
  final String? completionImageUrl;

  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? rootCause;
  final String? solutionApplied;
  final String? resolutionNotes;
  final DateTime? resolvedAt;
  final String? assignedTo;
  final String? assignedToName;

  // ─── Escalation / TT fields ───
  final String? escalationReason;
  final String? ttAdvisorEmail;
  final String? ttAdvisorName;
  final DateTime? ttReviewStartedAt;

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
  final DateTime? cancelledAt;

  final Map<String, dynamic>? lastAdminAction;

  Ticket({
    required this.id,
    required this.createdBy,
    required this.createdByName,
    required this.createdByRole,
    required this.siteId,
    required this.siteName,
    required this.siteLocation,
    required this.lanes,
    required this.productType,
    required this.productIssue,
    required this.contactName,
    required this.contactPhone,
    required this.description,
    required this.imageUrls,
    this.completionImageUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.rootCause,
    this.solutionApplied,
    this.resolutionNotes,
    this.resolvedAt,
    this.assignedTo,
    this.assignedToName,
    this.escalationReason,
    this.ttAdvisorEmail,
    this.ttAdvisorName,
    this.ttReviewStartedAt,
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
    this.cancelledAt,
    this.lastAdminAction,

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

  static List<Map<String, String>> _parseLanes(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];

    final result = <Map<String, String>>[];
    for (final item in value) {
      if (item is Map) {
        result.add({
          'id': item['id']?.toString() ?? '',
          'name': item['name']?.toString() ?? '',
          'type': item['type']?.toString() ?? 'entry',
          'zone_id': item['zone_id']?.toString() ?? '',
          'zone_name': item['zone_name']?.toString() ?? '',
        });
      }
    }
    return result;
  }

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
    id: json['ticket_id'] ?? json['id'] ?? '',
    createdBy: json['created_by'] ?? '',
    createdByName: json['created_by_name'] ?? '',
    createdByRole: json['created_by_role'] ?? 'client',

    siteId: json['site_id'] ?? '',
    siteName: json['site_name'] ?? '',
    siteLocation: json['site_location'] ?? '',

    lanes: _parseLanes(json['lanes']),

    productType: json['product_type'] ?? '',
    productIssue: json['product_issue'] ?? '',
    contactName: json['contact_name'] ?? '',
    contactPhone: json['contact_phone'] ?? '',
    description: json['description'] ?? '',

    imageUrls: _stringList(json['image_urls']),
    completionImageUrl: json['completion_image_url'],

    status: json['status'] ?? 'pending',
    createdAt: _ts(json['created_at']) ?? DateTime.now(),
    updatedAt: _ts(json['updated_at']) ?? DateTime.now(),
    assignedTo: json['assigned_to'],
    assignedToName: json['assigned_to_name'],
    rootCause: json['root_cause'],
    solutionApplied: json['solution_applied'],
    resolutionNotes: json['resolution_notes'],
    resolvedAt: _ts(json['resolved_at']),

    escalationReason: json['escalation_reason'],
    ttAdvisorEmail: json['tt_advisor_email'],
    ttAdvisorName: json['tt_advisor_name'],
    ttReviewStartedAt: _ts(json['tt_review_started_at']),

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
    cancelledAt: _ts(json['cancelled_at']),
    lastAdminAction: json['last_admin_action'] is Map
        ? Map<String, dynamic>.from(json['last_admin_action'] as Map)
        : null,

  );

  Ticket copyWith({
    String? status,
    String? rootCause,
    String? solutionApplied,
    String? resolutionNotes,
    String? assignedTo,
    String? assignedToName,
    String? escalationReason,
    String? ttAdvisorEmail,
    String? ttAdvisorName,
    DateTime? ttReviewStartedAt,
    DateTime? resolvedAt,
    DateTime? updatedAt,
    List<String>? imageUrls,
    String? completionImageUrl,
  }) =>
      Ticket(
        id: id,
        createdBy: createdBy,
        createdByName: createdByName,
        createdByRole: createdByRole,
        siteId: siteId,
        siteName: siteName,
        siteLocation: siteLocation,
        lanes: lanes,
        productType: productType,
        productIssue: productIssue,
        contactName: contactName,
        contactPhone: contactPhone,
        description: description,
        imageUrls: imageUrls ?? this.imageUrls,
        completionImageUrl:
        completionImageUrl ?? this.completionImageUrl,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        rootCause: rootCause ?? this.rootCause,
        solutionApplied: solutionApplied ?? this.solutionApplied,
        resolutionNotes: resolutionNotes ?? this.resolutionNotes,
        resolvedAt: resolvedAt ?? this.resolvedAt,
        assignedTo: assignedTo ?? this.assignedTo,
        assignedToName: assignedToName ?? this.assignedToName,
        escalationReason: escalationReason ?? this.escalationReason,
        ttAdvisorEmail: ttAdvisorEmail ?? this.ttAdvisorEmail,
        ttAdvisorName: ttAdvisorName ?? this.ttAdvisorName,
        ttReviewStartedAt: ttReviewStartedAt ?? this.ttReviewStartedAt,
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
        cancelledAt: cancelledAt,
        lastAdminAction: lastAdminAction ?? this.lastAdminAction,
      );

  // ─── Display helpers ───

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending Verification';
      case 'verified':
        return 'In Review with ADSB Support';
      case 'pending_onsite':
        return 'On-Site Visit Queued';
      case 'in_progress':
        return 'On-Site Work In Progress';
      case 'resolved':
        return 'Resolved — Awaiting Your Confirmation';
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
          status == 'pending_onsite' ||
          status == 'in_progress' ||
          status == 'resolved' ||
          status == 'reopened';
  bool get isResolved => status == 'resolved' || status == 'closed';

  bool get isUnassigned => assignedTo == null && status == 'pending';
  bool get isBeingVerified => assignedTo != null && status == 'pending';

  /// Primary or summary lane name.
  String get laneName => lanesSummary;

  /// Map of zoneName -> List of lane maps in that zone.
  Map<String, List<Map<String, String>>> get lanesByZone {
    final map = <String, List<Map<String, String>>>{};
    for (final lane in lanes) {
      final zoneName = (lane['zone_name']?.isNotEmpty == true)
          ? lane['zone_name']!
          : (lane['zone']?.isNotEmpty == true)
              ? lane['zone']!
              : 'General';
      map.putIfAbsent(zoneName, () => []).add(lane);
    }
    return map;
  }

  /// Display string for lane direction/type ("ENTRY", "EXIT", or "ENTRY / EXIT").
  String get laneDirectionDisplay {
    if (lanes.isEmpty) return '—';
    final types = lanes
        .map((l) => (l['type'] ?? '').toUpperCase())
        .where((t) => t.isNotEmpty)
        .toSet();
    if (types.isEmpty) return '—';
    return types.join(' / ');
  }

  /// Comma-separated with zone: "P1 → Entry 1, P1 → Exit 2"
  String get lanesSummary {
    if (lanes.isEmpty) return '—';
    return lanes.map((l) {
      final zone = l['zone_name'] ?? '';
      final name = l['name'] ?? '';
      return zone.isEmpty ? name : '$zone → $name';
    }).join(', ');
  }

  /// Full location display: site + lanes
  String get fullLocationDisplay {
    if (lanes.isEmpty) return siteName;
    return '$siteName → $lanesSummary';
  }

  /// Label used in ticket details.
  String get createdByRoleLabel {
    switch (createdByRole) {
      case 'client':
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
        return createdByRole;
    }
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