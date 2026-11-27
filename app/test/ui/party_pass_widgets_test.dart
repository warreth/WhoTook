import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/party_pass/party_pass_controller.dart';
import 'package:whotook/core/party_pass/purchase_service.dart';
import 'package:whotook/core/party_pass/room_theme.dart';
import 'package:whotook/core/party_pass/sound_effect.dart';
import 'package:whotook/core/storage/settings_repository.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/state/providers.dart';
import 'package:whotook/ui/widgets/firewall_prompt.dart';
import 'package:whotook/ui/widgets/party_pass_bar.dart';
import 'package:whotook/ui/widgets/party_pass_sheet.dart';
import 'package:whotook/ui/widgets/room_theme_picker.dart';
import 'package:whotook/ui/widgets/soundboard_overlay.dart';

import '../support/test_photo_library.dart';

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
      matchCoordinatorProvider.overrideWith((ref) {
        final coordinator = MatchCoordinator(
          photos: TestPhotoLibrary(seed: 1),
          settings: SettingsRepository(),
          platformServices: false,
        );
        ref.onDispose(coordinator.dispose);
        return coordinator;
      }),
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
      _app(
        const PartyPassLobbyBar(),
        const PartyPassState(loading: false, priceLabel: '€2.99'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Classic Party'), findsOneWidget);
    expect(find.text('Soundboard'), findsOneWidget);
    expect(find.text('Optional'), findsOneWidget);
    expect(find.text('Same Wi-Fi'), findsOneWidget);
    expect(find.text('Optional: Play online & soundboard'), findsOneWidget);
    expect(find.text('Same Wi-Fi or hotspot is always free.'), findsOneWidget);
    expect(find.text('Party Pass (€2.99)'), findsOneWidget);
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
        const PartyPassState(
          loading: false,
          billingAvailable: true,
          priceLabel: '€2.99',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('WhoTook Party Pass'), findsOneWidget);
    expect(find.text('Play Anywhere'), findsOneWidget);
    expect(find.textContaining('Same Wi-Fi is always free'), findsOneWidget);
    expect(find.text('Live soundboard'), findsOneWidget);
    expect(find.text('Shared room themes'), findsOneWidget);
    expect(find.text('Unlock Forever, €2.99'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.text('Use your own TURN server'), findsOneWidget);
  });

  testWidgets('a build without billing points at the store', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        const PartyPassBottomSheet(verifyOnOpen: false),
        const PartyPassState(loading: false, billingAvailable: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('The store is not available in this build'),
      findsOneWidget,
    );
    expect(find.text('Get the store version'), findsOneWidget);
    expect(find.text('Unlock Forever, €2.99'), findsNothing);
    expect(find.text('I have a license key'), findsNothing);
  });

  testWidgets('an iOS paywall never links to the website', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _app(
          const PartyPassBottomSheet(verifyOnOpen: false),
          const PartyPassState(loading: false, billingAvailable: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('The store is not available in this build'),
        findsOneWidget,
      );
      // whotook.party sells the Party Pass through Paddle, so an App Store
      // build must not offer that link from the paywall.
      expect(find.text('Get the store version'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'a direct build offers Paddle and a license entry, never the store',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _app(
          const PartyPassBottomSheet(verifyOnOpen: false),
          const PartyPassState(
            loading: false,
            billingAvailable: true,
            billingKind: PartyPassBillingKind.paddle,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unlock Forever, €2.99'), findsOneWidget);
      expect(find.text('I have a license key'), findsOneWidget);
      expect(find.textContaining('The store is not available'), findsNothing);
      expect(find.text('Get the store version'), findsNothing);

      await tester.ensureVisible(find.text('I have a license key'));
      await tester.tap(find.text('I have a license key'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your Party Pass license'), findsOneWidget);
      expect(
        find.text('WT-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a direct build without checkout still accepts a license', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        const PartyPassBottomSheet(verifyOnOpen: false),
        const PartyPassState(
          loading: false,
          billingAvailable: false,
          billingKind: PartyPassBillingKind.paddle,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Online checkout is unavailable'),
      findsOneWidget,
    );
    expect(find.text('Unlock Forever, €2.99'), findsNothing);
    expect(find.text('I have a license key'), findsOneWidget);
    expect(find.text('Get the store version'), findsNothing);
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
    expect(find.text('Unlock Forever, €2.99'), findsNothing);
    expect(find.text('Restore purchases'), findsOneWidget);
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

  testWidgets('the blocked-network prompt offers the free Wi-Fi route first', (
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

    expect(find.text('This network blocks direct play'), findsOneWidget);
    expect(find.textContaining('Same Wi-Fi is always free'), findsOneWidget);
    expect(find.text('Play on Wi-Fi/Hotspot'), findsOneWidget);
    expect(find.text('Unlock Party Pass'), findsOneWidget);
  });

  testWidgets('a fair-use denial shows the quota copy and reset time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        const Stack(children: <Widget>[FirewallPromptOverlay()]),
        PartyPassState(
          active: true,
          loading: false,
          relayErrorCode: 'fair_use_limit_reached',
          relayRetryAtUtc: DateTime.utc(2026, 11, 17, 12),
          remainingMatchesToday: 0,
        ),
        match: _lobby().copyWith(
          firewallPrompt: true,
          firewallRelayAttempted: true,
          firewallRelayErrorCode: 'fair_use_limit_reached',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily relay limit reached'), findsOneWidget);
    expect(find.textContaining('Next allowance:'), findsOneWidget);
    expect(find.text('Retry now'), findsOneWidget);
  });

  testWidgets('the theme picker scrolls at large text on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      _app(
        const RoomThemePickerSheet(),
        const PartyPassState(
          active: true,
          billingAvailable: true,
          loading: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Room theme'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });

  testWidgets('tapping a theme previews it live and exposes Apply', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const RoomThemePickerSheet(),
        const PartyPassState(
          active: true,
          billingAvailable: true,
          loading: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(RoomThemePickerSheet)),
    );
    expect(container.read(roomThemePreviewProvider), isNull);

    await tester.tap(find.text('Midnight Arcade'));
    await tester.pumpAndSettle();

    expect(
      container.read(roomThemePreviewProvider),
      RoomThemeId.midnightArcade,
    );
    expect(find.textContaining('Apply Theme'), findsOneWidget);
    expect(find.textContaining('Revert'), findsNothing);
  });

  testWidgets('a locked theme previews with Unlock and Revert', (tester) async {
    await tester.pumpWidget(
      _app(const RoomThemePickerSheet(), const PartyPassState(loading: false)),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(RoomThemePickerSheet)),
    );
    await tester.tap(find.text('Cyber Neon'));
    await tester.pumpAndSettle();

    expect(container.read(roomThemePreviewProvider), RoomThemeId.cyberNeon);
    expect(find.textContaining('Unlock Party Pass'), findsOneWidget);
    await tester.tap(find.text('Revert'));
    await tester.pumpAndSettle();
    expect(container.read(roomThemePreviewProvider), isNull);
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
