import 'dart:convert';
import 'package:http/http.dart' as http;
import 'payment_data.dart';

class PaymentService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  // Kunin ang listahan ng lahat ng membership payments
  static Future<List<Map<String, dynamic>>> getMembershipPayments() async {
    final response = await http.get(Uri.parse('$baseUrl/payments'));

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      final result = data.cast<Map<String, dynamic>>();
      PaymentData.instance.setPayments(result);
      return result;
    }

    // On failure, return existing cached payments
    return PaymentData.instance.payments;
  }
}