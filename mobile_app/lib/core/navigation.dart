import 'package:flutter/material.dart';

/// One place for navigation so every screen transition behaves the same.
class Nav {
  Nav._();

  static Future<T?> push<T>(BuildContext context, Widget screen) {
    return Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (BuildContext _) => screen));
  }

  /// Replaces the current route (used by the splash screen).
  static void replace(BuildContext context, Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (BuildContext _) => screen),
    );
  }
}
