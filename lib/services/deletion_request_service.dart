import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dashboard_analytics_service.dart' show ApiConfig;

class DeletionRequestItem {
  final int id;
  final String itemType; // 'equipment' | 'merch'
  final int itemId;
  final String itemName;
  final String? requestedBy;
  final String status; // 'Pending' | 'Approved' | 'Rejected'
  final String createdAt;

  DeletionRequestItem({
    required this.id,
    required this.itemType,
    required this.itemId,
    required this.itemName,
    this.requestedBy,
    required this.status,
    required this.createdAt,
  });

  factory DeletionRequestItem.fromJson(Map<String, dynamic> json) {
    return DeletionRequestItem(
      id: json['id'],
      itemType: json['item_type'] ?? '',
      itemId: json['item_id'] is int ? json['item_id'] : int.tryParse('${json['item_id']}') ?? 0,
      itemName: json['item_name'] ?? '',
      requestedBy: json['requested_by'],
      status: json['status'] ?? 'Pending',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class DeletionActionResult {
  final bool success;
  final String message;
  DeletionActionResult({required this.success, required this.message});
}

class DeletionRequestService {
  static Future<List<DeletionRequestItem>> fetchRequests({String status = 'Pending'}) async {
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/deletion-requests?status=$status'));
      if (res.statusCode != 200) return [];
      final body = json.decode(res.body);
      return (body['requests'] as List? ?? []).map((r) => DeletionRequestItem.fromJson(r)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Called by STAFF when they hit "Remove" — creates a pending request
  /// instead of deleting anything.
  static Future<DeletionActionResult> requestDeletion({
    required String itemType, // 'equipment' | 'merch'
    required int itemId,
    required String itemName,
    String? requestedBy,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/deletion-requests'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'item_type': itemType,
          'item_id': itemId,
          'item_name': itemName,
          'requested_by': requestedBy,
        }),
      );
      final body = json.decode(res.body);
      return DeletionActionResult(
        success: res.statusCode == 201 || res.statusCode == 200,
        message: body['message'] ?? '',
      );
    } catch (e) {
      return DeletionActionResult(success: false, message: 'Network error: $e');
    }
  }

  /// Called by OWNER — this is what actually deletes the item.
  static Future<DeletionActionResult> approve(int requestId, {String? reviewedBy}) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/deletion-requests/$requestId/approve'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'reviewed_by': reviewedBy}),
      );
      final body = json.decode(res.body);
      return DeletionActionResult(success: res.statusCode == 200, message: body['message'] ?? '');
    } catch (e) {
      return DeletionActionResult(success: false, message: 'Network error: $e');
    }
  }

  static Future<DeletionActionResult> reject(int requestId, {String? reviewedBy}) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/deletion-requests/$requestId/reject'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'reviewed_by': reviewedBy}),
      );
      final body = json.decode(res.body);
      return DeletionActionResult(success: res.statusCode == 200, message: body['message'] ?? '');
    } catch (e) {
      return DeletionActionResult(success: false, message: 'Network error: $e');
    }
  }
}
