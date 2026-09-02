import 'package:flutter/material.dart';
import '../services/pending_receipt_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tab_visibility.dart';

/// Review queue for manually-uploaded GCash / Maya payment receipts. An admin
/// eyeballs the receipt image against the OCR-extracted amount / reference and
/// then approves or rejects it.
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
  final Set<String> _actingOn = {};
  String? _expandedId;

  // Refresh quietly while the tab is visible, like the other admin screens.
  @override
  Duration get pollInterval => const Duration(seconds: 30);

  @override
  void onInitialLoad() => _load();

  @override
  void onPoll() => _load(silent: true);

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

  Future<void> _approve(PendingReceipt r) async {
    setState(() => _actingOn.add(r.paymentId));
    final res = await PendingReceiptService.approveReceipt(r.paymentId);
    if (!mounted) return;
    setState(() => _actingOn.remove(r.paymentId));
    _toast(res.success ? 'Receipt approved.' : res.message, res.success);
    if (res.success) _load(silent: true);
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
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject receipt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add an optional reason for rejecting this payment receipt.',
              style: AppTheme.cardSubtitle(context),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. amount does not match the plan price',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pending Payment Receipts',
                          style: AppTheme.pageTitle(context)),
                      const SizedBox(height: 6),
                      Text(
                        'Review manually-uploaded GCash / Maya payment receipts and approve or reject them.',
                        style: AppTheme.pageSubtitle(context),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : () => _load(),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.section),
            _body(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator()),
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

    return Column(
      children: [
        for (final r in _receipts) ...[
          _ReceiptCard(
            receipt: r,
            expanded: _expandedId == r.paymentId,
            busy: _actingOn.contains(r.paymentId),
            onTap: () => setState(() => _expandedId =
                _expandedId == r.paymentId ? null : r.paymentId),
            onApprove: () => _approve(r),
            onReject: () => _reject(r),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Receipt card
// ---------------------------------------------------------------------------

class _ReceiptCard extends StatelessWidget {
  final PendingReceipt receipt;
  final bool expanded;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ReceiptCard({
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

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: AppTheme.cardDecoration(context, accent: AppColors.cyan),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.card),
              child: Column(
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
                              receipt.memberName.isEmpty
                                  ? 'Unknown member'
                                  : receipt.memberName,
                              style: AppTheme.sectionTitle(context),
                            ),
                            if (receipt.memberEmail.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(receipt.memberEmail,
                                  style: AppTheme.cardSubtitle(context)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _badge(
                        matches ? 'Amount matches' : 'Amount mismatch',
                        matches ? AppColors.successBg : AppColors.dangerBg,
                        matches ? AppColors.success : AppColors.danger,
                        icon: matches
                            ? Icons.check_circle_rounded
                            : Icons.error_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 28,
                    runSpacing: 14,
                    children: [
                      _field(
                        context,
                        'Plan',
                        receipt.planName.isEmpty
                            ? '—'
                            : receipt.planPrice.isEmpty
                                ? receipt.planName
                                : '${receipt.planName}  ·  ${_peso(receipt.planPrice)}',
                      ),
                      _field(
                        context,
                        'Method',
                        receipt.paymentMethod.isEmpty
                            ? '—'
                            : receipt.paymentMethod,
                      ),
                      _field(context, 'Submitted',
                          _formatDate(receipt.dateSubmitted)),
                      _field(
                        context,
                        'OCR amount',
                        receipt.ocrAmount.isEmpty
                            ? '—'
                            : _peso(receipt.ocrAmount),
                      ),
                      _field(
                        context,
                        'OCR reference',
                        receipt.ocrReference.isEmpty ? '—' : receipt.ocrReference,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        expanded ? 'Hide receipt' : 'View receipt',
                        style: const TextStyle(
                          color: AppColors.cyanDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Icon(expanded ? Icons.expand_less : Icons.expand_more,
                          size: 18, color: AppColors.cyanDark),
                    ],
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
              color: Colors.black.withValues(alpha: 0.04),
              child: receipt.receiptImageUrl.isEmpty
                  ? _imgPlaceholder(context, 'No receipt image provided')
                  : Image.network(
                      receipt.receiptImageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (c, child, progress) => progress == null
                          ? child
                          : const Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(),
                            ),
                      errorBuilder: (c, e, s) =>
                          _imgPlaceholder(context, 'Could not load receipt image'),
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
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 18, color: Colors.white),
                    label: const Text('Approve',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B4D8),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      decoration: AppTheme.cardDecoration(context),
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

Widget _field(BuildContext context, String label, String value) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppTheme.textMuted(context),
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppTheme.heading(context),
        ),
      ),
    ],
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
