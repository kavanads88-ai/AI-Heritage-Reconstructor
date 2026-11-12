import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AppButtonStyle { primary, secondary, tonal }

/// Consistent button. While [loading] it is disabled (blocks duplicate taps) and shows a spinner.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.style = AppButtonStyle.primary,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final AppButtonStyle style;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;
    final Color spinnerColor = style == AppButtonStyle.primary ? Colors.white : AppColors.terracotta;

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: spinnerColor),
          )
        else if (icon != null)
          Icon(icon, size: 20),
        if (loading || icon != null) const SizedBox(width: 10),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );

    final VoidCallback? handler = enabled ? onPressed : null;
    Widget button;
    switch (style) {
      case AppButtonStyle.primary:
        button = FilledButton(onPressed: handler, child: content);
      case AppButtonStyle.secondary:
        button = OutlinedButton(onPressed: handler, child: content);
      case AppButtonStyle.tonal:
        button = FilledButton(
          onPressed: handler,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.sandstone,
            foregroundColor: AppColors.charcoal,
          ),
          child: content,
        );
    }
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
