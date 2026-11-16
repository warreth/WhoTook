import 'package:flutter/material.dart';

/// Palette tokens from DESIGN.md. Core surfaces stay flat; the party
/// backdrop owns the gradients and drifting props.
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
    required this.accent2,
    required this.onAccent2,
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

  /// Secondary party accent for premium shared themes. Classic keeps this
  /// equal to [accent] so the default look does not change.
  final Color accent2;
  final Color onAccent2;
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
    accent2: Color(0xFFC63D22),
    onAccent2: Color(0xFFFFFFFF),
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
    accent2: Color(0xFFE59437),
    onAccent2: Color(0xFF161513),
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
    Color? accent2,
    Color? onAccent2,
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
    accent2: accent2 ?? this.accent2,
    onAccent2: onAccent2 ?? this.onAccent2,
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
      accent2: Color.lerp(accent2, other.accent2, t)!,
      onAccent2: Color.lerp(onAccent2, other.onAccent2, t)!,
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
  static const double rControl = 12;
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

ThemeData buildWhoTookTheme(Brightness brightness, {WhoTookColors? palette}) {
  final colors =
      palette ??
      (brightness == Brightness.dark
          ? WhoTookColors.dark
          : WhoTookColors.light);
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

/// Flat crop-frame glyph with the new camera and question-mark lens. Drawn
/// with strokes only so it stays crisp at any size.
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
    final s = size.shortestSide;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.075
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.10, s * 0.30, s * 0.80, s * 0.56),
      Radius.circular(s * 0.13),
    );
    final hump = Path()
      ..moveTo(s * 0.30, s * 0.30)
      ..lineTo(s * 0.36, s * 0.17)
      ..lineTo(s * 0.64, s * 0.17)
      ..lineTo(s * 0.70, s * 0.30);
    canvas.drawRRect(body, stroke);
    canvas.drawPath(hump, stroke);
    canvas.drawCircle(Offset(s * 0.50, s * 0.58), s * 0.19, stroke);
    final question = TextPainter(
      text: TextSpan(
        text: '?',
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: s * 0.30,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    question.paint(
      canvas,
      Offset(s * 0.50 - question.width / 2, s * 0.58 - question.height / 2),
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.color != color;
}

/// The product logo: a terracotta camera with a yellow question mark in the
/// lens, black neo-brutalist border and a hard offset shadow.
class WhoTookLogo extends StatelessWidget {
  const WhoTookLogo({super.key, this.size = 48, this.shadow = true});

  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _LogoPainter(shadow: shadow)),
  );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.shadow});

  final bool shadow;

  static const Color terracotta = Color(0xFFC63D22);
  static const Color charcoal = Color(0xFF1A1714);
  static const Color yellow = Color(0xFFFFC93C);
  static const Color cream = Color(0xFFFFF8E8);

  RRect _body(double s) => RRect.fromRectAndRadius(
    Rect.fromLTWH(s * 0.08, s * 0.28, s * 0.84, s * 0.58),
    Radius.circular(s * 0.14),
  );

  Path _hump(double s) => Path()
    ..moveTo(s * 0.30, s * 0.30)
    ..lineTo(s * 0.37, s * 0.16)
    ..lineTo(s * 0.64, s * 0.16)
    ..lineTo(s * 0.71, s * 0.30)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.scale(s / 64);
    final ink = Paint()..color = charcoal;
    final body = _body(64);
    final hump = _hump(64);

    if (shadow) {
      canvas.save();
      canvas.translate(4, 5);
      final shadowBody = RRect.fromRectAndRadius(
        body.outerRect,
        const Radius.circular(9),
      );
      canvas.drawRRect(shadowBody, ink);
      canvas.drawPath(hump, ink);
      canvas.restore();
    }

    final fill = Paint()..color = terracotta;
    final border = Paint()
      ..color = charcoal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(hump, fill);
    canvas.drawPath(hump, border);
    canvas.drawRRect(body, fill);
    canvas.drawRRect(body, border);

    // Viewfinder and shutter button.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(13, 24, 11, 6),
        const Radius.circular(2),
      ),
      Paint()..color = cream,
    );
    canvas.drawCircle(const Offset(51, 33), 3.2, Paint()..color = yellow);

    // Lens, with the question mark set into it.
    const lensCentre = Offset(32, 41);
    canvas.drawCircle(lensCentre, 15, Paint()..color = cream);
    canvas.drawCircle(lensCentre, 15, border);
    canvas.drawCircle(lensCentre, 12, Paint()..color = charcoal);
    canvas.drawCircle(
      lensCentre,
      9.2,
      Paint()
        ..color = const Color(0xFF3A332D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    final question = TextPainter(
      text: const TextSpan(
        text: '?',
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: yellow,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    question.paint(
      canvas,
      Offset(
        lensCentre.dx - question.width / 2,
        lensCentre.dy - question.height / 2,
      ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => oldDelegate.shadow != shadow;
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
