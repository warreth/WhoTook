import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/whotook_theme.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import 'join_screen.dart';
import 'settings_screen.dart';
import 'setup/rounds_setup_screen.dart';

/// The front door: one clear decision, host or join, and nothing else.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s20,
                AppSpacing.s8,
                AppSpacing.s20,
                AppSpacing.s12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      WhoTookMark(size: 24, color: colors.accent),
                      const SizedBox(width: AppSpacing.s8),
                      const Expanded(
                        child: Text(
                          'WhoTook',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
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
                  const Expanded(child: _Hero()),
                  if (state.errorMessage != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.s8),
                    NoticeBanner(
                      message: state.errorMessage!,
                      tone: StatusTone.warning,
                      icon: Icons.error_outline,
                    ),
                  ],
                  if (state.turnLimitNotice != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.s8),
                    const NoticeBanner(
                      message: 'Online relay is used up today. Use the same Wi-Fi to keep playing.',
                      tone: StatusTone.warning,
                      icon: Icons.wifi_tethering,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s16),
                  _BigAction(
                    title: 'Host a game',
                    subtitle: 'You set the rounds and pick the photos',
                    icon: Icons.groups_outlined,
                    filled: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RoundsSetupScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  _BigAction(
                    title: 'Join a game',
                    subtitle: "Scan the host's QR code",
                    icon: Icons.qr_code_scanner,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const JoinScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Text(
                    'Same room, same Wi-Fi. Photos stay between players.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: colors.ink3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    const panel = Color(0xFF1B1713);
    const paper = Color(0xFFF7F4EE);
    const muted = Color(0xFFC7BFB3);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.rModal),
      child: ColoredBox(
        color: panel,
        child: Stack(
          children: <Widget>[
            Positioned(
              right: AppSpacing.s20,
              top: AppSpacing.s20,
              child: ExcludeSemantics(
                child: WhoTookMark(size: 132, color: const Color(0x24F7F4EE)),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Spacer(),
                    const Text(
                      'Whose camera\nroll is this?',
                      style: TextStyle(
                        fontSize: 38,
                        height: 0.98,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1.6,
                        color: paper,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      'One photo at a time. Everyone guesses whose it is.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    const _ContactStrip(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tiny contact sheet: four numbered frames, the game's own visual motif.
class _ContactStrip extends StatelessWidget {
  const _ContactStrip();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        children: <Widget>[
          for (var i = 0; i < 4; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1.28,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF27221D),
                    borderRadius: BorderRadius.circular(AppRadii.rSm),
                    border: Border.all(
                      color: i == 0
                          ? const Color(0xFFE59437)
                          : const Color(0x33F7F4EE),
                    ),
                  ),
                  child: Stack(
                    children: <Widget>[
                      const Positioned.fill(
                        child: CropFrameOverlay(
                          color: Color(0x55F7F4EE),
                          armLength: 7,
                          strokeWidth: 1,
                          inset: 5,
                        ),
                      ),
                      Positioned(
                        left: 5,
                        top: 5,
                        child: NumberTag(
                          label: (i + 1).toString().padLeft(2, '0'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final foreground = filled ? colors.onAccent : colors.ink;
    final secondary = filled
        ? colors.onAccent.withValues(alpha: 0.78)
        : colors.ink2;
    return Material(
      color: filled ? colors.accent : colors.card,
      borderRadius: BorderRadius.circular(AppRadii.rCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.rCard),
            border: filled ? null : Border.all(color: colors.hairline),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 24, color: foreground),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: secondary),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: filled
                    ? colors.onAccent.withValues(alpha: 0.7)
                    : colors.ink3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
