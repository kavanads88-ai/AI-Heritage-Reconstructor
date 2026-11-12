import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/monument.dart';
import '../../providers/monument_provider.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import 'empty_state.dart';
import 'heritage_image.dart';

/// Bottom sheet that lets the user choose one of the monuments.
Future<Monument?> showMonumentPicker(BuildContext context, {String title = 'Choose a monument'}) {
  final List<Monument> monuments = context.read<MonumentProvider>().monuments;
  return showModalBottomSheet<Monument>(
    context: context,
    backgroundColor: AppColors.ivory,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
              ),
              if (monuments.isEmpty)
                const EmptyState(
                  icon: Icons.account_balance_outlined,
                  title: 'No monuments loaded yet',
                  message: 'Go back and wait for the list to load, or check the backend connection in Settings.',
                )
              else
                for (final Monument m in monuments)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: SizedBox(
                      width: 56,
                      height: 56,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: HeritageImage(
                          networkUrl: m.assets.thumbnailUrl,
                          assetPath: AppConfig.bundledImageAsset(m.id, 'present'),
                          placeholderLabel: m.name,
                          compact: true,
                        ),
                      ),
                    ),
                    title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(m.location),
                    onTap: () => Navigator.of(sheetContext).pop(m),
                  ),
            ],
          ),
        ),
      );
    },
  );
}
