import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/navigation.dart';
import '../core/services/api_service.dart';
import '../core/services/photo_picker.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/disclaimer_banner.dart';
import '../core/widgets/error_banner.dart';
import '../models/api_models.dart';
import '../providers/settings_provider.dart';
import 'result_screen.dart';

/// Screen 3: pick a photo (camera/gallery), preview it, send it to /identify.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  PickedPhoto? _photo;
  IdentifyResult? _result;
  String? _pickError;
  String? _apiError;
  bool _busy = false;

  Future<void> _pick(PhotoSource source) async {
    if (_busy) return;
    final PhotoPicker picker = context.read<PhotoPicker>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final PickedPhoto? photo = await picker.pick(source);
      if (!mounted) return;
      if (photo == null) {
        // The user backed out of the camera/gallery: keep the current state.
        messenger.showSnackBar(const SnackBar(content: Text('No photo selected.')));
        return;
      }
      setState(() {
        _photo = photo;
        _result = null;
        _apiError = null;
        _pickError = null;
      });
    } on PhotoPickException catch (e) {
      if (!mounted) return;
      setState(() => _pickError = e.message);
    }
  }

  Future<void> _identify() async {
    final PickedPhoto? photo = _photo;
    if (photo == null || _busy) return; // blocks duplicate taps
    final AppSettings settings = context.read<AppSettings>();
    setState(() {
      _busy = true;
      _apiError = null;
      _result = null;
    });
    try {
      final IdentifyResult result = await settings.api.identify(photo.bytes, filename: photo.name);
      if (!mounted) return;
      setState(() => _result = result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _apiError = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final double threshold = context.watch<AppSettings>().threshold;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a monument')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: <Widget>[
            Text(
              'Take a photograph or choose one from your gallery, then tap Identify Monument.',
              style: text.bodyLarge?.copyWith(color: AppColors.mutedText),
            ),
            const SizedBox(height: 16),
            _Preview(photo: _photo),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppButton(
                    label: 'Camera',
                    icon: Icons.photo_camera_outlined,
                    style: AppButtonStyle.tonal,
                    onPressed: _busy ? null : () => _pick(PhotoSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Gallery',
                    icon: Icons.photo_library_outlined,
                    style: AppButtonStyle.tonal,
                    onPressed: _busy ? null : () => _pick(PhotoSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppButton(
              label: _busy ? 'Identifying…' : 'Identify Monument',
              icon: Icons.search,
              loading: _busy,
              onPressed: _photo == null ? null : _identify,
            ),
            if (_pickError != null) ...<Widget>[
              const SizedBox(height: 16),
              ErrorBanner(title: 'Photo not available', message: _pickError!),
            ],
            if (_apiError != null) ...<Widget>[
              const SizedBox(height: 16),
              ErrorBanner(title: 'Could not identify the monument', message: _apiError!, onRetry: _identify),
            ],
            if (_result != null) ...<Widget>[
              const SizedBox(height: 16),
              IdentifyResultCard(result: _result!, threshold: threshold),
              if (!_result!.isUnknownAt(threshold)) ...<Widget>[
                const SizedBox(height: 12),
                AppButton(
                  label: 'View full result',
                  icon: Icons.arrow_forward,
                  onPressed: () => Nav.push<void>(
                    context,
                    ResultScreen(photo: _photo?.bytes, result: _result!),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.photo});

  final PickedPhoto? photo;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: photo == null
            ? Container(
                color: AppColors.sandstoneLight,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.add_a_photo_outlined, size: 44, color: AppColors.charcoal),
                    const SizedBox(height: 8),
                    Text('No photo selected yet', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              )
            : Image.memory(photo!.bytes, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    );
  }
}

/// Shows the identification outcome: name, confidence and the top predictions.
class IdentifyResultCard extends StatelessWidget {
  const IdentifyResultCard({super.key, required this.result, required this.threshold});

  final IdentifyResult result;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool unknown = result.isUnknownAt(threshold);
    final double? confidence = result.confidence;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (result.isMock) ...<Widget>[
          DisclaimerBanner(
            icon: Icons.science_outlined,
            text: result.message ??
                'MOCK DATA: no trained model is installed on the server. This is not an AI prediction.',
          ),
          const SizedBox(height: 12),
        ],
        AppCard(
          borderColor: unknown ? AppColors.terracotta : AppColors.sage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    unknown ? Icons.help_outline : Icons.check_circle_outline,
                    color: unknown ? AppColors.terracotta : AppColors.sageDark,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      unknown ? 'Unknown Monument' : result.name,
                      style: text.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (unknown)
                Text(
                  'The app is not confident enough to name this monument. Try a closer photo, '
                  'better light or a different angle. Supported: Stone Chariot, Vittala Temple, Lotus Mahal.',
                  style: text.bodyMedium,
                )
              else if (confidence != null) ...<Widget>[
                Text('Confidence: ${percent(confidence)}', style: text.titleMedium),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: confidence.clamp(0.0, 1.0).toDouble(),
                    minHeight: 10,
                    backgroundColor: AppColors.sandstoneLight,
                    color: AppColors.sage,
                  ),
                ),
              ] else
                Text('Confidence is not available for mock data.', style: text.bodyMedium),
              if (result.top3.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text('Top predictions', style: text.titleMedium),
                const SizedBox(height: 6),
                for (final Prediction p in result.top3)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: <Widget>[
                        Expanded(child: Text(prettyId(p.id))),
                        Text(percent(p.confidence), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
