// Regenerates the lobby, photo check, round and podium store screenshots.
// Run from app/: flutter test tool/store_capture_test.dart --update-goldens
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/state/providers.dart';
import 'package:whotook/ui/screens/lobby_screen.dart';
import 'package:whotook/ui/screens/podium_screen.dart';
import 'package:whotook/ui/screens/prepare_screen.dart';
import 'package:whotook/ui/screens/round_screen.dart';

import '../test/support/test_photo_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  final photo = _fixturePhoto('party-dog');
  final photos = <Uint8List>[
    photo,
    _fixturePhoto('party-cat'),
    _fixturePhoto('party-hamster'),
    _fixturePhoto('party-pizza'),
  ];

  for (final target in _targets) {
    testWidgets('lobby ${target.folder}', (tester) async {
      await _capture(
        tester,
        target,
        '03-lobby.png',
        const LobbyScreen(),
        _lobbyState(),
      );
    });

    testWidgets('photo check ${target.folder}', (tester) async {
      for (final bytes in photos) {
        await _precachePhoto(tester, bytes);
      }
      await _capture(
        tester,
        target,
        '04-photo-check.png',
        const PrepareScreen(),
        _prepareState(photos),
      );
    });

    testWidgets('round ${target.folder}', (tester) async {
      await _precachePhoto(tester, photo);
      await _capture(
        tester,
        target,
        '05-round.png',
        const RoundScreen(),
        _roundState(photo),
      );
    });

    testWidgets('podium ${target.folder}', (tester) async {
      await _capture(
        tester,
        target,
        '06-podium.png',
        const PodiumScreen(),
        _podiumState(),
        extraPump: const Duration(milliseconds: 850),
      );
    });
  }
}

Future<void> _capture(
  WidgetTester tester,
  _Target target,
  String file,
  Widget screen,
  MatchUiState state, {
  Duration extraPump = Duration.zero,
}) async {
  tester.view.physicalSize = Size(
    target.width * target.scale,
    target.height * target.scale,
  );
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        width: target.width,
        height: target.height,
        child: ProviderScope(
          overrides: [
            appSettingsProvider.overrideWith(() => _FixedSettings()),
            photoLibraryProvider.overrideWithValue(TestPhotoLibrary()),
            matchStateProvider.overrideWith(
              (ref) => Stream<MatchUiState>.value(state),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildWhoTookTheme(Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: Size(target.width, target.height),
                devicePixelRatio: 1,
              ),
              child: child!,
            ),
            home: screen,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  if (extraPump != Duration.zero) await tester.pump(extraPump);
  await expectLater(
    find.byType(FittedBox),
    matchesGoldenFile('../../store/assets/screenshots/${target.folder}/$file'),
  );
}

class _Target {
  const _Target(this.folder, this.width, this.height, this.scale);
  final String folder;
  final double width;
  final double height;
  final int scale;
}

const List<_Target> _targets = <_Target>[
  _Target('iphone69', 440, 956, 3),
  _Target('ipad13', 1032, 1376, 2),
  _Target('play', 390, 780, 3),
];

const AppSettings _settings = AppSettings(
  nickname: 'Bram',
  avatar: 'rocket',
  onboardingCompleted: true,
);

class _FixedSettings extends AppSettingsController {
  @override
  Future<AppSettings> build() async => _settings;
}

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

MatchUiState _lobbyState() => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  inviteUrl: 'https://whotook.party/j#eyJ2IjoxLCJob3N0SWQiOiJob3N0Iiwicm9vbSI6Ims4bTJwOXg0In0',
  localPlayerId: 'host',
  players: _players(),
  config: const MatchConfig(roundsK: 10, roundSeconds: 8),
  connectionMode: ConnectionMode.localLan,
);

MatchUiState _prepareState(List<Uint8List> photos) => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  players: _players(),
  phase: RoundPhase.preparing,
  photosNeeded: 4,
  candidates: <PhotoCandidate>[
    for (var i = 0; i < photos.length; i++)
      PhotoCandidate(
        photoId: 'p$i',
        localAssetId: 'a$i',
        ownerId: 'host',
        bytes: photos[i],
      ),
  ],
  plantUnlocked: true,
  plantEligible: true,
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

Uint8List _fixturePhoto(String name) =>
    File('test/ui/fixtures/$name.jpg').readAsBytesSync();

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
