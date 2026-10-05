import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../services/ticket_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _service = TicketService();
  List<Ticket> _tickets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _service.getAllTickets();
    if (!mounted) return;
    setState(() {
      _tickets = list;
      _isLoading = false;
    });
  }

  // ═══════════════ ANALYTICS CALCULATIONS ═══════════════

  // 1. Total counts by status
  Map<String, int> get _statusCounts {
    final map = <String, int>{};
    for (final t in _tickets) {
      map[t.status] = (map[t.status] ?? 0) + 1;
    }
    return map;
  }

  // 2. Count by product type
  Map<String, int> get _productCounts {
    final map = <String, int>{};
    for (final t in _tickets) {
      map[t.productType] = (map[t.productType] ?? 0) + 1;
    }
    // Sort by count descending
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  // 3. Count by product issue
  Map<String, int> get _issueCounts {
    final map = <String, int>{};
    for (final t in _tickets) {
      map[t.productIssue] = (map[t.productIssue] ?? 0) + 1;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  // 4. Count by site
  Map<String, int> get _siteCounts {
    final map = <String, int>{};
    for (final t in _tickets) {
      map[t.siteName] = (map[t.siteName] ?? 0) + 1;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  // 5. Average resolution time (for resolved tickets)
  Duration? get _avgResolutionTime {
    final resolved = _tickets
        .where((t) => t.resolvedAt != null)
        .toList();
    if (resolved.isEmpty) return null;

    int totalSeconds = 0;
    for (final t in resolved) {
      totalSeconds += t.resolvedAt!.difference(t.createdAt).inSeconds;
    }
    return Duration(seconds: totalSeconds ~/ resolved.length);
  }

  // 6. Tickets per day (last 7 days)
  Map<String, int> get _last7Days {
    final now = DateTime.now();
    final map = <String, int>{};

    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final key = DateFormat('EEE dd').format(day);
      map[key] = 0;
    }

    for (final t in _tickets) {
      final diff = now.difference(t.createdAt).inDays;
      if (diff >= 0 && diff <= 6) {
        final day = DateTime(now.year, now.month, now.day - diff);
        final key = DateFormat('EEE dd').format(day);
        map[key] = (map[key] ?? 0) + 1;
      }
    }
    return map;
  }

  // 7. Resolution rate
  double get _resolutionRate {
    if (_tickets.isEmpty) return 0;
    final resolved = _tickets
        .where((t) => t.status == 'resolved' || t.status == 'closed')
        .length;
    return (resolved / _tickets.length) * 100;
  }

  // 8. Common root causes (from resolved tickets)
  Map<String, int> get _rootCauseCounts {
    final map = <String, int>{};
    for (final t in _tickets) {
      if (t.rootCause != null && t.rootCause!.isNotEmpty) {
        map[t.rootCause!] = (map[t.rootCause!] ?? 0) + 1;
      }
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  // ═══════════════ UI ═══════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Reporting'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
          ? _emptyState()
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _kpiSection(),
            const SizedBox(height: 24),
            _resolutionRateCard(),
            const SizedBox(height: 24),
            _avgResolutionCard(),
            const SizedBox(height: 24),
            _statusBreakdownCard(),
            const SizedBox(height: 24),
            _barChartCard(
              'Top Product Issues',
              _issueCounts,
              AppColors.primary,
            ),
            const SizedBox(height: 24),
            _barChartCard(
              'Issues by Product Type',
              _productCounts,
              AppColors.accent,
            ),
            const SizedBox(height: 24),
            _barChartCard(
              'Issues by Site',
              _siteCounts,
              AppColors.warning,
            ),
            const SizedBox(height: 24),
            _trendCard(),
            if (_rootCauseCounts.isNotEmpty) ...[
              const SizedBox(height: 24),
              _barChartCard(
                'Common Root Causes',
                _rootCauseCounts,
                AppColors.success,
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.analytics_outlined,
                size: 72, color: AppColors.textSecondary),
            SizedBox(height: 20),
            Text(
              'No data yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Create some tickets to see analytics',
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // KPI row
  Widget _kpiSection() {
    final total = _tickets.length;
    final open = _tickets
        .where((t) =>
    t.status == 'pending' ||
        t.status == 'verified' ||
        t.status == 'in_progress')
        .length;
    final resolved = _tickets
        .where((t) => t.status == 'resolved' || t.status == 'closed')
        .length;

    return Row(
      children: [
        Expanded(
            child: _kpi('Total', '$total', Icons.list_alt_outlined,
                AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(
            child: _kpi('Open', '$open', Icons.pending_outlined,
                AppColors.warning)),
        const SizedBox(width: 10),
        Expanded(
            child: _kpi('Resolved', '$resolved',
                Icons.check_circle_outline, AppColors.success)),
      ],
    );
  }

  Widget _kpi(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _resolutionRateCard() {
    final rate = _resolutionRate;
    return _card(
      title: 'Resolution Rate',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${rate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'of all tickets resolved or closed',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: rate / 100,
                  strokeWidth: 8,
                  backgroundColor: AppColors.divider,
                  valueColor: const AlwaysStoppedAnimation(
                      AppColors.success),
                ),
                Text(
                  '${rate.toInt()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avgResolutionCard() {
    final avg = _avgResolutionTime;
    return _card(
      title: 'Average Resolution Time',
      child: Row(
        children: [
          const Icon(Icons.timer_outlined,
              size: 40, color: AppColors.accent),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  avg == null ? '—' : _formatDuration(avg),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'from ticket created to resolved',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  Widget _statusBreakdownCard() {
    final counts = _statusCounts;
    if (counts.isEmpty) return const SizedBox();

    return _card(
      title: 'Status Breakdown',
      child: Column(
        children: counts.entries.map((e) {
          final percentage = (e.value / _tickets.length) * 100;
          final color = _statusColor(e.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _statusLabel(e.key),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '${e.value} (${percentage.toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: 8,
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _barChartCard(
      String title, Map<String, int> data, Color color) {
    if (data.isEmpty) return const SizedBox();

    final maxValue = data.values.reduce((a, b) => a > b ? a : b);
    final total = data.values.reduce((a, b) => a + b);

    return _card(
      title: title,
      child: Column(
        children: data.entries.take(8).map((e) {
          final percentage = (e.value / maxValue) * 100;
          final overall = (e.value / total) * 100;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${e.value} (${overall.toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: 8,
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _trendCard() {
    final data = _last7Days;
    final maxValue =
    data.values.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) return const SizedBox();

    return _card(
      title: 'Last 7 Days (Tickets Created)',
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: data.entries.map((e) {
            final height = (e.value / maxValue) * 100;
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${e.value}',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: height.clamp(4.0, 100.0),
                    decoration: BoxDecoration(
                      color: e.value == 0
                          ? AppColors.divider
                          : AppColors.primary,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    e.key,
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Helpers
  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Pending';
      case 'verified':
        return 'Verified';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      case 'reopened':
        return 'Reopened';
      case 'cancelled':
        return 'Cancelled';
      default:
        return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return AppColors.warning;
      case 'verified':
        return AppColors.accent;
      case 'in_progress':
        return AppColors.primary;
      case 'resolved':
        return AppColors.success;
      case 'closed':
        return AppColors.textSecondary;
      case 'reopened':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}