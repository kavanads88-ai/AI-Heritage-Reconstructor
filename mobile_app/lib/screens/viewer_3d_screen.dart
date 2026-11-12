import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/navigation.dart';
import '../core/services/api_service.dart';
import '../core/services/model_source.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/disclaimer_banner.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/error_banner.dart';
import '../core/widgets/loading_widgets.dart';
import '../core/widgets/model_viewer_view.dart';
import '../core/widgets/monument_loader.dart';
import '../core/widgets/status_chip.dart';
import '../models/monument.dart';
import '../providers/settings_provider.dart';
import 'ar_screen.dart';

/// Screen 8: interactive 3D viewer (rotate / zoom with touch) for the curated GLB model.
class Viewer3dScreen extends StatelessWidget {
  const Viewer3dScreen({super.key, required this.monumentId, this.viewerBuilder});

  final String monumentId;

  /// Tests inject a fake; production uses model_viewer_plus.
  final ModelViewerBuilder? viewerBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3D Explorer')),
      body: SafeArea(
        child: MonumentLoader(
          monumentId: monumentId,
          builder: (BuildContext context, Monument m) =>
              _ViewerBody(monument: m, viewerBuilder: viewerBuilder ?? defaultModelViewerBuilder),
        ),
      ),
    );
  }
}

class _ViewerBody extends StatefulWidget {
  const _ViewerBody({required this.monument, required this.viewerBuilder});

  final Monument monument;
  final ModelViewerBuilder viewerBuilder;

  @override
  State<_ViewerBody> createState() => _ViewerBodyState();
}

class _ViewerBodyState extends State<_ViewerBody> {
  late Future<ResolvedModel> _future;
  int _resetToken = 0;
  bool _autoRotate = false;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  Future<ResolvedModel> _resolve() {
    return context.read<ModelSourceResolver>().resolve(widget.monument, context.read<AppSettings>().api);
  }

  void _reload() => setState(() {
        _future = _resolve();
        _resetToken++;
      });

  void _resetView() => setState(() => _resetToken++);

  @override
  Widget build(BuildContext context) {
    final Monument m = widget.monument;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(m.name, style: text.headlineSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (!m.isPrimary)
                const StatusChip(
                  label: 'Model available only if its GLB file has been added',
                  color: AppColors.charcoal,
                  icon: Icons.info_outline,
                ),
              if (m.offlineCopy) const OfflineChip(),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FutureBuilder<ResolvedModel>(
              future: _future,
              builder: (BuildContext context, AsyncSnapshot<ResolvedModel> snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const LoadingIndicator(message: 'Preparing the 3D model…');
                }
                if (snap.hasError) return _problem(snap.error, m);
                final ResolvedModel model = snap.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: widget.viewerBuilder(
                        context,
                        ViewerConfig(
                          src: model.src,
                          alt: '3D model of ${m.name}',
                          autoRotate: _autoRotate,
                          resetToken: _resetToken,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Drag to rotate, pinch to zoom. If nothing appears, tap Reload.',
                            style: text.bodySmall?.copyWith(color: AppColors.mutedText),
                          ),
                        ),
                        FilterChip(
                          label: const Text('Auto-rotate'),
                          selected: _autoRotate,
                          onSelected: (bool v) => setState(() => _autoRotate = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: AppButton(
                            label: 'Reset view',
                            icon: Icons.center_focus_strong,
                            style: AppButtonStyle.secondary,
                            onPressed: _resetView,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppButton(
                            label: 'Reload',
                            icon: Icons.refresh,
                            style: AppButtonStyle.secondary,
                            onPressed: _reload,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AppButton(
                      label: 'View in AR',
                      icon: Icons.view_in_ar,
                      onPressed: () => Nav.push<void>(context, ArScreen(monument: m, viewerBuilder: widget.viewerBuilder)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      Disclaimers.curatedModels,
                      style: text.bodySmall?.copyWith(color: AppColors.mutedText),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _problem(Object? error, Monument m) {
    final bool missing = error is ApiException && error.kind == ApiErrorKind.notFound;
    if (missing) {
      return ListView(
        children: <Widget>[
          EmptyState(
            icon: Icons.view_in_ar_outlined,
            title: 'No 3D model for ${m.name} yet',
            message: '${(error as ApiException).message}\n\nThe 3D model is a curated asset prepared by the '
                'project team (for example in Blender and exported as .glb). It is not generated '
                'automatically.',
            action: AppButton(label: 'Check again', icon: Icons.refresh, expand: false, onPressed: _reload),
          ),
          const DisclaimerBanner(text: Disclaimers.curatedModels),
        ],
      );
    }
    final String msg = error is ApiException ? error.message : 'The 3D model could not be prepared ($error).';
    return ListView(
      children: <Widget>[
        ErrorBanner(title: '3D model unavailable', message: msg, onRetry: _reload),
        const SizedBox(height: 12),
        const DisclaimerBanner(text: Disclaimers.curatedModels),
      ],
    );
  }
}
