import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/disclaimer_banner.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/model_viewer_view.dart';
import '../models/monument.dart';

/// Screen 9: Augmented reality through model-viewer's Android Scene Viewer mode.
///
/// Scene Viewer is launched by Google's app, not by this app, so it must be able to download
/// the GLB itself. That is why AR uses a URL (a public https [Monument.arModelUrl], or the
/// backend's /models/{id} URL) and never the bundled copy. This has NOT been tested on a real
/// ARCore device by the project generator - see README "Features still requiring real-device testing".
class ArScreen extends StatelessWidget {
  const ArScreen({super.key, required this.monument, this.viewerBuilder});

  final Monument monument;
  final ModelViewerBuilder? viewerBuilder;

  /// URL that Scene Viewer can fetch, or null when none is available.
  String? get arUrl => monument.arModelUrl ?? monument.assets.modelUrl;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String? url = arUrl;
    final ModelViewerBuilder build = viewerBuilder ?? defaultModelViewerBuilder;

    return Scaffold(
      appBar: AppBar(title: const Text('View in AR')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(monument.name, style: text.headlineSmall),
              const SizedBox(height: 8),
              const DisclaimerBanner(text: Disclaimers.arRequirements, icon: Icons.phone_android),
              const SizedBox(height: 10),
              Expanded(
                child: url == null
                    ? ListView(
                        children: const <Widget>[
                          EmptyState(
                            icon: Icons.view_in_ar_outlined,
                            title: 'AR is not available for this model',
                            message:
                                'AR needs the model to be reachable by URL. Either the model file has not been '
                                'added to the backend, or the backend is offline. Add the .glb to '
                                'backend/static/models/ (or set "ar_model_url" in monuments.json) and try again.',
                          ),
                        ],
                      )
                    : build(context, ViewerConfig(src: url, alt: 'AR model of ${monument.name}', ar: true)),
              ),
              const SizedBox(height: 10),
              if (url != null)
                Text(
                  'Tap the AR button shown in the viewer. Slowly move your phone to find a flat surface, '
                  'then tap to place the model. Drag to move it, twist with two fingers to rotate, pinch '
                  'to scale. If no AR button appears, this phone or its software does not support it.',
                  style: text.bodySmall?.copyWith(color: AppColors.mutedText),
                ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Back to normal 3D viewer',
                icon: Icons.threed_rotation,
                style: AppButtonStyle.secondary,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
