import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/current_user.dart';
import '../theme/app_theme.dart';

/// Sidebar-specific tuning that isn't a general-purpose app color: hover/press
/// overlays and a lightened destructive-red calibrated to sit on the solid
/// cyan rail. Brand colors (cyan/gold) come from the shared [AppColors]
/// instead of being redeclared here.
class _SidebarColors {
  /// Row feedback: the row lightens toward white on hover, and further while
  /// pressed. Stops well short of solid white on purpose — the labels on these
  /// rows are white, so a fully white row would erase its own text.
  static const Color hoverOverlay = Color(0x24FFFFFF);
  static const Color pressOverlay = Color(0x38FFFFFF);

  /// Destructive-action red for the Sign Out row's hover state. Lighter than
  /// the usual `AppColors.danger` because that one was tuned to sit on a
  /// white surface; on solid cyan it needs to be lighter to read clearly.
  static const Color danger = Color(0xFFFFD9D6);
}

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData(this.icon, this.label);
}

/// First letter of up to the first two words of [name], upper-cased, for the
/// user-profile avatar circle. Falls back to "A" for an empty/blank name.
String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'A';
  final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
  return letters;
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
    // Solid flat cyan rail — deliberately no gradient — matching the
    // reference design's dark teal/cyan sidebar.
    return Container(
      width: 260,
      color: AppColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------- Branding ----------------
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
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
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
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
                          TextSpan(text: 'Prime', style: TextStyle(color: Colors.white)),
                          TextSpan(text: 'Fit', style: TextStyle(color: AppColors.gold)),
                        ],
                      ),
                    ),
                    Text('Admin Portal',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.75))),
                  ],
                )
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.18)),
          const SizedBox(height: 16),

          // ---------------- Navigation ----------------
          Padding(
            padding: const EdgeInsets.fromLTRB(23, 0, 22, 10),
            child: Text(
              'MY PORTAL',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: Colors.white.withValues(alpha: 0.7),
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

          Divider(height: 1, color: Colors.white.withValues(alpha: 0.18)),

          // ---------------- User profile ----------------
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _initialsOf(CurrentUser.fullName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (CurrentUser.adminLevel != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  CurrentUser.isOwner ? 'Owner' : 'Staff',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: CurrentUser.isOwner ? AppColors.gold : Colors.white,
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
                              color: Colors.white.withValues(alpha: 0.75)),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),

          // ---------------- Sign Out ----------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _SignOutButton(onTap: onLogout),
          ),
        ],
      ),
    );
  }
}

/// A single sidebar nav row with default / active visual states.
///
/// Active: a solid white rounded pill with dark text/icon and a trailing
/// chevron, standing out against the cyan rail. Inactive: plain icon + label
/// directly on the cyan background in a lighter, muted tone, with a subtle
/// hover overlay so the row still reads as interactive.
class _SidebarNavItem extends StatefulWidget {
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
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;

    final Color rowBg = active
        ? Colors.white
        : (_hovered ? Colors.white.withValues(alpha: 0.12) : Colors.transparent);
    final Color textColor = active
        ? AppColors.inventoryHeader
        : Colors.white.withValues(alpha: 0.82);
    final Color iconColor = active
        ? AppColors.cyan
        : Colors.white.withValues(alpha: 0.75);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: rowBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 14,
                      spreadRadius: -4,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(widget.icon, size: 19, color: iconColor),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 14,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    if (active)
                      Icon(Icons.chevron_right_rounded,
                          size: 20, color: AppTheme.textMuted(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sign Out row — lightens on hover like the nav rows, and its label/icon
/// turn a soft red on hover since it's a destructive action.
class _SignOutButton extends StatefulWidget {
  final VoidCallback onTap;
  const _SignOutButton({required this.onTap});

  @override
  State<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<_SignOutButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color fg =
        _hovered ? _SidebarColors.danger : Colors.white.withValues(alpha: 0.85);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: _SidebarColors.hoverOverlay,
          highlightColor: _SidebarColors.pressOverlay,
          splashColor: _SidebarColors.pressOverlay,
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.logout, size: 18, color: fg),
                const SizedBox(width: 13),
                Text('Sign Out',
                    style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: -0.1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
