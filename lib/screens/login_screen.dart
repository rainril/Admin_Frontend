import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';
import '../services/auth_service.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import '../services/current_user.dart';

/// Shared typography for this screen, matched to the member Sign In
/// page: Archivo Black for the bold heading, Inter for everything else
/// (subtitle, labels, inputs, links, buttons).
class _AuthFonts {
  static TextStyle heading({double size = 24, Color color = Colors.black}) =>
      GoogleFonts.archivoBlack(
        fontSize: size,
        color: color,
        height: 1.15,
        letterSpacing: -0.3,
      );

  static TextStyle wordmark({double size = 26}) => GoogleFonts.archivoBlack(
        fontSize: size,
        height: 1.1,
        letterSpacing: -0.3,
      );

  static TextStyle subtitle({double size = 14, Color color = const Color(0xFF6B7280)}) =>
      GoogleFonts.inter(fontSize: size, color: color, height: 1.4, fontWeight: FontWeight.w400);

  static TextStyle label({double size = 13, Color color = Colors.black}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.w600, color: color);

  static TextStyle body({double size = 13.5, Color color = Colors.black87, double height = 1.5}) =>
      GoogleFonts.inter(fontSize: size, color: color, height: height, fontWeight: FontWeight.w400);

  static TextStyle link({double size = 13.5, required Color color, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.inter(fontSize: size, color: color, fontWeight: weight);

  static TextStyle button({double size = 15, Color color = Colors.white}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.6);
}

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

    // Full-screen layout — the info panel and form panel now stretch
    // to fill the whole viewport, instead of floating as a centered
    // card with a margin/background around it.
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 7, child: _buildInfoPanel()),
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
      ),
    );
  }

  // Sampled directly from the photo's own backdrop (its darkest corners
  // sit around RGB 12-20, neutral) so the flat panel area matches the
  // photo's actual black instead of AppColors.dark's slightly different tone.
  static const Color _panelBackdrop = Color(0xFF121212);

  Widget _buildInfoPanel({bool compact = false}) {
    return Container(
      width: double.infinity,
      color: _panelBackdrop,
      child: Stack(
        children: [
          // Background photo. Falls back to the plain dark brand color
          // if the asset isn't found, instead of crashing the page.
          Positioned.fill(
            child: Image.asset(
              'assets/images/login_bg.jpg',
              fit: BoxFit.contain,
              alignment: Alignment.centerRight,
              errorBuilder: (context, error, stackTrace) => Container(color: _panelBackdrop),
            ),
          ),
          // Soft fade only where the figure/rope actually gets clipped —
          // the bottom edge of the photo — so it melts into the panel
          // instead of showing a hard cut. Left untouched everywhere else.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 60,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [_panelBackdrop, _panelBackdrop.withValues(alpha: 0)],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(40, compact ? 40 : 60, 40, compact ? 32 : 40),
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: compact ? 64 : 90,
                    height: compact ? 64 : 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: const DecorationImage(
                        image: AssetImage('assets/primefit_logo.jpg'),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  RichText(
                    text: TextSpan(
                      style: _AuthFonts.wordmark(size: compact ? 26 : 34),
                      children: const [
                        TextSpan(text: 'Prime', style: TextStyle(color: AppColors.cyan)),
                        TextSpan(text: 'Fit', style: TextStyle(color: AppColors.gold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Owner and Staff Portal',
                      style: _AuthFonts.body(size: 16, color: Colors.white70)),
                  if (!compact) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Secure access for gym owners and staffs. Manage members, billing, inventory, and AI-powered analytics from one place.',
                      style: _AuthFonts.body(size: 14, color: Colors.white60, height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_outlined, color: AppColors.gold, size: 18),
                              const SizedBox(width: 8),
                              Text('Restricted Access',
                                  style: _AuthFonts.label(size: 14, color: Colors.white)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This portal is for authorized PrimeFit Owner and Staff only. Unauthorized access attempts are logged and monitored.',
                            style: _AuthFonts.body(size: 13, color: Colors.white54, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text('© 2026 PrimeFit Fitness Gym',
                        style: _AuthFonts.body(size: 12, color: Colors.white38)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
              // Centered badge + title + subtitle, matching the inspo's
              // centered header instead of the old left-aligned icon row.
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
                  style: _AuthFonts.heading(),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('Enter your credentials to access the staff portal.',
                  style: _AuthFonts.subtitle(),
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              Text('Email Address', style: _AuthFonts.label()),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.black),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
                decoration: _pillDecoration(hint: 'Enter admin email'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Password', style: _AuthFonts.label()),
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
                        style: _AuthFonts.link(size: 13, color: const Color(0xFFB45309))),
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
                decoration: _pillDecoration(hint: 'Enter password').copyWith(
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
                      : Text('Sign In', style: _AuthFonts.button(size: 16)),
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
                      style: _AuthFonts.body(size: 13.5, color: const Color(0xFF6B7280)),
                      children: [
                        TextSpan(
                          text: 'Sign Up',
                          style: _AuthFonts.link(size: 13.5, color: const Color(0xFFB45309), weight: FontWeight.w600),
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

  // Rounded, filled "pill" style input decoration matching the inspo's
  // soft light-gray text fields with no visible border until focused.
  InputDecoration _pillDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.6),
      ),
    );
  }
}
