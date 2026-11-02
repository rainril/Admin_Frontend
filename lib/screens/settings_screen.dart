import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/current_user.dart';
import '../services/settings_service.dart';
import '../services/theme_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _firstNameController = TextEditingController(text: 'Admin');
  final _lastNameController = TextEditingController(text: 'User');
  final _emailController = TextEditingController(text: 'admin@primefit.com');
  final _phoneController = TextEditingController(text: '+63 917 847 8351');

  final _gymNameController = TextEditingController(text: 'PrimeFit Fitness Gym');
  final _addressController = TextEditingController(text: 'Taguig City, Philippines');
  final _hoursController = TextEditingController(text: '6:00 AM – 10:00 PM');

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _notificationsEnabled = true;
  bool _darkMode = false;
  bool _loadingSettings = true;
  bool _changingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  @override
  void initState() {
    super.initState();
    _firstNameController.text = CurrentUser.firstName ?? 'Admin';
    _lastNameController.text = CurrentUser.lastName ?? '';
    _emailController.text = CurrentUser.email ?? '';
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final accountId = CurrentUser.accountId;
    if (accountId == null) {
      setState(() => _loadingSettings = false);
      return;
    }
    final settings = await SettingsService.getSettings(accountId);
    if (mounted) {
      setState(() {
        if (settings != null) {
          _notificationsEnabled = settings['notificationsEnabled'] ?? true;
          _darkMode = settings['darkMode'] ?? false;
          ThemeController.instance.setDarkMode(_darkMode);
        }
        _loadingSettings = false;
      });
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade600 : null,
      ),
    );
  }

  Future<void> _onToggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    final accountId = CurrentUser.accountId;
    if (accountId == null) return;
    final success = await SettingsService.updateSettings(
      accountId: accountId,
      notificationsEnabled: value,
    );
    if (!success) {
      _snack('Failed to update notifications setting', isError: true);
    }
  }

  Future<void> _onToggleDarkMode(bool value) async {
    setState(() => _darkMode = value);
    ThemeController.instance.setDarkMode(value); // agad na mag-a-apply
    final accountId = CurrentUser.accountId;
    if (accountId == null) return;
    final success = await SettingsService.updateSettings(
      accountId: accountId,
      darkMode: value,
    );
    if (!success) {
      _snack('Failed to update dark mode setting', isError: true);
    }
  }

  Future<void> _onChangePassword() async {
    final current = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _snack('Please fill in all password fields', isError: true);
      return;
    }
    if (newPass.length < 6) {
      _snack('New password must be at least 6 characters', isError: true);
      return;
    }
    if (newPass != confirm) {
      _snack('New password and confirmation do not match', isError: true);
      return;
    }

    final accountId = CurrentUser.accountId;
    if (accountId == null) {
      _snack('Unable to identify account. Please log in again.', isError: true);
      return;
    }

    setState(() => _changingPassword = true);
    final result = await SettingsService.changePassword(
      accountId: accountId,
      currentPassword: current,
      newPassword: newPass,
    );
    setState(() => _changingPassword = false);

    if (result['success'] == true) {
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _snack('Password changed successfully');
    } else {
      _snack(result['message'] ?? 'Failed to change password', isError: true);
    }
  }

  // ---------------------------------------------------------------------
  // Presentation helpers (styling only, no logic)
  // ---------------------------------------------------------------------

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  /// Dark solid button (cyan in dark mode), replaces the gold button.
  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _isDark ? AppColors.cyan : const Color(0xFF111827),
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  /// Plain bordered field (no tinted fill), cyan border when focused.
  InputDecoration _inputDecoration({Widget? suffixIcon}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Theme.of(context).dividerColor),
    );
    return InputDecoration(
      isDense: true,
      filled: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.cyan),
      ),
      suffixIcon: suffixIcon,
    );
  }

  TextStyle get _labelStyle => TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: AppTheme.heading(context),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 900;

      final left = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(
            title: 'Admin Profile',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                isWide
                    ? Row(
                        children: [
                          Expanded(child: _labeledField('First Name', _firstNameController)),
                          const SizedBox(width: 16),
                          Expanded(child: _labeledField('Last Name', _lastNameController)),
                        ],
                      )
                    : Column(
                        children: [
                          _labeledField('First Name', _firstNameController),
                          const SizedBox(height: 16),
                          _labeledField('Last Name', _lastNameController),
                        ],
                      ),
                const SizedBox(height: 16),
                _labeledField('Email', _emailController),
                const SizedBox(height: 16),
                _labeledField('Phone', _phoneController),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _snack('Profile changes saved'),
                    style: _primaryButtonStyle(),
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          _card(
            title: 'Account Settings',
            child: _loadingSettings
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Change Password',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.heading(context),
                          )),
                      const SizedBox(height: 12),
                      _passwordField('Current Password', _currentPasswordController, _obscureCurrent,
                          () => setState(() => _obscureCurrent = !_obscureCurrent)),
                      const SizedBox(height: 12),
                      _passwordField('New Password', _newPasswordController, _obscureNew,
                          () => setState(() => _obscureNew = !_obscureNew)),
                      const SizedBox(height: 12),
                      _passwordField('Confirm New Password', _confirmPasswordController, _obscureNew,
                          () => setState(() => _obscureNew = !_obscureNew)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _changingPassword ? null : _onChangePassword,
                          style: _primaryButtonStyle(),
                          child: _changingPassword
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Update Password'),
                        ),
                      ),
                      Divider(height: 32, color: Theme.of(context).dividerColor),
                      _toggleRow('Enable notifications', _notificationsEnabled, _onToggleNotifications),
                      _toggleRow('Dark mode', _darkMode, _onToggleDarkMode),
                    ],
                  ),
          ),
        ],
      );

      final right = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(
            title: 'Gym Information',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _labeledField('Gym Name', _gymNameController),
                const SizedBox(height: 16),
                _labeledField('Address', _addressController),
                const SizedBox(height: 16),
                _labeledField('Opening Hours', _hoursController),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _snack('Gym information updated'),
                    style: _primaryButtonStyle(),
                    child: const Text('Update Info'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: AppSpacing.section),
            isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: left),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: right),
                    ],
                  )
                : Column(
                    children: [left, const SizedBox(height: AppSpacing.section), right],
                  ),
            const SizedBox(height: AppSpacing.section),
          ],
        ),
      );
    });
  }

  /// Plain page title (replaces the big cyan banner).
  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppTheme.heading(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage system configuration and preferences',
          style: TextStyle(fontSize: 14, color: AppTheme.textMuted(context)),
        ),
      ],
    );
  }

  /// White rounded card with hairline border + soft shadow.
  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: _isDark
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: AppTheme.heading(context),
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _labeledField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 8),
        TextFormField(controller: controller, decoration: _inputDecoration()),
      ],
    );
  }

  Widget _passwordField(
    String label,
    TextEditingController controller,
    bool obscure,
    VoidCallback onToggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          decoration: _inputDecoration(
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                size: 20,
                color: AppTheme.textMuted(context),
              ),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.heading(context),
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.cyan,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
