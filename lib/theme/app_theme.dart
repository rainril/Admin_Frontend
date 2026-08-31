import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central color palette matching the PrimeFit admin portal design.
class AppColors {
  static const cyan = Color(0xFF17C3D6);
  static const cyanDark = Color(0xFF0E8FA0);
  static const gold = Color(0xFFF2B705);
  static const dark = Color(0xFF0B0B0D);
  static const bg = Color(0xFFF7F8FA); // soft off-white main content ground
  static const cardBorder = Color(0xFFE7E9EE);
  static const textMuted = Color(0xFF6B7280);

  static const success = Color(0xFF16A34A);
  static const successBg = Color(0xFFDCFCE7);
  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFEE2E2);
  static const warning = Color(0xFFCA8A04);
  static const warningBg = Color(0xFFFEF3C7);

  static const blueBg = Color(0xFFDBEAFE);
  static const blueIcon = Color(0xFF3B82F6);
  static const greenBg = Color(0xFFD1FAE5);
  static const greenIcon = Color(0xFF10B981);
  static const goldBg = Color(0xFFFEF3C7);
  static const tealBg = Color(0xFFCCFBF1);
  static const tealIcon = Color(0xFF0D9488);

  // Inventory Screen Colors
  static const inventoryPrimary = Color(0xFF00B4D8);
  static const inventoryHeader = Color(0xFF1E293B);

  // ---- Dark-mode surface counterparts ----
  // Kept separate (rather than swapping the constants above) so any code
  // still reading e.g. AppColors.bg directly gets the light value; screens
  // should prefer the theme-aware helpers below instead.
  static const bgDark = Color(0xFF121417);
  static const cardDark = Color(0xFF1E2126);
  static const cardBorderDark = Color(0xFF2C3038);
  static const textMutedDark = Color(0xFF9CA3AF);
  static const headingDark = Color(0xFFE9EAEE);
}

/// Consistent corner radii for the whole portal. Cards and containers use
/// [card]; buttons, inputs, chips and small controls use [control].
class AppRadius {
  static const double card = 16;
  static const double control = 10;
  static const double chip = 8;
  static const double pill = 999;
}

/// Consistent spacing rhythm. [section] is the vertical gap between the
/// major blocks on a page (header → stat row → insight card → chart …);
/// [card] is the inner padding of a card/container; [gap] is the small
/// gap between side-by-side items.
class AppSpacing {
  static const double section = 28;
  static const double card = 22;
  static const double gap = 16;
}

class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppColors.bgDark : AppColors.bg;
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final borderColor = isDark ? AppColors.cardBorderDark : AppColors.cardBorder;
    final bodyColor = isDark ? AppColors.headingDark : Colors.black87;
    final mutedColor = isDark ? AppColors.textMutedDark : AppColors.textMuted;

    // One typeface for the whole portal, matching the Login screen: Inter for
    // all body / label / button text, Archivo Black for the big page headings
    // (mirrors _AuthFonts in login_screen.dart).
    final baseText = GoogleFonts.interTextTheme(
      (isDark ? ThemeData.dark() : ThemeData.light()).textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardBg,
      dividerColor: borderColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.cyan,
        brightness: brightness,
        primary: AppColors.cyan,
        secondary: AppColors.gold,
        surface: cardBg,
      ),
      textTheme: baseText
          .apply(bodyColor: bodyColor, displayColor: bodyColor)
          .copyWith(
            // A clearer, more confident type scale applied portal-wide.
            headlineMedium: GoogleFonts.archivoBlack(
              fontSize: 30,
              letterSpacing: -0.5,
              height: 1.12,
              color: bodyColor,
            ),
            titleLarge: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: bodyColor,
            ),
            titleMedium: GoogleFonts.inter(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: bodyColor,
            ),
            bodyMedium: GoogleFonts.inter(
              fontSize: 14,
              height: 1.45,
              color: bodyColor,
            ),
            bodySmall: GoogleFonts.inter(
              fontSize: 12.5,
              height: 1.4,
              color: mutedColor,
            ),
            labelLarge: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
      iconTheme: IconThemeData(color: bodyColor),
      cardTheme: CardThemeData(
        color: cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: borderColor),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cardBg,
        foregroundColor: bodyColor,
        elevation: 0.5,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: bodyColor,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardBg,
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: bodyColor),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowHeight: 44,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 56,
        horizontalMargin: 20,
        columnSpacing: 28,
        dividerThickness: 1,
        headingTextStyle: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: mutedColor,
        ),
        dataTextStyle: GoogleFonts.inter(fontSize: 13.5, color: bodyColor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        hintStyle: TextStyle(color: mutedColor),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Theme-aware colour helpers
  // ---------------------------------------------------------------------------

  /// Theme-aware "card surface" color — use in place of hardcoded
  /// Colors.white for card/container backgrounds.
  static Color surface(BuildContext context) => Theme.of(context).cardColor;

  /// Theme-aware card/divider border color — use in place of
  /// AppColors.cardBorder.
  static Color border(BuildContext context) => Theme.of(context).dividerColor;

  /// Theme-aware page background — use in place of AppColors.bg.
  static Color pageBackground(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  /// Theme-aware muted/secondary text color.
  static Color textMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.textMutedDark
          : AppColors.textMuted;

  /// Theme-aware primary heading/body text color — use in place of
  /// hardcoded dark literals like AppColors.inventoryHeader, Colors.black87,
  /// or Color(0xFF1E293B)/Color(0xFF334155)/Color(0xFF1A1D23).
  static Color heading(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.headingDark
          : AppColors.inventoryHeader;

  /// A subtle "sunken" fill for section headers inside tables, toggle
  /// tracks and quiet backgrounds.
  static Color subtleFill(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF23262D)
          : const Color(0xFFF8FAFC);

  // ---------------------------------------------------------------------------
  // Shared card surface
  // ---------------------------------------------------------------------------

  /// The one card look for the whole portal: [AppRadius.card] corners, a
  /// soft 1px border and — in light mode — a barely-there drop shadow that
  /// gives cards gentle depth instead of reading as flat blocks. Dark mode
  /// leans on the border alone (shadows disappear on dark surfaces anyway).
  ///
  /// Pass an [accent] (always from PrimeFit's own palette — cyan, gold, a
  /// soft green, a warm amber, …) to give the card a subtle semantic tint:
  /// a faint accent-tinted fill, a slightly stronger accent border and an
  /// accent-coloured glow instead of the neutral one. Keep it quiet — this
  /// is a hint, not a highlight.
  static BoxDecoration cardDecoration(
    BuildContext context, {
    bool elevated = true,
    double radius = AppRadius.card,
    Color? accent,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final baseBorder = Theme.of(context).dividerColor;
    return BoxDecoration(
      color: accent == null
          ? cardBg
          : Color.alphaBlend(
              accent.withValues(alpha: isDark ? 0.06 : 0.035), cardBg),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: accent == null
            ? baseBorder
            : Color.alphaBlend(accent.withValues(alpha: 0.30), baseBorder),
      ),
      boxShadow: (elevated && !isDark)
          ? [
              BoxShadow(
                color: accent == null
                    ? const Color(0x0D111827)
                    : accent.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
            ]
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Accent tints for cells / list items — cohesive with cyan + gold
  // ---------------------------------------------------------------------------

  /// A very faint accent wash for a table row / list cell background.
  static Color accentFill(BuildContext context, Color accent) =>
      Color.alphaBlend(
        accent.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? 0.07 : 0.05),
        Theme.of(context).cardColor,
      );

  /// The alternating ("zebra") background for every other data-table row.
  static Color? zebraRow(BuildContext context, int index) =>
      index.isOdd ? subtleFill(context) : null;

  // ---------------------------------------------------------------------------
  // Typography helpers — one hierarchy, applied the same way on every page
  // ---------------------------------------------------------------------------

  /// Big, confident page heading (e.g. "Dashboard", "Billing & Payments") —
  /// Archivo Black, matching the Login screen's heading.
  static TextStyle pageTitle(BuildContext context) => GoogleFonts.archivoBlack(
        fontSize: 30,
        letterSpacing: -0.5,
        height: 1.12,
        color: heading(context),
      );

  /// The muted line under a page title ("Welcome back! …").
  static TextStyle pageSubtitle(BuildContext context) => GoogleFonts.inter(
        fontSize: 14.5,
        height: 1.4,
        color: textMuted(context),
      );

  /// Title of a card or a section within a page.
  static TextStyle sectionTitle(BuildContext context) => GoogleFonts.inter(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: heading(context),
      );

  /// The small muted line under a card/section title.
  static TextStyle cardSubtitle(BuildContext context) => GoogleFonts.inter(
        fontSize: 12.5,
        height: 1.35,
        color: textMuted(context),
      );

  /// The large number on a stat card.
  static TextStyle statValue(BuildContext context) => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.05,
        color: heading(context),
      );

  /// The caption under a stat number.
  static TextStyle statLabel(BuildContext context) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textMuted(context),
      );

  /// A field / form label.
  static TextStyle fieldLabel(BuildContext context) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: heading(context),
      );
}
