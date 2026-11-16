import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/party_pass/party_pass_controller.dart';
import '../../core/party_pass/room_theme.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import 'party_pass_sheet.dart';

Future<void> showRoomThemePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const RoomThemePickerSheet(),
  );
}

class RoomThemePickerSheet extends ConsumerWidget {
  const RoomThemePickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final pass =
        ref.watch(partyPassProvider).value ?? const PartyPassState();
    final selected = RoomThemeId.fromWire(state.roomThemeId);

    Future<void> choose(RoomThemeId theme) async {
      if (theme.premium && !pass.active) {
        Navigator.of(context).pop();
        await showPartyPassSheet(context);
        return;
      }
      await coordinator.setRoomTheme(theme);
      if (context.mounted) Navigator.of(context).pop();
    }

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.s12,
          0,
          AppSpacing.s12,
          AppSpacing.s12,
        ),
        padding: const EdgeInsets.all(AppSpacing.s20),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadii.rModal),
          border: Border.all(color: colors.ink, width: 2.5),
          boxShadow: <BoxShadow>[
            BoxShadow(color: colors.ink, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.roomThemePickerTitle,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: colors.ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.close,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 22),
                ),
              ],
            ),
            Text(
              l10n.roomThemePickerBody,
              style: TextStyle(fontSize: 13, height: 1.4, color: colors.ink2),
            ),
            const SizedBox(height: AppSpacing.s16),
            for (final theme in RoomThemeId.values) ...<Widget>[
              _ThemeChoice(
                theme: theme,
                selected: theme == selected,
                unlocked: !theme.premium || pass.active,
                onTap: () => choose(theme),
              ),
              if (theme != RoomThemeId.values.last)
                const SizedBox(height: AppSpacing.s8),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.theme,
    required this.selected,
    required this.unlocked,
    required this.onTap,
  });

  final RoomThemeId theme;
  final bool selected;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brightness = theme.forcedBrightness ?? Theme.of(context).brightness;
    final palette = theme.palette(brightness);
    final shadow = brightness == Brightness.dark ? Colors.black : palette.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: selected
          ? '${roomThemeLabel(l10n, theme)}, ${l10n.roomThemeSelected}'
          : roomThemeLabel(l10n, theme),
      child: Material(
        color: selected ? palette.raised : palette.card,
        borderRadius: BorderRadius.circular(AppRadii.rControl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.rControl),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s12,
              AppSpacing.s8,
              AppSpacing.s12,
              AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.rControl),
              border: Border.all(
                color: selected ? palette.accent : palette.ink,
                width: selected ? 2.5 : 2,
              ),
              boxShadow: selected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: shadow,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: <Widget>[
                _Swatch(palette: palette),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        roomThemeLabel(l10n, theme),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                        ),
                      ),
                      Text(
                        theme.premium
                            ? (unlocked
                                  ? l10n.roomThemePremium
                                  : l10n.roomThemeLocked)
                            : l10n.roomThemeFree,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: palette.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Icon(
                  selected
                      ? Icons.check_circle
                      : unlocked
                      ? Icons.circle_outlined
                      : Icons.lock_outline,
                  size: 20,
                  color: selected ? palette.accent : palette.ink3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.palette});

  final WhoTookColors palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 34,
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(AppRadii.rSm),
        border: Border.all(color: palette.ink, width: 2),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: ColoredBox(color: palette.accent)),
          Expanded(child: ColoredBox(color: palette.accent2)),
          Expanded(child: ColoredBox(color: palette.raised)),
        ],
      ),
    );
  }
}
