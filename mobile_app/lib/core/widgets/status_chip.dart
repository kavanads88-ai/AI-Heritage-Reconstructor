import 'package:flutter/material.dart';

import '../../models/monument.dart';
import '../theme/app_colors.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[Icon(icon, size: 14, color: color), const SizedBox(width: 5)],
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge describing how well a historical fact has been verified.
class VerificationBadge extends StatelessWidget {
  const VerificationBadge(this.status, {super.key});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case VerificationStatus.verified:
        return const StatusChip(label: 'Verified', color: AppColors.sageDark, icon: Icons.verified_outlined);
      case VerificationStatus.secondarySourceChecked:
        return const StatusChip(
          label: 'Secondary source - confirm with ASI/UNESCO',
          color: AppColors.charcoal,
          icon: Icons.fact_check_outlined,
        );
      case VerificationStatus.pending:
        return const StatusChip(label: 'Pending verification', color: AppColors.terracotta, icon: Icons.hourglass_top);
    }
  }
}
