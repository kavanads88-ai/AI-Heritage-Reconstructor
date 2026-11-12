import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/format.dart';
import '../core/services/api_service.dart';
import '../core/services/photo_picker.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/disclaimer_banner.dart';
import '../core/widgets/error_banner.dart';
import '../core/widgets/section_header.dart';
import '../models/api_models.dart';
import '../providers/settings_provider.dart';

/// Screen 6: OpenCV-based possible damage indicators (NOT a structural assessment).
class DamageScreen extends StatefulWidget {
  const DamageScreen({super.key, required this.monumentId, this.initialPhoto});

  final String monumentId;
  final Uint8List? initialPhoto;

  @override
  State<DamageScreen> createState() => _DamageScreenState();
}

class _DamageScreenState extends State<DamageScreen> {
  Uint8List? _photo;
  String _filename = 'photo.jpg';
  DamageResult? _result;
  String? _error;
  String? _pickError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _photo = widget.initialPhoto;
  }

  Future<void> _pick(PhotoSource source) async {
    if (_busy) return;
    final PhotoPicker picker = context.read<PhotoPicker>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final PickedPhoto? p = await picker.pick(source);
      if (!mounted) return;
      if (p == null) {
        messenger.showSnackBar(const SnackBar(content: Text('No photo selected.')));
        return;
      }
      setState(() {
        _photo = p.bytes;
        _filename = p.name;
        _result = null;
        _error = null;
        _pickError = null;
      });
    } on PhotoPickException catch (e) {
      if (!mounted) return;
      setState(() => _pickError = e.message);
    }
  }

  Future<void> _analyze() async {
    final Uint8List? photo = _photo;
    if (photo == null || _busy) return;
    final AppSettings settings = context.read<AppSettings>();
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final DamageResult r = await settings.api.analyzeDamage(photo, filename: _filename);
      if (!mounted) return;
      setState(() => _result = r);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final DamageResult? result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Damage analysis')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: <Widget>[
            Text(prettyId(widget.monumentId), style: text.headlineSmall),
            const SizedBox(height: 10),
            const DisclaimerBanner(text: Disclaimers.damage, icon: Icons.warning_amber_rounded),
            const SizedBox(height: 10),
            Text(Disclaimers.damageLimits, style: text.bodySmall?.copyWith(color: AppColors.mutedText)),
            const SectionHeader('Photograph'),
            _PhotoBox(bytes: _photo, label: 'No photograph chosen yet'),
            const SizedBox(height: 12),
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
              label: _busy ? 'Analysing…' : 'Analyze Damage',
              icon: Icons.troubleshoot,
              loading: _busy,
              onPressed: _photo == null ? null : _analyze,
            ),
            if (_pickError != null) ...<Widget>[
              const SizedBox(height: 14),
              ErrorBanner(title: 'Photo not available', message: _pickError!),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 14),
              ErrorBanner(
                title: 'Analysis unavailable',
                message: '$_error\nNo results are shown because none could be computed.',
                onRetry: _analyze,
              ),
            ],
            if (result != null) ...<Widget>[
              const SectionHeader('Results'),
              Text('Original', style: text.titleMedium),
              const SizedBox(height: 6),
              _PhotoBox(bytes: _photo, label: 'Original'),
              const SizedBox(height: 14),
              Text('Possible regions highlighted', style: text.titleMedium),
              const SizedBox(height: 6),
              _PhotoBox(bytes: result.annotatedImage, label: 'Processed image', zoomable: true),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Metric(label: 'Damage-indicator area', value: '${result.damageAreaPercent.toStringAsFixed(2)}% of image'),
                    const SizedBox(height: 8),
                    _Metric(label: 'Regions highlighted', value: '${result.regionsFound}'),
                    const SizedBox(height: 10),
                    Text(result.message, style: text.bodyMedium),
                    if (result.regions.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      Text('Largest regions', style: text.titleMedium),
                      const SizedBox(height: 4),
                      for (final DamageRegion r in result.regions.take(5))
                        Text('• ${r.width}×${r.height} px at (${r.x}, ${r.y}) - ${r.areaPercent.toStringAsFixed(2)}% of image'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              DisclaimerBanner(text: result.disclaimer, icon: Icons.warning_amber_rounded),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.terracotta)),
      ],
    );
  }
}

class _PhotoBox extends StatelessWidget {
  const _PhotoBox({required this.bytes, required this.label, this.zoomable = false});

  final Uint8List? bytes;
  final String label;
  final bool zoomable;

  @override
  Widget build(BuildContext context) {
    final Uint8List? data = bytes;
    Widget child;
    if (data == null) {
      child = Container(
        color: AppColors.sandstoneLight,
        alignment: Alignment.center,
        child: Text(label),
      );
    } else {
      final Widget img = Image.memory(data, fit: BoxFit.contain, gaplessPlayback: true);
      child = Container(
        color: AppColors.charcoal,
        child: zoomable ? InteractiveViewer(minScale: 1, maxScale: 5, child: img) : img,
      );
    }
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
    );
  }
}
