import 'package:flutter/material.dart';

/// Palette tokens from DESIGN.md. Every color is a flat value; no gradients.
@immutable
class WhoTookColors extends ThemeExtension<WhoTookColors> {
  const WhoTookColors({
    required this.bg,
    required this.card,
    required this.raised,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.accent,
    required this.onAccent,
    required this.positive,
    required this.negative,
    required this.hairline,
  });

  final Color bg;
  final Color card;
  final Color raised;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color accent;
  final Color onAccent;
  final Color positive;
  final Color negative;
  final Color hairline;

  /// Warm Contact Sheet.
  static const WhoTookColors light = WhoTookColors(
    bg: Color(0xFFF7F4EE),
    card: Color(0xFFFFFFFF),
    raised: Color(0xFFEFE9DF),
    ink: Color(0xFF1F1B16),
    ink2: Color(0xFF5E554A),
    ink3: Color(0xFF6E655A),
    accent: Color(0xFFC63D22),
    onAccent: Color(0xFFFFFFFF),
    positive: Color(0xFF15803D),
    negative: Color(0xFFB91C1C),
    hairline: Color(0x1A1F1B16),
  );

  /// Darkroom Ink.
  static const WhoTookColors dark = WhoTookColors(
    bg: Color(0xFF161513),
    card: Color(0xFF1C1A18),
    raised: Color(0xFF262421),
    ink: Color(0xFFEFE9DE),
    ink2: Color(0xFFB4ADA1),
    ink3: Color(0xFF989186),
    accent: Color(0xFFE59437),
    onAccent: Color(0xFF161513),
    positive: Color(0xFF4CC38A),
    negative: Color(0xFFF06A6E),
    hairline: Color(0x1AEFE9DE),
  );

  static WhoTookColors of(BuildContext context) =>
      Theme.of(context).extension<WhoTookColors>() ?? light;

  @override
  WhoTookColors copyWith({
    Color? bg,
    Color? card,
    Color? raised,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? accent,
    Color? onAccent,
    Color? positive,
    Color? negative,
    Color? hairline,
  }) => WhoTookColors(
    bg: bg ?? this.bg,
    card: card ?? this.card,
    raised: raised ?? this.raised,
    ink: ink ?? this.ink,
    ink2: ink2 ?? this.ink2,
    ink3: ink3 ?? this.ink3,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    positive: positive ?? this.positive,
    negative: negative ?? this.negative,
    hairline: hairline ?? this.hairline,
  );

  @override
  WhoTookColors lerp(ThemeExtension<WhoTookColors>? other, double t) {
    if (other is! WhoTookColors) {
      return this;
    }
    return WhoTookColors(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
    );
  }
}

/// Strict 4px grid.
abstract final class AppSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
}

/// Nested radius rule: print matte 6 inside card 14, modal 16.
abstract final class AppRadii {
  static const double rSm = 6;
  static const double rControl = 10;
  static const double rCard = 14;
  static const double rModal = 16;
}

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
}

/// Numbers that tick must not jitter, so counters use tabular figures.
TextStyle tabularFigures(TextStyle style) => style.copyWith(
  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
);

ThemeData buildWhoTookTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark
      ? WhoTookColors.dark
      : WhoTookColors.light;
  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    fontFamily: 'DMSans',
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: colors.accent,
          brightness: brightness,
        ).copyWith(
          primary: colors.accent,
          onPrimary: colors.onAccent,
          surface: colors.card,
          onSurface: colors.ink,
          error: colors.negative,
        ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: colors.bg,
    extensions: <ThemeExtension<dynamic>>[colors],
    textTheme: base.textTheme.apply(
      bodyColor: colors.ink,
      displayColor: colors.ink,
    ),
    dividerColor: colors.hairline,
  );
}

/// Flat crop-frame glyph: a rounded print matte with four corner marks and a
/// lens ring. Drawn with strokes only so it stays crisp at any size.
class WhoTookMark extends StatelessWidget {
  const WhoTookMark({super.key, this.size = 48, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? WhoTookColors.of(context).ink;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter(ink)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.09;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square;
    final inset = stroke * 0.75;
    final rect = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );
    final arm = size.shortestSide * 0.26;
    final path = Path()
      ..moveTo(rect.left, rect.top + arm)
      ..lineTo(rect.left, rect.top)
      ..lineTo(rect.left + arm, rect.top)
      ..moveTo(rect.right - arm, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.top + arm)
      ..moveTo(rect.right, rect.bottom - arm)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.right - arm, rect.bottom)
      ..moveTo(rect.left + arm, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.bottom - arm);
    canvas.drawPath(path, paint);
    final center = rect.center;
    final lens = size.shortestSide * 0.16;
    canvas.drawCircle(center, lens, paint);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.color != color;
}

/// The four crisp corner crop marks around the active photo frame.
class CropFrameOverlay extends StatelessWidget {
  const CropFrameOverlay({
    super.key,
    this.color,
    this.armLength = 18,
    this.strokeWidth = 2,
    this.inset = 0,
  });

  final Color? color;
  final double armLength;
  final double strokeWidth;
  final double inset;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? WhoTookColors.of(context).ink;
    return IgnorePointer(
      child: CustomPaint(
        painter: _CropFramePainter(
          color: ink,
          armLength: armLength,
          strokeWidth: strokeWidth,
          inset: inset,
        ),
      ),
    );
  }
}

class _CropFramePainter extends CustomPainter {
  _CropFramePainter({
    required this.color,
    required this.armLength,
    required this.strokeWidth,
    required this.inset,
  });

  final Color color;
  final double armLength;
  final double strokeWidth;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;
    final left = inset;
    final top = inset;
    final right = size.width - inset;
    final bottom = size.height - inset;
    final arm = armLength;
    final path = Path()
      ..moveTo(left, top + arm)
      ..lineTo(left, top)
      ..lineTo(left + arm, top)
      ..moveTo(right - arm, top)
      ..lineTo(right, top)
      ..lineTo(right, top + arm)
      ..moveTo(right, bottom - arm)
      ..lineTo(right, bottom)
      ..lineTo(right - arm, bottom)
      ..moveTo(left + arm, bottom)
      ..lineTo(left, bottom)
      ..lineTo(left, bottom - arm);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CropFramePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.armLength != armLength ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.inset != inset;
}
