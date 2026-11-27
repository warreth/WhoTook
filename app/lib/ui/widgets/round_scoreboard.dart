import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import 'common.dart';
import 'game_widgets.dart';

/// Ranked round-end standings showing everyone's total score, round delta,
/// and active streak so nobody loses track of where they stand.
class RoundScoreboard extends StatelessWidget {
  const RoundScoreboard({
    super.key,
    required this.players,
    required this.scoreDeltas,
    this.streaks = const <String, int>{},
    this.avatarPhotos = const <String, String>{},
    this.localPlayerId,
    this.doublePoints = false,
  });

  final List<Player> players;
  final Map<String, int> scoreDeltas;
  final Map<String, int> streaks;
  final Map<String, String> avatarPhotos;
  final String? localPlayerId;
  final bool doublePoints;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final sorted = List<Player>.of(players)
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        return byScore != 0 ? byScore : a.id.compareTo(b.id);
      });
    if (sorted.isEmpty) return const SizedBox.shrink();

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                l10n.standingsLabel.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: colors.ink2,
                ),
              ),
              const Spacer(),
              if (doublePoints)
                StickerBadge(
                  label: l10n.finalRoundDoubleBadge,
                  background: GamePalette.gold,
                  foreground: GamePalette.onGold,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          for (var i = 0; i < sorted.length; i++) ...<Widget>[
            _ScoreboardRow(
              rank: i + 1,
              player: sorted[i],
              delta: scoreDeltas[sorted[i].id] ?? 0,
              streak: streaks[sorted[i].id] ?? sorted[i].streak,
              avatarPhoto: avatarPhotos[sorted[i].id],
              isLocal: sorted[i].id == localPlayerId,
            ),
            if (i != sorted.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _ScoreboardRow extends StatelessWidget {
  const _ScoreboardRow({
    required this.rank,
    required this.player,
    required this.delta,
    required this.streak,
    required this.avatarPhoto,
    required this.isLocal,
  });

  final int rank;
  final Player player;
  final int delta;
  final int streak;
  final String? avatarPhoto;
  final bool isLocal;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final deltaText = delta > 0
        ? '+$delta'
        : delta < 0
        ? '$delta'
        : '0';
    final deltaColor = delta > 0
        ? colors.positive
        : delta < 0
        ? colors.negative
        : colors.ink3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isLocal
            ? colors.accent.withValues(alpha: 0.1)
            : colors.raised,
        borderRadius: BorderRadius.circular(AppRadii.rControl),
        border: Border.all(
          color: isLocal ? colors.accent : colors.hairline,
          width: isLocal ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 24,
            child: Text(
              '#$rank',
              style: tabularFigures(
                TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: rank == 1 ? GamePalette.goldInk : colors.ink2,
                ),
              ),
            ),
          ),
          PlayerAvatar(
            initial: player.name,
            avatar: player.avatar,
            photoBase64: avatarPhoto,
            isHost: player.isHost,
            size: 26,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isLocal ? FontWeight.w700 : FontWeight.w500,
                      color: colors.ink,
                    ),
                  ),
                ),
                if (isLocal) ...<Widget>[
                  const SizedBox(width: 4),
                  Text(
                    '(${l10n.you})',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (streak >= 2) ...<Widget>[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: GamePalette.gold,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${streak}x',
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: GamePalette.onGold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            deltaText,
            style: tabularFigures(
              TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: deltaColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            l10n.points(player.score),
            style: tabularFigures(
              TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
