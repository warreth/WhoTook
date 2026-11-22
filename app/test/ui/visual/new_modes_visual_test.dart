import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/storage/settings_repository.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/state/providers.dart';
import 'package:whotook/ui/screens/setup/mode_setup_screen.dart';

import '../../support/fonts.dart';
import '../../support/test_photo_library.dart';

/// Run only when the visual check is asked for:
///   flutter test test/ui/visual/new_modes_visual_test.dart \
///     --dart-define=VISUAL_UPDATE=true --update-goldens
///
/// The PNGs land in .private_prototypes/visual and stay out of git.
const bool _visual = bool.fromEnvironment('VISUAL_UPDATE');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await loadTestFonts();
  });

  for (final size in const <Size>[Size(375, 667), Size(412, 915)]) {
    testWidgets('choose the game and mixed selector at ${size.width.toInt()}', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = size;
      view.devicePixelRatio = 1;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final coordinator = MatchCoordinator(
        photos: TestPhotoLibrary(),
        settings: SettingsRepository(),
      );
      addTearDown(coordinator.dispose);
      final state = MatchUiState(
        config: const MatchConfig(
          mode: GameMode.mixedParty,
          enabledMixedModes: MatchConfig.coreMixedModes,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matchCoordinatorProvider.overrideWithValue(coordinator),
            matchStateProvider.overrideWith(
              (ref) => Stream<MatchUiState>.value(state),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('nl'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildWhoTookTheme(Brightness.light),
            home: const ModeSetupScreen(),
          ),
        ),
      );
      await tester.pump();
      final suffix = size.width.toInt();

      await expectLater(
        find.byType(ModeSetupScreen),
        matchesGoldenFile(
          '../../../../.private_prototypes/visual/choose-mixed-$suffix.png',
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -260));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(ModeSetupScreen),
        matchesGoldenFile(
          '../../../../.private_prototypes/visual/mixed-selector-$suffix.png',
        ),
      );
    }, skip: !_visual);
  }
}
