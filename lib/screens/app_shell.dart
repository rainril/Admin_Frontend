import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar.dart';
import '../widgets/floating_chatbot.dart';
import '../widgets/tab_visibility.dart';
import '../widgets/notification_bell.dart';
import 'dashboard_screen.dart';
import 'notifications_screen.dart';
import 'billing_screen.dart';
import 'attendance_page.dart';
import 'scan_checkin_page.dart';
import 'inventory_screen.dart';
import 'settings_screen.dart';
import 'pending_receipts_screen.dart';
import 'login_screen.dart';
import '../services/current_user.dart';
import '../services/auth_service.dart';
import '../services/notification_center.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  // NOTE: Notifications was added at index 1, so every screen after Dashboard
  // moved down by one. Keep this list, the sidebar items and _screens in the
  // same order.
  static const _titles = [
    'Dashboard',
    'Notifications',
    'Attendance',
    'Scan',
    'Billing',
    'Pending Payments',
    'Inventory',
    'Settings',
  ];
  static const int notificationsIndex = 1;
  static const int scanIndex = 3;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  void _onSelect(int i) => setState(() => _index = i);

  Future<void> _logout() async {
    await AuthService.logout();
    CurrentUser.clear();
    NotificationCenter.instance.reset();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Wrap each tab so it knows whether it's the one currently on screen —
  /// screens use this to pause backend polling while hidden.
  Widget _tab(int i, Widget child) =>
      TabVisibility(isActive: _index == i, child: child);

  List<Widget> get _screens => [
        _tab(0, const DashboardScreen()),
        _tab(1, const NotificationsScreen()),
        _tab(2, AttendancePage(onGoToScan: () => _onSelect(scanIndex))),
        _tab(3, const ScanCheckInPage()),
        _tab(4, const BillingScreen()),
        _tab(5, const PendingReceiptsScreen()),
        _tab(6, const InventoryScreen()),
        _tab(7, const SettingsScreen()),
      ];

  /// Slim bar above every screen with the notification bell at the top right.
  Widget _topBar() {
    return Container(
      height: 64,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: NotificationBell(onTap: () => _onSelect(notificationsIndex)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    if (isWide) {
      return FloatingChatbotOverlay(
        child: Scaffold(
          body: Row(
            children: [
              Sidebar(currentIndex: _index, onSelect: _onSelect, onLogout: _logout),
              Expanded(
                child: Container(
                  color: AppTheme.pageBackground(context),
                  child: SafeArea(
                    child: Column(
                      children: [
                        _topBar(),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: IndexedStack(
                              index: _index,
                              children: _screens,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FloatingChatbotOverlay(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.cyan,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(_titles[_index], style: const TextStyle(color: Colors.white)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: NotificationBell(onTap: () => _onSelect(notificationsIndex)),
              ),
            ),
          ],
        ),
        drawer: Drawer(
          child: Sidebar(
            currentIndex: _index,
            onSelect: (i) {
              setState(() => _index = i);
              Navigator.of(context).pop();
            },
            onLogout: _logout,
          ),
        ),
        body: Container(
          color: AppTheme.pageBackground(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: IndexedStack(
              index: _index,
              children: _screens,
            ),
          ),
        ),
      ),
    );
  }
}
