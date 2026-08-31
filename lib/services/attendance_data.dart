import 'package:flutter/foundation.dart';

class AttendanceStatus {
  static const present = 'Present';
  static const late = 'Late';
  static const absent = 'Absent';
  static const all = [present, late, absent];
}

class SubscriptionStatus {
  static const active = 'Active';
  static const expired = 'Expired';
  static const expiringSoon = 'Expiring Soon';
}

class WalkInStatus {
  static const paid = 'Paid';
  static const pending = 'Pending';
  static const failed = 'Failed';
  static const all = [paid, pending, failed];
}

class Member {
  final String id; // ito yung value na naka-encode sa QR code ng member
  final String name;
  final String email;
  String plan;
  String subscriptionStatus;
  String expiryDate;

  Member({
    required this.id,
    required this.name,
    required this.email,
    required this.plan,
    required this.subscriptionStatus,
    required this.expiryDate,
  });
}

class AttendanceRecord {
  final String id;
  final String memberId;
  final String name;
  final String email;
  final String plan;
  String date;
  String checkIn;
  String checkOut;
  double hoursSpent;
  String status;
  final String source; // 'walk-in' o 'member' (QR scan)

  AttendanceRecord({
    required this.id,
    required this.memberId,
    required this.name,
    required this.email,
    required this.plan,
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.hoursSpent,
    required this.status,
    this.source = 'member',
  });
}

class WalkInRecord {
  final String id;
  String name;
  final String date; // auto-set kapag ginawa
  String checkIn;
  String checkOut;
  double amount;
  String method;
  String status;

  WalkInRecord({
    required this.id,
    required this.name,
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.amount,
    required this.method,
    required this.status,
  });
}

/// Shared source of truth para sa Members, AttendanceRecords (QR/member
/// check-ins), at WalkInRecords (manual walk-in customers) — para
/// magamit ito pareho ng AttendancePage, ScanCheckInPage, at Dashboard.
class AttendanceData extends ChangeNotifier {
  AttendanceData._internal();
  static final AttendanceData instance = AttendanceData._internal();

  int _nextRecordId = 7;
  int _nextMemberId = 7;
  int _nextWalkInId = 2;

  final List<Member> members = [
    Member(
      id: 'M001',
      name: 'John Doe',
      email: 'john@example.com',
      plan: 'Premium',
      subscriptionStatus: SubscriptionStatus.active,
      expiryDate: '2026-01-15',
    ),
    Member(
      id: 'M002',
      name: 'Jane Smith',
      email: 'jane@example.com',
      plan: 'Basic',
      subscriptionStatus: SubscriptionStatus.active,
      expiryDate: '2025-09-20',
    ),
    Member(
      id: 'M003',
      name: 'Mike Johnson',
      email: 'mike@example.com',
      plan: 'Premium',
      subscriptionStatus: SubscriptionStatus.expiringSoon,
      expiryDate: '2025-07-25',
    ),
  ];

 final List<AttendanceRecord> records = [];

  final List<WalkInRecord> walkIns = [];
  
  String formatNow() {
    final now = DateTime.now();
    var hour = now.hour % 12;
    if (hour == 0) hour = 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String formatToday() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Member? findMemberById(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  Member addMember({
    required String name,
    required String email,
    required String plan,
    required String expiryDate,
  }) {
    final member = Member(
      id: 'M${(_nextMemberId++).toString().padLeft(3, '0')}',
      name: name,
      email: email,
      plan: plan,
      subscriptionStatus: SubscriptionStatus.active,
      expiryDate: expiryDate,
    );
    members.add(member);
    notifyListeners();
    return member;
  }

  /// Ginagamit ng Scan page (QR check-in ng members).
  void recordCheckIn(
    Member member, {
    String status = AttendanceStatus.present,
    String source = 'member',
  }) {
    records.insert(
      0,
      AttendanceRecord(
        id: (_nextRecordId++).toString(),
        memberId: member.id,
        name: member.name,
        email: member.email,
        plan: member.plan,
        date: formatToday(),
        checkIn: formatNow(),
        checkOut: '--',
        hoursSpent: 0.0,
        status: status,
        source: source,
      ),
    );
    notifyListeners();
  }

  void updateRecord(AttendanceRecord r) => notifyListeners();

  void deleteRecord(String id) {
    records.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  /// Ginagamit ng Attendance page (manual check-in ng walk-in customers).
  WalkInRecord addWalkIn({
    required String name,
    required String checkIn,
    required String checkOut,
    required double amount,
    required String method,
    required String status,
  }) {
    final record = WalkInRecord(
      id: (_nextWalkInId++).toString(),
      name: name,
      date: formatToday(),
      checkIn: checkIn,
      checkOut: checkOut,
      amount: amount,
      method: method,
      status: status,
    );
    walkIns.insert(0, record);
    notifyListeners();
    return record;
  }

  void updateWalkIn(WalkInRecord r) => notifyListeners();

  void deleteWalkIn(String id) {
    walkIns.removeWhere((x) => x.id == id);
    notifyListeners();
  }
}