import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatars.dart';
import '../../core/constants.dart';
import '../../core/links.dart';
import '../../core/models/models.dart';
import '../../core/theme/game_skin.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../widgets/avatar_editor.dart';
import '../widgets/common.dart';
import '../widgets/game_background.dart';

/// First-install 3-step onboarding: offline/hotspot play, open-source privacy,
/// then profile & community rules.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pages = PageController();
  final TextEditingController _name = TextEditingController();
  int _step = 0;
  bool _acceptedTerms = false;
  String _avatar = kAvatarIds.first;
  String? _avatarPhoto;
  String? _error;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _goToStep(int step) async {
    final target = step.clamp(0, 2);
    setState(() => _step = target);
    if (_pages.hasClients) {
      await _pages.animateToPage(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = context.l10n.pickNameError);
      return;
    }
    if (!_acceptedTerms) {
      setState(() => _error = context.l10n.acceptTermsError);
      return;
    }
    await ref
        .read(appSettingsProvider.notifier)
        .apply(
          (current) => current.copyWith(
            nickname: name,
            avatar: _avatar,
            avatarPhoto: _avatarPhoto,
            clearAvatarPhoto: _avatarPhoto == null,
            onboardingCompleted: true,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GameBackdrop(
        mode: GameMode.classic,
        lobby: true,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s24,
                      AppSpacing.s16,
                      AppSpacing.s24,
                      AppSpacing.s8,
                    ),
                    child: Row(
                      children: <Widget>[
                        const WhoTookLogo(size: 38),
                        const SizedBox(width: AppSpacing.s12),
                        Text(
                          'WhoTook',
                          style: gameDisplay(
                            size: 26,
                            color: colors.ink,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const Spacer(),
                        for (var i = 0; i < 3; i++) ...<Widget>[
                          if (i > 0) const SizedBox(width: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: _step == i ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _step == i ? colors.accent : colors.card,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: colors.ink, width: 1.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      onPageChanged: (index) => setState(() => _step = index),
                      children: <Widget>[
                        _OfflineStepPage(onNext: () => unawaited(_goToStep(1))),
                        _PrivacyStepPage(
                          onBack: () => unawaited(_goToStep(0)),
                          onNext: () => unawaited(_goToStep(2)),
                          onOpenRepo: () =>
                              unawaited(openExternal(context, kRepoUrl)),
                        ),
                        _ProfileStepPage(
                          nameController: _name,
                          avatar: _avatar,
                          avatarPhoto: _avatarPhoto,
                          acceptedTerms: _acceptedTerms,
                          error: _error,
                          onAvatarChanged: (avatar, photo) => setState(() {
                            _avatar = avatar;
                            _avatarPhoto = photo;
                          }),
                          onTermsChanged: (value) =>
                              setState(() => _acceptedTerms = value),
                          onOpenTerms: () =>
                              unawaited(openExternal(context, kTermsUrl)),
                          onOpenPrivacy: () =>
                              unawaited(openExternal(context, kPrivacyUrl)),
                          onBack: () => unawaited(_goToStep(1)),
                          onFinish: () => unawaited(_finish()),
                        ),
                      ],
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

class _OfflineStepPage extends StatelessWidget {
  const _OfflineStepPage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s24,
        AppSpacing.s12,
        AppSpacing.s24,
        AppSpacing.s24,
      ),
      children: <Widget>[
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s12,
            ),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(AppRadii.rCard),
              border: Border.all(color: colors.ink, width: 2.5),
              boxShadow: <BoxShadow>[
                BoxShadow(color: colors.ink, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.flight_takeoff, size: 28, color: colors.accent),
                const SizedBox(width: AppSpacing.s12),
                Icon(Icons.terrain_outlined, size: 30, color: colors.positive),
                const SizedBox(width: AppSpacing.s12),
                Icon(Icons.wifi_tethering, size: 28, color: colors.ink),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s24),
        Text(
          l10n.onboardingOfflineTitle,
          style: gameDisplay(
            size: 30,
            height: 1.08,
            color: colors.ink,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          l10n.onboardingOfflineBody,
          style: TextStyle(fontSize: 15, color: colors.ink2, height: 1.45),
        ),
        const SizedBox(height: AppSpacing.s20),
        SurfaceCard(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.rSm),
                  border: Border.all(color: colors.ink, width: 2),
                ),
                child: Icon(Icons.wifi_tethering, size: 22, color: colors.ink),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.onboardingHotspotTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.onboardingHotspotBody,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: colors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s24),
        PrimaryButton(
          label: l10n.onboardingNext,
          icon: Icons.arrow_forward,
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _PrivacyStepPage extends StatelessWidget {
  const _PrivacyStepPage({
    required this.onBack,
    required this.onNext,
    required this.onOpenRepo,
  });

  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onOpenRepo;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s24,
        AppSpacing.s12,
        AppSpacing.s24,
        AppSpacing.s24,
      ),
      children: <Widget>[
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s12,
            ),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(AppRadii.rCard),
              border: Border.all(color: colors.ink, width: 2.5),
              boxShadow: <BoxShadow>[
                BoxShadow(color: colors.ink, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.lock_outline, size: 28, color: colors.positive),
                const SizedBox(width: AppSpacing.s12),
                Icon(Icons.devices, size: 28, color: colors.ink),
                const SizedBox(width: AppSpacing.s12),
                Icon(Icons.code, size: 28, color: colors.accent),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s24),
        Text(
          l10n.onboardingPrivacyTitle,
          style: gameDisplay(
            size: 30,
            height: 1.08,
            color: colors.ink,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        SurfaceCard(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _PrivacyFactRow(
                icon: Icons.phonelink_lock,
                title: l10n.onboardingPrivacyDirectTitle,
                body: l10n.onboardingPrivacyDirectBody,
              ),
              const SizedBox(height: AppSpacing.s12),
              _PrivacyFactRow(
                icon: Icons.visibility_off_outlined,
                title: l10n.onboardingPrivacyNoDataTitle,
                body: l10n.onboardingPrivacyNoDataBody,
              ),
              const SizedBox(height: AppSpacing.s12),
              _PrivacyFactRow(
                icon: Icons.code,
                title: l10n.onboardingPrivacyOpenSourceTitle,
                body: l10n.onboardingPrivacyOpenSourceBody,
              ),
              const SizedBox(height: AppSpacing.s8),
              TextButton.icon(
                onPressed: onOpenRepo,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(l10n.onboardingViewSource),
                style: TextButton.styleFrom(
                  foregroundColor: colors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s24),
        Row(
          children: <Widget>[
            Expanded(
              child: SecondaryButton(
                label: l10n.back,
                onPressed: onBack,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: l10n.onboardingNext,
                icon: Icons.arrow_forward,
                onPressed: onNext,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PrivacyFactRow extends StatelessWidget {
  const _PrivacyFactRow({
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.raised,
            borderRadius: BorderRadius.circular(AppRadii.rSm),
            border: Border.all(color: colors.ink, width: 1.5),
          ),
          child: Icon(icon, size: 18, color: colors.ink),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: colors.ink2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileStepPage extends StatelessWidget {
  const _ProfileStepPage({
    required this.nameController,
    required this.avatar,
    required this.avatarPhoto,
    required this.acceptedTerms,
    required this.error,
    required this.onAvatarChanged,
    required this.onTermsChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
    required this.onBack,
    required this.onFinish,
  });

  final TextEditingController nameController;
  final String avatar;
  final String? avatarPhoto;
  final bool acceptedTerms;
  final String? error;
  final void Function(String avatar, String? photo) onAvatarChanged;
  final ValueChanged<bool> onTermsChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s24,
        AppSpacing.s8,
        AppSpacing.s24,
        AppSpacing.s24,
      ),
      children: <Widget>[
        Text(
          l10n.guessWhosePhoto,
          style: gameDisplay(
            size: 28,
            height: 1.08,
            color: colors.ink,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          l10n.onboardingTagline,
          style: TextStyle(fontSize: 14, color: colors.ink2, height: 1.45),
        ),
        const SizedBox(height: AppSpacing.s16),
        SurfaceCard(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.raised,
                  borderRadius: BorderRadius.circular(AppRadii.rSm),
                  border: Border.all(color: colors.ink, width: 2),
                ),
                child: Icon(
                  Icons.wifi_tethering,
                  size: 18,
                  color: colors.positive,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.onboardingFreeTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.onboardingFreeBody,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: colors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.yourName,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.rControl),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        AvatarEditor(
          avatar: avatar,
          photoBase64: avatarPhoto,
          onChanged: onAvatarChanged,
        ),
        const SizedBox(height: AppSpacing.s16),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CheckboxListTile(
                value: acceptedTerms,
                onChanged: (value) => onTermsChanged(value ?? false),
                title: Text(
                  l10n.acceptTerms,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              Wrap(
                spacing: AppSpacing.s4,
                children: <Widget>[
                  TextButton(
                    onPressed: onOpenTerms,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s8,
                      ),
                      foregroundColor: colors.ink,
                      textStyle: const TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: Text(l10n.termsLink),
                  ),
                  TextButton(
                    onPressed: onOpenPrivacy,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s8,
                      ),
                      foregroundColor: colors.ink2,
                      textStyle: const TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 13,
                      ),
                    ),
                    child: Text(l10n.privacy),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s20),
        if (error != null) ...<Widget>[
          NoticeBanner(
            message: error!,
            tone: StatusTone.warning,
            icon: Icons.error_outline,
          ),
          const SizedBox(height: AppSpacing.s12),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: SecondaryButton(
                label: l10n.back,
                onPressed: onBack,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: l10n.continueLabel,
                onPressed: onFinish,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Text(
          l10n.onboardingPhotoNote,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: colors.ink3, height: 1.4),
        ),
      ],
    );
  }
}
