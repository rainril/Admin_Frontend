import 'package:flutter/material.dart';
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
      body: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: _buildInfoPanel()),
                Expanded(
                  flex: 6,
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
    );
  }

  Widget _buildInfoPanel({bool compact = false}) {
    return Container(
      width: double.infinity,
      color: AppColors.dark,
      padding: EdgeInsets.fromLTRB(40, compact ? 40 : 60, 40, compact ? 32 : 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 64 : 90,
            height: compact ? 64 : 90,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: AssetImage('assets/images/logo.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 20),
          RichText(
            text: TextSpan(
              style: TextStyle(
                  fontSize: compact ? 26 : 34, fontWeight: FontWeight.bold),
              children: const [
                TextSpan(text: 'Prime', style: TextStyle(color: AppColors.cyan)),
                TextSpan(text: 'Fit', style: TextStyle(color: AppColors.gold)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text('Admin Portal',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          if (!compact) ...[
            const SizedBox(height: 16),
            const Text(
              'Secure access for gym staff and owners. Manage members, billing, inventory, and AI-powered analytics from one place.',
              style: TextStyle(color: Colors.white60, height: 1.5),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, color: AppColors.gold, size: 18),
                      SizedBox(width: 8),
                      Text('Restricted Access',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This portal is for authorized PrimeFit staff only. Unauthorized access attempts are logged and monitored.',
                    style:
                        TextStyle(color: Colors.white54, height: 1.4, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('© 2026 PrimeFit Fitness Gym',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildFormPanel() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(_subtitle, style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 32),

            // STEP 1: EMAIL
            if (_step == _Step.email) ...[
              const Text('Admin email address', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(hintText: 'admin@primefit.com'),
              ),
            ],

            // STEP 2: CODE ONLY
            if (_step == _Step.code) ...[
              const Text('6-digit code', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Enter the code from your email'),
              ),
            ],

            // STEP 3: NEW PASSWORD ONLY
            if (_step == _Step.newPassword) ...[
              const Text('New password', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _newPasswordController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: 'Enter new password',
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
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
            if (_successMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_successMessage!, style: const TextStyle(color: Colors.green)),
              ),

            SizedBox(
              width: double.infinity,
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
                  backgroundColor: AppColors.dark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                child: Text(_step == _Step.email ? '← Back to sign in' : 'Use a different email'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}