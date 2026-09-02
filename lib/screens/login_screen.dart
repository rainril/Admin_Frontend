import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/auth_theme.dart';
import 'app_shell.dart';
import '../services/auth_service.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import '../services/current_user.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  // ignore: unused_field
  final bool _keepSignedIn = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final result = await AuthService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      CurrentUser.firstName = result['firstName'];
      CurrentUser.lastName = result['lastName'];
      CurrentUser.email = _emailController.text.trim();
      CurrentUser.adminLevel = result['adminLevel'];
      CurrentUser.accountId = result['accountId'];

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.dark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.gold, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result['message'] ?? 'Login failed',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.goldBg,
                    border: Border.all(color: AppColors.gold, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.shield_outlined, color: AppColors.gold, size: 30),
                ),
              ),
              const SizedBox(height: 18),
              Text('Staff Sign In',
                  style: AuthFonts.heading(),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('Enter your credentials to access the staff portal.',
                  style: AuthFonts.subtitle(),
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              Text('Email Address', style: AuthFonts.label()),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.black),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
                decoration: authPillDecoration(hint: 'Enter admin email'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Password', style: AuthFonts.label()),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB45309),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0)),
                    child: Text('Forgot password?',
                        style: AuthFonts.link(size: 13, color: const Color(0xFFB45309))),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.black),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  return null;
                },
                decoration: authPillDecoration(hint: 'Enter password').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textMuted),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
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
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text('Sign In', style: AuthFonts.button(size: 16)),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  child: Text.rich(
                    TextSpan(
                      text: "Don't have an account? ",
                      style: AuthFonts.body(size: 13.5, color: const Color(0xFF6B7280)),
                      children: [
                        TextSpan(
                          text: 'Sign Up',
                          style: AuthFonts.link(size: 13.5, color: const Color(0xFFB45309), weight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
