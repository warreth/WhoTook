import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/party_pass/room_theme.dart';

double _ratio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final high = l1 > l2 ? l1 : l2;
  final low = l1 > l2 ? l2 : l1;
  return (high + 0.05) / (low + 0.05);
}

void main() {
  test('wire ids are stable and unknown ids fall back safely', () {
    expect(RoomThemeId.values, hasLength(5));
    expect(RoomThemeId.classicParty.wireId, 'classic_party');
    expect(RoomThemeId.midnightArcade.wireId, 'midnight_arcade');
    expect(RoomThemeId.cyberNeon.wireId, 'cyber_neon');
    expect(RoomThemeId.retroPolaroid.wireId, 'retro_polaroid');
    expect(RoomThemeId.pubKroeg.wireId, 'pub_kroeg');
    expect(RoomThemeId.fromWire('nope'), RoomThemeId.classicParty);
    expect(RoomThemeId.fromWire(null), RoomThemeId.classicParty);
  });

  test('only Classic is free and the others own their brightness', () {
    expect(RoomThemeId.classicParty.premium, isFalse);
    expect(RoomThemeId.classicParty.forcedBrightness, isNull);
    for (final theme in RoomThemeId.values.where((value) => value.premium)) {
      expect(theme.forcedBrightness, isNotNull, reason: theme.wireId);
    }
  });

  test('every palette keeps readable text and button contrast', () {
    for (final theme in RoomThemeId.values) {
      final brightness = theme.forcedBrightness ?? Brightness.light;
      final palette = theme.palette(brightness);
      expect(
        _ratio(palette.ink, palette.bg),
        greaterThanOrEqualTo(4.5),
        reason: '${theme.wireId} ink on bg',
      );
      expect(
        _ratio(palette.ink, palette.card),
        greaterThanOrEqualTo(4.5),
        reason: '${theme.wireId} ink on card',
      );
      expect(
        _ratio(palette.onAccent, palette.accent),
        greaterThanOrEqualTo(4.5),
        reason: '${theme.wireId} onAccent on accent',
      );
      expect(
        _ratio(palette.onAccent2, palette.accent2),
        greaterThanOrEqualTo(4.5),
        reason: '${theme.wireId} onAccent2 on accent2',
      );
      expect(
        _ratio(palette.ink2, palette.card),
        greaterThanOrEqualTo(4.5),
        reason: '${theme.wireId} secondary text',
      );
    }
  });

  test('the premium palettes are visually distinct from Classic', () {
    final classic = RoomThemeId.classicParty.palette(Brightness.light);
    for (final theme in RoomThemeId.values.where((value) => value.premium)) {
      final palette = theme.palette(theme.forcedBrightness!);
      expect(palette.bg, isNot(classic.bg), reason: theme.wireId);
      expect(palette.accent, isNot(classic.accent), reason: theme.wireId);
    }
  });
}
