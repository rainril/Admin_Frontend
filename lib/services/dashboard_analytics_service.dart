import 'dart:convert';
import 'package:http/http.dart' as http;

/// Point this at the same base URL your other services (PaymentService,
/// AttendanceService, DashboardStatsService) already use to reach the
/// Laravel API. If you already have a shared ApiConfig/api constants file,
/// delete this class and import that one instead.
class ApiConfig {
  static const String baseUrl = 'http://localhost:8000/api'; // 
  
}

class ChurnRiskMember {
  final int customerId;
  final String name;
  final String? plan;
  final int? daysSinceLastVisit;
  final int? daysUntilExpiry;
  final String riskLevel; // 'High' | 'Medium'
  final String reason;

  ChurnRiskMember({
    required this.customerId,
    required this.name,
    this.plan,
    this.daysSinceLastVisit,
    this.daysUntilExpiry,
    required this.riskLevel,
    required this.reason,
  });

  factory ChurnRiskMember.fromJson(Map<String, dynamic> json) {
    return ChurnRiskMember(
      customerId: json['customer_id'] is int
          ? json['customer_id']
          : int.tryParse('${json['customer_id']}') ?? 0,
      name: json['name'] ?? 'Unknown',
      plan: json['plan'],
      // days_since_last_visit / days_until_expiry come back as floats from
      // Carbon::diffInDays, so round them down to whole days instead of
      // assigning a double directly into an int? field (which throws).
      daysSinceLastVisit: json['days_since_last_visit'] is num
          ? (json['days_since_last_visit'] as num).floor()
          : null,
      daysUntilExpiry: json['days_until_expiry'] is num
          ? (json['days_until_expiry'] as num).floor()
          : null,
      riskLevel: json['risk_level'] ?? 'Low',
      reason: json['reason'] ?? '',
    );
  }
}

class ChurnForecast {
  final String forecast;
  final int riskRatePercent;
  final int highRiskCount;
  final int mediumRiskCount;
  final int totalActive;

  ChurnForecast({
    required this.forecast,
    required this.riskRatePercent,
    required this.highRiskCount,
    required this.mediumRiskCount,
    required this.totalActive,
  });

  factory ChurnForecast.fromJson(Map<String, dynamic> json) {
    return ChurnForecast(
      forecast: json['forecast'] ?? '',
      riskRatePercent: json['risk_rate_percent'] ?? 0,
      highRiskCount: json['high_risk_count'] ?? 0,
      mediumRiskCount: json['medium_risk_count'] ?? 0,
      totalActive: json['total_active'] ?? 0,
    );
  }
}

class ChartSeries {
  final List<String> labels;
  final List<double> values;
  ChartSeries({required this.labels, required this.values});

  factory ChartSeries.fromJson(Map<String, dynamic> json) {
    return ChartSeries(
      labels: List<String>.from(json['labels'] ?? []),
      values: (json['values'] as List? ?? [])
          .map((v) => (v as num).toDouble())
          .toList(),
    );
  }
}

/// A member whose Active membership renews within the lookahead window
/// (default 7 days) -- a straightforward renewal action list, distinct
/// from Churn Risk (which mixes in attendance signals).
class ExpiringMember {
  final int customerId;
  final String name;
  final String? email;
  final String? plan;
  final String? nextRenewalDate;
  final int daysUntilExpiry;
  final int renewalCount;
  final bool isExpired;

  ExpiringMember({
    required this.customerId,
    required this.name,
    this.email,
    this.plan,
    this.nextRenewalDate,
    required this.daysUntilExpiry,
    required this.renewalCount,
    required this.isExpired,
  });

  factory ExpiringMember.fromJson(Map<String, dynamic> json) {
    return ExpiringMember(
      customerId: json['customer_id'] is int
          ? json['customer_id']
          : int.tryParse('${json['customer_id']}') ?? 0,
      name: json['name'] ?? 'Unknown',
      email: json['email'],
      plan: json['plan'],
      nextRenewalDate: json['next_renewal_date'],
      // days_until_expiry comes back as a float from Carbon::diffInDays,
      // so round it down to whole days for display.
      daysUntilExpiry: json['days_until_expiry'] is num
          ? (json['days_until_expiry'] as num).floor()
          : int.tryParse('${json['days_until_expiry']}') ?? 0,
      renewalCount: json['renewal_count'] ?? 0,
      isExpired: json['is_expired'] ?? false,
    );
  }
}

/// A real activity event for the admin dashboard's notification feed --
/// a new registration or a payment event (paid/failed/pending).
class AppNotification {
  final String type;
  final String title;
  final String subtitle;
  final DateTime? timestamp;

  AppNotification({
    required this.type,
    required this.title,
    required this.subtitle,
    this.timestamp,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    DateTime? parsed;
    try {
      parsed = DateTime.parse(json['timestamp'].toString());
    } catch (_) {}

    return AppNotification(
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      timestamp: parsed,
    );
  }

  /// Human-friendly relative time, e.g. "5m ago", "3h ago", "2d ago".
  String get timeAgo {
    if (timestamp == null) return '';
    final diff = DateTime.now().difference(timestamp!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// A single walk-in (non-member / guest) check-in for today's activity list.
/// Adjust field names below to match whatever your
/// `/dashboard/todays-walkins` endpoint actually returns.
class TodayWalkInEntry {
  final int? id;
  final String name;
  final String? contactNumber;
  final String? purpose;
  final DateTime? checkInTime;
  final double? amountPaid;

  TodayWalkInEntry({
    this.id,
    required this.name,
    this.contactNumber,
    this.purpose,
    this.checkInTime,
    this.amountPaid,
  });

  factory TodayWalkInEntry.fromJson(Map<String, dynamic> json) {
    DateTime? parsed;
    try {
      if (json['check_in_time'] != null) {
        parsed = DateTime.parse(json['check_in_time'].toString());
      }
    } catch (_) {}

    return TodayWalkInEntry(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}'),
      name: json['name'] ?? 'Unknown',
      contactNumber: json['contact_number'],
      purpose: json['purpose'],
      checkInTime: parsed,
      amountPaid: json['amount_paid'] != null
          ? (json['amount_paid'] as num).toDouble()
          : null,
    );
  }

  /// Formatted check-in time for display, e.g. "10:30 AM". Empty string if unknown.
  String get time => checkInTime != null ? _formatTimeOfDay(checkInTime!) : '';

  /// Amount paid, defaulting to 0 when not provided by the API.
  double get amount => amountPaid ?? 0;
}

/// A single member attendance/check-in event for today, for the admin
/// dashboard's "today's activity" list. Adjust field names below to match
/// whatever your `/dashboard/todays-member-attendance` endpoint returns.
class TodayMemberEntry {
  final int customerId;
  final String name;
  final String? plan;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;

  TodayMemberEntry({
    required this.customerId,
    required this.name,
    this.plan,
    this.checkInTime,
    this.checkOutTime,
  });

  factory TodayMemberEntry.fromJson(Map<String, dynamic> json) {
    DateTime? checkIn;
    DateTime? checkOut;
    try {
      if (json['check_in_time'] != null) {
        checkIn = DateTime.parse(json['check_in_time'].toString());
      }
    } catch (_) {}
    try {
      if (json['check_out_time'] != null) {
        checkOut = DateTime.parse(json['check_out_time'].toString());
      }
    } catch (_) {}

    return TodayMemberEntry(
      customerId: json['customer_id'] is int
          ? json['customer_id']
          : int.tryParse('${json['customer_id']}') ?? 0,
      name: json['name'] ?? 'Unknown',
      plan: json['plan'],
      checkInTime: checkIn,
      checkOutTime: checkOut,
    );
  }

  /// Formatted check-in time for display, e.g. "10:30 AM". Empty string if unknown.
  String get time => checkInTime != null ? _formatTimeOfDay(checkInTime!) : '';
}

/// Shared helper for TodayWalkInEntry.time / TodayMemberEntry.time.
/// Formats a DateTime as a 12-hour clock string, e.g. "9:05 AM".
String _formatTimeOfDay(DateTime dt) {
  final hour24 = dt.hour;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour12:$minute $period';
}

class DashboardAnalyticsService {
  static Future<List<ChurnRiskMember>> fetchChurnRisk() async {
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/dashboard/churn-risk'));
      if (res.statusCode != 200) return [];
      final body = json.decode(res.body);
      return (body['members'] as List? ?? [])
          .map((m) => ChurnRiskMember.fromJson(m))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<ChurnForecast?> fetchChurnForecast() async {
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/dashboard/churn-forecast'));
      if (res.statusCode != 200) return null;
      return ChurnForecast.fromJson(json.decode(res.body));
    } catch (_) {
      return null;
    }
  }

  /// period: 'weekly' | 'monthly' | 'yearly'
  static Future<ChartSeries?> fetchRevenueAnalytics(String period) async {
    try {
      final res = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/dashboard/revenue-analytics?period=$period'));
      if (res.statusCode != 200) return null;
      final body = json.decode(res.body);
      return ChartSeries.fromJson(body['data'] ?? {});
    } catch (_) {
      return null;
    }
  }

  static Future<ChartSeries?> fetchAttendanceAnalytics() async {
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/dashboard/attendance-analytics'));
      if (res.statusCode != 200) return null;
      return ChartSeries.fromJson(json.decode(res.body));
    } catch (_) {
      return null;
    }
  }

  /// days: how many days ahead counts as "expiring soon" (default 7,
  /// matches the member-side threshold).
  static Future<List<ExpiringMember>> fetchExpiringMemberships({int days = 7}) async {
    try {
      final res = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/dashboard/expiring-memberships?days=$days'));
      if (res.statusCode != 200) return [];
      final body = json.decode(res.body);
      return (body['members'] as List? ?? [])
          .map((m) => ExpiringMember.fromJson(m))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<AppNotification>> fetchRecentNotifications({int limit = 8}) async {
    try {
      final res = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/dashboard/notifications?limit=$limit'));
      if (res.statusCode != 200) return [];
      final body = json.decode(res.body);
      return (body['notifications'] as List? ?? [])
          .map((n) => AppNotification.fromJson(n))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<TodayWalkInEntry>> fetchTodaysWalkIns() async {
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/dashboard/todays-walkins'));
      if (res.statusCode != 200) return [];
      final body = json.decode(res.body);
      return (body['entries'] as List? ?? [])
          .map((e) => TodayWalkInEntry.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<TodayMemberEntry>> fetchTodaysMemberAttendance() async {
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/dashboard/todays-member-attendance'));
      if (res.statusCode != 200) return [];
      final body = json.decode(res.body);
      return (body['entries'] as List? ?? [])
          .map((e) => TodayMemberEntry.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }
} 