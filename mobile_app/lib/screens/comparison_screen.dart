import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/services/api_service.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/comparison_slider.dart';
import '../core/widgets/disclaimer_banner.dart';
import '../core/widgets/error_banner.dart';
import '../core/widgets/heritage_image.dart';
import '../core/widgets/loading_widgets.dart';
import '../core/widgets/monument_loader.dart';
import '../core/widgets/section_header.dart';
import '../core/widgets/status_chip.dart';
import '../models/api_models.dart';
import '../models/monument.dart';
import '../providers/settings_provider.dart';

/// Screen 7: Present Appearance vs Proposed Reconstruction with a draggable slider.
class ComparisonScreen extends StatelessWidget {
  const ComparisonScreen({super.key, required this.monumentId});

  final String monumentId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reconstruction')),
      body: SafeArea(
        child: MonumentLoader(
          monumentId: monumentId,
          builder: (BuildContext context, Monument m) => _ComparisonBody(monument: m),
        ),
      ),
    );
  }
}

class _ComparisonBody extends StatefulWidget {
  const _ComparisonBody({required this.monument});

  final Monument monument;

  @override
  State<_ComparisonBody> createState() => _ComparisonBodyState();
}

class _ComparisonBodyState extends State<_ComparisonBody> {
  late Future<ComparisonInfo> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<ComparisonInfo> _fetch() => context.read<AppSettings>().api.comparison(widget.monument.id);

  void _retry() => setState(() => _future = _fetch());

  @override
  Widget build(BuildContext context) {
    final Monument m = widget.monument;
    final TextTheme text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: <Widget>[
        Text(m.name, style: text.headlineMedium),
        const SizedBox(height: 12),
        const DisclaimerBanner(text: Disclaimers.reconstruction),
        const SizedBox(height: 16),
        FutureBuilder<ComparisonInfo>(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<ComparisonInfo> snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 220, child: LoadingIndicator(message: 'Loading comparison…'));
            }
            if (snap.hasError) {
              final Object? e = snap.error;
              final String msg = e is ApiException ? e.message : 'The comparison could not be loaded.';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ErrorBanner(
                    title: 'Comparison unavailable',
                    message: '$msg\nReconstruction images are served by the backend, so they cannot be shown right now.',
                    onRetry: _retry,
                  ),
                  if (m.reconstructionExplanation.isNotEmpty) ...<Widget>[
                    const SectionHeader('About this reconstruction'),
                    Text(m.reconstructionExplanation, style: text.bodyLarge),
                  ],
                ],
              );
            }
            return _Loaded(monument: m, info: snap.data!);
          },
        ),
      ],
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.monument, required this.info});

  final Monument monument;
  final ComparisonInfo info;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool hasRecon = info.reconstructionUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ComparisonSlider(
          before: HeritageImage(
            networkUrl: info.presentUrl,
            assetPath: AppConfig.bundledImageAsset(monument.id, 'present'),
            placeholderLabel: 'Present photograph not added yet',
          ),
          after: HeritageImage(
            networkUrl: info.reconstructionUrl,
            placeholderLabel: 'Reconstruction not available yet',
            icon: Icons.construction,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Drag the handle left or right to compare.',
          style: text.bodySmall?.copyWith(color: AppColors.mutedText),
        ),
        if (!hasRecon) ...<Widget>[
          const SizedBox(height: 14),
          const StatusChip(
            label: 'No reconstruction image installed',
            color: AppColors.terracotta,
            icon: Icons.info_outline,
          ),
        ],
        const SectionHeader('About this reconstruction'),
        Text(
          info.explanation.isEmpty ? 'No explanation available yet.' : info.explanation,
          style: text.bodyLarge,
        ),
        if (monument.documentedElements.isNotEmpty || monument.hypotheticalElements.isNotEmpty) ...<Widget>[
          const SectionHeader('Documented vs hypothetical'),
          for (final ElementNote e in monument.documentedElements)
            _Row(note: e, documented: true),
          for (final ElementNote e in monument.hypotheticalElements)
            _Row(note: e, documented: false),
        ],
        const SizedBox(height: 16),
        DisclaimerBanner(text: info.disclaimer),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.note, required this.documented});

  final ElementNote note;
  final bool documented;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            StatusChip(
              label: documented ? 'Documented' : 'Hypothetical',
              color: documented ? AppColors.sageDark : AppColors.terracotta,
            ),
            const SizedBox(height: 6),
            Text(note.element, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (note.status.isNotEmpty) Text(note.status),
          ],
        ),
      ),
    );
  }
}
