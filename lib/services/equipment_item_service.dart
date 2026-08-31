import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dashboard_analytics_service.dart' show ApiConfig;

class EquipmentItem {
  final int id;
  final String barcode;
  final String name;
  final String category;
  final int qty;
  final String status; // 'Available' | 'Maintenance' | 'Damaged'
  final String? location;
  final String? nextMaintenance;
  final String? description;
  final String? imageUrl;

  EquipmentItem({
    required this.id,
    required this.barcode,
    required this.name,
    required this.category,
    required this.qty,
    required this.status,
    this.location,
    this.nextMaintenance,
    this.description,
    this.imageUrl,
  });

  factory EquipmentItem.fromJson(Map<String, dynamic> json) {
    return EquipmentItem(
      id: json['id'],
      barcode: json['barcode'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      qty: json['qty'] ?? 0,
      status: json['status'] ?? 'Available',
      location: json['location'],
      nextMaintenance: json['next_maintenance'],
      description: json['description'],
      imageUrl: json['image_url'],
    );
  }
}

class EquipmentListResult {
  final List<EquipmentItem> items;
  final int totalQty;
  final int availableQty;
  final int maintenanceQty;
  final int damagedQty;

  EquipmentListResult({
    required this.items,
    required this.totalQty,
    required this.availableQty,
    required this.maintenanceQty,
    required this.damagedQty,
  });

  factory EquipmentListResult.empty() => EquipmentListResult(
        items: [],
        totalQty: 0,
        availableQty: 0,
        maintenanceQty: 0,
        damagedQty: 0,
      );
}

class EquipmentActionResult {
  final bool success;
  final String message;
  EquipmentActionResult({required this.success, required this.message});
}

class EquipmentItemService {
  static Future<EquipmentListResult> fetchItems() async {
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/equipment-items'));
      if (res.statusCode != 200) return EquipmentListResult.empty();
      final body = json.decode(res.body);
      return EquipmentListResult(
        items: (body['items'] as List? ?? []).map((i) => EquipmentItem.fromJson(i)).toList(),
        totalQty: body['totalQty'] ?? 0,
        availableQty: body['availableQty'] ?? 0,
        maintenanceQty: body['maintenanceQty'] ?? 0,
        damagedQty: body['damagedQty'] ?? 0,
      );
    } catch (_) {
      return EquipmentListResult.empty();
    }
  }

  static Future<bool> addItem({
    required String barcode,
    required String name,
    required String category,
    required int qty,
    String status = 'Available',
    String? location,
    String? description,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/equipment-items'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'barcode': barcode,
          'name': name,
          'category': category,
          'qty': qty,
          'status': status,
          'location': location,
          'description': description,
        }),
      );
      return res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Edit — status, qty, and/or location. Only send what changed.
  static Future<bool> updateItem(
    int id, {
    String? status,
    int? qty,
    String? location,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (status != null) payload['status'] = status;
      if (qty != null) payload['qty'] = qty;
      if (location != null) payload['location'] = location;

      final res = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/equipment-items/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<EquipmentActionResult> markForMaintenance(int id) async {
    try {
      final res = await http.post(Uri.parse('${ApiConfig.baseUrl}/equipment-items/$id/maintain'));
      final body = json.decode(res.body);
      return EquipmentActionResult(success: res.statusCode == 200, message: body['message'] ?? '');
    } catch (e) {
      return EquipmentActionResult(success: false, message: 'Network error: $e');
    }
  }

  static Future<EquipmentActionResult> removeItem(int id) async {
    try {
      final res = await http.delete(Uri.parse('${ApiConfig.baseUrl}/equipment-items/$id'));
      final body = json.decode(res.body);
      return EquipmentActionResult(success: res.statusCode == 200, message: body['message'] ?? '');
    } catch (e) {
      return EquipmentActionResult(success: false, message: 'Network error: $e');
    }
  }
}
