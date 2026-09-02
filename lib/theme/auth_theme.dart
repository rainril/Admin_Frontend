import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Shared typography for the auth screens (Login, Forgot Password, Register).
/// Archivo Black for headings/wordmark, Inter for everything else.
class AuthFonts {
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

/// Panel backdrop color sampled from the login background photo's darkest corners.
const Color authPanelBackdrop = Color(0xFF121212);

/// Rounded, filled "pill" style input decoration matching the auth screens'
/// soft light-gray text fields with no visible border until focused.
InputDecoration authPillDecoration({required String hint}) {
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

/// Reusable left info panel with background image, gradient overlay, and
/// bottom fade — shared across Login, Forgot Password, and Register screens.
/// Pass [compact] true for narrow/mobile layouts to hide the description box.
Widget buildAuthInfoPanel({bool compact = false}) {
  return Container(
    width: double.infinity,
    color: authPanelBackdrop,
    child: Stack(
      children: [
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Image.asset(
              'assets/images/login_bg.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (context, error, stackTrace) => Container(color: authPanelBackdrop),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    authPanelBackdrop.withValues(alpha: 0.85),
                    authPanelBackdrop.withValues(alpha: 0.35),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
        ),
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
                  colors: [authPanelBackdrop, authPanelBackdrop.withValues(alpha: 0)],
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
                    style: AuthFonts.wordmark(size: compact ? 26 : 34),
                    children: const [
                      TextSpan(text: 'Prime', style: TextStyle(color: AppColors.cyan)),
                      TextSpan(text: 'Fit', style: TextStyle(color: AppColors.gold)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text('Owner and Staff Portal',
                    style: AuthFonts.body(size: 16, color: Colors.white70)),
                if (!compact) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Secure access for gym owners and staffs. Manage members, billing, inventory, and AI-powered analytics from one place.',
                    style: AuthFonts.body(size: 14, color: Colors.white60, height: 1.5),
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
                                style: AuthFonts.label(size: 14, color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This portal is for authorized PrimeFit Owner and Staff only. Unauthorized access attempts are logged and monitored.',
                          style: AuthFonts.body(size: 13, color: Colors.white54, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text('© 2026 PrimeFit Fitness Gym',
                      style: AuthFonts.body(size: 12, color: Colors.white38)),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
