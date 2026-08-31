import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches the real dashboard numbers (subscriptions, members, revenue,
/// attendance rate) from the Laravel /api/dashboard-stats route.
class DashboardStatsService {
  static const String _baseUrl = 'http://127.0.0.1:8000/api';

  static Future<DashboardStats?> fetch() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/dashboard-stats'));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] != true) return null;

      return DashboardStats(
        activeSubscriptions: data['activeSubscriptions'] ?? 0,
        activeMembers: data['activeMembers'] ?? 0,
        totalRevenue: data['totalRevenue'] ?? 0,
        attendanceRate: data['attendanceRate'] ?? 0,
      );
    } catch (e) {
      return null;
    }
  }
}

class DashboardStats {
  final int activeSubscriptions;
  final int activeMembers;
  final int totalRevenue;
  final int attendanceRate;

  DashboardStats({
    required this.activeSubscriptions,
    required this.activeMembers,
    required this.totalRevenue,
    required this.attendanceRate,
  });
}