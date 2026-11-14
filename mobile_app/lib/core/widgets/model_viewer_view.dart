import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../theme/app_colors.dart';

/// Everything the 3D / AR screens need to configure a viewer.
class ViewerConfig {
  const ViewerConfig({
    required this.src,
    required this.alt,
    this.ar = false,
    this.autoRotate = false,
    this.resetToken = 0,
  });

  /// Asset path, file:// URI or http(s) URL of a .glb file.
  final String src;
  final String alt;

  /// Show model-viewer's "view in your space" AR button (Android Scene Viewer).
  final bool ar;
  final bool autoRotate;

  /// Changing this value rebuilds the viewer, which resets the camera.
  final int resetToken;
}

/// Seam so widget tests can replace the WebView-based viewer with a plain widget.
typedef ModelViewerBuilder = Widget Function(BuildContext context, ViewerConfig config);

/// Production viewer: model_viewer_plus (Google's <model-viewer> inside a WebView).
Widget defaultModelViewerBuilder(BuildContext context, ViewerConfig config) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: ModelViewer(
      key: ValueKey<String>('${config.src}|${config.ar}|${config.resetToken}'),
      src: config.src,
      alt: config.alt,
      backgroundColor: AppColors.sandstoneLight,
      cameraControls: true,
      autoRotate: config.autoRotate,
      ar: config.ar,
      arModes: const <String>['scene-viewer', 'webxr'],
    ),
  );
}
