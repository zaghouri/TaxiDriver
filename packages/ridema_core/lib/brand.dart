/// Brand identity for RideMA (D8).
///
/// This file is the ONLY place where the product name is written in code.
/// To rename the product: change [kAppName], run `python3 tool/make_logo.py`
/// to regenerate `assets/brand/`, and rebuild the apps.
library;

import 'package:flutter/material.dart';

/// Product name shown in the UI, notifications and share messages.
const String kAppName = 'RideMA';

/// Brand colours.
abstract final class BrandColors {
  /// Emerald — primary colour (buttons, app bars, highlights).
  static const Color primary = Color(0xFF0B6E4F);

  /// Saffron — accent colour (counter-offers, PIN, badges).
  static const Color accent = Color(0xFFF4A300);

  /// Ink — main text colour.
  static const Color ink = Color(0xFF1D1D1F);

  /// Light background used behind cards.
  static const Color surface = Color(0xFFF6F8F7);

  /// Danger red used for SOS and destructive actions.
  static const Color danger = Color(0xFFC62828);

  /// Positive green used for "verified" badges.
  static const Color success = Color(0xFF1B8A3A);
}

/// Paths of the brand assets inside this package.
abstract final class BrandAssets {
  static const String package = 'ridema_core';

  /// Square logo mark (pin on emerald), SVG.
  static const String markSvg = 'assets/brand/logo_mark.svg';

  /// Horizontal wordmark (mark + name), SVG.
  static const String wordmarkSvg = 'assets/brand/logo_wordmark.svg';

  /// 512×512 PNG of the mark (launcher icon source, store listing).
  static const String markPng = 'assets/brand/logo_mark_512.png';

  /// 1024×1024 PNG of the mark on a transparent background (adaptive icon foreground source).
  static const String markForegroundPng = 'assets/brand/logo_foreground_1024.png';
}
