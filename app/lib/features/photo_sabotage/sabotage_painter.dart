import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/models.dart';

/// Eight high-contrast marker colours every sabotage player gets. The index
/// travels on the wire, so the palette matches across all devices.
const List<Color> sabotageColors = <Color>[
  Color(0xFF16120F),
  Color(0xFFFFFFFF),
  Color(0xFFE53935),
  Color(0xFFFFD400),
  Color(0xFF39D353),
  Color(0xFF2979FF),
  Color(0xFFEC4899),
  Color(0xFFFF6D00),
];

Color sabotageColor(int index) =>
    sabotageColors[index.clamp(0, sabotageColors.length - 1)];

/// Paints normalized marker strokes and stickers over a photo. Points are
/// mapped to the current canvas size, so an iPhone, Android phone, and iPad
/// show the same drawing in the exact same spot.
class SabotageDrawingPainter extends CustomPainter {
  SabotageDrawingPainter({
    required this.strokes,
    this.stickers = const <SabotageSticker>[],
    this.selectedStickerIndex,
    this.progress = 1.0,
  });

  final List<SabotageStroke> strokes;
  final List<SabotageSticker> stickers;
  final int? selectedStickerIndex;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final clampedProgress = progress.clamp(0.0, 1.0);
    final totalPoints = strokes.fold<int>(
      0,
      (sum, stroke) => sum + stroke.points.length,
    );
    var remaining = (totalPoints * clampedProgress).ceil();
    for (final stroke in strokes) {
      if (remaining <= 0) break;
      final paint = Paint()
        ..color = sabotageColor(stroke.colorIndex)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(1.5, stroke.width * size.shortestSide);
      final points = stroke.points.take(remaining).toList();
      remaining -= points.length;
      if (points.isEmpty) continue;
      if (points.length == 1) {
        canvas.drawCircle(
          Offset(points.first.dx * size.width, points.first.dy * size.height),
          paint.strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
        continue;
      }
      final path = Path()
        ..moveTo(points.first.dx * size.width, points.first.dy * size.height);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }

    if (stickers.isEmpty || clampedProgress < 0.15) return;
    final visibleStickers = totalPoints == 0
        ? (stickers.length * clampedProgress).ceil().clamp(0, stickers.length)
        : clampedProgress >= 0.85
        ? stickers.length
        : (stickers.length * ((clampedProgress - 0.15) / 0.7))
              .ceil()
              .clamp(0, stickers.length);
    for (var i = 0; i < visibleStickers; i++) {
      paintSabotageSticker(
        canvas,
        size,
        stickers[i],
        selected: selectedStickerIndex == i,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SabotageDrawingPainter oldDelegate) => true;
}

/// Draws a single cartoon sticker onto [canvas] using normalized coordinates or
/// an explicit [unitOverride] for icon previews.
void paintSabotageSticker(
  Canvas canvas,
  Size size,
  SabotageSticker sticker, {
  bool selected = false,
  double? unitOverride,
}) {
  final center = Offset(sticker.x * size.width, sticker.y * size.height);
  final unit = unitOverride ?? (size.shortestSide * 0.14 * sticker.scale);
  final ink = const Color(0xFF16120F);
  final outlineWidth = math.max(1.4, unit * 0.085);

  if (selected) {
    final box = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: unit * 2.35, height: unit * 1.75),
      Radius.circular(unit * 0.25),
    );
    canvas.drawRRect(
      box,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawRRect(
      box,
      Paint()
        ..color = const Color(0xFFFFD400)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  canvas.save();
  canvas.translate(center.dx, center.dy);
  switch (sticker.kind) {
    case SabotageStickerKind.googlyEyes:
      final r = unit * 0.36;
      final sep = r * 1.1;
      final white = Paint()..color = Colors.white;
      final border = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = outlineWidth;
      final pupil = Paint()..color = ink;
      for (final dx in <double>[-sep, sep]) {
        final eyeCenter = Offset(dx, 0);
        canvas.drawCircle(eyeCenter, r, white);
        canvas.drawCircle(eyeCenter, r, border);
        canvas.drawCircle(
          Offset(dx + r * 0.26, -r * 0.12),
          r * 0.45,
          pupil,
        );
      }
    case SabotageStickerKind.mustache:
      final fill = Paint()..color = ink;
      final edge = Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, unit * 0.045);
      final path = Path()
        ..moveTo(0, -unit * 0.1)
        ..cubicTo(
          -unit * 0.3,
          -unit * 0.35,
          -unit * 0.7,
          unit * 0.35,
          -unit * 0.95,
          0,
        )
        ..cubicTo(
          -unit * 0.65,
          unit * 0.55,
          -unit * 0.2,
          unit * 0.2,
          0,
          unit * 0.15,
        )
        ..cubicTo(
          unit * 0.2,
          unit * 0.2,
          unit * 0.65,
          unit * 0.55,
          unit * 0.95,
          0,
        )
        ..cubicTo(
          unit * 0.7,
          unit * 0.35,
          unit * 0.3,
          -unit * 0.35,
          0,
          -unit * 0.1,
        )
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, edge);
    case SabotageStickerKind.crown:
      final fill = Paint()..color = const Color(0xFFFFD400);
      final border = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = outlineWidth
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(-unit * 0.68, unit * 0.36)
        ..lineTo(-unit * 0.78, -unit * 0.32)
        ..lineTo(-unit * 0.3, unit * 0.02)
        ..lineTo(0, -unit * 0.5)
        ..lineTo(unit * 0.3, unit * 0.02)
        ..lineTo(unit * 0.78, -unit * 0.32)
        ..lineTo(unit * 0.68, unit * 0.36)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, border);
      canvas.drawCircle(
        Offset(0, unit * 0.14),
        unit * 0.1,
        Paint()..color = const Color(0xFFE53935),
      );
    case SabotageStickerKind.sunglasses:
      final dark = Paint()..color = ink;
      final rim = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, unit * 0.05);
      final glare = Paint()
        ..color = Colors.white
        ..strokeWidth = math.max(1.4, unit * 0.07)
        ..strokeCap = StrokeCap.round;
      final leftLens = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(-unit * 0.42, 0),
          width: unit * 0.68,
          height: unit * 0.46,
        ),
        Radius.circular(unit * 0.09),
      );
      final rightLens = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(unit * 0.42, 0),
          width: unit * 0.68,
          height: unit * 0.46,
        ),
        Radius.circular(unit * 0.09),
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(0, -unit * 0.08),
          width: unit * 1.65,
          height: unit * 0.11,
        ),
        dark,
      );
      canvas.drawRRect(leftLens, dark);
      canvas.drawRRect(rightLens, dark);
      canvas.drawRRect(leftLens, rim);
      canvas.drawRRect(rightLens, rim);
      canvas.drawLine(
        Offset(-unit * 0.58, -unit * 0.11),
        Offset(-unit * 0.4, unit * 0.11),
        glare,
      );
      canvas.drawLine(
        Offset(unit * 0.24, -unit * 0.11),
        Offset(unit * 0.42, unit * 0.11),
        glare,
      );
    case SabotageStickerKind.censorBar:
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: unit * 1.85,
          height: unit * 0.54,
        ),
        Radius.circular(unit * 0.08),
      );
      canvas.drawRRect(rect, Paint()..color = ink);
      canvas.drawRRect(
        rect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, unit * 0.05),
      );
      final stripe = Paint()
        ..color = const Color(0xFFE53935)
        ..strokeWidth = math.max(1.5, unit * 0.08)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(-unit * 0.68, 0),
        Offset(unit * 0.68, 0),
        stripe,
      );
    case SabotageStickerKind.heart:
      final fill = Paint()..color = const Color(0xFFE53935);
      final border = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = outlineWidth
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(0, unit * 0.52)
        ..cubicTo(
          -unit * 0.9,
          unit * 0.05,
          -unit * 0.76,
          -unit * 0.62,
          0,
          -unit * 0.14,
        )
        ..cubicTo(
          unit * 0.76,
          -unit * 0.62,
          unit * 0.9,
          unit * 0.05,
          0,
          unit * 0.52,
        )
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, border);
    case SabotageStickerKind.clownNose:
      final r = unit * 0.46;
      canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFFE53935));
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = outlineWidth,
      );
      canvas.drawCircle(
        Offset(-r * 0.3, -r * 0.28),
        r * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    case SabotageStickerKind.devilHorns:
      final fill = Paint()..color = const Color(0xFFE53935);
      final border = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = outlineWidth
        ..strokeJoin = StrokeJoin.round;
      for (final sign in <double>[-1, 1]) {
        final horn = Path()
          ..moveTo(sign * unit * 0.22, unit * 0.34)
          ..quadraticBezierTo(
            sign * unit * 0.88,
            unit * 0.06,
            sign * unit * 0.68,
            -unit * 0.56,
          )
          ..quadraticBezierTo(
            sign * unit * 0.48,
            -unit * 0.05,
            sign * unit * 0.54,
            unit * 0.34,
          )
          ..close();
        canvas.drawPath(horn, fill);
        canvas.drawPath(horn, border);
      }
    case SabotageStickerKind.halo:
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: unit * 1.48,
        height: unit * 0.52,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = outlineWidth + math.max(3.0, unit * 0.16),
      );
      canvas.drawOval(
        rect,
        Paint()
          ..color = const Color(0xFFFFD400)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.6, unit * 0.15),
      );
    case SabotageStickerKind.partyHat:
      final cone = Path()
        ..moveTo(0, -unit * 0.62)
        ..lineTo(-unit * 0.52, unit * 0.48)
        ..lineTo(unit * 0.52, unit * 0.48)
        ..close();
      canvas.drawPath(cone, Paint()..color = const Color(0xFF2979FF));
      final stripe = Path()
        ..moveTo(-unit * 0.26, -unit * 0.07)
        ..lineTo(unit * 0.26, -unit * 0.07)
        ..lineTo(unit * 0.39, unit * 0.21)
        ..lineTo(-unit * 0.39, unit * 0.21)
        ..close();
      canvas.drawPath(stripe, Paint()..color = const Color(0xFFFFD400));
      canvas.drawPath(
        cone,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = outlineWidth
          ..strokeJoin = StrokeJoin.round,
      );
      final pomCenter = Offset(0, -unit * 0.64);
      final pomR = unit * 0.16;
      canvas.drawCircle(pomCenter, pomR, Paint()..color = const Color(0xFFEC4899));
      canvas.drawCircle(
        pomCenter,
        pomR,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, outlineWidth * 0.8),
      );
  }
  canvas.restore();
}

/// Compact vector icon widget rendering a sticker in the sabotage picker bar
/// without any text labels.
class SabotageStickerIcon extends StatelessWidget {
  const SabotageStickerIcon({
    super.key,
    required this.kind,
    this.size = 28,
  });

  final SabotageStickerKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _StickerIconPainter(kind: kind),
      ),
    );
  }
}

class _StickerIconPainter extends CustomPainter {
  const _StickerIconPainter({required this.kind});

  final SabotageStickerKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    paintSabotageSticker(
      canvas,
      size,
      SabotageSticker(kind: kind, x: 0.5, y: 0.5),
      unitOverride: size.shortestSide * 0.44,
    );
  }

  @override
  bool shouldRepaint(covariant _StickerIconPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
