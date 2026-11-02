import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
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

  // ---------------- design tokens (same as the staff sign-in page) ----------------
  static const Color _pageBg = Color(0xFF0B0B0C);
  static const Color _cardBg = Color(0xFF15161A);
  static const Color _cardBorder = Color(0xFF262832);
  static const Color _fieldFill = Color(0xFF1E2025);
  static const Color _fieldBorder = Color(0xFF2C2F36);
  static const Color _mutedText = Color(0xFF9CA3AF);
  static const Color _mutedIcon = Color(0xFF7D838C);

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
        return 'Reset admin password';
      case _Step.code:
        return 'Enter reset code';
      case _Step.newPassword:
        return 'Set a new password';
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

  // ---------------------------------------------------------------------
  // Layout: one centered card on a plain black page
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 520;

    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                horizontal: compact ? 16 : 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _buildCard(compact),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(bool compact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(compact ? 22 : 36, compact ? 28 : 32,
          compact ? 22 : 36, compact ? 22 : 26),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 80,
            offset: const Offset(0, 30),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- brand header ----
          Center(
            child: ClipOval(
              child: Image.asset(
                'assets/primefit_logo.jpg',
                width: 54,
                height: 54,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text.rich(
              TextSpan(
                style:
                    GoogleFonts.archivoBlack(fontSize: 24, letterSpacing: -0.4),
                children: const [
                  TextSpan(
                      text: 'Prime', style: TextStyle(color: AppColors.cyan)),
                  TextSpan(
                      text: 'Fit', style: TextStyle(color: AppColors.gold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'OWNER & STAFF PORTAL',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.8,
                color: const Color(0xFFC9CDD3),
              ),
            ),
          ),
          SizedBox(height: compact ? 20 : 24),

          // ---- step progress (1 of 3) ----
          _stepBars(),
          const SizedBox(height: 20),

          // ---- heading ----
          Text(
            _title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: compact ? 21 : 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: compact ? 12.5 : 13, height: 1.55, color: _mutedText),
          ),
          const SizedBox(height: 22),

          // STEP 1: EMAIL
          if (_step == _Step.email) ...[
            _label('Admin email address'),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.inter(fontSize: 14.5, color: Colors.white),
              cursorColor: AppColors.cyan,
              decoration: _inputDecoration(hint: 'admin@primefit.com'),
            ),
          ],

          // STEP 2: CODE ONLY
          if (_step == _Step.code) ...[
            _label('6-digit code'),
            const SizedBox(height: 8),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(fontSize: 14.5, color: Colors.white),
              cursorColor: AppColors.cyan,
              decoration:
                  _inputDecoration(hint: 'Enter the code from your email'),
            ),
          ],

          // STEP 3: NEW PASSWORD ONLY
          if (_step == _Step.newPassword) ...[
            _label('New password'),
            const SizedBox(height: 8),
            TextField(
              controller: _newPasswordController,
              obscureText: _obscure,
              style: GoogleFonts.inter(fontSize: 14.5, color: Colors.white),
              cursorColor: AppColors.cyan,
              decoration: _inputDecoration(hint: 'Enter new password').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                      size: 19, color: _mutedIcon),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ],

          const SizedBox(height: 18),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.redAccent)),
            ),
          if (_successMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_successMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: const Color(0xFF4ADE80))),
            ),

          // ---- main action ----
          SizedBox(
            height: 50,
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
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.5),
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2),
                    )
                  : Text(
                      _step == _Step.email
                          ? 'Send Reset Code'
                          : _step == _Step.code
                              ? 'Verify Code'
                              : 'Reset Password',
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
            ),
          ),

          const SizedBox(height: 10),
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
              style: TextButton.styleFrom(foregroundColor: AppColors.cyan),
              child: Text(
                _step == _Step.email ? '← Back to sign in' : 'Use a different email',
                style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cyan),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Three small bars showing which step of the reset you're on.
  Widget _stepBars() {
    final current = _step.index;
    return Center(
      child: SizedBox(
        width: 150,
        child: Row(
          children: [
            for (int i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: i < current
                        ? AppColors.cyan
                        : i == current
                            ? AppColors.gold
                            : const Color(0xFF2A2D31),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFC4C8CE)),
      );

  // Dark filled input with the label above it.
  InputDecoration _inputDecoration({required String hint}) {
    OutlineInputBorder border(Color c, [double w = 1.2]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle:
          GoogleFonts.inter(fontSize: 14.5, color: const Color(0xFF6F7681)),
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(_fieldBorder),
      enabledBorder: border(_fieldBorder),
      focusedBorder: border(AppColors.cyan, 1.6),
    );
  }
}
