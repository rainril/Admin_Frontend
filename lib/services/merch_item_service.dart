import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dashboard_analytics_service.dart' show ApiConfig;

class MerchItem {
  final int id;
  final String sku;
  final String name;
  final double price;
  final int stock;
  final int sold;
  final double revenue;
  final String? imageUrl;

  MerchItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.price,
    required this.stock,
    required this.sold,
    required this.revenue,
    this.imageUrl,
  });

  factory MerchItem.fromJson(Map<String, dynamic> json) {
    return MerchItem(
      id: json['id'],
      sku: json['sku'] ?? '',
      name: json['name'] ?? '',
      price: double.tryParse('${json['price']}') ?? 0,
      stock: json['stock'] ?? 0,
      sold: json['sold'] ?? 0,
      revenue: double.tryParse('${json['revenue']}') ?? 0,
      imageUrl: json['image_url'],
    );
  }
}

class MerchItemListResult {
  final List<MerchItem> items;
  final int totalItems;
  final double totalRevenue;
  final int totalUnitsSold;

  MerchItemListResult({
    required this.items,
    required this.totalItems,
    required this.totalRevenue,
    required this.totalUnitsSold,
  });

  factory MerchItemListResult.empty() =>
      MerchItemListResult(items: [], totalItems: 0, totalRevenue: 0, totalUnitsSold: 0);
}

class MerchItemService {
  static Future<MerchItemListResult> fetchItems() async {
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/merch-items'));
      if (res.statusCode != 200) return MerchItemListResult.empty();
      final body = json.decode(res.body);
      return MerchItemListResult(
        items: (body['items'] as List? ?? []).map((i) => MerchItem.fromJson(i)).toList(),
        totalItems: body['totalItems'] ?? 0,
        totalRevenue: double.tryParse('${body['totalRevenue']}') ?? 0,
        totalUnitsSold: body['totalUnitsSold'] ?? 0,
      );
    } catch (_) {
      return MerchItemListResult.empty();
    }
  }

  static Future<bool> addItem({
    required String sku,
    required String name,
    required double price,
    required int stock,
    String? imageUrl,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/merch-items'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sku': sku,
          'name': name,
          'price': price,
          'stock': stock,
          'image_url': imageUrl,
        }),
      );
      return res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updatePrice(int id, double price) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/merch-items/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'price': price}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> restock(int id, int quantity) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/merch-items/$id/restock'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'quantity': quantity}),
      );
      final body = json.decode(res.body);
      return res.statusCode == 200 ? (body['message'] ?? 'Restocked.') : null;
    } catch (_) {
      return null;
    }
  }

  static Future<MerchItemDeleteResult> removeItem(int id) async {
    try {
      final res = await http.delete(Uri.parse('${ApiConfig.baseUrl}/merch-items/$id'));
      final body = json.decode(res.body);
      return MerchItemDeleteResult(success: res.statusCode == 200, message: body['message'] ?? '');
    } catch (e) {
      return MerchItemDeleteResult(success: false, message: 'Network error: $e');
    }
  }
}

class MerchItemDeleteResult {
  final bool success;
  final String message;
  MerchItemDeleteResult({required this.success, required this.message});
}
