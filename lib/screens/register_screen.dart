import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
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

  String _adminLevel = 'staff'; // default value
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _loading = false;

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.dark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: AppColors.gold,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
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
                image: AssetImage('assets/primefit_logo.jpg'),
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
          const Text('Staff Portal',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          if (!compact) ...[
            const SizedBox(height: 16),
            const Text(
              'Create your staff or owner account to manage members, billing, inventory, and AI-powered analytics from one place.',
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.goldBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.gold),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Create Account',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text('Sign up as staff or owner',
                          style: TextStyle(color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // First & Last Name
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      label: 'First Name',
                      controller: _firstNameController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      label: 'Last Name',
                      controller: _lastNameController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildTextField(
                label: 'Email Address',
                controller: _emailController,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              const Text('Role', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _adminLevel,
                items: const [
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                  DropdownMenuItem(value: 'owner', child: Text('Owner')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _adminLevel = value);
                },
              ),
              const SizedBox(height: 20),

              const Text('Password', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 6) return 'Minimum 6 characters';
                  return null;
                },
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textMuted),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text('Confirm Password', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please confirm your password';
                  return null;
                },
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textMuted),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dark,
                    foregroundColor: Colors.white,
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Create Account',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: const Text.rich(
                    TextSpan(
                      text: 'Already have an account? ',
                      style: TextStyle(color: AppColors.textMuted),
                      children: [
                        TextSpan(
                          text: 'Sign In',
                          style: TextStyle(
                              color: Color(0xFFB45309), fontWeight: FontWeight.w600),
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(controller: controller, validator: validator),
      ],
    );
  }
}