import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

/// Caption This: write, vote, then watch the authors get exposed.
class CaptionScreen extends ConsumerStatefulWidget {
  const CaptionScreen({super.key});

  @override
  ConsumerState<CaptionScreen> createState() => _CaptionScreenState();
}

class _CaptionScreenState extends ConsumerState<CaptionScreen> {
  final TextEditingController _caption = TextEditingController();
  int _template = 0;

  static const List<String> _templates = <String>[
    'Nobody: ... Me:',
    'POV: you said "one more round".',
    'This is the last photo before...',
    'When the Wi-Fi drops mid-game...',
    'Tell me you lost without telling me you lost.',
    'The face you make when someone guesses your photo.',
  ];

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _inspire() {
    final template = _templates[_template % _templates.length];
    _template += 1;
    _caption.value = TextEditingValue(
      text: template,
      selection: TextSelection.collapsed(offset: template.length),
    );
    unawaited(HapticFeedback.selectionClick());
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;

    return Scaffold(
      body: SafeArea(
        child: switch (state.phase) {
          RoundPhase.captionVoting => _CaptionVoting(
            state: state,
            onVote: (id) => unawaited(
              state.isHosting
                  ? coordinator.voteCaption(id)
                  : coordinator.clientVoteCaption(id),
            ),
          ),
          RoundPhase.captionReveal => _CaptionReveal(state: state),
          _ => _CaptionWriting(
            state: state,
            controller: _caption,
            onInspire: _inspire,
            onSubmit: (text) => unawaited(
              state.isHosting
                  ? coordinator.submitCaption(text)
                  : coordinator.clientSubmitCaption(text),
            ),
          ),
        },
      ),
    );
  }
}

class _CaptionWriting extends StatelessWidget {
  const _CaptionWriting({
    required this.state,
    required this.controller,
    required this.onInspire,
    required this.onSubmit,
  });

  final MatchUiState state;
  final TextEditingController controller;
  final VoidCallback onInspire;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s12,
        AppSpacing.s20,
        AppSpacing.s24,
      ),
      children: <Widget>[
        _CaptionHeader(state: state),
        const SizedBox(height: AppSpacing.s12),
        PhotoPanel(bytes: state.activePhotoBytes, aspectRatio: 1.15),
        const SizedBox(height: AppSpacing.s12),
        CountdownBar(
          remainingMs: state.remainingMs,
          totalMs: state.phaseDurationMs,
          label: 'Write the funniest caption',
        ),
        const SizedBox(height: AppSpacing.s16),
        if (state.captionSubmitted) ...<Widget>[
          const NoticeBanner(
            message: 'Caption sent. Waiting for the others.',
            icon: Icons.hourglass_empty,
          ),
          const SizedBox(height: AppSpacing.s12),
        ],
        TextField(
          controller: controller,
          enabled: !state.captionSubmitted,
          maxLength: 80,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            labelText: 'Your caption',
            hintText: 'Make it weird.',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.rControl),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: state.captionSubmitted ? null : onInspire,
                icon: const Icon(Icons.casino_outlined, size: 18),
                label: const Text('Inspire me'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: colors.ink2,
                  side: BorderSide(color: colors.hairline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.rControl),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        if (state.captionSubmitted)
          const SecondaryButton(
            label: 'Waiting for the others',
            onPressed: null,
          )
        else
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => PrimaryButton(
              label: 'Send caption',
              onPressed: value.text.trim().isEmpty
                  ? null
                  : () => onSubmit(value.text),
            ),
          ),
        if (state.errorMessage != null) ...<Widget>[
          const SizedBox(height: AppSpacing.s12),
          NoticeBanner(
            message: state.errorMessage!,
            tone: StatusTone.warning,
            icon: Icons.error_outline,
          ),
        ],
      ],
    );
  }
}

class _CaptionVoting extends StatelessWidget {
  const _CaptionVoting({required this.state, required this.onVote});

  final MatchUiState state;
  final ValueChanged<String> onVote;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s12,
        AppSpacing.s20,
        AppSpacing.s24,
      ),
      children: <Widget>[
        _CaptionHeader(state: state),
        const SizedBox(height: AppSpacing.s12),
        PhotoPanel(bytes: state.activePhotoBytes, aspectRatio: 1.8),
        const SizedBox(height: AppSpacing.s12),
        CountdownBar(
          remainingMs: state.remainingMs,
          totalMs: state.phaseDurationMs,
          label: 'Vote for the funniest',
        ),
        const SizedBox(height: AppSpacing.s12),
        Text(
          state.votedCaptionId == null
              ? 'Tap one caption. You cannot pick your own.'
              : 'Vote locked. Waiting for the table.',
          style: TextStyle(fontSize: 13, color: colors.ink2),
        ),
        const SizedBox(height: AppSpacing.s12),
        if (state.captionOptions.isEmpty)
          const EmptyState(
            title: 'No captions',
            body: 'This round will move on.',
          )
        else
          _StaggeredCaptionList(
            captions: state.captionOptions,
            ownId: state.ownCaptionId,
            votedId: state.votedCaptionId,
            onVote: onVote,
          ),
        if (state.errorMessage != null) ...<Widget>[
          const SizedBox(height: AppSpacing.s12),
          NoticeBanner(
            message: state.errorMessage!,
            tone: StatusTone.warning,
            icon: Icons.error_outline,
          ),
        ],
      ],
    );
  }
}

class _CaptionReveal extends StatelessWidget {
  const _CaptionReveal({required this.state});

  final MatchUiState state;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final reveal = state.lastCaptionReveal;
    if (reveal == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final topVotes = reveal.entries.isEmpty
        ? 0
        : reveal.entries
              .map((entry) => entry.votes)
              .reduce((a, b) => a > b ? a : b);
    final own = reveal.entries
        .where((entry) => entry.id == state.ownCaptionId)
        .firstOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s12,
        AppSpacing.s20,
        AppSpacing.s24,
      ),
      children: <Widget>[
        _CaptionHeader(state: state),
        const SizedBox(height: AppSpacing.s12),
        PhotoPanel(bytes: state.activePhotoBytes, aspectRatio: 1.8),
        const SizedBox(height: AppSpacing.s12),
        Text(
          'The table has spoken',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
            color: colors.ink,
          ),
        ),
        if (state.players
                .where((player) => player.id == reveal.ownerId)
                .firstOrNull !=
            null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            'Photo by ${state.players.where((player) => player.id == reveal.ownerId).first.name}',
            style: TextStyle(fontSize: 12, color: colors.ink2),
          ),
        ],
        const SizedBox(height: AppSpacing.s12),
        _StaggeredCaptionResults(entries: reveal.entries, topVotes: topVotes),
        if (own != null) ...<Widget>[
          const SizedBox(height: AppSpacing.s4),
          Text(
            own.votes == 0
                ? 'Your caption got zero votes. Brutal.'
                : 'Your caption got ${own.votes} ${own.votes == 1 ? 'vote' : 'votes'}.',
            style: TextStyle(
              fontSize: 13,
              color: own.votes == 0 ? colors.ink2 : colors.positive,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s12),
        Text(
          'Next round in a moment.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: colors.ink3),
        ),
      ],
    );
  }
}

class _CaptionHeader extends StatelessWidget {
  const _CaptionHeader({required this.state});

  final MatchUiState state;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Caption This',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.4,
                  color: colors.ink,
                ),
              ),
            ),
            FrameCounter(current: state.currentRound, total: state.totalRounds),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        ProgressSegments(current: state.currentRound, total: state.totalRounds),
      ],
    );
  }
}

class _StaggeredCaptionList extends StatefulWidget {
  const _StaggeredCaptionList({
    required this.captions,
    required this.ownId,
    required this.votedId,
    required this.onVote,
  });

  final List<CaptionOption> captions;
  final String? ownId;
  final String? votedId;
  final ValueChanged<String> onVote;

  @override
  State<_StaggeredCaptionList> createState() => _StaggeredCaptionListState();
}

class _StaggeredCaptionListState extends State<_StaggeredCaptionList> {
  int _visible = 0;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timer != null || _visible >= widget.captions.length) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _visible = widget.captions.length;
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 110), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(
        () => _visible = (_visible + 1).clamp(0, widget.captions.length),
      );
      if (_visible >= widget.captions.length) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var i = 0; i < widget.captions.length; i++)
          AnimatedOpacity(
            opacity: i < _visible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedSlide(
              offset: i < _visible ? Offset.zero : const Offset(0, 0.08),
              duration: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                child: _CaptionCard(
                  caption: widget.captions[i],
                  own: widget.captions[i].id == widget.ownId,
                  selected: widget.captions[i].id == widget.votedId,
                  locked: widget.votedId != null,
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    widget.onVote(widget.captions[i].id);
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CaptionCard extends StatelessWidget {
  const _CaptionCard({
    required this.caption,
    required this.own,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final CaptionOption caption;
  final bool own;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Opacity(
      opacity: own ? 0.55 : 1,
      child: Material(
        color: selected ? colors.raised : colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rControl),
        child: InkWell(
          onTap: own || locked ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadii.rControl),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.rControl),
              border: Border.all(
                color: selected ? colors.accent : colors.hairline,
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    caption.text,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      color: colors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                if (own)
                  Text(
                    'Yours',
                    style: TextStyle(fontSize: 12, color: colors.ink3),
                  )
                else if (selected)
                  Icon(Icons.check_circle, size: 18, color: colors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaggeredCaptionResults extends StatefulWidget {
  const _StaggeredCaptionResults({
    required this.entries,
    required this.topVotes,
  });

  final List<CaptionEntry> entries;
  final int topVotes;

  @override
  State<_StaggeredCaptionResults> createState() =>
      _StaggeredCaptionResultsState();
}

class _StaggeredCaptionResultsState extends State<_StaggeredCaptionResults> {
  int _visible = 0;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timer != null || _visible >= widget.entries.length) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _visible = widget.entries.length;
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 160), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _visible = (_visible + 1).clamp(0, widget.entries.length));
      if (_visible >= widget.entries.length) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var i = 0; i < widget.entries.length; i++)
          AnimatedOpacity(
            opacity: i < _visible ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: AnimatedSlide(
              offset: i < _visible ? Offset.zero : const Offset(0, 0.08),
              duration: const Duration(milliseconds: 220),
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                child: _CaptionResultCard(
                  entry: widget.entries[i],
                  index: i,
                  topVotes: widget.topVotes,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CaptionResultCard extends StatelessWidget {
  const _CaptionResultCard({
    required this.entry,
    required this.index,
    required this.topVotes,
  });

  final CaptionEntry entry;
  final int index;
  final int topVotes;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final isTop = topVotes > 0 && entry.votes == topVotes;
    final badge = entry.votes == 0
        ? 'Zero votes'
        : isTop
        ? (entry.votes >= 3 ? 'Group menace' : 'Top caption')
        : entry.votes == 1
        ? '1 vote'
        : '${entry.votes} votes';
    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}',
              style: tabularFigures(
                TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  color: colors.ink3,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.text,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${entry.authorName} · $badge',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: colors.ink2),
                      ),
                    ),
                    Text(
                      '+${entry.points}',
                      style: tabularFigures(
                        TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isTop ? colors.accent : colors.ink2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
