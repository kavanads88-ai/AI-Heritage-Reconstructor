import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_button.dart';

/// Error message with an optional Retry button.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.message,
    this.title = 'Something went wrong',
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.error_outline, color: AppColors.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: 12),
            AppButton(
              label: retryLabel,
              icon: Icons.refresh,
              style: AppButtonStyle.secondary,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

/// Positive confirmation message.
class SuccessBanner extends StatelessWidget {
  const SuccessBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sageLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sageDark, width: 1),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.check_circle_outline, color: AppColors.sageDark),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
