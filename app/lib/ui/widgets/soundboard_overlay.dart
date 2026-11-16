import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/party_pass/party_pass_controller.dart';
import '../../core/party_pass/sound_effect.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';
import 'game_widgets.dart';

/// Floating collapsible soundboard. Visible only to a Party Pass holder during
/// rounds, voting and reveals; everyone still hears the broadcast sounds.
class SoundboardPill extends ConsumerStatefulWidget {
  const SoundboardPill({super.key});

  @override
  ConsumerState<SoundboardPill> createState() => _SoundboardPillState();
}

class _SoundboardPillState extends ConsumerState<SoundboardPill> {
  final SoundboardGate _gate = SoundboardGate();
  Timer? _ticker;
  bool _expanded = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      if (_gate.remaining('self') == Duration.zero) {
        _ticker?.cancel();
        _ticker = null;
      }
      setState(() {});
    });
  }

  void _play(PartySound sound) {
    if (!_gate.tryPlay('self')) return;
    ref.read(matchCoordinatorProvider).playSoundEffect(sound);
    _startTicker();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pass =
        ref.watch(partyPassProvider).value ?? const PartyPassState();
    final state = ref.watch(matchStateProvider).value;
    if (!pass.active ||
        state == null ||
        state.roomId == null ||
        !_showsOn(state.phase)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final remaining = _gate.remaining('self');
    final waiting = remaining > Duration.zero;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s12,
            0,
            AppSpacing.s12,
            96,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.bottomRight,
            child: _expanded
                ? _SoundboardPanel(
                    l10n: l10n,
                    remaining: remaining,
                    onPlay: _play,
                    onCollapse: () => setState(() => _expanded = false),
                  )
                : _SoundboardPillButton(
                    l10n: l10n,
                    active: waiting,
                    onTap: () => setState(() => _expanded = true),
                  ),
          ),
        ),
      ),
    );
  }

  bool _showsOn(RoundPhase phase) => switch (phase) {
    RoundPhase.countdown ||
    RoundPhase.guessing ||
    RoundPhase.reveal ||
    RoundPhase.captionWriting ||
    RoundPhase.captionVoting ||
    RoundPhase.captionReveal ||
    RoundPhase.timelineGuessing ||
    RoundPhase.timelineReveal => true,
    RoundPhase.lobby ||
    RoundPhase.preparing ||
    RoundPhase.extendPrompt ||
    RoundPhase.podium => false,
  };
}

class _SoundboardPillButton extends StatelessWidget {
  const _SoundboardPillButton({
    required this.l10n,
    required this.active,
    required this.onTap,
  });

  final AppLocalizations l10n;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Semantics(
      button: true,
      label: l10n.soundboardExpand,
      child: Material(
        color: GamePalette.gold,
        borderRadius: BorderRadius.circular(AppRadii.rControl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.rControl),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.rControl),
              border: Border.all(color: GamePalette.onGold, width: 2.5),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black
                      : colors.ink,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  active ? Icons.timer_outlined : Icons.graphic_eq,
                  size: 17,
                  color: GamePalette.onGold,
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  l10n.soundboardTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: GamePalette.onGold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoundboardPanel extends StatelessWidget {
  const _SoundboardPanel({
    required this.l10n,
    required this.remaining,
    required this.onPlay,
    required this.onCollapse,
  });

  final AppLocalizations l10n;
  final Duration remaining;
  final ValueChanged<PartySound> onPlay;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final waiting = remaining > Duration.zero;
    return Container(
      width: 264,
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rModal),
        border: Border.all(color: colors.ink, width: 2.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black
                : colors.ink,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.graphic_eq, size: 18),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  l10n.soundboardTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.soundboardCollapse,
                visualDensity: VisualDensity.compact,
                onPressed: onCollapse,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          Text(
            waiting
                ? l10n.soundboardCooldown(
                    remaining.inMilliseconds <= 0
                        ? 0
                        : (remaining.inMilliseconds / 1000).ceil(),
                  )
                : l10n.soundboardHint,
            style: TextStyle(fontSize: 11, color: colors.ink2),
          ),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: <Widget>[
              for (final sound in PartySound.values)
                SizedBox(
                  width: 110,
                  child: _SoundButton(
                    label: partySoundLabel(l10n, sound),
                    enabled: !waiting,
                    onTap: () => onPlay(sound),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SoundButton extends StatelessWidget {
  const _SoundButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: colors.raised,
          borderRadius: BorderRadius.circular(AppRadii.rSm),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppRadii.rSm),
            child: Container(
              height: 38,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.rSm),
                border: Border.all(color: colors.ink, width: 1.5),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Short toast shown on every phone when a sound is played. It listens to the
/// match state so it appears above round, vote and reveal screens alike.
class SoundboardToast extends ConsumerStatefulWidget {
  const SoundboardToast({super.key});

  @override
  ConsumerState<SoundboardToast> createState() => _SoundboardToastState();
}

class _SoundboardToastState extends ConsumerState<SoundboardToast> {
  SoundEffectEvent? _event;
  Timer? _timer;
  int? _seenAtMs;

  @override
  void initState() {
    super.initState();
    _seenAtMs = ref.read(matchStateProvider).value?.lastSoundEffect?.atMs;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _show(SoundEffectEvent event) {
    _seenAtMs = event.atMs;
    _timer?.cancel();
    setState(() => _event = event);
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _event = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<MatchUiState>>(matchStateProvider, (previous, next) {
      final event = next.value?.lastSoundEffect;
      if (event == null || event.atMs == _seenAtMs) return;
      _show(event);
    });
    final event = _event;
    if (event == null) return const SizedBox.shrink();
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final sound = partySoundLabel(l10n, event.sound);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: IgnorePointer(
            child: Material(
              elevation: 4,
              shadowColor: colors.ink.withValues(alpha: 0.18),
              color: colors.ink,
              borderRadius: BorderRadius.circular(AppRadii.rControl),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s12,
                  AppSpacing.s8,
                  AppSpacing.s16,
                  AppSpacing.s8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.volume_up, size: 16, color: colors.accent),
                    const SizedBox(width: AppSpacing.s8),
                    Flexible(
                      child: Text(
                        l10n.soundPlayedToast(event.playerName, sound),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.bg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
