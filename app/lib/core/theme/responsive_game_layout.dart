import 'package:flutter/widgets.dart';

/// Central compact-screen rules. The tall-phone branch returns the exact
/// values the app already used, so Pixel-class devices do not move.
class ResponsiveGameLayout {
  const ResponsiveGameLayout(this.size);

  final Size size;

  bool get isCompactHeight => size.height < 720;
  bool get isUltraCompact => size.height < 680;

  double get pagePadding => isCompactHeight ? 13 : 20;
  double get sectionGap => isCompactHeight ? 8 : 12;
  double get cardPadding => isCompactHeight ? 12 : 16;
  double get controlHeight => isCompactHeight ? 44 : 52;
  double get smallControlHeight => isCompactHeight ? 40 : 42;
  double get shadowOffset => isCompactHeight ? 3 : 5;
  double get qrSize => isCompactHeight ? 140 : 160;
  double get titleSize => isCompactHeight ? 22 : 28;
  double get largeTitleSize => isCompactHeight ? 26 : 34;
  double get timerSize => isCompactHeight ? 54 : 66;
  double get timerInnerSize => isCompactHeight ? 36 : 44;

  double scaled(double value) => isCompactHeight ? value * 0.8 : value;

  static ResponsiveGameLayout of(BuildContext context) =>
      ResponsiveGameLayout(MediaQuery.sizeOf(context));
}
