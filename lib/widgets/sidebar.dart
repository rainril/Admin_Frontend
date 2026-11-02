import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/current_user.dart';
import '../services/notification_center.dart';
import '../theme/app_theme.dart';

/// Sidebar-specific colors, matched to the staff login page: a near-black
/// rail, hairline borders, and muted greys. Brand colors (cyan/gold) still
/// come from the shared [AppColors].
class _SidebarColors {
  /// Rail background (same near-black as the login screen).
  static const Color background = Color(0xFF0A0A0A);

  /// Hairline border / divider on the rail.
  static const Color border = Color(0xFF1F1F23);

  /// Surface + border used by the profile card and Sign Out outline.
  static const Color cardSurface = Color(0xFF121214);
  static const Color cardBorder = Color(0xFF26262B);
  static const Color outline = Color(0xFF2E2E34);

  /// Row hover wash.
  static const Color hoverOverlay = Color(0x14FFFFFF);

  /// Text colors on the dark rail.
  static const Color mutedText = Color(0xFF8A8A93);
  static const Color subtleText = Color(0xFFA1A1AA);
  static const Color inactiveText = Color(0xFFB4B4BC);

  /// Text/icon color placed on top of the gold active pill.
  static const Color onGold = Color(0xFF0A0A0A);

  /// Soft red for the Sign Out hover state, readable on a dark background.
  static const Color danger = Color(0xFFFCA5A5);
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

  // Same items, same order, same indexes as before.
  static const items = [
    _NavItemData(Icons.grid_view_rounded, 'Dashboard'),
    _NavItemData(Icons.notifications_none_rounded, 'Notifications'),
    _NavItemData(Icons.qr_code_scanner_rounded, 'Attendance'),
    _NavItemData(Icons.center_focus_strong_rounded, 'Check-In'),
    _NavItemData(Icons.credit_card_outlined, 'Billing'),
    _NavItemData(Icons.receipt_long_outlined, 'Pending Payments'),
    _NavItemData(Icons.inventory_2_outlined, 'Inventory'),
    _NavItemData(Icons.settings_outlined, 'Settings'),
  ];

  /// Visual grouping only: a small label is drawn above the item at each
  /// index below. This does not change item indexes or what onSelect receives.
  static const Map<int, String> _groupLabels = {
    2: 'MEMBERS',
    4: 'FINANCE',
    6: 'MANAGEMENT',
  };

  /// Index of the Notifications item (shows the "new" count badge).
  static const int notificationsIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: _SidebarColors.background,
        border: Border(
          right: BorderSide(color: _SidebarColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------- Branding ----------------
          // Gold-ringed logo + cyan/gold wordmark, like the login page.
          // Tapping still takes the user back to the Dashboard (index 0).
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onSelect(0),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: const DecorationImage(
                                image: AssetImage('assets/primefit_logo.jpg'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    style: GoogleFonts.archivoBlack(
                                        fontSize: 21, letterSpacing: -0.3),
                                    children: const [
                                      TextSpan(
                                          text: 'Prime',
                                          style:
                                              TextStyle(color: AppColors.cyan)),
                                      TextSpan(
                                          text: 'Fit',
                                          style:
                                              TextStyle(color: AppColors.gold)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Owner & Staff Portal'.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.6,
                                    color: _SidebarColors.inactiveText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: _SidebarColors.border),
              ],
            ),
          ),

          // ---------------- Navigation ----------------
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = index == currentIndex;
                final groupLabel = _groupLabels[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (groupLabel != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
                        child: Text(
                          groupLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                            color: _SidebarColors.mutedText,
                          ),
                        ),
                      ),
                    if (index == notificationsIndex)
                      ListenableBuilder(
                        listenable: NotificationCenter.instance,
                        builder: (context, _) => _SidebarNavItem(
                          icon: item.icon,
                          label: item.label,
                          selected: selected,
                          badgeCount: NotificationCenter.instance.unreadCount,
                          onTap: () => onSelect(index),
                        ),
                      )
                    else
                      _SidebarNavItem(
                        icon: item.icon,
                        label: item.label,
                        selected: selected,
                        onTap: () => onSelect(index),
                      ),
                  ],
                );
              },
            ),
          ),

          // ---------------- User profile ----------------
          // Bordered dark card, like the "Restricted access" box on login.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _SidebarColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _SidebarColors.cardBorder, width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1A1A1D),
                      border: Border.all(
                        color: AppColors.cyan,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      _initialsOf(CurrentUser.fullName),
                      style: const TextStyle(
                        color: AppColors.cyan,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (CurrentUser.adminLevel != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: CurrentUser.isOwner
                                      ? AppColors.gold.withValues(alpha: 0.16)
                                      : Colors.white.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: CurrentUser.isOwner
                                        ? AppColors.gold.withValues(alpha: 0.45)
                                        : Colors.white.withValues(alpha: 0.18),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  CurrentUser.isOwner ? 'Owner' : 'Staff',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: CurrentUser.isOwner
                                        ? AppColors.gold
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          CurrentUser.email ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _SidebarColors.subtleText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---------------- Sign Out ----------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: _SignOutButton(onTap: onLogout),
          ),
        ],
      ),
    );
  }
}

/// A single sidebar nav row with default / hover / active visual states.
///
/// Active: a solid gold pill with black bold label and icon (same look as the
/// gold Sign In button on the login page). Inactive: muted grey label and icon
/// directly on the rail, with a subtle white wash and gold icon on hover.
class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Small red count pill at the right of the row (0 = hidden).
  final int badgeCount;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
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
        ? AppColors.gold
        : (_hovered ? _SidebarColors.hoverOverlay : Colors.transparent);
    final Color textColor = active
        ? _SidebarColors.onGold
        : (_hovered ? Colors.white : _SidebarColors.inactiveText);
    final Color iconColor = active
        ? _SidebarColors.onGold
        : (_hovered ? AppColors.gold : _SidebarColors.inactiveText);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: rowBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Icon(widget.icon, size: 20, color: iconColor),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 14.5,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    if (widget.badgeCount > 0)
                      Container(
                        constraints:
                            const BoxConstraints(minWidth: 20, minHeight: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          widget.badgeCount > 9 ? '9+' : '${widget.badgeCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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

/// Sign Out: an outlined pill that stays quiet by default; on hover its
/// border, label and icon turn a soft red since it's a destructive action.
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
    final Color fg = _hovered ? _SidebarColors.danger : const Color(0xFFE4E4E7);
    final Color borderColor = _hovered
        ? _SidebarColors.danger.withValues(alpha: 0.45)
        : _SidebarColors.outline;
    final Color bg = _hovered
        ? _SidebarColors.danger.withValues(alpha: 0.08)
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, size: 18, color: fg),
                  const SizedBox(width: 10),
                  Text(
                    'Sign Out',
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: -0.1,
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
