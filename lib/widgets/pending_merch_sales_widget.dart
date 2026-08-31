import 'package:flutter/material.dart';
import '../services/merch_sale_service.dart';
import '../theme/app_theme.dart';

/// Drop this widget into your Merch & Price List tab, below the merch cards.
/// It manages its own data fetching/refresh. Pass [onSaleConfirmed] so the
/// parent page can re-fetch merch item stock/sold/revenue after a confirm
/// (since that's what actually changes those numbers).
///
/// ```dart
/// MerchSalesPanel(
///   onSaleConfirmed: () => _loadMerchItems(), // whatever refreshes your cards
/// )
/// ```
class MerchSalesPanel extends StatefulWidget {
  final VoidCallback? onSaleConfirmed;
  const MerchSalesPanel({super.key, this.onSaleConfirmed});

  @override
  State<MerchSalesPanel> createState() => MerchSalesPanelState();
}

class MerchSalesPanelState extends State<MerchSalesPanel> {
  static const Color accent = Color(0xFF14B8C6);
  static const Color mutedText = Color(0xFF8A8F98);

  List<MerchSale> _pending = [];
  List<MerchSale> _recent = [];
  bool _loading = true;
  final Set<int> _actingOn = {}; // sale ids currently being confirmed/voided

  @override
  void initState() {
    super.initState();
    refresh();
  }

  /// Public so the parent page can call `_panelKey.currentState?.refresh()`
  /// after recording a new sale, or you can just re-mount this widget.
  Future<void> refresh() async {
    setState(() => _loading = true);
    final pending = await MerchSaleService.fetchSales(status: 'Pending');
    final completed = await MerchSaleService.fetchSales(status: 'Completed');
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _recent = completed.take(10).toList();
      _loading = false;
    });
  }

  Future<void> _confirm(MerchSale sale) async {
    setState(() => _actingOn.add(sale.id));
    final result = await MerchSaleService.confirmSale(sale.id);
    if (!mounted) return;
    setState(() => _actingOn.remove(sale.id));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? null : Colors.red.shade600,
      ),
    );

    if (result.success) {
      await refresh();
      widget.onSaleConfirmed?.call();
    }
  }

  Future<void> _void(MerchSale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void this sale?'),
        content: Text(
            '${sale.itemName} × ${sale.quantity} for ${sale.buyerName} — this cancels the sale with no effect on stock.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Void', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _actingOn.add(sale.id));
    final result = await MerchSaleService.voidSale(sale.id);
    if (!mounted) return;
    setState(() => _actingOn.remove(sale.id));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message.isEmpty ? 'Sale voided.' : result.message),
        backgroundColor: result.success ? null : Colors.red.shade600,
      ),
    );

    if (result.success) await refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pendingSalesCard(),
        const SizedBox(height: AppSpacing.section),
        _recentSalesCard(),
      ],
    );
  }

  Widget _pendingSalesCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: AppTheme.cardDecoration(context, accent: AppColors.warning),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Pending Sales', style: AppTheme.sectionTitle(context)),
                    if (_pending.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3E2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${_pending.length}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFCA8A04))),
                      ),
                    ],
                  ],
                ),
                IconButton(
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh, size: 20, color: mutedText),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_pending.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('No pending sales awaiting confirmation.', style: TextStyle(color: mutedText)),
              ),
            )
          else
            for (final sale in _pending) _pendingRow(sale),
        ],
      ),
    );
  }

  Widget _pendingRow(MerchSale sale) {
    final busy = _actingOn.contains(sale.id);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sale.itemName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('${sale.buyerName} · ${sale.paymentMethod}',
                    style: const TextStyle(fontSize: 12, color: mutedText)),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text('× ${sale.quantity}', style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: Text('₱${sale.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () => _void(sale),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Void', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _confirm(sale),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Confirm', style: TextStyle(fontSize: 12, color: Colors.white)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _recentSalesCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: AppTheme.cardDecoration(context, accent: AppColors.success),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text('Recent Sales', style: AppTheme.sectionTitle(context)),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No confirmed sales yet.', style: TextStyle(color: mutedText))),
            )
          else
            for (final sale in _recent) _recentRow(sale),
        ],
      ),
    );
  }

  Widget _recentRow(MerchSale sale) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(sale.itemName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(flex: 2, child: Text(sale.buyerName, style: const TextStyle(fontSize: 12, color: mutedText))),
          Expanded(flex: 1, child: Text('× ${sale.quantity}', style: const TextStyle(fontSize: 12))),
          Expanded(
            flex: 2,
            child: Text('₱${sale.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          Expanded(flex: 2, child: Text(sale.date, style: const TextStyle(fontSize: 12, color: mutedText))),
        ],
      ),
    );
  }
}
