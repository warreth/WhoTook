import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/game_skin.dart';
import '../../../core/theme/whotook_theme.dart';
import '../../../l10n/l10n.dart';
import '../../widgets/game_background.dart';
import '../../widgets/game_widgets.dart';

/// Shared header, step rail and bottom action for the four host setup screens.
class SetupScaffold extends StatelessWidget {
  const SetupScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryEnabled = true,
    this.busy = false,
    this.notice,
  });

  final int step;
  final String title;
  final String subtitle;
  final Widget child;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool primaryEnabled;
  final bool busy;
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GameBackdrop(
        mode: GameMode.classic,
        lobby: true,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s8,
                      AppSpacing.s8,
                      AppSpacing.s20,
                      0,
                    ),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          tooltip: context.l10n.back,
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        Expanded(
                          child: Text(
                            context.l10n.hostAGameTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: colors.ink2,
                            ),
                          ),
                        ),
                        StickerBadge(
                          label: context.l10n.stepOf(step),
                          background: colors.raised,
                          foreground: colors.ink,
                          angle: 0.03,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s20,
                      AppSpacing.s8,
                      AppSpacing.s20,
                      0,
                    ),
                    child: _StepRail(step: step),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s20,
                        AppSpacing.s12,
                        AppSpacing.s20,
                        AppSpacing.s24,
                      ),
                      children: <Widget>[
                        Text(
                          title,
                          style: gameDisplay(
                            size: 34,
                            height: 1.02,
                            color: colors.ink,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: colors.ink2,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s20),
                        child,
                        if (notice != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.s12),
                          notice!,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.s20,
          AppSpacing.s8,
          AppSpacing.s20,
          AppSpacing.s16,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SizedBox(
                  width: double.infinity,
                  child: GameButton(
                    label: primaryLabel,
                    onPressed: primaryEnabled && !busy ? onPrimary : null,
                    fullWidth: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRail extends StatelessWidget {
  const _StepRail({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return ExcludeSemantics(
      child: Row(
        children: <Widget>[
          for (var i = 1; i <= 3; i++)
            Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                decoration: BoxDecoration(
                  color: i <= step ? colors.accent : colors.raised,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
