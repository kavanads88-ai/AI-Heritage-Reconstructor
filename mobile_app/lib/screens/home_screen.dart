import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/navigation.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/heritage_logo.dart';
import '../core/widgets/loading_widgets.dart';
import '../core/widgets/monument_card.dart';
import '../core/widgets/monument_loader.dart';
import '../core/widgets/monument_picker.dart';
import '../core/widgets/section_header.dart';
import '../models/monument.dart';
import '../providers/monument_provider.dart';
import 'comparison_screen.dart';
import 'history_screen.dart';
import 'monument_detail_screen.dart';
import 'viewer_3d_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onScan, this.onExplore});

  final VoidCallback onScan;
  final VoidCallback? onExplore;

  Future<void> _shortcut(BuildContext context, String title, Widget Function(String id) build) async {
    final Monument? m = await showMonumentPicker(context, title: title);
    if (m == null || !context.mounted) return;
    await Nav.push<void>(context, build(m.id));
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Consumer<MonumentProvider>(
          builder: (BuildContext context, MonumentProvider mp, Widget? _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const HeritageLogo(size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AI Heritage Reconstructor',
                        style: text.titleMedium?.copyWith(color: AppColors.terracotta, fontFamily: 'serif'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text('Welcome, explorer', style: text.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Identify Hampi monuments from a photograph, read their sourced history, look for '
                  'possible damage indicators, compare reconstructions and view them in 3D and AR.',
                  style: text.bodyLarge?.copyWith(color: AppColors.mutedText),
                ),
                if (mp.loaded && mp.offline) ...<Widget>[
                  const SizedBox(height: 12),
                  const OfflineChip(),
                ],
                const SizedBox(height: 18),
                AppButton(label: 'Scan Monument', icon: Icons.camera_alt, onPressed: onScan),
                const SectionHeader('Featured monuments'),
                _Featured(provider: mp),
                const SectionHeader('Shortcuts'),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ShortcutTile(
                        icon: Icons.compare,
                        label: 'Reconstruction',
                        onTap: () => _shortcut(
                          context,
                          'Compare reconstruction',
                          (String id) => ComparisonScreen(monumentId: id),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ShortcutTile(
                        icon: Icons.view_in_ar,
                        label: '3D Explorer',
                        onTap: () => _shortcut(context, 'Explore in 3D', (String id) => Viewer3dScreen(monumentId: id)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ShortcutTile(
                        icon: Icons.menu_book_outlined,
                        label: 'History',
                        onTap: () => _shortcut(context, 'Read history', (String id) => HistoryScreen(monumentId: id)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  Disclaimers.curatedModels,
                  style: text.bodySmall?.copyWith(color: AppColors.mutedText),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Featured extends StatelessWidget {
  const _Featured({required this.provider});

  final MonumentProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.monuments.isEmpty) {
      if (!provider.loaded || provider.loading) {
        return const SizedBox(height: 200, child: LoadingIndicator(message: 'Loading monuments…'));
      }
      return SizedBox(
        height: 260,
        child: EmptyState(
          icon: Icons.account_balance_outlined,
          title: 'No monuments to show',
          message: 'The monument list could not be loaded.',
          action: AppButton(
            label: 'Retry',
            icon: Icons.refresh,
            expand: false,
            onPressed: () => provider.load(force: true),
          ),
        ),
      );
    }
    return SizedBox(
      height: 230,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: provider.monuments.length,
        separatorBuilder: (BuildContext _, int __) => const SizedBox(width: 14),
        itemBuilder: (BuildContext context, int i) {
          final Monument m = provider.monuments[i];
          return MonumentCard(
            monument: m,
            onTap: () => Nav.push<void>(context, MonumentDetailScreen(monumentId: m.id)),
          );
        },
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.white,
        elevation: 1.5,
        shadowColor: AppColors.shadow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            child: Column(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: AppColors.sandstoneLight, shape: BoxShape.circle),
                  child: Icon(icon, color: AppColors.terracotta),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
