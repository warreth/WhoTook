import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/avatars.dart';
import '../../core/theme/responsive_game_layout.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import 'game_background.dart';
import 'game_widgets.dart';

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
    final layout = ResponsiveGameLayout.of(context);
    return SizedBox(
      height: layout.controlHeight,
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
          textStyle: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: layout.isCompactHeight ? 14 : 16,
            fontWeight: FontWeight.w600,
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
    final layout = ResponsiveGameLayout.of(context);
    return SizedBox(
      height: layout.controlHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.ink,
          side: BorderSide(color: colors.hairline),
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.rControl),
          ),
          textStyle: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: layout.isCompactHeight ? 14 : 16,
            fontWeight: FontWeight.w600,
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

/// Tilted round sticker (`ROUND 3/10`) replacing the old monospace counter.
class FrameCounter extends StatelessWidget {
  const FrameCounter({
    super.key,
    required this.current,
    required this.total,
    this.label,
    this.badge = true,
  });

  final int current;
  final int total;
  final String? label;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final text =
        label ??
        '${current.toString().padLeft(2, '0')}/${total.toString().padLeft(2, '0')}';
    if (!badge) {
      final colors = WhoTookColors.of(context);
      return Text(
        text,
        style: tabularFigures(
          TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
            color: colors.ink2,
          ),
        ),
      );
    }
    return StickerBadge(label: text);
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
    this.avatar = '',
    this.photoBase64,
    this.isHost = false,
    this.size = 32,
    this.crown = false,
  });

  final String initial;
  final String avatar;
  final String? photoBase64;
  final bool isHost;
  final double size;
  final bool crown;

  @override
  Widget build(BuildContext context) {
    final photo = avatar == kPhotoAvatar
        ? decodeAvatarPhoto(photoBase64)
        : null;
    final sticker = normalizeAvatar(avatar);
    final palette = _stickerPalette(sticker);
    final face = playerAvatarFaceIndex(sticker);
    final inner = size - (size * 0.15).clamp(4.0, 8.0);
    return SizedBox(
      width: size,
      height: size + (crown ? size * 0.24 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: <Widget>[
          Positioned(
            top: crown ? size * 0.18 : 0,
            child: Transform.rotate(
              angle: -0.035,
              child: Container(
                width: size,
                height: size,
                padding: EdgeInsets.all((size * 0.055).clamp(1.0, 3.0)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF171310),
                    width: (size * 0.055).clamp(1.4, 3.2),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFF171310).withValues(alpha: 0.9),
                      offset: Offset(0, (size * 0.09).clamp(1.5, 4.0)),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: photo != null
                      ? Image.memory(
                          photo,
                          width: inner,
                          height: inner,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        )
                      : CustomPaint(
                          painter: _StickerFacePainter(
                            variant: face,
                            background: palette.$1,
                            ink: palette.$2,
                            accent: palette.$3,
                          ),
                        ),
                ),
              ),
            ),
          ),
          if (crown)
            Positioned(
              top: 0,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.55, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.elasticOut,
                builder: (context, value, child) => Transform.rotate(
                  angle: 0.22 + (1 - value) * 0.30,
                  child: Transform.scale(scale: value, child: child),
                ),
                child: SizedBox(
                  width: size * 0.54,
                  height: size * 0.30,
                  child: CustomPaint(
                    painter: _CrownPainter(
                      fill: const Color(0xFFFFC93C),
                      ink: const Color(0xFF171310),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

int playerAvatarFaceIndex(String avatar) => switch (avatar) {
  'face' => 1,
  'pizza' => 2,
  'music' => 3,
  'game' => 4,
  'rocket' => 5,
  'star' => 6,
  'plant' => 7,
  _ => 0,
};

(Color, Color, Color) _stickerPalette(String avatar) => switch (avatar) {
  'face' => (
    const Color(0xFFFFD34E),
    const Color(0xFF3A2604),
    const Color(0xFFFF8A3D),
  ),
  'pizza' => (
    const Color(0xFFFF8A5B),
    const Color(0xFF3B1607),
    const Color(0xFFFFD34E),
  ),
  'music' => (
    const Color(0xFF8C6BFF),
    const Color(0xFF20114F),
    const Color(0xFFFFD34E),
  ),
  'game' => (
    const Color(0xFF35C4A0),
    const Color(0xFF052E25),
    const Color(0xFFFFF1B8),
  ),
  'rocket' => (
    const Color(0xFFEB5A8C),
    const Color(0xFF3C0A1C),
    const Color(0xFFFFE7A3),
  ),
  'star' => (
    const Color(0xFFF5B82E),
    const Color(0xFF352203),
    const Color(0xFFFFFFFF),
  ),
  'plant' => (
    const Color(0xFF63B96B),
    const Color(0xFF102E12),
    const Color(0xFFFFF1B8),
  ),
  _ => (
    const Color(0xFF6ED0F0),
    const Color(0xFF052F3A),
    const Color(0xFFFFD34E),
  ),
};

class _StickerFacePainter extends CustomPainter {
  const _StickerFacePainter({
    required this.variant,
    required this.background,
    required this.ink,
    required this.accent,
  });

  final int variant;
  final Color background;
  final Color ink;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = background,
    );
    final wash = Paint()..color = accent.withValues(alpha: 0.22);
    canvas.drawCircle(Offset(s * 0.78, s * 0.18), s * 0.32, wash);
    final eye = Paint()..color = ink;
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.075
      ..strokeCap = StrokeCap.round;

    // Cheeks.
    canvas.drawCircle(
      Offset(s * 0.24, s * 0.68),
      s * 0.10,
      Paint()..color = accent.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      Offset(s * 0.76, s * 0.68),
      s * 0.10,
      Paint()..color = accent.withValues(alpha: 0.55),
    );

    switch (variant) {
      case 1: // wink
        canvas.drawCircle(Offset(s * 0.34, s * 0.42), s * 0.075, eye);
        canvas.drawLine(
          Offset(s * 0.58, s * 0.42),
          Offset(s * 0.74, s * 0.42),
          line,
        );
        _smile(canvas, s, open: true);
      case 2: // surprised
        canvas.drawCircle(Offset(s * 0.35, s * 0.40), s * 0.10, eye);
        canvas.drawCircle(Offset(s * 0.65, s * 0.40), s * 0.10, eye);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(s * 0.5, s * 0.68),
            width: s * 0.20,
            height: s * 0.26,
          ),
          eye,
        );
      case 3: // cool shades
        final shades = RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.18, s * 0.34, s * 0.64, s * 0.18),
          Radius.circular(s * 0.06),
        );
        canvas.drawRRect(shades, eye);
        canvas.drawRect(
          Rect.fromLTWH(s * 0.47, s * 0.38, s * 0.06, s * 0.04),
          Paint()..color = background,
        );
        _smile(canvas, s, open: false);
      case 4: // silly tongue
        canvas.drawCircle(Offset(s * 0.34, s * 0.42), s * 0.075, eye);
        canvas.drawCircle(Offset(s * 0.66, s * 0.42), s * 0.075, eye);
        _smile(canvas, s, open: true);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(s * 0.55, s * 0.78),
            width: s * 0.16,
            height: s * 0.18,
          ),
          Paint()..color = const Color(0xFFE45A7B),
        );
      case 5: // determined
        canvas.drawLine(
          Offset(s * 0.24, s * 0.31),
          Offset(s * 0.44, s * 0.37),
          line,
        );
        canvas.drawLine(
          Offset(s * 0.76, s * 0.31),
          Offset(s * 0.56, s * 0.37),
          line,
        );
        canvas.drawCircle(Offset(s * 0.34, s * 0.46), s * 0.065, eye);
        canvas.drawCircle(Offset(s * 0.66, s * 0.46), s * 0.065, eye);
        canvas.drawLine(
          Offset(s * 0.38, s * 0.72),
          Offset(s * 0.62, s * 0.66),
          line,
        );
      case 6: // starstruck
        _starEye(canvas, Offset(s * 0.34, s * 0.43), s * 0.13);
        _starEye(canvas, Offset(s * 0.66, s * 0.43), s * 0.13);
        _smile(canvas, s, open: true);
      case 7: // sleepy
        canvas.drawLine(
          Offset(s * 0.25, s * 0.43),
          Offset(s * 0.42, s * 0.43),
          line,
        );
        canvas.drawLine(
          Offset(s * 0.58, s * 0.43),
          Offset(s * 0.75, s * 0.43),
          line,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(s * 0.5, s * 0.68),
            width: s * 0.16,
            height: s * 0.10,
          ),
          eye,
        );
        canvas.drawCircle(
          Offset(s * 0.8, s * 0.62),
          s * 0.09,
          Paint()..color = accent,
        );
      default: // happy
        canvas.drawCircle(Offset(s * 0.35, s * 0.42), s * 0.08, eye);
        canvas.drawCircle(Offset(s * 0.65, s * 0.42), s * 0.08, eye);
        _smile(canvas, s, open: true);
    }
  }

  void _smile(Canvas canvas, double s, {required bool open}) {
    final path = Path();
    if (open) {
      path.moveTo(s * 0.33, s * 0.64);
      path.quadraticBezierTo(s * 0.5, s * 0.88, s * 0.67, s * 0.64);
      path.close();
      canvas.drawPath(path, Paint()..color = ink);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFF8FA3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.03,
      );
    } else {
      canvas.drawArc(
        Rect.fromLTWH(s * 0.36, s * 0.58, s * 0.28, s * 0.18),
        0.15,
        math.pi - 0.3,
        false,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.07
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _starEye(Canvas canvas, Offset centre, double radius) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 - math.pi / 2;
      final r = i.isEven ? radius : radius * 0.40;
      final point = Offset(
        centre.dx + math.cos(angle) * r,
        centre.dy + math.sin(angle) * r,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = accent);
    canvas.drawPath(
      path,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.14,
    );
  }

  @override
  bool shouldRepaint(covariant _StickerFacePainter oldDelegate) =>
      oldDelegate.variant != variant ||
      oldDelegate.background != background ||
      oldDelegate.ink != ink ||
      oldDelegate.accent != accent;
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter({required this.fill, required this.ink});

  final Color fill;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.10, h * 0.88)
      ..lineTo(w * 0.02, h * 0.22)
      ..lineTo(w * 0.32, h * 0.48)
      ..lineTo(w * 0.50, h * 0.06)
      ..lineTo(w * 0.68, h * 0.48)
      ..lineTo(w * 0.98, h * 0.22)
      ..lineTo(w * 0.90, h * 0.88)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = (size.shortestSide * 0.09).clamp(1.6, 3.0)
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.66),
      size.shortestSide * 0.08,
      Paint()..color = const Color(0xFFE04F33),
    );
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.ink != ink;
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
    this.photoBase64,
    this.maxScore,
  });

  final int position;
  final Player player;
  final int score;
  final int? delta;
  final int? maxScore;
  final int? streak;
  final bool highlighted;
  final String? photoBase64;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final share = maxScore == null || maxScore! <= 0
        ? 0.0
        : (score / maxScore!).clamp(0.0, 1.0);
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: highlighted ? colors.raised : Colors.transparent,
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      child: Stack(
        children: <Widget>[
          if (share > 0)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: share),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => FractionallySizedBox(
                    widthFactor: value,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            colors.accent.withValues(alpha: 0.22),
                            colors.accent.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
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
                PlayerAvatar(
                  initial: player.name,
                  avatar: player.avatar,
                  photoBase64: photoBase64,
                  isHost: player.isHost,
                  size: 28,
                ),
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
                  style: tabularFigures(
                    TextStyle(fontSize: 13, color: colors.ink),
                  ),
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
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(AppRadii.rSm),
        border: Border.all(color: colors.hairline),
      ),
      child: Text(
        l10n.streakLabel(streak),
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

/// Segmented round progress. More than 24 rounds falls back to a single bar.
class ProgressSegments extends StatelessWidget {
  const ProgressSegments({
    super.key,
    required this.current,
    required this.total,
  });

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    if (total <= 0) return const SizedBox.shrink();
    if (total > 24) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: (current / total).clamp(0.0, 1.0),
          minHeight: 5,
          backgroundColor: colors.raised,
          valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
        ),
      );
    }
    return ExcludeSemantics(
      child: Row(
        children: <Widget>[
          for (var i = 0; i < total; i++)
            Expanded(
              child: Container(
                height: 5,
                margin: EdgeInsets.only(right: i == total - 1 ? 0 : 2),
                decoration: BoxDecoration(
                  color: i < current ? colors.accent : colors.raised,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Contact-sheet framed photo used by the party modes.
class PhotoPanel extends StatelessWidget {
  const PhotoPanel({
    super.key,
    required this.bytes,
    this.aspectRatio = 4 / 3,
    this.isPanorama = false,
  });

  final Uint8List? bytes;
  final double aspectRatio;
  final bool isPanorama;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final data = bytes;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadii.rCard),
          border: Border.all(color: colors.hairline),
        ),
        padding: const EdgeInsets.all(AppSpacing.s8),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.rSm),
              child: data == null || data.isEmpty
                  ? Container(
                      color: colors.raised,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image_outlined,
                        size: 28,
                        color: colors.ink3,
                      ),
                    )
                  : ColoredBox(
                      color: isPanorama ? colors.ink : Colors.transparent,
                      child: GamePhoto(
                        bytes: data,
                        fit: isPanorama ? BoxFit.contain : BoxFit.cover,
                      ),
                    ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CropFrameOverlay(
                  color: colors.ink,
                  inset: 4,
                  armLength: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seconds left plus a thin progress track.
class CountdownBar extends StatelessWidget {
  const CountdownBar({
    super.key,
    required this.remainingMs,
    required this.totalMs,
    required this.label,
  });

  final int remainingMs;
  final int totalMs;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final total = totalMs <= 0 ? 1 : totalMs;
    final fraction = (remainingMs / total).clamp(0.0, 1.0);
    final seconds = (remainingMs / 1000).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              l10n.secondsLeftShort(seconds),
              style: tabularFigures(
                TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colors.ink,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.ink2),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Semantics(
          label: label,
          value: seconds,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: colors.raised,
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            ),
          ),
        ),
      ],
    );
  }
}

/// Keeps a phone-first game screen readable on a tablet: the page centres at
/// 720 logical pixels instead of stretching every card across the display.
class ScreenBody extends StatelessWidget {
  const ScreenBody({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
