import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/current_user.dart';

/// PrimeFit brand palette — scoped to the sidebar only. The accent colors
/// (cyan/gold) stay constant across themes; the neutral tones swap for dark
/// mode so the sidebar doesn't stay pinned to a light appearance.
class _SidebarColors {
  static const Color cyan = Color(0xFF08AFC3);
  static const Color gold = Color(0xFFF5C400);

  /// Standard cyan blue for every nav icon, in every state — no exceptions.
  /// Kept separate from the brand [cyan] (which the logo text keeps) so the
  /// icons read as the usual cyan/blue accent.
  static const Color menuIcon = Color(0xFF00B0FF);

  /// Row feedback: the row lightens toward white on hover, and further while
  /// pressed. Stops well short of solid white on purpose — the labels on these
  /// rows are white, so a fully white row would erase its own text.
  static const Color hoverOverlay = Color(0x29FFFFFF);
  static const Color pressOverlay = Color(0x42FFFFFF);

  /// Destructive-action red for the Logout row's hover state. A lighter red
  /// than the usual `#DC2626` because that one was picked to sit on a white
  /// rail; on black it's too dark to read. Backgrounds layer it at low alpha
  /// so the row tints instead of turning into a bright block.
  static const Color danger = Color(0xFFF87171);

  final Color bg;
  final Color lightCyan;
  final Color textPrimary;
  final Color white;
  final Color lightGray;
  final Color mediumGray;
  final Color divider;

  const _SidebarColors({
    required this.bg,
    required this.lightCyan,
    required this.textPrimary,
    required this.white,
    required this.lightGray,
    required this.mediumGray,
    required this.divider,
  });

  /// One flat-black palette for both themes. The sidebar deliberately no
  /// longer follows `Theme.of(context).brightness` — it stays black with
  /// white text in light and dark mode alike, matching the member portal.
  static const palette = _SidebarColors(
    bg: Color(0xFF000000),
    lightCyan: Color(0xFF17323A),
    textPrimary: Color(0xFFFFFFFF),
    white: Color(0xFFFFFFFF),
    lightGray: Color(0xFF1C1F26),
    mediumGray: Color(0xFFFFFFFF),
    divider: Color(0xFF262A31),
  );

  static _SidebarColors of(BuildContext context) => palette;
}

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData(this.icon, this.label);
}

class Sidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  const Sidebar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.onLogout,
  });

  static const items = [
    _NavItemData(Icons.grid_view_rounded, 'Dashboard'),
    _NavItemData(Icons.qr_code_scanner_rounded, 'Attendance'),
    _NavItemData(Icons.center_focus_strong_rounded, 'Check-In'),
    _NavItemData(Icons.credit_card_outlined, 'Billing'),
    _NavItemData(Icons.receipt_long_outlined, 'Pending Payments'),
    _NavItemData(Icons.inventory_2_outlined, 'Inventory'),
    _NavItemData(Icons.settings_outlined, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _SidebarColors.of(context);
    return Container(
      width: 260,
      color: colors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------- Branding ----------------
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                // Bare circular logo — no outer ring. Same 42px footprint and
                // position as before; the image simply fills the whole circle
                // now instead of being inset by the ring's 2px.
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: const DecorationImage(
                      image: AssetImage('assets/primefit_logo.jpg'),
                      fit: BoxFit.cover,
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _SidebarColors.cyan.withValues(alpha: 0.28),
                        blurRadius: 14,
                        spreadRadius: -3,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.archivoBlack(fontSize: 17, letterSpacing: -0.3),
                        children: const [
                          TextSpan(text: 'Prime', style: TextStyle(color: _SidebarColors.cyan)),
                          TextSpan(text: 'Fit', style: TextStyle(color: _SidebarColors.gold)),
                        ],
                      ),
                    ),
                    Text('Admin Portal',
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.mediumGray.withValues(alpha: 0.6))),
                  ],
                )
              ],
            ),
          ),
          Divider(height: 1, color: colors.divider),
          const SizedBox(height: 16),

          // ---------------- Navigation ----------------
          Padding(
            padding: const EdgeInsets.fromLTRB(23, 0, 22, 10),
            child: Text(
              'MENU',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: colors.mediumGray.withValues(alpha: 0.55),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = index == currentIndex;
                return _SidebarNavItem(
                  icon: item.icon,
                  label: item.label,
                  selected: selected,
                  onTap: () => onSelect(index),
                );
              },
            ),
          ),

          Divider(height: 1, color: colors.divider),

          // ---------------- User profile ----------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _SidebarColors.cyan.withValues(alpha: 0.16),
                    border: Border.all(
                      color: _SidebarColors.cyan.withValues(alpha: 0.28),
                      width: 1,
                    ),
                  ),
                  child: const Icon(Icons.person, color: _SidebarColors.cyan, size: 19),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              CurrentUser.fullName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          if (CurrentUser.adminLevel != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: CurrentUser.isOwner
                                    ? _SidebarColors.gold.withValues(alpha: 0.18)
                                    : colors.lightCyan,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                CurrentUser.isOwner ? 'Owner' : 'Staff',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  // Bright gold, not the old dark-gold ink —
                                  // that was tuned for a white rail and is
                                  // unreadable on the black background.
                                  color: CurrentUser.isOwner
                                      ? _SidebarColors.gold
                                      : _SidebarColors.cyan,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrentUser.email ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.mediumGray.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),

          // ---------------- Logout ----------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _LogoutButton(onTap: onLogout),
          ),
        ],
      ),
    );
  }
}

/// A single sidebar nav row with default / active visual states. The icon
/// always sits in a colored chip so the rail doesn't read as flat, with the
/// chip going from a light cyan tint (default) to a solid cyan fill (active).
/// Active items get a gold left-border + small gold dot.
///
/// There is deliberately no hover treatment: rows look identical whether or
/// not the pointer is over them, so the active row is distinguished only by
/// its own highlight and never darkens further under the cursor.
class _SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = selected;

    // Soft cyan-tinted "pill" for the active row, with a faint cyan glow —
    // deliberately not a hard flat block or a left border.
    final Color rowBg =
        active ? _SidebarColors.cyan.withValues(alpha: 0.16) : Colors.transparent;
    final Color textColor = active
        ? Colors.white
        : Colors.white.withValues(alpha: 0.78);

    final Color chipBg = active
        ? _SidebarColors.cyan.withValues(alpha: 0.24)
        : Colors.white.withValues(alpha: 0.06);
    final Color iconColor = active
        ? _SidebarColors.menuIcon
        : Colors.white.withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: rowBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: _SidebarColors.cyan.withValues(alpha: 0.20),
                    blurRadius: 16,
                    spreadRadius: -3,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            hoverColor: Colors.white.withValues(alpha: 0.05),
            highlightColor: Colors.white.withValues(alpha: 0.08),
            splashColor: Colors.white.withValues(alpha: 0.08),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 18, color: iconColor),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logout row — lightens on hover and press exactly like the nav rows. The
/// one thing that sets it apart is its label and icon turning red on hover,
/// since it's a destructive action.
class _LogoutButton extends StatefulWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color chipBg = _hovered
        ? _SidebarColors.danger.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.06);
    final Color fg =
        _hovered ? _SidebarColors.danger : Colors.white.withValues(alpha: 0.65);
    final Color textColor = _hovered
        ? _SidebarColors.danger
        : Colors.white.withValues(alpha: 0.78);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            hoverColor: _SidebarColors.hoverOverlay,
            highlightColor: _SidebarColors.pressOverlay,
            splashColor: _SidebarColors.pressOverlay,
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.logout, size: 17, color: fg),
                  ),
                  const SizedBox(width: 13),
                  Text('Logout',
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          letterSpacing: -0.1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
