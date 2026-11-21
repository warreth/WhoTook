import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/media/photo_service.dart';

void main() {
  test('stratified sampling takes one index from every full-history slice', () {
    for (var seed = 0; seed < 200; seed++) {
      final indices = stratifiedSampleIndices(120, 6, Random(seed));
      expect(indices, hasLength(6));
      expect(indices.toSet(), hasLength(6));
      for (var slice = 0; slice < 6; slice++) {
        final start = 120 * slice ~/ 6;
        final end = 120 * (slice + 1) ~/ 6;
        expect(indices[slice], inInclusiveRange(start, end - 1));
      }
    }
  });

  test('a smaller gallery yields every photo once', () {
    final indices = stratifiedSampleIndices(4, 6, Random(2));
    expect(indices, hasLength(4));
    expect(indices.toSet(), <int>{0, 1, 2, 3});
  });

  test('empty ranges and empty requests return nothing', () {
    expect(stratifiedSampleIndices(0, 6, Random(1)), isEmpty);
    expect(stratifiedSampleIndices(100, 0, Random(1)), isEmpty);
  });

  test('the oldest and newest slices are both reachable', () {
    final seen = <int>{};
    for (var seed = 0; seed < 500; seed++) {
      final indices = stratifiedSampleIndices(60, 3, Random(seed));
      if (indices.first < 20) seen.add(0);
      if (indices.last >= 40) seen.add(2);
    }
    expect(seen, <int>{0, 2});
  });
}
