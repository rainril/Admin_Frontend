import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../services/auth_service.dart';
import '../services/current_user.dart';
import 'app_shell.dart';
import 'attendance_page.dart';
import 'login_screen.dart';
import 'qr_scanner_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _retry = false;
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    setState(() {
      _checking = true;
      _retry = false;
    });
    try {
      final user = await AuthService.restoreSession();
      if (!mounted) return;
      if (user == null) {
        CurrentUser.clear();
        setState(() {
          _destination = const LoginScreen();
          _checking = false;
        });
        return;
      }

      CurrentUser.firstName = user['firstName'] as String?;
      CurrentUser.lastName = user['lastName'] as String?;
      CurrentUser.email = user['email'] as String?;
      CurrentUser.adminLevel = user['adminLevel'] as String?;
      CurrentUser.accountId = (user['accountId'] as num?)?.toInt();
      setState(() {
        _destination = _authorizedInitialPage();
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _retry = true;
        _checking = false;
      });
    }
  }

  Widget _authorizedInitialPage() {
    if (!kIsWeb) return const AppShell();
    final hash = web.window.location.hash;
    final route = hash.startsWith('#') ? hash.substring(1) : hash;
    switch (route) {
      case '/scan':
      case 'scan':
        return const QrScannerPage();
      case '/attendance':
      case 'attendance':
        return const AttendancePage();
      default:
        return const AppShell();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_retry) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Unable to verify your saved admin session. Check your connection and try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _restore, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return _destination ?? const LoginScreen();
  }
}
