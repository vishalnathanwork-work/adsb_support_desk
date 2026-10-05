class SiteLocation {
  final String id;
  final String name;
  final String address;

  SiteLocation({required this.id, required this.name, required this.address});
}

class Presets {
  // Mock site locations (in real app, these come from backend)
  static const List<Map<String, String>> sites = [
    {'id': 'SITE-001', 'name': 'Parken HQ', 'address': 'Melaka, Malaysia'},
    {'id': 'SITE-002', 'name': 'Parken Branch A', 'address': 'Ayer Keroh, Melaka'},
    {'id': 'SITE-003', 'name': 'Parken Branch B', 'address': 'Jasin, Melaka'},
  ];

  // Product types
  static const List<String> productTypes = [
    'Parken LPR',
    'Parken Barrier',
    'Parken Payment Terminal',
    'Parken Intercom',
    'Parken CCTV',
    'Parken Communication Cabling',
    'Parken Loop Sensitivity',
    'Parken Cloud Reporting',
    'Parken Server PC',
    'Parken Other',
  ];

  // Product issues per product type (simplified — same list for now)
  static const List<String> productIssues = [
    'Gate not opening',
    'Gate not closing',
    'Barrier stuck',
    'Ticket not printing',
    'Payment not accepted',
    'Screen not working',
    'Sensor not detecting',
    'Power failure',
    'Network disconnected',
    'Other (please describe)',
  ];
}