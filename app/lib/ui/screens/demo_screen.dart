import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/whotook_theme.dart';
import '../widgets/common.dart';

/// A hidden, fully offline walkthrough for store reviewers. It uses bundle
/// images and fake players, never the network or the real photo library.
class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

enum _DemoPhase { photos, guess, reveal, podium }

class _DemoPlayer {
  const _DemoPlayer(this.name, this.score, {this.isHost = false});

  final String name;
  final int score;
  final bool isHost;
}

class _DemoScreenState extends State<DemoScreen> {
  static const List<String> _photos = <String>[
    'assets/samples/party-dog.jpg',
    'assets/samples/party-cat.jpg',
    'assets/samples/party-hamster.jpg',
    'assets/samples/party-pizza.jpg',
  ];
  static const List<_DemoPlayer> _players = <_DemoPlayer>[
    _DemoPlayer('Bram', 2410, isHost: true),
    _DemoPlayer('Lotte', 3410),
    _DemoPlayer('Sam', 2740),
    _DemoPlayer('Noor', 3180),
  ];

  _DemoPhase _phase = _DemoPhase.photos;
  int _offset = 0;
  int _secondsLeft = 8;
  String? _guessed;
  bool _ownerRevealed = false;
  Timer? _ticker;
  Timer? _revealTimer;

  bool get _isCorrect => _guessed == 'Lotte';

  @override
  void dispose() {
    _ticker?.cancel();
    _revealTimer?.cancel();
    super.dispose();
  }

  void _startRound() {
    _ticker?.cancel();
    _revealTimer?.cancel();
    setState(() {
      _phase = _DemoPhase.guess;
      _secondsLeft = 8;
      _guessed = null;
      _ownerRevealed = false;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        _revealOwner();
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  void _guess(String name) {
    if (_guessed != null || _ownerRevealed) return;
    _ticker?.cancel();
    setState(() => _guessed = name);
    _revealTimer = Timer(const Duration(milliseconds: 700), _revealOwner);
  }

  void _revealOwner() {
    if (!mounted || _ownerRevealed) return;
    _ticker?.cancel();
    setState(() {
      _ownerRevealed = true;
      _phase = _DemoPhase.reveal;
    });
  }

  void _reroll() {
    setState(() => _offset = (_offset + 1) % _photos.length);
  }

  void _restart() {
    _ticker?.cancel();
    _revealTimer?.cancel();
    setState(() {
      _phase = _DemoPhase.photos;
      _offset = 0;
      _secondsLeft = 8;
      _guessed = null;
      _ownerRevealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Review demo'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Close demo',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: switch (_phase) {
              _DemoPhase.photos => _PhotosStep(
                photos: _photos,
                offset: _offset,
                onReroll: _reroll,
                onStart: _startRound,
              ),
              _DemoPhase.guess => _GuessStep(
                photo: _photos[_offset % _photos.length],
                players: _players,
                secondsLeft: _secondsLeft,
                guessed: _guessed,
                onGuess: _guess,
              ),
              _DemoPhase.reveal => _RevealStep(
                photo: _photos[_offset % _photos.length],
                guessed: _guessed,
                isCorrect: _isCorrect,
                onNext: () => setState(() => _phase = _DemoPhase.podium),
              ),
              _DemoPhase.podium => _PodiumStep(
                players: _players,
                onRestart: _restart,
                onClose: () => Navigator.of(context).maybePop(),
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(AppRadii.rControl),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.science_outlined, size: 16, color: colors.ink2),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              'Demo with fake players. No network and no real photos.',
              style: TextStyle(fontSize: 12, color: colors.ink2, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotosStep extends StatelessWidget {
  const _PhotosStep({
    required this.photos,
    required this.offset,
    required this.onReroll,
    required this.onStart,
  });

  final List<String> photos;
  final int offset;
  final VoidCallback onReroll;
  final VoidCallback onStart;

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
        const _DemoBanner(),
        const SizedBox(height: AppSpacing.s20),
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
            const FrameCounter(current: 4, total: 4),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          'All 4 demo photos are here. Reroll all for a different set.',
          style: TextStyle(fontSize: 13, color: colors.ink2, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.s16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.s12,
          crossAxisSpacing: AppSpacing.s12,
          childAspectRatio: 0.94,
          children: <Widget>[
            for (var i = 0; i < photos.length; i++)
              _DemoPhoto(
                asset: photos[(i + offset) % photos.length],
                number: i + 1,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        SecondaryButton(
          label: 'Reroll all',
          icon: Icons.refresh,
          onPressed: onReroll,
        ),
        const SizedBox(height: AppSpacing.s12),
        PrimaryButton(label: 'Start demo round', onPressed: onStart),
      ],
    );
  }
}

class _DemoPhoto extends StatelessWidget {
  const _DemoPhoto({required this.asset, required this.number});

  final String asset;
  final int number;

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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.rSm),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(asset, fit: BoxFit.cover),
            Positioned(
              left: AppSpacing.s8,
              top: AppSpacing.s8,
              child: NumberTag(label: number.toString().padLeft(2, '0')),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuessStep extends StatelessWidget {
  const _GuessStep({
    required this.photo,
    required this.players,
    required this.secondsLeft,
    required this.guessed,
    required this.onGuess,
  });

  final String photo;
  final List<_DemoPlayer> players;
  final int secondsLeft;
  final String? guessed;
  final ValueChanged<String> onGuess;

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
        const _DemoBanner(),
        const SizedBox(height: AppSpacing.s16),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Who took this?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: colors.ink,
                ),
              ),
            ),
            Text(
              '0:${secondsLeft.toString().padLeft(2, '0')}',
              style: tabularFigures(
                TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: secondsLeft <= 3 ? colors.negative : colors.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.rCard),
            border: Border.all(color: colors.hairline),
          ),
          padding: const EdgeInsets.all(AppSpacing.s8),
          child: AspectRatio(
            aspectRatio: 1.08,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.rSm),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image.asset(photo, fit: BoxFit.cover),
                  const CropFrameOverlay(
                    color: Color(0xCCF7F4EE),
                    armLength: 16,
                    strokeWidth: 2,
                    inset: 10,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.s8,
          crossAxisSpacing: AppSpacing.s8,
          childAspectRatio: 2.6,
          children: <Widget>[
            for (final player in players)
              _GuessButton(
                player: player,
                guessed: guessed == player.name,
                locked: guessed != null,
                onTap: () => onGuess(player.name),
              ),
          ],
        ),
      ],
    );
  }
}

class _GuessButton extends StatelessWidget {
  const _GuessButton({
    required this.player,
    required this.guessed,
    required this.locked,
    required this.onTap,
  });

  final _DemoPlayer player;
  final bool guessed;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Material(
      color: guessed ? colors.raised : colors.card,
      borderRadius: BorderRadius.circular(AppRadii.rControl),
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadii.rControl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.rControl),
            border: Border.all(
              color: guessed ? colors.accent : colors.hairline,
            ),
          ),
          child: Row(
            children: <Widget>[
              PlayerAvatar(initial: player.name, isHost: player.isHost),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  player.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (guessed)
                Icon(Icons.check_circle, size: 18, color: colors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevealStep extends StatelessWidget {
  const _RevealStep({
    required this.photo,
    required this.guessed,
    required this.isCorrect,
    required this.onNext,
  });

  final String photo;
  final String? guessed;
  final bool isCorrect;
  final VoidCallback onNext;

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
        const _DemoBanner(),
        const SizedBox(height: AppSpacing.s16),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.rCard),
            border: Border.all(color: colors.hairline),
          ),
          padding: const EdgeInsets.all(AppSpacing.s8),
          child: AspectRatio(
            aspectRatio: 1.2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.rSm),
              child: Image.asset(photo, fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        Text(
          'Shot by Lotte',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.6,
            color: colors.ink,
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          guessed == null
              ? 'The timer ran out.'
              : isCorrect
              ? 'You got it. +820'
              : 'You guessed $guessed. Next time.',
          style: TextStyle(
            fontSize: 14,
            color: isCorrect ? colors.positive : colors.ink2,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.s20),
        SurfaceCard(
          child: Column(
            children: <Widget>[
              for (final player in _DemoScreenState._players)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: <Widget>[
                      PlayerAvatar(initial: player.name, isHost: player.isHost),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Text(
                          player.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${player.score}',
                        style: tabularFigures(
                          TextStyle(fontSize: 13, color: colors.ink2),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        PrimaryButton(label: 'See the podium', onPressed: onNext),
      ],
    );
  }
}

class _PodiumStep extends StatelessWidget {
  const _PodiumStep({
    required this.players,
    required this.onRestart,
    required this.onClose,
  });

  final List<_DemoPlayer> players;
  final VoidCallback onRestart;
  final VoidCallback onClose;

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
        const _DemoBanner(),
        const SizedBox(height: AppSpacing.s24),
        Text(
          'CHAMPION',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 11,
            letterSpacing: 1.2,
            color: colors.ink3,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          'Lotte',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.8,
            color: colors.ink,
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          '3410 pts',
          textAlign: TextAlign.center,
          style: tabularFigures(
            TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 18,
              color: colors.accent,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s24),
        SurfaceCard(
          child: Column(
            children: <Widget>[
              for (final player in players)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: <Widget>[
                      PlayerAvatar(initial: player.name, isHost: player.isHost),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Text(
                          player.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${player.score}',
                        style: tabularFigures(
                          TextStyle(fontSize: 13, color: colors.ink2),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        PrimaryButton(label: 'Restart demo', onPressed: onRestart),
        const SizedBox(height: AppSpacing.s12),
        SecondaryButton(label: 'Close demo', onPressed: onClose),
      ],
    );
  }
}
