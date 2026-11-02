import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/notification_center.dart';
import '../services/dashboard_analytics_service.dart' show AppNotification;
import '../widgets/state_views.dart';

/// Notifications center: every recent notification in one place, with
/// filters and "mark as read". Opened from the sidebar or the top-right bell.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _center = NotificationCenter.instance;
  String _filter = 'All';

  static const _filters = ['All', 'New', 'Payments', 'Members'];

  @override
  void initState() {
    super.initState();
    _center.startPolling();
  }

  bool _isPayment(AppNotification n) => '${n.type}'.startsWith('payment');
  bool _isMember(AppNotification n) => '${n.type}' == 'registration';

  List<AppNotification> _filtered(List<AppNotification> all) {
    switch (_filter) {
      case 'New':
        return all.where((n) => !_center.isSeen(n)).toList();
      case 'Payments':
        return all.where(_isPayment).toList();
      case 'Members':
        return all.where(_isMember).toList();
      default:
        return all;
    }
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _center,
      builder: (context, _) {
        final all = _center.items;
        final shown = _filtered(all);
        final newCount = _center.unreadCount;
        final paymentCount = all.where(_isPayment).length;
        final memberCount = all.where(_isMember).length;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(newCount),
              const SizedBox(height: AppSpacing.section),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryCard(
                    label: 'New',
                    value: _center.loading && all.isEmpty ? '—' : '$newCount',
                    caption: 'Since you opened the app',
                    accent: newCount > 0 ? AppColors.cyan : null,
                  ),
                  const SizedBox(width: 16),
                  _summaryCard(
                    label: 'Payments',
                    value: _center.loading && all.isEmpty ? '—' : '$paymentCount',
                    caption: 'Payment activity',
                  ),
                  const SizedBox(width: 16),
                  _summaryCard(
                    label: 'New Members',
                    value: _center.loading && all.isEmpty ? '—' : '$memberCount',
                    caption: 'Recent sign-ups',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.section),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in _filters)
                    _pill(
                      label: f,
                      selected: _filter == f,
                      onTap: () => setState(() => _filter = f),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _listCard(all, shown),
              const SizedBox(height: AppSpacing.section),
            ],
          ),
        );
      },
    );
  }

  // ---------- Header ----------

  Widget _header(int newCount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppTheme.heading(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Recent activity across your gym: sign-ups and payments.',
                style: TextStyle(fontSize: 14, color: AppTheme.textMuted(context)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: newCount > 0 ? _center.markAllSeen : null,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all as read'),
              style: _outlinedPillStyle(),
            ),
            OutlinedButton.icon(
              onPressed: _center.loading ? null : () => _center.load(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
              style: _outlinedPillStyle(),
            ),
          ],
        ),
      ],
    );
  }

  ButtonStyle _outlinedPillStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppTheme.heading(context),
      side: BorderSide(color: AppTheme.heading(context).withValues(alpha: 0.35)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  // ---------- Summary cards ----------

  Widget _summaryCard({
    required String label,
    required String value,
    required String caption,
    Color? accent,
  }) {
    return Expanded(
      child: _panel(
        accent: accent,
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppTheme.heading(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- List ----------

  Widget _listCard(List<AppNotification> all, List<AppNotification> shown) {
    if (_center.loading && all.isEmpty) {
      return _panel(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: const LoadingState(),
      );
    }

    if (all.isEmpty) {
      return _panel(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: EmptyState(
          icon: _center.failed ? Icons.cloud_off_rounded : Icons.notifications_none,
          message: _center.failed
              ? 'Could not load notifications. Check that the backend is running, then refresh.'
              : 'No notifications yet.',
        ),
      );
    }

    if (shown.isEmpty) {
      return _panel(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: const EmptyState(
          icon: Icons.notifications_none,
          message: 'Nothing to show for this filter.',
        ),
      );
    }

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < shown.length; i++) _row(shown[i], first: i == 0),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Text(
              'Showing ${shown.length} of ${all.length} notifications',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(AppNotification n, {required bool first}) {
    final isNew = !_center.isSeen(n);
    final style = _styleFor(n);

    return InkWell(
      onTap: () => _center.markSeen(n),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          color: isNew ? AppColors.cyan.withValues(alpha: _isDark ? 0.10 : 0.05) : null,
          border: first ? null : Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unread dot (keeps the alignment even when read).
            Padding(
              padding: const EdgeInsets.only(top: 15, right: 12),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isNew ? AppColors.cyan : Colors.transparent,
                ),
              ),
            ),
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(style.icon, size: 19, color: style.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: isNew ? FontWeight.w800 : FontWeight.w600,
                      color: AppTheme.heading(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.subtitle,
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted(context)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  n.timeAgo,
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context)),
                ),
                if (isNew) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'New',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cyanDark,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Same icons/colors the Dashboard used for each notification type.
  ({IconData icon, Color color}) _styleFor(AppNotification n) {
    switch ('${n.type}') {
      case 'registration':
        return (icon: Icons.person_add_alt, color: AppColors.blueIcon);
      case 'payment_paid':
        return (icon: Icons.check_circle_outline, color: AppColors.greenIcon);
      case 'payment_failed':
        return (icon: Icons.error_outline, color: AppColors.danger);
      case 'payment_pending':
        return (icon: Icons.hourglass_empty, color: AppColors.warning);
      default:
        return (icon: Icons.notifications_none, color: AppTheme.textMuted(context));
    }
  }

  // ---------- Shared presentation helpers ----------

  /// Pill chip: dark when selected (cyan in dark mode), white with a hairline
  /// border otherwise.
  Widget _pill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final selectedBg = _isDark ? AppColors.cyan : const Color(0xFF111827);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? selectedBg : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? selectedBg : Theme.of(context).dividerColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.heading(context),
          ),
        ),
      ),
    );
  }

  /// White rounded card with hairline border + soft shadow. [accent] draws a
  /// thin colored bar on the left edge, reserved for cards needing attention.
  Widget _panel({
    required Widget child,
    Color? accent,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: _isDark
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Stack(
        children: [
          SizedBox(width: double.infinity, child: Padding(padding: padding, child: child)),
          if (accent != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: accent),
            ),
        ],
      ),
    );
  }
}
