import 'package:flutter/material.dart';
import '../services/merch_sale_service.dart';
import '../theme/app_theme.dart';

/// Call this from your Merch & Price List card's "Record Sale" button:
///
/// ```dart
/// final recorded = await showRecordSaleDialog(
///   context,
///   itemId: item.id,
///   itemName: item.name,
///   price: item.price,
///   stock: item.stock,
/// );
/// if (recorded) {
///   // refresh your merch list + pending sales list here
/// }
/// ```
Future<bool> showRecordSaleDialog(
  BuildContext context, {
  required int itemId,
  required String itemName,
  required double price,
  required int stock,
}) async {
  final buyerController = TextEditingController();
  int quantity = 1;
  String method = 'Cash';
  bool submitting = false;
  String? errorText;

  const methods = ['Cash', 'GCash', 'Maya', 'Bank Transfer'];
  const accent = Color(0xFF14B8C6);
  const mutedText = Color(0xFF8A8F98);

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final total = price * quantity;
        final outOfStock = stock <= 0;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      const Text('Record Sale',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close, size: 20, color: mutedText),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(itemName, style: const TextStyle(fontSize: 13, color: mutedText)),
                  const SizedBox(height: 4),
                  Text(
                    outOfStock ? 'Out of stock' : '$stock in stock · ₱${price.toStringAsFixed(0)} each',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: outOfStock ? Colors.red : mutedText,
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text('Quantity',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _qtyButton(
                        context: context,
                        icon: Icons.remove,
                        onTap: quantity > 1
                            ? () => setDialogState(() => quantity--)
                            : null,
                      ),
                      Container(
                        width: 56,
                        alignment: Alignment.center,
                        child: Text('$quantity',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      _qtyButton(
                        context: context,
                        icon: Icons.add,
                        onTap: quantity < stock
                            ? () => setDialogState(() => quantity++)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text('Buyer Name (optional)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: buyerController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Juan Dela Cruz — leave blank for Walk-in',
                      hintStyle: const TextStyle(fontSize: 12, color: mutedText),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: accent)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Payment Method',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    items: methods
                        .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setDialogState(() => method = v!),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('₱${total.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accent)),
                      ],
                    ),
                  ),

                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],

                  const SizedBox(height: 20),
                  const Text(
                    "This will be saved as Pending — stock won't change until you confirm it.",
                    style: TextStyle(fontSize: 11, color: mutedText, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: submitting ? null : () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Theme.of(context).dividerColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (outOfStock || submitting)
                              ? null
                              : () async {
                                  setDialogState(() {
                                    submitting = true;
                                    errorText = null;
                                  });

                                  final result = await MerchSaleService.recordSale(
                                    itemId: itemId,
                                    quantity: quantity,
                                    buyerName: buyerController.text.trim().isEmpty
                                        ? null
                                        : buyerController.text.trim(),
                                    paymentMethod: method,
                                  );

                                  if (!context.mounted) return;

                                  if (result.success) {
                                    Navigator.pop(context, true);
                                  } else {
                                    setDialogState(() {
                                      submitting = false;
                                      errorText = result.message;
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: submitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Record Sale', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  return result ?? false;
}

Widget _qtyButton({required BuildContext context, required IconData icon, required VoidCallback? onTap}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: onTap == null ? const Color(0xFFC5C9D1) : AppTheme.heading(context)),
    ),
  );
}
