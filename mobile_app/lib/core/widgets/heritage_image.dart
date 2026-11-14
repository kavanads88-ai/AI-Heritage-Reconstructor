import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Clearly identified placeholder shown instead of a broken-image icon.
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({
    super.key,
    required this.label,
    this.icon = Icons.account_balance_outlined,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Placeholder: $label',
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppColors.sandstone, AppColors.sandstoneLight],
          ),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: compact ? 26 : 44, color: AppColors.charcoal),
            if (!compact) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                'Placeholder image',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows a backend image if available, otherwise a bundled asset, otherwise a labelled placeholder.
class HeritageImage extends StatelessWidget {
  const HeritageImage({
    super.key,
    this.networkUrl,
    this.assetPath,
    required this.placeholderLabel,
    this.fit = BoxFit.cover,
    this.compact = false,
    this.icon = Icons.account_balance_outlined,
  });

  final String? networkUrl;
  final String? assetPath;
  final String placeholderLabel;
  final BoxFit fit;
  final bool compact;
  final IconData icon;

  Widget _placeholder() => ImagePlaceholder(label: placeholderLabel, compact: compact, icon: icon);

  Widget _asset() {
    final String? path = assetPath;
    if (path == null) return _placeholder();
    return Image.asset(
      path,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (BuildContext c, Object e, StackTrace? s) => _placeholder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? url = networkUrl;
    if (url == null) return _asset();
    return Image.network(
      url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (BuildContext c, Widget child, ImageChunkEvent? progress) {
        if (progress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (BuildContext c, Object e, StackTrace? s) => _asset(),
    );
  }
}
