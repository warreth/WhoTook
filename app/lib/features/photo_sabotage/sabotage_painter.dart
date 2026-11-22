import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/models.dart';

/// The five marker colours every sabotage player gets. The index travels on
/// the wire, so the palette is identical on every phone and on the Podium.
const List<Color> sabotageColors = <Color>[
  Color(0xFF16120F),
  Color(0xFFFFFFFF),
  Color(0xFFE53935),
  Color(0xFFFFD400),
  Color(0xFF39D353),
];

Color sabotageColor(int index) =>
    sabotageColors[index.clamp(0, sabotageColors.length - 1)];

/// Paints normalized marker strokes over a photo. Points are mapped to the
/// current canvas size, so an iPhone 8, a Pixel 8 Pro and an iPad show the
/// same drawing in the same place.
class SabotageDrawingPainter extends CustomPainter {
  SabotageDrawingPainter({required this.strokes, this.progress = 1.0});

  final List<SabotageStroke> strokes;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final totalPoints = strokes.fold<int>(
      0,
      (sum, stroke) => sum + stroke.points.length,
    );
    if (totalPoints == 0) return;
    var remaining = (totalPoints * progress.clamp(0.0, 1.0)).ceil();
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
  }

  @override
  bool shouldRepaint(covariant SabotageDrawingPainter oldDelegate) => true;
}
