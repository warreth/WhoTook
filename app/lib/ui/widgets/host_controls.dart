import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';

/// Small host-only menu for a match in progress: skip a stuck screen or
/// remove a disruptive player without closing the room.
class HostControlsButton extends ConsumerWidget {
  const HostControlsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    if (!state.isHosting) return const SizedBox.shrink();
    final canSkip = switch (state.phase) {
      RoundPhase.countdown ||
      RoundPhase.guessing ||
      RoundPhase.reveal ||
      RoundPhase.captionWriting ||
      RoundPhase.captionVoting ||
      RoundPhase.captionReveal ||
      RoundPhase.timelineGuessing ||
      RoundPhase.timelineReveal => true,
      _ => false,
    };
    final others = state.players
        .where((player) => player.id != 'host' && player.connected)
        .toList();
    if (!canSkip && others.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: context.l10n.hostControls,
      icon: Icon(
        Icons.more_vert,
        size: 20,
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFB4ADA1)
            : const Color(0xFF5E554A),
      ),
      onSelected: (value) {
        if (value == 'skip') {
          unawaited(_confirmSkip(context, coordinator));
        } else if (value == 'remove') {
          unawaited(_pickPlayer(context, coordinator, others));
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        if (canSkip)
          PopupMenuItem<String>(
            value: 'skip',
            child: Text(context.l10n.skipRound),
          ),
        if (others.isNotEmpty)
          PopupMenuItem<String>(
            value: 'remove',
            child: Text(context.l10n.removePlayer),
          ),
      ],
    );
  }

  Future<void> _confirmSkip(
    BuildContext context,
    MatchCoordinator coordinator,
  ) async {
    final l10n = context.l10n;
    final skip = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.skipRoundTitle),
        content: Text(l10n.skipRoundBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.skipButton),
          ),
        ],
      ),
    );
    if (skip == true) await coordinator.skipRound();
  }

  Future<void> _pickPlayer(
    BuildContext context,
    MatchCoordinator coordinator,
    List<Player> players,
  ) async {
    final l10n = context.l10n;
    final picked = await showDialog<Player>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.removeAPlayer),
        children: <Widget>[
          for (final player in players)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(player),
              child: Text(player.name),
            ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removePlayerTitle(picked.name)),
        content: Text(l10n.removePlayerMatchBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    if (remove == true) await coordinator.kickPlayer(picked.id);
  }
}
