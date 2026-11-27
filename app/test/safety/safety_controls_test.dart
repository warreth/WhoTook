import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/party_pass/party_pass_controller.dart';
import 'package:whotook/core/party_pass/purchase_service.dart';
import 'package:whotook/core/safety/moderation_report_service.dart';
import 'package:whotook/core/storage/settings_repository.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/state/providers.dart';
import 'package:whotook/transport/game_transport.dart';
import 'package:whotook/transport/hybrid_connector.dart';
import 'package:whotook/ui/screens/podium_screen.dart';
import 'package:whotook/ui/screens/round_screen.dart';
import 'package:whotook/ui/widgets/host_controls.dart';
import 'package:whotook/ui/widgets/party_pass_sheet.dart';
import 'package:whotook/ui/widgets/safety_controls.dart';

import '../support/test_photo_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('AppSettings.blockedPlayerNames normalizes and serializes', () {
    expect(normalizeBlockedName('  Lotte  '), 'lotte');
    final initial = AppSettings(
      blockedPlayerNames: <String>{'lotte'},
    );
    final roundTripped = AppSettings.fromJson(initial.toJson());
    expect(roundTripped.blockedPlayerNames, <String>{'lotte'});
    expect(roundTripped.isPlayerBlocked(' Lotte '), isTrue);
    expect(roundTripped.isPlayerBlocked('Bram'), isFalse);
  });

  test('MatchCoordinator blocks, unblocks, hides photos, and kicks on host', () async {
    final hub = LoopbackHub();
    final host = MatchCoordinator(
      photos: TestPhotoLibrary(seed: 1),
      settings: SettingsRepository(),
      hostTransportFactory: (roomId, secret, lan) => LoopbackHostTransport(hub),
    );
    final client = MatchCoordinator(
      photos: TestPhotoLibrary(seed: 2),
      settings: SettingsRepository(),
      playerTokenOverride: 'client-safety-token',
      connector: HybridConnector(
        onlineClientFactory: () => LoopbackClientTransport(hub),
      ),
    );
    await host.loadSettings();
    await client.loadSettings();

    await host.hostMatch();
    await client.joinMatch(host.state.inviteUrl!);
    await _waitFor(() => host.state.players.length == 2);

    final guest = host.state.players.firstWhere((player) => !player.isHost);
    host.hidePhoto('photo-bad');
    expect(host.state.isPhotoHidden('photo-bad'), isTrue);

    await host.blockPlayer(guest.id, name: guest.name);
    expect(host.state.isPlayerBlocked(guest.id, guest.name), isTrue);
    expect(host.state.safeAvatarPhoto(guest.id, guest.name), isNull);
    expect(host.state.visibleAvatarPhotos.containsKey(guest.id), isFalse);
    expect(
      host.state.isCardBlocked(
        MemeCard(
          id: 'm1',
          photoBase64: '',
          template: MemeTemplate.classic,
          topText: 'top',
          bottomText: 'bottom',
          snapY: 48,
          photoId: 'photo-ok',
          authorId: guest.id,
          authorName: guest.name,
          photoOwnerId: 'host',
          photoOwnerName: 'Host',
        ),
      ),
      isTrue,
    );

    host.unblockPlayer(playerId: guest.id, name: guest.name);
    expect(host.state.isPlayerBlocked(guest.id, guest.name), isFalse);

    await host.blockPlayer(guest.id, name: guest.name, removeIfHost: true);
    await _waitFor(() => host.state.players.length == 1);

    await client.dispose();
    await host.dispose();
    await hub.dispose();
  });

  test('ModerationReportService posts /api/v1/reports and skips in demo mode', () async {
    Uri? capturedUri;
    Map<String, dynamic>? capturedBody;
    final service = ModerationReportService(
      baseUrl: 'https://signal.example.test',
      client: MockClient((request) async {
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'ok': true,
            'reportId': 'rpt_1234567890abcdef',
          }),
          200,
        );
      }),
    );

    final onlineResult = await service.submitReport(
      reason: ModerationReportReason.harassment,
      targetType: ModerationTargetType.photo,
      roomId: 'room1234',
      details: 'Offensive photo caption',
    );
    expect(onlineResult.submittedOnline, isTrue);
    expect(onlineResult.reportId, 'rpt_1234567890abcdef');
    expect(capturedUri.toString(), 'https://signal.example.test/api/v1/reports');
    expect(capturedBody?['reason'], 'harassment');
    expect(capturedBody?['targetType'], 'photo');
    expect(capturedBody?['roomId'], 'room1234');
    expect(capturedBody?['details'], 'Offensive photo caption');

    final demoResult = await service.submitReport(
      reason: ModerationReportReason.other,
      targetType: ModerationTargetType.general,
      isDemo: true,
    );
    expect(demoResult.submittedOnline, isFalse);
  });

  testWidgets('non-host players see Report and Block in HostControlsButton', (
    tester,
  ) async {
    final state = MatchUiState(
      isHosting: false,
      roomId: 'room1234',
      localPlayerId: 'c1',
      phase: RoundPhase.guessing,
      players: <Player>[
        Player(id: 'host', name: 'Bram', isHost: true),
        Player(id: 'c1', name: 'Lotte'),
        Player(id: 'c2', name: 'Sam'),
      ],
    );

    await _pumpWidget(
      tester,
      const Scaffold(body: Center(child: HostControlsButton())),
      state: state,
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Report content or player'), findsOneWidget);
    expect(find.text('Block a player'), findsOneWidget);
    expect(find.text('Skip round'), findsNothing);
    expect(find.text('Remove player'), findsNothing);
  });

  testWidgets('RoundScreen hides blocked photo behind BlockedContentPlaceholder', (
    tester,
  ) async {
    final state = MatchUiState(
      isHosting: false,
      roomId: 'room1234',
      localPlayerId: 'c1',
      phase: RoundPhase.guessing,
      currentRound: 1,
      totalRounds: 5,
      activePhotoId: 'bad-photo',
      activePhotoBytes: Uint8List.fromList(<int>[1, 2, 3]),
      hiddenPhotoIds: const <String>{'bad-photo'},
      players: <Player>[
        Player(id: 'host', name: 'Bram', isHost: true),
        Player(id: 'c1', name: 'Lotte'),
      ],
    );

    await _pumpWidget(tester, const RoundScreen(), state: state);

    expect(find.byType(BlockedContentPlaceholder), findsOneWidget);
    expect(find.text('Hidden from a blocked or reported player'), findsOneWidget);
  });

  testWidgets('PodiumScreen hides Top Creations by a blocked player', (
    tester,
  ) async {
    final state = MatchUiState(
      isHosting: false,
      roomId: 'room1234',
      localPlayerId: 'c1',
      phase: RoundPhase.podium,
      currentRound: 3,
      totalRounds: 3,
      blockedPlayerIds: const <String>{'c2'},
      blockedPlayerNames: const <String>{'sam'},
      players: <Player>[
        Player(id: 'host', name: 'Bram', isHost: true, score: 1200),
        Player(id: 'c1', name: 'Lotte', score: 900),
        Player(id: 'c2', name: 'Sam', score: 700),
      ],
      topMemes: const <MemeCard>[
        MemeCard(
          id: 'm1',
          photoBase64: '',
          template: MemeTemplate.classic,
          topText: 'hidden top',
          bottomText: 'hidden bottom',
          snapY: 48,
          photoId: 'p1',
          authorId: 'c2',
          authorName: 'Sam',
          photoOwnerId: 'host',
          photoOwnerName: 'Bram',
          upVotes: 2,
          points: 200,
        ),
      ],
    );

    await _pumpWidget(tester, const PodiumScreen(), state: state);
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.byType(BlockedContentPlaceholder), findsOneWidget);
    expect(find.text('hidden top'), findsNothing);
  });

  testWidgets('PartyPassBottomSheet shows Restore purchases even when billingAvailable is false on store build', (
    tester,
  ) async {
    final state = MatchUiState(
      isHosting: true,
      roomId: 'room1234',
      localPlayerId: 'host',
      phase: RoundPhase.lobby,
      players: <Player>[Player(id: 'host', name: 'Bram', isHost: true)],
    );

    await _pumpWidget(
      tester,
      const Scaffold(body: PartyPassBottomSheet()),
      state: state,
      partyPassState: const PartyPassState(
        active: false,
        billingAvailable: false,
        billingReady: true,
        billingKind: PartyPassBillingKind.store,
        loading: false,
      ),
    );

    expect(find.text('Restore purchases'), findsOneWidget);
  });
}

Future<void> _pumpWidget(
  WidgetTester tester,
  Widget child, {
  required MatchUiState state,
  PartyPassState? partyPassState,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsProvider.overrideWith(
          () => _FixedSettings(
            const AppSettings(nickname: 'Lotte', onboardingCompleted: true),
          ),
        ),
        matchStateProvider.overrideWith(
          (ref) => Stream<MatchUiState>.value(state),
        ),
        if (partyPassState != null)
          partyPassProvider.overrideWith(() => _FixedPartyPass(partyPassState)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: buildWhoTookTheme(Brightness.light),
        home: child,
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

class _FixedPartyPass extends PartyPassController {
  _FixedPartyPass(this._value);

  final PartyPassState _value;

  @override
  Future<PartyPassState> build() async => _value;
}

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
