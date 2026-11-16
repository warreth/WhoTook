import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';
import 'common.dart';

/// A short, visible alert for a screenshot taken by anyone in the room. It
/// listens to the match state so it can appear on every screen, not only the
/// classic guessing screen.
class ScreenshotAlertToast extends ConsumerStatefulWidget {
  const ScreenshotAlertToast({super.key});

  @override
  ConsumerState<ScreenshotAlertToast> createState() =>
      _ScreenshotAlertToastState();
}

class _ScreenshotAlertToastState extends ConsumerState<ScreenshotAlertToast> {
  ScreenshotBanner? _banner;
  Timer? _timer;
  int? _seenAtMs;

  @override
  void initState() {
    super.initState();
    final alerts = ref.read(matchStateProvider).value?.screenshotAlerts;
    _seenAtMs = alerts == null || alerts.isEmpty ? null : alerts.last.atMs;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _show(ScreenshotBanner banner) {
    _seenAtMs = banner.atMs;
    _timer?.cancel();
    setState(() => _banner = banner);
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<MatchUiState>>(matchStateProvider, (previous, next) {
      final alerts = next.value?.screenshotAlerts;
      if (alerts == null || alerts.isEmpty) return;
      final latest = alerts.last;
      if (latest.atMs == _seenAtMs) return;
      _show(latest);
    });
    final banner = _banner;
    if (banner == null) return const SizedBox.shrink();
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final state = ref.watch(matchStateProvider).value;
    final player = state?.players
        .where((player) => player.id == banner.playerId)
        .firstOrNull;
    final name = banner.playerName.isEmpty ? l10n.player : banner.playerName;
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
                    PlayerAvatar(
                      initial: name,
                      avatar: player?.avatar ?? '',
                      photoBase64: player == null
                          ? null
                          : state?.avatarPhotos[player.id],
                      size: 28,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 16,
                      color: colors.accent,
                    ),
                    const SizedBox(width: AppSpacing.s4),
                    Flexible(
                      child: Text(
                        l10n.screenshotBy(name),
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
