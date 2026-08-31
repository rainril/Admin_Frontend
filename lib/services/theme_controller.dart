import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Simpleng global controller para sa dark mode — ang buong app ay
/// makikinig dito (via ListenableBuilder sa main.dart) at magre-rebuild
/// gamit ang bagong theme kapag nagbago ang value.
class ThemeController extends ChangeNotifier {
  ThemeController._internal();
  static final ThemeController instance = ThemeController._internal();

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  void setDarkMode(bool value) {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();
  }

  ThemeData get lightTheme => AppTheme.light;
  ThemeData get darkTheme => AppTheme.dark;
}
