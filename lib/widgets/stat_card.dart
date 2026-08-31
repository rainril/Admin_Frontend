import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final IconData? icon;
  final String? iconText;
  final Color iconBg;
  final Color iconColor;
  final String change;
  final String value;
  final String label;

  const StatCard({
    super.key,
    this.icon,
    this.iconText,
    required this.iconBg,
    required this.iconColor,
    required this.change,
    required this.value,
    required this.label,
  }) : assert(icon != null || iconText != null);

  @override
  Widget build(BuildContext context) {
    // Growth metrics get the familiar green "+X%" pill; a card whose accent is
    // the warm danger red (e.g. Churn Risk) gets a matching amber pill so the
    // badge doesn't read as "good news".
    final bool warmMetric =
        iconColor == AppColors.danger || iconColor == const Color(0xFFDC2626);
    final Color pillBg = warmMetric ? AppColors.warningBg : AppColors.successBg;
    final Color pillFg = warmMetric ? AppColors.warning : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: AppTheme.cardDecoration(context, accent: iconColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: iconText != null
                    ? Text(iconText!,
                        style: TextStyle(
                            color: iconColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1))
                    : Icon(icon, color: iconColor, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(change,
                    style: TextStyle(
                        color: pillFg,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(value, style: AppTheme.statValue(context)),
          const SizedBox(height: 4),
          Text(label, style: AppTheme.statLabel(context)),
        ],
      ),
    );
  }
}
