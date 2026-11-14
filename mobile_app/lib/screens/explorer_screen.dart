import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/navigation.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/heritage_image.dart';
import '../core/widgets/loading_widgets.dart';
import '../core/widgets/monument_loader.dart';
import '../models/monument.dart';
import '../providers/monument_provider.dart';
import 'monument_detail_screen.dart';

/// Screen 10 (part 1): searchable list of the monuments.
class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({super.key});

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MonumentProvider mp = context.watch<MonumentProvider>();
    final String q = _query.trim().toLowerCase();
    final List<Monument> items = mp.monuments
        .where((Monument m) => q.isEmpty || m.name.toLowerCase().contains(q) || m.location.toLowerCase().contains(q))
        .toList();

    Widget body;
    if (mp.monuments.isEmpty && (!mp.loaded || mp.loading)) {
      body = const LoadingIndicator(message: 'Loading monuments…');
    } else if (mp.monuments.isEmpty) {
      body = EmptyState(
        icon: Icons.account_balance_outlined,
        title: 'No monuments available',
        message: 'The list could not be loaded.',
        action: AppButton(label: 'Retry', icon: Icons.refresh, expand: false, onPressed: () => mp.load(force: true)),
      );
    } else if (items.isEmpty) {
      body = EmptyState(
        icon: Icons.search_off,
        title: 'No matches',
        message: 'No monument matches "${_query.trim()}".',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => mp.load(force: true),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: items.length,
          separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 12),
          itemBuilder: (BuildContext context, int i) => _MonumentRow(monument: items[i]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Explore monuments')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: (String v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search monuments',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.sandstone),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.sandstone),
                  ),
                ),
              ),
            ),
            if (mp.loaded && mp.offline)
              const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: OfflineChip()),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _MonumentRow extends StatelessWidget {
  const _MonumentRow({required this.monument});

  final Monument monument;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Nav.push<void>(context, MonumentDetailScreen(monumentId: monument.id)),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 84,
            height: 84,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: HeritageImage(
                networkUrl: monument.assets.thumbnailUrl,
                assetPath: AppConfig.bundledImageAsset(monument.id, 'present'),
                placeholderLabel: monument.name,
                compact: true,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(monument.name, style: text.titleMedium),
                const SizedBox(height: 4),
                Text(monument.location, style: text.bodyMedium?.copyWith(color: AppColors.mutedText)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.terracotta),
        ],
      ),
    );
  }
}
