import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

/// Five more rounds: three fresh frames, a short window to swap them, and one
/// approve action so nobody stalls the group.
class ExtendScreen extends ConsumerWidget {
  const ExtendScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final isHost = state.isHosting;
    final approved = state.extensionApproved;

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
                    l10n.moreRounds(5),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.4,
                      color: colors.ink,
                    ),
                  ),
                ),
                _CountdownPill(seconds: state.extensionSecondsLeft),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              l10n.swapBeforeTimer,
              style: TextStyle(fontSize: 13, color: colors.ink2, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.s16),
            if (state.extensionCandidates.isEmpty)
              SurfaceCard(
                child: EmptyState(
                  title: l10n.pickingExtraPhotos,
                  body: l10n.freshFrames,
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.extensionCandidates.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.s12,
                  crossAxisSpacing: AppSpacing.s12,
                  childAspectRatio: 0.84,
                ),
                itemBuilder: (context, index) => _ExtensionTile(
                  candidate: state.extensionCandidates[index],
                  index: index,
                  onSwap: approved
                      ? null
                      : () => unawaited(
                          isHost
                              ? coordinator.swapExtensionCandidate(index)
                              : coordinator.clientSwapExtensionCandidate(index),
                        ),
                ),
              ),
            const SizedBox(height: AppSpacing.s16),
            Row(
              children: <Widget>[
                Expanded(
                  child: SecondaryButton(
                    label: l10n.rerollAll,
                    icon: Icons.refresh,
                    onPressed: approved
                        ? null
                        : () => unawaited(
                            isHost
                                ? coordinator.rerollExtensionCandidates()
                                : coordinator.clientRerollExtension(),
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: PrimaryButton(
                    label: approved
                        ? l10n.waitingForPlayersButton
                        : l10n.approve,
                    onPressed: approved || state.extensionCandidates.isEmpty
                        ? null
                        : () => unawaited(
                            isHost
                                ? coordinator.approveExtension()
                                : coordinator.clientApproveExtension(),
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
}

class _CountdownPill extends StatelessWidget {
  const _CountdownPill({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(AppRadii.rSm),
        border: Border.all(color: colors.hairline),
      ),
      child: Text(
        context.l10n.secondsShort(seconds),
        style: tabularFigures(
          TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.ink,
          ),
        ),
      ),
    );
  }
}

class _ExtensionTile extends StatelessWidget {
  const _ExtensionTile({
    required this.candidate,
    required this.index,
    required this.onSwap,
  });

  final PhotoCandidate candidate;
  final int index;
  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
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
                  _PhotoBytes(bytes: candidate.bytes),
                  Positioned(
                    left: AppSpacing.s8,
                    top: AppSpacing.s8,
                    child: NumberTag(
                      label: (index + 1).toString().padLeft(2, '0'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onSwap,
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: Text(l10n.swap, style: const TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                foregroundColor: colors.ink2,
                disabledForegroundColor: colors.ink3,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.rSm),
                ),
              ),
            ),
          ),
        ],
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
      return Container(
        color: colors.raised,
        alignment: Alignment.center,
        child: Icon(Icons.image_outlined, size: 20, color: colors.ink3),
      );
    }
    return Image.memory(
      data,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) => Container(
        color: colors.raised,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 20,
          color: colors.ink3,
        ),
      ),
    );
  }
}
