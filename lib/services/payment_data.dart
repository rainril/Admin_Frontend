import 'package:flutter/foundation.dart';
import 'attendance_data.dart';

class PaymentData extends ChangeNotifier {
  PaymentData._internal();
  static final PaymentData instance = PaymentData._internal();

  List<Map<String, dynamic>> _payments = [];

  List<Map<String, dynamic>> get payments => List.unmodifiable(_payments);

  bool _loading = false;
  bool get loading => _loading;

  void setLoading(bool value) {
    if (_loading != value) {
      _loading = value;
      notifyListeners();
    }
  }

  void setPayments(List<Map<String, dynamic>> newPayments) {
    _payments = newPayments;
    notifyListeners();
  }

  void addPayment(Map<String, dynamic> payment) {
    _payments.insert(0, payment);
    notifyListeners();
  }

  void updatePayment(int index, Map<String, dynamic> payment) {
    if (index >= 0 && index < _payments.length) {
      _payments[index] = payment;
      notifyListeners();
    }
  }

  void deletePayment(int index) {
    if (index >= 0 && index < _payments.length) {
      _payments.removeAt(index);
      notifyListeners();
    }
  }

  int countByStatus(String status) {
    return _payments.where((p) => p['status'] == status).length;
  }

  int countByPlan(String planName) {
    final lower = planName.toLowerCase();
    return _payments
        .where((p) => (p['plan'] as String? ?? '').toLowerCase() == lower)
        .length;
  }

  List<Map<String, dynamic>> get paidPayments =>
      _payments.where((p) => p['status'] == 'Paid').toList();

  int calculateTotalRevenue() {
    int total = 0;
    for (var payment in _payments) {
      if (payment['status'] == 'Paid') {
        final String clean =
            (payment['amount'] as String? ?? '0')
                .replaceAll('₱', '')
                .replaceAll(',', '');
        total += int.tryParse(clean) ?? 0;
      }
    }
    for (var w in AttendanceData.instance.walkIns) {
      if (w.status == WalkInStatus.paid) {
        total += w.amount.toInt();
      }
    }
    return total;
  }

  Map<String, int> getMonthlyRevenue() {
    final monthly = <String, int>{};
    for (var payment in _payments) {
      if (payment['status'] == 'Paid') {
        final String clean =
            (payment['amount'] as String? ?? '0')
                .replaceAll('₱', '')
                .replaceAll(',', '');
        final int amount = int.tryParse(clean) ?? 0;
        final String date = payment['date'] as String? ?? '';
        if (date.length >= 7) {
          final String month = date.substring(0, 7);
          monthly[month] = (monthly[month] ?? 0) + amount;
        }
      }
    }
    for (var w in AttendanceData.instance.walkIns) {
      if (w.status == WalkInStatus.paid) {
        final String month = w.date.substring(0, 7);
        monthly[month] = (monthly[month] ?? 0) + w.amount.toInt();
      }
    }
    return monthly;
  }
}
