import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/monument.dart';
import '../../providers/monument_provider.dart';
import '../services/api_service.dart';
import 'error_banner.dart';
import 'loading_widgets.dart';
import 'status_chip.dart';
import '../theme/app_colors.dart';

/// Loads a full monument record (backend, falling back to bundled data) and builds [builder]
/// with it. Shows loading and error states with a Retry button.
class MonumentLoader extends StatefulWidget {
  const MonumentLoader({super.key, required this.monumentId, required this.builder});

  final String monumentId;
  final Widget Function(BuildContext context, Monument monument) builder;

  @override
  State<MonumentLoader> createState() => _MonumentLoaderState();
}

class _MonumentLoaderState extends State<MonumentLoader> {
  late Future<Monument> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<MonumentProvider>().details(widget.monumentId);
  }

  void _reload() {
    setState(() {
      _future = context.read<MonumentProvider>().details(widget.monumentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Monument>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<Monument> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingIndicator(message: 'Loading monument details…');
        }
        if (snapshot.hasError) {
          final Object? err = snapshot.error;
          final String message = err is ApiException
              ? err.message
              : 'The monument information could not be loaded.';
          return Padding(
            padding: const EdgeInsets.all(20),
            child: ErrorBanner(title: 'Monument unavailable', message: message, onRetry: _reload),
          );
        }
        return widget.builder(context, snapshot.data!);
      },
    );
  }
}

/// Small notice shown when bundled data is being displayed instead of live backend data.
class OfflineChip extends StatelessWidget {
  const OfflineChip({super.key});

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: StatusChip(
        label: 'Offline - showing bundled information',
        color: AppColors.terracotta,
        icon: Icons.cloud_off,
      ),
    );
  }
}
