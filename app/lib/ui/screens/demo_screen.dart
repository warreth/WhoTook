import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/theme/game_skin.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/game_background.dart';
import '../widgets/game_widgets.dart';
import '../widgets/mode_picker.dart';
import 'demo_game_screen.dart';

/// Launcher for the offline demo. The demo itself runs the production host and
/// three production clients over an in-process transport, so the screens,
/// rules and new features are the real game.
class DemoScreen extends ConsumerStatefulWidget {
  const DemoScreen({super.key});

  @override
  ConsumerState<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends ConsumerState<DemoScreen> {
  GameMode _mode = GameMode.mixedParty;

  @override
  Widget build(BuildContext context) {
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
        color: GameModeSkin.forMode(_mode).base,
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
                        builder: (_) => DemoGameScreen(
                          settings: settings,
                          locale: locale,
                          config: MatchConfig(
                            roundsK: 5,
                            roundSeconds: GamePace.fast.mainSeconds(_mode),
                            mode: _mode,
                            pace: GamePace.fast,
                          ),
                        ),
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
        mode: _mode,
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
                  SectionLabel(l10n.modeLabel),
                  const SizedBox(height: AppSpacing.s8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth - AppSpacing.s8) / 2;
                      return Wrap(
                        spacing: AppSpacing.s8,
                        runSpacing: AppSpacing.s8,
                        children: <Widget>[
                          for (final mode in playableGameModes)
                            SizedBox(
                              width: width,
                              child: _DemoModeChip(
                                mode: mode,
                                selected: mode == _mode,
                                onTap: () => setState(() => _mode = mode),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    l10n.demoTryModes,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: colors.ink2,
                    ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoModeChip extends StatelessWidget {
  const _DemoModeChip({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final GameMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final info = modeInfo(mode);
    return Semantics(
      button: true,
      selected: selected,
      label: modeLabel(l10n, mode),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? GamePalette.gold : colors.card,
            borderRadius: BorderRadius.circular(AppRadii.rControl),
            border: Border.all(color: colors.ink, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colors.ink,
                offset: const Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Icon(
                info.icon,
                size: 17,
                color: selected ? GamePalette.onGold : colors.ink2,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  modeLabel(l10n, mode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? GamePalette.onGold : colors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
