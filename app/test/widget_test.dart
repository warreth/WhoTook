import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/app.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/qr/invite_codec.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:whotook/core/storage/last_room_repository.dart';
import 'package:whotook/core/storage/settings_repository.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/state/providers.dart';
import 'package:whotook/ui/screens/join_confirm_screen.dart';

import 'support/test_photo_library.dart';

class _MemorySettings extends SettingsRepository {
  _MemorySettings(this.initial);

  final AppSettings initial;

  @override
  Future<AppSettings> load() async => initial;

  @override
  Future<void> save(AppSettings settings) async {}
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<void> usePhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('shows onboarding on first run', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _MemorySettings(const AppSettings()),
          ),
        ],
        child: const WhoTookApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guess whose photo it is'), findsOneWidget);
    expect(find.text('Same Wi-Fi is always free'), findsOneWidget);
    expect(find.textContaining('Play Anywhere is optional'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Continue'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Continue'), findsOneWidget);
    expect(
      find.textContaining('I agree to the Terms of use and Community rules'),
      findsOneWidget,
    );
  });

  testWidgets('onboarding requires terms before continuing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _MemorySettings(const AppSettings()),
          ),
          photoLibraryProvider.overrideWithValue(TestPhotoLibrary()),
        ],
        child: const WhoTookApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Bram');
    await tester.scrollUntilVisible(
      find.byType(Checkbox),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Continue'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Host a game'), findsOneWidget);
  });

  testWidgets('home offers the last joined room again', (tester) async {
    await usePhone(tester);
    await LastRoomRepository().remember(
      LastRoom(
        inviteUrl: 'https://whotook.party/j#abc',
        roomId: 'k8m2p9x4',
        playerId: 'p_test',
        playerToken: 'token_test',
        joinedAtUtc: DateTime.now().toUtc(),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _MemorySettings(const AppSettings(onboardingCompleted: true)),
          ),
        ],
        child: const WhoTookApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Last room'), findsOneWidget);
    expect(find.textContaining('k8m2p9x4'), findsOneWidget);

    await tester.tap(find.byTooltip('Forget this room'));
    await tester.pumpAndSettle();
    expect(find.text('Last room'), findsNothing);
    expect(await LastRoomRepository().load(), isNull);
  });

  testWidgets('the join checkpoint shows the saved identity', (tester) async {
    await usePhone(tester);
    final invite = encodeInviteUrl(
      const InvitePayload(
        roomId: 'k8m2p9x4',
        hostId: 'host',
        secret: '0123456789abcdef0123456789abcdef',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _MemorySettings(
              const AppSettings(
                nickname: 'Bram',
                avatar: 'rocket',
                onboardingCompleted: true,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData.light(),
          home: JoinConfirmScreen(invite: invite),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Joining as'), findsOneWidget);
    expect(find.text('Join the room'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      'Bram',
    );
  });

  testWidgets('a lost connection shows the reconnect overlay', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _MemorySettings(const AppSettings(onboardingCompleted: true)),
          ),
          matchStateProvider.overrideWith(
            (ref) => Stream<MatchUiState>.value(
              const MatchUiState(
                roomId: 'k8m2p9x4',
                reconnecting: true,
                reconnectSecondsLeft: 12,
              ),
            ),
          ),
        ],
        child: const WhoTookApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Connection lost'), findsOneWidget);
    expect(find.textContaining('12 seconds'), findsOneWidget);
    expect(find.text('Leave room'), findsOneWidget);
  });

  testWidgets('a screenshot alert names the player on every screen', (
    tester,
  ) async {
    await usePhone(tester);
    final states = StreamController<MatchUiState>.broadcast();
    addTearDown(states.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _MemorySettings(const AppSettings(onboardingCompleted: true)),
          ),
          matchStateProvider.overrideWith((ref) => states.stream),
        ],
        child: const WhoTookApp(),
      ),
    );
    await tester.pump();
    states.add(const MatchUiState());
    await tester.pump();
    states.add(
      const MatchUiState(
        screenshotAlerts: <ScreenshotBanner>[
          ScreenshotBanner(playerId: 'c1', playerName: 'Lotte', atMs: 1234),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Lotte took a screenshot'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Lotte took a screenshot'), findsNothing);
  });

  testWidgets('a version mismatch can be skipped', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _MemorySettings(const AppSettings(onboardingCompleted: true)),
          ),
          matchStateProvider.overrideWith(
            (ref) => Stream<MatchUiState>.value(
              const MatchUiState(
                versionWarning: VersionWarning(
                  latestVersion: '1.7.0',
                  latestBuild: 11,
                  ownVersion: '1.6.0',
                  ownBuild: 10,
                ),
              ),
            ),
          ),
        ],
        child: const WhoTookApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Different app versions'), findsOneWidget);
    expect(find.textContaining('1.7.0'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Keep playing'));
    await tester.pumpAndSettle();
    expect(find.text('Different app versions'), findsNothing);
  });

  testWidgets('host and join are the only two actions on home', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _MemorySettings(const AppSettings(onboardingCompleted: true)),
          ),
        ],
        child: const WhoTookApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Host a game'), findsOneWidget);
    expect(find.text('Join a game'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });
}
