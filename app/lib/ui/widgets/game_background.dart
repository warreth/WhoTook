import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/game_skin.dart';
import '../../core/theme/whotook_theme.dart';

/// Full-screen party backdrop. A mode colour, a handful of slowly drifting
/// props, and a paper wash that keeps every word readable. The motion runs
/// once (about 16 seconds); reduced-motion users get the final frame.
class GameBackdrop extends StatefulWidget {
  const GameBackdrop({
    super.key,
    required this.mode,
    required this.child,
    this.lobby = false,
    this.paper = true,
    this.accent = true,
  });

  final GameMode mode;
  final Widget child;
  final bool lobby;
  final bool paper;
  final bool accent;

  @override
  State<GameBackdrop> createState() => _GameBackdropState();
}

class _GameBackdropState extends State<GameBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  @override
  void initState() {
    super.initState();
    _drift.forward();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = GameModeSkin.forMode(widget.mode, lobby: widget.lobby);
    final palette = WhoTookColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final theme = Theme.of(context);
    final themed = widget.accent
        ? theme.copyWith(
            extensions: <ThemeExtension<dynamic>>[skinPalette(palette, skin)],
            colorScheme: theme.colorScheme.copyWith(
              primary: skin.accent,
              onPrimary: skin.onAccent,
            ),
          )
        : theme;
    return AnimatedBuilder(
      animation: _drift,
      builder: (context, child) {
        final progress = reduce ? 1.0 : _drift.value;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CustomPaint(
              painter: _PartyBackdropPainter(
                skin: skin,
                dark: dark,
                progress: progress,
                paper: widget.paper,
              ),
            ),
            child!,
          ],
        );
      },
      child: Theme(data: themed, child: widget.child),
    );
  }
}

class _PartyBackdropPainter extends CustomPainter {
  _PartyBackdropPainter({
    required this.skin,
    required this.dark,
    required this.progress,
    required this.paper,
  });

  final GameModeSkin skin;
  final bool dark;
  final double progress;
  final bool paper;

  static const int _shapeCount = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = dark
        ? Color.alphaBlend(Colors.black.withValues(alpha: 0.42), skin.deep)
        : skin.base;
    final deep = dark
        ? Color.alphaBlend(Colors.black.withValues(alpha: 0.72), skin.deep)
        : skin.deep;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[base, deep],
        ).createShader(rect),
    );

    final glow = Paint()
      ..color = skin.shapeA.withValues(alpha: dark ? 0.20 : 0.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 46);
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.10),
      size.width * 0.46,
      glow,
    );
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.38),
      size.width * 0.34,
      Paint()
        ..color = skin.shapeB.withValues(alpha: dark ? 0.14 : 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 52),
    );

    final random = math.Random(27);
    for (var i = 0; i < _shapeCount; i++) {
      final x = random.nextDouble();
      final y = random.nextDouble();
      final kind = i % 4;
      final phase = random.nextDouble() * math.pi * 2;
      final drift = math.sin(progress * math.pi + phase);
      final rise = math.cos(progress * math.pi * 0.8 + phase);
      final centre = Offset(
        (x * size.width + drift * 18) % (size.width + 60) - 30,
        (y * size.height + rise * 22 + progress * 26) % (size.height + 60) - 30,
      );
      final scale = 0.7 + random.nextDouble() * 0.9;
      final color = (i.isEven ? skin.shapeA : skin.shapeB).withValues(
        alpha: dark ? 0.10 : 0.22,
      );
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate((random.nextDouble() - 0.5) * 0.7 + progress * 0.12);
      switch (kind) {
        case 0:
          _polaroid(canvas, color, 28 * scale);
        case 1:
          _shutter(canvas, color, 18 * scale);
        case 2:
          _star(canvas, color, 11 * scale);
        default:
          canvas.drawCircle(Offset.zero, 3.5 * scale, Paint()..color = color);
      }
      canvas.restore();
    }

    if (!paper) return;
    final sheet =
        ThemeData.estimateBrightnessForColor(skin.deep) == Brightness.dark
        ? const Color(0xFFF8F4E9)
        : Colors.white;
    final wash = Color.alphaBlend(
      skin.base.withValues(alpha: dark ? 0.10 : 0.16),
      dark ? const Color(0xFF1B1917) : sheet,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            wash.withValues(alpha: dark ? 0.74 : 0.62),
            wash.withValues(alpha: dark ? 0.88 : 0.84),
            wash.withValues(alpha: dark ? 0.93 : 0.90),
          ],
          stops: const <double>[0, 0.42, 1],
        ).createShader(rect),
    );
  }

  void _polaroid(Canvas canvas, Color color, double size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: size, height: size * 1.18),
      const Radius.circular(3),
    );
    canvas.drawRRect(body, Paint()..color = color);
    canvas.drawRect(
      Rect.fromLTWH(-size * 0.36, -size * 0.38, size * 0.72, size * 0.58),
      Paint()..color = color.withValues(alpha: 0.55),
    );
  }

  void _shutter(Canvas canvas, Color color, double radius) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(Offset.zero, radius, paint);
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      final start = Offset(
        math.cos(angle) * radius * 0.36,
        math.sin(angle) * radius * 0.36,
      );
      final end = Offset(
        math.cos(angle + 0.35) * radius,
        math.sin(angle + 0.35) * radius,
      );
      canvas.drawLine(start, end, paint);
    }
  }

  void _star(Canvas canvas, Color color, double radius) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 - math.pi / 2;
      final r = i.isEven ? radius : radius * 0.34;
      final point = Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PartyBackdropPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.skin != skin ||
      oldDelegate.dark != dark ||
      oldDelegate.paper != paper;
}

/// Tilted sticker used for round counters and small status labels.
class StickerBadge extends StatelessWidget {
  const StickerBadge({
    super.key,
    required this.label,
    this.background,
    this.foreground,
    this.angle = -0.05,
    this.icon,
  });

  final String label;
  final Color? background;
  final Color? foreground;
  final double angle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final bg = background ?? colors.accent;
    final fg = foreground ?? colors.onAccent;
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.ink, width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.ink,
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: gameDisplay(
                size: 11,
                weight: FontWeight.w700,
                color: fg,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
