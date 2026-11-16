import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/last_room_repository.dart';
import '../../l10n/l10n.dart';
import '../../core/theme/whotook_theme.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import 'join_screen.dart';
import 'settings_screen.dart';
import 'setup/mode_setup_screen.dart';

/// The front door: one clear decision, host or join, and nothing else.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  LastRoom? _lastRoom;
  bool _rejoining = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLastRoom());
  }

  Future<void> _loadLastRoom() async {
    final room = await ref.read(lastRoomRepositoryProvider).load();
    if (!mounted) return;
    setState(() => _lastRoom = room);
  }

  Future<void> _rejoin(LastRoom room) async {
    if (_rejoining) return;
    setState(() => _rejoining = true);
    await ref.read(matchCoordinatorProvider).joinMatch(room.inviteUrl);
    if (!mounted) return;
    setState(() => _rejoining = false);
  }

  Future<void> _forgetRoom() async {
    await ref.read(lastRoomRepositoryProvider).forget();
    if (!mounted) return;
    setState(() => _lastRoom = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final actions = _HomeActions(
      state: state,
      showGuide: wide,
      lastRoom: _lastRoom,
      rejoining: _rejoining,
      onRejoin: _rejoin,
      onForgetRoom: () => unawaited(_forgetRoom()),
      onHost: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ModeSetupScreen())),
      onJoin: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const JoinScreen())),
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 1120 : 720),
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
                        tooltip: l10n.settings,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (wide) {
                          return Row(
                            children: <Widget>[
                              const Expanded(flex: 3, child: _Hero()),
                              const SizedBox(width: AppSpacing.s24),
                              SizedBox(
                                width: 360,
                                child: Center(child: actions),
                              ),
                            ],
                          );
                        }
                        if (constraints.maxHeight >= 700) {
                          return Column(
                            children: <Widget>[
                              const Expanded(child: _Hero()),
                              actions,
                            ],
                          );
                        }
                        // Short windows scroll instead of squeezing the hero
                        // behind the action buttons.
                        return SingleChildScrollView(
                          child: Column(
                            children: <Widget>[
                              const SizedBox(height: 380, child: _Hero()),
                              actions,
                            ],
                          ),
                        );
                      },
                    ),
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

class _HomeActions extends StatelessWidget {
  const _HomeActions({
    required this.state,
    required this.showGuide,
    required this.lastRoom,
    required this.rejoining,
    required this.onRejoin,
    required this.onForgetRoom,
    required this.onHost,
    required this.onJoin,
  });

  final MatchUiState state;
  final bool showGuide;
  final LastRoom? lastRoom;
  final bool rejoining;
  final ValueChanged<LastRoom> onRejoin;
  final VoidCallback onForgetRoom;
  final VoidCallback onHost;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
          NoticeBanner(
            message: l10n.onlineRelayUsed,
            tone: StatusTone.warning,
            icon: Icons.wifi_tethering,
          ),
        ],
        const SizedBox(height: AppSpacing.s16),
        _BigAction(
          title: l10n.hostAGame,
          subtitle: l10n.hostAGameSubtitle,
          icon: Icons.groups_outlined,
          filled: true,
          onTap: onHost,
        ),
        const SizedBox(height: AppSpacing.s12),
        _BigAction(
          title: l10n.joinAGame,
          subtitle: l10n.joinAGameSubtitle,
          icon: Icons.qr_code_scanner,
          onTap: onJoin,
        ),
        if (lastRoom != null) ...<Widget>[
          const SizedBox(height: AppSpacing.s12),
          _RejoinCard(
            room: lastRoom!,
            busy: rejoining,
            onRejoin: () => onRejoin(lastRoom!),
            onForget: onForgetRoom,
          ),
        ],
        const SizedBox(height: AppSpacing.s12),
        Text(
          l10n.homeFooter,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: colors.ink3),
        ),
        if (showGuide) ...<Widget>[
          const SizedBox(height: AppSpacing.s16),
          const _HowItPlaysCard(),
        ],
      ],
    );
  }
}

class _RejoinCard extends StatelessWidget {
  const _RejoinCard({
    required this.room,
    required this.busy,
    required this.onRejoin,
    required this.onForget,
  });

  final LastRoom room;
  final bool busy;
  final VoidCallback onRejoin;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s12,
        AppSpacing.s8,
        AppSpacing.s8,
        AppSpacing.s8,
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.meeting_room_outlined, size: 20, color: colors.accent),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.lastRoom,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  l10n.roomLabel(room.roomId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: colors.ink2),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: busy ? null : onRejoin,
            child: busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.rejoin),
          ),
          IconButton(
            tooltip: l10n.forgetRoom,
            onPressed: busy ? null : onForget,
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _HowItPlaysCard extends StatelessWidget {
  const _HowItPlaysCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s12,
        AppSpacing.s16,
        AppSpacing.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionLabel(l10n.howItPlays),
          _GuideRow(
            icon: Icons.casino_outlined,
            title: l10n.guideSetTable,
            body: l10n.guideSetTableBody,
          ),
          _GuideRow(
            icon: Icons.qr_code_scanner,
            title: l10n.guideScanIn,
            body: l10n.guideScanInBody,
          ),
          _GuideRow(
            icon: Icons.photo_library_outlined,
            title: l10n.guidePlay,
            body: l10n.guidePlayBody,
          ),
        ],
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 24,
            child: Icon(icon, size: 16, color: colors.accent),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    color: colors.ink2,
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

class _Hero extends StatelessWidget {
  const _Hero();

  static const List<String> _photos = <String>[
    'assets/samples/party-dog.jpg',
    'assets/samples/party-cat.jpg',
    'assets/samples/party-hamster.jpg',
    'assets/samples/party-pizza.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    const paper = Color(0xFFF7F4EE);
    const muted = Color(0xFFC7BFB3);
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.rModal),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x241F1B16),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.rModal),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Transform.scale(
              scale: 1.08,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                child: Image.asset(
                  _photos.first,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
            const ColoredBox(color: Color(0x591B1713)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0x001B1713), Color(0xE61B1713)],
                  stops: <double>[0.35, 0.9],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _HeroFact(label: l10n.heroFact),
                  const Spacer(),
                  Text(
                    l10n.heroTitle,
                    style: const TextStyle(
                      fontSize: 38,
                      height: 0.98,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1.6,
                      color: paper,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Text(
                    l10n.heroSubtitle,
                    style: TextStyle(fontSize: 14, height: 1.35, color: muted),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  const _ContactStrip(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0x661B1713),
        borderRadius: BorderRadius.circular(AppRadii.rSm),
        border: Border.all(color: const Color(0x33F7F4EE)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xFFF7F4EE),
        ),
      ),
    );
  }
}

/// A tiny contact sheet with real sample frames, the game's visual motif.
class _ContactStrip extends StatelessWidget {
  const _ContactStrip();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        children: <Widget>[
          for (var i = 0; i < _Hero._photos.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Transform.rotate(
                angle: <double>[-0.02, 0.015, -0.01, 0.02][i],
                child: AspectRatio(
                  aspectRatio: 1.32,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.rSm),
                      border: Border.all(
                        color: i == 0
                            ? const Color(0xFFE59437)
                            : const Color(0x55F7F4EE),
                        width: i == 0 ? 1.5 : 1,
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x331B1713),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.rSm - 1),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Image.asset(_Hero._photos[i], fit: BoxFit.cover),
                          const CropFrameOverlay(
                            color: Color(0x88F7F4EE),
                            armLength: 7,
                            strokeWidth: 1,
                            inset: 5,
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.rCard),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.ink,
            blurRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: filled ? colors.accent : colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.rCard),
              border: Border.all(
                color: filled ? colors.ink : colors.ink,
                width: 2,
              ),
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
      ),
    );
  }
}
