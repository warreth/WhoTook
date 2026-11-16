import 'package:flutter/material.dart';

import '../models/models.dart';
import 'whotook_theme.dart';

/// Identity for one party mode: the colour the room feels like, and the accent
/// its buttons use. The wash keeps body copy readable while the saturated
/// edges, drifting props and sticker headers carry the mode.
@immutable
class GameModeSkin {
  const GameModeSkin({
    required this.id,
    required this.name,
    required this.base,
    required this.deep,
    required this.accent,
    required this.onAccent,
    required this.shapeA,
    required this.shapeB,
    this.displayOnBase = const Color(0xFFFFF4D8),
  });

  final String id;
  final String name;
  final Color base;
  final Color deep;
  final Color accent;
  final Color onAccent;
  final Color shapeA;
  final Color shapeB;
  final Color displayOnBase;

  static const GameModeSkin lobby = GameModeSkin(
    id: 'lobby',
    name: 'Lobby',
    base: Color(0xFFFFBE3D),
    deep: Color(0xFFF09A12),
    accent: Color(0xFFD93A1E),
    onAccent: Color(0xFFFFFFFF),
    shapeA: Color(0xFFFFE7A3),
    shapeB: Color(0xFFFFF3D1),
  );

  static const GameModeSkin classic = GameModeSkin(
    id: 'classic',
    name: 'Classic',
    base: Color(0xFFE04F33),
    deep: Color(0xFFB32E18),
    accent: Color(0xFFFFC93C),
    onAccent: Color(0xFF2A1408),
    shapeA: Color(0xFFFFB59F),
    shapeB: Color(0xFFFFE0D6),
  );

  static const GameModeSkin meme = GameModeSkin(
    id: 'meme',
    name: 'Make It Meme',
    base: Color(0xFF6C3CE9),
    deep: Color(0xFF4720B5),
    accent: Color(0xFFFFD34E),
    onAccent: Color(0xFF2B1754),
    shapeA: Color(0xFFB9A3FF),
    shapeB: Color(0xFFE7DEFF),
  );

  static const GameModeSkin time = GameModeSkin(
    id: 'time',
    name: 'Time Traveler',
    base: Color(0xFF16264C),
    deep: Color(0xFF0A1530),
    accent: Color(0xFFF5B82E),
    onAccent: Color(0xFF241A05),
    shapeA: Color(0xFF314C86),
    shapeB: Color(0xFFF5B82E),
  );

  static GameModeSkin forMode(GameMode? mode, {bool lobby = false}) {
    if (lobby) return GameModeSkin.lobby;
    return switch (mode) {
      GameMode.makeItMeme || GameMode.captionThis => GameModeSkin.meme,
      GameMode.timeTraveler => GameModeSkin.time,
      GameMode.classic || GameMode.mixedParty || null => GameModeSkin.classic,
    };
  }
}

/// Heavy, rounded display type for titles, timers, stickers and buttons.
TextStyle gameDisplay({
  double size = 20,
  FontWeight weight = FontWeight.w700,
  Color? color,
  double height = 1.0,
  double letterSpacing = -0.4,
}) => TextStyle(
  fontFamily: 'Fredoka',
  fontSize: size,
  height: height,
  fontWeight: weight,
  letterSpacing: letterSpacing,
  color: color,
  shadows: const <Shadow>[
    Shadow(color: Color(0x33171310), offset: Offset(0, 2), blurRadius: 0),
  ],
);

/// The palette a screen's buttons use while a mode skin is active.
WhoTookColors skinPalette(WhoTookColors base, GameModeSkin skin) =>
    base.copyWith(accent: skin.accent, onAccent: skin.onAccent);
