import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/theme/game_skin.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/game_background.dart';
import 'demo_game_screen.dart';

/// Launcher for the offline demo. The demo itself runs the production host and
/// three production clients over an in-process transport, so the screens,
/// rules and new features are the real game.
class DemoScreen extends ConsumerWidget {
  const DemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final locale = Localizations.localeOf(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.reviewDemo),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.closeDemo,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      bottomNavigationBar: ColoredBox(
        color: GameModeSkin.lobby.base,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(
            AppSpacing.s20,
            AppSpacing.s8,
            AppSpacing.s20,
            AppSpacing.s16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: l10n.startDemo,
                  icon: Icons.play_arrow_rounded,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            DemoGameScreen(settings: settings, locale: locale),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(l10n.close),
              ),
            ],
          ),
        ),
      ),
      body: GameBackdrop(
        mode: GameMode.mixedParty,
        lobby: true,
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s20,
                  AppSpacing.s16,
                  AppSpacing.s20,
                  AppSpacing.s24,
                ),
                children: <Widget>[
                  Text(
                    l10n.demoIntroTitle,
                    style: gameDisplay(size: 32, color: colors.ink),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    l10n.demoIntroBody,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: colors.ink2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  NoticeBanner(
                    message: l10n.demoIntroNotice,
                    icon: Icons.science_outlined,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.demoLineup,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        Row(
                          children: <Widget>[
                            PlayerAvatar(
                              initial: settings.nickname.trim().isEmpty
                                  ? 'Jij'
                                  : settings.nickname.trim(),
                              avatar: 'rocket',
                              isHost: true,
                              size: 44,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            for (final bot in const <(String, String)>[
                              ('Lotte', 'star'),
                              ('Sam', 'music'),
                              ('Noor', 'plant'),
                            ]) ...[
                              PlayerAvatar(
                                initial: bot.$1,
                                avatar: bot.$2,
                                size: 44,
                              ),
                              const SizedBox(width: AppSpacing.s8),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        Text(
                          l10n.demoBotRoles,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: colors.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    l10n.demoTryModes,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: colors.ink2,
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
