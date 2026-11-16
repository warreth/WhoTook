import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../theme/whotook_theme.dart';

/// Wire id stored in the room state. Keep these strings stable: they travel
/// between phones and an old build must still recognise the default.
abstract final class RoomThemeIds {
  static const String classicParty = 'classic_party';
  static const String midnightArcade = 'midnight_arcade';
  static const String cyberNeon = 'cyber_neon';
  static const String retroPolaroid = 'retro_polaroid';
  static const String pubKroeg = 'pub_kroeg';
}

/// Premium shared themes. A Party Pass holder picks one and every phone in the
/// lobby follows it for the rest of the match.
enum RoomThemeId {
  classicParty(
    wireId: RoomThemeIds.classicParty,
    premium: false,
    forcedBrightness: null,
  ),
  midnightArcade(
    wireId: RoomThemeIds.midnightArcade,
    premium: true,
    forcedBrightness: Brightness.dark,
    bg: Color(0xFF080B14),
    card: Color(0xFF111827),
    raised: Color(0xFF1C2436),
    ink: Color(0xFFEAF2FF),
    ink2: Color(0xFFA9B7CE),
    ink3: Color(0xFF8494AD),
    accent: Color(0xFF22D3EE),
    onAccent: Color(0xFF041016),
    accent2: Color(0xFFE879F9),
    onAccent2: Color(0xFF1A061B),
    positive: Color(0xFF34D399),
    negative: Color(0xFFFB7185),
    hairline: Color(0x3322D3EE),
  ),
  cyberNeon(
    wireId: RoomThemeIds.cyberNeon,
    premium: true,
    forcedBrightness: Brightness.dark,
    bg: Color(0xFF0B0220),
    card: Color(0xFF150A33),
    raised: Color(0xFF221046),
    ink: Color(0xFFF5E9FF),
    ink2: Color(0xFFC9B6E8),
    ink3: Color(0xFFA48FC7),
    accent: Color(0xFFFF2E97),
    onAccent: Color(0xFF1A0010),
    accent2: Color(0xFF00F0FF),
    onAccent2: Color(0xFF001416),
    positive: Color(0xFF3DFFB8),
    negative: Color(0xFFFF6B81),
    hairline: Color(0x33FF2E97),
  ),
  retroPolaroid(
    wireId: RoomThemeIds.retroPolaroid,
    premium: true,
    forcedBrightness: Brightness.light,
    bg: Color(0xFFF4E8D0),
    card: Color(0xFFFFF9EC),
    raised: Color(0xFFEAD9BD),
    ink: Color(0xFF3B2A1A),
    ink2: Color(0xFF6B5236),
    ink3: Color(0xFF82694E),
    accent: Color(0xFFB84A18),
    onAccent: Color(0xFFFFF8F0),
    accent2: Color(0xFF2F6F62),
    onAccent2: Color(0xFFFFF9EC),
    positive: Color(0xFF2F6B3A),
    negative: Color(0xFFA62D22),
    hairline: Color(0x333B2A1A),
  ),
  pubKroeg(
    wireId: RoomThemeIds.pubKroeg,
    premium: true,
    forcedBrightness: Brightness.dark,
    bg: Color(0xFF1E140E),
    card: Color(0xFF2A1C13),
    raised: Color(0xFF3A281B),
    ink: Color(0xFFF7E8D4),
    ink2: Color(0xFFD3B995),
    ink3: Color(0xFFB09372),
    accent: Color(0xFFE0A44B),
    onAccent: Color(0xFF2A1707),
    accent2: Color(0xFF8FBF7F),
    onAccent2: Color(0xFF102008),
    positive: Color(0xFF8FBF7F),
    negative: Color(0xFFE07A6A),
    hairline: Color(0x33F7E8D4),
  );

  const RoomThemeId({
    required this.wireId,
    required this.premium,
    required this.forcedBrightness,
    this.bg,
    this.card,
    this.raised,
    this.ink,
    this.ink2,
    this.ink3,
    this.accent,
    this.onAccent,
    this.accent2,
    this.onAccent2,
    this.positive,
    this.negative,
    this.hairline,
  });

  final String wireId;
  final bool premium;

  /// Premium themes own their brightness so they look the same on every phone.
  final Brightness? forcedBrightness;

  final Color? bg;
  final Color? card;
  final Color? raised;
  final Color? ink;
  final Color? ink2;
  final Color? ink3;
  final Color? accent;
  final Color? onAccent;
  final Color? accent2;
  final Color? onAccent2;
  final Color? positive;
  final Color? negative;
  final Color? hairline;

  bool get isClassic => this == RoomThemeId.classicParty;

  WhoTookColors palette(Brightness brightness) {
    if (isClassic) {
      return brightness == Brightness.dark
          ? WhoTookColors.dark
          : WhoTookColors.light;
    }
    return WhoTookColors(
      bg: bg!,
      card: card!,
      raised: raised!,
      ink: ink!,
      ink2: ink2!,
      ink3: ink3!,
      accent: accent!,
      onAccent: onAccent!,
      accent2: accent2!,
      onAccent2: onAccent2!,
      positive: positive!,
      negative: negative!,
      hairline: hairline!,
    );
  }

  static RoomThemeId fromWire(String? id) {
    for (final theme in RoomThemeId.values) {
      if (theme.wireId == id) return theme;
    }
    return RoomThemeId.classicParty;
  }
}

String roomThemeLabel(AppLocalizations l10n, RoomThemeId theme) =>
    switch (theme) {
      RoomThemeId.classicParty => l10n.roomThemeClassicParty,
      RoomThemeId.midnightArcade => l10n.roomThemeMidnightArcade,
      RoomThemeId.cyberNeon => l10n.roomThemeCyberNeon,
      RoomThemeId.retroPolaroid => l10n.roomThemeRetroPolaroid,
      RoomThemeId.pubKroeg => l10n.roomThemePubKroeg,
    };
