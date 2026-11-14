import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import 'join_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final settings = ref.watch(appSettingsProvider).value;
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;

    return Scaffold(
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.s20,
          AppSpacing.s8,
          AppSpacing.s20,
          AppSpacing.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PrimaryButton(
              label: 'Host a match',
              icon: Icons.groups_outlined,
              onPressed: () async {
                await coordinator.hostMatch(config: state.config);
                if (!context.mounted) return;
                final error = coordinator.state.errorMessage;
                if (error != null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error)));
                }
              },
            ),
            const SizedBox(height: AppSpacing.s12),
            SecondaryButton(
              label: 'Join with a QR code',
              icon: Icons.qr_code_scanner,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const JoinScreen()),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s24,
            AppSpacing.s16,
            AppSpacing.s24,
            AppSpacing.s24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  WhoTookMark(size: 28, color: colors.accent),
                  const SizedBox(width: AppSpacing.s12),
                  const Expanded(
                    child: Text(
                      'WhoTook',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Settings',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Guess whose camera roll it is.',
                style: TextStyle(fontSize: 15, color: colors.ink2, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.s20),
              _ExclusionSummary(
                count: settings?.excludedAlbumIds.length ?? 0,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              if (state.turnLimitNotice != null) ...<Widget>[
                NoticeBanner(
                  message: 'Online relay is used up today. Use the same Wi-Fi to keep playing.',
                  tone: StatusTone.warning,
                  icon: Icons.wifi_tethering,
                ),
                const SizedBox(height: AppSpacing.s12),
              ],
              if (state.errorMessage != null) ...<Widget>[
                NoticeBanner(
                  message: state.errorMessage!,
                  tone: StatusTone.warning,
                  icon: Icons.error_outline,
                ),
                const SizedBox(height: AppSpacing.s12),
              ],
              _MatchPreset(
                config: state.config,
                onRounds: (rounds) => unawaited(coordinator.setRounds(rounds)),
                onSeconds: (seconds) =>
                    unawaited(coordinator.setRoundSeconds(seconds)),
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                'Photos stay with the players in the match.',
                style: TextStyle(fontSize: 13, color: colors.ink2, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExclusionSummary extends StatelessWidget {
  const _ExclusionSummary({required this.count, required this.onTap});

  final int count;
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
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.rCard),
            border: Border.all(color: colors.hairline),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.photo_library_outlined, size: 18, color: colors.ink2),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      count == 0
                          ? 'No albums excluded'
                          : '$count albums excluded',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 0
                          ? 'Every album can be drawn from'
                          : 'Private folders stay out of matches',
                      style: TextStyle(fontSize: 12, color: colors.ink2),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: colors.ink3),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchPreset extends StatelessWidget {
  const _MatchPreset({
    required this.config,
    required this.onRounds,
    required this.onSeconds,
  });

  final MatchConfig config;
  final ValueChanged<int> onRounds;
  final ValueChanged<int> onSeconds;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionLabel('Rounds per match'),
          Row(
            children: <Widget>[
              for (final rounds in <int>[5, 10, 15, 20])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: rounds == 20 ? 0 : AppSpacing.s8,
                    ),
                    child: _PresetChip(
                      label: '$rounds',
                      selected: config.roundsK == rounds,
                      onTap: () => onRounds(rounds),
                      mono: true,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          const SectionLabel('Seconds per photo'),
          Row(
            children: <Widget>[
              for (final seconds in <int>[6, 8, 12])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: seconds == 12 ? 0 : AppSpacing.s8,
                    ),
                    child: _PresetChip(
                      label: '$seconds',
                      selected: config.roundSeconds == seconds,
                      onTap: () => onSeconds(seconds),
                      mono: true,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'The host can add five more rounds when the last photo is done.',
            style: TextStyle(fontSize: 12, color: colors.ink3),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.mono = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: selected ? colors.bg : colors.ink2,
      fontFamily: mono ? 'JetBrainsMono' : null,
    );
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.rSm),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.ink : colors.raised,
            borderRadius: BorderRadius.circular(AppRadii.rControl),
            border: Border.all(color: colors.hairline),
          ),
          child: Text(label, style: style),
        ),
      ),
    );
  }
}
