import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/features/photo_sabotage/sabotage_stroke_utils.dart';

void main() {
  test('normalized strokes survive the wire roundtrip', () {
    final stroke = SabotageStroke(
      colorIndex: 3,
      width: 0.012,
      points: const <Offset>[
        Offset(0.1, 0.2),
        Offset(0.4, 0.5),
        Offset(0.8, 0.9),
      ],
    );
    final restored = SabotageStroke.fromJson(stroke.toJson());
    expect(restored.colorIndex, 3);
    expect(restored.width, closeTo(0.012, 0.0001));
    expect(restored.points, hasLength(3));
    expect(restored.points.first.dx, closeTo(0.1, 0.0001));
  });

  test('a long drawing stays under five kilobytes on the wire', () {
    final strokes = <SabotageStroke>[
      for (var stroke = 0; stroke < 6; stroke++)
        SabotageStroke(
          colorIndex: stroke % 5,
          width: 0.01,
          points: <Offset>[
            for (var i = 0; i < 180; i++)
              Offset(
                0.1 + 0.8 * (i / 180),
                0.2 + 0.6 * sin(i / 8 + stroke).abs(),
              ),
          ],
        ),
    ];
    final simplified = simplifySabotageStrokes(strokes);
    expect(simplified, hasLength(6));
    expect(
      simplified.fold<int>(0, (sum, stroke) => sum + stroke.points.length),
      lessThan(6 * 180),
    );
    expect(sabotagePayloadBytes(simplified), lessThan(5000));
    for (final stroke in simplified) {
      expect(stroke.points, isNotEmpty);
      for (final point in stroke.points) {
        expect(point.dx, inInclusiveRange(0, 1));
        expect(point.dy, inInclusiveRange(0, 1));
      }
    }
  });

  test('the worst case twelve-stroke scribble still fits five kilobytes', () {
    final strokes = <SabotageStroke>[
      for (var stroke = 0; stroke < 12; stroke++)
        SabotageStroke(
          colorIndex: stroke % 5,
          width: 0.012,
          points: <Offset>[
            for (var i = 0; i < 64; i++)
              Offset(
                0.05 + 0.9 * ((i * 37 + stroke * 11) % 64) / 64,
                0.05 + 0.9 * ((i * 53 + stroke * 7) % 64) / 64,
              ),
          ],
        ),
    ];
    final simplified = simplifySabotageStrokes(strokes);
    expect(simplified, isNotEmpty);
    expect(sabotagePayloadBytes(simplified), lessThan(5000));
  });

  test('the simplifier keeps endpoints and clamps stray points', () {
    final points = <Offset>[
      const Offset(-0.2, 0.2),
      const Offset(0.4, 0.4),
      const Offset(0.6, 0.6),
      const Offset(1.2, 0.8),
    ];
    final simplified = simplifySabotageStrokes(<SabotageStroke>[
      SabotageStroke(colorIndex: 0, width: 0.01, points: points),
    ]).single;
    expect(simplified.points.first.dx, 0);
    expect(simplified.points.last.dx, 1);
  });
}
