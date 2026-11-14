import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Heritage-inspired logo: a carved stone-chariot wheel inside an arch.
class HeritageLogo extends StatelessWidget {
  const HeritageLogo({super.key, this.size = 96, this.color = AppColors.terracotta});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'AI Heritage Reconstructor logo',
      child: CustomPaint(size: Size.square(size), painter: _LogoPainter(color)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round;
    final Paint fill = Paint()..color = color;

    // Arch outline
    final double w = size.width;
    final double h = size.height;
    final Path arch = Path()
      ..moveTo(w * 0.08, h * 0.95)
      ..lineTo(w * 0.08, h * 0.45)
      ..arcToPoint(Offset(w * 0.92, h * 0.45), radius: Radius.circular(w * 0.42))
      ..lineTo(w * 0.92, h * 0.95);
    canvas.drawPath(arch, stroke);

    // Wheel
    final Offset c = Offset(w * 0.5, h * 0.58);
    final double r = w * 0.27;
    canvas.drawCircle(c, r, stroke);
    canvas.drawCircle(c, r * 0.2, fill);
    for (int i = 0; i < 8; i++) {
      final double a = i * math.pi / 4;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * (r * 0.28),
        c + Offset(math.cos(a), math.sin(a)) * r,
        stroke..strokeWidth = size.width * 0.03,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => oldDelegate.color != color;
}
