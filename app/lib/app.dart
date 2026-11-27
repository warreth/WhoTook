import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/models.dart';
import '../core/navigation.dart';
import '../core/party_pass/room_theme.dart';
import '../l10n/l10n.dart';
import '../core/theme/whotook_theme.dart';
import '../state/providers.dart';
import 'ui/deep_link_listener.dart';
import 'ui/playtest_bootstrap.dart';
import '../core/playtest_config.dart';
import 'ui/screens/onboarding_screen.dart';

class WhoTookApp extends ConsumerWidget {
  const WhoTookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final preference =
        settings.value?.themePreference ?? ThemePreference.system;
    final roomThemeId =
        ref.watch(
          matchStateProvider.select((value) => value.value?.roomThemeId),
        ) ??
        kDefaultRoomThemeId;
    final preview = ref.watch(roomThemePreviewProvider);
    final roomTheme = preview ?? RoomThemeId.fromWire(roomThemeId);
    final hasSharedTheme = !roomTheme.isClassic;
    final language = settings.value?.language ?? AppLanguage.system;
    final locale = switch (language) {
      AppLanguage.system => null,
      AppLanguage.english => const Locale('en'),
      AppLanguage.dutch => const Locale('nl'),
    };
    return MaterialApp(
      title: 'WhoTook',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildWhoTookTheme(
        Brightness.light,
        palette: hasSharedTheme ? roomTheme.palette(Brightness.light) : null,
      ),
      darkTheme: buildWhoTookTheme(
        Brightness.dark,
        palette: hasSharedTheme ? roomTheme.palette(Brightness.dark) : null,
      ),
      themeMode: switch (roomTheme.forcedBrightness) {
        Brightness.dark => ThemeMode.dark,
        Brightness.light => ThemeMode.light,
        null => switch (preference) {
          ThemePreference.system => ThemeMode.system,
          ThemePreference.light => ThemeMode.light,
          ThemePreference.dark => ThemeMode.dark,
        },
      },
      builder: (context, child) => child == null
          ? const SizedBox.shrink()
          : PlaytestConfig.enabled
          ? child
          : DeepLinkListener(child: child),
      home: settings.when(
        loading: () => const _BootScreen(),
        error: (error, stack) => const OnboardingScreen(),
        data: (value) => value.onboardingCompleted || PlaytestConfig.enabled
            ? const PlaytestBootstrap()
            : const OnboardingScreen(),
      ),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            WhoTookMark(size: 40, color: colors.accent),
            const SizedBox(height: AppSpacing.s16),
            Text('WhoTook', style: TextStyle(fontSize: 18, color: colors.ink2)),
          ],
        ),
      ),
    );
  }
}
