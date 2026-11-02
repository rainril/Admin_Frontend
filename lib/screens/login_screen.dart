import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _loading = false;

  // PrimeFit's real pages (same links the landing page uses).
  static const _facebookUrl =
      'https://www.facebook.com/profile.php?id=61579305812618';
  static const _tiktokUrl = 'https://www.tiktok.com/@primefit.fitness.g';

  // ---------------- design tokens ----------------
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
      showAuthSnack(context,
          message: result['message'] ?? 'Login failed', isError: true);
    }
  }

  /// Copies the page link (no extra package needed). To open the page
  /// directly instead, add the `url_launcher` package and replace the body
  /// with:  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  Future<void> _openSocial(String name, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name link copied: $url')),
    );
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCard(compact),
                  const SizedBox(height: 18),
                  _socialRow(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Sign-in card
  // ---------------------------------------------------------------------

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
      child: Form(
        key: _formKey,
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
                  style: GoogleFonts.archivoBlack(
                      fontSize: 24, letterSpacing: -0.4),
                  children: const [
                    TextSpan(
                        text: 'Prime',
                        style: TextStyle(color: AppColors.cyan)),
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

            // ---- heading ----
            Text(
              'Sign in to the staff portal',
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
              'Staff and administrators only. Access is restricted and monitored.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: compact ? 12.5 : 13,
                  height: 1.55,
                  color: _mutedText),
            ),
            const SizedBox(height: 20),

            // ---- email ----
            _label('Email address'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.inter(fontSize: 14.5, color: Colors.white),
              cursorColor: AppColors.cyan,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
              decoration: _inputDecoration(hint: 'Enter admin email'),
            ),
            const SizedBox(height: 14),

            // ---- password (+ forgot password) ----
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _label('Password'),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen()),
                    );
                  },
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0)),
                  child: Text('Forgot password?',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              style: GoogleFonts.inter(fontSize: 14.5, color: Colors.white),
              cursorColor: AppColors.cyan,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                return null;
              },
              decoration: _inputDecoration(hint: 'Enter password').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      size: 19,
                      color: _mutedIcon),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ---- sign in ----
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor:
                      AppColors.gold.withValues(alpha: 0.5),
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
                    : Text('Sign In',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 8),

            // ---- sign up ----
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
                    style: GoogleFonts.inter(
                        fontSize: 13.5, color: const Color(0xFFA7ADB5)),
                    children: [
                      TextSpan(
                        text: 'Sign Up',
                        style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.cyan),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // ---- restricted access note ----
            _restrictedNote(),
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

  /// Small "restricted access" box at the bottom of the card (this used to
  /// be the big card on the left side of the old layout).
  Widget _restrictedNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _fieldBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child:
                Icon(Icons.shield_outlined, size: 16, color: AppColors.gold),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: GoogleFonts.inter(
                    fontSize: 11.5, height: 1.45, color: const Color(0xFFA7ADB5)),
                children: [
                  TextSpan(
                    text: 'Restricted access. ',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                  const TextSpan(
                    text:
                        'This portal is for authorized PrimeFit Owner and Staff only. Unauthorized access attempts are logged and monitored.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
      errorBorder: border(Colors.redAccent),
      focusedErrorBorder: border(Colors.redAccent, 1.6),
      errorStyle: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent),
    );
  }

  // ---------------------------------------------------------------------
  // Under the card: social links + copyright (was at the bottom left)
  // ---------------------------------------------------------------------

  Widget _socialRow() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        _SocialButton(
          tooltip: 'Facebook',
          onTap: () => _openSocial('Facebook', _facebookUrl),
          child: Text(
            'f',
            style: GoogleFonts.inter(
              fontSize: 19,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        _SocialButton(
          tooltip: 'TikTok',
          onTap: () => _openSocial('TikTok', _tiktokUrl),
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CustomPaint(painter: _TikTokPainter()),
          ),
        ),
        const SizedBox(width: 2),
        Text(
          '© 2026 PrimeFit Fitness Gym',
          style: GoogleFonts.inter(
              fontSize: 12.5, color: const Color(0xFF7D838C)),
        ),
      ],
    );
  }
}

// =====================================================================
// Presentation-only pieces (no logic)
// =====================================================================

/// Small round button for a social icon.
class _SocialButton extends StatelessWidget {
  final String tooltip;
  final Widget child;
  final VoidCallback onTap;

  const _SocialButton({
    required this.tooltip,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFF17181C),
        shape: const CircleBorder(
            side: BorderSide(color: Color(0xFF262832))),
        child: InkWell(
          customBorder: const CircleBorder(),
          hoverColor: AppColors.cyan.withValues(alpha: 0.22),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// TikTok note drawn with a cyan and a pink offset behind a white stroke,
/// like the real logo (no image asset or icon package needed).
class _TikTokPainter extends CustomPainter {
  const _TikTokPainter();

  Path _note() {
    return Path()
      ..moveTo(13.5, 3.5)
      ..lineTo(13.5, 15.5)
      ..addArc(Rect.fromCircle(center: const Offset(10, 15.5), radius: 3.5), 0,
          6.2832)
      ..moveTo(13.5, 3.5)
      ..cubicTo(14, 6.5, 16, 8.2, 19.5, 8.4);
  }

  Paint _stroke(Color c) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);

    canvas.save();
    canvas.translate(-0.9, -0.6);
    canvas.drawPath(_note(), _stroke(const Color(0xFF25F4EE)));
    canvas.restore();

    canvas.save();
    canvas.translate(0.9, 0.6);
    canvas.drawPath(_note(), _stroke(const Color(0xFFFE2C55)));
    canvas.restore();

    canvas.drawPath(_note(), _stroke(Colors.white));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
