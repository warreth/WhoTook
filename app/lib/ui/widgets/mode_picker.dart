import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';

class ModeInfo {
  const ModeInfo({
    required this.label,
    required this.blurb,
    required this.icon,
  });

  final String label;
  final String blurb;
  final IconData icon;
}

ModeInfo modeInfo(GameMode mode) => switch (mode) {
  GameMode.classic => const ModeInfo(
    label: 'Classic',
    blurb: 'Guess who took it.',
    icon: Icons.photo_camera_outlined,
  ),
  GameMode.captionThis => const ModeInfo(
    label: 'Caption This',
    blurb: 'Write the funniest caption.',
    icon: Icons.chat_bubble_outline,
  ),
  GameMode.timeTraveler => const ModeInfo(
    label: 'Time Traveler',
    blurb: 'Guess the year and month.',
    icon: Icons.history,
  ),
  GameMode.mixedParty => const ModeInfo(
    label: 'Mixed Party',
    blurb: 'All three, shuffled.',
    icon: Icons.shuffle,
  ),
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
        for (final value in GameMode.values)
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
    final info = modeInfo(mode);
    return Semantics(
      selected: selected,
      button: true,
      label: '${info.label}. ${info.blurb}',
      child: Material(
        color: selected ? colors.raised : colors.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.rCard),
          side: BorderSide(
            color: selected ? colors.accent : colors.hairline,
            width: selected ? 1.5 : 1,
          ),
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
                        color: selected ? colors.accent : colors.raised,
                        borderRadius: BorderRadius.circular(AppRadii.rSm),
                      ),
                      child: Icon(
                        info.icon,
                        size: 18,
                        color: selected ? colors.onAccent : colors.ink2,
                      ),
                    ),
                    const Spacer(),
                    if (selected)
                      Icon(Icons.check_circle, size: 18, color: colors.accent)
                    else
                      Icon(Icons.circle_outlined, size: 18, color: colors.ink3),
                  ],
                ),
                const Spacer(),
                Text(
                  info.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  info.blurb,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    color: colors.ink2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
