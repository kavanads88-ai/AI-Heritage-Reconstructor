import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../screens/comparison_screen.dart';
import '../../screens/damage_screen.dart';
import '../../screens/history_screen.dart';
import '../../screens/viewer_3d_screen.dart';
import '../navigation.dart';
import 'app_button.dart';

/// The four standard actions available for a monument.
class MonumentActions extends StatelessWidget {
  const MonumentActions({super.key, required this.monumentId, this.photo});

  final String monumentId;

  /// Photograph the user already took (reused by damage analysis).
  final Uint8List? photo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        AppButton(
          label: 'View History',
          icon: Icons.menu_book_outlined,
          onPressed: () => Nav.push<void>(context, HistoryScreen(monumentId: monumentId)),
        ),
        const SizedBox(height: 10),
        AppButton(
          label: 'Analyze Damage',
          icon: Icons.troubleshoot,
          style: AppButtonStyle.secondary,
          onPressed: () => Nav.push<void>(context, DamageScreen(monumentId: monumentId, initialPhoto: photo)),
        ),
        const SizedBox(height: 10),
        AppButton(
          label: 'Compare Reconstruction',
          icon: Icons.compare,
          style: AppButtonStyle.secondary,
          onPressed: () => Nav.push<void>(context, ComparisonScreen(monumentId: monumentId)),
        ),
        const SizedBox(height: 10),
        AppButton(
          label: 'Explore in 3D',
          icon: Icons.view_in_ar,
          style: AppButtonStyle.secondary,
          onPressed: () => Nav.push<void>(context, Viewer3dScreen(monumentId: monumentId)),
        ),
      ],
    );
  }
}
