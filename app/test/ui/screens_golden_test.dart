import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/storage/last_room_repository.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/state/providers.dart';
import 'package:whotook/ui/screens/home_screen.dart';
import 'package:whotook/ui/screens/lobby_screen.dart';
import 'package:whotook/ui/screens/onboarding_screen.dart';
import 'package:whotook/ui/screens/podium_screen.dart';
import 'package:whotook/ui/screens/prepare_screen.dart';
import 'package:whotook/ui/screens/round_screen.dart';
import 'package:whotook/ui/screens/settings_screen.dart';
import 'package:whotook/ui/screens/setup/mode_setup_screen.dart';
import 'package:whotook/ui/screens/setup/rounds_setup_screen.dart';
import 'package:whotook/ui/screens/setup/speed_setup_screen.dart';
import 'package:whotook/ui/widgets/version_warning_card.dart';

import '../support/test_photo_library.dart';

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
    await _pump(tester, const LobbyScreen(), _settings(), state: _lobbyState());
    await expectLater(
      find.byType(LobbyScreen),
      matchesGoldenFile('goldens/lobby.png'),
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
      state: _setupState(mode: GameMode.captionThis),
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
}) async {
  await _pumpWidget(tester, screen, settings, state: state, locale: locale);
  await tester.pumpAndSettle();
}

Future<void> _pumpWidget(
  WidgetTester tester,
  Widget screen,
  AppSettings settings, {
  MatchUiState? state,
  Locale locale = const Locale('en'),
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
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: buildWhoTookTheme(Brightness.light),
        home: screen,
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

List<Uint8List> _fixturePhotos() => <Uint8List>[
  _fixturePhoto('party-dog'),
  _fixturePhoto('party-cat'),
  _fixturePhoto('party-hamster'),
  _fixturePhoto('party-pizza'),
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
