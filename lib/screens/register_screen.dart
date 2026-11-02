import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/auth_theme.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _adminLevel = 'staff';
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _loading = false;

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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      _showMessage('Passwords do not match', isError: true);
      return;
    }

    setState(() => _loading = true);

    final result = await AuthService.register(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      adminLevel: _adminLevel,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      _showMessage('Account created successfully! Please sign in.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      _showMessage(result['message'] ?? 'Registration failed', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    showAuthSnack(context, message: message, isError: isError);
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
              constraints: const BoxConstraints(maxWidth: 480),
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
      padding: EdgeInsets.fromLTRB(compact ? 22 : 36, compact ? 26 : 30,
          compact ? 22 : 36, compact ? 20 : 24),
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
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text.rich(
                TextSpan(
                  style: GoogleFonts.archivoBlack(
                      fontSize: 22, letterSpacing: -0.4),
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
            const SizedBox(height: 4),
            Center(
              child: Text(
                'OWNER & STAFF PORTAL',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.8,
                  color: const Color(0xFFC9CDD3),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ---- heading ----
            Text(
              'Create your account',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: compact ? 21 : 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign up as staff or owner.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: _mutedText),
            ),
            const SizedBox(height: 18),

            // First & Last Name
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'First name',
                    controller: _firstNameController,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    label: 'Last name',
                    controller: _lastNameController,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _buildTextField(
              label: 'Email address',
              controller: _emailController,
              hint: 'admin@primefit.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Role
            _label('Role'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _adminLevel,
              decoration: _inputDecoration(hint: ''),
              style: GoogleFonts.inter(fontSize: 14.5, color: Colors.white),
              dropdownColor: const Color(0xFF1E2025),
              iconEnabledColor: _mutedIcon,
              items: const [
                DropdownMenuItem(value: 'staff', child: Text('Staff')),
                DropdownMenuItem(value: 'owner', child: Text('Owner')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _adminLevel = value);
              },
            ),
            const SizedBox(height: 14),

            // Password
            _label('Password'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              style: GoogleFonts.inter(fontSize: 14.5, color: Colors.white),
              cursorColor: AppColors.cyan,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 6) return 'Minimum 6 characters';
                return null;
              },
              decoration: _inputDecoration(hint: 'Enter password').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                      size: 19, color: _mutedIcon),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Confirm Password
            _label('Confirm password'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              style: GoogleFonts.inter(fontSize: 14.5, color: Colors.white),
              cursorColor: AppColors.cyan,
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please confirm your password';
                }
                return null;
              },
              decoration: _inputDecoration(hint: 'Confirm password').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      size: 19,
                      color: _mutedIcon),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ---- create account ----
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
                    : Text('Create Account',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 6),

            // ---- sign in ----
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: Text.rich(
                  TextSpan(
                    text: 'Already have an account? ',
                    style: GoogleFonts.inter(
                        fontSize: 13.5, color: const Color(0xFFA7ADB5)),
                    children: [
                      TextSpan(
                        text: 'Sign In',
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    String hint = '',
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 14.5, color: Colors.white),
          cursorColor: AppColors.cyan,
          validator: validator,
          decoration: _inputDecoration(hint: hint),
        ),
      ],
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      border: border(_fieldBorder),
      enabledBorder: border(_fieldBorder),
      focusedBorder: border(AppColors.cyan, 1.6),
      errorBorder: border(Colors.redAccent),
      focusedErrorBorder: border(Colors.redAccent, 1.6),
      errorStyle: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent),
    );
  }
}
