import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/auth_theme.dart';
import '../services/auth_service.dart';

enum _Step { email, code, newPassword }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _obscure = true;

  bool _loading = false;
  _Step _step = _Step.email;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your email');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final result = await AuthService.forgotPassword(_emailController.text.trim());

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _step = _Step.code;
        _successMessage = result['message'];
      } else {
        _errorMessage = result['message'];
      }
    });
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter the code');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final result = await AuthService.verifyResetCode(
      _emailController.text.trim(),
      _codeController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _step = _Step.newPassword;
        _successMessage = null;
      } else {
        _errorMessage = result['message'];
      }
    });
  }

  Future<void> _resetPassword() async {
    if (_newPasswordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter a new password');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final result = await AuthService.resetPassword(
      _emailController.text.trim(),
      _codeController.text.trim(),
      _newPasswordController.text,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _successMessage = result['message'];
      } else {
        _errorMessage = result['message'];
      }
    });

    if (result['success'] == true) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
    }
  }

  String get _title {
    switch (_step) {
      case _Step.email:
        return 'Reset Admin Password';
      case _Step.code:
        return 'Enter Reset Code';
      case _Step.newPassword:
        return 'Set New Password';
    }
  }

  String get _subtitle {
    switch (_step) {
      case _Step.email:
        return 'Enter your admin email to receive a password reset code.';
      case _Step.code:
        return 'Enter the 6-digit code sent to your email.';
      case _Step.newPassword:
        return 'Choose a new password for your account.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 6, child: _buildInfoPanel()),
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: _buildFormPanel(),
                      ),
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildInfoPanel(compact: true),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                      child: _buildFormPanel(),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoPanel({bool compact = false}) {
    return buildAuthInfoPanel(compact: compact);
  }

  Widget _buildFormPanel() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_title, style: AuthFonts.heading(size: 22)),
            const SizedBox(height: 6),
            Text(_subtitle, style: AuthFonts.subtitle()),
            const SizedBox(height: 32),

            // STEP 1: EMAIL
            if (_step == _Step.email) ...[
              Text('Admin email address', style: AuthFonts.label()),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.black),
                decoration: authPillDecoration(hint: 'admin@primefit.com'),
              ),
            ],

            // STEP 2: CODE ONLY
            if (_step == _Step.code) ...[
              Text('6-digit code', style: AuthFonts.label()),
              const SizedBox(height: 8),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.black),
                decoration: authPillDecoration(hint: 'Enter the code from your email'),
              ),
            ],

            // STEP 3: NEW PASSWORD ONLY
            if (_step == _Step.newPassword) ...[
              Text('New password', style: AuthFonts.label()),
              const SizedBox(height: 8),
              TextField(
                controller: _newPasswordController,
                obscureText: _obscure,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.black),
                decoration: authPillDecoration(hint: 'Enter new password').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textMuted),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_errorMessage!,
                    style: AuthFonts.body(size: 13, color: Colors.red)),
              ),
            if (_successMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_successMessage!,
                    style: AuthFonts.body(size: 13, color: Colors.green)),
              ),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : () {
                        if (_step == _Step.email) {
                          _sendCode();
                        } else if (_step == _Step.code) {
                          _verifyCode();
                        } else {
                          _resetPassword();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _step == _Step.email
                            ? 'Send Reset Code'
                            : _step == _Step.code
                                ? 'Verify Code'
                                : 'Reset Password',
                        style: AuthFonts.button(size: 16),
                      ),
              ),
            ),

            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _loading
                    ? null
                    : () {
                        if (_step == _Step.email) {
                          Navigator.of(context).pop();
                        } else {
                          setState(() {
                            _step = _Step.email;
                            _codeController.clear();
                            _newPasswordController.clear();
                            _errorMessage = null;
                            _successMessage = null;
                          });
                        }
                      },
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFB45309)),
                child: Text(
                  _step == _Step.email ? '← Back to sign in' : 'Use a different email',
                  style: AuthFonts.link(size: 13, color: const Color(0xFFB45309)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
