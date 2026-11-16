import 'package:flutter/material.dart';

import '../../core/avatars.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import 'common.dart';

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
            label: context.l10n.avatarOption(kAvatarIds.indexOf(avatar) + 1),
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
                  child: Center(
                    child: PlayerAvatar(initial: '', avatar: avatar, size: 38),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
