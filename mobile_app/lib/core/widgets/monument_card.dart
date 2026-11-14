import 'package:flutter/material.dart';

import '../../models/monument.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import 'heritage_image.dart';

/// Photo card used for featured monuments.
class MonumentCard extends StatelessWidget {
  const MonumentCard({super.key, required this.monument, required this.onTap, this.width = 250});

  final Monument monument;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(20);
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: '${monument.name}, ${monument.location}',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: const <BoxShadow>[
              BoxShadow(color: AppColors.shadow, blurRadius: 14, offset: Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                HeritageImage(
                  networkUrl: monument.assets.thumbnailUrl,
                  assetPath: AppConfig.bundledImageAsset(monument.id, 'present'),
                  placeholderLabel: monument.name,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0x0030312D), AppColors.darkGradient],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        monument.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'serif',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        monument.location,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(onTap: onTap),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
