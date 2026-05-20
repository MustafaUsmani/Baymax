import 'package:flutter/material.dart';
import 'package:crisis_link/theme/app_colors.dart';

/// Reusable severity chip widget that displays color-coded severity level
class SeverityChip extends StatelessWidget {
  final String severity;

  const SeverityChip({super.key, required this.severity});

  Color get _color {
    switch (severity.toLowerCase()) {
      case 'low':
        return AppColors.successTeal;
      case 'medium':
        return AppColors.accentAmber;
      case 'high':
        return AppColors.emergencyRed;
      case 'critical':
        return const Color(0xFFB71C1C);
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        severity[0].toUpperCase() + severity.substring(1),
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
