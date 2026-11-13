import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/theme/whotook_theme.dart';

void main() {
  group('WhoTookColors', () {
    test('light tokens match the Warm Contact Sheet palette', () {
      const c = WhoTookColors.light;
      expect(c.bg, const Color(0xFFF7F4EE));
      expect(c.card, const Color(0xFFFFFFFF));
      expect(c.raised, const Color(0xFFEFE9DF));
      expect(c.ink, const Color(0xFF1F1B16));
      expect(c.ink2, const Color(0xFF5E554A));
      expect(c.ink3, const Color(0xFF6E655A));
      expect(c.accent, const Color(0xFFC63D22));
      expect(c.onAccent, const Color(0xFFFFFFFF));
      expect(c.positive, const Color(0xFF15803D));
      expect(c.negative, const Color(0xFFB91C1C));
      expect(c.hairline, const Color(0x1A1F1B16));
    });

    test('dark tokens match the Darkroom Ink palette', () {
      const c = WhoTookColors.dark;
      expect(c.bg, const Color(0xFF161513));
      expect(c.card, const Color(0xFF1C1A18));
      expect(c.raised, const Color(0xFF262421));
      expect(c.ink, const Color(0xFFEFE9DE));
      expect(c.ink2, const Color(0xFFB4ADA1));
      expect(c.ink3, const Color(0xFF989186));
      expect(c.accent, const Color(0xFFE59437));
      expect(c.onAccent, const Color(0xFF161513));
      expect(c.positive, const Color(0xFF4CC38A));
      expect(c.negative, const Color(0xFFF06A6E));
      expect(c.hairline, const Color(0x1AEFE9DE));
    });

    test('copyWith and lerp keep every token', () {
      final copy = WhoTookColors.light.copyWith(
        accent: const Color(0xFF000000),
      );
      expect(copy.accent, const Color(0xFF000000));
      expect(copy.bg, WhoTookColors.light.bg);

      final mid = WhoTookColors.light.lerp(WhoTookColors.dark, 0.5);
      expect(
        mid.bg,
        Color.lerp(WhoTookColors.light.bg, WhoTookColors.dark.bg, 0.5),
      );
      expect(WhoTookColors.light.lerp(null, 0.5).bg, WhoTookColors.light.bg);
    });
  });

  test('spacing and radii follow the 4px grid and nested radius rule', () {
    expect(AppSpacing.s4, 4);
    expect(AppSpacing.s8, 8);
    expect(AppSpacing.s12, 12);
    expect(AppSpacing.s16, 16);
    expect(AppSpacing.s20, 20);
    expect(AppSpacing.s24, 24);
    expect(AppSpacing.s32, 32);
    expect(AppRadii.rSm, 6);
    expect(AppRadii.rControl, 12);
    expect(AppRadii.rCard, 14);
    expect(AppRadii.rModal, 16);
    expect(AppRadii.rSm, lessThan(AppRadii.rCard));
  });

  test('tabular figures helper sets the font feature', () {
    final style = tabularFigures(const TextStyle(fontSize: 14));
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(style.fontSize, 14);
  });

  testWidgets('buildWhoTookTheme exposes the extension on both brightnesses', (
    tester,
  ) async {
    late WhoTookColors seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildWhoTookTheme(Brightness.light),
        home: Builder(
          builder: (context) {
            seen = WhoTookColors.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen.accent, WhoTookColors.light.accent);

    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('dark'),
        theme: buildWhoTookTheme(Brightness.dark),
        home: Builder(
          builder: (context) {
            seen = WhoTookColors.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen.accent, WhoTookColors.dark.accent);
  });

  testWidgets('WhoTookMark paints without overflow at several sizes', (
    tester,
  ) async {
    for (final size in <double>[16, 48, 120]) {
      await tester.pumpWidget(
        Center(
          child: WhoTookMark(size: size, color: const Color(0xFF1F1B16)),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(WhoTookMark), findsOneWidget);
    }
  });

  testWidgets('CropFrameOverlay fills its parent and ignores pointers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 200,
          height: 260,
          child: CropFrameOverlay(color: Color(0xFF1F1B16)),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(IgnorePointer), findsOneWidget);
  });
}
