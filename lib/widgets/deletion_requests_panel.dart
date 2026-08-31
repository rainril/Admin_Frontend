import 'package:flutter/material.dart';
import '../services/deletion_request_service.dart';
import '../theme/app_theme.dart';

/// Only meant to be shown when CurrentUser.isOwner is true — check that in
/// the parent screen before rendering this widget. Staff should never see
/// this panel (they only see the effect: their "Remove" click now shows a
/// "sent for approval" message instead of actually deleting).
///
/// ```dart
/// if (CurrentUser.isOwner)
///   DeletionRequestsPanel(key: _deletionPanelKey),
/// ```
class DeletionRequestsPanel extends StatefulWidget {
  const DeletionRequestsPanel({super.key});

  @override
  State<DeletionRequestsPanel> createState() => DeletionRequestsPanelState();
}

class DeletionRequestsPanelState extends State<DeletionRequestsPanel> {
  static const Color mutedText = Color(0xFF8A8F98);

  List<DeletionRequestItem> _pending = [];
  bool _loading = true;
  final Set<int> _actingOn = {};

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => _loading = true);
    final list = await DeletionRequestService.fetchRequests(status: 'Pending');
    if (!mounted) return;
    setState(() {
      _pending = list;
      _loading = false;
    });
  }

  Future<void> _approve(DeletionRequestItem req) async {
    setState(() => _actingOn.add(req.id));
    final result = await DeletionRequestService.approve(req.id);
    if (!mounted) return;
    setState(() => _actingOn.remove(req.id));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), backgroundColor: result.success ? null : Colors.red.shade600),
    );

    if (result.success) refresh();
  }

  Future<void> _reject(DeletionRequestItem req) async {
    setState(() => _actingOn.add(req.id));
    final result = await DeletionRequestService.reject(req.id);
    if (!mounted) return;
    setState(() => _actingOn.remove(req.id));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), backgroundColor: result.success ? null : Colors.red.shade600),
    );

    if (result.success) refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _pending.isEmpty) {
      // Nothing pending — stay out of the way instead of showing an empty card.
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.section),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: const Color(0xFFFCA5A5)),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? null
            : const [BoxShadow(color: Color(0x0D111827), blurRadius: 12, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      'Removal Requests Awaiting Your Approval (${_pending.length})',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh, size: 18, color: mutedText),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final req in _pending) _requestRow(req),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _requestRow(DeletionRequestItem req) {
    final busy = _actingOn.contains(req.id);
    final typeLabel = req.itemType == 'merch' ? 'Merch' : 'Equipment';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: AppTheme.heading(context)),
                children: [
                  TextSpan(text: req.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(
                    text: '  ($typeLabel)${req.requestedBy != null ? " · requested by ${req.requestedBy}" : ""}',
                    style: const TextStyle(color: mutedText, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          if (busy)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () => _reject(req),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: mutedText,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Reject', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _approve(req),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Approve & Remove', style: TextStyle(fontSize: 12, color: Colors.white)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
