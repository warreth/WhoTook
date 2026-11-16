import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/build_flavor.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/party_pass/party_pass_controller.dart';
import 'package:whotook/core/party_pass/sound_effect.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/state/providers.dart';
import 'package:whotook/ui/widgets/custom_turn_section.dart';
import 'package:whotook/ui/widgets/firewall_prompt.dart';
import 'package:whotook/ui/widgets/party_pass_bar.dart';
import 'package:whotook/ui/widgets/party_pass_sheet.dart';
import 'package:whotook/ui/widgets/soundboard_overlay.dart';

class _FixedSettings extends AppSettingsController {
  _FixedSettings(this.value);

  final AppSettings value;

  @override
  Future<AppSettings> build() async => value;
}

class _FixedPartyPass extends PartyPassController {
  _FixedPartyPass(this.value);

  final PartyPassState value;

  @override
  Future<PartyPassState> build() async => value;
}

MatchUiState _lobby() => const MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  connectionMode: ConnectionMode.localLan,
);

MatchUiState _round() => const MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  phase: RoundPhase.guessing,
  connectionMode: ConnectionMode.webrtcTurn,
  lastSoundEffect: SoundEffectEvent(
    playerId: 'host',
    playerName: 'Bram',
    sound: PartySound.airhorn,
    atMs: 1,
  ),
);

Widget _app(
  Widget child,
  PartyPassState pass, {
  MatchUiState? match,
  AppSettings settings = const AppSettings(nickname: 'Bram'),
}) {
  return ProviderScope(
    overrides: [
      appSettingsProvider.overrideWith(() => _FixedSettings(settings)),
      partyPassProvider.overrideWith(() => _FixedPartyPass(pass)),
      matchStateProvider.overrideWith(
        (ref) => Stream<MatchUiState>.value(match ?? _lobby()),
      ),
    ],
    child: MaterialApp(
      theme: buildWhoTookTheme(Brightness.light),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('lobby bar shows the free theme, soundboard and relay state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const PartyPassLobbyBar(), const PartyPassState(loading: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Classic Party'), findsOneWidget);
    expect(find.text('Soundboard'), findsOneWidget);
    expect(find.text('Pass only'), findsOneWidget);
    expect(find.text('Same Wi-Fi'), findsOneWidget);
    if (BuildFlavor.foss) {
      expect(find.text('Use your own TURN server'), findsOneWidget);
    } else {
      expect(find.text('Party Pass (€2.99)'), findsOneWidget);
    }
  });

  testWidgets('the pass sheet lists every perk, restore and the price', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        const PartyPassBottomSheet(verifyOnOpen: false),
        const PartyPassState(loading: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('WhoTook Party Pass'), findsOneWidget);
    expect(find.text('5G & firewall relay'), findsOneWidget);
    expect(find.text('Live soundboard'), findsOneWidget);
    expect(find.text('Shared room themes'), findsOneWidget);
    expect(find.text('Unlock Forever — €2.99'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.text('Use your own TURN server'), findsOneWidget);
  });

  testWidgets('an active pass shows the allowance and no unlock button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const PartyPassBottomSheet(verifyOnOpen: false),
        const PartyPassState(
          active: true,
          billingAvailable: true,
          remainingMatchesToday: 12,
          dailyLimit: 15,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Party Pass Active'), findsOneWidget);
    expect(find.text('12 of 15 relay matches left today'), findsOneWidget);
    expect(find.text('Unlock Forever — €2.99'), findsNothing);
    expect(find.text('Restore purchases'), findsOneWidget);
  });

  testWidgets('a FOSS build includes the features and points at self-hosting', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const PartyPassBottomSheet(verifyOnOpen: false),
        const PartyPassState(
          active: true,
          fossIncluded: true,
          remainingMatchesToday: 0,
          dailyLimit: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Included in this FOSS build'), findsOneWidget);
    expect(find.text('Use your own TURN server'), findsOneWidget);
    expect(find.text('Unlock Forever — €2.99'), findsNothing);
  });

  testWidgets('the soundboard expands with all six sounds', (tester) async {
    await tester.pumpWidget(
      _app(
        const SoundboardPill(),
        const PartyPassState(
          active: true,
          billingAvailable: true,
          loading: false,
        ),
        match: _round(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Soundboard'), findsOneWidget);
    await tester.tap(find.text('Soundboard'));
    await tester.pumpAndSettle();

    for (final label in <String>[
      'Vine Boom',
      'Airhorn',
      'Crickets',
      'Sad Trombone',
      'Drumroll',
      'Laugh Track',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Tap a sound. Everyone hears it.'), findsOneWidget);
  });

  testWidgets('the soundboard is hidden without a pass', (tester) async {
    await tester.pumpWidget(
      _app(const SoundboardPill(), const PartyPassState(), match: _round()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Soundboard'), findsNothing);
  });

  testWidgets('the 5G prompt offers the free Wi-Fi route first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        const Stack(children: <Widget>[FirewallPromptOverlay()]),
        const PartyPassState(),
        match: _lobby().copyWith(firewallPrompt: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Strict 5G firewall detected!'), findsOneWidget);
    if (BuildFlavor.foss) {
      expect(find.text('Set up custom TURN'), findsOneWidget);
      expect(find.text('Unlock Party Pass'), findsNothing);
    } else {
      expect(find.text('Play on Wi-Fi/Hotspot'), findsOneWidget);
      expect(find.text('Unlock Party Pass'), findsOneWidget);
    }
  });

  testWidgets('the FOSS self-host form has URI, username and password', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const SingleChildScrollView(child: CustomTurnSection()),
        const PartyPassState(active: true, fossIncluded: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Custom TURN Server (Self-Host)'), findsOneWidget);
    expect(find.text('TURN URI'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('the lobby bar opens the theme picker', (tester) async {
    await tester.pumpWidget(
      _app(
        const PartyPassLobbyBar(),
        const PartyPassState(
          active: true,
          billingAvailable: true,
          loading: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Classic Party'));
    await tester.pumpAndSettle();
    expect(find.text('Room theme'), findsOneWidget);
    expect(find.text('Midnight Arcade'), findsOneWidget);
    expect(find.text('Cyber Neon'), findsOneWidget);
    expect(find.text('Retro Polaroid 90s'), findsOneWidget);
    expect(find.text('Pub / Kroeg Mode'), findsOneWidget);
  });
}
