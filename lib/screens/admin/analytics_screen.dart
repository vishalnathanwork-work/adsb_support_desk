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
    setState(() => _isLoading = true);
    final list = await _service.getAllTickets();
    if (!mounted) return;
    setState(() {
      _tickets = list;
      _isLoading = false;
    });
  }

  // ═══════════════════════════════════════════════
  // COMPUTED METRICS
  // ═══════════════════════════════════════════════

  int get totalTickets => _tickets.length;

  int get openTickets => _tickets
      .where((t) =>
  t.status == 'pending' ||
      t.status == 'verified' ||
      t.status == 'in_progress' ||
      t.status == 'reopened')
      .length;

  int get resolvedTickets => _tickets
      .where((t) => t.status == 'resolved' || t.status == 'closed')
      .length;

  double get resolutionRate =>
      totalTickets == 0 ? 0 : (resolvedTickets / totalTickets) * 100;

  Duration? get avgResolutionTime {
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

  Map<String, int> get statusCounts {
    final map = <String, int>{};
    for (final t in _tickets) {
      map[t.status] = (map[t.status] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get productIssueCounts {
    final map = <String, int>{};
    for (final t in _tickets) {
      map[t.productIssue] = (map[t.productIssue] ?? 0) + 1;
    }
    final sorted = _sortDescending(map);
    final top5 = sorted.entries.take(5);
    return Map.fromEntries(top5);
  }

  Map<String, int> get productTypeCounts {
    final map = <String, int>{};
    for (final t in _tickets) {
      map[t.productType] = (map[t.productType] ?? 0) + 1;
    }
    return _sortDescending(map);
  }

  Map<String, int> get siteCounts {
    final map = <String, int>{};
    for (final t in _tickets) {
      map[t.siteName] = (map[t.siteName] ?? 0) + 1;
    }
    return _sortDescending(map);
  }

  Map<String, int> get rootCauseCounts {
    final map = <String, int>{};
    for (final t in _tickets) {
      if (t.rootCause != null && t.rootCause!.isNotEmpty) {
        map[t.rootCause!] = (map[t.rootCause!] ?? 0) + 1;
      }
    }
    return _sortDescending(map);
  }

  Map<String, int> get last7Days {
    final now = DateTime.now();
    final map = <String, int>{};
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      map[DateFormat('EEE').format(day)] = 0;
    }
    for (final t in _tickets) {
      final diff = now.difference(t.createdAt).inDays;
      if (diff >= 0 && diff <= 6) {
        final day = DateTime(now.year, now.month, now.day - diff);
        final key = DateFormat('EEE').format(day);
        map[key] = (map[key] ?? 0) + 1;
      }
    }
    return map;
  }

  Map<String, int> _sortDescending(Map<String, int> input) {
    final sorted = input.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  // ═══════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════

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
            _kpiRow(),
            const SizedBox(height: 16),
            _resolutionRateCard(),
            const SizedBox(height: 16),
            _avgTimeCard(),
            const SizedBox(height: 16),
            _statusBreakdownCard(),
            const SizedBox(height: 16),
            if (productIssueCounts.isNotEmpty)
              _barChartCard(
                'Top Product Issues',
                productIssueCounts,
                AppColors.warning,
              ),
            const SizedBox(height: 16),
            if (productTypeCounts.isNotEmpty)
              _barChartCard(
                'Issues by Product Type',
                productTypeCounts,
                AppColors.primary,
              ),
            const SizedBox(height: 16),
            if (siteCounts.isNotEmpty)
              _barChartCard(
                'Issues by Site',
                siteCounts,
                AppColors.accent,
              ),
            const SizedBox(height: 16),
            _trendCard(),
            if (rootCauseCounts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _barChartCard(
                'Common Root Causes',
                rootCauseCounts,
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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

  // ═══════════════════════════════════════════════
  // CARDS
  // ═══════════════════════════════════════════════

  Widget _kpiRow() {
    return Row(
      children: [
        Expanded(
            child: _kpi('Total', '$totalTickets', Icons.list_alt_outlined,
                AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(
            child: _kpi('Open', '$openTickets', Icons.pending_outlined,
                AppColors.warning)),
        const SizedBox(width: 10),
        Expanded(
            child: _kpi('Resolved', '$resolvedTickets',
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
    final rate = resolutionRate;
    return _card(
      title: 'Resolution Rate',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${rate.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success)),
                const SizedBox(height: 4),
                Text('$resolvedTickets of $totalTickets tickets resolved',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
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
                  valueColor:
                  const AlwaysStoppedAnimation(AppColors.success),
                ),
                Text('${rate.toInt()}%',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avgTimeCard() {
    final avg = avgResolutionTime;
    return _card(
      title: 'Average Resolution Time',
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 40, color: AppColors.accent),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(avg == null ? '—' : _formatDuration(avg),
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent)),
                const SizedBox(height: 4),
                const Text('from ticket created to resolved',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBreakdownCard() {
    final counts = statusCounts;
    if (counts.isEmpty) return const SizedBox();

    return _card(
      title: 'Status Breakdown',
      child: Column(
        children: counts.entries.map((e) {
          final pct = (e.value / totalTickets) * 100;
          final color = _statusColor(e.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(_statusLabel(e.key),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    Text('${e.value} (${pct.toStringAsFixed(0)}%)',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100,
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

  Widget _barChartCard(String title, Map<String, int> data, Color color) {
    if (data.isEmpty) return const SizedBox();

    final maxVal = data.values.reduce((a, b) => a > b ? a : b);
    final total = data.values.reduce((a, b) => a + b);

    return _card(
      title: title,
      child: Column(
        children: data.entries.take(8).map((e) {
          final barPct = (e.value / maxVal) * 100;
          final overallPct = (e.value / total) * 100;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(e.key,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Text('${e.value} (${overallPct.toStringAsFixed(0)}%)',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: barPct / 100,
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
    final data = last7Days;
    final maxVal =
    data.values.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);

    return _card(
      title: 'Last 7 Days (Tickets Created)',
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: data.entries.map((e) {
            final height = (e.value / maxVal) * 100;
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${e.value}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
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
                  Text(e.key,
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textSecondary)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

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
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
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