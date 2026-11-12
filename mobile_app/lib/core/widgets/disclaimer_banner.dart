import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Prominent notice used for the mandatory reconstruction / damage disclaimers.
class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key, required this.text, this.icon = Icons.info_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sandstoneLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.terracotta, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppColors.terracotta, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
