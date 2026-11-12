import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Horizontal before/after slider. [before] is revealed on the left of the handle,
/// [after] on the right. Drag anywhere (or tap) to move the divider.
class ComparisonSlider extends StatefulWidget {
  const ComparisonSlider({
    super.key,
    required this.before,
    required this.after,
    this.beforeLabel = 'Present Appearance',
    this.afterLabel = 'Proposed Reconstruction',
    this.aspectRatio = 4 / 3,
    this.initialPosition = 0.5,
  });

  final Widget before;
  final Widget after;
  final String beforeLabel;
  final String afterLabel;
  final double aspectRatio;
  final double initialPosition;

  @override
  State<ComparisonSlider> createState() => _ComparisonSliderState();
}

class _ComparisonSliderState extends State<ComparisonSlider> {
  late double _position = widget.initialPosition.clamp(0.0, 1.0).toDouble();

  void _setFromDx(double dx, double width) {
    if (width <= 0) return;
    setState(() => _position = (dx / width).clamp(0.0, 1.0).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth;
            final double height = constraints.maxHeight;
            final double x = width * _position;
            return Semantics(
              slider: true,
              label: 'Comparison slider: ${widget.beforeLabel} versus ${widget.afterLabel}',
              value: '${(_position * 100).round()} percent',
              increasedValue: '${((_position + 0.1).clamp(0.0, 1.0) * 100).round()} percent',
              decreasedValue: '${((_position - 0.1).clamp(0.0, 1.0) * 100).round()} percent',
              onIncrease: () => setState(() => _position = (_position + 0.1).clamp(0.0, 1.0).toDouble()),
              onDecrease: () => setState(() => _position = (_position - 0.1).clamp(0.0, 1.0).toDouble()),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (DragUpdateDetails d) => _setFromDx(x + d.delta.dx, width),
                onTapDown: (TapDownDetails d) => _setFromDx(d.localPosition.dx, width),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    widget.after,
                    ClipRect(clipper: _LeftClipper(x), child: widget.before),
                    Positioned(left: 10, top: 10, child: _Label(widget.beforeLabel)),
                    Positioned(right: 10, top: 10, child: _Label(widget.afterLabel)),
                    Positioned(
                      left: x - 1.5,
                      top: 0,
                      bottom: 0,
                      width: 3,
                      child: const ColoredBox(color: AppColors.white),
                    ),
                    Positioned(
                      left: x - 22,
                      top: height / 2 - 22,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.terracotta,
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2)),
                          ],
                        ),
                        child: const Icon(Icons.compare_arrows, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  _LeftClipper(this.x);

  final double x;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, x, size.height);

  @override
  bool shouldReclip(covariant _LeftClipper oldClipper) => oldClipper.x != x;
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.darkGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
