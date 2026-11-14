import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/whotook_theme.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/mode_picker.dart';
import 'setup_scaffold.dart';

/// The last setup step: the host approves the frames that open the room.
class HostPhotosScreen extends ConsumerStatefulWidget {
  const HostPhotosScreen({super.key});

  @override
  ConsumerState<HostPhotosScreen> createState() => _HostPhotosScreenState();
}

class _HostPhotosScreenState extends ConsumerState<HostPhotosScreen> {
  bool _loading = true;
  bool _opening = false;
  int? _swapping;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePhotos());
  }

  Future<void> _ensurePhotos() async {
    final coordinator = ref.read(matchCoordinatorProvider);
    final current = ref.read(matchStateProvider).value ?? coordinator.state;
    if (current.candidates.isNotEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    await coordinator.drawHostCandidates();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _shuffle() async {
    if (_loading) return;
    setState(() => _loading = true);
    await ref.read(matchCoordinatorProvider).rerollHostCandidates();
    if (!mounted) return;
    setState(() => _loading = false);
    unawaited(HapticFeedback.selectionClick());
  }

  Future<void> _swap(int index) async {
    if (_swapping != null) return;
    setState(() => _swapping = index);
    await ref.read(matchCoordinatorProvider).swapHostCandidate(index);
    if (!mounted) return;
    setState(() => _swapping = null);
    unawaited(HapticFeedback.selectionClick());
  }

  Future<void> _openRoom() async {
    if (_opening) return;
    final coordinator = ref.read(matchCoordinatorProvider);
    final current = ref.read(matchStateProvider).value ?? coordinator.state;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _opening = true);
    await coordinator.hostMatch(config: current.config);
    if (!mounted) return;
    final next = coordinator.state;
    if (next.roomId == null || next.errorMessage != null) {
      setState(() => _opening = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(next.errorMessage ?? 'Could not open the room.'),
        ),
      );
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final candidates = state.candidates;
    final mode = modeInfo(state.config.mode);

    return SetupScaffold(
      step: 4,
      title: 'Pick your photos',
      subtitle: 'These frames go into the deck first. Swap any you would rather keep private.',
      primaryLabel: 'Open the room',
      primaryEnabled: !_loading && !_opening && candidates.isNotEmpty,
      busy: _opening,
      onPrimary: () => unawaited(_openRoom()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MetaRow(config: state.config),
          const SizedBox(height: AppSpacing.s16),
          if (_loading)
            const SurfaceCard(
              child: Row(
                children: <Widget>[
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Text(
                      'Picking frames from your gallery. This stays on your phone.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            )
          else if (candidates.isEmpty)
            SurfaceCard(
              child: EmptyState(
                title: 'No photos to show yet',
                body:
                    state.errorMessage ??
                    'Allow photo access, or try another album in settings.',
                actionLabel: 'Try again',
                onAction: () => unawaited(_shuffle()),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: candidates.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.s12,
                crossAxisSpacing: AppSpacing.s12,
                childAspectRatio: 0.94,
              ),
              itemBuilder: (context, index) => _PhotoTile(
                candidate: candidates[index],
                index: index,
                showDate: state.config.needsPhotoDates,
                busy: _swapping == index,
                onSwap: () => unawaited(_swap(index)),
              ),
            ),
          if (candidates.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.s12),
            SecondaryButton(
              label: 'Shuffle these frames',
              icon: Icons.shuffle,
              onPressed: _loading ? null : () => unawaited(_shuffle()),
            ),
          ],
          if (state.errorMessage != null && candidates.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.s12),
            NoticeBanner(
              message: state.errorMessage!,
              tone: StatusTone.warning,
              icon: Icons.error_outline,
            ),
          ],
          const SizedBox(height: AppSpacing.s16),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: colors.raised,
              borderRadius: BorderRadius.circular(AppRadii.rControl),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.lock_outline, size: 16, color: colors.ink2),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    'You can add more photos once friends join. ${mode.label} starts after everyone readies up.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: colors.ink2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.config});

  final MatchConfig config;

  @override
  Widget build(BuildContext context) {
    final info = modeInfo(config.mode);
    final pace = switch (config.roundSeconds) {
      6 => 'Fast',
      12 => 'Slow',
      _ => 'Normal',
    };
    return Wrap(
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s8,
      children: <Widget>[
        _MetaChip(
          icon: Icons.casino_outlined,
          label: '${config.roundsK} rounds',
        ),
        _MetaChip(
          icon: Icons.timer_outlined,
          label: '$pace ${config.roundSeconds}s',
        ),
        _MetaChip(icon: info.icon, label: info.label),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rSm),
        border: Border.all(color: colors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: colors.ink3),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: colors.ink2)),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.candidate,
    required this.index,
    required this.showDate,
    required this.busy,
    required this.onSwap,
  });

  final PhotoCandidate candidate;
  final int index;
  final bool showDate;
  final bool busy;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final month = candidate.capturedMonth;
    final year = candidate.capturedYear;
    final dateLabel = month == null || year == null
        ? null
        : '${_months[month - 1]} $year';
    return Semantics(
      label: 'Photo ${index + 1}',
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadii.rCard),
          border: Border.all(color: colors.hairline),
        ),
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.rSm),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _PhotoBytes(bytes: candidate.bytes),
              Positioned(
                left: AppSpacing.s8,
                top: AppSpacing.s8,
                child: NumberTag(label: (index + 1).toString().padLeft(2, '0')),
              ),
              if (showDate && dateLabel != null)
                Positioned(
                  left: AppSpacing.s8,
                  bottom: AppSpacing.s8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC1F1B16),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      dateLabel,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 9,
                        color: Color(0xFFF7F4EE),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: AppSpacing.s8,
                bottom: AppSpacing.s8,
                child: Semantics(
                  button: true,
                  label: 'Swap photo ${index + 1}',
                  child: Material(
                    color: const Color(0xCC1F1B16),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: busy ? null : onSwap,
                      child: SizedBox.square(
                        dimension: 44,
                        child: busy
                            ? const Padding(
                                padding: EdgeInsets.all(13),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFF7F4EE),
                                ),
                              )
                            : const Icon(
                                Icons.swap_horiz,
                                size: 20,
                                color: Color(0xFFF7F4EE),
                              ),
                      ),
                    ),
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

class _PhotoBytes extends StatelessWidget {
  const _PhotoBytes({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final data = bytes;
    if (data == null || data.isEmpty) {
      return ColoredBox(
        color: colors.raised,
        child: Center(
          child: Icon(Icons.image_outlined, size: 24, color: colors.ink3),
        ),
      );
    }
    return Image.memory(
      data,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) => ColoredBox(
        color: colors.raised,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 24,
            color: colors.ink3,
          ),
        ),
      ),
    );
  }
}

const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
