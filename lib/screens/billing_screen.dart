import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/tab_visibility.dart';
import '../services/payment_data.dart';
import '../services/payment_service.dart';
import '../services/attendance_service.dart';
import '../services/earnings_pdf_service.dart';
import '../services/current_user.dart';

/// This screen was built with its own self-contained slate palette instead
/// of the shared AppColors/AppTheme. Rather than rewiring every literal to
/// the app-wide tokens, it gets a light/dark pair of its own so the same
/// visual design survives dark mode instead of staying hardcoded white.
class _BillingColors {
  final Color scaffoldBg;
  final Color card;
  final Color border;
  final Color heading;
  final Color label;
  final Color secondary;
  final Color muted;
  final Color placeholder;
  final Color subtleBg;
  final Color tableDivider;

  const _BillingColors({
    required this.scaffoldBg,
    required this.card,
    required this.border,
    required this.heading,
    required this.label,
    required this.secondary,
    required this.muted,
    required this.placeholder,
    required this.subtleBg,
    required this.tableDivider,
  });

  static const light = _BillingColors(
    scaffoldBg: Color(0xFFF8F9FA),
    card: Colors.white,
    border: Color(0xFFE2E8F0),
    heading: Color(0xFF1E293B),
    label: Color(0xFF334155),
    secondary: Color(0xFF475569),
    muted: Color(0xFF64748B),
    placeholder: Color(0xFF94A3B8),
    subtleBg: Color(0xFFF8FAFC),
    tableDivider: Color(0xFFF1F5F9),
  );

  static const dark = _BillingColors(
    scaffoldBg: Color(0xFF121417),
    card: Color(0xFF1E2126),
    border: Color(0xFF2C3038),
    heading: Color(0xFFE9EAEE),
    label: Color(0xFFD1D5DB),
    secondary: Color(0xFFB0B6C0),
    muted: Color(0xFF9CA3AF),
    placeholder: Color(0xFF7B8290),
    subtleBg: Color(0xFF23262D),
    tableDivider: Color(0xFF2C3038),
  );

  static _BillingColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen>
    with PollingScreenMixin<BillingScreen> {
  bool _isSendingEmail = false;

  static const Map<String, List<Color>> _paymentStatusColors = {
    'Paid': [Color(0xFFDCFCE7), Color(0xFF16A34A)],
    'Pending': [Color(0xFFFEF3C7), Color(0xFFD97706)],
    'Failed': [Color(0xFFFEE2E2), Color(0xFFDC2626)],
  };

  static const Map<String, List<Color>> _walkInStatusColors = {
    'Paid': [Color(0xFFDCFCE7), Color(0xFF16A34A)],
    'Pending': [Color(0xFFFEF3C7), Color(0xFFD97706)],
    'Failed': [Color(0xFFFEE2E2), Color(0xFFDC2626)],
  };

  bool _loadingPayments = true;
  bool _loadingWalkIns = true;
  List<Map<String, dynamic>> _walkIns = [];

  @override
  void initState() {
    super.initState();
    PaymentData.instance.addListener(_onDataChanged);
  }

  // Polling runs only while Billing is the visible tab.
  @override
  Duration get pollInterval => const Duration(seconds: 20);

  @override
  void onInitialLoad() {
    _loadMembershipPayments();
    _loadWalkIns();
  }

  @override
  void onPoll() {
    _loadMembershipPayments(silent: true);
    _loadWalkIns(silent: true);
  }

  Future<void> _loadMembershipPayments({bool silent = false}) async {
    if (!silent) {
      setState(() => _loadingPayments = true);
    }
    await PaymentService.getMembershipPayments();
    if (mounted) {
      setState(() => _loadingPayments = false);
    }
  }

  Future<void> _loadWalkIns({bool silent = false}) async {
    if (!silent) {
      setState(() => _loadingWalkIns = true);
    }
    final data = await AttendanceService.getWalkIns();
    if (mounted) {
      setState(() {
        _walkIns = data;
        _loadingWalkIns = false;
      });
    }
  }

  @override
  void dispose() {
    PaymentData.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  // ---------- Date/amount parsing helpers ----------

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  int _parseAmount(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) return raw.round();
    final cleaned = raw.toString().replaceAll(RegExp(r'[₱,]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  bool _isPaid(dynamic status) => (status ?? '').toString() == 'Paid';

  DateTime _startOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - DateTime.monday;
    final monday = date.subtract(Duration(days: daysFromMonday));
    return DateTime(monday.year, monday.month, monday.day);
  }

  DateTime _endOfWeek(DateTime date) {
    final start = _startOfWeek(date);
    return start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  }

  // ---------- Revenue calculations ----------

  int _calculateRevenueInRange(DateTime start, DateTime end) {
    int total = 0;

    for (final item in PaymentData.instance.payments) {
      if (!_isPaid(item['status'])) continue;
      final date = _parseDate(item['date']?.toString());
      if (date == null || date.isBefore(start) || date.isAfter(end)) continue;
      total += _parseAmount(item['amount']);
    }

    for (final w in _walkIns) {
      if (!_isPaid(w['status'])) continue;
      final date = _parseDate(w['date']?.toString());
      if (date == null || date.isBefore(start) || date.isAfter(end)) continue;
      total += _parseAmount(w['amount']);
    }

    return total;
  }

  int _calculateWeekRevenue() {
    final now = DateTime.now();
    return _calculateRevenueInRange(_startOfWeek(now), _endOfWeek(now));
  }

  int _calculateMonthRevenue() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1));
    return _calculateRevenueInRange(start, end);
  }

  int _countMembershipByStatus(String status) {
    return PaymentData.instance.countByStatus(status);
  }

  int _countWalkInByStatus(String status) {
    return _walkIns.where((w) => w['status'] == status).length;
  }

  int _countPendingPayments() => _countMembershipByStatus('Pending') + _countWalkInByStatus('Pending');
  int _countFailedPayments() => _countMembershipByStatus('Failed') + _countWalkInByStatus('Failed');

  String _formatCurrency(int amount) {
    return '₱${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  // ---------- EXPORT / SEND EARNINGS STATEMENT ----------

  Future<void> _exportEarningsStatement() async {
    final now = DateTime.now();
    final dateStr = '${now.month}/${now.day}/${now.year}';

    final paidMembership =
        PaymentData.instance.payments.where((p) => _isPaid(p['status'])).toList();
    final paidWalkIns = _walkIns.where((w) => _isPaid(w['status'])).toList();

    int membershipTotal = 0;
    final membershipRows = paidMembership.map((p) {
      final amt = _parseAmount(p['amount']);
      membershipTotal += amt;
      return [
        (p['member'] ?? '').toString(),
        (p['plan'] ?? '').toString(),
        _formatCurrency(amt),
        (p['method'] ?? '').toString(),
        (p['date'] ?? '').toString(),
      ];
    }).toList();

    int walkInTotal = 0;
    final walkInRows = paidWalkIns.map((w) {
      final amt = _parseAmount(w['amount']);
      walkInTotal += amt;
      return [
        (w['name'] ?? '').toString(),
        _formatCurrency(amt),
        (w['method'] ?? '').toString(),
        (w['date'] ?? '').toString(),
      ];
    }).toList();

    final grandTotal = membershipTotal + walkInTotal;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Export Earnings Statement',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.print_outlined, color: Color(0xFF00B4D8)),
              title: const Text('Print Statement'),
              onTap: () {
                Navigator.pop(ctx);
                EarningsPdfService.printStatement(
                  generatedDate: dateStr,
                  membershipRows: membershipRows,
                  membershipTotal: _formatCurrency(membershipTotal),
                  walkInRows: walkInRows,
                  walkInTotal: _formatCurrency(walkInTotal),
                  grandTotal: _formatCurrency(grandTotal),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline, color: Color(0xFF00B4D8)),
              title: const Text('Send Earnings Statement to Email'),
              subtitle: const Text('Awtomatikong ipapadala ang PDF sa email'),
              onTap: () async {
                Navigator.pop(ctx);
                await _sendEarningsEmail(
                  dateStr: dateStr,
                  membershipRows: membershipRows,
                  membershipTotal: membershipTotal,
                  walkInRows: walkInRows,
                  walkInTotal: walkInTotal,
                  grandTotal: grandTotal,
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _sendEarningsEmail({
    required String dateStr,
    required List<List<String>> membershipRows,
    required int membershipTotal,
    required List<List<String>> walkInRows,
    required int walkInTotal,
    required int grandTotal,
  }) async {
    if (_isSendingEmail) return;

    setState(() => _isSendingEmail = true);

    // Loading dialog habang nagse-send
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success = await EarningsPdfService.sendEarningsEmail(
      generatedDate: dateStr,
      membershipRows: membershipRows,
      membershipTotal: _formatCurrency(membershipTotal),
      walkInRows: walkInRows,
      walkInTotal: _formatCurrency(walkInTotal),
      grandTotal: _formatCurrency(grandTotal),
    );

    if (!mounted) return;
    Navigator.pop(context); // isara ang loading dialog
    setState(() => _isSendingEmail = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Earnings statement successfully sent!'
              : 'Failed to send email. Please check your internet connection or sender credentials.',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _BillingColors.of(context);
    return Scaffold(
      backgroundColor: c.scaffoldBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Billing & Payments', style: AppTheme.pageTitle(context)),
                    const SizedBox(height: 6),
                    Text(
                      'Manage membership plans and track payments',
                      style: AppTheme.pageSubtitle(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.section),

            Row(
              children: [
                _buildSummaryCard(
                  title: "This Week's Revenue",
                  value: _formatCurrency(_calculateWeekRevenue()),
                  icon: Icons.calendar_view_week,
                  iconBg: const Color(0xFFE0F7FA),
                  iconColor: const Color(0xFF00B4D8),
                  accent: AppColors.cyan,
                ),
                const SizedBox(width: 16),
                _buildSummaryCard(
                  title: "This Month's Revenue",
                  value: _formatCurrency(_calculateMonthRevenue()),
                  icon: Icons.calendar_month,
                  iconBg: const Color(0xFFEDE9FE),
                  iconColor: const Color(0xFF7C3AED),
                  accent: AppColors.gold,
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                _buildSummaryCard(
                  title: 'Pending Payments',
                  value: _countPendingPayments().toString(),
                  icon: Icons.credit_card,
                  iconBg: const Color(0xFFFFF9C4),
                  iconColor: const Color(0xFFFBC02D),
                  accent: AppColors.warning,
                ),
                const SizedBox(width: 16),
                _buildSummaryCard(
                  title: 'Failed Payments',
                  value: _countFailedPayments().toString(),
                  icon: Icons.warning_amber_rounded,
                  iconBg: const Color(0xFFFFEBEE),
                  iconColor: const Color(0xFFE53935),
                  accent: AppColors.danger,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.section),

            Text(
              'Membership Plans',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: c.heading),
            ),
            const SizedBox(height: 12),
            _buildMembershipPlanCards(),
            const SizedBox(height: AppSpacing.section),

            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  'Membership Plan Payments',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: c.heading),
                ),
              ],
            ),
            if (CurrentUser.isOwner) const SizedBox(height: 8),
            if (CurrentUser.isOwner)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _isSendingEmail ? null : _exportEarningsStatement,
                  icon: const Icon(Icons.download, size: 16, color: Colors.white),
                  label: const Text('Export PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B4D8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: AppTheme.cardDecoration(context, accent: AppColors.cyan),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: c.tableDivider),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(c.subtleBg),
                  columns: [
                    DataColumn(label: Text('MEMBER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.muted))),
                    DataColumn(label: Text('PLAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.muted))),
                    DataColumn(label: Text('AMOUNT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.muted))),
                    DataColumn(label: Text('METHOD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.muted))),
                    DataColumn(label: Text('DATE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.muted))),
                    DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.muted))),
                  ],
                  rows: _loadingPayments
                      ? [
                          DataRow(cells: [
                            DataCell(Text('Loading...', style: TextStyle(color: c.placeholder))),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                          ]),
                        ]
                      : PaymentData.instance.payments.isEmpty
                          ? [
                              DataRow(cells: [
                                DataCell(Text('No membership payments yet', style: TextStyle(color: c.placeholder))),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                              ]),
                            ]
                          : PaymentData.instance.payments.asMap().entries.map((entry) {
                              final item = entry.value;
                              final colors = _paymentStatusColors[item['status']] ??
                                  [const Color(0xFFF1F1F3), const Color(0xFF64748B)];
                              return _buildPaymentRow(
                                item['member'] ?? '',
                                item['plan'] ?? '',
                                item['amount'] ?? '',
                                item['method'] ?? '',
                                item['date'] ?? '',
                                item['status'] ?? '',
                                colors[0],
                                colors[1],
                                entry.key,
                              );
                            }).toList(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.section),

            Text(
              'Walk-in Payments',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: c.heading),
            ),
            const SizedBox(height: 4),
            Text(
              'Payments from walk-in customers checked in via the Attendance page.',
              style: TextStyle(fontSize: 13, color: c.muted),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: AppTheme.cardDecoration(context, accent: AppColors.cyan),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: c.tableDivider),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(c.subtleBg),
                  columns: [
                    DataColumn(label: Text('NAME', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.muted))),
                    DataColumn(label: Text('AMOUNT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.muted))),
                    DataColumn(label: Text('METHOD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.muted))),
                    DataColumn(label: Text('DATE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.muted))),
                    DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.muted))),
                  ],
                  rows: _loadingWalkIns
                      ? [
                          DataRow(cells: [
                            DataCell(Text('Loading...', style: TextStyle(color: c.placeholder))),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                          ]),
                        ]
                      : _walkIns.isEmpty
                          ? [
                              DataRow(cells: [
                                DataCell(Text('No walk-in payments yet', style: TextStyle(color: c.placeholder))),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                              ]),
                            ]
                          : _walkIns.asMap().entries.map((entry) {
                              final w = entry.value;
                              final status = w['status'] ?? '';
                              final colors = _walkInStatusColors[status] ??
                                  [const Color(0xFFF1F1F3), const Color(0xFF64748B)];
                              final zebra = AppTheme.zebraRow(context, entry.key);
                              return DataRow(
                                color: zebra == null ? null : WidgetStateProperty.all(zebra),
                                cells: [
                                DataCell(Text(w['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: c.heading))),
                                DataCell(Text('₱${((w['amount'] ?? 0) as num).toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w600, color: c.heading))),
                                DataCell(Text(w['method'] ?? '', style: TextStyle(color: c.secondary))),
                                DataCell(Text(w['date'] ?? '', style: TextStyle(color: c.secondary))),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: colors[0], borderRadius: BorderRadius.circular(12)),
                                  child: Text(status, style: TextStyle(color: colors[1], fontWeight: FontWeight.bold, fontSize: 11)),
                                )),
                              ]);
                            }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    Color? accent,
  }) {
    final c = _BillingColors.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.cardDecoration(context, accent: accent),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: c.muted, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c.heading),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _countPlanMembers(String planName) {
    return PaymentData.instance.countByPlan(planName);
  }

  static const _planDefinitions = [
    PlanDefinition('4 months', '₱2400', Color(0xFFEFF6FF), Color(0xFF2563EB)),
    PlanDefinition('5 months', '₱2800', Color(0xFFE0F2FE), Color(0xFF0284C7)),
    PlanDefinition('7 months', '₱3500', Color(0xFFF3E8FF), Color(0xFF7C3AED)),
    PlanDefinition('1 year', '₱4800', Color(0xFFFDF2FD), Color(0xFFBE12B8)),
  ];

  Widget _buildMembershipPlanCards() {
    final children = <Widget>[];
    for (int i = 0; i < _planDefinitions.length; i++) {
      final plan = _planDefinitions[i];
      final count = _countPlanMembers(plan.name);
      children.add(_buildPlanCard(plan.name, plan.price, '$count active members', plan.chipBg, plan.chipText));
      if (i < _planDefinitions.length - 1) {
        children.add(const SizedBox(width: 16));
      }
    }
    return Row(children: children);
  }

  Widget _buildPlanCard(String name, String price, String sub, Color chipBg, Color chipText) {
    final c = _BillingColors.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.cardDecoration(context, accent: AppColors.cyan),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(12)),
                  child: Text(name, style: TextStyle(color: chipText, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                Text(price, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.heading)),
              ],
            ),
            const SizedBox(height: 16),
            Text(sub, style: TextStyle(color: c.muted, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  DataRow _buildPaymentRow(String member, String plan, String amount, String method, String date, String status, Color statusBg, Color statusText, [int index = 0]) {
    final c = _BillingColors.of(context);
    final zebra = AppTheme.zebraRow(context, index);
    return DataRow(
      color: zebra == null ? null : WidgetStateProperty.all(zebra),
      cells: [
      DataCell(Text(member, style: TextStyle(fontWeight: FontWeight.w600, color: c.heading))),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: c.subtleBg, borderRadius: BorderRadius.circular(6)),
        child: Text(plan, style: TextStyle(fontSize: 12, color: c.label)),
      )),
      DataCell(Text(amount, style: TextStyle(fontWeight: FontWeight.w600, color: c.heading))),
      DataCell(Text(method, style: TextStyle(color: c.secondary))),
      DataCell(Text(date, style: TextStyle(color: c.secondary))),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
        child: Text(status, style: TextStyle(color: statusText, fontWeight: FontWeight.bold, fontSize: 11)),
      )),
    ]);
  }
}

class PlanDefinition {
  final String name;
  final String price;
  final Color chipBg;
  final Color chipText;
  const PlanDefinition(this.name, this.price, this.chipBg, this.chipText);
}
