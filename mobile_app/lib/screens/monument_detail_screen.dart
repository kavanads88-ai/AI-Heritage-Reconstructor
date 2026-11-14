import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/format.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/heritage_image.dart';
import '../core/widgets/monument_actions.dart';
import '../core/widgets/monument_loader.dart';
import '../core/widgets/section_header.dart';
import '../core/widgets/status_chip.dart';
import '../models/monument.dart';

/// Details page for one monument (opened from Home and Explore).
class MonumentDetailScreen extends StatelessWidget {
  const MonumentDetailScreen({super.key, required this.monumentId});

  final String monumentId;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(prettyId(monumentId))),
      body: SafeArea(
        child: MonumentLoader(
          monumentId: monumentId,
          builder: (BuildContext context, Monument m) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: <Widget>[
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: HeritageImage(
                      networkUrl: m.assets.presentImageUrl ?? m.assets.thumbnailUrl,
                      assetPath: AppConfig.bundledImageAsset(m.id, 'present'),
                      placeholderLabel: m.name,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(m.name, style: text.headlineMedium),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    const Icon(Icons.place_outlined, size: 18, color: AppColors.terracotta),
                    const SizedBox(width: 6),
                    Expanded(child: Text(m.location.isEmpty ? 'Location not available' : m.location)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (m.isPrimary)
                      const StatusChip(
                        label: 'Primary reconstruction target',
                        color: AppColors.sageDark,
                        icon: Icons.star_outline,
                      ),
                    if (m.offlineCopy) const OfflineChip(),
                  ],
                ),
                const SectionHeader('Overview'),
                Text(m.summary.isEmpty ? 'No summary available yet.' : m.summary, style: text.bodyLarge),
                if (m.period.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text('Period', style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(m.period),
                ],
                const SectionHeader('Explore'),
                MonumentActions(monumentId: m.id),
              ],
            );
          },
        ),
      ),
    );
  }
}
