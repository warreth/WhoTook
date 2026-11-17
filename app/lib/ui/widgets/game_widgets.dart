import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import '../../core/audio/game_audio_service.dart';
import '../../core/constants.dart';
import '../../core/media/photo_memory_cache.dart';
import '../../core/models/models.dart';
import '../../core/theme/game_skin.dart';
import '../../core/theme/responsive_game_layout.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';

abstract final class GamePalette {
  static const Color gold = Color(0xFFE8B34A);
  static const Color goldDeep = Color(0xFFB46B12);

  /// Ink for text on a gold surface. Gold is light in both themes.
  static const Color onGold = Color(0xFF2A1B06);
  static const Color onGoldMuted = Color(0xFF5B3A0E);

  /// A darker gold that keeps small text readable on white paper.
  static const Color goldInk = Color(0xFF8A4E0A);
  static const Color teal = Color(0xFF1F6F63);
  static const Color tealSoft = Color(0xFFDCEBE7);
  static const Color blue = Color(0xFF2D5B8E);
  static const Color blueSoft = Color(0xFFDFE9F3);
}

enum GameButtonVariant { primary, secondary, gold, teal, ghost }

/// A chunky 3D button: two-pixel border, hard bottom shadow, and a four-pixel
/// press. The same widget carries the app's tactile feel across screens.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = GameButtonVariant.primary,
    this.small = false,
    this.fullWidth = false,
    this.sound = true,
    this.haptic = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GameButtonVariant variant;
  final bool small;
  final bool fullWidth;
  final bool sound;
  final bool haptic;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final layout = ResponsiveGameLayout.of(context);
    final shadow = dark ? Colors.black : colors.ink;
    final background = switch (widget.variant) {
      GameButtonVariant.primary => colors.accent,
      GameButtonVariant.secondary => colors.card,
      GameButtonVariant.gold => GamePalette.gold,
      GameButtonVariant.teal => GamePalette.teal,
      GameButtonVariant.ghost => Colors.transparent,
    };
    final foreground = switch (widget.variant) {
      GameButtonVariant.primary => colors.onAccent,
      GameButtonVariant.secondary => colors.ink,
      GameButtonVariant.gold => GamePalette.onGold,
      GameButtonVariant.teal => Colors.white,
      GameButtonVariant.ghost => colors.ink,
    };
    final height = widget.small
        ? layout.smallControlHeight
        : layout.controlHeight;
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled
            ? (_) {
                setState(() => _pressed = true);
                if (widget.sound) {
                  unawaited(GameAudioService.instance.tapDown());
                }
              }
            : null,
        onTapUp: _enabled
            ? (_) {
                setState(() => _pressed = false);
                if (widget.sound) unawaited(GameAudioService.instance.tapUp());
              }
            : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: _enabled
            ? () {
                if (widget.haptic) unawaited(GameHaptics.instance.selection());
                widget.onPressed!.call();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          curve: Curves.easeOut,
          width: widget.fullWidth ? double.infinity : null,
          height: height,
          transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
          padding: EdgeInsets.symmetric(horizontal: widget.small ? 12 : 18),
          decoration: BoxDecoration(
            color: _enabled ? background : background.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.variant == GameButtonVariant.ghost
                  ? colors.hairline
                  : colors.ink,
              width: 2,
            ),
            boxShadow: widget.variant == GameButtonVariant.ghost
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: shadow,
                      offset: Offset(0, _pressed ? 0 : layout.shadowOffset),
                      blurRadius: 0,
                      spreadRadius: 0,
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: widget.fullWidth
                ? MainAxisSize.max
                : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (widget.icon != null) ...<Widget>[
                Icon(
                  widget.icon,
                  size: widget.small ? 16 : 18,
                  color: foreground,
                ),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: widget.small ? 13 : 15,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                    letterSpacing: -0.1,
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

/// A physical print for photos: white paper, dark border, hard shadow and a
/// small tilt. The rotation is deliberately tiny so text stays readable.
class PolaroidPhotoCard extends StatelessWidget {
  const PolaroidPhotoCard({
    super.key,
    required this.bytes,
    this.caption,
    this.meta,
    this.tilt = -0.012,
    this.aspectRatio = 1.02,
    this.showTape = true,
    this.onTap,
  });

  final Uint8List? bytes;
  final String? caption;
  final String? meta;
  final double tilt;
  final double aspectRatio;
  final bool showTape;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Transform.rotate(
      angle: tilt,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: GamePalette.onGold, width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              offset: const Offset(0, 6),
              blurRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(7, 7, 7, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: _PhotoBytes(bytes: bytes),
                  ),
                ),
                if (showTape)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: -1,
                    child: Center(
                      child: Container(
                        width: 58,
                        height: 15,
                        transform: Matrix4.rotationZ(-0.025),
                        color: GamePalette.gold.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
              ],
            ),
            if (caption != null || meta != null) ...<Widget>[
              const SizedBox(height: 7),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      caption ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: GamePalette.onGold,
                      ),
                    ),
                  ),
                  if (meta != null)
                    Text(
                      meta!,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 9,
                        color: GamePalette.onGoldMuted,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}

class _PhotoBytes extends StatelessWidget {
  const _PhotoBytes({required this.bytes, this.photoId});

  final Uint8List? bytes;
  final String? photoId;

  @override
  Widget build(BuildContext context) {
    final id = photoId;
    final cached = id == null ? null : PhotoMemoryCache.instance.bytesFor(id);
    final current = bytes;
    final data = (current == null || current.isEmpty) ? cached : current;
    if (data == null || data.isEmpty) {
      return const PhotoShimmer();
    }
    return GamePhoto(bytes: data, photoId: photoId, fit: BoxFit.cover);
  }
}

/// Decoded photo with a real loading state. `Image.memory` paints nothing
/// until its first frame is ready, which is exactly the black box a delayed
/// peer photo used to leave on screen. This keeps the shimmer up instead.
class GamePhoto extends StatelessWidget {
  const GamePhoto({
    super.key,
    required this.bytes,
    this.photoId,
    this.fit = BoxFit.cover,
    this.compact = false,
  });

  final Uint8List bytes;
  final String? photoId;
  final BoxFit fit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final id = photoId;
    final cached = id == null
        ? null
        : PhotoMemoryCache.instance.providerFor(id);
    final provider = cached ?? MemoryImage(bytes);
    return Image(
      key: id == null ? null : ValueKey<String>('photo-$id'),
      image: provider,
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return PhotoShimmer(compact: compact);
      },
      errorBuilder: (context, error, stack) => Container(
        color: colors.raised,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: colors.ink3,
          size: compact ? 22 : 30,
        ),
      ),
    );
  }
}

/// Playful photo placeholder shown while a peer's JPEG is still arriving.
/// One finite sweep, then calm, so it never becomes an endless animation.
class PhotoShimmer extends StatefulWidget {
  const PhotoShimmer({super.key, this.compact = false});

  final bool compact;

  @override
  State<PhotoShimmer> createState() => _PhotoShimmerState();
}

class _PhotoShimmerState extends State<PhotoShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  @override
  void initState() {
    super.initState();
    final reduce = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (reduce) {
      _sweep.value = 1;
    } else {
      _sweep.forward();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Semantics(
      label: context.l10n.photoLoading,
      child: AnimatedBuilder(
        animation: _sweep,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_sweep.value);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colors.raised,
              gradient: LinearGradient(
                begin: Alignment(-1.5 + t * 3, -0.4),
                end: Alignment(-0.5 + t * 3, 0.4),
                colors: <Color>[
                  colors.raised,
                  Color.alphaBlend(
                    colors.accent.withValues(alpha: 0.16),
                    colors.card,
                  ),
                  colors.raised,
                ],
                stops: const <double>[0, 0.5, 1],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Center(
                  child: Icon(
                    Icons.photo_camera_back_outlined,
                    size: widget.compact ? 22 : 34,
                    color: colors.ink3,
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: colors.card.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A chunky circular clock / time-bomb. It pulses, turns red and shakes in the
/// last five seconds. The parent already ticks [remainingMs] about ten times a
/// second, so no endless animation controller is needed.
class PanicTimerBar extends StatefulWidget {
  const PanicTimerBar({
    super.key,
    required this.remainingMs,
    required this.totalMs,
    this.label,
    this.dangerThresholdMs = 5000,
    this.showLabel = true,
  });

  final int remainingMs;
  final int totalMs;
  final String? label;
  final int dangerThresholdMs;
  final bool showLabel;

  @override
  State<PanicTimerBar> createState() => _PanicTimerBarState();
}

class _PanicTimerBarState extends State<PanicTimerBar> {
  bool _up = false;
  bool _ducking = false;
  int? _lastTickSecond;

  @override
  void didUpdateWidget(covariant PanicTimerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final seconds = (widget.remainingMs / 1000).ceil();
    final danger = widget.remainingMs <= widget.dangerThresholdMs;
    final panic = danger && widget.remainingMs > 0;
    if (panic && !_ducking) {
      _ducking = true;
      unawaited(GameAudioService.instance.setDucking(true));
    } else if (!panic && _ducking) {
      _ducking = false;
      unawaited(GameAudioService.instance.setDucking(false));
    }
    if (panic) {
      _up = !_up;
      if (seconds != _lastTickSecond) {
        _lastTickSecond = seconds;
        unawaited(GameAudioService.instance.tick());
        if (seconds.isOdd) unawaited(GameAudioService.instance.heartbeat());
        unawaited(GameHaptics.instance.light());
      }
    } else {
      _up = false;
    }
  }

  @override
  void dispose() {
    if (_ducking) unawaited(GameAudioService.instance.setDucking(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final layout = ResponsiveGameLayout.of(context);
    final total = math.max(1, widget.totalMs);
    final fraction = (widget.remainingMs / total).clamp(0.0, 1.0);
    final danger = widget.remainingMs <= widget.dangerThresholdMs;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final seconds = (widget.remainingMs / 1000).ceil().clamp(0, 999);
    final shake = danger && !reduce
        ? math.sin(widget.remainingMs / 70) * 2.6
        : 0.0;
    final tone = danger ? colors.negative : colors.accent;
    final badge = Transform.translate(
      offset: Offset(shake, 0),
      child: AnimatedScale(
        scale: danger && _up && !reduce ? 1.075 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Semantics(
          label: widget.label,
          value: '$seconds',
          child: SizedBox.square(
            dimension: layout.timerSize,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CustomPaint(
                  painter: _BombRingPainter(
                    fraction: fraction,
                    tone: tone,
                    track: colors.raised,
                    ink: colors.ink,
                  ),
                ),
                Center(
                  child: Container(
                    width: layout.timerInnerSize,
                    height: layout.timerInnerSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: danger ? colors.negative : colors.ink,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.ink, width: 2),
                    ),
                    child: Text(
                      '$seconds',
                      style: gameDisplay(
                        size: seconds >= 100 ? 13 : 20,
                        weight: FontWeight.w700,
                        color: danger ? Colors.white : colors.bg,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 2,
                  top: 0,
                  child: Transform.rotate(
                    angle: 0.5,
                    child: Container(
                      width: 10,
                      height: 5,
                      decoration: BoxDecoration(
                        color: tone,
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: colors.ink, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final label = widget.label;
    if (!widget.showLabel) return Center(child: badge);
    return Row(
      children: <Widget>[
        badge,
        if (label != null) ...<Widget>[
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: danger ? colors.negative : colors.ink2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BombRingPainter extends CustomPainter {
  const _BombRingPainter({
    required this.fraction,
    required this.tone,
    required this.track,
    required this.ink,
  });

  final double fraction;
  final Color tone;
  final Color track;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 3;
    final background = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(centre, radius, background);
    final ring = Paint()
      ..color = tone
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      ring,
    );
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _BombRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.tone != tone ||
      oldDelegate.track != track ||
      oldDelegate.ink != ink;
}

/// One canvas for all seven meme templates. The same widget is used in the
/// editor, the anonymous vote and the podium.
class MemeCanvas extends StatelessWidget {
  const MemeCanvas({
    super.key,
    required this.bytes,
    this.photoId,
    required this.template,
    required this.topText,
    required this.bottomText,
    this.snapY = 48,
    this.onSnapChanged,
    this.showWatermark = false,
  });

  final Uint8List? bytes;
  final String? photoId;
  final MemeTemplate template;
  final String topText;
  final String bottomText;
  final double snapY;
  final ValueChanged<double>? onSnapChanged;
  final bool showWatermark;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: colors.ink,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: colors.ink, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            offset: const Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 1.06,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (template != MemeTemplate.poster &&
                    template != MemeTemplate.split)
                  _PhotoBytes(bytes: bytes, photoId: photoId),
                if (template == MemeTemplate.classic) ...<Widget>[
                  Positioned(
                    left: 10,
                    right: 10,
                    top: 8,
                    child: _ImpactText(topText),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 8,
                    child: _ImpactText(bottomText),
                  ),
                ],
                if (template == MemeTemplate.pov) ...<Widget>[
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: Container(
                      constraints: BoxConstraints(maxHeight: h * 0.35),
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
                      child: Text(
                        topText,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 8,
                    child: _ImpactText(bottomText),
                  ),
                ],
                if (template == MemeTemplate.breaking)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      color: const Color(0xFFC81E1E),
                      padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            l10n.breakingNews,
                            style: const TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 8,
                              letterSpacing: 1.1,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            topText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (template == MemeTemplate.live) ...<Widget>[
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFD21F1F),
                          width: 4,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 9,
                    top: 9,
                    child: ColoredBox(
                      color: const Color(0xFFD21F1F),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        child: Text(
                          l10n.liveBadge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'JetBrainsMono',
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Text(
                      topText,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        shadows: <Shadow>[
                          Shadow(color: Colors.black, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ],
                if (template == MemeTemplate.poster)
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0xFF111111),
                      child: Stack(
                        children: <Widget>[
                          Positioned(
                            left: 28,
                            right: 28,
                            top: 34,
                            bottom: 84,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: _PhotoBytes(
                                bytes: bytes,
                                photoId: photoId,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 44,
                            child: Text(
                              topText,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Fredoka',
                                color: Color(0xFFF7F4EE),
                                fontSize: 21,
                                height: 1.05,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 30,
                            right: 30,
                            bottom: 16,
                            child: Text(
                              bottomText,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFB4ADA1),
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (template == MemeTemplate.snap)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: (snapY / 100 * h).clamp(20, h - 70),
                    child: GestureDetector(
                      onVerticalDragUpdate: onSnapChanged == null
                          ? null
                          : (details) => onSnapChanged!(
                              (snapY + details.delta.dy / h * 100).clamp(
                                12,
                                88,
                              ),
                            ),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.62),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        child: Text(
                          topText,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (template == MemeTemplate.split)
                  Positioned.fill(
                    child: Column(
                      children: <Widget>[
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            color: GamePalette.blue,
                            padding: const EdgeInsets.all(12),
                            alignment: Alignment.center,
                            child: Text(
                              topText,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              _PhotoBytes(bytes: bytes, photoId: photoId),
                              if (bottomText.isNotEmpty)
                                Positioned(
                                  left: 8,
                                  bottom: 8,
                                  child: Container(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    child: Text(
                                      bottomText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'JetBrainsMono',
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (showWatermark)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Text(
                      kWatermark,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontFamily: 'JetBrainsMono',
                        fontSize: 8,
                        shadows: const <Shadow>[
                          Shadow(color: Colors.black54, blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ImpactText extends StatelessWidget {
  const _ImpactText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final style = TextStyle(
      color: Colors.white,
      fontSize: 28,
      height: 1.02,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.3,
      shadows: const <Shadow>[Shadow(color: Colors.black87, blurRadius: 3)],
    );
    final stroke = style.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black,
    );
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Text(
          text.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: stroke,
        ),
        Text(
          text.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ],
    );
  }
}

class MemeTemplatePicker extends StatelessWidget {
  const MemeTemplatePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final MemeTemplate selected;
  final ValueChanged<MemeTemplate> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8);
    final compact = ResponsiveGameLayout.of(context).isCompactHeight;
    return SizedBox(
      height: (compact ? 48 : 58) * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: MemeTemplate.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final template = MemeTemplate.values[index];
          final active = template == selected;
          return Semantics(
            selected: active,
            button: true,
            label: memeTemplateLabel(l10n, template),
            child: GestureDetector(
              onTap: () {
                unawaited(GameHaptics.instance.selection());
                unawaited(GameAudioService.instance.tap());
                onSelected(template);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 86,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? colors.ink : colors.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active ? colors.ink : colors.hairline,
                    width: 2,
                  ),
                  boxShadow: active
                      ? const <BoxShadow>[
                          BoxShadow(
                            color: GamePalette.gold,
                            offset: Offset(0, 2),
                            blurRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      memeTemplateGlyph(template),
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? (dark
                                  ? GamePalette.onGoldMuted
                                  : GamePalette.gold)
                            : colors.accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      memeTemplateLabel(l10n, template),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: active ? colors.bg : colors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String memeTemplateLabel(AppLocalizations l10n, MemeTemplate template) =>
    switch (template) {
      MemeTemplate.classic => l10n.memeTemplateClassic,
      MemeTemplate.pov => l10n.memeTemplatePov,
      MemeTemplate.breaking => l10n.memeTemplateBreaking,
      MemeTemplate.live => l10n.memeTemplateLive,
      MemeTemplate.poster => l10n.memeTemplatePoster,
      MemeTemplate.snap => l10n.memeTemplateSnap,
      MemeTemplate.split => l10n.memeTemplateSplit,
    };

String memeTemplateGlyph(MemeTemplate template) => switch (template) {
  MemeTemplate.classic => 'T/B',
  MemeTemplate.pov => 'POV',
  MemeTemplate.breaking => 'NEWS',
  MemeTemplate.live => 'LIVE',
  MemeTemplate.poster => 'POST',
  MemeTemplate.snap => 'SNAP',
  MemeTemplate.split => '2×',
};

/// Captures a meme canvas and writes it to the device gallery. Returns false
/// when the platform has no gallery permission or the plugin is unavailable.
class MemeExporter {
  const MemeExporter._();

  static Future<bool> save(GlobalKey boundaryKey, {String? album}) async {
    try {
      if (!await Gal.hasPermission(toAlbum: true)) {
        final granted = await Gal.requestPermission(toAlbum: true);
        if (!granted) return false;
      }
      final boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return false;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return false;
      await Gal.putImageBytes(
        data.buffer.asUint8List(),
        album: album ?? 'WhoTook',
      );
      return true;
    } on Object {
      return false;
    }
  }
}
