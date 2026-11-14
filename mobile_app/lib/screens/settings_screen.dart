import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/disclaimer_banner.dart';
import '../core/widgets/error_banner.dart';
import '../core/widgets/section_header.dart';
import '../core/widgets/status_chip.dart';
import '../providers/connection_provider.dart';
import '../providers/monument_provider.dart';
import '../providers/settings_provider.dart';

/// Screen 10 (part 2): backend connection status, configuration and the About section.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _url;
  String? _urlError;
  String? _saved;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: context.read<AppSettings>().baseUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final AppSettings settings = context.read<AppSettings>();
    final ConnectionProvider connection = context.read<ConnectionProvider>();
    try {
      settings.updateBaseUrl(_url.text);
      _url.text = settings.baseUrl;
      setState(() {
        _urlError = null;
        _saved = 'Backend address saved: ${settings.baseUrl}';
      });
      await connection.check();
    } on FormatException catch (e) {
      setState(() {
        _urlError = e.message;
        _saved = null;
      });
    }
  }

  void _preset(String url) {
    _url.text = url;
    setState(() {
      _urlError = null;
      _saved = null;
    });
  }

  Future<void> _retryEverything() async {
    final MonumentProvider monuments = context.read<MonumentProvider>();
    final ConnectionProvider connection = context.read<ConnectionProvider>();
    await connection.check();
    if (!mounted) return;
    await monuments.load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AppSettings settings = context.watch<AppSettings>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & About')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: <Widget>[
            const SectionHeader('Backend connection', padding: EdgeInsets.only(top: 4, bottom: 10)),
            _ConnectionCard(onRetry: _retryEverything),
            const SizedBox(height: 14),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: 'Backend address',
                hintText: 'http://10.0.2.2:8000',
                errorText: _urlError,
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ActionChip(
                  label: const Text('Emulator (10.0.2.2)'),
                  onPressed: () => _preset('http://10.0.2.2:8000'),
                ),
                ActionChip(
                  label: const Text('USB + adb reverse (127.0.0.1)'),
                  onPressed: () => _preset('http://127.0.0.1:8000'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Same Wi-Fi: type http://<your PC IPv4 address>:8000 (find it with ipconfig on the PC). '
              'Never use "localhost" for a phone - it means the phone itself.',
              style: text.bodySmall?.copyWith(color: AppColors.mutedText),
            ),
            const SizedBox(height: 12),
            AppButton(label: 'Save and test connection', icon: Icons.save_outlined, onPressed: _save),
            if (_saved != null) ...<Widget>[
              const SizedBox(height: 10),
              SuccessBanner(message: _saved!),
            ],
            const SectionHeader('Recognition threshold'),
            Text(
              'Photos recognised with less confidence than this are shown as "Unknown Monument". '
              'Current value: ${(settings.threshold * 100).round()}%.',
              style: text.bodyMedium,
            ),
            Slider(
              value: settings.threshold.clamp(0.3, 0.95).toDouble(),
              min: 0.3,
              max: 0.95,
              divisions: 13,
              label: '${(settings.threshold * 100).round()}%',
              onChanged: (double v) => context.read<AppSettings>().updateThreshold(v),
            ),
            const SectionHeader('About'),
            const _AboutCard(),
          ],
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final ConnectionProvider c = context.watch<ConnectionProvider>();
    final TextTheme text = Theme.of(context).textTheme;

    final (String label, Color color, IconData icon) = switch (c.state) {
      BackendState.online => ('Connected', AppColors.sageDark, Icons.cloud_done_outlined),
      BackendState.offline => ('Not reachable', AppColors.error, Icons.cloud_off),
      BackendState.checking => ('Checking…', AppColors.charcoal, Icons.sync),
      BackendState.unknown => ('Not checked yet', AppColors.charcoal, Icons.cloud_queue),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              StatusChip(label: label, color: color, icon: icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.watch<AppSettings>().baseUrl,
                  style: text.bodySmall?.copyWith(color: AppColors.mutedText),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (c.state == BackendState.online && c.health != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(c.health!.message, style: text.bodyMedium),
            const SizedBox(height: 6),
            if (c.health!.modelLoaded)
              const Text('Recognition model: loaded on the server.')
            else if (c.health!.mockEnabled)
              const DisclaimerBanner(
                icon: Icons.science_outlined,
                text: 'No trained model is installed on the server. Scan results are MOCK data, '
                    'not AI predictions.',
              )
            else
              Text('Recognition model: not available (${c.health!.modelStatus}).'),
          ],
          if (c.state == BackendState.offline && c.error != null) ...<Widget>[
            const SizedBox(height: 10),
            ErrorBanner(
              title: 'Backend not reachable',
              message: '${c.error!}\nHistory stays readable offline from bundled data; scanning, damage '
                  'analysis, reconstruction images and downloaded 3D models need the backend.',
            ),
          ],
          const SizedBox(height: 12),
          AppButton(
            label: c.state == BackendState.checking ? 'Checking…' : 'Retry connection',
            icon: Icons.refresh,
            style: AppButtonStyle.secondary,
            loading: c.state == BackendState.checking,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    Widget bullet(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 7, right: 8),
                child: Icon(Icons.circle, size: 6, color: AppColors.terracotta),
              ),
              Expanded(child: Text(t)),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('AI Heritage Reconstructor', style: text.titleLarge),
              const SizedBox(height: 4),
              Text('Discover the Past. Visualise Heritage.', style: text.bodyMedium),
              const SizedBox(height: 10),
              const Text(
                'An academic project for exploring three monuments at Hampi: the Stone Chariot, the '
                'Vittala Temple and the Lotus Mahal.',
              ),
              const SizedBox(height: 12),
              Text('Technologies', style: text.titleMedium),
              const SizedBox(height: 6),
              bullet('App: Flutter / Dart, Material Design 3'),
              bullet('Backend: Python, FastAPI, Uvicorn'),
              bullet('Recognition: TensorFlow/Keras MobileNetV2 (transfer learning, trained in Google Colab)'),
              bullet('Damage indicators: OpenCV image processing (not a trained model)'),
              bullet('3D / AR: model_viewer_plus and Android Scene Viewer (ARCore devices only)'),
              bullet('Speech: flutter_tts using the phone\'s English voice'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const DisclaimerBanner(text: Disclaimers.curatedModels),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Limitations', style: text.titleMedium),
              const SizedBox(height: 8),
              bullet('Reconstruction images and 3D models are prepared manually by the project team; they are not AI-generated.'),
              bullet(Disclaimers.reconstruction),
              bullet(Disclaimers.damage),
              bullet('Historical text is marked "pending verification" until it has been checked against ASI or UNESCO sources.'),
              bullet(Disclaimers.arRequirements),
            ],
          ),
        ),
      ],
    );
  }
}
