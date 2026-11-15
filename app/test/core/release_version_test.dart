import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/constants.dart';

void main() {
  test('the version reported to rooms matches pubspec', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((line) => line.startsWith('version:'));
    final value = line.substring('version:'.length).trim();
    final parts = value.split('+');
    expect(parts, hasLength(2));
    expect(parts.first, kAppVersion);
    expect(int.parse(parts.last), kAppBuildNumber);
  });
}
