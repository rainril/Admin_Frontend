import 'package:flutter/material.dart';
import '../services/attendance_service.dart';
import '../services/current_user.dart';
import '../theme/app_theme.dart';
import '../widgets/tab_visibility.dart';

/// Attendance page — dalawang hiwalay na listahan:
///  - Walk-in Customers: mga hindi naka-membership plan, manual check-in
///    dito, naka-store sa 'walk_ins' table
///  - Member Check-ins: mga naka-membership plan na na-scan via QR sa
///    Scan page, naka-store sa 'attendance_logs' table
class AttendancePage extends StatefulWidget {
  final VoidCallback? onGoToScan;
  const AttendancePage({super.key, this.onGoToScan});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with PollingScreenMixin<AttendancePage> {
  static const Color accent = Color(0xFF14B8C6);
  static const Color mutedText = Color(0xFF8A8F98);

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
              if (CurrentUser.isOwner) ...[
                _buildPendingApprovalsCard(),
                const SizedBox(height: AppSpacing.section),
              ],
              _buildWalkInCard(),
              const SizedBox(height: AppSpacing.section),
              _buildMemberCheckInsCard(),
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
        Text('Attendance', style: AppTheme.pageTitle(context)),
        const SizedBox(height: 6),
        Text(
          'Check in walk-in customers and record their payment.',
          style: AppTheme.pageSubtitle(context),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: widget.onGoToScan,
              icon: const Icon(Icons.qr_code_scanner, size: 18, color: accent),
              label: const Text('QR Check-In'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: const BorderSide(color: accent),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _onManualCheckIn,
              icon: const Icon(Icons.how_to_reg, size: 18, color: Colors.white),
              label: const Text('Manual Check In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
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
            Text('Pending Approvals',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: AppTheme.heading(context))),
            const SizedBox(width: 8),
            if (_pendingApprovals.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFDEBEC), borderRadius: BorderRadius.circular(20)),
                child: Text('${_pendingApprovals.length}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Staff edit/delete requests waiting for your approval.',
            style: TextStyle(fontSize: 13, color: mutedText)),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.cardDecoration(context, accent: AppColors.warning),
          clipBehavior: Clip.antiAlias,
          child: _loadingApprovals
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('Loading...', style: TextStyle(color: mutedText))),
                )
              : _pendingApprovals.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('No pending approvals.', style: TextStyle(color: mutedText))),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(
        children: [
          Icon(
            type == 'delete' ? Icons.delete_outline : Icons.edit_outlined,
            size: 18,
            color: type == 'delete' ? const Color(0xFFDC2626) : const Color(0xFFCA8A04),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.heading(context))),
                Text(description, style: const TextStyle(fontSize: 12, color: mutedText)),
                const SizedBox(height: 2),
                Text('Requested by $requestedBy', style: const TextStyle(fontSize: 11, color: mutedText)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => _onRejectApproval(a),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              side: const BorderSide(color: Color(0xFFDC2626)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('Reject'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _onApproveApproval(a),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              elevation: 0,
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
  // WALK-IN CUSTOMERS TABLE
  // ==========================================

  Widget _buildWalkInCard() {
    final filtered = _filteredWalkIns;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Walk-in Customers',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: AppTheme.heading(context))),
        const SizedBox(height: 4),
        const Text('Customers without a membership plan, checked in manually.',
            style: TextStyle(fontSize: 13, color: mutedText)),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.cardDecoration(context, accent: AppColors.cyan),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.all(16), child: _buildSearchAndFilter()),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              _buildWalkInTableHeader(),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              if (_loadingWalkIns)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('Loading...', style: TextStyle(color: mutedText))),
                )
              else if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No walk-in records found', style: TextStyle(color: mutedText))),
                )
              else
                ...filtered.asMap().entries.map((e) => _buildWalkInRow(e.value, e.key)),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text('Showing ${filtered.length} of ${_walkIns.length} records',
                    style: const TextStyle(fontSize: 13, color: mutedText)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.search, size: 18, color: mutedText),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: const InputDecoration(
                      hintText: 'Search by name...',
                      hintStyle: TextStyle(color: mutedText, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _statusFilter,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              items: ['All Status', ..._statusOptions].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _statusFilter = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWalkInTableHeader() {
    const style = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: mutedText, letterSpacing: 0.5);
    return Container(
      color: AppTheme.subtleFill(context),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('NAME', style: style)),
          Expanded(flex: 2, child: Text('DATE', style: style)),
          Expanded(flex: 2, child: Text('CHECK-IN', style: style)),
          Expanded(flex: 2, child: Text('CHECK-OUT', style: style)),
          Expanded(flex: 2, child: Text('PAYMENT', style: style)),
          Expanded(flex: 2, child: Text('METHOD', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          SizedBox(width: 80, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }

  static const Map<String, List<Color>> _statusColors = {
    'Paid': [Color(0xFFE6F7ED), Color(0xFF16A34A)],
    'Pending': [Color(0xFFFEF3E2), Color(0xFFCA8A04)],
    'Failed': [Color(0xFFFDEBEC), Color(0xFFDC2626)],
  };

  Widget _buildWalkInRow(Map<String, dynamic> r, [int index = 0]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.zebraRow(context, index),
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(r['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.heading(context)))),
          Expanded(flex: 2, child: Text(r['date'] ?? '', style: TextStyle(fontSize: 13, color: AppTheme.heading(context)))),
          Expanded(flex: 2, child: Text(r['checkIn'] ?? '--', style: TextStyle(fontSize: 13, color: AppTheme.heading(context)))),
          Expanded(flex: 2, child: Text(r['checkOut'] ?? '--', style: TextStyle(fontSize: 13, color: AppTheme.heading(context)))),
          Expanded(flex: 2, child: Text('₱${(r['amount'] ?? 0).toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.heading(context)))),
          Expanded(flex: 2, child: Text(r['method'] ?? '', style: TextStyle(fontSize: 13, color: AppTheme.heading(context)))),
          Expanded(flex: 2, child: _buildBadge(r['status'] ?? '', _statusColors)),
          SizedBox(width: 80, child: _buildWalkInActions(r)),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Map<String, List<Color>> palette) {
    final colors = palette[label] ?? [const Color(0xFFF1F1F3), mutedText];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: colors[0], borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors[1])),
    );
  }

  Widget _buildWalkInActions(Map<String, dynamic> r) {
    return Row(
      children: [
        IconButton(
          onPressed: () => _onEditWalkIn(r),
          icon: const Icon(Icons.edit_outlined, size: 18),
          color: mutedText,
          splashRadius: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () => _onDeleteWalkIn(r),
          icon: const Icon(Icons.delete_outline, size: 18),
          color: mutedText,
          splashRadius: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  // ==========================================
  // MEMBER / QR CHECK-INS TABLE (attendance_logs)
  // ==========================================

  Widget _buildMemberCheckInsCard() {
    final filtered = _filteredMemberCheckIns;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Member Check-ins',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: AppTheme.heading(context))),
        const SizedBox(height: 4),
        const Text('Members on a plan, checked in via the Scan page (QR).',
            style: TextStyle(fontSize: 13, color: mutedText)),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.cardDecoration(context, accent: AppColors.cyan),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 18, color: mutedText),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _memberSearchQuery = v),
                          decoration: const InputDecoration(
                            hintText: 'Search by member name or email...',
                            hintStyle: TextStyle(color: mutedText, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              _buildMemberTableHeader(),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              if (_loadingMemberCheckIns)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('Loading...', style: TextStyle(color: mutedText))),
                )
              else if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No member check-ins found', style: TextStyle(color: mutedText))),
                )
              else
                ...filtered.asMap().entries.map((e) => _buildMemberRow(e.value, e.key)),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text('Showing ${filtered.length} of ${_memberCheckIns.length} records',
                    style: const TextStyle(fontSize: 13, color: mutedText)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberTableHeader() {
    const style = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: mutedText, letterSpacing: 0.5);
    return Container(
      color: AppTheme.subtleFill(context),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('MEMBER', style: style)),
          Expanded(flex: 2, child: Text('DATE', style: style)),
          Expanded(flex: 2, child: Text('CHECK-IN', style: style)),
          Expanded(flex: 2, child: Text('CHECK-OUT', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
        ],
      ),
    );
  }

  static const Map<String, List<Color>> _memberStatusColors = {
    'Present': [Color(0xFFE6F7ED), Color(0xFF16A34A)],
    'Late': [Color(0xFFFEF3E2), Color(0xFFCA8A04)],
    'Absent': [Color(0xFFFDEBEC), Color(0xFFDC2626)],
  };

  Widget _buildMemberRow(Map<String, dynamic> r, [int index = 0]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.zebraRow(context, index),
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.heading(context))),
                Text(r['email'] ?? '', style: const TextStyle(fontSize: 12, color: mutedText)),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(r['date'] ?? '', style: TextStyle(fontSize: 13, color: AppTheme.heading(context)))),
          Expanded(flex: 2, child: Text(r['checkIn'] ?? '--', style: TextStyle(fontSize: 13, color: AppTheme.heading(context)))),
          Expanded(flex: 2, child: Text(r['checkOut'] ?? '--', style: TextStyle(fontSize: 13, color: AppTheme.heading(context)))),
          Expanded(flex: 2, child: _buildBadge(r['status'] ?? '', _memberStatusColors)),
        ],
      ),
    );
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
                        icon: const Icon(Icons.close, size: 20, color: mutedText),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text('Walk-in customer', style: TextStyle(fontSize: 13, color: mutedText)),
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
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

  Widget _dialogField({required TextEditingController controller, String? hint, String? prefixText, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: mutedText, fontSize: 13),
        prefixText: prefixText,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.heading(context)),
                            overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20, color: mutedText),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  if (!CurrentUser.isOwner) ...[
                    const SizedBox(height: 2),
                    const Text('Your changes will be sent to the Owner for approval.',
                        style: TextStyle(fontSize: 13, color: mutedText)),
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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