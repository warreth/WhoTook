import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/theme/game_skin.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/game_background.dart';
import '../widgets/game_widgets.dart';
import '../widgets/mode_picker.dart';

/// A clean holding screen for a player who scanned the QR while a match was
/// running. They watch the current round read-only, then join the next match
/// with the normal photo check instead of touching the active round.
class WaitingRoomScreen extends ConsumerWidget {
  const WaitingRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final watching = state.currentRound > 0;
    final photo = state.activePhotoBytes;
    final progress = state.phaseDurationMs <= 0
        ? 0.0
        : (state.remainingMs / state.phaseDurationMs).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GameBackdrop(
        mode: watching ? state.activeMode : GameMode.classic,
        lobby: true,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SurfaceCard(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Icon(
                        Icons.hourglass_top,
                        size: 30,
                        color: GamePalette.goldDeep,
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      Text(
                        l10n.matchInProgressTitle,
                        textAlign: TextAlign.center,
                        style: gameDisplay(size: 28, color: colors.ink),
                      ),
                      if (watching) ...<Widget>[
                        const SizedBox(height: AppSpacing.s12),
                        Text(
                          l10n.watchingLive.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 9,
                            letterSpacing: 0.8,
                            color: colors.ink3,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          l10n.watchingRound(
                            state.currentRound,
                            state.totalRounds,
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          modeLabel(l10n, state.activeMode),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: colors.ink2),
                        ),
                        if (state.phaseDurationMs > 0) ...<Widget>[
                          const SizedBox(height: AppSpacing.s8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadii.rSm),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              color: colors.accent,
                              backgroundColor: colors.raised,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.secondsShort(
                              (state.remainingMs / 1000).ceil(),
                            ),
                            textAlign: TextAlign.center,
                            style: tabularFigures(
                              TextStyle(fontSize: 10, color: colors.ink3),
                            ),
                          ),
                        ],
                        if (photo != null && photo.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.s12),
                          Container(
                            height: 170,
                            decoration: BoxDecoration(
                              color: colors.raised,
                              borderRadius: BorderRadius.circular(
                                AppRadii.rControl,
                              ),
                              border: Border.all(color: colors.hairline),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.memory(
                              photo,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        l10n.matchInProgressBody,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: colors.ink2,
                        ),
                      ),
                      if (state.roomId != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.s12),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.raised,
                              borderRadius: BorderRadius.circular(AppRadii.rSm),
                            ),
                            child: Text(
                              l10n.roomCode(state.roomId!),
                              style: tabularFigures(
                                const TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s20),
                      SecondaryButton(
                        label: l10n.leaveRoom,
                        icon: Icons.logout,
                        onPressed: () => unawaited(coordinator.leaveMatch()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
