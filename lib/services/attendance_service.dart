import 'dart:convert';
import 'package:http/http.dart' as http;

class AttendanceService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  // Kunin ang listahan ng lahat ng members (para sa Test QR Codes, dropdown)
  static Future<List<Map<String, dynamic>>> getMembers() async {
    final response = await http.get(Uri.parse('$baseUrl/customers'));

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      return [];
    }
  }

  // Hanapin ang member gamit ang scanned QR code
  static Future<Map<String, dynamic>?> findMemberByQr(String qrCode) async {
    final response = await http.get(Uri.parse('$baseUrl/customers/$qrCode'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return null; // hindi nahanap
    }
  }

  // I-record ang check-in (galing sa Scan page o Manual Check In)
  static Future<Map<String, dynamic>> recordCheckIn({
    required String qrCode,
    required String status,
    int? adminId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/attendance'),
      headers: {'Accept': 'application/json'},
      body: {
        'qrCode': qrCode,
        'status': status,
        if (adminId != null) 'adminId': adminId.toString(),
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'message': data['message'] ?? 'Check-in failed'};
    }
  }

  // Kunin ang listahan ng attendance records
  static Future<List<Map<String, dynamic>>> getAttendanceLogs() async {
    final response = await http.get(Uri.parse('$baseUrl/attendance'));

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      return [];
    }
  }

  // I-verify ang signed QR token (galing sa Member app), kukunin ang
  // detalye ng member mula sa memberaccount_db (via Laravel).
  static Future<Map<String, dynamic>?> verifyQrToken(String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/verify-qr'),
      headers: {'Accept': 'application/json'},
      body: {'token': token},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final data = jsonDecode(response.body);
      return {'error': true, 'message': data['message'] ?? 'Invalid QR code'};
    }
  }

  // ---------- Walk-in customers ----------

  static Future<List<Map<String, dynamic>>> getWalkIns() async {
    final response = await http.get(Uri.parse('$baseUrl/walk-ins'));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  static Future<Map<String, dynamic>> addWalkIn({
    required String name,
    required String checkIn,
    required String checkOut,
    required double amount,
    required String method,
    required String status,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/walk-ins'),
      headers: {'Accept': 'application/json'},
      body: {
        'name': name,
        'checkIn': checkIn,
        'checkOut': checkOut,
        'amount': amount.toString(),
        'method': method,
        'status': status,
      },
    );
    if (response.statusCode == 201) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'message': 'Failed to add walk-in'};
  }

  // Direct update -- used ONLY when the current user is Owner. Staff
  // should go through createApprovalRequest() instead.
  static Future<bool> updateWalkIn({
    required String id,
    required String name,
    required String checkIn,
    required String checkOut,
    required double amount,
    required String method,
    required String status,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/walk-ins/$id'),
      headers: {'Accept': 'application/json'},
      body: {
        'name': name,
        'check_in': checkIn,
        'check_out': checkOut,
        'amount': amount.toString(),
        'method': method,
        'status': status,
      },
    );
    return response.statusCode == 200;
  }

  // Direct delete -- used ONLY when the current user is Owner. Staff
  // should go through createApprovalRequest() instead.
  static Future<bool> deleteWalkIn(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/walk-ins/$id'));
    return response.statusCode == 200;
  }

  // ---------- Approval requests (Staff edits/deletes require Owner sign-off) ----------

  static Future<Map<String, dynamic>> createApprovalRequest({
    required String type, // 'edit' | 'delete'
    required String targetType, // 'walk_in'
    required String targetId,
    Map<String, dynamic>? payload,
    required String requestedBy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/approval-requests'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'type': type,
          'target_type': targetType,
          'target_id': targetId,
          'payload': payload,
          'requested_by': requestedBy,
        }),
      );
      if (response.statusCode == 201) {
        return {'success': true};
      }
      return {'success': false, 'message': 'Failed to submit request for approval.'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingApprovals() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/approval-requests?status=pending'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> approveRequest(int id) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/approval-requests/$id/approve'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> rejectRequest(int id) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/approval-requests/$id/reject'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}