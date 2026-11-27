import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/links.dart';
import '../../core/models/models.dart';
import '../../core/safety/moderation_report_service.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';
import 'common.dart';

/// Placeholder shown in place of any photo, meme, or sabotage hidden by the
/// local player through reporting or blocking.
class BlockedContentPlaceholder extends StatelessWidget {
  const BlockedContentPlaceholder({
    super.key,
    this.compact = false,
    this.onManage,
  });

  final bool compact;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AppSpacing.s12 : AppSpacing.s20),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(AppRadii.rCard),
        border: Border.all(color: colors.hairline, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.visibility_off_outlined,
            size: compact ? 22 : 30,
            color: colors.ink2,
          ),
          SizedBox(height: compact ? AppSpacing.s4 : AppSpacing.s8),
          Text(
            l10n.contentHiddenBlocked,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w500,
              color: colors.ink2,
            ),
          ),
          if (!compact && onManage != null) ...<Widget>[
            const SizedBox(height: AppSpacing.s8),
            TextButton(
              onPressed: onManage,
              child: Text(l10n.blockedPlayersTitle),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showReportBlockSheet(
  BuildContext context, {
  Player? initialPlayer,
  String? initialPhotoId,
  ModerationTargetType? initialTargetType,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportBlockSheet(
      initialPlayer: initialPlayer,
      initialPhotoId: initialPhotoId,
      initialTargetType: initialTargetType,
    ),
  );
}

Future<void> showBlockedPlayersSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _BlockedPlayersSheet(),
  );
}

String _reasonLabel(AppLocalizations l10n, ModerationReportReason reason) =>
    switch (reason) {
      ModerationReportReason.inappropriate => l10n.safetyReasonInappropriate,
      ModerationReportReason.harassment => l10n.safetyReasonHarassment,
      ModerationReportReason.hateSpeech => l10n.safetyReasonHateSpeech,
      ModerationReportReason.nonConsensual => l10n.safetyReasonNonConsensual,
      ModerationReportReason.other => l10n.safetyReasonOther,
    };

class _ReportBlockSheet extends ConsumerStatefulWidget {
  const _ReportBlockSheet({
    this.initialPlayer,
    this.initialPhotoId,
    this.initialTargetType,
  });

  final Player? initialPlayer;
  final String? initialPhotoId;
  final ModerationTargetType? initialTargetType;

  @override
  ConsumerState<_ReportBlockSheet> createState() => _ReportBlockSheetState();
}

class _ReportBlockSheetState extends ConsumerState<_ReportBlockSheet> {
  final TextEditingController _details = TextEditingController();
  ModerationReportReason _reason = ModerationReportReason.inappropriate;
  String? _selectedPlayerId;
  late ModerationTargetType _targetType;
  bool _hideAndBlock = true;
  bool _removeFromRoom = true;
  bool _submitting = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(matchStateProvider).value ??
        ref.read(matchCoordinatorProvider).state;
    _selectedPlayerId = widget.initialPlayer?.id;
    _targetType = widget.initialTargetType ?? _defaultTargetType(state);
  }

  ModerationTargetType _defaultTargetType(MatchUiState state) {
    if (state.activeMode == GameMode.photoSabotage &&
        (state.phase == RoundPhase.captionVoting ||
            state.phase == RoundPhase.captionReveal ||
            state.phase == RoundPhase.captionWriting)) {
      return ModerationTargetType.sabotage;
    }
    if (state.activeMode == GameMode.makeItMeme &&
        (state.phase == RoundPhase.captionVoting ||
            state.phase == RoundPhase.captionReveal ||
            state.phase == RoundPhase.captionWriting)) {
      return ModerationTargetType.meme;
    }
    if (_activeContentIds(state).isNotEmpty) {
      return ModerationTargetType.photo;
    }
    if (_selectedPlayerId != null || state.players.isNotEmpty) {
      return ModerationTargetType.player;
    }
    return ModerationTargetType.general;
  }

  List<String> _activeContentIds(MatchUiState state) {
    final ids = <String>[];
    if (widget.initialPhotoId != null && widget.initialPhotoId!.isNotEmpty) {
      ids.add(widget.initialPhotoId!);
    }
    if (state.activePhotoId != null && state.activePhotoId!.isNotEmpty) {
      ids.add(state.activePhotoId!);
    }
    if (state.lastReveal != null && state.lastReveal!.photoId.isNotEmpty) {
      ids.add(state.lastReveal!.photoId);
    }
    if (state.memeAssignment != null &&
        state.memeAssignment!.photoId.isNotEmpty) {
      ids.add(state.memeAssignment!.photoId);
    }
    final focusCard = state.memeCards
        .where((card) => card.id == state.memeFocusId)
        .firstOrNull ??
        state.memeCards.firstOrNull;
    if (focusCard != null) {
      if (focusCard.id.isNotEmpty) ids.add(focusCard.id);
      if (focusCard.photoId.isNotEmpty) ids.add(focusCard.photoId);
    }
    return ids.toSet().toList();
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.read(matchStateProvider).value ?? coordinator.state;
    final settings = ref.read(appSettingsProvider).value ?? const AppSettings();
    final demo = ref.read(demoModeProvider);

    final selectedPlayer = _selectedPlayerId == null
        ? null
        : state.players
              .where((player) => player.id == _selectedPlayerId)
              .firstOrNull;

    if (_hideAndBlock) {
      for (final id in _activeContentIds(state)) {
        coordinator.hidePhoto(id);
      }
      if (selectedPlayer != null) {
        await coordinator.blockPlayer(
          selectedPlayer.id,
          name: selectedPlayer.name,
          removeIfHost: state.isHosting && _removeFromRoom,
        );
        final normalized = normalizeBlockedName(selectedPlayer.name);
        if (normalized.isNotEmpty) {
          try {
            await ref.read(appSettingsProvider.notifier).apply((current) {
              final next = Set<String>.of(current.blockedPlayerNames)
                ..add(normalized);
              return current.copyWith(blockedPlayerNames: next);
            });
          } on Object {
            // Standalone widget tests may not mount full persistence.
          }
        }
      }
    } else if (state.isHosting &&
        _removeFromRoom &&
        selectedPlayer != null &&
        selectedPlayer.id != 'host') {
      await coordinator.kickPlayer(selectedPlayer.id);
    }

    await ModerationReportService().submitReport(
      reason: _reason,
      targetType: _targetType,
      roomId: state.roomId,
      details: _details.text,
      isDemo: demo,
      signalingOverrideUrl: settings.customSignalingUrl,
    );

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final state = ref.watch(matchStateProvider).value ??
        ref.read(matchCoordinatorProvider).state;
    final otherPlayers = state.players
        .where((player) => player.id != state.localPlayerId)
        .toList();
    final hasContent = _activeContentIds(state).isNotEmpty;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.s20,
          0,
          AppSpacing.s20,
          AppSpacing.s20 + bottomInset,
        ),
        child: _submitted
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Icon(
                    Icons.check_circle_outline,
                    size: 40,
                    color: colors.positive,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Text(
                    l10n.reportSubmittedTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    l10n.reportSubmittedBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: colors.ink2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(
                      openExternal(
                        context,
                        'mailto:$kSupportEmail?subject=WhoTook%20report',
                      ),
                    ),
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: Text(l10n.openSupportEmail(kSupportEmail)),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  PrimaryButton(
                    label: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      l10n.reportContentOrPlayer,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    SectionLabel(l10n.reportTargetLabel),
                    Wrap(
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s8,
                      children: <Widget>[
                        if (hasContent)
                          ChoiceChip(
                            label: Text(l10n.reportTargetCurrentPhoto),
                            selected:
                                _selectedPlayerId == null &&
                                _targetType != ModerationTargetType.general,
                            onSelected: (_) => setState(() {
                              _selectedPlayerId = null;
                              _targetType = _defaultTargetType(state);
                            }),
                          ),
                        if (!hasContent && otherPlayers.isEmpty)
                          ChoiceChip(
                            label: Text(l10n.reportTargetGeneral),
                            selected: _selectedPlayerId == null,
                            onSelected: (_) => setState(() {
                              _selectedPlayerId = null;
                              _targetType = ModerationTargetType.general;
                            }),
                          ),
                        for (final player in otherPlayers)
                          ChoiceChip(
                            label: Text(player.name),
                            selected: _selectedPlayerId == player.id,
                            onSelected: (_) => setState(() {
                              _selectedPlayerId = player.id;
                              _targetType = ModerationTargetType.player;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    SectionLabel(l10n.reportReasonLabel),
                    Wrap(
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s8,
                      children: <Widget>[
                        for (final reason in ModerationReportReason.values)
                          ChoiceChip(
                            label: Text(_reasonLabel(l10n, reason)),
                            selected: _reason == reason,
                            onSelected: (_) => setState(() => _reason = reason),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    TextField(
                      controller: _details,
                      maxLength: 500,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: l10n.reportDetailsHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.rControl),
                        ),
                      ),
                    ),
                    CheckboxListTile(
                      value: _hideAndBlock,
                      onChanged: (value) =>
                          setState(() => _hideAndBlock = value ?? true),
                      title: Text(
                        l10n.hideAndBlockToggle,
                        style: const TextStyle(fontSize: 13),
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    if (state.isHosting &&
                        _selectedPlayerId != null &&
                        _selectedPlayerId != 'host')
                      CheckboxListTile(
                        value: _removeFromRoom,
                        onChanged: (value) =>
                            setState(() => _removeFromRoom = value ?? true),
                        title: Text(
                          l10n.removeFromRoomToggle,
                          style: const TextStyle(fontSize: 13),
                        ),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                    const SizedBox(height: AppSpacing.s12),
                    PrimaryButton(
                      label: l10n.submitReport,
                      icon: Icons.outlined_flag,
                      onPressed: _submitting ? null : () => unawaited(_submit()),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _BlockedPlayersSheet extends ConsumerWidget {
  const _BlockedPlayersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = WhoTookColors.of(context);
    final settings = ref.watch(appSettingsProvider).value ?? const AppSettings();
    final blocked = settings.blockedPlayerNames.toList()..sort();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s20,
          0,
          AppSpacing.s20,
          AppSpacing.s20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.blockedPlayersTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.s12),
            if (blocked.isEmpty)
              EmptyState(
                title: l10n.noBlockedPlayersTitle,
                body: l10n.noBlockedPlayersBody,
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: blocked.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: colors.hairline),
                  itemBuilder: (context, index) {
                    final name = blocked[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(name),
                      trailing: OutlinedButton(
                        onPressed: () async {
                          ref
                              .read(matchCoordinatorProvider)
                              .unblockPlayer(name: name);
                          try {
                            await ref.read(appSettingsProvider.notifier).apply((
                              current,
                            ) {
                              final next = Set<String>.of(
                                current.blockedPlayerNames,
                              )..remove(name);
                              return current.copyWith(blockedPlayerNames: next);
                            });
                          } on Object {
                            // Standalone test harness may omit controller persistence.
                          }
                        },
                        child: Text(l10n.unblockPlayer),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: AppSpacing.s12),
            SecondaryButton(
              label: l10n.close,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
