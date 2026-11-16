import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/party_pass/party_pass_controller.dart';
import 'package:whotook/core/party_pass/room_theme.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/state/providers.dart';
import 'package:whotook/ui/widgets/common.dart';
import 'package:whotook/ui/widgets/game_widgets.dart';
import 'package:whotook/ui/widgets/party_pass_sheet.dart';
import 'package:whotook/ui/widgets/soundboard_overlay.dart';

const bool _enabled = bool.fromEnvironment(
  'PARTY_PASS_VISUALS',
  defaultValue: false,
);

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

MatchUiState _match({RoundPhase phase = RoundPhase.lobby}) => MatchUiState(
  isHosting: true,
  roomId: 'k8m2p9x4',
  localPlayerId: 'host',
  phase: phase,
  connectionMode: ConnectionMode.webrtcTurn,
);

Widget _app(
  Widget child, {
  required PartyPassState pass,
  MatchUiState? match,
  Stream<MatchUiState>? stateStream,
  RoomThemeId theme = RoomThemeId.classicParty,
}) {
  final brightness = theme.forcedBrightness ?? Brightness.light;
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      appSettingsProvider.overrideWith(
        () => _FixedSettings(const AppSettings(nickname: 'Bram')),
      ),
      partyPassProvider.overrideWith(() => _FixedPartyPass(pass)),
      matchStateProvider.overrideWith(
        (ref) => stateStream ?? Stream<MatchUiState>.value(match ?? _match()),
      ),
    ],
    child: MaterialApp(
      theme: buildWhoTookTheme(
        brightness,
        palette: theme.isClassic ? null : theme.palette(brightness),
      ),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    ),
  );
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.pump(const Duration(milliseconds: 150));
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('../.private_prototypes/screens')
      ..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final sans = FontLoader('DMSans')
      ..addFont(rootBundle.load('assets/fonts/DMSans.ttf'));
    final display = FontLoader('Fredoka')
      ..addFont(rootBundle.load('assets/fonts/Fredoka.ttf'));
    await display.load();
    final mono = FontLoader('JetBrainsMono')
      ..addFont(rootBundle.load('assets/fonts/JetBrainsMono.ttf'));
    await Future.wait(<Future<void>>[sans.load(), mono.load()]);
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
  });

  testWidgets('capture the Party Pass surfaces', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sheetKey = GlobalKey();
    await tester.pumpWidget(
      _app(
        RepaintBoundary(
          key: sheetKey,
          child: const PartyPassBottomSheet(verifyOnOpen: false),
        ),
        pass: const PartyPassState(loading: false, billingAvailable: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await _capture(tester, sheetKey, 'party_pass_sheet');

    final activeKey = GlobalKey();
    await tester.pumpWidget(
      _app(
        RepaintBoundary(
          key: activeKey,
          child: const PartyPassBottomSheet(verifyOnOpen: false),
        ),
        pass: const PartyPassState(
          active: true,
          loading: false,
          billingAvailable: true,
          remainingMatchesToday: 12,
          dailyLimit: 15,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await _capture(tester, activeKey, 'party_pass_active');

    final soundKey = GlobalKey();
    await tester.pumpWidget(
      _app(
        RepaintBoundary(
          key: soundKey,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(
                color: const Color(0xFF1F1B16).withValues(alpha: 0.06),
              ),
              const _SoundToastPreview(),
              const Positioned.fill(child: SoundboardPill()),
            ],
          ),
        ),
        pass: const PartyPassState(
          active: true,
          loading: false,
          billingAvailable: true,
        ),
        match: _match(phase: RoundPhase.guessing),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soundboard'));
    await tester.pumpAndSettle();
    await _capture(tester, soundKey, 'soundboard');

    for (final theme in RoomThemeId.values) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildWhoTookTheme(
            theme.forcedBrightness ?? Brightness.light,
            palette: theme.palette(theme.forcedBrightness ?? Brightness.light),
          ),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: RepaintBoundary(
            key: key,
            child: _ThemeShowcase(theme: theme),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await _capture(tester, key, 'theme_${theme.wireId}');
    }
  }, skip: !_enabled);
}

class _SoundToastPreview extends StatelessWidget {
  const _SoundToastPreview();

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Material(
            color: colors.ink,
            borderRadius: BorderRadius.circular(AppRadii.rControl),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s12,
                AppSpacing.s8,
                AppSpacing.s16,
                AppSpacing.s8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.volume_up, size: 16, color: colors.accent),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    l10n.soundPlayedToast('Lotte', l10n.soundAirhorn),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.bg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeShowcase extends StatelessWidget {
  const _ThemeShowcase({required this.theme});

  final RoomThemeId theme;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s20),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.yourRoom,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: colors.ink,
                    ),
                  ),
                ),
                Icon(Icons.close, color: colors.ink),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(
              roomThemeLabel(l10n, theme),
              style: TextStyle(
                fontSize: 30,
                height: 1.05,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.9,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              l10n.roomThemePickerBody,
              style: TextStyle(fontSize: 14, height: 1.4, color: colors.ink2),
            ),
            const SizedBox(height: AppSpacing.s16),
            SurfaceCard(
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.raised,
                          borderRadius: BorderRadius.circular(AppRadii.rSm),
                        ),
                        child: Text(
                          'ROOM k8m2p9x4',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 10,
                            color: colors.ink2,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.positive,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        l10n.relayStatusRelay,
                        style: TextStyle(fontSize: 12, color: colors.ink2),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: colors.raised,
                      borderRadius: BorderRadius.circular(AppRadii.rSm),
                      border: Border.all(color: colors.hairline),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.qr_code_2,
                        size: 112,
                        color: colors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.ios_share, size: 18, color: colors.ink2),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        l10n.shareInviteLink,
                        style: TextStyle(fontSize: 14, color: colors.ink),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(AppRadii.rCard),
                border: Border.all(color: colors.ink, width: 2.5),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black
                        : colors.ink,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s8,
                    children: <Widget>[
                      _Chip(
                        icon: Icons.palette_outlined,
                        label: l10n.lobbyThemeLabel,
                        value: roomThemeLabel(l10n, theme),
                      ),
                      _Chip(
                        icon: Icons.graphic_eq,
                        label: l10n.lobbySoundboardLabel,
                        value: l10n.lobbySoundboardOn,
                      ),
                      _Chip(
                        icon: Icons.public,
                        label: l10n.lobbyRelayLabel,
                        value: l10n.relayStatusRelay,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s8,
                    ),
                    decoration: BoxDecoration(
                      color: GamePalette.gold,
                      borderRadius: BorderRadius.circular(AppRadii.rControl),
                      border: Border.all(color: GamePalette.onGold, width: 2.5),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.workspace_premium,
                          size: 18,
                          color: GamePalette.onGold,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Text(
                          l10n.partyPassLobbyActive,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: GamePalette.onGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  for (final player in <String>['Bram', 'Lotte', 'Sam'])
                    ListTile(
                      minTileHeight: 48,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: colors.raised,
                        child: Text(
                          player[0],
                          style: TextStyle(fontSize: 12, color: colors.ink),
                        ),
                      ),
                      title: Text(
                        player,
                        style: TextStyle(fontSize: 14, color: colors.ink),
                      ),
                      trailing: Text(
                        player == 'Bram' ? l10n.hostLabel : l10n.ready,
                        style: TextStyle(fontSize: 12, color: colors.ink2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
            GameButton(
              label: l10n.startPhotoCheck,
              icon: Icons.photo_camera_outlined,
              fullWidth: true,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(AppRadii.rSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: colors.ink2),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: colors.ink3)),
          Text(':', style: TextStyle(fontSize: 11, color: colors.ink3)),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
