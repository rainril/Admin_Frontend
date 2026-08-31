import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../services/merch_item_service.dart';
import '../services/equipment_item_service.dart';
import '../services/deletion_request_service.dart';
import '../services/current_user.dart';
import '../services/merch_sale_service.dart';
import '../services/dashboard_analytics_service.dart' show ChartSeries;
import '../widgets/record_sale_dialog.dart';
import '../widgets/pending_merch_sales_widget.dart';
import '../widgets/deletion_requests_panel.dart';
import '../widgets/tab_visibility.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with PollingScreenMixin<InventoryScreen> {
  int _selectedTab = 0; // 0: Equipment, 1: Products & Price List, 2: Revenue Statistics
  String _equipmentFilter = 'All';
  String _revenueTimeframe = 'Daily';

  // --- EQUIPMENT: now backed by the real API ---
  List<EquipmentItem> _equipmentItems = [];
  bool _loadingEquipment = true;
  int _equipTotalQty = 0;
  int _equipAvailableQty = 0;
  int _equipMaintenanceQty = 0;
  int _equipDamagedQty = 0;

  // --- MERCH: now backed by the real API ---
  List<MerchItem> _merchItems = [];
  bool _loadingMerch = true;
  double _merchTotalRevenue = 0;
  int _merchTotalUnitsSold = 0;

  // --- MERCH REVENUE ANALYTICS: real chart data from confirmed sales ---
  ChartSeries? _merchRevenueSeries;
  bool _loadingMerchRevenueAnalytics = true;

  final GlobalKey<MerchSalesPanelState> _merchSalesPanelKey = GlobalKey<MerchSalesPanelState>();

  // Inventory data is refetched by its own add/edit/remove/sale actions, so
  // it only needs a load the first time the tab is opened — no polling, and
  // no reload on every return (that would flash the loading spinners).
  @override
  Duration get pollInterval => Duration.zero;

  @override
  void onInitialLoad() {
    _loadMerchItems();
    _loadEquipmentItems();
    _loadMerchRevenueAnalytics();
  }

  @override
  void onPoll() {}

  Future<void> _loadMerchItems() async {
    setState(() => _loadingMerch = true);
    final result = await MerchItemService.fetchItems();
    if (!mounted) return;
    setState(() {
      _merchItems = result.items;
      _merchTotalRevenue = result.totalRevenue;
      _merchTotalUnitsSold = result.totalUnitsSold;
      _loadingMerch = false;
    });
  }

  Future<void> _loadEquipmentItems() async {
    setState(() => _loadingEquipment = true);
    final result = await EquipmentItemService.fetchItems();
    if (!mounted) return;
    setState(() {
      _equipmentItems = result.items;
      _equipTotalQty = result.totalQty;
      _equipAvailableQty = result.availableQty;
      _equipMaintenanceQty = result.maintenanceQty;
      _equipDamagedQty = result.damagedQty;
      _loadingEquipment = false;
    });
  }

  Future<void> _loadMerchRevenueAnalytics() async {
    setState(() => _loadingMerchRevenueAnalytics = true);
    final series = await MerchSaleService.fetchRevenueAnalytics(_revenuePeriodParam(_revenueTimeframe));
    if (!mounted) return;
    setState(() {
      _merchRevenueSeries = series;
      _loadingMerchRevenueAnalytics = false;
    });
  }

  String _revenuePeriodParam(String timeframe) {
    switch (timeframe) {
      case 'Weekly':
        return 'weekly';
      case 'Monthly':
        return 'monthly';
      case 'Annual':
        return 'annual';
      case 'Daily':
      default:
        return 'daily';
    }
  }

  // --- GETTERS FOR REAL-TIME STATS (Equipment) ---
  int get totalEquipmentQty => _equipTotalQty;
  int get availableCount => _equipAvailableQty;
  int get maintenanceCount => _equipMaintenanceQty;
  int get damagedCount => _equipDamagedQty;

  // --- GETTERS FOR REAL-TIME STATS (Merch) ---
  int get totalProductsCount => _merchItems.length;
  int get totalProductRevenue => _merchTotalRevenue.round();
  int get totalUnitsSold => _merchTotalUnitsSold;

  String _formatNumber(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatCurrency(int value) {
    return '₱${_formatNumber(value)}';
  }

  String _formatChartValue(double v) {
    if (v == 0) return '₱0';
    if (v >= 1000000) return '₱${(v / 1000000).toStringAsFixed(1)}m';
    if (v >= 1000) return '₱${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
    return '₱${v.toInt()}';
  }

  // Local fallback images for the merch items you already have bundled in
  // assets/merch/. Add an entry here whenever you add a new SKU, or set
  // that item's image_url in the database instead once you have real
  // product photos to host.
  static const Map<String, String> _localMerchImages = {
    'MC-001-TSH': 'assets/merch/tshirt.png',
    'MC-002-SSL': 'assets/merch/sando_sleeveless.png',
    'MC-003-SMT': 'assets/merch/sando_muscle_tee.png',
  };

  // ==========================================
  // MERCH ACTIONS (now hit the real API)
  // ==========================================

  void _showEditProductPriceDialog(MerchItem product) {
    final priceController = TextEditingController(text: product.price.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Change Price'),
          content: TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Price (₱)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final parsedPrice = double.tryParse(priceController.text);
                if (parsedPrice == null) return;
                Navigator.pop(dialogContext);
                final ok = await MerchItemService.updatePrice(product.id, parsedPrice);
                if (!mounted) return;
                if (ok) {
                  _loadMerchItems();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to update price.'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.inventoryPrimary),
              child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeProduct(MerchItem product) async {
    if (!CurrentUser.isOwner) {
      // Staff: don't delete directly — send a request for the owner to approve.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Request removal?'),
          content: Text(
              'This will send a request to the owner to remove "${product.name}". It will stay in your list until approved.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.inventoryPrimary),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send Request', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final result = await DeletionRequestService.requestDeletion(
        itemType: 'merch',
        itemId: product.id,
        itemName: product.name,
        requestedBy: 'Staff',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: result.success ? null : Colors.red.shade600),
      );
      return;
    }

    // Owner: deletes immediately, same as before.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove item?'),
        content: Text('This will remove "${product.name}" from your merch list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await MerchItemService.removeItem(product.id);
    if (!mounted) return;

    if (result.success) {
      _loadMerchItems();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message.isEmpty ? 'Failed to remove item.' : result.message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _recordSaleForProduct(MerchItem product) async {
    final recorded = await showRecordSaleDialog(
      context,
      itemId: product.id,
      itemName: product.name,
      price: product.price,
      stock: product.stock,
    );

    if (recorded) {
      // Stock/sold/revenue only actually change once staff CONFIRMS the
      // pending sale (see MerchSalesPanel below), but we refresh the item
      // list anyway in case anything else changed.
      _loadMerchItems();
      _merchSalesPanelKey.currentState?.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale recorded as pending — confirm it below to update stock.')),
        );
      }
    }
  }

  // --- MODAL FUNCTIONS ---
  void _showAddEquipmentDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final qtyController = TextEditingController(text: '0');
    String? nameError;
    bool submitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.all(24),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Add Equipment', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Equipment Name', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Treadmill Pro X',
                        errorText: nameError,
                      ),
                      onChanged: (_) {
                        if (nameError != null) setDialogState(() => nameError = null);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Equipment Description', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Brief description of the equipment',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Quantity / Stock', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(controller: qtyController, keyboardType: TextInputType.number),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            child: Text('Cancel', style: TextStyle(color: AppTheme.heading(context))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: submitting
                                ? null
                                : () async {
                              if (nameController.text.trim().isEmpty) {
                                setDialogState(() => nameError = 'Equipment name is required');
                                return;
                              }
                              setDialogState(() => submitting = true);

                              // The backend still requires a unique barcode even
                              // though this form no longer asks for one — mint it
                              // silently rather than surfacing it to the user.
                              final autoBarcode = 'EQ-${DateTime.now().millisecondsSinceEpoch}';
                              final added = await EquipmentItemService.addItem(
                                barcode: autoBarcode,
                                name: nameController.text.trim(),
                                category: 'General',
                                qty: int.tryParse(qtyController.text) ?? 0,
                                description: descriptionController.text.trim().isEmpty
                                    ? null
                                    : descriptionController.text.trim(),
                              );
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              if (added) {
                                nameController.clear();
                                descriptionController.clear();
                                qtyController.text = '0';
                                setState(() => _selectedTab = 0);
                                _loadEquipmentItems();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to add equipment.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.inventoryPrimary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            child: const Text('Add Equipment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddMerchDialog() {
    final nameController = TextEditingController();
    final barcodeController = TextEditingController();
    final priceController = TextEditingController(text: '0');
    final stockController = TextEditingController(text: '0');
    String? nameError;
    String? barcodeError;
    bool submitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.all(24),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Add Merch', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Merch Name', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'Item name',
                        errorText: nameError,
                      ),
                      onChanged: (_) {
                        if (nameError != null) setDialogState(() => nameError = null);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Barcode', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: barcodeController,
                      decoration: InputDecoration(
                        hintText: 'e.g., PD-009-XYZ',
                        errorText: barcodeError,
                      ),
                      onChanged: (_) {
                        if (barcodeError != null) setDialogState(() => barcodeError = null);
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Price (₱)', style: TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              TextField(controller: priceController, keyboardType: TextInputType.number),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Opening Stock', style: TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              TextField(controller: stockController, keyboardType: TextInputType.number),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            child: Text('Cancel', style: TextStyle(color: AppTheme.heading(context))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: submitting
                                ? null
                                : () async {
                              final missingName = nameController.text.trim().isEmpty;
                              final missingBarcode = barcodeController.text.trim().isEmpty;
                              if (missingName || missingBarcode) {
                                setDialogState(() {
                                  nameError = missingName ? 'Merch name is required' : null;
                                  barcodeError = missingBarcode ? 'Barcode is required' : null;
                                });
                                return;
                              }
                              setDialogState(() => submitting = true);

                              final added = await MerchItemService.addItem(
                                sku: barcodeController.text.trim(),
                                name: nameController.text.trim(),
                                price: double.tryParse(priceController.text) ?? 0,
                                stock: int.tryParse(stockController.text) ?? 0,
                              );
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              if (added) {
                                nameController.clear();
                                barcodeController.clear();
                                priceController.text = '0';
                                stockController.text = '0';
                                _loadMerchItems();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to add merch — check that the barcode is unique.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.inventoryPrimary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            child: const Text('Add Merch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Inventory Management', style: AppTheme.pageTitle(context)),
              const SizedBox(height: 6),
              Text('Equipment, products, and revenue tracking', style: AppTheme.pageSubtitle(context)),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          if (CurrentUser.isOwner) const DeletionRequestsPanel(),
          Row(
            children: [
              _buildTabButton(0, Icons.fitness_center, 'Equipment'),
              _buildTabButton(1, Icons.checkroom_outlined, 'Merch & Price List'),
              _buildTabButton(2, Icons.bar_chart, 'Revenue Statistics'),
            ],
          ),
          Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero).animate(animation),
                  child: child,
                ),
              );
            },
            child: _selectedTab == 0
                ? KeyedSubtree(
                    key: const ValueKey<int>(0),
                    child: _buildEquipmentContent(),
                  )
                : _selectedTab == 1
                    ? KeyedSubtree(
                        key: const ValueKey<int>(1),
                        child: _buildProductsContent(),
                      )
                    : KeyedSubtree(
                        key: const ValueKey<int>(2),
                        child: _buildRevenueContent(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, IconData icon, String label) {
    bool isSelected = _selectedTab == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isSelected ? AppColors.inventoryPrimary : Colors.transparent,
            width: 2.5,
          ),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        onTap: () => setState(() => _selectedTab = index),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.inventoryPrimary : Colors.grey[500],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.inventoryPrimary : Colors.grey[600],
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditEquipmentDialog(EquipmentItem equipment) {
    String status = equipment.status;
    final qtyController = TextEditingController(text: equipment.qty.toString());
    final locationController = TextEditingController(text: equipment.location ?? '');

    const statusOptions = ['Available', 'Maintenance', 'Damaged'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Edit — ${equipment.name}'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      isExpanded: true,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: statusOptions
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => status = v!),
                    ),
                    const SizedBox(height: 16),
                    const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    const Text('Location', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'e.g. Weight Room',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.inventoryPrimary),
                  onPressed: () async {
                    final ok = await EquipmentItemService.updateItem(
                      equipment.id,
                      status: status,
                      qty: int.tryParse(qtyController.text),
                      location: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    if (ok) {
                      _loadEquipmentItems();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to update equipment.'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _markEquipmentForMaintenance(EquipmentItem equipment) async {
    final result = await EquipmentItemService.markForMaintenance(equipment.id);
    if (!mounted) return;
    if (result.success) {
      _loadEquipmentItems();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message.isEmpty ? 'Failed to update status.' : result.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _removeEquipment(EquipmentItem equipment) async {
    if (!CurrentUser.isOwner) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Request removal?'),
          content: Text(
              'This will send a request to the owner to remove "${equipment.name}". It will stay in your inventory until approved.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.inventoryPrimary),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send Request', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final result = await DeletionRequestService.requestDeletion(
        itemType: 'equipment',
        itemId: equipment.id,
        itemName: equipment.name,
        requestedBy: 'Staff',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: result.success ? null : Colors.red.shade600),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove equipment?'),
        content: Text('This will remove "${equipment.name}" from your inventory.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await EquipmentItemService.removeItem(equipment.id);
    if (!mounted) return;
    if (result.success) {
      _loadEquipmentItems();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message.isEmpty ? 'Failed to remove equipment.' : result.message), backgroundColor: Colors.red),
      );
    }
  }

  // ==========================================
  // TAB 1: EQUIPMENT (now real API data, image + description cards)
  // ==========================================
  Widget _buildEquipmentContent() {
    final filtered = _equipmentItems
        .where((e) => _equipmentFilter == 'All' || e.status == _equipmentFilter)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          double cardWidth = (constraints.maxWidth - 48) / 4;
          return Wrap(
            spacing: 16, runSpacing: 16,
            children: [              
              _buildStatCard('Total Equipment', totalEquipmentQty.toString(), Icons.widgets_outlined, AppColors.inventoryPrimary.withValues(alpha: 0.1), AppColors.inventoryPrimary, cardWidth),
              _buildStatCard('Available', availableCount.toString(), Icons.check_circle_outline, const Color(0xFFE8F5E9), Colors.green, cardWidth),
              _buildStatCard('In Maintenance', maintenanceCount.toString(), Icons.build_outlined, const Color(0xFFFFF3E0), Colors.orange, cardWidth),
              _buildStatCard('Damaged', damagedCount.toString(), Icons.cancel_outlined, const Color(0xFFFFEBEE), Colors.red, cardWidth),
            ],
          );
        }),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['All', 'Available', 'Maintenance', 'Damaged'].map((filter) {
                  bool isSelected = _equipmentFilter == filter;
                  return ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: AppColors.inventoryPrimary,
                    backgroundColor: Theme.of(context).cardColor,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.heading(context)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey[300]!)),
                    onSelected: (selected) { if (selected) setState(() => _equipmentFilter = filter); },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _showAddEquipmentDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Equipment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.inventoryPrimary, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loadingEquipment)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('No equipment found for this filter.', style: TextStyle(color: Colors.grey[600])),
            ),
          )
        else
          LayoutBuilder(builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth >= 1100
                ? 4
                : constraints.maxWidth >= 800
                    ? 3
                    : constraints.maxWidth >= 500
                        ? 2
                        : 1;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.58,
              children: filtered.map((e) => _buildEquipmentCard(e)).toList(),
            );
          }),
      ],
    );
  }

  Widget _buildEquipmentCard(EquipmentItem e) {
    Color sColor = Colors.green; Color sBg = const Color(0xFFE8F5E9); IconData sIcon = Icons.check_circle_outline;
    if (e.status == 'Maintenance') { sColor = Colors.orange; sBg = const Color(0xFFFFF3E0); sIcon = Icons.build_outlined; }
    if (e.status == 'Damaged') { sColor = Colors.red; sBg = const Color(0xFFFFEBEE); sIcon = Icons.cancel_outlined; }

    return Container(
      decoration: AppTheme.cardDecoration(context, accent: sColor),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.4,
            child: Container(
              color: const Color(0xFFF8FAFC),
              child: (e.imageUrl != null && e.imageUrl!.isNotEmpty)
                  ? Image.asset(
                      e.imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stack) =>
                          const Icon(Icons.fitness_center, size: 40, color: Colors.grey),
                    )
                  : const Icon(Icons.fitness_center, size: 40, color: Colors.grey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(e.barcode, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.inventoryPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(e.category, style: const TextStyle(color: AppColors.inventoryPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: sBg, borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(sIcon, size: 12, color: sColor),
                        const SizedBox(width: 3),
                        Text(e.status, style: TextStyle(color: sColor, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Qty: ${e.qty}${e.location != null && e.location!.isNotEmpty ? ' • ${e.location}' : ''}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
                if (e.description != null && e.description!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    e.description!,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showEditEquipmentDialog(e),
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(vertical: 8)),
                        child: Text('Edit', style: TextStyle(color: AppTheme.heading(context), fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _markEquipmentForMaintenance(e),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFF8E1), elevation: 0, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(vertical: 8)),
                        child: const Text('Maintain', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _removeEquipment(e),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFEBEE), elevation: 0, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(vertical: 8)),
                    child: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: MERCH (now real API data + sales flow)
  // ==========================================
  Widget _buildProductsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          double cardWidth = (constraints.maxWidth - 32) / 3;
          return Wrap(
            spacing: 16, runSpacing: 16,
            children: [
              _buildStatCard('Total Merch Items', totalProductsCount.toString(), Icons.checkroom_outlined, AppColors.inventoryPrimary.withValues(alpha: 0.1), AppColors.inventoryPrimary, cardWidth),
              _buildStatCard('Total Merch Revenue', _formatCurrency(totalProductRevenue), Icons.attach_money, AppColors.inventoryPrimary.withValues(alpha: 0.1), AppColors.inventoryPrimary, cardWidth),
              _buildStatCard('Total Units Sold', totalUnitsSold.toString(), Icons.local_offer_outlined, AppColors.inventoryPrimary.withValues(alpha: 0.1), AppColors.inventoryPrimary, cardWidth),
            ],
          );
        }),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Merch & Price List', style: AppTheme.sectionTitle(context)),
            ElevatedButton.icon(
              onPressed: _showAddMerchDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.inventoryPrimary, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingMerch)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_merchItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('No merch items yet. Use "Add Item" to create one.', style: TextStyle(color: Colors.grey[600])),
            ),
          )
        else
          LayoutBuilder(builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 600
                    ? 2
                    : 1;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.68,
              children: _merchItems.map((p) => _buildMerchCard(p)).toList(),
            );
          }),
        const SizedBox(height: 24),
        MerchSalesPanel(
          key: _merchSalesPanelKey,
          onSaleConfirmed: () {
            // Stock/sold/revenue on the item list AND the revenue chart
            // both actually change once a sale is confirmed.
            _loadMerchItems();
            _loadMerchRevenueAnalytics();
          },
        ),
      ],
    );
  }

  Widget _buildMerchImage(MerchItem p) {
    if (p.imageUrl != null && p.imageUrl!.isNotEmpty) {
      return Image.network(
        p.imageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => _merchImageFallback(p.sku),
      );
    }
    return _merchImageFallback(p.sku);
  }

  Widget _merchImageFallback(String sku) {
    final localPath = _localMerchImages[sku];
    if (localPath != null) {
      return Image.asset(
        localPath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) =>
            const Icon(Icons.checkroom_outlined, size: 48, color: Colors.grey),
      );
    }
    return const Icon(Icons.checkroom_outlined, size: 48, color: Colors.grey);
  }

  Widget _buildMerchCard(MerchItem p) {
    bool isLow = p.stock <= 15;
    return Container(
      decoration: AppTheme.cardDecoration(context,
          accent: isLow ? AppColors.warning : AppColors.inventoryPrimary),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.4,
            child: Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.all(12),
              child: _buildMerchImage(p),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(p.sku, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatCurrency(p.price.round()),
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'Stock: ${p.stock}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isLow ? Colors.red : Colors.grey[700],
                        fontWeight: isLow ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Sold: ${p.sold}  •  Revenue: ${_formatCurrency(p.revenue.round())}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: p.stock <= 0 ? null : () => _recordSaleForProduct(p),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.inventoryPrimary,
                      elevation: 0,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      p.stock <= 0 ? 'Out of Stock' : 'Record Sale',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showEditProductPriceDialog(p),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text('Edit Price', style: TextStyle(color: AppTheme.heading(context), fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _removeProduct(p),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFEBEE),
                          elevation: 0,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: REVENUE — real merch revenue chart
  // (built from confirmed merch_sales only, via /merch-sales/revenue-analytics)
  // ==========================================
  Widget _buildRevenueContent() {
    final series = _merchRevenueSeries;
    final labels = series?.labels ?? const <String>[];
    final values = series?.values ?? const <double>[];
    final maxRaw = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    final maxY = maxRaw > 0 ? maxRaw * 1.2 : 1.0;
    final interval = maxRaw > 0 ? maxRaw / 5 : 1.0;
    final totalForPeriod = values.fold<double>(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: ['Daily', 'Weekly', 'Monthly', 'Annual'].map((timeframe) {
            bool isSelected = _revenueTimeframe == timeframe;
            return Container(
              margin: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(timeframe),
                selected: isSelected,
                selectedColor: AppColors.inventoryPrimary,
                backgroundColor: Theme.of(context).cardColor,
                labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.heading(context)),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _revenueTimeframe = timeframe);
                    _loadMerchRevenueAnalytics();
                  }
                },
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.card),
          decoration: AppTheme.cardDecoration(context, accent: AppColors.inventoryPrimary),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Merch Revenue', style: AppTheme.sectionTitle(context)),
                      const SizedBox(height: 3),
                      Text('From confirmed merch sales only',
                          style: AppTheme.cardSubtitle(context)),
                    ],
                  ),
                  Text(
                    _loadingMerchRevenueAnalytics ? '—' : _formatCurrency(totalForPeriod.round()),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 260,
                child: _loadingMerchRevenueAnalytics
                    ? const Center(child: CircularProgressIndicator())
                    : values.isEmpty
                        ? Center(
                            child: Text('No merch sales recorded for this period yet.',
                                style: TextStyle(color: Colors.grey[600])))
                        : LineChart(
                            LineChartData(
                              maxY: maxY,
                              minY: 0,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: interval,
                                getDrawingHorizontalLine: (v) =>
                                    FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
                              ),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: interval,
                                    reservedSize: 56,
                                    getTitlesWidget: (v, meta) => Text(_formatChartValue(v),
                                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ),
                                ),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, meta) {
                                      final i = v.toInt();
                                      if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(labels[i],
                                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: List.generate(
                                      values.length, (i) => FlSpot(i.toDouble(), values[i])),
                                  isCurved: true,
                                  curveSmoothness: 0.28,
                                  color: AppColors.inventoryPrimary,
                                  barWidth: 3,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                                        radius: 3.5,
                                        color: Theme.of(context).cardColor,
                                        strokeWidth: 2.5,
                                        strokeColor: AppColors.inventoryPrimary),
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        AppColors.inventoryPrimary.withValues(alpha: 0.18),
                                        AppColors.inventoryPrimary.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // HELPER REUSABLE WIDGETS
  // ==========================================
  Widget _buildStatCard(String title, String value, IconData icon, Color iconBg, Color iconColor, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration(context, accent: iconColor),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.statLabel(context), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: AppTheme.heading(context)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
