import 'package:flutter/material.dart';

import '../../core/avatars.dart';
import '../../core/theme/whotook_theme.dart';

IconData avatarIcon(String avatar) => switch (avatar) {
  'face' => Icons.face_outlined,
  'pizza' => Icons.local_pizza_outlined,
  'music' => Icons.music_note_outlined,
  'game' => Icons.sports_esports_outlined,
  'rocket' => Icons.rocket_launch_outlined,
  'star' => Icons.star_outline,
  'plant' => Icons.local_florist_outlined,
  _ => Icons.pets_outlined,
};

class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Wrap(
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s8,
      children: <Widget>[
        for (final avatar in kAvatarIds)
          Semantics(
            selected: avatar == selected,
            button: true,
            label: 'Avatar $avatar',
            child: Material(
              color: avatar == selected ? colors.raised : colors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.rControl),
                side: BorderSide(
                  color: avatar == selected ? colors.accent : colors.hairline,
                ),
              ),
              child: InkWell(
                onTap: () => onSelect(avatar),
                borderRadius: BorderRadius.circular(AppRadii.rControl),
                child: SizedBox.square(
                  dimension: 48,
                  child: Icon(
                    avatarIcon(avatar),
                    size: 22,
                    color: avatar == selected ? colors.accent : colors.ink2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
