import 'dart:convert';
import 'dart:ui' show Offset;

import '../../core/models/models.dart';

/// Keeps a freehand stroke light enough for the wire. Ramer-Douglas-Peucker
/// removes collinear points, then the result is capped so a long scribble
/// cannot balloon the JSON payload.
List<Offset> simplifySabotagePoints(
  List<Offset> points, {
  double epsilon = 0.003,
  int maxPoints = 64,
}) {
  if (points.length <= 2) return List<Offset>.of(points);
  final simplified = _rdp(points, 0, points.length - 1, epsilon);
  if (simplified.length <= maxPoints) return simplified;
  final step = simplified.length / maxPoints;
  return <Offset>[
    for (var i = 0; i < maxPoints; i++)
      simplified[(i * step).floor().clamp(0, simplified.length - 1)],
    simplified.last,
  ];
}

List<Offset> _rdp(List<Offset> points, int first, int last, double epsilon) {
  if (last <= first + 1) return <Offset>[points[first], points[last]];
  final start = points[first];
  final end = points[last];
  var maxDistance = 0.0;
  var split = first;
  for (var i = first + 1; i < last; i++) {
    final distance = _distanceToSegment(points[i], start, end);
    if (distance > maxDistance) {
      maxDistance = distance;
      split = i;
    }
  }
  if (maxDistance <= epsilon) return <Offset>[start, end];
  final left = _rdp(points, first, split, epsilon);
  final right = _rdp(points, split, last, epsilon);
  return <Offset>[...left, ...right.skip(1)];
}

double _distanceToSegment(Offset point, Offset start, Offset end) {
  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) {
    return (point - start).distance;
  }
  final t =
      (((point.dx - start.dx) * dx + (point.dy - start.dy) * dy) /
              lengthSquared)
          .clamp(0.0, 1.0);
  final closest = Offset(start.dx + t * dx, start.dy + t * dy);
  return (point - closest).distance;
}

/// Hard ceiling for one sabotage submission. The wire carries only strokes,
/// but a very determined scribbler still must not push the JSON past this.
const int sabotageMaxPayloadBytes = 5000;

/// Normalizes and simplifies every local stroke before it is submitted.
List<SabotageStroke> simplifySabotageStrokes(
  List<SabotageStroke> strokes, {
  int maxStrokes = 12,
  int maxPoints = 64,
}) {
  final result = <SabotageStroke>[];
  for (final stroke in strokes.take(maxStrokes)) {
    final points = simplifySabotagePoints(
      stroke.points
          .map(
            (point) =>
                Offset(point.dx.clamp(0.0, 1.0), point.dy.clamp(0.0, 1.0)),
          )
          .toList(),
      maxPoints: maxPoints,
    );
    if (points.length < 2) continue;
    result.add(
      SabotageStroke(
        colorIndex: stroke.colorIndex,
        width: stroke.width.clamp(0.003, 0.04),
        points: points,
      ),
    );
  }
  return _fitSabotagePayload(result);
}

/// Trims the drawing until its real UTF-8 JSON fits the five kilobyte budget.
/// Strokes are dropped from the oldest end first, then the longest stroke is
/// halved, so the most recent marks survive.
List<SabotageStroke> _fitSabotagePayload(List<SabotageStroke> strokes) {
  final current = List<SabotageStroke>.of(strokes);
  while (current.isNotEmpty &&
      sabotagePayloadBytes(current) > sabotageMaxPayloadBytes) {
    if (current.length > 6) {
      current.removeAt(0);
      continue;
    }
    var longest = 0;
    for (var i = 1; i < current.length; i++) {
      if (current[i].points.length > current[longest].points.length) {
        longest = i;
      }
    }
    final points = current[longest].points;
    if (points.length <= 2) {
      if (current.length == 1) break;
      current.removeAt(longest);
      continue;
    }
    final reduced = <Offset>[
      for (var i = 0; i < points.length; i += 2) points[i],
    ];
    if (reduced.last != points.last) reduced.add(points.last);
    current[longest] = SabotageStroke(
      colorIndex: current[longest].colorIndex,
      width: current[longest].width,
      points: reduced,
    );
  }
  return List<SabotageStroke>.unmodifiable(current);
}

/// Real UTF-8 JSON size of the sabotage payload, used by the unit test and
/// the editor's pre-send guard.
int sabotagePayloadBytes(List<SabotageStroke> strokes) {
  final json = <String, dynamic>{
    'sabotage': true,
    'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
  };
  return utf8.encode(jsonEncode(json)).length;
}

/// Largest distance is kept exported for tests that want to assert sampling.
double sabotageStrokeLength(List<Offset> points) {
  if (points.length < 2) return 0;
  var length = 0.0;
  for (var i = 1; i < points.length; i++) {
    length += (points[i] - points[i - 1]).distance;
  }
  return length;
}
