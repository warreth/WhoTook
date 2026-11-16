import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/build_flavor.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/storage/last_room_repository.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/state/providers.dart';
import 'package:whotook/ui/screens/advanced_settings_screen.dart';
import 'package:whotook/ui/screens/home_screen.dart';
import 'package:whotook/ui/screens/lobby_screen.dart';
import 'package:whotook/ui/screens/meme_screen.dart';
import 'package:whotook/ui/screens/onboarding_screen.dart';
import 'package:whotook/ui/screens/podium_screen.dart';
import 'package:whotook/ui/screens/prepare_screen.dart';
import 'package:whotook/ui/screens/round_screen.dart';
import 'package:whotook/ui/screens/settings_screen.dart';
import 'package:whotook/ui/screens/timeline_screen.dart';
import 'package:whotook/ui/screens/setup/mode_setup_screen.dart';
import 'package:whotook/ui/screens/setup/rounds_setup_screen.dart';
import 'package:whotook/ui/screens/setup/speed_setup_screen.dart';
import 'package:whotook/ui/widgets/version_warning_card.dart';

import '../support/test_photo_library.dart';

/// Store captures are opt-in because they are large and only needed when the
/// listing screenshots change. Run them with:
///   flutter test test/ui/screens_golden_test.dart --update-goldens \
///     --dart-define=STORE_SCREENSHOTS=true --plain-name "store"
const bool _storeScreenshots = bool.fromEnvironment('STORE_SCREENSHOTS');

/// Renders every screen at phone size so the layout can be checked visually and
/// changes are caught by the golden diff.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await _loadFonts();
  });

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('home', (tester) async {
    await _precacheHomePhotos(tester);
    await _pump(tester, const HomeScreen(), _settings());
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home.png'),
    );
  });

  testWidgets('home last room', (tester) async {
    await _precacheHomePhotos(tester);
    await LastRoomRepository().remember(
      LastRoom(
        inviteUrl: 'https://whotook.party/j#abc',
        roomId: 'k8m2p9x4',
        playerId: 'p_test',
        playerToken: 'token_test',
        joinedAtUtc: DateTime.now().toUtc(),
      ),
    );
    await _pump(tester, const HomeScreen(), _settings());
    expect(find.text('Last room'), findsOneWidget);
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home-last-room.png'),
    );
    await LastRoomRepository().forget();
  });

  testWidgets('onboarding', (tester) async {
    await _pump(tester, const OnboardingScreen(), _settings());
    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('goldens/onboarding.png'),
    );
  });

  testWidgets('version warning', (tester) async {
    await _precacheHomePhotos(tester);
    await _pump(tester, const _VersionWarningPreview(), _settings());
    expect(find.text('Different app versions'), findsOneWidget);
    await expectLater(
      find.byType(_VersionWarningPreview),
      matchesGoldenFile('goldens/version-warning.png'),
    );
  });

  testWidgets('lobby', (tester) async {
    if (BuildFlavor.foss) return;
    await _pump(tester, const LobbyScreen(), _settings(), state: _lobbyState());
    await expectLater(
      find.byType(LobbyScreen),
      matchesGoldenFile('goldens/lobby.png'),
    );
  });

  testWidgets('online lobby shows the Wi-Fi hint', (tester) async {
    await _pump(
      tester,
      const LobbyScreen(),
      _settings(),
      state: _onlineLobbyState(),
    );
    expect(
      find.text(
        'If everyone joins the same Wi-Fi, it is faster and your photos stay on your network.',
      ),
      findsOneWidget,
    );
    await expectLater(
      find.byType(LobbyScreen),
      matchesGoldenFile('goldens/lobby-online.png'),
    );
  });

  testWidgets('online lobby dismisses the Wi-Fi hint', (tester) async {
    await _pump(
      tester,
      const LobbyScreen(),
      _settings(),
      state: _onlineLobbyState(),
    );
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'If everyone joins the same Wi-Fi, it is faster and your photos stay on your network.',
      ),
      findsNothing,
    );
  });

  testWidgets('prepare', (tester) async {
    final photos = _fixturePhotos();
    for (final photo in photos) {
      await _precachePhoto(tester, photo);
    }
    await _pump(
      tester,
      const PrepareScreen(),
      _settings(),
      state: _prepareState(photos),
    );
    await expectLater(
      find.byType(PrepareScreen),
      matchesGoldenFile('goldens/prepare.png'),
    );
  });

  testWidgets('prepare short set', (tester) async {
    final photos = _fixturePhotos();
    for (final photo in photos) {
      await _precachePhoto(tester, photo);
    }
    await _pump(
      tester,
      const PrepareScreen(),
      _settings(),
      state: _prepareState(photos, count: 2, needed: 4),
    );
    expect(find.textContaining('Only 2 usable photos'), findsOneWidget);
    await expectLater(
      find.byType(PrepareScreen),
      matchesGoldenFile('goldens/prepare-short.png'),
    );
  });

  testWidgets('prepare full set', (tester) async {
    final photos = _fixturePhotos();
    for (final photo in photos) {
      await _precachePhoto(tester, photo);
    }
    await _pump(
      tester,
      const PrepareScreen(),
      _settings(),
      state: _prepareState(photos, count: 16, needed: 16),
    );
    await expectLater(
      find.byType(PrepareScreen),
      matchesGoldenFile('goldens/prepare-full-set.png'),
    );
  });

  testWidgets('prepare six photo vault', (tester) async {
    final photos = _fixturePhotos();
    for (final photo in photos) {
      await _precachePhoto(tester, photo);
    }
    await _pump(
      tester,
      const PrepareScreen(),
      _settings(),
      state: _prepareState(_fixturePhotosSix(), count: 6, needed: 6).copyWith(
        config: const MatchConfig(
          roundsK: 5,
          roundSeconds: 90,
          mode: GameMode.makeItMeme,
        ),
      ),
    );
    await _settleImages(tester);
    await expectLater(
      find.byType(PrepareScreen),
      matchesGoldenFile('goldens/prepare-six.png'),
    );
  });

  testWidgets('round', (tester) async {
    final photo = _fixturePhoto('party-dog');
    await _precachePhoto(tester, photo);
    await _pump(
      tester,
      const RoundScreen(),
      _settings(),
      state: _roundState(photo),
    );
    await expectLater(
      find.byType(RoundScreen),
      matchesGoldenFile('goldens/round.png'),
    );
  });

  testWidgets('rounds setup', (tester) async {
    await _pump(
      tester,
      const RoundsSetupScreen(),
      _settings(),
      state: _setupState(),
    );
    await expectLater(
      find.byType(RoundsSetupScreen),
      matchesGoldenFile('goldens/rounds-setup.png'),
    );
  });

  testWidgets('speed setup', (tester) async {
    await _pump(
      tester,
      const SpeedSetupScreen(),
      _settings(),
      state: _setupState(),
    );
    await expectLater(
      find.byType(SpeedSetupScreen),
      matchesGoldenFile('goldens/speed-setup.png'),
    );
  });

  testWidgets('mode setup', (tester) async {
    await _pump(
      tester,
      const ModeSetupScreen(),
      _settings(),
      state: _setupState(mode: GameMode.makeItMeme),
    );
    await expectLater(
      find.byType(ModeSetupScreen),
      matchesGoldenFile('goldens/mode-setup.png'),
    );
  });

  testWidgets('settings', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith(() => _FixedSettings(_settings())),
          photoLibraryProvider.overrideWithValue(TestPhotoLibrary()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          theme: buildWhoTookTheme(Brightness.light),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings.png'),
    );
  });

  testWidgets('advanced settings', (tester) async {
    await _pump(tester, const AdvancedSettingsScreen(), _settings());
    await expectLater(
      find.byType(AdvancedSettingsScreen),
      matchesGoldenFile('goldens/advanced-settings.png'),
    );
  });

  testWidgets('podium', (tester) async {
    await _pump(
      tester,
      const PodiumScreen(),
      _settings(),
      state: _podiumState(),
    );
    await expectLater(
      find.byType(PodiumScreen),
      matchesGoldenFile('goldens/podium.png'),
    );
  });

  testWidgets('make it meme editor', (tester) async {
    final photo = _fixturePhoto('party-dog');
    await _precachePhoto(tester, photo);
    await _pump(
      tester,
      const MemeScreen(),
      _settings(),
      state: _memeEditorState(photo),
    );
    await _settleImages(tester);
    await expectLater(
      find.byType(MemeScreen),
      matchesGoldenFile('goldens/meme-editor.png'),
    );
  });

  testWidgets('make it meme vote', (tester) async {
    final photo = _fixturePhoto('party-cat');
    await _precachePhoto(tester, photo);
    await _pump(
      tester,
      const MemeScreen(),
      _settings(),
      state: _memeVoteState(photo),
    );
    await _settleImages(tester);
    await expectLater(
      find.byType(MemeScreen),
      matchesGoldenFile('goldens/meme-vote.png'),
    );
  });

  testWidgets('make it meme reveal', (tester) async {
    final photo = _fixturePhoto('party-hamster');
    await _precachePhoto(tester, photo);
    await _pump(
      tester,
      const MemeScreen(),
      _settings(),
      state: _memeRevealState(photo),
    );
    await _settleImages(tester);
    await expectLater(
      find.byType(MemeScreen),
      matchesGoldenFile('goldens/meme-reveal.png'),
    );
  });

  testWidgets('podium with top memes', (tester) async {
    final photo = _fixturePhoto('party-dog');
    await _precachePhoto(tester, photo);
    final meme = MemeCard(
      id: 'meme-top',
      photoBase64: base64Encode(photo),
      template: MemeTemplate.classic,
      topText: 'When the cake hits the floor',
      bottomText: 'and nobody brought a fork',
      snapY: 48,
      authorName: 'Lotte',
      points: 300,
      isWinner: true,
    );
    await _pump(
      tester,
      const PodiumScreen(),
      _settings(),
      state: _podiumState().copyWith(topMemes: <MemeCard>[meme]),
    );
    await _settleImages(tester);
    await expectLater(
      find.byType(PodiumScreen),
      matchesGoldenFile('goldens/podium-memes.png'),
    );
  });

  testWidgets('dark home', (tester) async {
    await _precacheHomePhotos(tester);
    await _pump(
      tester,
      const HomeScreen(),
      _settings(),
      brightness: Brightness.dark,
    );
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/dark-home.png'),
    );
  });

  testWidgets('dark lobby', (tester) async {
    if (BuildFlavor.foss) return;
    await _pump(
      tester,
      const LobbyScreen(),
      _settings(),
      state: _lobbyState(),
      brightness: Brightness.dark,
    );
    await expectLater(
      find.byType(LobbyScreen),
      matchesGoldenFile('goldens/dark-lobby.png'),
    );
  });

  testWidgets('dark meme editor', (tester) async {
    final photo = _fixturePhoto('party-dog');
    await _precachePhoto(tester, photo);
    await _pump(
      tester,
      const MemeScreen(),
      _settings(),
      state: _memeEditorState(photo),
      brightness: Brightness.dark,
    );
    await _settleImages(tester);
    await expectLater(
      find.byType(MemeScreen),
      matchesGoldenFile('goldens/dark-meme-editor.png'),
    );
  });

  testWidgets('dark meme vote', (tester) async {
    final photo = _fixturePhoto('party-cat');
    await _precachePhoto(tester, photo);
    await _pump(
      tester,
      const MemeScreen(),
      _settings(),
      state: _memeVoteState(photo),
      brightness: Brightness.dark,
    );
    await _settleImages(tester);
    await expectLater(
      find.byType(MemeScreen),
      matchesGoldenFile('goldens/dark-meme-vote.png'),
    );
  });

  testWidgets('dark timeline reveal', (tester) async {
    final photo = _fixturePhoto('party-hamster');
    await _precachePhoto(tester, photo);
    await _pump(
      tester,
      const TimelineScreen(),
      _settings(),
      state: _timelineRevealState(photo),
      brightness: Brightness.dark,
    );
    await expectLater(
      find.byType(TimelineScreen),
      matchesGoldenFile('goldens/dark-timeline-reveal.png'),
    );
  });

  testWidgets('dark podium with top memes', (tester) async {
    final photo = _fixturePhoto('party-dog');
    await _precachePhoto(tester, photo);
    final meme = MemeCard(
      id: 'meme-top',
      photoBase64: base64Encode(photo),
      template: MemeTemplate.classic,
      topText: 'When the cake hits the floor',
      bottomText: 'and nobody brought a fork',
      snapY: 48,
      authorName: 'Lotte',
      points: 300,
      isWinner: true,
    );
    await _pump(
      tester,
      const PodiumScreen(),
      _settings(),
      state: _podiumState().copyWith(topMemes: <MemeCard>[meme]),
      brightness: Brightness.dark,
    );
    await _settleImages(tester);
    await expectLater(
      find.byType(PodiumScreen),
      matchesGoldenFile('goldens/dark-podium.png'),
    );
  });

  testWidgets('dark mode setup', (tester) async {
    await _pump(
      tester,
      const ModeSetupScreen(),
      _settings(),
      state: _setupState(mode: GameMode.makeItMeme),
      brightness: Brightness.dark,
    );
    await expectLater(
      find.byType(ModeSetupScreen),
      matchesGoldenFile('goldens/dark-mode-setup.png'),
    );
  });

  testWidgets('dark lobby with meme mode', (tester) async {
    if (BuildFlavor.foss) return;
    await _pump(
      tester,
      const LobbyScreen(),
      _settings(),
      state: _lobbyState().copyWith(
        config: const MatchConfig(
          roundsK: 10,
          roundSeconds: 8,
          mode: GameMode.makeItMeme,
        ),
      ),
      brightness: Brightness.dark,
    );
    await expectLater(
      find.byType(LobbyScreen),
      matchesGoldenFile('goldens/dark-lobby-meme.png'),
    );
  });

  testWidgets('dark meme reveal', (tester) async {
    final photo = _fixturePhoto('party-hamster');
    await _precachePhoto(tester, photo);
    await _pump(
      tester,
      const MemeScreen(),
      _settings(),
      state: _memeRevealState(photo),
      brightness: Brightness.dark,
    );
    await _settleImages(tester);
    await expectLater(
      find.byType(MemeScreen),
      matchesGoldenFile('goldens/dark-meme-reveal.png'),
    );
  });

  testWidgets('large text keeps the party screens usable', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final photo = _fixturePhoto('party-dog');
    await _precacheHomePhotos(tester);
    await _precachePhoto(tester, photo);

    await _pump(tester, const HomeScreen(), _settings());
    expect(tester.takeException(), isNull);

    await _pump(
      tester,
      const ModeSetupScreen(),
      _settings(),
      state: _setupState(mode: GameMode.makeItMeme),
    );
    expect(tester.takeException(), isNull);

    await _pump(
      tester,
      const MemeScreen(),
      _settings(),
      state: _memeEditorState(photo),
    );
    expect(tester.takeException(), isNull);

    await _pump(
      tester,
      const MemeScreen(),
      _settings(),
      state: _memeVoteState(photo),
    );
    expect(tester.takeException(), isNull);

    await _pump(
      tester,
      const TimelineScreen(),
      _settings(),
      state: _timelineRevealState(photo),
    );
    expect(tester.takeException(), isNull);

    await _pump(tester, const LobbyScreen(), _settings(), state: _lobbyState());
    expect(tester.takeException(), isNull);

    await _pump(
      tester,
      const PrepareScreen(),
      _settings(),
      state: _prepareState(_fixturePhotosSix(), count: 6, needed: 6),
    );
    expect(tester.takeException(), isNull);

    await _pump(
      tester,
      const PodiumScreen(),
      _settings(),
      state: _podiumState(),
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dutch home fits', (tester) async {
    await _precacheHomePhotos(tester);
    await _pump(
      tester,
      const HomeScreen(),
      _settings(),
      locale: const Locale('nl'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dutch onboarding fits', (tester) async {
    await _pump(
      tester,
      const OnboardingScreen(),
      _settings(),
      locale: const Locale('nl'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dutch lobby fits', (tester) async {
    await _pump(
      tester,
      const LobbyScreen(),
      _settings(),
      state: _lobbyState(),
      locale: const Locale('nl'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dutch online lobby fits', (tester) async {
    await _pump(
      tester,
      const LobbyScreen(),
      _settings(),
      state: _onlineLobbyState(),
      locale: const Locale('nl'),
    );
    expect(
      find.text(
        "Als iedereen op dezelfde wifi zit, is het sneller en blijven je foto's op je netwerk.",
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dutch prepare fits', (tester) async {
    final photos = _fixturePhotos();
    for (final photo in photos) {
      await _precachePhoto(tester, photo);
    }
    await _pump(
      tester,
      const PrepareScreen(),
      _settings(),
      state: _prepareState(photos),
      locale: const Locale('nl'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dutch round fits', (tester) async {
    final photo = _fixturePhoto('party-dog');
    await _precachePhoto(tester, photo);
    await _pump(
      tester,
      const RoundScreen(),
      _settings(),
      state: _roundState(photo),
      locale: const Locale('nl'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dutch podium fits', (tester) async {
    await _pump(
      tester,
      const PodiumScreen(),
      _settings(),
      state: _podiumState(),
      locale: const Locale('nl'),
    );
    await tester.pump(const Duration(milliseconds: 850));
    expect(tester.takeException(), isNull);
  });

  testWidgets('store play screenshots', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
    final dog = _fixturePhoto('party-dog');
    final cat = _fixturePhoto('party-cat');
    final hamster = _fixturePhoto('party-hamster');
    await _precacheHomePhotos(tester);
    await _precachePhoto(tester, dog);
    await _precachePhoto(tester, cat);
    await _precachePhoto(tester, hamster);

    await _pump(tester, const HomeScreen(), _settings());
    await _settleImages(tester);
    await _storeShot(tester, find.byType(HomeScreen), 'play-01-home.png', 3);

    await _pump(
      tester,
      const ModeSetupScreen(),
      _settings(),
      state: _setupState(mode: GameMode.makeItMeme),
    );
    await _storeShot(
      tester,
      find.byType(ModeSetupScreen),
      'play-02-modes.png',
      3,
    );

    await _pump(
      tester,
      const MemeScreen(),
      _settings(),
      state: _memeEditorState(dog),
    );
    await _settleImages(tester);
    await _storeShot(
      tester,
      find.byType(MemeScreen),
      'play-03-meme-editor.png',
      3,
    );

    await _pump(
      tester,
      const MemeScreen(),
      _settings(),
      state: _memeVoteState(cat),
    );
    await _settleImages(tester);
    await _storeShot(
      tester,
      find.byType(MemeScreen),
      'play-04-meme-vote.png',
      3,
    );

    await _pump(
      tester,
      const TimelineScreen(),
      _settings(),
      state: _timelineRevealState(hamster),
    );
    await _settleImages(tester);
    await _storeShot(
      tester,
      find.byType(TimelineScreen),
      'play-05-timeline.png',
      3,
    );

    await _pumpWidget(
      tester,
      const PodiumScreen(),
      _settings(),
      state: _podiumState(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await _storeShot(
      tester,
      find.byType(PodiumScreen),
      'play-06-podium.png',
      3,
    );
  }, skip: !_storeScreenshots);

  testWidgets('store iphone screenshots', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = const Size(440, 956);
    view.devicePixelRatio = 1;
    final dog = _fixturePhoto('party-dog');
    final cat = _fixturePhoto('party-cat');
    final hamster = _fixturePhoto('party-hamster');
    await _precacheHomePhotos(tester);
    await _precachePhoto(tester, dog);
    await _precachePhoto(tester, cat);
    await _precachePhoto(tester, hamster);

    await _pump(tester, const HomeScreen(), _settings());
    await _settleImages(tester);
    await _storeShot(tester, find.byType(HomeScreen), 'iphone-01-home.png', 3);

    await _pump(
      tester,
      const ModeSetupScreen(),
      _settings(),
      state: _setupState(mode: GameMode.makeItMeme),
    );
    await _storeShot(
      tester,
      find.byType(ModeSetupScreen),
      'iphone-02-modes.png',
      3,
    );

    await _pump(
      tester,
      const MemeScreen(),
      _settings(),
      state: _memeEditorState(dog),
    );
    await _settleImages(tester);
    await _storeShot(
      tester,
      find.byType(MemeScreen),
      'iphone-03-meme-editor.png',
      3,
    );

    await _pump(
      tester,
      const MemeScreen(),
      _settings(),
      state: _memeVoteState(cat),
    );
    await _settleImages(tester);
    await _storeShot(
      tester,
      find.byType(MemeScreen),
      'iphone-04-meme-vote.png',
      3,
    );

    await _pump(
      tester,
      const TimelineScreen(),
      _settings(),
      state: _timelineRevealState(hamster),
    );
    await _settleImages(tester);
    await _storeShot(
      tester,
      find.byType(TimelineScreen),
      'iphone-05-timeline.png',
      3,
    );

    await _pumpWidget(
      tester,
      const PodiumScreen(),
      _settings(),
      state: _podiumState(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await _storeShot(
      tester,
      find.byType(PodiumScreen),
      'iphone-06-podium.png',
      3,
    );
  }, skip: !_storeScreenshots);

  testWidgets('store ipad screenshots', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = const Size(1032, 1376);
    view.devicePixelRatio = 1;
    final photos = _fixturePhotosSix();
    final dog = _fixturePhoto('party-dog');
    final hamster = _fixturePhoto('party-hamster');
    await _precacheHomePhotos(tester);
    for (final photo in photos) {
      await _precachePhoto(tester, photo);
    }
    await _precachePhoto(tester, dog);
    await _precachePhoto(tester, hamster);

    await _pump(tester, const HomeScreen(), _settings());
    await _settleImages(tester);
    await _storeShot(tester, find.byType(HomeScreen), 'ipad-01-home.png', 2);

    await _pump(
      tester,
      const PrepareScreen(),
      _settings(),
      state: _prepareState(_fixturePhotosSix(), count: 6, needed: 6).copyWith(
        config: const MatchConfig(
          roundsK: 5,
          roundSeconds: 90,
          mode: GameMode.makeItMeme,
        ),
      ),
    );
    await _settleImages(tester);
    await _storeShot(
      tester,
      find.byType(PrepareScreen),
      'ipad-02-vault.png',
      2,
    );

    await _pump(
      tester,
      const MemeScreen(),
      _settings(),
      state: _memeEditorState(dog),
    );
    await _settleImages(tester);
    await _storeShot(
      tester,
      find.byType(MemeScreen),
      'ipad-03-meme-editor.png',
      2,
    );

    await _pump(tester, const LobbyScreen(), _settings(), state: _lobbyState());
    await _storeShot(tester, find.byType(LobbyScreen), 'ipad-04-lobby.png', 2);

    await _pump(
      tester,
      const TimelineScreen(),
      _settings(),
      state: _timelineRevealState(hamster),
    );
    await _settleImages(tester);
    await _storeShot(
      tester,
      find.byType(TimelineScreen),
      'ipad-05-timeline.png',
      2,
    );

    await _pumpWidget(
      tester,
      const PodiumScreen(),
      _settings(),
      state: _podiumState(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await _storeShot(
      tester,
      find.byType(PodiumScreen),
      'ipad-06-podium.png',
      2,
    );
  }, skip: !_storeScreenshots);

  testWidgets('marketing round', (tester) async {
    _retina(tester);
    final photo = _fixturePhoto('party-dog');
    await _precachePhoto(tester, photo);
    await _pump(
      tester,
      const RoundScreen(),
      _settings(),
      state: _roundState(photo),
    );
    await expectLater(
      find.byType(RoundScreen),
      matchesGoldenFile('marketing/round.png'),
    );
  });

  testWidgets('marketing prepare', (tester) async {
    _retina(tester);
    final photos = _fixturePhotos();
    for (final photo in photos) {
      await _precachePhoto(tester, photo);
    }
    await _pump(
      tester,
      const PrepareScreen(),
      _settings(),
      state: _prepareState(photos),
    );
    await expectLater(
      find.byType(PrepareScreen),
      matchesGoldenFile('marketing/prepare.png'),
    );
  });

  testWidgets('marketing lobby', (tester) async {
    if (BuildFlavor.foss) return;
    _retina(tester);
    await _pump(tester, const LobbyScreen(), _settings(), state: _lobbyState());
    await expectLater(
      find.byType(LobbyScreen),
      matchesGoldenFile('marketing/lobby.png'),
    );
  });

  testWidgets('marketing home', (tester) async {
    _retina(tester);
    await _precacheHomePhotos(tester);
    await _pump(tester, const HomeScreen(), _settings());
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('marketing/home.png'),
    );
  });

  testWidgets('marketing round reveal', (tester) async {
    final photo = _fixturePhoto('party-dog');
    await _precachePhoto(tester, photo);
    await _pump(
      tester,
      const RoundScreen(),
      _settings(),
      state: _classicRevealState(photo),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await expectLater(
      find.byType(RoundScreen),
      matchesGoldenFile('marketing/round-reveal.png'),
    );
  });

  testWidgets('marketing podium', (tester) async {
    _retina(tester);
    await _pumpWidget(
      tester,
      const PodiumScreen(),
      _settings(),
      state: _podiumState(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 850));
    await expectLater(
      find.byType(PodiumScreen),
      matchesGoldenFile('marketing/podium.png'),
    );
  });
}

class _VersionWarningPreview extends StatelessWidget {
  const _VersionWarningPreview();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const HomeScreen(),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  VersionWarningCard(
                    warning: const VersionWarning(
                      latestVersion: '1.7.0',
                      latestBuild: 11,
                      ownVersion: '1.6.0',
                      ownBuild: 10,
                    ),
                    onDismiss: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _storeShot(
  WidgetTester tester,
  Finder finder,
  String name,
  double pixelRatio,
) async {
  final element = finder.evaluate().single;
  RenderObject renderObject = element.renderObject!;
  while (!renderObject.isRepaintBoundary) {
    renderObject = renderObject.parent!;
  }
  final layer = renderObject.debugLayer! as OffsetLayer;
  final data = await tester.binding.runAsync(() async {
    final image = await layer.toImage(
      renderObject.paintBounds,
      pixelRatio: pixelRatio,
    );
    try {
      return await image.toByteData(format: ui.ImageByteFormat.png);
    } finally {
      image.dispose();
    }
  });
  if (data == null) {
    throw StateError('Could not encode $name');
  }
  Directory('test/ui/store_raw').createSync(recursive: true);
  File('test/ui/store_raw/$name').writeAsBytesSync(data.buffer.asUint8List());
  // Drop the tree so the next screen gets a fresh ProviderScope instead of
  // keeping the first screen's stream value.
  await tester.pumpWidget(const SizedBox.shrink());
}

void _retina(WidgetTester tester) {
  final view =
      TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
  view.physicalSize = const Size(780, 1688);
  view.devicePixelRatio = 2;
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  AppSettings settings, {
  MatchUiState? state,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
}) async {
  await _pumpWidget(
    tester,
    screen,
    settings,
    state: state,
    locale: locale,
    brightness: brightness,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpWidget(
  WidgetTester tester,
  Widget screen,
  AppSettings settings, {
  MatchUiState? state,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsProvider.overrideWith(() => _FixedSettings(settings)),
        photoLibraryProvider.overrideWithValue(TestPhotoLibrary()),
        matchStateProvider.overrideWith(
          (ref) => Stream<MatchUiState>.value(state ?? const MatchUiState()),
        ),
      ],
      child: RepaintBoundary(
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          theme: buildWhoTookTheme(brightness),
          home: screen,
        ),
      ),
    ),
  );
}

class _FixedSettings extends AppSettingsController {
  _FixedSettings(this._value);

  final AppSettings _value;

  @override
  Future<AppSettings> build() async => _value;
}

AppSettings _settings() => const AppSettings(
  nickname: 'Bram',
  onboardingCompleted: true,
  excludedAlbumIds: <String>{'screenshots', 'whatsapp', 'documents'},
);

List<Player> _players() => <Player>[
  Player(id: 'host', name: 'Bram', avatar: 'rocket', isHost: true, score: 2410),
  Player(
    id: 'c1',
    name: 'Lotte',
    avatar: 'star',
    score: 3410,
    streak: 3,
    ready: true,
  ),
  Player(id: 'c2', name: 'Sam', avatar: 'music', score: 2740),
  Player(id: 'c3', name: 'Noor', avatar: 'plant', score: 3180),
];

MatchUiState _setupState({GameMode mode = GameMode.classic}) =>
    MatchUiState(config: MatchConfig(roundsK: 10, roundSeconds: 8, mode: mode));

MatchUiState _lobbyState() => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  inviteUrl: 'https://whotook.party/j#eyJ2IjoxLCJob3N0SWQiOiJob3N0Iiwicm9vbSI6Ims4bTJwOXg0In0',
  localPlayerId: 'host',
  players: _players(),
  config: const MatchConfig(roundsK: 10, roundSeconds: 8),
  connectionMode: ConnectionMode.localLan,
);

MatchUiState _onlineLobbyState() => MatchUiState(
  isHosting: false,
  roomId: 'k8m2p9x4',
  localPlayerId: 'c1',
  players: _players(),
  config: const MatchConfig(roundsK: 10, roundSeconds: 8),
  connectionMode: ConnectionMode.webrtcP2p,
);

List<Uint8List> _fixturePhotos() => <Uint8List>[
  _fixturePhoto('party-dog'),
  _fixturePhoto('party-cat'),
  _fixturePhoto('party-hamster'),
  _fixturePhoto('party-pizza'),
];

/// Six distinct photos for the Make It Meme vault screenshots.
List<Uint8List> _fixturePhotosSix() => <Uint8List>[
  ..._fixturePhotos(),
  _fixturePhoto('party-dog2'),
  _fixturePhoto('party-cat2'),
];

MatchUiState _prepareState(
  List<Uint8List> photos, {
  int count = 4,
  int needed = 4,
}) => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  players: _players(),
  phase: RoundPhase.preparing,
  photosNeeded: needed,
  candidates: <PhotoCandidate>[
    for (var i = 0; i < count; i++)
      PhotoCandidate(
        photoId: 'p$i',
        localAssetId: 'a$i',
        ownerId: 'host',
        bytes: photos[i % photos.length],
      ),
  ],
  plantUnlocked: true,
);

MatchUiState _roundState(Uint8List photo) => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  players: _players(),
  phase: RoundPhase.guessing,
  currentRound: 3,
  totalRounds: 10,
  remainingMs: 5400,
  config: const MatchConfig(roundsK: 10, roundSeconds: 8),
  activePhotoBytes: photo,
  activeRoundOptions: _players(),
  screenshotAlerts: const <ScreenshotBanner>[
    ScreenshotBanner(playerId: 'c1', playerName: 'Lotte', atMs: 0),
  ],
);

String _encoded(Uint8List bytes) => base64Encode(bytes);

MatchUiState _timelineRevealState(Uint8List photo) => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  players: _players(),
  phase: RoundPhase.timelineReveal,
  activeMode: GameMode.timeTraveler,
  config: const MatchConfig(
    roundsK: 6,
    roundSeconds: 8,
    mode: GameMode.timeTraveler,
  ),
  currentRound: 2,
  totalRounds: 6,
  activePhotoBytes: photo,
  lastTimelineReveal: TimelineReveal(
    roundNumber: 2,
    photoId: 'p-hamster',
    ownerId: 'c3',
    actualYear: 2019,
    actualMonth: 8,
    entries: const <TimelineEntry>[
      TimelineEntry(
        playerId: 'c1',
        playerName: 'Lotte',
        year: 2019,
        month: 8,
        monthsOff: 0,
        points: 1000,
      ),
      TimelineEntry(
        playerId: 'c2',
        playerName: 'Sam',
        year: 2014,
        month: 2,
        monthsOff: 66,
        points: 300,
      ),
      TimelineEntry(
        playerId: 'c3',
        playerName: 'Noor',
        year: 2019,
        month: 8,
        monthsOff: 0,
        points: 1120,
        isOwner: true,
      ),
      TimelineEntry(
        playerId: 'host',
        playerName: 'Bram',
        points: 0,
        timedOut: true,
      ),
    ],
    scoreDeltas: const <String, int>{'c1': 1000, 'c2': 300, 'c3': 1120},
    closestId: 'c1',
    furthestId: 'c2',
  ),
);

MatchUiState _classicRevealState(Uint8List photo) => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  players: _players(),
  phase: RoundPhase.reveal,
  currentRound: 3,
  totalRounds: 10,
  remainingMs: 0,
  config: const MatchConfig(roundsK: 10, roundSeconds: 8),
  activePhotoBytes: photo,
  lastReveal: RoundReveal(
    roundNumber: 3,
    ownerId: 'c1',
    photoId: 'p-dog',
    isPlanted: false,
    guesses: const <GuessRecord>[
      GuessRecord(
        playerId: 'host',
        guessedOwnerId: 'c1',
        elapsedMs: 1200,
        isCorrect: true,
        isOwnPhoto: false,
        pointsAwarded: 820,
      ),
      GuessRecord(
        playerId: 'c2',
        guessedOwnerId: 'c1',
        elapsedMs: 2400,
        isCorrect: true,
        isOwnPhoto: false,
        pointsAwarded: 610,
      ),
      GuessRecord(
        playerId: 'c3',
        guessedOwnerId: 'c2',
        elapsedMs: 3100,
        isCorrect: false,
        isOwnPhoto: false,
        pointsAwarded: 0,
      ),
      GuessRecord(
        playerId: 'c1',
        guessedOwnerId: 'c1',
        elapsedMs: 0,
        isCorrect: false,
        isOwnPhoto: true,
        pointsAwarded: 0,
      ),
    ],
    scoreDeltas: const <String, int>{
      'host': 820,
      'c2': 610,
      'c3': 0,
      'c1': 180,
    },
    streaks: const <String, int>{'host': 2, 'c2': 1},
    everyoneGuessed: true,
  ),
);

MatchUiState _memeEditorState(Uint8List photo) => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  players: _players(),
  phase: RoundPhase.captionWriting,
  activeMode: GameMode.makeItMeme,
  currentRound: 1,
  totalRounds: 5,
  remainingMs: 64000,
  phaseDurationMs: 90000,
  config: const MatchConfig(
    roundsK: 5,
    roundSeconds: 90,
    mode: GameMode.makeItMeme,
    pace: GamePace.normal,
  ),
  memeAssignment: const MemeAssignment(
    playerId: 'host',
    photoId: 'meme-photo',
    ownerId: 'c2',
    ownerName: 'Sam',
  ),
  memePhotoBase64: _encoded(photo),
  memeSwapsLeft: 5,
);

MatchUiState _memeVoteState(Uint8List photo) => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  players: _players(),
  phase: RoundPhase.captionVoting,
  activeMode: GameMode.makeItMeme,
  currentRound: 1,
  totalRounds: 5,
  remainingMs: 0,
  config: const MatchConfig(roundsK: 5, mode: GameMode.makeItMeme),
  memeCards: <MemeCard>[
    MemeCard(
      id: 'meme-0',
      photoBase64: _encoded(photo),
      template: MemeTemplate.pov,
      topText: 'POV: you said one more round',
      bottomText: 'and the room heard you',
      snapY: 48,
    ),
    MemeCard(
      id: 'meme-1',
      photoBase64: _encoded(photo),
      template: MemeTemplate.classic,
      topText: 'Nobody:',
      bottomText: '... me:',
      snapY: 48,
    ),
  ],
);

MatchUiState _memeRevealState(Uint8List photo) => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  players: _players(),
  phase: RoundPhase.captionReveal,
  activeMode: GameMode.makeItMeme,
  currentRound: 1,
  totalRounds: 5,
  remainingMs: 0,
  config: const MatchConfig(roundsK: 5, mode: GameMode.makeItMeme),
  lastMemeReveal: MemeReveal(
    roundNumber: 1,
    entries: const <MemeEntry>[
      MemeEntry(
        id: 'meme-0',
        authorId: 'c1',
        authorName: 'Lotte',
        photoId: 'meme-photo',
        photoOwnerId: 'c2',
        photoOwnerName: 'Sam',
        template: MemeTemplate.pov,
        topText: 'POV: you said one more round',
        bottomText: 'and the room heard you',
        snapY: 48,
        upVotes: 3,
        mehVotes: 1,
        downVotes: 0,
        points: 300,
      ),
      MemeEntry(
        id: 'meme-1',
        authorId: 'c2',
        authorName: 'Sam',
        photoId: 'meme-photo',
        photoOwnerId: 'c1',
        photoOwnerName: 'Lotte',
        template: MemeTemplate.classic,
        topText: 'Nobody:',
        bottomText: '... me:',
        snapY: 48,
        upVotes: 1,
        mehVotes: 2,
        downVotes: 1,
        points: 50,
      ),
    ],
    winnerIds: const <String>['meme-0'],
    scoreDeltas: const <String, int>{'c1': 300, 'c2': 25},
  ),
  memeRevealCards: <MemeCard>[
    MemeCard(
      id: 'meme-0',
      photoBase64: _encoded(photo),
      template: MemeTemplate.pov,
      topText: 'POV: you said one more round',
      bottomText: 'and the room heard you',
      snapY: 48,
      authorName: 'Lotte',
      photoOwnerName: 'Sam',
      upVotes: 3,
      mehVotes: 1,
      points: 300,
      isWinner: true,
    ),
    MemeCard(
      id: 'meme-1',
      photoBase64: _encoded(photo),
      template: MemeTemplate.classic,
      topText: 'Nobody:',
      bottomText: '... me:',
      snapY: 48,
      authorName: 'Sam',
      photoOwnerName: 'Lotte',
      upVotes: 1,
      mehVotes: 2,
      downVotes: 1,
      points: 50,
    ),
  ],
  topMemes: <MemeCard>[
    MemeCard(
      id: 'meme-0',
      photoBase64: _encoded(photo),
      template: MemeTemplate.pov,
      topText: 'POV: you said one more round',
      bottomText: 'and the room heard you',
      snapY: 48,
      authorName: 'Lotte',
      points: 300,
      isWinner: true,
    ),
  ],
);

MatchUiState _podiumState() => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  players: _players(),
  phase: RoundPhase.podium,
  currentRound: 10,
  totalRounds: 10,
  awards: const <MatchAward>[
    MatchAward(
      kind: MatchAwardKind.champion,
      playerId: 'c1',
      playerName: 'Lotte',
      value: 3410,
    ),
    MatchAward(
      kind: MatchAwardKind.quickestDraw,
      playerId: 'c2',
      playerName: 'Sam',
      value: 400,
    ),
    MatchAward(
      kind: MatchAwardKind.unstoppable,
      playerId: 'c1',
      playerName: 'Lotte',
      value: 5,
    ),
    MatchAward(
      kind: MatchAwardKind.masterOfMystery,
      playerId: 'c3',
      playerName: 'Noor',
      value: 450,
    ),
    MatchAward(
      kind: MatchAwardKind.paparazzi,
      playerId: 'c1',
      playerName: 'Lotte',
      value: 3,
    ),
  ],
);

Future<void> _precacheHomePhotos(WidgetTester tester) async {
  for (final name in <String>[
    'party-dog',
    'party-cat',
    'party-hamster',
    'party-pizza',
  ]) {
    final provider = AssetImage('assets/samples/$name.jpg');
    await tester.runAsync(() async {
      final stream = provider.resolve(ImageConfiguration.empty);
      final done = Completer<void>();
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (_, _) {
          if (!done.isCompleted) done.complete();
          stream.removeListener(listener);
        },
        onError: (_, _) {
          if (!done.isCompleted) done.complete();
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      await done.future;
    });
  }
}

Future<void> _loadFonts() async {
  final dmSans = FontLoader('DMSans')
    ..addFont(rootBundle.load('assets/fonts/DMSans.ttf'));
  final mono = FontLoader('JetBrainsMono')
    ..addFont(rootBundle.load('assets/fonts/JetBrainsMono.ttf'));
  await Future.wait(<Future<void>>[dmSans.load(), mono.load()]);
  final iconFont = File(
    '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}'
    '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (iconFont.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(
        Future<ByteData>.value(
          ByteData.sublistView(iconFont.readAsBytesSync()),
        ),
      );
    await loader.load();
  }
}

Uint8List _fixturePhoto(String name) =>
    File('test/ui/fixtures/$name.jpg').readAsBytesSync();

/// Fills the image cache before the widget builds, so the golden shows the
/// photo instead of the empty frame the test renderer paints on a cache miss.
Future<void> _settleImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  });
  await tester.pump();
}

Future<void> _precachePhoto(WidgetTester tester, Uint8List bytes) async {
  await tester.runAsync(() async {
    final stream = MemoryImage(bytes).resolve(ImageConfiguration.empty);
    final done = Completer<void>();
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, _) {
        if (!done.isCompleted) done.complete();
        stream.removeListener(listener);
      },
      onError: (_, _) {
        if (!done.isCompleted) done.complete();
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    await done.future;
  });
}
