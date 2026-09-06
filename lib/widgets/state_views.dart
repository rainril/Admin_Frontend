import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared "nothing to show yet" placeholder for cards/lists across the
/// portal (Dashboard charts, Billing/Attendance tables, Inventory grids),
/// replacing each screen's own ad-hoc `Center(child: Text(...))`.
class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final EdgeInsetsGeometry padding;

  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.padding = const EdgeInsets.symmetric(vertical: 24),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: AppTheme.textMuted(context)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted(context)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared inline loading placeholder for the same card/list contexts.
class LoadingState extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const LoadingState({
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 24),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
