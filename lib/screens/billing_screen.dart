import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/tab_visibility.dart';
import '../services/payment_data.dart';
import '../services/payment_service.dart';
import '../services/attendance_service.dart';
import '../services/earnings_pdf_service.dart';
import '../services/current_user.dart';

/// Billing page.
///
/// UI updates (visual lang, walang binago sa functions/services):
///  - Membership payments at Walk-in payments ay hiwalay pa rin, ngayon
///    naka-tabs para hindi na kailangang mag-scroll sa pagitan ng dalawa
///  - Payments naka-group per BUWAN (current month expanded, older collapsed)
///  - Shared filter bar: month navigator, range chips, status chips,
///    plan chips (membership lang), search
enum _BillingTab { membership, walkIns }

enum _BillingRange { month, last3, all, custom }

/// Isang buwan ng payments (membership o walk-in, depende sa tab).
class _MonthGroup {
  final DateTime? month;
  final String key;
  final List<Map<String, dynamic>> items = [];
  _MonthGroup(this.month, this.key);
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen>
    with PollingScreenMixin<BillingScreen> {
  bool _isSendingEmail = false;

  static const Map<String, List<Color>> _paymentStatusColors = {
    'Paid': [AppColors.successBg, AppColors.success],
    'Pending': [AppColors.warningBg, AppColors.warning],
    'Failed': [AppColors.dangerBg, AppColors.danger],
  };

  static const Map<String, List<Color>> _walkInStatusColors = {
    'Paid': [AppColors.successBg, AppColors.success],
    'Pending': [AppColors.warningBg, AppColors.warning],
    'Failed': [AppColors.dangerBg, AppColors.danger],
  };

  bool _loadingPayments = true;
  bool _loadingWalkIns = true;
  List<Map<String, dynamic>> _walkIns = [];

  // ---- View state (presentation only) ----
  static const int _pageSize = 6;
  _BillingTab _tab = _BillingTab.membership;
  _BillingRange _range = _BillingRange.month;
  DateTime _anchorMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTimeRange? _customRange;
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _planFilter = 'All';
  int _visibleMonths = _pageSize;
  final Map<String, bool> _monthExpanded = {};

  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const List<String> _monthsFull = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

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

  // ---------- Presentation helpers (styling only, no logic) ----------

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  /// Dark solid button (cyan in dark mode), replaces the gold button.
  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _isDark ? AppColors.cyan : const Color(0xFF111827),
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  TextStyle get _sectionTitleStyle => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppTheme.heading(context),
      );

  TextStyle get _tableHeaderStyle => TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: AppTheme.textMuted(context),
        letterSpacing: 0.6,
      );

  /// White rounded card with hairline border + soft shadow. [accent] draws a
  /// thin colored bar on the left edge, reserved for cards needing attention.
  Widget _card({
    required Widget child,
    Color? accent,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: _isDark
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Stack(
        children: [
          SizedBox(width: double.infinity, child: Padding(padding: padding, child: child)),
          if (accent != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: accent),
            ),
        ],
      ),
    );
  }

  /// Plain bordered search box (no tinted fill).
  Widget _searchBox({required String hint, required ValueChanged<String> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: AppTheme.textMuted(context)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: AppTheme.textMuted(context), fontSize: 14),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Export Earnings Statement',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: AppTheme.heading(ctx),
                  )),
            ),
            ListTile(
              leading: Icon(Icons.print_outlined, color: AppTheme.heading(ctx)),
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
              leading: Icon(Icons.mail_outline, color: AppTheme.heading(ctx)),
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

  // ---------------------------------------------------------------------
  // View helpers: date range, filtering, grouping (display only)
  // ---------------------------------------------------------------------

  DateTime get _currentMonth => DateTime(DateTime.now().year, DateTime.now().month, 1);

  bool get _searching => _searchQuery.isNotEmpty;

  DateTime? get _rangeStart {
    switch (_range) {
      case _BillingRange.month:
        return DateTime(_anchorMonth.year, _anchorMonth.month, 1);
      case _BillingRange.last3:
        final n = DateTime.now();
        return DateTime(n.year, n.month - 2, 1);
      case _BillingRange.custom:
        final c = _customRange;
        return c == null ? null : _dateOnly(c.start);
      case _BillingRange.all:
        return null;
    }
  }

  DateTime? get _rangeEnd {
    switch (_range) {
      case _BillingRange.month:
        return DateTime(_anchorMonth.year, _anchorMonth.month + 1, 0);
      case _BillingRange.last3:
        final n = DateTime.now();
        return DateTime(n.year, n.month + 1, 0);
      case _BillingRange.custom:
        final c = _customRange;
        return c == null ? null : _dateOnly(c.end);
      case _BillingRange.all:
        return null;
    }
  }

  bool _inRange(DateTime? d) {
    // Search is global: tinitingnan ang lahat ng buwan.
    if (_searching || _range == _BillingRange.all) return true;
    final s = _rangeStart;
    final e = _rangeEnd;
    if (s == null || e == null) return true;
    if (d == null) return false;
    final day = _dateOnly(d);
    return !day.isBefore(s) && !day.isAfter(e);
  }

  String _monthDay(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  String get _rangeLabel {
    switch (_range) {
      case _BillingRange.month:
        return '${_monthsFull[_anchorMonth.month - 1]} ${_anchorMonth.year}';
      case _BillingRange.last3:
        final s = _rangeStart;
        final e = _rangeEnd;
        if (s == null || e == null) return 'Last 3 months';
        return '${_months[s.month - 1]} – ${_months[e.month - 1]} ${e.year}';
      case _BillingRange.custom:
        final s = _rangeStart;
        final e = _rangeEnd;
        if (s == null || e == null) return 'Pick a date range';
        return '${_monthDay(s)} – ${_monthDay(e)}, ${e.year}';
      case _BillingRange.all:
        return 'All dates';
    }
  }

  bool get _canNavigate => _range == _BillingRange.month;

  bool get _canGoNext => _anchorMonth.isBefore(_currentMonth);

  void _resetView() {
    _visibleMonths = _pageSize;
    _monthExpanded.clear();
  }

  void _setRange(_BillingRange r) {
    setState(() {
      _range = r;
      _anchorMonth = _currentMonth;
      _resetView();
    });
  }

  void _shiftMonth(int dir) {
    setState(() {
      _anchorMonth = DateTime(_anchorMonth.year, _anchorMonth.month + dir, 1);
      _resetView();
    });
  }

  Future<void> _pickMonth() async {
    if (_range == _BillingRange.custom) {
      await _pickCustomRange();
      return;
    }
    final today = _dateOnly(DateTime.now());
    final initial = _anchorMonth.isAfter(today) ? today : _anchorMonth;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _anchorMonth = DateTime(picked.year, picked.month, 1);
      _range = _BillingRange.month;
      _resetView();
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _dateOnly(DateTime.now()),
      initialDateRange: _customRange,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customRange = picked;
      _range = _BillingRange.custom;
      _resetView();
    });
  }

  List<Map<String, dynamic>> get _filteredMembershipPayments {
    final all = List<Map<String, dynamic>>.from(PaymentData.instance.payments);
    final q = _searchQuery.toLowerCase();
    return all.where((p) {
      final name = (p['member'] ?? '').toString().toLowerCase();
      final matchesSearch = q.isEmpty || name.contains(q);
      final matchesStatus = _statusFilter == 'All' || (p['status'] ?? '').toString() == _statusFilter;
      final matchesPlan = _planFilter == 'All' ||
          (p['plan'] ?? '').toString().toLowerCase() == _planFilter.toLowerCase();
      return matchesSearch && matchesStatus && matchesPlan;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredWalkInPayments {
    final q = _searchQuery.toLowerCase();
    return _walkIns.where((w) {
      final name = (w['name'] ?? '').toString().toLowerCase();
      final matchesSearch = q.isEmpty || name.contains(q);
      final matchesStatus = _statusFilter == 'All' || (w['status'] ?? '').toString() == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  List<_MonthGroup> _groupByMonth(List<Map<String, dynamic>> items) {
    final Map<String, _MonthGroup> map = {};
    for (final r in items) {
      final d = _parseDate(r['date']?.toString());
      if (!_inRange(d)) continue;
      final String key;
      final DateTime? month;
      if (d == null) {
        key = 'unknown';
        month = null;
      } else {
        key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        month = DateTime(d.year, d.month, 1);
      }
      map.putIfAbsent(key, () => _MonthGroup(month, key)).items.add(r);
    }

    final groups = map.values.toList();
    groups.sort((a, b) {
      final am = a.month;
      final bm = b.month;
      if (am == null && bm == null) return 0;
      if (am == null) return 1;
      if (bm == null) return -1;
      return bm.compareTo(am);
    });
    return groups;
  }

  bool _isMonthExpanded(_MonthGroup g) {
    final override = _monthExpanded[g.key];
    if (override != null) return override;
    if (_searching) return true;
    if (_range == _BillingRange.month) return true;
    final m = g.month;
    return m != null && m == _currentMonth;
  }

  // ---------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final pendingCount = _countPendingPayments();
    final failedCount = _countFailedPayments();

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plain page title (replaces the big cyan banner).
            Text(
              'Billing & Payments',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppTheme.heading(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage membership plans and track payments',
              style: TextStyle(fontSize: 14, color: AppTheme.textMuted(context)),
            ),
            const SizedBox(height: AppSpacing.section),

            Row(
              children: [
                _buildSummaryCard(
                  title: "This Week's Revenue",
                  value: _formatCurrency(_calculateWeekRevenue()),
                  icon: Icons.calendar_view_week,
                ),
                const SizedBox(width: 16),
                _buildSummaryCard(
                  title: "This Month's Revenue",
                  value: _formatCurrency(_calculateMonthRevenue()),
                  icon: Icons.calendar_month,
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                _buildSummaryCard(
                  title: 'Pending Payments',
                  value: pendingCount.toString(),
                  icon: Icons.credit_card,
                  tint: AppColors.warning,
                  accent: pendingCount > 0 ? AppColors.warning : null,
                ),
                const SizedBox(width: 16),
                _buildSummaryCard(
                  title: 'Failed Payments',
                  value: failedCount.toString(),
                  icon: Icons.warning_amber_rounded,
                  tint: AppColors.danger,
                  accent: failedCount > 0 ? AppColors.danger : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.section),

            Text('Membership Plans', style: _sectionTitleStyle),
            const SizedBox(height: 12),
            _buildMembershipPlanCards(),
            const SizedBox(height: AppSpacing.section),

            _buildPaymentsSection(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PAYMENTS SECTION (tabs + filters + month groups)
  // ==========================================

  Widget _buildPaymentsSection() {
    final isMembership = _tab == _BillingTab.membership;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMembership ? 'Membership Plan Payments' : 'Walk-in Payments',
                    style: _sectionTitleStyle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isMembership
                        ? 'Payments from members on a plan, grouped by month.'
                        : 'Payments from walk-in customers checked in via the Attendance page.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted(context)),
                  ),
                ],
              ),
            ),
            if (CurrentUser.isOwner)
              ElevatedButton.icon(
                onPressed: _isSendingEmail ? null : _exportEarningsStatement,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export PDF'),
                style: _primaryButtonStyle(),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildFilterBar(),
        const SizedBox(height: 16),
        _buildGroupsView(),
      ],
    );
  }

  Widget _buildFilterBar() {
    final searching = _searching;
    final isMembership = _tab == _BillingTab.membership;
    return _card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildTabs(),
              Opacity(
                opacity: searching ? 0.4 : 1,
                child: IgnorePointer(
                  ignoring: searching,
                  child: _buildMonthNavigator(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Opacity(
            opacity: searching ? 0.4 : 1,
            child: IgnorePointer(
              ignoring: searching,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(
                    label: 'This month',
                    selected: _range == _BillingRange.month && _anchorMonth == _currentMonth,
                    onTap: () => _setRange(_BillingRange.month),
                  ),
                  _pill(
                    label: 'Last 3 months',
                    selected: _range == _BillingRange.last3,
                    onTap: () => _setRange(_BillingRange.last3),
                  ),
                  _pill(
                    label: 'All dates',
                    selected: _range == _BillingRange.all,
                    onTap: () => _setRange(_BillingRange.all),
                  ),
                  _pill(
                    label: 'Custom',
                    selected: _range == _BillingRange.custom,
                    onTap: _pickCustomRange,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text('STATUS', style: _tableHeaderStyle),
              ),
              for (final s in ['All', 'Paid', 'Pending', 'Failed'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _pill(
                    label: s,
                    selected: _statusFilter == s,
                    onTap: () => setState(() {
                      _statusFilter = s;
                      _resetView();
                    }),
                  ),
                ),
            ],
          ),
          if (isMembership) ...[
            const SizedBox(height: 12),
            Wrap(
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text('PLAN', style: _tableHeaderStyle),
                ),
                for (final p in ['All', ..._planDefinitions.map((d) => d.name)])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _pill(
                      label: p,
                      selected: _planFilter == p,
                      onTap: () => setState(() {
                        _planFilter = p;
                        _resetView();
                      }),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          KeyedSubtree(
            key: const ValueKey('billing-search-box'),
            child: _searchBox(
              hint: isMembership ? 'Search by member name...' : 'Search by customer name...',
              onChanged: (v) => setState(() {
                _searchQuery = v;
                _resetView();
              }),
            ),
          ),
          if (searching) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.info_outline, size: 15, color: AppTheme.textMuted(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Searching across all dates. The date filter is paused until you clear the search.',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted(context)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabs() {
    Widget item(String label, _BillingTab t, int count) {
      final selected = _tab == t;
      return InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => setState(() {
          _tab = t;
          _resetView();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Theme.of(context).cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? Theme.of(context).dividerColor : Colors.transparent,
            ),
          ),
          child: Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? AppTheme.heading(context) : AppTheme.textMuted(context),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.subtleFill(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          item('Membership payments', _BillingTab.membership, PaymentData.instance.payments.length),
          item('Walk-in payments', _BillingTab.walkIns, _walkIns.length),
        ],
      ),
    );
  }

  Widget _buildMonthNavigator() {
    final nav = _canNavigate;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (nav) _navArrow(Icons.chevron_left_rounded, () => _shiftMonth(-1)),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _pickMonth,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.textMuted(context)),
                const SizedBox(width: 8),
                Text(
                  _rangeLabel,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.heading(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (nav) _navArrow(Icons.chevron_right_rounded, _canGoNext ? () => _shiftMonth(1) : null),
      ],
    );
  }

  Widget _navArrow(IconData icon, VoidCallback? onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 22),
      color: AppTheme.heading(context),
      disabledColor: AppTheme.textMuted(context).withValues(alpha: 0.4),
      splashRadius: 18,
      visualDensity: VisualDensity.compact,
    );
  }

  /// Generic pill chip (range, status and plan filters).
  Widget _pill({required String label, required bool selected, required VoidCallback onTap}) {
    final selectedBg = _isDark ? AppColors.cyan : const Color(0xFF111827);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? selectedBg : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? selectedBg : Theme.of(context).dividerColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.heading(context),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MONTH GROUPS
  // ==========================================

  Widget _buildGroupsView() {
    final isMembership = _tab == _BillingTab.membership;
    final items = isMembership ? _filteredMembershipPayments : _filteredWalkInPayments;
    final groups = _groupByMonth(items);
    final loading = isMembership ? _loadingPayments : _loadingWalkIns;
    final totalRecords = isMembership ? PaymentData.instance.payments.length : _walkIns.length;

    if (loading && groups.isEmpty) {
      return _card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('Loading...', style: TextStyle(color: AppTheme.textMuted(context)))),
        ),
      );
    }

    if (groups.isEmpty) {
      final String message;
      if (_searching) {
        message = 'No payments match your search.';
      } else if (_range != _BillingRange.all) {
        message = isMembership
            ? 'No membership payments for this period.'
            : 'No walk-in payments for this period.';
      } else {
        message = isMembership ? 'No membership payments yet' : 'No walk-in payments yet';
      }
      return _card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, style: TextStyle(color: AppTheme.textMuted(context))),
                if (!_searching && _range != _BillingRange.all) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _setRange(_BillingRange.all),
                    child: const Text('Show all dates'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final shown = groups.take(_visibleMonths).toList();
    final remaining = groups.length - shown.length;
    final shownRecords = shown.fold<int>(0, (sum, g) => sum + g.items.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildMonthCard(g, isMembership),
          ),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _visibleMonths += _pageSize),
                icon: const Icon(Icons.expand_more_rounded, size: 18),
                label: Text('Load earlier months ($remaining more)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.heading(context),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(
            'Showing $shownRecords of $totalRecords payments',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted(context)),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthCard(_MonthGroup g, bool isMembership) {
    final expanded = _isMonthExpanded(g);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMonthHeader(g, expanded),
          if (expanded) _buildMonthBody(g, isMembership),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(_MonthGroup g, bool expanded) {
    final m = g.month;
    final title = m == null ? 'Unknown date' : '${_monthsFull[m.month - 1]} ${m.year}';
    final isCurrent = m != null && m == _currentMonth;

    int collected = 0;
    int pending = 0;
    int failed = 0;
    for (final r in g.items) {
      final status = (r['status'] ?? '').toString();
      if (status == 'Paid') collected += _parseAmount(r['amount']);
      if (status == 'Pending') pending++;
      if (status == 'Failed') failed++;
    }

    final pills = <Widget>[
      _countPill('${g.items.length} ${g.items.length == 1 ? 'payment' : 'payments'}'),
      _countPill('${_formatCurrency(collected)} collected', color: AppColors.success),
      if (pending > 0) _countPill('$pending pending', color: AppColors.warning),
      if (failed > 0) _countPill('$failed failed', color: AppColors.danger),
    ];

    return InkWell(
      onTap: () => setState(() => _monthExpanded[g.key] = !expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
              size: 22,
              color: AppTheme.textMuted(context),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: AppTheme.heading(context),
              ),
            ),
            if (isCurrent) ...[
              const SizedBox(width: 8),
              Text('This month', style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted(context))),
            ],
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 6,
                  children: pills,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countPill(String text, {Color? color}) {
    final fg = color ?? AppTheme.textMuted(context);
    final bg = color == null ? AppTheme.subtleFill(context) : color.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _buildMonthBody(_MonthGroup g, bool isMembership) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: Theme.of(context).dividerColor),
        isMembership ? _buildMembershipTableHeader() : _buildWalkInTableHeader(),
        Divider(height: 1, color: Theme.of(context).dividerColor),
        ...g.items.map((r) => isMembership ? _buildMembershipRow(r) : _buildWalkInRow(r)),
      ],
    );
  }

  Widget _buildMembershipTableHeader() {
    final style = _tableHeaderStyle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('MEMBER', style: style)),
          Expanded(flex: 2, child: Text('PLAN', style: style)),
          Expanded(flex: 2, child: Text('AMOUNT', style: style)),
          Expanded(flex: 2, child: Text('METHOD', style: style)),
          Expanded(flex: 2, child: Text('DATE', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
        ],
      ),
    );
  }

  Widget _buildWalkInTableHeader() {
    final style = _tableHeaderStyle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('NAME', style: style)),
          Expanded(flex: 2, child: Text('AMOUNT', style: style)),
          Expanded(flex: 2, child: Text('METHOD', style: style)),
          Expanded(flex: 2, child: Text('DATE', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
        ],
      ),
    );
  }

  /// Colored left edge for rows that need attention (Pending / Failed).
  Color _attentionBar(String status) {
    if (status == 'Pending') return AppColors.warning;
    if (status == 'Failed') return AppColors.danger;
    return Colors.transparent;
  }

  Widget _statusBadge(String status, Map<String, List<Color>> palette) {
    final colors = palette[status] ?? [AppTheme.subtleFill(context), AppTheme.textMuted(context)];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: colors[0], borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: colors[1], fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget _buildMembershipRow(Map<String, dynamic> item) {
    final status = (item['status'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 14, 20, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
          left: BorderSide(color: _attentionBar(status), width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              (item['member'] ?? '').toString(),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.heading(context)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.subtleFill(context), borderRadius: BorderRadius.circular(6)),
                child: Text((item['plan'] ?? '').toString(), style: TextStyle(fontSize: 12, color: AppTheme.heading(context))),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              (item['amount'] ?? '').toString(),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.heading(context)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text((item['method'] ?? '').toString(), style: TextStyle(fontSize: 13, color: AppTheme.textMuted(context))),
          ),
          Expanded(
            flex: 2,
            child: Text((item['date'] ?? '').toString(), style: TextStyle(fontSize: 13, color: AppTheme.textMuted(context))),
          ),
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.centerLeft, child: _statusBadge(status, _paymentStatusColors)),
          ),
        ],
      ),
    );
  }

  Widget _buildWalkInRow(Map<String, dynamic> w) {
    final status = (w['status'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 14, 20, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
          left: BorderSide(color: _attentionBar(status), width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              (w['name'] ?? '').toString(),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.heading(context)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '₱${((w['amount'] ?? 0) as num).toStringAsFixed(0)}',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.heading(context)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text((w['method'] ?? '').toString(), style: TextStyle(fontSize: 13, color: AppTheme.textMuted(context))),
          ),
          Expanded(
            flex: 2,
            child: Text((w['date'] ?? '').toString(), style: TextStyle(fontSize: 13, color: AppTheme.textMuted(context))),
          ),
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.centerLeft, child: _statusBadge(status, _walkInStatusColors)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SUMMARY + PLAN CARDS (unchanged)
  // ==========================================

  /// KPI-style summary card: small gray label + small icon tile on top, big
  /// bold value underneath. [accent] (left bar) is only passed for cards that
  /// need attention; [tint] colors the icon tile.
  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    Color? tint,
    Color? accent,
  }) {
    final iconTint = tint ?? accent ?? AppColors.cyan;
    return Expanded(
      child: _card(
        accent: accent,
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.textMuted(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconTint.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconTint, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppTheme.heading(context),
              ),
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
      children.add(_buildPlanCard(plan.name, plan.price, '$count active members'));
      if (i < _planDefinitions.length - 1) {
        children.add(const SizedBox(width: 16));
      }
    }
    return Row(children: children);
  }

  /// Plan card: one neutral cyan-tinted chip for every plan (the per-plan
  /// pastel colors are no longer used), price on the right.
  Widget _buildPlanCard(String name, String price, String sub) {
    return Expanded(
      child: _card(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(name, style: const TextStyle(color: AppColors.cyanDark, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
                Text(price, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppTheme.heading(context))),
              ],
            ),
            const SizedBox(height: 16),
            Text(sub, style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class PlanDefinition {
  final String name;
  final String price;
  final Color chipBg;
  final Color chipText;
  const PlanDefinition(this.name, this.price, this.chipBg, this.chipText);
}
