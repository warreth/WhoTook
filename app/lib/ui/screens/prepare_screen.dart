import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

/// Contact sheet: every player approves their own photos and can reroll as
/// often as they like before tapping Ready.
class PrepareScreen extends ConsumerWidget {
  const PrepareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final isHost = state.isHosting;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s20,
            AppSpacing.s16,
            AppSpacing.s20,
            AppSpacing.s24,
          ),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Check your photos',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.4,
                      color: colors.ink,
                    ),
                  ),
                ),
                FrameCounter(
                  current: state.candidates.length,
                  total: state.photosNeeded,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Swap anything you would rather not share. Nothing is shown to the group yet.',
              style: TextStyle(fontSize: 13, color: colors.ink2, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.s16),
            if (state.candidates.isEmpty)
              SurfaceCard(
                child: EmptyState(
                  title: 'Reading your photos',
                  body:
                      'Picking frames from the albums you allowed. This stays on your device.',
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.candidates.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.s12,
                      crossAxisSpacing: AppSpacing.s12,
                      childAspectRatio: 0.92,
                    ),
                itemBuilder: (context, index) {
                  final candidate = state.candidates[index];
                  return _CandidateTile(
                    candidate: candidate,
                    index: index,
                    onSwap: () => unawaited(
                      isHost
                          ? coordinator.swapCandidate(index)
                          : coordinator.clientSwapCandidate(index),
                    ),
                  );
                },
              ),
            const SizedBox(height: AppSpacing.s16),
            if (state.plantUnlocked && !state.plantUsed)
              _PlantTile(
                onTap: () => unawaited(_plant(context, coordinator, state, isHost)),
              ),
            if (state.plantUsed) ...<Widget>[
              const SizedBox(height: AppSpacing.s8),
              StatusRow(label: 'Secret photo planted', tone: StatusTone.positive),
            ],
            const SizedBox(height: AppSpacing.s16),
            Row(
              children: <Widget>[
                Expanded(
                  child: SecondaryButton(
                    label: 'Reroll all',
                    icon: Icons.refresh,
                    onPressed: () => unawaited(
                      isHost
                          ? coordinator.rerollCandidates()
                          : coordinator.clientRerollAll(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: PrimaryButton(
                    label: state.localReady
                        ? (state.isHosting ? 'Waiting for players' : 'Ready')
                        : 'Ready',
                    onPressed: state.localReady
                        ? null
                        : () => unawaited(
                            isHost
                                ? coordinator.markLocalReady()
                                : coordinator.clientMarkReady(),
                          ),
                  ),
                ),
              ],
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
        ),
      ),
    );
  }

  Future<void> _plant(
    BuildContext context,
    MatchCoordinator coordinator,
    MatchUiState state,
    bool isHost,
  ) async {
    final choice = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSpacing.s20),
          children: <Widget>[
            const Text(
              'Pick the photo to plant',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'One per match. Nobody learns which one it was until the podium.',
              style: TextStyle(
                fontSize: 13,
                color: WhoTookColors.of(sheetContext).ink2,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            for (var i = 0; i < state.candidates.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: 48,
                  height: 48,
                  child: _PhotoBytes(bytes: state.candidates[i].bytes),
                ),
                title: Text('Photo ${i + 1}'),
                onTap: () => Navigator.of(sheetContext).pop(i),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (isHost) {
      final candidate = state.candidates[choice];
      await coordinator.plantSecretPhoto(
        candidate.localAssetId,
        candidate.bytes ?? Uint8List(0),
      );
    } else {
      await coordinator.clientPlantPhoto(choice);
    }
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.candidate,
    required this.index,
    required this.onSwap,
  });

  final PhotoCandidate candidate;
  final int index;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rCard),
        border: Border.all(color: colors.hairline),
      ),
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.rSm),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _PhotoBytes(bytes: candidate.bytes, fit: BoxFit.cover),
                  Positioned(
                    left: AppSpacing.s8,
                    bottom: AppSpacing.s8,
                    child: _NumberTag(
                      label: (index + 1).toString().padLeft(2, '0'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          SizedBox(
            height: 40,
            child: TextButton.icon(
              onPressed: onSwap,
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: const Text('Swap', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: colors.ink2,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberTag extends StatelessWidget {
  const _NumberTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: tabularFigures(
          const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 10,
            color: Color(0xFF1F1B16),
          ),
        ),
      ),
    );
  }
}

class _PlantTile extends StatelessWidget {
  const _PlantTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(AppRadii.rCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.rCard),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.rCard),
            border: Border.all(color: colors.hairline),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.raised,
                  borderRadius: BorderRadius.circular(AppRadii.rSm),
                ),
                child: Icon(
                  Icons.local_florist_outlined,
                  size: 18,
                  color: colors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Plant one secret photo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'One per match. It quietly replaces one of your approved photos.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders compressed bytes, with a calm placeholder when a photo is still in
/// flight or the platform image decoder is unavailable.
class _PhotoBytes extends StatelessWidget {
  const _PhotoBytes({required this.bytes, this.fit = BoxFit.cover});

  final Uint8List? bytes;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final data = bytes;
    if (data == null || data.isEmpty) {
      return Container(
        color: colors.raised,
        alignment: Alignment.center,
        child: Icon(Icons.image_outlined, size: 20, color: colors.ink3),
      );
    }
    return Image.memory(
      data,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) => Container(
        color: colors.raised,
        alignment: Alignment.center,
        child: Icon(Icons.image_not_supported_outlined, size: 20, color: colors.ink3),
      ),
    );
  }
}
