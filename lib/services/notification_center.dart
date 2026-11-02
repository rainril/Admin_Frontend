import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dashboard_analytics_service.dart' show AppNotification, DashboardAnalyticsService;

/// One shared source of notifications for the whole app, so the sidebar,
/// the top-right bell and the Notifications screen always show the same list.
///
/// It reads the same feed the Dashboard's "Recent Notifications" card uses
/// (`DashboardAnalyticsService.fetchRecentNotifications`).
///
/// The backend does not store a read/unread state, so "new" is tracked in the
/// app for the current session:
///   * whatever is already in the feed on the first load counts as seen
///   * anything that shows up afterwards is "new" until the user taps it or
///     uses "Mark all as read"
/// This resets when the app is reloaded.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter._();
  static final NotificationCenter instance = NotificationCenter._();

  List<AppNotification> _items = [];
  bool _loading = true;
  bool _failed = false;
  bool _baselineTaken = false;
  final Set<String> _seen = {};
  Timer? _timer;

  List<AppNotification> get items => _items;
  bool get loading => _loading;
  bool get failed => _failed;

  /// Number of notifications that arrived since the app was opened and have
  /// not been marked as read yet.
  int get unreadCount => _items.where((n) => !isSeen(n)).length;

  static String _keyOf(AppNotification n) => '${n.type}|${n.title}|${n.subtitle}';

  bool isSeen(AppNotification n) => _seen.contains(_keyOf(n));

  void markSeen(AppNotification n) {
    if (_seen.add(_keyOf(n))) notifyListeners();
  }

  void markAllSeen() {
    var changed = false;
    for (final n in _items) {
      if (_seen.add(_keyOf(n))) changed = true;
    }
    if (changed) notifyListeners();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _loading = true;
      notifyListeners();
    }
    try {
      final list = await DashboardAnalyticsService.fetchRecentNotifications();
      _items = list;
      _failed = false;
      if (!_baselineTaken) {
        // First successful load: everything already there counts as seen.
        for (final n in list) {
          _seen.add(_keyOf(n));
        }
        _baselineTaken = true;
      }
    } catch (_) {
      _failed = true;
    }
    _loading = false;
    notifyListeners();
  }

  /// Safe to call from several places; only one timer ever runs.
  void startPolling({Duration every = const Duration(seconds: 30)}) {
    if (_timer != null) return;
    load();
    _timer = Timer.periodic(every, (_) => load(silent: true));
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  /// Call on logout so the next person who logs in starts clean.
  void reset() {
    stopPolling();
    _items = [];
    _loading = true;
    _failed = false;
    _baselineTaken = false;
    _seen.clear();
    notifyListeners();
  }
}
