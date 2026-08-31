import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar.dart';
import '../widgets/tab_visibility.dart';
import 'dashboard_screen.dart';
import 'billing_screen.dart';
import 'attendance_page.dart';
import 'scan_checkin_page.dart';
import 'inventory_screen.dart';
import 'settings_screen.dart';
import 'chatbot_screen.dart';
import 'login_screen.dart';
import '../services/current_user.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _titles = ['Dashboard', 'Attendance', 'Scan', 'Billing', 'Inventory', 'Chatbot', 'Settings'];
  static const int scanIndex = 2;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  void _onSelect(int i) => setState(() => _index = i);

  void _logout() {
    CurrentUser.clear();
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
        _tab(1, AttendancePage(onGoToScan: () => _onSelect(scanIndex))),
        _tab(2, const ScanCheckInPage()),
        _tab(3, const BillingScreen()),
        _tab(4, const InventoryScreen()),
        _tab(5, const ChatbotScreen()),
        _tab(6, const SettingsScreen()),
      ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            Sidebar(currentIndex: _index, onSelect: _onSelect, onLogout: _logout),
            Expanded(
              child: Container(
                color: AppTheme.pageBackground(context),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: IndexedStack(
                      index: _index,
                      children: _screens,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
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
    );
  }
}