import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/navigation.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/heritage_logo.dart';
import 'home_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.duration = AppConfig.splashDuration});

  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, () {
      if (!mounted) return;
      Nav.replace(context, const HomeShell());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            builder: (BuildContext context, double t, Widget? child) =>
                Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 16), child: child)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 148,
                    height: 148,
                    decoration: const BoxDecoration(
                      color: AppColors.sandstoneLight,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const HeritageLogo(size: 96),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'AI Heritage\nReconstructor',
                    textAlign: TextAlign.center,
                    style: text.headlineMedium?.copyWith(color: AppColors.terracotta, height: 1.15),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Discover the Past. Visualise Heritage.',
                    textAlign: TextAlign.center,
                    style: text.bodyLarge?.copyWith(color: AppColors.charcoal),
                  ),
                  const SizedBox(height: 36),
                  const SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: AppColors.sandstone,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
