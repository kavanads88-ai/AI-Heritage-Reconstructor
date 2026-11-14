import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/monument_actions.dart';
import '../core/widgets/monument_loader.dart';
import '../core/widgets/section_header.dart';
import '../models/api_models.dart';
import '../models/monument.dart';
import '../providers/settings_provider.dart';
import 'scanner_screen.dart';

/// Screen 4: identification result with the photo, name, location, confidence and actions.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result, this.photo});

  final IdentifyResult result;
  final Uint8List? photo;

  @override
  Widget build(BuildContext context) {
    final double threshold = context.watch<AppSettings>().threshold;
    final bool unknown = result.isUnknownAt(threshold);
    final String? id = result.monumentId;
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Identification result')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: <Widget>[
            if (photo != null)
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.memory(photo!, fit: BoxFit.cover, gaplessPlayback: true),
                ),
              ),
            const SizedBox(height: 16),
            IdentifyResultCard(result: result, threshold: threshold),
            if (!unknown && id != null)
              MonumentLoader(
                monumentId: id,
                builder: (BuildContext context, Monument m) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 12),
                      if (m.offlineCopy) const OfflineChip(),
                      const SectionHeader('About this monument'),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Icon(Icons.place_outlined, color: AppColors.terracotta),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    m.location.isEmpty ? 'Location not available' : m.location,
                                    style: text.titleMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(m.summary.isEmpty ? 'No summary available yet.' : m.summary),
                            if (result.confidence != null) ...<Widget>[
                              const SizedBox(height: 10),
                              Text(
                                'Recognition confidence: ${percent(result.confidence!)}',
                                style: text.bodySmall?.copyWith(color: AppColors.mutedText),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SectionHeader('What would you like to do?'),
                      MonumentActions(monumentId: m.id, photo: photo),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
