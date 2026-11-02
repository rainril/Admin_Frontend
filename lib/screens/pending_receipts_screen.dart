import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/pending_receipt_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tab_visibility.dart';

/// Review queue for manually-uploaded GCash / Maya payment receipts. An admin
/// eyeballs the receipt image against the OCR-extracted amount / reference and
/// then approves or rejects it.
///
/// Layout (Haws Prints "Review Management" style):
///   1. Three summary cards (pending / approved / amount match rate)
///   2. Pending receipts table (click a row to open the receipt + actions)
///   3. Approved payments table
class PendingReceiptsScreen extends StatefulWidget {
  const PendingReceiptsScreen({super.key});

  @override
  State<PendingReceiptsScreen> createState() => _PendingReceiptsScreenState();
}

class _PendingReceiptsScreenState extends State<PendingReceiptsScreen>
    with PollingScreenMixin<PendingReceiptsScreen> {
  bool _loading = true;
  String? _error;
  List<PendingReceipt> _receipts = [];
  List<Map<String, dynamic>> _approved = [];
  final Set<String> _actingOn = {};
  String? _expandedId;

  // Approved payments are read from the member database.
  bool _loadingApproved = true;
  bool _approvedFailed = false;

  // Refresh quietly while the tab is visible, like the other admin screens.
  @override
  Duration get pollInterval => const Duration(seconds: 30);

  @override
  void onInitialLoad() {
    _load();
    _loadApproved();
  }

  @override
  void onPoll() {
    _load(silent: true);
    _loadApproved(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await PendingReceiptService.listPendingReceipts();
      if (!mounted) return;
      setState(() {
        _receipts = list;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // A failed background poll keeps whatever list is already on screen.
        if (!silent) _error = 'Could not load pending receipts.';
      });
    }
  }

  Future<void> _loadApproved({bool silent = false}) async {
    if (!silent) setState(() => _loadingApproved = true);
    try {
      final payments = await PendingReceiptService.listApprovedPayments();
      if (mounted) setState(() { _approved = payments; _approvedFailed = false; });
    } catch (_) {
      if (mounted && _approved.isEmpty) setState(() => _approvedFailed = true);
    }
    if (mounted) setState(() => _loadingApproved = false);
  }

  Future<void> _approve(PendingReceipt r) async {
    setState(() => _actingOn.add(r.paymentId));
    final res = await PendingReceiptService.approveReceipt(r.paymentId);
    if (!mounted) return;
    setState(() => _actingOn.remove(r.paymentId));
    _toast(res.success ? 'Receipt approved.' : res.message, res.success);
    if (res.success) {
      _load(silent: true);
      _loadApproved(silent: true);
    }
  }

  Future<void> _reject(PendingReceipt r) async {
    final reason = await _askReason();
    if (reason == null) return; // dialog dismissed / cancelled
    setState(() => _actingOn.add(r.paymentId));
    final res = await PendingReceiptService.rejectReceipt(r.paymentId, reason);
    if (!mounted) return;
    setState(() => _actingOn.remove(r.paymentId));
    _toast(res.success ? 'Receipt rejected.' : res.message, res.success);
    if (res.success) _load(silent: true);
  }

  Future<String?> _askReason() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject receipt'),
        content: const Text('Reject this payment receipt?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ''),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _toast(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ),
    );
  }

  // ---------- Approved payments (Paid membership payments), newest first ----------

  List<Map> _approvedPayments() {
    final list = _approved
        .where((p) => (p['status'] ?? '').toString() == 'Paid')
        .toList();
    list.sort((a, b) {
      final da = DateTime.tryParse((a['date'] ?? '').toString());
      final db = DateTime.tryParse((b['date'] ?? '').toString());
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final approved = _approvedPayments();

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: AppSpacing.section),
            _summaryRow(approved.length),
            const SizedBox(height: AppSpacing.section),

            Text('Pending Payments', style: _sectionTitleStyle(context)),
            const SizedBox(height: 4),
            Text('Receipts waiting for your review.',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted(context))),
            const SizedBox(height: 12),
            _pendingBody(),
            const SizedBox(height: AppSpacing.section),

            Text('Approved Payments', style: _sectionTitleStyle(context)),
            const SizedBox(height: 4),
            Text('Membership payments that have been confirmed.',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted(context))),
            const SizedBox(height: 12),
            _approvedBody(approved),
          ],
        ),
      ),
    );
  }

  // ---------- Header ----------

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pending Payment Receipts',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppTheme.heading(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Review manually-uploaded GCash / Maya payment receipts and approve or reject them.',
                style: TextStyle(fontSize: 14, color: AppTheme.textMuted(context)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: _loading
              ? null
              : () {
                  _load();
                  _loadApproved();
                },
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.heading(context),
            side: BorderSide(color: AppTheme.heading(context).withValues(alpha: 0.35)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // ---------- Summary cards ----------

  Widget _summaryRow(int approvedCount) {
    final total = _receipts.length;
    final checked = _receipts.where((r) => r.ocrAmount.isNotEmpty).length;
    final matching = _receipts.where((r) => r.amountMatches).length;
    final matchRate = checked == 0 ? '—' : '${(matching * 100 / checked).round()}%';
    final waiting = _loading && _receipts.isEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryCard(
          label: 'Pending Payments',
          value: waiting ? '—' : '$total',
          caption: 'Awaiting review',
          accent: total > 0 ? AppColors.warning : null,
        ),
        const SizedBox(width: 16),
        _summaryCard(
          label: 'Approved Payments',
          value: (_loadingApproved && approvedCount == 0) || _approvedFailed ? '—' : '$approvedCount',
          caption: 'Confirmed and paid',
        ),
        const SizedBox(width: 16),
        _summaryCard(
          label: 'Amount Match Rate',
          value: waiting ? '—' : matchRate,
          caption: 'Pending receipts matching the plan price',
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required String caption,
    Color? accent,
  }) {
    return Expanded(
      child: _panel(
        context,
        accent: accent,
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppTheme.heading(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Pending receipts list ----------

  Widget _pendingBody() {
    if (_loading) {
      return _panel(
        context,
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _MessageState(
        icon: Icons.cloud_off_rounded,
        title: _error!,
        subtitle: 'Check that the backend is running, then try again.',
        action: OutlinedButton.icon(
          onPressed: () => _load(),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Retry'),
        ),
      );
    }

    if (_receipts.isEmpty) {
      return const _MessageState(
        icon: Icons.inbox_outlined,
        title: 'No pending receipts',
        subtitle:
            'Manually-uploaded payment receipts awaiting review will show up here.',
      );
    }

    return _panel(
      context,
      accent: AppColors.warning,
      child: _hScroll(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pendingHeader(),
            for (final r in _receipts)
              _ReceiptRow(
                receipt: r,
                expanded: _expandedId == r.paymentId,
                busy: _actingOn.contains(r.paymentId),
                onTap: () => setState(() =>
                    _expandedId = _expandedId == r.paymentId ? null : r.paymentId),
                onApprove: () => _approve(r),
                onReject: () => _reject(r),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pendingHeader() {
    final style = _headerStyle(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: _Cols.customer, child: Text('CUSTOMER', style: style)),
          Expanded(flex: _Cols.plan, child: Text('PLAN', style: style)),
          Expanded(flex: _Cols.method, child: Text('METHOD', style: style)),
          Expanded(flex: _Cols.submitted, child: Text('SUBMITTED', style: style)),
          Expanded(flex: _Cols.ocrAmount, child: Text('OCR AMOUNT', style: style)),
          Expanded(flex: _Cols.ocrRef, child: Text('OCR REFERENCE', style: style)),
          Expanded(flex: _Cols.type, child: Text('TYPE', style: style)),
          Expanded(flex: _Cols.check, child: Text('AMOUNT CHECK', style: style)),
          Expanded(flex: _Cols.action, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }

  // ---------- Approved payments list ----------

  Widget _approvedBody(List<Map> approved) {
    if (_approvedFailed && approved.isEmpty) {
      return _panel(context, padding: const EdgeInsets.symmetric(vertical: 40),
        child: const Center(child: Text('Could not load approved payments.')));
    }
    if (_loadingApproved && approved.isEmpty) {
      return _panel(
        context,
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('Loading...', style: TextStyle(color: AppTheme.textMuted(context))),
        ),
      );
    }

    if (approved.isEmpty) {
      return _panel(
        context,
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('No approved payments yet',
              style: TextStyle(color: AppTheme.textMuted(context))),
        ),
      );
    }

    final shown = approved.take(10).toList();
    final style = _headerStyle(context);

    return _panel(
      context,
      child: _hScroll(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
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
            ),
            for (final p in shown) _approvedRow(p),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Text(
                'Showing ${shown.length} of ${approved.length} payments',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _approvedRow(Map p) {
    final amountRaw = (p['amount'] ?? '').toString();
    final dateRaw = (p['date'] ?? '').toString();
    final bodyStyle = TextStyle(fontSize: 13, color: AppTheme.heading(context));
    final mutedStyle = TextStyle(fontSize: 13, color: AppTheme.textMuted(context));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              (p['member'] ?? '').toString(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.heading(context),
              ),
            ),
          ),
          Expanded(flex: 2, child: Text((p['plan'] ?? '').toString(), style: bodyStyle)),
          Expanded(
            flex: 2,
            child: Text(
              amountRaw.isEmpty ? '—' : _peso(amountRaw),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTheme.heading(context),
              ),
            ),
          ),
          Expanded(flex: 2, child: Text((p['method'] ?? '').toString(), style: mutedStyle)),
          Expanded(
            flex: 2,
            child: Text(dateRaw.isEmpty ? '—' : _formatDate(dateRaw), style: mutedStyle),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _badge('Paid', AppColors.successBg, AppColors.success),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared presentation helpers
// ---------------------------------------------------------------------------

class _Cols {
  static const int customer = 3;
  static const int plan = 3;
  static const int method = 2;
  static const int submitted = 3;
  static const int ocrAmount = 2;
  static const int ocrRef = 3;
  static const int type = 2;
  static const int check = 3;
  static const int action = 3;
}

TextStyle _sectionTitleStyle(BuildContext context) => TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: AppTheme.heading(context),
    );

TextStyle _headerStyle(BuildContext context) => TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: AppTheme.textMuted(context),
    );

/// White rounded card with hairline border + soft shadow. [accent] draws a
/// thin colored bar on the left edge, reserved for cards needing attention.
Widget _panel(
  BuildContext context, {
  required Widget child,
  Color? accent,
  EdgeInsetsGeometry padding = EdgeInsets.zero,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).dividerColor),
      boxShadow: dark
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

/// Keeps table columns readable on narrow windows by scrolling sideways
/// instead of squeezing the cells.
Widget _hScroll(Widget child, {double minWidth = 1100}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final w = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: w, child: child),
      );
    },
  );
}

/// Dark solid button (cyan in dark mode), replaces the gold button.
ButtonStyle _primaryStyle(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return ElevatedButton.styleFrom(
    backgroundColor: dark ? AppColors.cyan : const Color(0xFF111827),
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  );
}

// ---------------------------------------------------------------------------
// Pending receipt row (table row + expandable receipt detail)
// ---------------------------------------------------------------------------

class _ReceiptRow extends StatelessWidget {
  final PendingReceipt receipt;
  final bool expanded;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ReceiptRow({
    required this.receipt,
    required this.expanded,
    required this.busy,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final matches = receipt.amountMatches;
    final heading = AppTheme.heading(context);
    final muted = AppTheme.textMuted(context);

    final planText = receipt.planName.isEmpty
        ? '—'
        : receipt.planPrice.isEmpty
            ? receipt.planName
            : '${receipt.planName}  ·  ${_peso(receipt.planPrice)}';

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    flex: _Cols.customer,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receipt.memberName.isEmpty ? 'Unknown member' : receipt.memberName,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: heading),
                        ),
                        if (receipt.memberEmail.isNotEmpty)
                          Text(receipt.memberEmail,
                              style: TextStyle(fontSize: 12, color: muted)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: _Cols.plan,
                    child: Text(planText, style: TextStyle(fontSize: 13, color: heading)),
                  ),
                  Expanded(
                    flex: _Cols.method,
                    child: Text(
                      receipt.paymentMethod.isEmpty ? '—' : receipt.paymentMethod,
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  ),
                  Expanded(
                    flex: _Cols.submitted,
                    child: Text(_formatDate(receipt.dateSubmitted),
                        style: TextStyle(fontSize: 13, color: muted)),
                  ),
                  Expanded(
                    flex: _Cols.ocrAmount,
                    child: Text(
                      receipt.ocrAmount.isEmpty ? '—' : _peso(receipt.ocrAmount),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: heading),
                    ),
                  ),
                  Expanded(
                    flex: _Cols.ocrRef,
                    child: Text(
                      receipt.ocrReference.isEmpty ? '—' : receipt.ocrReference,
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  ),
                  Expanded(
                    flex: _Cols.type,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _purposeBadge(receipt.purpose),
                    ),
                  ),
                  Expanded(
                    flex: _Cols.check,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _badge(
                        receipt.ocrAmount.isEmpty ? 'Review manually' : (matches ? 'Amount matches' : 'Amount mismatch'),
                        receipt.ocrAmount.isEmpty ? AppColors.warningBg : (matches ? AppColors.successBg : AppColors.dangerBg),
                        receipt.ocrAmount.isEmpty ? AppColors.warning : (matches ? AppColors.success : AppColors.danger),
                        icon: receipt.ocrAmount.isEmpty ? Icons.search : (matches ? Icons.check_circle_rounded : Icons.error_rounded),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: _Cols.action,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: heading.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              expanded ? 'Hide receipt' : 'View receipt',
                              style: TextStyle(
                                color: heading,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(expanded ? Icons.expand_less : Icons.expand_more,
                                size: 18, color: heading),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) _detail(context),
        ],
      ),
    );
  }

  Widget _detail(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: AppTheme.subtleFill(context),
        border: Border(top: BorderSide(color: AppTheme.border(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 420),
              alignment: Alignment.center,
              color: AppTheme.subtleFill(context),
              child: FutureBuilder<Uint8List>(
                future: PendingReceiptService.loadReceipt(receipt.paymentId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _imgPlaceholder(context, 'Could not load receipt image');
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(40), child: CircularProgressIndicator());
                  }
                  return Image.memory(snapshot.data!, fit: BoxFit.contain);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: _primaryStyle(context),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small shared pieces
// ---------------------------------------------------------------------------

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return _panel(
      context,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppTheme.textMuted(context)),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: AppTheme.sectionTitle(context)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: AppTheme.cardSubtitle(context)),
          if (action != null) ...[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Colour-codes the payment's purpose so admin can tell at a glance whether
/// this is a brand-new member, a renewal, or a plan upgrade -- all of which
/// land in this same Pending Payments queue.
Widget _purposeBadge(String purpose) {
  Color bg;
  Color fg;
  switch (purpose) {
    case 'Renewal':
      bg = AppColors.cyan.withValues(alpha: 0.15);
      fg = AppColors.cyanDark;
      break;
    case 'Upgrade':
      bg = const Color(0xFFF3E8FF);
      fg = const Color(0xFF7C3AED);
      break;
    default:
      bg = AppColors.successBg;
      fg = AppColors.success;
  }
  return _badge(purpose, bg, fg);
}

Widget _badge(String text, Color bg, Color fg, {IconData? icon}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration:
        BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
        ],
        Text(text,
            style: TextStyle(
                color: fg, fontWeight: FontWeight.w700, fontSize: 11)),
      ],
    ),
  );
}

Widget _imgPlaceholder(BuildContext context, String msg) {
  return Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.image_not_supported_outlined,
            color: AppTheme.textMuted(context)),
        const SizedBox(height: 8),
        Text(msg, style: AppTheme.cardSubtitle(context)),
      ],
    ),
  );
}

/// Format a peso amount that may arrive as `"2400"`, `"₱2,400"` or `2400.0`.
/// Falls back to the raw string if it isn't numeric.
String _peso(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[₱,\s]'), '');
  final n = num.tryParse(cleaned);
  if (n == null) return raw;
  final isWhole = n == n.roundToDouble();
  final s = n.toStringAsFixed(isWhole ? 0 : 2);
  final parts = s.split('.');
  final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  return '₱$intPart${parts.length > 1 ? '.${parts[1]}' : ''}';
}

/// Light date formatting with a raw-string fallback (no `intl` dependency in
/// this project).
String _formatDate(String raw) {
  if (raw.isEmpty) return '—';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final d = parsed.toLocal();
  final base = '${months[d.month - 1]} ${d.day}, ${d.year}';
  if (d.hour == 0 && d.minute == 0) return base;
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  return '$base · $h:${d.minute.toString().padLeft(2, '0')} $ampm';
}
