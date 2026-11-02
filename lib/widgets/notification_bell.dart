import 'package:flutter/material.dart';
import '../services/notification_center.dart';
import '../theme/app_theme.dart';

/// Bell button for the top-right corner of every screen. It shows how many new
/// notifications there are and calls [onTap] when pressed (the app shell uses
/// that to open the Notifications screen).
///
/// Place it ONCE, in the app shell's top bar, not inside each screen.
class NotificationBell extends StatefulWidget {
  final VoidCallback onTap;
  const NotificationBell({super.key, required this.onTap});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _center = NotificationCenter.instance;

  @override
  void initState() {
    super.initState();
    // Keeps the badge fresh on every screen (one shared timer for the app).
    _center.startPolling();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _center,
      builder: (context, _) {
        final count = _center.unreadCount;
        return Tooltip(
          message: count > 0 ? '$count new notification${count == 1 ? '' : 's'}' : 'Notifications',
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: Theme.of(context).cardColor,
                shape: CircleBorder(side: BorderSide(color: Theme.of(context).dividerColor)),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onTap,
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      count > 0 ? Icons.notifications : Icons.notifications_none,
                      size: 21,
                      color: AppTheme.heading(context),
                    ),
                  ),
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: IgnorePointer(
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Theme.of(context).cardColor, width: 2),
                      ),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
