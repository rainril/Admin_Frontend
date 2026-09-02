import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_application_1/screens/attendance_page.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/screens/qr_scanner_page.dart';
import 'theme/app_theme.dart';
import 'services/theme_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    PrimeFitApp(
      initialPage: _resolveInitialPage(),
    ),
  );
}

Widget _resolveInitialPage() {
  if (!kIsWeb) {
    return const LoginScreen();
  }

  final hash = web.window.location.hash;

  final route = hash.startsWith('#')
      ? hash.substring(1)
      : hash;

  switch (route) {
    case '/scan':
    case 'scan':
      return const QrScannerPage();

    case '/attendance':
    case 'attendance':
      return const AttendancePage();

    case '':
    case '/':
    default:
      return const LoginScreen();
  }
}

class PrimeFitApp extends StatelessWidget {
  const PrimeFitApp({
    super.key,
    required this.initialPage,
  });

  final Widget initialPage;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'PrimeFit Admin',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeController.instance.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: initialPage,
        );
      },
    );
  }
}
