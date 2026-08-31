import 'dart:convert';
import 'package:http/http.dart' as http;

/// Reuse the same base-URL config already defined in
/// dashboard_analytics_service.dart, instead of duplicating it here.
/// ChartSeries is also reused — same {labels, values} shape as the
/// dashboard's revenue chart.
import 'dashboard_analytics_service.dart' show ApiConfig, ChartSeries;

class MerchSale {
  final int id;
  final int itemId;
  final String itemName;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final String buyerName;
  final String paymentMethod;
  final String status; // 'Pending' | 'Completed' | 'Voided'
  final String date;

  MerchSale({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.buyerName,
    required this.paymentMethod,
    required this.status,
    required this.date,
  });

  factory MerchSale.fromJson(Map<String, dynamic> json) {
    return MerchSale(
      id: json['id'],
      itemId: json['item_id'],
      itemName: json['item_name'] ?? '',
      quantity: json['quantity'] ?? 0,
      unitPrice: double.tryParse('${json['unit_price']}') ?? 0,
      totalAmount: double.tryParse('${json['total_amount']}') ?? 0,
      buyerName: json['buyer_name'] ?? 'Walk-in',
      paymentMethod: json['payment_method'] ?? 'Cash',
      status: json['status'] ?? 'Pending',
      date: json['date'] ?? '',
    );
  }
}

class MerchStats {
  final double allTimeRevenue;
  final int allTimeUnitsSold;
  final double yearRevenue;
  final int yearUnitsSold;
  final int pendingCount;

  MerchStats({
    required this.allTimeRevenue,
    required this.allTimeUnitsSold,
    required this.yearRevenue,
    required this.yearUnitsSold,
    required this.pendingCount,
  });

  factory MerchStats.fromJson(Map<String, dynamic> json) {
    return MerchStats(
      allTimeRevenue: double.tryParse('${json['allTimeRevenue']}') ?? 0,
      allTimeUnitsSold: json['allTimeUnitsSold'] ?? 0,
      yearRevenue: double.tryParse('${json['yearRevenue']}') ?? 0,
      yearUnitsSold: json['yearUnitsSold'] ?? 0,
      pendingCount: json['pendingCount'] ?? 0,
    );
  }
}

/// Simple result wrapper so callers can show the exact backend message
/// (e.g. "Only 3 units left in stock") without re-parsing responses.
class MerchSaleResult {
  final bool success;
  final String message;
  final MerchSale? sale;

  MerchSaleResult({required this.success, required this.message, this.sale});
}

class MerchSaleService {
  static Future<List<MerchSale>> fetchSales({String? status}) async {
    try {
      final uri = status != null
          ? Uri.parse('${ApiConfig.baseUrl}/merch-sales?status=$status')
          : Uri.parse('${ApiConfig.baseUrl}/merch-sales');
      final res = await http.get(uri);
      if (res.statusCode != 200) return [];
      final body = json.decode(res.body);
      return (body['sales'] as List? ?? []).map((s) => MerchSale.fromJson(s)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<MerchSaleResult> recordSale({
    required int itemId,
    required int quantity,
    String? buyerName,
    String paymentMethod = 'Cash',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/merch-sales'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: json.encode({
          'item_id': itemId,
          'quantity': quantity,
          'buyer_name': buyerName,
          'payment_method': paymentMethod,
        }),
      );
      final body = json.decode(res.body);
      if (res.statusCode == 201) {
        return MerchSaleResult(
          success: true,
          message: body['message'] ?? 'Sale recorded.',
          sale: MerchSale.fromJson(body['sale']),
        );
      }
      // Validation errors (422) come back as {"errors": {"quantity": ["..."]}}
      final errors = body['errors'] as Map<String, dynamic>?;
      final firstError = errors != null && errors.isNotEmpty
          ? (errors.values.first as List).first.toString()
          : (body['message'] ?? 'Failed to record sale.');
      return MerchSaleResult(success: false, message: firstError);
    } catch (e) {
      return MerchSaleResult(success: false, message: 'Network error: $e');
    }
  }

  static Future<MerchSaleResult> confirmSale(int saleId) async {
    try {
      final res = await http.post(Uri.parse('${ApiConfig.baseUrl}/merch-sales/$saleId/confirm'));
      final body = json.decode(res.body);
      return MerchSaleResult(
        success: body['success'] == true,
        message: body['message'] ?? '',
        sale: body['sale'] != null ? MerchSale.fromJson(body['sale']) : null,
      );
    } catch (e) {
      return MerchSaleResult(success: false, message: 'Network error: $e');
    }
  }

  static Future<MerchSaleResult> voidSale(int saleId) async {
    try {
      final res = await http.post(Uri.parse('${ApiConfig.baseUrl}/merch-sales/$saleId/void'));
      final body = json.decode(res.body);
      return MerchSaleResult(success: body['success'] == true, message: body['message'] ?? '');
    } catch (e) {
      return MerchSaleResult(success: false, message: 'Network error: $e');
    }
  }

  static Future<MerchStats?> fetchStats() async {
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/merch-sales/stats'));
      if (res.statusCode != 200) return null;
      return MerchStats.fromJson(json.decode(res.body));
    } catch (_) {
      return null;
    }
  }

  /// period: 'daily' | 'weekly' | 'monthly' | 'annual'
  /// Real merch revenue, summed only from Completed (confirmed) sales.
  static Future<ChartSeries?> fetchRevenueAnalytics(String period) async {
    try {
      final res = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/merch-sales/revenue-analytics?period=$period'));
      if (res.statusCode != 200) return null;
      final body = json.decode(res.body);
      return ChartSeries.fromJson(body['data'] ?? {});
    } catch (_) {
      return null;
    }
  }
}
