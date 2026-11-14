import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';

/// The one primary action per screen. 52 tall so it clears the 44px target.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          disabledBackgroundColor: colors.raised,
          disabledForegroundColor: colors.ink3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.rControl),
          ),
          textStyle: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: busy
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.ink3,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 18),
                    const SizedBox(width: AppSpacing.s8),
                  ],
                  Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                ],
              ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.ink,
          side: BorderSide(color: colors.hairline),
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.rControl),
          ),
          textStyle: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 18, color: colors.ink2),
              const SizedBox(width: AppSpacing.s8),
            ],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

/// Quiet surface with a hairline. No shadow, no glow.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.s16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    // Material, not a decorated Container: ListTiles inside paint their ink on
    // the nearest Material ancestor and would otherwise be invisible.
    return Material(
      color: colors.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.rCard),
        side: BorderSide(color: colors.hairline),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: colors.ink2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Monospace counter (`03 / 10`) with tabular figures so ticking is stable.
class FrameCounter extends StatelessWidget {
  const FrameCounter({super.key, required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final label =
        '${current.toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}';
    return Text(
      label,
      style: tabularFigures(
        TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 12,
          color: colors.ink2,
        ),
      ),
    );
  }
}

/// Small white corner tag that numbers a photo on the contact sheet.
class NumberTag extends StatelessWidget {
  const NumberTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: tabularFigures(
          const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 10,
            color: Color(0xFF1F1B16),
          ),
        ),
      ),
    );
  }
}

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.initial,
    this.isHost = false,
    this.size = 32,
  });

  final String initial;
  final bool isHost;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isHost ? colors.ink : colors.raised,
        shape: BoxShape.circle,
        border: Border.all(color: colors.hairline),
      ),
      child: Text(
        initial.isEmpty ? '?' : initial.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w500,
          color: isHost ? colors.bg : colors.ink2,
        ),
      ),
    );
  }
}

/// Live transfer status. A dot only appears for a real state, never decoration.
class StatusRow extends StatelessWidget {
  const StatusRow({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
  });

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final color = switch (tone) {
      StatusTone.positive => colors.positive,
      StatusTone.warning => colors.negative,
      StatusTone.neutral => colors.ink3,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.s8),
        Text(label, style: TextStyle(fontSize: 12, color: colors.ink2)),
      ],
    );
  }
}

enum StatusTone { neutral, positive, warning }

/// Banner for the screenshot callout and the relay limit message.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.message,
    this.tone = StatusTone.neutral,
    this.icon = Icons.camera_alt_outlined,
  });

  final String message;
  final StatusTone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final foreground = tone == StatusTone.warning
        ? colors.negative
        : colors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rControl),
        border: Border.all(color: colors.hairline),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// One leaderboard line. Scores right aligned with tabular figures.
class ScoreRow extends StatelessWidget {
  const ScoreRow({
    super.key,
    required this.position,
    required this.player,
    required this.score,
    this.delta,
    this.streak,
    this.highlighted = false,
  });

  final int position;
  final Player player;
  final int score;
  final int? delta;
  final int? streak;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
      decoration: BoxDecoration(
        color: highlighted ? colors.raised : Colors.transparent,
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 20,
            child: Text(
              '$position',
              style: tabularFigures(
                TextStyle(fontSize: 12, color: colors.ink3),
              ),
            ),
          ),
          PlayerAvatar(initial: player.name, isHost: player.isHost, size: 28),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    player.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (streak != null && streak! > 1) ...<Widget>[
                  const SizedBox(width: AppSpacing.s8),
                  _StreakChip(streak: streak!),
                ],
              ],
            ),
          ),
          Text(
            '$score',
            style: tabularFigures(TextStyle(fontSize: 13, color: colors.ink)),
          ),
          SizedBox(
            width: 56,
            child: Text(
              delta == null || delta == 0 ? '' : '+$delta',
              textAlign: TextAlign.right,
              style: tabularFigures(
                TextStyle(fontSize: 12, color: colors.positive),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(AppRadii.rSm),
        border: Border.all(color: colors.hairline),
      ),
      child: Text(
        'Streak $streak',
        style: tabularFigures(TextStyle(fontSize: 11, color: colors.ink2)),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.primaryAction = false,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Marks the action as the one that unblocks the screen.
  final bool primaryAction;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(body, style: TextStyle(fontSize: 13, color: colors.ink2)),
        if (actionLabel != null && onAction != null) ...<Widget>[
          const SizedBox(height: AppSpacing.s16),
          if (primaryAction)
            PrimaryButton(label: actionLabel!, onPressed: onAction)
          else
            SecondaryButton(label: actionLabel!, onPressed: onAction),
        ],
      ],
    );
  }
}
