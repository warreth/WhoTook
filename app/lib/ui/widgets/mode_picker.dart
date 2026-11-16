import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import 'game_widgets.dart';

class ModeInfo {
  const ModeInfo({required this.icon});

  final IconData icon;
}

const List<GameMode> playableGameModes = <GameMode>[
  GameMode.classic,
  GameMode.makeItMeme,
  GameMode.timeTraveler,
  GameMode.mixedParty,
];

ModeInfo modeInfo(GameMode mode) => ModeInfo(
  icon: switch (mode) {
    GameMode.classic => Icons.photo_camera_outlined,
    GameMode.captionThis => Icons.chat_bubble_outline,
    GameMode.makeItMeme => Icons.emoji_emotions_outlined,
    GameMode.timeTraveler => Icons.history,
    GameMode.mixedParty => Icons.shuffle,
  },
);

String modeLabel(AppLocalizations l10n, GameMode mode) => switch (mode) {
  GameMode.classic => l10n.modeClassic,
  GameMode.captionThis => l10n.modeCaptionThis,
  GameMode.makeItMeme => l10n.modeMakeItMeme,
  GameMode.timeTraveler => l10n.modeTimeTraveler,
  GameMode.mixedParty => l10n.modeMixedParty,
};

String modeBlurb(AppLocalizations l10n, GameMode mode) => switch (mode) {
  GameMode.classic => l10n.modeClassicBlurb,
  GameMode.captionThis => l10n.modeCaptionThisBlurb,
  GameMode.makeItMeme => l10n.modeMakeItMemeBlurb,
  GameMode.timeTraveler => l10n.modeTimeTravelerBlurb,
  GameMode.mixedParty => l10n.modeMixedPartyBlurb,
};

/// The host's 2x2 mode picker. The selected card carries the accent border.
class ModePicker extends StatelessWidget {
  const ModePicker({super.key, required this.mode, required this.onSelect});

  final GameMode mode;
  final ValueChanged<GameMode> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.s12,
      crossAxisSpacing: AppSpacing.s12,
      childAspectRatio: 1.14,
      children: <Widget>[
        for (final value in playableGameModes)
          _ModeTile(
            mode: value,
            selected: value == mode,
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              onSelect(value);
            },
          ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
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
    final label = modeLabel(l10n, mode);
    final blurb = modeBlurb(l10n, mode);
    final ink = selected ? GamePalette.onGold : colors.ink;
    final ink2 = selected ? GamePalette.onGoldMuted : colors.ink2;
    return Semantics(
      selected: selected,
      button: true,
      label: l10n.modeSemantic(label, blurb),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.rCard),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: selected ? GamePalette.onGold : colors.ink,
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: selected ? GamePalette.gold : colors.card,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.rCard),
            side: BorderSide(color: ink, width: 2),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? GamePalette.onGold : colors.raised,
                          borderRadius: BorderRadius.circular(AppRadii.rSm),
                        ),
                        child: Icon(
                          info.icon,
                          size: 18,
                          color: selected ? GamePalette.gold : colors.ink2,
                        ),
                      ),
                      const Spacer(),
                      if (selected)
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: GamePalette.onGold,
                        )
                      else
                        Icon(
                          Icons.circle_outlined,
                          size: 18,
                          color: colors.ink3,
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    blurb,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, height: 1.25, color: ink2),
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
