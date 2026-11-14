import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/services/speech_service.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/disclaimer_banner.dart';
import '../core/widgets/error_banner.dart';
import '../core/widgets/monument_loader.dart';
import '../core/widgets/section_header.dart';
import '../core/widgets/status_chip.dart';
import '../models/monument.dart';

/// Builds the text read aloud. Pending-verification facts are NOT read as facts.
String buildNarration(Monument m) {
  final StringBuffer b = StringBuffer()
    ..write('${m.name}. ')
    ..write(m.location.isEmpty ? '' : 'Location: ${m.location}. ')
    ..write(m.period.isEmpty ? '' : 'Period: ${m.period} ')
    ..write(m.summary.isEmpty ? '' : '${m.summary} ')
    ..write(m.architecturalSignificance.isEmpty ? '' : 'Architectural significance: ${m.architecturalSignificance} ');
  final List<Fact> usable = m.facts.where((Fact f) => f.status != VerificationStatus.pending).toList();
  if (usable.isNotEmpty) {
    b.write('Facts. ');
    for (final Fact f in usable) {
      b.write('${f.text} ');
    }
  }
  if (m.facts.any((Fact f) => f.status == VerificationStatus.pending)) {
    b.write('Some details are still pending verification.');
  }
  return b.toString().trim();
}

/// Screen 5: history with sources and Listen / Pause / Stop controls.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.monumentId});

  final String monumentId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: SafeArea(
        child: MonumentLoader(
          monumentId: monumentId,
          builder: (BuildContext context, Monument m) => _HistoryBody(monument: m),
        ),
      ),
    );
  }
}

class _HistoryBody extends StatefulWidget {
  const _HistoryBody({required this.monument});

  final Monument monument;

  @override
  State<_HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<_HistoryBody> {
  late final SpeechService _speech;

  @override
  void initState() {
    super.initState();
    _speech = context.read<SpeechService>();
  }

  @override
  void dispose() {
    // Never keep talking after the user leaves the screen. Deferred to a microtask because
    // stop() notifies listeners and the widget tree is locked while a route is being disposed.
    final SpeechService speech = _speech;
    scheduleMicrotask(speech.stop);
    super.dispose();
  }

  String _sourceTitle(String id) {
    for (final Source s in widget.monument.sources) {
      if (s.id == id) return s.title;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final Monument m = widget.monument;
    final TextTheme text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: <Widget>[
        if (m.offlineCopy) ...<Widget>[const OfflineChip(), const SizedBox(height: 10)],
        Text(m.name, style: text.headlineMedium),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            const Icon(Icons.place_outlined, size: 18, color: AppColors.terracotta),
            const SizedBox(width: 6),
            Expanded(child: Text(m.location.isEmpty ? 'Location not available' : m.location)),
          ],
        ),
        const SizedBox(height: 14),
        _SpeechControls(narration: buildNarration(m)),
        const SectionHeader('Historical period'),
        Text(m.period.isEmpty ? 'Pending verification.' : m.period, style: text.bodyLarge),
        const SectionHeader('Summary'),
        Text(m.summary.isEmpty ? 'Pending verification.' : m.summary, style: text.bodyLarge),
        const SectionHeader('Architectural significance'),
        Text(
          m.architecturalSignificance.isEmpty ? 'Pending verification.' : m.architecturalSignificance,
          style: text.bodyLarge,
        ),
        const SectionHeader('Facts'),
        if (m.facts.isEmpty)
          const DisclaimerBanner(text: 'No facts have been added for this monument yet (pending verification).')
        else
          for (final Fact f in m.facts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(f.text, style: text.bodyLarge),
                    const SizedBox(height: 10),
                    VerificationBadge(f.status),
                    if (f.sourceIds.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'Source: ${f.sourceIds.map(_sourceTitle).join('; ')}',
                        style: text.bodySmall?.copyWith(color: AppColors.mutedText),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        const SectionHeader('Sources'),
        if (m.sources.isEmpty)
          const DisclaimerBanner(text: 'No sources are listed for this monument yet.')
        else
          for (final Source s in m.sources)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.link, color: AppColors.terracotta),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(s.title, style: text.titleMedium),
                          const SizedBox(height: 4),
                          SelectableText(s.url, style: text.bodySmall?.copyWith(color: AppColors.mutedText)),
                          if (s.type.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 6),
                            StatusChip(
                              label: s.type == 'primary' ? 'Primary source' : 'Secondary source',
                              color: s.type == 'primary' ? AppColors.sageDark : AppColors.charcoal,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy link',
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
                        await Clipboard.setData(ClipboardData(text: s.url));
                        messenger.showSnackBar(const SnackBar(content: Text('Link copied')));
                      },
                    ),
                  ],
                ),
              ),
            ),
        if (m.documentedElements.isNotEmpty || m.hypotheticalElements.isNotEmpty) ...<Widget>[
          const SectionHeader('Documented vs hypothetical'),
          for (final ElementNote e in m.documentedElements) _ElementCard(note: e, documented: true),
          for (final ElementNote e in m.hypotheticalElements) _ElementCard(note: e, documented: false),
        ],
      ],
    );
  }
}

class _ElementCard extends StatelessWidget {
  const _ElementCard({required this.note, required this.documented});

  final ElementNote note;
  final bool documented;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        borderColor: documented ? AppColors.sage : AppColors.terracotta,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            StatusChip(
              label: documented ? 'Documented' : 'Hypothetical',
              color: documented ? AppColors.sageDark : AppColors.terracotta,
            ),
            const SizedBox(height: 8),
            Text(note.element, style: text.titleMedium),
            if (note.status.isNotEmpty) Text(note.status),
            if (note.source.isNotEmpty)
              Text('Source: ${note.source}', style: text.bodySmall?.copyWith(color: AppColors.mutedText)),
          ],
        ),
      ),
    );
  }
}

class _SpeechControls extends StatelessWidget {
  const _SpeechControls({required this.narration});

  final String narration;

  @override
  Widget build(BuildContext context) {
    return Consumer<SpeechService>(
      builder: (BuildContext context, SpeechService speech, Widget? _) {
        final SpeechStatus s = speech.status;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: AppButton(
                    label: s == SpeechStatus.paused ? 'Resume' : 'Listen',
                    icon: Icons.volume_up,
                    onPressed: s == SpeechStatus.speaking ? null : () => speech.speak(narration),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: 'Pause',
                    icon: Icons.pause,
                    style: AppButtonStyle.secondary,
                    onPressed: s == SpeechStatus.speaking ? speech.pause : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: 'Stop',
                    icon: Icons.stop,
                    style: AppButtonStyle.secondary,
                    onPressed: s == SpeechStatus.idle ? null : speech.stop,
                  ),
                ),
              ],
            ),
            if (speech.error != null) ...<Widget>[
              const SizedBox(height: 10),
              ErrorBanner(title: 'Speech unavailable', message: speech.error!),
            ],
          ],
        );
      },
    );
  }
}
