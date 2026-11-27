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
    this.progress = 1.0,
  });

  final List<SabotageStroke> strokes;
  final List<SabotageSticker> stickers;
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
      _paintSticker(canvas, size, stickers[i]);
    }
  }

  void _paintSticker(Canvas canvas, Size size, SabotageSticker sticker) {
    final center = Offset(sticker.x * size.width, sticker.y * size.height);
    final unit = size.shortestSide * 0.14 * sticker.scale;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    switch (sticker.kind) {
      case SabotageStickerKind.googlyEyes:
        final r = unit * 0.34;
        final sep = r * 1.15;
        final white = Paint()..color = Colors.white;
        final border = Paint()
          ..color = const Color(0xFF16120F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, unit * 0.08);
        final pupil = Paint()..color = const Color(0xFF16120F);
        for (final dx in <double>[-sep, sep]) {
          final eyeCenter = Offset(dx, 0);
          canvas.drawCircle(eyeCenter, r, white);
          canvas.drawCircle(eyeCenter, r, border);
          canvas.drawCircle(
            Offset(dx + r * 0.28, -r * 0.12),
            r * 0.45,
            pupil,
          );
        }
      case SabotageStickerKind.mustache:
        final fill = Paint()..color = const Color(0xFF16120F);
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
      case SabotageStickerKind.crown:
        final fill = Paint()..color = const Color(0xFFFFD400);
        final border = Paint()
          ..color = const Color(0xFF16120F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, unit * 0.08)
          ..strokeJoin = StrokeJoin.round;
        final path = Path()
          ..moveTo(-unit * 0.65, unit * 0.35)
          ..lineTo(-unit * 0.75, -unit * 0.3)
          ..lineTo(-unit * 0.3, unit * 0.02)
          ..lineTo(0, -unit * 0.48)
          ..lineTo(unit * 0.3, unit * 0.02)
          ..lineTo(unit * 0.75, -unit * 0.3)
          ..lineTo(unit * 0.65, unit * 0.35)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, border);
        final gem = Paint()..color = const Color(0xFFE53935);
        canvas.drawCircle(Offset(0, unit * 0.14), unit * 0.09, gem);
      case SabotageStickerKind.sunglasses:
        final dark = Paint()..color = const Color(0xFF16120F);
        final glare = Paint()
          ..color = Colors.white
          ..strokeWidth = math.max(1.5, unit * 0.07)
          ..strokeCap = StrokeCap.round;
        final leftLens = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(-unit * 0.42, 0),
            width: unit * 0.66,
            height: unit * 0.44,
          ),
          Radius.circular(unit * 0.08),
        );
        final rightLens = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(unit * 0.42, 0),
            width: unit * 0.66,
            height: unit * 0.44,
          ),
          Radius.circular(unit * 0.08),
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(0, -unit * 0.08),
            width: unit * 1.65,
            height: unit * 0.1,
          ),
          dark,
        );
        canvas.drawRRect(leftLens, dark);
        canvas.drawRRect(rightLens, dark);
        canvas.drawLine(
          Offset(-unit * 0.6, -unit * 0.12),
          Offset(-unit * 0.42, unit * 0.12),
          glare,
        );
        canvas.drawLine(
          Offset(unit * 0.24, -unit * 0.12),
          Offset(unit * 0.42, unit * 0.12),
          glare,
        );
      case SabotageStickerKind.censorBar:
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: unit * 1.9,
            height: unit * 0.56,
          ),
          Radius.circular(unit * 0.06),
        );
        canvas.drawRRect(rect, Paint()..color = const Color(0xFF16120F));
        final stripe = Paint()
          ..color = const Color(0xFFE53935)
          ..strokeWidth = math.max(1.5, unit * 0.07);
        canvas.drawLine(
          Offset(-unit * 0.72, 0),
          Offset(unit * 0.72, 0),
          stripe,
        );
      case SabotageStickerKind.heart:
        final fill = Paint()..color = const Color(0xFFE53935);
        final border = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, unit * 0.07);
        final path = Path()
          ..moveTo(0, unit * 0.48)
          ..cubicTo(
            -unit * 0.85,
            unit * 0.05,
            -unit * 0.72,
            -unit * 0.58,
            0,
            -unit * 0.14,
          )
          ..cubicTo(
            unit * 0.72,
            -unit * 0.58,
            unit * 0.85,
            unit * 0.05,
            0,
            unit * 0.48,
          )
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, border);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SabotageDrawingPainter oldDelegate) => true;
}
