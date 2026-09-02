import 'dart:convert';
import 'package:http/http.dart' as http;

/// Base host for the plain-PHP billing endpoint (`billing_api.php`) that backs
/// manual GCash / Maya receipt review. This one lives *outside* Laravel's
/// `/api` prefix, so it needs its own host constant — keep it in sync with the
/// host the other services already use (`PaymentService.baseUrl`,
/// `ApiConfig.baseUrl` in `dashboard_analytics_service.dart`).
class BillingApiConfig {
     static const String host = 'http://127.0.0.1:8080';

  static String get endpoint => '$host/billing_api.php';

  /// Turn a receipt's `receipt_url` (which may come back absolute, or relative
  /// to the backend root) into a full, loadable image URL.
  static String receiptImageUrl(String receiptUrl) {
    if (receiptUrl.isEmpty) return '';
    if (receiptUrl.startsWith('http://') || receiptUrl.startsWith('https://')) {
      return receiptUrl;
    }
    return receiptUrl.startsWith('/') ? '$host$receiptUrl' : '$host/$receiptUrl';
  }
}

/// One manually-uploaded payment receipt awaiting admin review.
///
/// The backend's exact field names aren't pinned down, so [fromJson] accepts a
/// few common spellings for each value and falls back to an empty string.
class PendingReceipt {
  final String paymentId;
  final String memberName;
  final String memberEmail;
  final String planName;
  final String planPrice;
  final String dateSubmitted;
  final String paymentMethod;
  final String ocrAmount;
  final String ocrReference;
  final bool amountMatches;
  final String receiptUrl;

  PendingReceipt({
    required this.paymentId,
    required this.memberName,
    required this.memberEmail,
    required this.planName,
    required this.planPrice,
    required this.dateSubmitted,
    required this.paymentMethod,
    required this.ocrAmount,
    required this.ocrReference,
    required this.amountMatches,
    required this.receiptUrl,
  });

  String get receiptImageUrl => BillingApiConfig.receiptImageUrl(receiptUrl);

  factory PendingReceipt.fromJson(Map<String, dynamic> j) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
      }
      return '';
    }

    bool pickBool(List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v == null) continue;
        if (v is bool) return v;
        if (v is num) return v != 0;
        final s = v.toString().toLowerCase();
        return s == 'true' || s == '1' || s == 'yes';
      }
      return false;
    }

    return PendingReceipt(
      paymentId: pick(['payment_id', 'id', 'paymentId']),
      memberName: pick(
          ['member_name', 'name', 'full_name', 'customer_name', 'member']),
      memberEmail: pick(['member_email', 'email', 'customer_email']),
      planName: pick(['plan_name', 'plan', 'membership_plan']),
      planPrice: pick(['plan_price', 'price', 'plan_amount', 'amount']),
      dateSubmitted: pick([
        'date_submitted',
        'submitted_at',
        'created_at',
        'date',
        'submitted',
      ]),
      paymentMethod: pick(['payment_method', 'method', 'channel']),
      ocrAmount: pick([
        'ocr_amount',
        'extracted_amount',
        'amount_extracted',
        'detected_amount',
      ]),
      ocrReference: pick([
        'ocr_reference',
        'ocr_reference_number',
        'reference_number',
        'reference',
        'ref_number',
        'extracted_reference',
      ]),
      amountMatches: pickBool(
          ['amount_matches', 'amount_match', 'amountMatches', 'is_amount_match']),
      receiptUrl: pick([
        'receipt_url',
        'receipt',
        'receipt_image',
        'image_url',
        'receipt_path',
      ]),
    );
  }
}

class ReceiptActionResult {
  final bool success;
  final String message;
  ReceiptActionResult({required this.success, required this.message});
}

class PendingReceiptService {
  /// GET billing_api.php?action=list_pending_receipts
  ///
  /// Throws on a network error or non-200 response so the screen can show its
  /// retry state.
  static Future<List<PendingReceipt>> listPendingReceipts() async {
    final res = await http.get(
      Uri.parse('${BillingApiConfig.endpoint}?action=list_pending_receipts'),
    );

    if (res.statusCode != 200) {
      throw Exception('Server returned ${res.statusCode}');
    }

    final decoded = json.decode(res.body);
    final raw = decoded is List
        ? decoded
        : (decoded is Map
            ? (decoded['data'] ??
                decoded['receipts'] ??
                decoded['pending'] ??
                decoded['payments'] ??
                decoded['result'] ??
                const [])
            : const []);

    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((e) => PendingReceipt.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// POST billing_api.php?action=approve_receipt  { payment_id }
  static Future<ReceiptActionResult> approveReceipt(String paymentId) =>
      _postAction('approve_receipt', {'payment_id': paymentId});

  /// POST billing_api.php?action=reject_receipt  { payment_id, reason }
  static Future<ReceiptActionResult> rejectReceipt(
          String paymentId, String reason) =>
      _postAction('reject_receipt', {'payment_id': paymentId, 'reason': reason});

  static Future<ReceiptActionResult> _postAction(
      String action, Map<String, dynamic> body) async {
    try {
      final res = await http.post(
        Uri.parse('${BillingApiConfig.endpoint}?action=$action'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      Map<String, dynamic> parsed = {};
      try {
        final d = json.decode(res.body);
        if (d is Map<String, dynamic>) parsed = d;
      } catch (_) {
        // non-JSON body — fall back to the status code below
      }

      final ok = res.statusCode == 200 &&
          (parsed['success'] == null || parsed['success'] == true);

      return ReceiptActionResult(
        success: ok,
        message: (parsed['message'] ??
                parsed['error'] ??
                (ok ? 'Done.' : 'Request failed (${res.statusCode}).'))
            .toString(),
      );
    } catch (e) {
      return ReceiptActionResult(success: false, message: 'Network error: $e');
    }
  }
}
