import 'package:flutter/widgets.dart';

/// Central compact-screen rules. The tall-phone branch returns the exact
/// values the app already used, so Pixel-class devices do not move.
class ResponsiveGameLayout {
  const ResponsiveGameLayout(this.size);

  final Size size;

  bool get isCompactHeight => size.height < 720;
  bool get isUltraCompact => size.height < 680;
  bool get isTablet => size.width >= 600;

  /// Phones use the compact timeline composition at every height. The meme
  /// editor keeps its existing tall layout on phones and switches separately
  /// when a tablet needs the narrower column.
  bool get isCompactGameplay => size.width < 600;

  double get pagePadding => isCompactHeight ? 13 : 20;
  double get sectionGap => isCompactHeight ? 8 : 12;
  double get cardPadding => isCompactHeight ? 12 : 16;

  /// Thumb-friendly on every phone: 48 px on the shortest iPhone, 52 px on
  /// standard phones and 58 px on tall phones. Never shrink below this.
  double get controlHeight => isUltraCompact
      ? 48
      : isCompactHeight
      ? 52
      : 58;

  /// Secondary controls keep the same thumb target as primary ones: utility
  /// actions must not look like fingertips compared with the big buttons.
  double get smallControlHeight => isUltraCompact
      ? 48
      : isCompactHeight
      ? 50
      : 52;
  double get shadowOffset => isCompactHeight ? 3 : 5;
  double get qrSize => isCompactHeight ? 140 : 160;
  double get titleSize => isCompactHeight ? 22 : 28;
  double get largeTitleSize => isCompactHeight ? 26 : 34;
  double get timerSize => isCompactHeight ? 54 : 66;
  double get timerInnerSize => isCompactHeight ? 36 : 44;

  static ResponsiveGameLayout of(BuildContext context) =>
      ResponsiveGameLayout(MediaQuery.sizeOf(context));
}
