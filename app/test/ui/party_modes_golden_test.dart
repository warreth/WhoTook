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
import 'package:whotook/ui/screens/caption_screen.dart';
import 'package:whotook/ui/screens/setup/mode_setup_screen.dart';
import 'package:whotook/ui/screens/timeline_screen.dart';
import 'package:whotook/ui/widgets/common.dart';

import '../support/test_photo_library.dart';

/// Marketing screenshots for the two party modes, with deterministic state.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
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

  testWidgets('caption writing', (tester) async {
    final photo = _photo('party-cat');
    await _precache(tester, photo);
    await _pump(tester, const CaptionScreen(), _captionWriting(photo));
    await tester.enterText(
      find.byType(TextField),
      'When the cake hits the floor...',
    );
    await tester.pumpAndSettle();
    final send = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(send.onPressed, isNotNull);
    await expectLater(
      find.byType(CaptionScreen),
      matchesGoldenFile('marketing/caption-writing.png'),
    );
  });

  testWidgets('caption voting', (tester) async {
    final photo = _photo('party-cat');
    await _precache(tester, photo);
    await _pump(tester, const CaptionScreen(), _captionVoting(photo));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(CaptionScreen),
      matchesGoldenFile('marketing/caption-voting.png'),
    );
  });

  testWidgets('caption reveal', (tester) async {
    final photo = _photo('party-cat');
    await _precache(tester, photo);
    await _pump(tester, const CaptionScreen(), _captionReveal(photo));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(CaptionScreen),
      matchesGoldenFile('marketing/caption-reveal.png'),
    );
  });

  testWidgets('timeline guessing', (tester) async {
    final photo = _photo('party-hamster');
    await _precache(tester, photo);
    await _pump(tester, const TimelineScreen(), _timelineGuessing(photo));
    await expectLater(
      find.byType(TimelineScreen),
      matchesGoldenFile('marketing/timeline-guessing.png'),
    );
  });

  testWidgets('timeline reveal', (tester) async {
    final photo = _photo('party-hamster');
    await _precache(tester, photo);
    await _pump(tester, const TimelineScreen(), _timelineReveal(photo));
    await expectLater(
      find.byType(TimelineScreen),
      matchesGoldenFile('marketing/timeline-reveal.png'),
    );
  });

  testWidgets('mode selector', (tester) async {
    await _pump(tester, const ModeSetupScreen(), _lobbyModes());
    await expectLater(
      find.byType(ModeSetupScreen),
      matchesGoldenFile('marketing/modes.png'),
    );
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  MatchUiState state,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsProvider.overrideWith(
          () => _FixedSettings(
            const AppSettings(nickname: 'Bram', onboardingCompleted: true),
          ),
        ),
        photoLibraryProvider.overrideWithValue(TestPhotoLibrary()),
        matchStateProvider.overrideWith(
          (ref) => Stream<MatchUiState>.value(state),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildWhoTookTheme(Brightness.light),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FixedSettings extends AppSettingsController {
  _FixedSettings(this._value);

  final AppSettings _value;

  @override
  Future<AppSettings> build() async => _value;
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

MatchUiState _captionWriting(Uint8List photo) => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  players: _players(),
  phase: RoundPhase.captionWriting,
  activeMode: GameMode.captionThis,
  config: const MatchConfig(
    roundsK: 6,
    roundSeconds: 8,
    mode: GameMode.captionThis,
  ),
  currentRound: 2,
  totalRounds: 6,
  remainingMs: 32000,
  phaseDurationMs: 40000,
  activePhotoBytes: photo,
);

MatchUiState _captionVoting(Uint8List photo) => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  players: _players(),
  phase: RoundPhase.captionVoting,
  activeMode: GameMode.captionThis,
  config: const MatchConfig(
    roundsK: 6,
    roundSeconds: 8,
    mode: GameMode.captionThis,
  ),
  currentRound: 2,
  totalRounds: 6,
  activePhotoBytes: photo,
  ownCaptionId: 'cap-0',
  captionsSubmitted: 4,
  votesSubmitted: 2,
  captionOptions: const <CaptionOption>[
    CaptionOption(id: 'cap-0', text: 'This is the last photo before...'),
    CaptionOption(id: 'cap-1', text: 'When the cake hits the floor.'),
    CaptionOption(id: 'cap-2', text: 'POV: you said one more round.'),
    CaptionOption(id: 'cap-3', text: 'Nobody: ... Me:'),
  ],
);

MatchUiState _captionReveal(Uint8List photo) => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  players: _players(),
  phase: RoundPhase.captionReveal,
  activeMode: GameMode.captionThis,
  config: const MatchConfig(
    roundsK: 6,
    roundSeconds: 8,
    mode: GameMode.captionThis,
  ),
  currentRound: 2,
  totalRounds: 6,
  activePhotoBytes: photo,
  ownCaptionId: 'cap-0',
  lastCaptionReveal: CaptionReveal(
    roundNumber: 2,
    photoId: 'p-cat',
    ownerId: 'c1',
    entries: const <CaptionEntry>[
      CaptionEntry(
        id: 'cap-1',
        text: 'When the cake hits the floor.',
        authorId: 'c1',
        authorName: 'Lotte',
        votes: 3,
        points: 500,
      ),
      CaptionEntry(
        id: 'cap-2',
        text: 'POV: you said one more round.',
        authorId: 'c2',
        authorName: 'Sam',
        votes: 2,
        points: 200,
      ),
      CaptionEntry(
        id: 'cap-0',
        text: 'This is the last photo before...',
        authorId: 'host',
        authorName: 'Bram',
        votes: 1,
        points: 100,
      ),
      CaptionEntry(
        id: 'cap-3',
        text: 'Nobody: ... Me:',
        authorId: 'c3',
        authorName: 'Noor',
        votes: 0,
        points: 0,
      ),
    ],
    winnerIds: const <String>['cap-1'],
    scoreDeltas: const <String, int>{'c1': 500, 'c2': 200, 'host': 100},
  ),
);

MatchUiState _timelineGuessing(Uint8List photo) => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  players: _players(),
  phase: RoundPhase.timelineGuessing,
  activeMode: GameMode.timeTraveler,
  config: const MatchConfig(
    roundsK: 6,
    roundSeconds: 8,
    mode: GameMode.timeTraveler,
  ),
  currentRound: 2,
  totalRounds: 6,
  remainingMs: 22000,
  phaseDurationMs: 30000,
  activePhotoBytes: photo,
);

MatchUiState _timelineReveal(Uint8List photo) => MatchUiState(
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

MatchUiState _lobbyModes() => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  inviteUrl: 'https://whotook.party/j#eyJ2IjoxLCJob3N0SWQiOiJob3N0Iiwicm9vbSI6Ims4bTJwOXg0In0',
  localPlayerId: 'host',
  players: _players(),
  config: const MatchConfig(
    roundsK: 10,
    roundSeconds: 8,
    mode: GameMode.captionThis,
  ),
  connectionMode: ConnectionMode.localLan,
);

Uint8List _photo(String name) =>
    File('test/ui/fixtures/$name.jpg').readAsBytesSync();

Future<void> _precache(WidgetTester tester, Uint8List bytes) async {
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
