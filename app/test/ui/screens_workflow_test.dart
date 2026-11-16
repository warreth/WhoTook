import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/state/providers.dart';
import 'package:whotook/ui/screens/caption_screen.dart';
import 'package:whotook/ui/screens/extend_screen.dart';
import 'package:whotook/ui/screens/podium_screen.dart';
import 'package:whotook/ui/screens/round_screen.dart';
import 'package:whotook/ui/screens/settings_screen.dart';
import 'package:whotook/ui/widgets/common.dart';

import '../support/test_photo_library.dart';

/// Covers the flows a screenshot test cannot: the countdown copy, the extend
/// prompt and settings that save without the keyboard submit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('round countdown shows the calm numeral, not a photo box', (
    tester,
  ) async {
    await _pumpMatchScreen(tester, const RoundScreen(), _countdownState());

    expect(find.text('Round 3 of 10'), findsOneWidget);
    expect(find.text('Get ready'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(
      find.text('Tap who took the photo as soon as it appears'),
      findsOneWidget,
    );
    expect(find.textContaining('s left'), findsNothing);
  });

  testWidgets('extend prompt shows the window, frames and approve', (
    tester,
  ) async {
    await _pumpMatchScreen(tester, const ExtendScreen(), _extendState());

    expect(find.text('5 more rounds'), findsOneWidget);
    expect(find.text('42s'), findsOneWidget);
    expect(
      find.text('Swap anything you like before the timer ends.'),
      findsOneWidget,
    );
    expect(find.byType(NumberTag), findsNWidgets(3));
    expect(find.text('Swap'), findsNWidgets(3));
    expect(find.text('01'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
  });

  testWidgets('podium crowns a champion and offers one more round', (
    tester,
  ) async {
    await _pumpMatchScreen(tester, const PodiumScreen(), _podiumState());
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.text('CHAMPION'), findsOneWidget);
    expect(find.text('Lotte'), findsWidgets);
    expect(find.text('3410 pts'), findsOneWidget);
    expect(find.text('One more round (5)'), findsOneWidget);
  });

  testWidgets('host controls expose skip and remove', (tester) async {
    await _pumpMatchScreen(tester, const RoundScreen(), _revealState());
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byTooltip('Host controls'), findsOneWidget);
    await tester.tap(find.byTooltip('Host controls'));
    await tester.pumpAndSettle();
    expect(find.text('Skip round'), findsOneWidget);
    expect(find.text('Remove player'), findsOneWidget);
    await tester.tap(find.text('Skip round'));
    await tester.pumpAndSettle();
    expect(find.text('Skip this round?'), findsOneWidget);
  });

  testWidgets('caption voting offers a host reveal after the grace', (
    tester,
  ) async {
    await _pumpMatchScreen(
      tester,
      const CaptionScreen(),
      _captionVotingState(),
    );
    expect(find.text('Reveal now'), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(find.text('Reveal now'), findsOneWidget);
  });

  testWidgets('reveal builds suspense, then names the owner', (tester) async {
    await _pumpMatchScreen(tester, const RoundScreen(), _revealState());

    expect(find.text('Who took it?'), findsOneWidget);
    expect(find.text('Shot by Lotte'), findsNothing);

    await tester.pump(const Duration(milliseconds: 750));

    expect(find.text('Shot by Lotte'), findsOneWidget);
    expect(find.text('You got it. +820'), findsOneWidget);
  });

  testWidgets('settings saves the nickname while typing and opens the relay', (
    tester,
  ) async {
    final settings = _RecordingSettings(
      const AppSettings(nickname: 'Bram', onboardingCompleted: true),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith(() => settings),
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

    await tester.enterText(find.byType(TextField).first, 'Lotte');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(settings.savedNickname, 'Lotte');

    expect(find.text('Signaling URL'), findsNothing);
    final advancedTile = find.widgetWithText(ListTile, 'Advanced settings');
    await tester.dragUntilVisible(
      advancedTile,
      find.byType(ListView),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(advancedTile);
    await tester.pumpAndSettle();

    expect(find.text('Signaling URL'), findsOneWidget);
    expect(find.text('Custom TURN URL'), findsOneWidget);
    expect(find.text('TURN username'), findsOneWidget);
    expect(find.text('TURN credential'), findsOneWidget);
    expect(find.text('Save relay'), findsOneWidget);
    expect(find.text('Reset to default'), findsOneWidget);
  });
}

Future<void> _pumpMatchScreen(
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
        matchStateProvider.overrideWith(
          (ref) => Stream<MatchUiState>.value(state),
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
  await tester.pumpAndSettle();
}

class _FixedSettings extends AppSettingsController {
  _FixedSettings(this._value);

  final AppSettings _value;

  @override
  Future<AppSettings> build() async => _value;
}

/// Keeps the last nickname the screen applied, so the test can prove the
/// 300ms debounce saved without a keyboard submit.
class _RecordingSettings extends AppSettingsController {
  _RecordingSettings(this._initial);

  final AppSettings _initial;
  String? savedNickname;

  @override
  Future<AppSettings> build() async => _initial;

  @override
  Future<void> apply(AppSettings Function(AppSettings current) change) async {
    final next = change(state.value ?? _initial);
    savedNickname = next.nickname;
    state = AsyncData<AppSettings>(next);
  }
}

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
  ],
);

MatchUiState _revealState() => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  players: _players(),
  phase: RoundPhase.reveal,
  currentRound: 3,
  totalRounds: 10,
  lastReveal: RoundReveal(
    roundNumber: 3,
    ownerId: 'c1',
    photoId: 'p1',
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
    ],
    scoreDeltas: const <String, int>{'host': 820},
    streaks: const <String, int>{'host': 2},
    nobodyGuessed: false,
    everyoneGuessed: true,
  ),
);

List<Player> _players() => <Player>[
  Player(id: 'host', name: 'Bram', isHost: true, score: 2410),
  Player(id: 'c1', name: 'Lotte', score: 3410, streak: 3, ready: true),
  Player(id: 'c2', name: 'Sam', score: 2740),
];

MatchUiState _captionVotingState() => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  players: _players(),
  phase: RoundPhase.captionVoting,
  activeMode: GameMode.captionThis,
  currentRound: 2,
  totalRounds: 6,
  captionsSubmitted: 3,
  votesSubmitted: 1,
  ownCaptionId: 'cap-0',
  captionOptions: const <CaptionOption>[
    CaptionOption(id: 'cap-0', text: 'This is the last photo before...'),
    CaptionOption(id: 'cap-1', text: 'When the cake hits the floor.'),
    CaptionOption(id: 'cap-2', text: 'POV: you said one more round.'),
  ],
);

MatchUiState _countdownState() => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  players: _players(),
  phase: RoundPhase.countdown,
  currentRound: 3,
  totalRounds: 10,
  remainingMs: 3200,
  config: const MatchConfig(roundsK: 10, roundSeconds: 8),
);

MatchUiState _extendState() => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  players: _players(),
  phase: RoundPhase.extendPrompt,
  currentRound: 10,
  totalRounds: 15,
  config: const MatchConfig(roundsK: 10, roundSeconds: 8),
  extensionSecondsLeft: 42,
  extensionCandidates: <PhotoCandidate>[
    for (var i = 0; i < 3; i++)
      PhotoCandidate(
        photoId: 'ext$i',
        localAssetId: 'e$i',
        ownerId: 'host',
        bytes: Uint8List(0),
      ),
  ],
);
