import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/party_pass/party_pass_controller.dart';
import '../../core/party_pass/room_theme.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import 'game_widgets.dart';
import 'party_pass_sheet.dart';

Future<void> showRoomThemePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const RoomThemePickerSheet(),
  );
}

class RoomThemePickerSheet extends ConsumerStatefulWidget {
  const RoomThemePickerSheet({super.key});

  @override
  ConsumerState<RoomThemePickerSheet> createState() =>
      _RoomThemePickerSheetState();
}

class _RoomThemePickerSheetState extends ConsumerState<RoomThemePickerSheet> {
  RoomThemeId? _preview;
  bool _applied = false;
  late final RoomThemePreview _previewNotifier;

  @override
  void initState() {
    super.initState();
    _previewNotifier = ref.read(roomThemePreviewProvider.notifier);
  }

  @override
  void dispose() {
    if (!_applied) {
      // Closing the sheet without applying always puts the room back on its
      // real theme, including a locked preview the player was only admiring.
      _previewNotifier.set(null);
    }
    super.dispose();
  }

  void _showPreview(RoomThemeId theme) {
    _previewNotifier.set(theme);
    setState(() => _preview = theme);
  }

  Future<void> _revert() async {
    _previewNotifier.set(null);
    if (mounted) setState(() => _preview = null);
  }

  Future<void> _apply(RoomThemeId theme, bool unlocked) async {
    if (!unlocked) return;
    final coordinator = ref.read(matchCoordinatorProvider);
    _applied = true;
    _previewNotifier.set(null);
    await coordinator.setRoomTheme(theme);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.roomThemeApplied)));
  }

  Future<void> _unlock(RoomThemeId theme) async {
    await _revert();
    if (!mounted) return;
    await showPartyPassSheet(context);
    if (!mounted) return;
    final active = ref.read(partyPassProvider).value?.active ?? false;
    if (active) await _apply(theme, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final pass = ref.watch(partyPassProvider).value ?? const PartyPassState();
    final selected = RoomThemeId.fromWire(state.roomThemeId);
    final preview = _preview;
    final previewUnlocked =
        preview != null && (!preview.premium || pass.active);

    ref.listen(matchStateProvider, (previous, next) {
      final value = next.value;
      if (_preview == null || value == null) return;
      if (value.roomId != null && value.phase != RoundPhase.lobby) {
        unawaited(_revert());
        if (mounted) Navigator.of(context).maybePop();
      }
    });

    final price = pass.priceLabel ?? '€2.99';

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.s12,
          0,
          AppSpacing.s12,
          AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadii.rModal),
          border: Border.all(color: colors.ink, width: 2.5),
          boxShadow: <BoxShadow>[
            BoxShadow(color: colors.ink, offset: const Offset(0, 5)),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.s20),
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
                                fontWeight: FontWeight.w800,
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
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: colors.ink2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        l10n.roomThemePreviewHint,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      SizedBox(
                        height: 232,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              for (final theme
                                  in RoomThemeId.values) ...<Widget>[
                                _ThemePreviewCard(
                                  theme: theme,
                                  selected: theme == selected,
                                  previewing: theme == preview,
                                  unlocked: !theme.premium || pass.active,
                                  onTap: () => _showPreview(theme),
                                ),
                                if (theme != RoomThemeId.values.last)
                                  const SizedBox(width: AppSpacing.s8),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (preview != null)
                _PreviewBanner(
                  theme: preview,
                  unlocked: previewUnlocked,
                  price: price,
                  onApply: () => _apply(preview, previewUnlocked),
                  onUnlock: () => _unlock(preview),
                  onRevert: _revert,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.theme,
    required this.selected,
    required this.previewing,
    required this.unlocked,
    required this.onTap,
  });

  final RoomThemeId theme;
  final bool selected;
  final bool previewing;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brightness = theme.forcedBrightness ?? Theme.of(context).brightness;
    final palette = theme.palette(brightness);
    final active = previewing || selected;
    final shadow = brightness == Brightness.dark ? Colors.black : palette.ink;
    return Semantics(
      button: true,
      selected: active,
      label: selected
          ? '${roomThemeLabel(l10n, theme)}, ${l10n.roomThemeSelected}'
          : roomThemeLabel(l10n, theme),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 158,
          decoration: BoxDecoration(
            color: palette.bg,
            borderRadius: BorderRadius.circular(AppRadii.rControl),
            border: Border.all(
              color: active ? palette.accent : palette.ink,
              width: active ? 3 : 2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: shadow,
                offset: Offset(0, active ? 5 : 3),
                blurRadius: 0,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CustomPaint(
                      painter: _ThemePatternPainter(
                        background: palette.bg,
                        accent: palette.accent,
                        accent2: palette.accent2,
                        raised: palette.raised,
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 24,
                      bottom: 26,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: palette.card,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: palette.ink, width: 1.6),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: shadow,
                              offset: const Offset(0, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: palette.accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: palette.ink,
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Container(
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: palette.ink,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 5,
                              width: 62,
                              decoration: BoxDecoration(
                                color: palette.ink2,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              height: 4,
                              width: 48,
                              decoration: BoxDecoration(
                                color: palette.raised,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Container(
                                    height: 13,
                                    decoration: BoxDecoration(
                                      color: palette.accent,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Container(
                                    height: 13,
                                    decoration: BoxDecoration(
                                      color: palette.accent2,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 7,
                      right: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? palette.accent
                              : (unlocked ? palette.card : palette.ink),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: palette.ink, width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              unlocked ? Icons.check : Icons.lock,
                              size: 9,
                              color: active || !unlocked
                                  ? (active ? palette.onAccent : palette.bg)
                                  : palette.ink,
                            ),
                            if (active) ...<Widget>[
                              const SizedBox(width: 2),
                              Text(
                                l10n.roomThemePreviewBadge,
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 6,
                                  fontWeight: FontWeight.w800,
                                  color: palette.onAccent,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                decoration: BoxDecoration(
                  color: palette.card,
                  border: Border(
                    top: BorderSide(color: palette.ink, width: 1.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      roomThemeLabel(l10n, theme),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                    Text(
                      theme.premium
                          ? (unlocked
                                ? l10n.roomThemePremium
                                : l10n.roomThemeLocked)
                          : l10n.roomThemeFree,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8,
                        height: 1.25,
                        color: palette.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePatternPainter extends CustomPainter {
  const _ThemePatternPainter({
    required this.background,
    required this.accent,
    required this.accent2,
    required this.raised,
  });

  final Color background;
  final Color accent;
  final Color accent2;
  final Color raised;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.18)
      ..strokeWidth = 5;
    for (var x = -size.height; x < size.width; x += 22) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.2),
      22,
      Paint()..color = accent.withValues(alpha: 0.28),
    );
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.78),
      16,
      Paint()..color = accent2.withValues(alpha: 0.25),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 9, size.width, 9),
      Paint()..color = raised,
    );
  }

  @override
  bool shouldRepaint(covariant _ThemePatternPainter oldDelegate) =>
      oldDelegate.background != background ||
      oldDelegate.accent != accent ||
      oldDelegate.accent2 != accent2 ||
      oldDelegate.raised != raised;
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner({
    required this.theme,
    required this.unlocked,
    required this.price,
    required this.onApply,
    required this.onUnlock,
    required this.onRevert,
  });

  final RoomThemeId theme;
  final bool unlocked;
  final String price;
  final VoidCallback onApply;
  final VoidCallback onUnlock;
  final VoidCallback onRevert;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s12,
        AppSpacing.s16,
        AppSpacing.s16,
      ),
      decoration: BoxDecoration(
        color: colors.raised,
        border: Border(top: BorderSide(color: colors.ink, width: 2)),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadii.rModal),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.roomThemePreviewing(roomThemeLabel(l10n, theme)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.ink2,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          if (unlocked)
            GameButton(
              label: l10n.roomThemeApply,
              onPressed: onApply,
              fullWidth: true,
              icon: Icons.check,
            )
          else ...<Widget>[
            GameButton(
              label: l10n.roomThemeUnlockPass(price),
              onPressed: onUnlock,
              fullWidth: true,
              variant: GameButtonVariant.gold,
              icon: Icons.lock_open,
            ),
            const SizedBox(height: AppSpacing.s8),
            TextButton(onPressed: onRevert, child: Text(l10n.roomThemeRevert)),
          ],
        ],
      ),
    );
  }
}
