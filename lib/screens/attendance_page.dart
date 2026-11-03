import 'package:flutter/material.dart';
import '../services/attendance_service.dart';
import '../services/current_user.dart';
import '../theme/app_theme.dart';
import '../widgets/tab_visibility.dart';

/// Attendance page — dalawang hiwalay na listahan (ngayon naka-group na per ARAW):
///  - Walk-in Customers: mga hindi naka-membership plan, manual check-in
///    dito, naka-store sa 'walk_ins' table
///  - Member Check-ins: mga naka-membership plan na na-scan via QR sa
///    Scan page, naka-store sa 'attendance_logs' table
///
/// UI updates (visual lang, walang binago sa functions/services):
///  - Records naka-group per petsa (Today, Yesterday, Mon, Oct 26, ...)
///  - Default view = Today, may date navigator + range chips
///  - Collapsible na past days + "Load earlier days"
///  - Summary cards, All / Members / Walk-ins tabs
///  - Same-day repeat check-ins ng member = isang row na may badge
enum _AttendanceTab { all, members, walkIns }

enum _DateRange { day, week, month, all, custom }

/// Isang araw ng records (members + walk-ins).
class _DayGroup {
  final DateTime? date;
  final String key;
  final List<Map<String, dynamic>> members = [];
  final List<Map<String, dynamic>> walkIns = [];
  _DayGroup(this.date, this.key);

  int get total => members.length + walkIns.length;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class AttendancePage extends StatefulWidget {
  final VoidCallback? onGoToScan;
  const AttendancePage({super.key, this.onGoToScan});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with PollingScreenMixin<AttendancePage> {
  static const Color accent = AppColors.cyan;

  String _searchQuery = '';
  String _statusFilter = 'All Status';
  String _memberSearchQuery = '';

  List<Map<String, dynamic>> _walkIns = [];
  List<Map<String, dynamic>> _memberCheckIns = [];
  bool _loadingWalkIns = true;
  bool _loadingMemberCheckIns = true;

  List<Map<String, dynamic>> _pendingApprovals = [];
  bool _loadingApprovals = true;

  static const List<String> _statusOptions = ['Paid', 'Pending', 'Failed'];

  // ---- View state (presentation only) ----
  static const int _pageSize = 7;
  _AttendanceTab _tab = _AttendanceTab.all;
  _DateRange _range = _DateRange.day;
  DateTime _anchorDay = _dateOnly(DateTime.now());
  DateTimeRange? _customRange;
  int _visibleDays = _pageSize;
  final Map<String, bool> _dayExpanded = {};
  final Set<String> _expandedRepeats = {};
  final Set<String> _checkingOut = {};

  static const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const List<String> _monthsFull = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  List<Map<String, dynamic>> get _filteredWalkIns {
    return _walkIns.where((r) {
      final name = (r['name'] ?? '').toString().toLowerCase();
      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
      final matchesStatus = _statusFilter == 'All Status' || r['status'] == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredMemberCheckIns {
    if (_memberSearchQuery.isEmpty) return _memberCheckIns;
    final q = _memberSearchQuery.toLowerCase();
    return _memberCheckIns.where((r) {
      final name = (r['name'] ?? '').toString().toLowerCase();
      final email = (r['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  // Polling runs only while Attendance is the visible tab.
  @override
  Duration get pollInterval => const Duration(seconds: 25);

  @override
  void onInitialLoad() {
    _loadWalkIns();
    _loadMemberCheckIns();
    if (CurrentUser.isOwner) {
      _loadPendingApprovals();
    }
  }

  @override
  void onPoll() {
    _loadWalkIns(silent: true);
    _loadMemberCheckIns(silent: true);
    if (CurrentUser.isOwner) {
      _loadPendingApprovals(silent: true);
    }
  }

  Future<void> _loadWalkIns({bool silent = false}) async {
    if (!silent) setState(() => _loadingWalkIns = true);
    final data = await AttendanceService.getWalkIns();
    if (mounted) {
      setState(() {
        _walkIns = data;
        _loadingWalkIns = false;
      });
    }
  }

  Future<void> _loadMemberCheckIns({bool silent = false}) async {
    if (!silent) setState(() => _loadingMemberCheckIns = true);
    final data = await AttendanceService.getAttendanceLogs();
    if (mounted) {
      setState(() {
        _memberCheckIns = data;
        _loadingMemberCheckIns = false;
      });
    }
  }

  Future<void> _loadPendingApprovals({bool silent = false}) async {
    if (!silent) setState(() => _loadingApprovals = true);
    final data = await AttendanceService.getPendingApprovals();
    if (mounted) {
      setState(() {
        _pendingApprovals = data;
        _loadingApprovals = false;
      });
    }
  }

  // ---------------------------------------------------------------------
  // Presentation helpers (styling only, no logic)
  // ---------------------------------------------------------------------

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  /// Dark solid button (cyan in dark mode), replaces the gold button.
  ButtonStyle _primaryButtonStyle({double radius = 10, EdgeInsetsGeometry? padding}) {
    return ElevatedButton.styleFrom(
      backgroundColor: _isDark ? AppColors.cyan : const Color(0xFF111827),
      foregroundColor: Colors.white,
      elevation: 0,
      padding: padding,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  TextStyle get _sectionTitleStyle => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppTheme.heading(context),
      );

  /// White rounded card with hairline border + soft shadow. [accent] draws a
  /// thin colored bar on the left edge, reserved for cards needing attention.
  Widget _tableCard({required Widget child, Color? accent}) {
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
          SizedBox(width: double.infinity, child: child),
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

  // ---------------------------------------------------------------------
  // Date / data helpers (display only)
  // ---------------------------------------------------------------------

  DateTime get _today => _dateOnly(DateTime.now());

  bool get _searchActive => _searchQuery.isNotEmpty || _memberSearchQuery.isNotEmpty;

  DateTime? _parseDate(dynamic v) {
    final s = (v ?? '').toString().trim();
    if (s.isEmpty) return null;
    final d = DateTime.tryParse(s);
    if (d == null) return null;
    return _dateOnly(d);
  }

  String _dateKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  String _shortDate(DateTime d, {bool withYear = false}) {
    final base = '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
    if (!withYear) return base;
    return '$base, ${d.year}';
  }

  String _monthDay(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  String _dayLabel(DateTime d) {
    final today = _today;
    if (_sameDay(d, today)) return 'Today';
    if (_sameDay(d, _addDays(today, -1))) return 'Yesterday';
    return _shortDate(d, withYear: d.year != today.year);
  }

  String _plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString()) ?? 0;
  }

  bool _hasCheckOut(Map<String, dynamic> r) {
    final v = (r['checkOut'] ?? '').toString().trim();
    return v.isNotEmpty && v != '--';
  }

  bool _isTodayRecord(Map<String, dynamic> record) {
    final date = DateTime.tryParse((record['date'] ?? '').toString());
    if (date == null) return false;
    final today = DateTime.now();
    return date.year == today.year && date.month == today.month && date.day == today.day;
  }

  bool _canCheckOut(Map<String, dynamic> record) {
    final checkIn = (record['checkIn'] ?? '').toString().trim();
    final status = (record['status'] ?? '').toString();
    return _isTodayRecord(record) &&
        !_hasCheckOut(record) &&
        checkIn.isNotEmpty &&
        checkIn != '--' &&
        status != 'Absent';
  }

  Future<void> _checkOutMember(Map<String, dynamic> record) async {
    final id = (record['id'] ?? '').toString();
    if (id.isEmpty || !_canCheckOut(record)) return;
    final key = 'member:$id';
    if (!_checkingOut.add(key)) return;
    setState(() {});
    final success = await AttendanceService.checkOutMember(id);
    if (!mounted) return;
    setState(() => _checkingOut.remove(key));
    if (success) {
      await _loadMemberCheckIns(silent: true);
      _showSnack('${record['name'] ?? 'Member'} checked out at ${_formatNow()}.');
    } else {
      _showSnack('Could not check out this member. It may already be checked out.', isError: true);
    }
  }

  Future<void> _checkOutWalkIn(Map<String, dynamic> record) async {
    final id = (record['id'] ?? '').toString();
    if (id.isEmpty || !_canCheckOut(record)) return;
    final key = 'walk-in:$id';
    if (!_checkingOut.add(key)) return;
    setState(() {});
    final success = await AttendanceService.checkOutWalkIn(id);
    if (!mounted) return;
    setState(() => _checkingOut.remove(key));
    if (success) {
      await _loadWalkIns(silent: true);
      _showSnack('${record['name'] ?? 'Walk-in'} checked out at ${_formatNow()}.');
    } else {
      _showSnack('Could not check out this walk-in. It may already be checked out.', isError: true);
    }
  }

  String _memberKey(Map<String, dynamic> r) {
    final email = (r['email'] ?? '').toString().trim().toLowerCase();
    if (email.isNotEmpty) return email;
    return (r['name'] ?? '').toString().trim().toLowerCase();
  }

  // ---- Date range ----

  DateTime? get _rangeStart {
    switch (_range) {
      case _DateRange.day:
        return _anchorDay;
      case _DateRange.week:
        return _addDays(_anchorDay, -(_anchorDay.weekday - 1));
      case _DateRange.month:
        return DateTime(_anchorDay.year, _anchorDay.month, 1);
      case _DateRange.custom:
        final c = _customRange;
        return c == null ? null : _dateOnly(c.start);
      case _DateRange.all:
        return null;
    }
  }

  DateTime? get _rangeEnd {
    switch (_range) {
      case _DateRange.day:
        return _anchorDay;
      case _DateRange.week:
        return _addDays(_anchorDay, 7 - _anchorDay.weekday);
      case _DateRange.month:
        return DateTime(_anchorDay.year, _anchorDay.month + 1, 0);
      case _DateRange.custom:
        final c = _customRange;
        return c == null ? null : _dateOnly(c.end);
      case _DateRange.all:
        return null;
    }
  }

  bool _inRange(DateTime? d) {
    // Search is global: tinitingnan ang lahat ng araw.
    if (_searchActive || _range == _DateRange.all) return true;
    final s = _rangeStart;
    final e = _rangeEnd;
    if (s == null || e == null) return true;
    if (d == null) return false;
    return !d.isBefore(s) && !d.isAfter(e);
  }

  String get _rangeLabel {
    switch (_range) {
      case _DateRange.day:
        final label = _dayLabel(_anchorDay);
        if (label == 'Today' || label == 'Yesterday') {
          return '$label · ${_shortDate(_anchorDay)}';
        }
        return _shortDate(_anchorDay, withYear: true);
      case _DateRange.week:
        final s = _rangeStart;
        final e = _rangeEnd;
        if (s == null || e == null) return 'This week';
        return '${_monthDay(s)} – ${_monthDay(e)}, ${e.year}';
      case _DateRange.month:
        return '${_monthsFull[_anchorDay.month - 1]} ${_anchorDay.year}';
      case _DateRange.custom:
        final s = _rangeStart;
        final e = _rangeEnd;
        if (s == null || e == null) return 'Pick a date range';
        return '${_monthDay(s)} – ${_monthDay(e)}, ${e.year}';
      case _DateRange.all:
        return 'All dates';
    }
  }

  bool get _canNavigate =>
      _range == _DateRange.day || _range == _DateRange.week || _range == _DateRange.month;

  bool get _canGoNext {
    final end = _rangeEnd;
    if (end == null) return false;
    return end.isBefore(_today);
  }

  void _resetView() {
    _visibleDays = _pageSize;
    _dayExpanded.clear();
  }

  void _setRange(_DateRange r) {
    setState(() {
      _range = r;
      _anchorDay = _today;
      _resetView();
    });
  }

  void _shiftRange(int dir) {
    setState(() {
      switch (_range) {
        case _DateRange.day:
          _anchorDay = _addDays(_anchorDay, dir);
          break;
        case _DateRange.week:
          _anchorDay = _addDays(_anchorDay, 7 * dir);
          break;
        case _DateRange.month:
          _anchorDay = DateTime(_anchorDay.year, _anchorDay.month + dir, 1);
          break;
        case _DateRange.custom:
        case _DateRange.all:
          break;
      }
      _resetView();
    });
  }

  Future<void> _pickDate() async {
    if (_range == _DateRange.custom) {
      await _pickCustomRange();
      return;
    }
    final today = _today;
    final initial = _anchorDay.isAfter(today) ? today : _anchorDay;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _anchorDay = _dateOnly(picked);
      if (_range == _DateRange.all) _range = _DateRange.day;
      _resetView();
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _today,
      initialDateRange: _customRange,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customRange = picked;
      _range = _DateRange.custom;
      _resetView();
    });
  }

  // ---- Grouping ----

  List<_DayGroup> _buildGroups() {
    final Map<String, _DayGroup> map = {};

    _DayGroup groupFor(DateTime? d) {
      final key = d == null ? 'unknown' : _dateKey(d);
      return map.putIfAbsent(key, () => _DayGroup(d, key));
    }

    if (_tab != _AttendanceTab.walkIns) {
      for (final r in _filteredMemberCheckIns) {
        final d = _parseDate(r['date']);
        if (!_inRange(d)) continue;
        groupFor(d).members.add(r);
      }
    }
    if (_tab != _AttendanceTab.members) {
      for (final r in _filteredWalkIns) {
        final d = _parseDate(r['date']);
        if (!_inRange(d)) continue;
        groupFor(d).walkIns.add(r);
      }
    }

    final groups = map.values.toList();
    groups.sort((a, b) {
      final ad = a.date;
      final bd = b.date;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return groups;
  }

  bool _isExpanded(_DayGroup g) {
    final override = _dayExpanded[g.key];
    if (override != null) return override;
    if (_searchActive) return true;
    if (_range == _DateRange.day) return true;
    final d = g.date;
    if (d != null && _sameDay(d, _today)) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildSummaryCards(),
              const SizedBox(height: AppSpacing.section),
              if (CurrentUser.isOwner) ...[
                _buildPendingApprovalsCard(),
                const SizedBox(height: AppSpacing.section),
              ],
              _buildFilterBar(),
              const SizedBox(height: 16),
              _buildDayGroups(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attendance',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppTheme.heading(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Check in walk-in customers and record their payment.',
          style: TextStyle(fontSize: 14, color: AppTheme.textMuted(context)),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: widget.onGoToScan,
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('QR Check-In'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.heading(context),
                side: BorderSide(color: AppTheme.heading(context).withValues(alpha: 0.35)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _onManualCheckIn,
              icon: const Icon(Icons.how_to_reg, size: 18),
              label: const Text('Manual Check In'),
              style: _primaryButtonStyle(
                radius: 999,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // SUMMARY CARDS (today)
  // ==========================================

  Widget _buildSummaryCards() {
    final today = _today;
    final membersToday = _memberCheckIns.where((r) {
      final d = _parseDate(r['date']);
      return d != null && _sameDay(d, today);
    }).toList();
    final walkInsToday = _walkIns.where((r) {
      final d = _parseDate(r['date']);
      return d != null && _sameDay(d, today);
    }).toList();

    final presentCount = membersToday.map((r) => _memberKey(r)).toSet().length;
    final stillIn = membersToday.where((r) => !_hasCheckOut(r)).length +
        walkInsToday.where((r) => !_hasCheckOut(r)).length;
    double revenue = 0;
    for (final r in walkInsToday) {
      if (r['status'] == 'Paid') revenue += _toDouble(r['amount']);
    }

    final cards = <Widget Function(double)>[
      (w) => SizedBox(
            width: w,
            child: _summaryCard(
              icon: Icons.groups_rounded,
              label: 'Present today',
              value: '$presentCount',
              color: AppColors.cyan,
            ),
          ),
      (w) => SizedBox(
            width: w,
            child: _summaryCard(
              icon: Icons.directions_walk_rounded,
              label: 'Walk-ins today',
              value: '${walkInsToday.length}',
              color: AppColors.warning,
            ),
          ),
      (w) => SizedBox(
            width: w,
            child: _summaryCard(
              icon: Icons.payments_outlined,
              label: 'Walk-in revenue today',
              value: '₱${revenue.toStringAsFixed(0)}',
              color: AppColors.success,
            ),
          ),
      (w) => SizedBox(
            width: w,
            child: _summaryCard(
              icon: Icons.login_rounded,
              label: 'Still checked in',
              value: '$stillIn',
              color: const Color(0xFF6366F1),
            ),
          ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 900 ? 4 : 2;
        const gap = 12.0;
        final w = (constraints.maxWidth - (cols - 1) * gap) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards.map((build) => build(w)).toList(),
        );
      },
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return _tableCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: AppTheme.heading(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PENDING APPROVALS (Owner only)
  // ==========================================

  Widget _buildPendingApprovalsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Pending Approvals', style: _sectionTitleStyle),
            const SizedBox(width: 8),
            if (_pendingApprovals.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(20)),
                child: Text('${_pendingApprovals.length}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.danger)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Staff edit/delete requests waiting for your approval.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted(context))),
        const SizedBox(height: 12),
        _tableCard(
          accent: _pendingApprovals.isNotEmpty ? AppColors.warning : null,
          child: _loadingApprovals
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('Loading...', style: TextStyle(color: AppTheme.textMuted(context)))),
                )
              : _pendingApprovals.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('No pending approvals.', style: TextStyle(color: AppTheme.textMuted(context)))),
                    )
                  : Column(
                      children: _pendingApprovals.map((a) => _buildApprovalRow(a)).toList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildApprovalRow(Map<String, dynamic> a) {
    final type = a['type']?.toString() ?? '';
    final original = a['original'] as Map<String, dynamic>?;
    final payload = a['payload'] as Map<String, dynamic>?;
    final name = original?['name']?.toString() ?? 'Unknown';
    final requestedBy = a['requested_by']?.toString() ?? 'Staff';

    String description;
    if (type == 'delete') {
      description = 'Wants to delete this walk-in record.';
    } else {
      final changes = <String>[];
      if (payload != null) {
        payload.forEach((key, value) {
          final oldValue = original?[key];
          if (oldValue != null && '$oldValue' != '$value') {
            changes.add('$key: $oldValue → $value');
          }
        });
      }
      description = changes.isEmpty ? 'Wants to edit this walk-in record.' : changes.join(', ');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(
        children: [
          Icon(
            type == 'delete' ? Icons.delete_outline : Icons.edit_outlined,
            size: 18,
            color: type == 'delete' ? AppColors.danger : AppColors.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.heading(context))),
                Text(description, style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context))),
                const SizedBox(height: 2),
                Text('Requested by $requestedBy', style: TextStyle(fontSize: 11, color: AppTheme.textMuted(context))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => _onRejectApproval(a),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            child: const Text('Reject'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _onApproveApproval(a),
            style: _primaryButtonStyle(
              radius: 999,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  Future<void> _onApproveApproval(Map<String, dynamic> a) async {
    final id = a['id'] as int;
    final ok = await AttendanceService.approveRequest(id);
    if (!mounted) return;
    if (ok) {
      _showSnack('Request approved.');
      _loadPendingApprovals();
      _loadWalkIns();
    } else {
      _showSnack('Failed to approve request.', isError: true);
    }
  }

  Future<void> _onRejectApproval(Map<String, dynamic> a) async {
    final id = a['id'] as int;
    final ok = await AttendanceService.rejectRequest(id);
    if (!mounted) return;
    if (ok) {
      _showSnack('Request rejected.');
      _loadPendingApprovals();
    } else {
      _showSnack('Failed to reject request.', isError: true);
    }
  }

  // ==========================================
  // FILTER BAR (tabs, date navigator, range chips, status, search)
  // ==========================================

  Widget _buildFilterBar() {
    final searching = _searchActive;
    return _tableCard(
      child: Padding(
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
                    child: _buildDateNavigator(),
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
                      label: 'Today',
                      selected: _range == _DateRange.day && _sameDay(_anchorDay, _today),
                      onTap: () => _setRange(_DateRange.day),
                    ),
                    _pill(
                      label: 'This week',
                      selected: _range == _DateRange.week && _sameDay(_anchorDay, _today),
                      onTap: () => _setRange(_DateRange.week),
                    ),
                    _pill(
                      label: 'This month',
                      selected: _range == _DateRange.month &&
                          _anchorDay.year == _today.year &&
                          _anchorDay.month == _today.month,
                      onTap: () => _setRange(_DateRange.month),
                    ),
                    _pill(
                      label: 'All dates',
                      selected: _range == _DateRange.all,
                      onTap: () => _setRange(_DateRange.all),
                    ),
                    _pill(
                      label: 'Custom',
                      selected: _range == _DateRange.custom,
                      onTap: _pickCustomRange,
                    ),
                  ],
                ),
              ),
            ),
            if (_tab != _AttendanceTab.members) ...[
              const SizedBox(height: 12),
              Wrap(
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text('WALK-IN PAYMENT', style: _tableHeaderStyle),
                  ),
                  for (final s in ['All Status', ..._statusOptions]) _statusChip(s),
                ],
              ),
            ],
            const SizedBox(height: 14),
            KeyedSubtree(
              key: const ValueKey('attendance-search-box'),
              child: _searchBox(
                hint: 'Search by name or email...',
                onChanged: (v) => setState(() {
                  _searchQuery = v;
                  _memberSearchQuery = v;
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
      ),
    );
  }

  Widget _buildTabs() {
    Widget item(String label, _AttendanceTab t, int count) {
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
          item('All', _AttendanceTab.all, _memberCheckIns.length + _walkIns.length),
          item('Members', _AttendanceTab.members, _memberCheckIns.length),
          item('Walk-ins', _AttendanceTab.walkIns, _walkIns.length),
        ],
      ),
    );
  }

  Widget _buildDateNavigator() {
    final nav = _canNavigate;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (nav) _navArrow(Icons.chevron_left_rounded, () => _shiftRange(-1)),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _pickDate,
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
        if (nav) _navArrow(Icons.chevron_right_rounded, _canGoNext ? () => _shiftRange(1) : null),
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

  /// Generic pill chip (used by the date range chips and the status chips).
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

  /// Status filter as pill chips (same filter values as the old dropdown).
  Widget _statusChip(String value) {
    final label = value == 'All Status' ? 'All' : value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: _pill(
        label: label,
        selected: _statusFilter == value,
        onTap: () => setState(() {
          _statusFilter = value;
          _resetView();
        }),
      ),
    );
  }

  // ==========================================
  // DAY GROUPS
  // ==========================================

  Widget _buildDayGroups() {
    final groups = _buildGroups();

    final bool loading;
    final int totalRecords;
    switch (_tab) {
      case _AttendanceTab.members:
        loading = _loadingMemberCheckIns;
        totalRecords = _memberCheckIns.length;
        break;
      case _AttendanceTab.walkIns:
        loading = _loadingWalkIns;
        totalRecords = _walkIns.length;
        break;
      case _AttendanceTab.all:
        loading = _loadingMemberCheckIns && _loadingWalkIns;
        totalRecords = _memberCheckIns.length + _walkIns.length;
        break;
    }

    if (loading && groups.isEmpty) {
      return _tableCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('Loading...', style: TextStyle(color: AppTheme.textMuted(context)))),
        ),
      );
    }

    if (groups.isEmpty) {
      final String message;
      if (_searchActive) {
        message = 'No records match your search.';
      } else if (_range != _DateRange.all) {
        message = 'No attendance records for this period.';
      } else {
        message = 'No attendance records found';
      }
      return _tableCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, style: TextStyle(color: AppTheme.textMuted(context))),
                if (!_searchActive && _range != _DateRange.all) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _setRange(_DateRange.all),
                    child: const Text('Show all dates'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final shown = groups.take(_visibleDays).toList();
    final remaining = groups.length - shown.length;
    final shownRecords = shown.fold<int>(0, (sum, g) => sum + g.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildDayCard(g),
          ),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _visibleDays += _pageSize),
                icon: const Icon(Icons.expand_more_rounded, size: 18),
                label: Text('Load earlier days ($remaining more)'),
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
            'Showing $shownRecords of $totalRecords records',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted(context)),
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard(_DayGroup g) {
    final expanded = _isExpanded(g);
    return _tableCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDayHeader(g, expanded),
          if (expanded) _buildDayBody(g),
        ],
      ),
    );
  }

  Widget _buildDayHeader(_DayGroup g, bool expanded) {
    final date = g.date;
    final title = date == null ? 'Unknown date' : _dayLabel(date);
    final String? sub = (date != null && (title == 'Today' || title == 'Yesterday'))
        ? _shortDate(date, withYear: true)
        : null;

    double collected = 0;
    for (final r in g.walkIns) {
      if (r['status'] == 'Paid') collected += _toDouble(r['amount']);
    }

    final pills = <Widget>[
      if (g.members.isNotEmpty)
        _countPill(_plural(g.members.length, 'member check-in', 'member check-ins')),
      if (g.walkIns.isNotEmpty) _countPill(_plural(g.walkIns.length, 'walk-in', 'walk-ins')),
      if (g.walkIns.isNotEmpty)
        _countPill('₱${collected.toStringAsFixed(0)} collected', color: AppColors.success),
    ];

    return InkWell(
      onTap: () => setState(() => _dayExpanded[g.key] = !expanded),
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
            if (sub != null) ...[
              const SizedBox(width: 8),
              Text(sub, style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted(context))),
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

  Widget _buildDayBody(_DayGroup g) {
    final showLabels = _tab == _AttendanceTab.all;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: Theme.of(context).dividerColor),
        if (g.members.isNotEmpty) ...[
          if (showLabels) _subSectionLabel('Member check-ins', g.members.length, Icons.qr_code_scanner),
          _buildMemberTableHeader(),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          _buildMemberRows(g),
        ],
        if (g.members.isNotEmpty && g.walkIns.isNotEmpty) const SizedBox(height: 8),
        if (g.walkIns.isNotEmpty) ...[
          if (showLabels) _subSectionLabel('Walk-in customers', g.walkIns.length, Icons.directions_walk_rounded),
          _buildWalkInTableHeader(),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          ...g.walkIns.map((r) => _buildWalkInRow(r)),
        ],
      ],
    );
  }

  Widget _subSectionLabel(String text, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppTheme.textMuted(context)),
          const SizedBox(width: 6),
          Text(
            '$text · $count',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.heading(context),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _tableHeaderStyle => TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: AppTheme.textMuted(context),
        letterSpacing: 0.6,
      );

  // ---------------------------------------------------------------------
  // WALK-IN rows (walk_ins table)
  // ---------------------------------------------------------------------

  Widget _buildWalkInTableHeader() {
    final style = _tableHeaderStyle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('NAME', style: style)),
          Expanded(flex: 2, child: Text('CHECK-IN', style: style)),
          Expanded(flex: 2, child: Text('CHECK-OUT', style: style)),
          Expanded(flex: 2, child: Text('PAYMENT', style: style)),
          Expanded(flex: 2, child: Text('METHOD', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          SizedBox(width: 178, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }

  static const Map<String, List<Color>> _statusColors = {
    'Paid': [AppColors.successBg, AppColors.success],
    'Pending': [AppColors.warningBg, AppColors.warning],
    'Failed': [AppColors.dangerBg, AppColors.danger],
  };

  Widget _checkOutCell(Map<String, dynamic> r) {
    if (_hasCheckOut(r)) {
      return Text(
        r['checkOut'].toString(),
        style: TextStyle(fontSize: 13, color: AppTheme.heading(context)),
      );
    }
    return Text(
      'No check-out',
      style: TextStyle(
        fontSize: 12.5,
        fontStyle: FontStyle.italic,
        color: AppTheme.textMuted(context),
      ),
    );
  }

  Widget _buildWalkInRow(Map<String, dynamic> r) {
    final status = (r['status'] ?? '').toString();
    final Color barColor;
    if (status == 'Pending') {
      barColor = AppColors.warning;
    } else if (status == 'Failed') {
      barColor = AppColors.danger;
    } else {
      barColor = Colors.transparent;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(17, 14, 20, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
          left: BorderSide(color: barColor, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(r['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.heading(context)))),
          Expanded(flex: 2, child: Text(r['checkIn'] ?? '--', style: TextStyle(fontSize: 13, color: AppTheme.heading(context)))),
          Expanded(flex: 2, child: _checkOutCell(r)),
          Expanded(flex: 2, child: Text('₱${_toDouble(r['amount']).toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.heading(context)))),
          Expanded(flex: 2, child: Text(r['method'] ?? '', style: TextStyle(fontSize: 13, color: AppTheme.heading(context)))),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _buildBadge(r['status'] ?? '', _statusColors))),
          SizedBox(width: 178, child: _buildWalkInActions(r)),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Map<String, List<Color>> palette) {
    final colors = palette[label] ?? [AppTheme.subtleFill(context), AppTheme.textMuted(context)];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: colors[0], borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors[1])),
    );
  }

  Widget _buildWalkInActions(Map<String, dynamic> r) {
    return Row(
      children: [
        if (_canCheckOut(r))
          TextButton(
            onPressed: _checkingOut.contains('walk-in:${r['id']}') ? null : () => _checkOutWalkIn(r),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _checkingOut.contains('walk-in:${r['id']}') ? 'Saving…' : 'Check Out',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
        IconButton(
          onPressed: () => _onEditWalkIn(r),
          icon: Icon(Icons.edit_outlined, size: 18, color: AppTheme.textMuted(context)),
          splashRadius: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () => _onDeleteWalkIn(r),
          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
          splashRadius: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // MEMBER / QR CHECK-IN rows (attendance_logs)
  // ---------------------------------------------------------------------

  Widget _buildMemberTableHeader() {
    final style = _tableHeaderStyle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('MEMBER', style: style)),
          Expanded(flex: 2, child: Text('CHECK-IN', style: style)),
          Expanded(flex: 2, child: Text('CHECK-OUT', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          SizedBox(width: 115, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }

  static const Map<String, List<Color>> _memberStatusColors = {
    'Present': [AppColors.successBg, AppColors.success],
    'Still inside': [AppColors.successBg, AppColors.success],
    'Late': [AppColors.warningBg, AppColors.warning],
    'Absent': [AppColors.dangerBg, AppColors.danger],
  };

  /// Late / Absent keep their badge; "Present" is replaced by a more useful
  /// Still inside / Checked out indicator.
  String _memberStatusLabel(Map<String, dynamic> r) {
    final s = (r['status'] ?? '').toString();
    if (s.isNotEmpty && s != 'Present') return s;
    return _hasCheckOut(r) ? 'Checked out' : 'Still inside';
  }

  /// Same member + same day = one row; extra check-ins fold under a badge.
  Widget _buildMemberRows(_DayGroup g) {
    final Map<String, List<Map<String, dynamic>>> byMember = {};
    for (final r in g.members) {
      byMember.putIfAbsent(_memberKey(r), () => <Map<String, dynamic>>[]).add(r);
    }

    final rows = <Widget>[];
    byMember.forEach((memberKey, list) {
      if (list.length == 1) {
        rows.add(_buildMemberRow(list.first));
      } else {
        rows.add(_buildRepeatMemberRows('${g.key}|$memberKey', list));
      }
    });
    return Column(children: rows);
  }

  Widget _buildRepeatMemberRows(String repeatKey, List<Map<String, dynamic>> list) {
    final expanded = _expandedRepeats.contains(repeatKey);
    return Column(
      children: [
        _buildMemberRow(
          list.first,
          repeatCount: list.length,
          expanded: expanded,
          onToggle: () => setState(() {
            if (expanded) {
              _expandedRepeats.remove(repeatKey);
            } else {
              _expandedRepeats.add(repeatKey);
            }
          }),
        ),
        if (expanded) ...list.skip(1).map((r) => _buildMemberRow(r, nested: true)),
      ],
    );
  }

  Widget _buildMemberRow(
    Map<String, dynamic> r, {
    int repeatCount = 1,
    bool expanded = false,
    VoidCallback? onToggle,
    bool nested = false,
  }) {
    final Widget nameCell;
    if (nested) {
      nameCell = Padding(
        padding: const EdgeInsets.only(left: 24),
        child: Text(
          'Another check-in',
          style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted(context)),
        ),
      );
    } else {
      nameCell = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  r['name'] ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.heading(context)),
                ),
              ),
              if (repeatCount > 1) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$repeatCount check-ins',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.cyan),
                      ),
                      Icon(
                        expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 14,
                        color: AppColors.cyan,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          Text(r['email'] ?? '', style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context))),
        ],
      );
    }

    final content = Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: nested ? 10 : 14),
      decoration: BoxDecoration(
        color: nested ? AppTheme.subtleFill(context).withValues(alpha: 0.5) : null,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: nameCell),
          Expanded(flex: 2, child: Text(r['checkIn'] ?? '--', style: TextStyle(fontSize: 13, color: AppTheme.heading(context)))),
          Expanded(flex: 2, child: _checkOutCell(r)),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _buildBadge(_memberStatusLabel(r), _memberStatusColors))),
          SizedBox(
            width: 115,
            child: _canCheckOut(r)
                ? TextButton(
                    onPressed: _checkingOut.contains('member:${r['id']}') ? null : () => _checkOutMember(r),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _checkingOut.contains('member:${r['id']}') ? 'Saving…' : 'Check Out',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  )
                : _hasCheckOut(r)
                    ? const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20)
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );

    if (onToggle == null) return content;
    return InkWell(onTap: onToggle, child: content);
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatNow() {
    final now = DateTime.now();
    var hour = now.hour % 12;
    if (hour == 0) hour = 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  // ---------------------------------------------------------------------
  // Manual Check In dialog — para sa walk-in customers
  // ---------------------------------------------------------------------

  void _onManualCheckIn() {
    final nameController = TextEditingController();
    final checkInController = TextEditingController(text: _formatNow());
    final checkOutController = TextEditingController();
    final amountController = TextEditingController();
    String method = 'Cash';
    String status = 'Paid';
    const methods = ['Cash', 'GCash', 'Maya', 'Bank Transfer'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Manual Check In', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: AppTheme.heading(context))),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, size: 20, color: AppTheme.textMuted(context)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('Walk-in customer', style: TextStyle(fontSize: 13, color: AppTheme.textMuted(context))),
                  const SizedBox(height: 20),
                  _fieldLabel('Customer Name'),
                  _dialogField(controller: nameController, hint: 'e.g. Juan Dela Cruz'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [_fieldLabel('Check-in'), _dialogField(controller: checkInController, hint: '8:15 AM')],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [_fieldLabel('Check-out (optional)'), _dialogField(controller: checkOutController, hint: '--')],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('Total Payment'),
                  _dialogField(controller: amountController, hint: '0', prefixText: '₱ ', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Mode of Payment'),
                            _dialogDropdown(value: method, items: methods, onChanged: (v) => setDialogState(() => method = v!)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Status'),
                            _dialogDropdown(value: status, items: _statusOptions, onChanged: (v) => setDialogState(() => status = v!)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Theme.of(context).dividerColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Cancel', style: TextStyle(color: AppTheme.heading(context), fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: _primaryButtonStyle(padding: const EdgeInsets.symmetric(vertical: 14)),
                          onPressed: () async {
                            final name = nameController.text.trim();
                            if (name.isEmpty) {
                              _showSnack('Enter the customer\'s name', isError: true);
                              return;
                            }
                            final amount = double.tryParse(amountController.text.trim()) ?? 0;

                            final result = await AttendanceService.addWalkIn(
                              name: name,
                              checkIn: checkInController.text.trim(),
                              checkOut: checkOutController.text.trim().isEmpty ? '--' : checkOutController.text.trim(),
                              amount: amount,
                              method: method,
                              status: status,
                            );

                            if (!context.mounted) return;
                            Navigator.pop(context);

                            if (result['success'] == true) {
                              _loadWalkIns();
                              _showSnack('$name checked in');
                            } else {
                              _showSnack(result['message'] ?? 'Check-in failed', isError: true);
                            }
                          },
                          child: const Text('Check In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.heading(context))),
    );
  }

  /// [fillTint] lets a specific field use a subtle background tint instead of
  /// the app-wide default from [AppTheme]'s InputDecorationTheme — pass null
  /// to keep that default.
  Widget _dialogField({
    required TextEditingController controller,
    String? hint,
    String? prefixText,
    TextInputType? keyboardType,
    Color? fillTint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.textMuted(context), fontSize: 13),
        prefixText: prefixText,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        filled: fillTint != null ? true : null,
        fillColor: fillTint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: accent)),
      ),
    );
  }

  Widget _dialogDropdown({required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted(context)),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: accent)),
      ),
      items: items.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: onChanged,
    );
  }

  // ---------------------------------------------------------------------
  // Edit Walk-in — maayos na layout (parehong istilo ng Manual Check In),
  // may Owner-approval flow para sa Staff.
  // ---------------------------------------------------------------------

  void _onEditWalkIn(Map<String, dynamic> r) {
    final nameController = TextEditingController(text: r['name']);
    final checkInController = TextEditingController(text: r['checkIn'] ?? '');
    final checkOutController = TextEditingController(text: (r['checkOut'] ?? '') == '--' ? '' : (r['checkOut'] ?? ''));
    final amountController = TextEditingController(text: (r['amount'] ?? 0).toString());
    String method = r['method'] ?? 'Cash';
    String status = r['status'] ?? 'Paid';
    const methods = ['Cash', 'GCash', 'Maya', 'Bank Transfer'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('Edit — ${r['name']}',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: AppTheme.heading(context)),
                            overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, size: 20, color: AppTheme.textMuted(context)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  if (!CurrentUser.isOwner) ...[
                    const SizedBox(height: 2),
                    Text('Your changes will be sent to the Owner for approval.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textMuted(context))),
                  ],
                  const SizedBox(height: 20),
                  _fieldLabel('Customer Name'),
                  _dialogField(controller: nameController, hint: 'e.g. Juan Dela Cruz'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [_fieldLabel('Check-in'), _dialogField(controller: checkInController, hint: '8:15 AM')],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [_fieldLabel('Check-out'), _dialogField(controller: checkOutController, hint: '--')],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('Total Payment'),
                  _dialogField(controller: amountController, hint: '0', prefixText: '₱ ', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Mode of Payment'),
                            _dialogDropdown(value: method, items: methods, onChanged: (v) => setDialogState(() => method = v!)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Status'),
                            _dialogDropdown(value: status, items: _statusOptions, onChanged: (v) => setDialogState(() => status = v!)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Theme.of(context).dividerColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Cancel', style: TextStyle(color: AppTheme.heading(context), fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: _primaryButtonStyle(padding: const EdgeInsets.symmetric(vertical: 14)),
                          onPressed: () async {
                            final payload = {
                              'name': nameController.text.trim(),
                              'check_in': checkInController.text.trim(),
                              'check_out': checkOutController.text.trim().isEmpty ? '--' : checkOutController.text.trim(),
                              'amount': double.tryParse(amountController.text.trim()) ?? 0,
                              'method': method,
                              'status': status,
                            };

                            Navigator.pop(context);

                            if (CurrentUser.isOwner) {
                              final success = await AttendanceService.updateWalkIn(
                                id: r['id'],
                                name: payload['name'] as String,
                                checkIn: payload['check_in'] as String,
                                checkOut: payload['check_out'] as String,
                                amount: payload['amount'] as double,
                                method: payload['method'] as String,
                                status: payload['status'] as String,
                              );
                              if (!mounted) return;
                              if (success) {
                                _loadWalkIns();
                                _showSnack('Record updated');
                              } else {
                                _showSnack('Failed to update record', isError: true);
                              }
                            } else {
                              final result = await AttendanceService.createApprovalRequest(
                                type: 'edit',
                                targetType: 'walk_in',
                                targetId: r['id'].toString(),
                                payload: payload,
                                requestedBy: CurrentUser.fullName,
                              );
                              if (!mounted) return;
                              if (result['success'] == true) {
                                _showSnack('Edit request sent to Owner for approval.');
                              } else {
                                _showSnack(result['message'] ?? 'Failed to send request', isError: true);
                              }
                            }
                          },
                          child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onDeleteWalkIn(Map<String, dynamic> r) {
    final isOwner = CurrentUser.isOwner;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text(
          isOwner
              ? 'This will remove the walk-in record for ${r['name']} on ${r['date']}.'
              : 'This will send a delete request for ${r['name']}\'s record (${r['date']}) to the Owner for approval.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(context);

              if (isOwner) {
                final success = await AttendanceService.deleteWalkIn(r['id']);
                if (!mounted) return;
                if (success) {
                  _loadWalkIns();
                  _showSnack('Record deleted');
                } else {
                  _showSnack('Failed to delete record', isError: true);
                }
              } else {
                final result = await AttendanceService.createApprovalRequest(
                  type: 'delete',
                  targetType: 'walk_in',
                  targetId: r['id'].toString(),
                  requestedBy: CurrentUser.fullName,
                );
                if (!mounted) return;
                if (result['success'] == true) {
                  _showSnack('Delete request sent to Owner for approval.');
                } else {
                  _showSnack(result['message'] ?? 'Failed to send request', isError: true);
                }
              }
            },
            child: Text(isOwner ? 'Delete' : 'Send Request', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
