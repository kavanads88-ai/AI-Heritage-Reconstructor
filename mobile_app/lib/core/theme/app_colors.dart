import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color ivory = Color(0xFFFAF6EC);
  static const Color sandstone = Color(0xFFD9C3A5);
  static const Color sage = Color(0xFF87977A);
  static const Color terracotta = Color(0xFFB5523B);
  static const Color charcoal = Color(0xFF30312D);
  static const Color white = Color(0xFFFFFFFF);

  // Derived tints (explicit ARGB values avoid deprecated opacity helpers).
  static const Color sandstoneLight = Color(0xFFF0E6D6);
  static const Color sageDark = Color(0xFF4F5E44); // sage-family text with good contrast on ivory
  static const Color sageLight = Color(0xFFE6EBE1);
  static const Color mutedText = Color(0xFF5B5C55); // ~6:1 on ivory
  static const Color error = Color(0xFF9B2C2C);
  static const Color errorLight = Color(0xFFF8E6E3);
  static const Color shadow = Color(0x1F30312D);
  static const Color scrim = Color(0xB3FAF6EC);
  static const Color darkGradient = Color(0xCC30312D);
}
