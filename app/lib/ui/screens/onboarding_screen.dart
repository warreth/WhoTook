import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatars.dart';
import '../../core/constants.dart';
import '../../core/models/models.dart';
import '../../core/links.dart';
import '../../core/theme/game_skin.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../widgets/avatar_editor.dart';
import '../widgets/common.dart';
import '../widgets/game_background.dart';

/// First run: name, terms and a clear path into the game. Private albums and
/// photo access live in Settings and at the first photo check.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final TextEditingController _name = TextEditingController();
  bool _acceptedTerms = false;
  String _avatar = kAvatarIds.first;
  String? _avatarPhoto;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
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
          (current) =>
              current.copyWith(nickname: name, onboardingCompleted: true),
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
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s24),
            children: <Widget>[
              Row(
                children: <Widget>[
                  const WhoTookLogo(size: 40),
                  const SizedBox(width: AppSpacing.s12),
                  Text(
                    'WhoTook',
                    style: gameDisplay(
                      size: 28,
                      color: colors.ink,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s32),
              Text(
                context.l10n.guessWhosePhoto,
                style: gameDisplay(
                  size: 32,
                  height: 1.08,
                  color: colors.ink,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                context.l10n.onboardingTagline,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.ink2,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: context.l10n.yourName,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.rControl),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s20),
              AvatarEditor(
                avatar: _avatar,
                photoBase64: _avatarPhoto,
                onChanged: (avatar, photo) => setState(() {
                  _avatar = avatar;
                  _avatarPhoto = photo;
                }),
              ),
              const SizedBox(height: AppSpacing.s16),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    CheckboxListTile(
                      value: _acceptedTerms,
                      onChanged: (value) =>
                          setState(() => _acceptedTerms = value ?? false),
                      title: Text(
                        context.l10n.acceptTerms,
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
                          onPressed: () =>
                              unawaited(openExternal(context, kTermsUrl)),
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
                          child: Text(context.l10n.termsLink),
                        ),
                        TextButton(
                          onPressed: () =>
                              unawaited(openExternal(context, kPrivacyUrl)),
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
                          child: Text(context.l10n.privacy),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              if (_error != null) ...<Widget>[
                NoticeBanner(
                  message: _error!,
                  tone: StatusTone.warning,
                  icon: Icons.error_outline,
                ),
                const SizedBox(height: AppSpacing.s12),
              ],
              PrimaryButton(
                label: context.l10n.continueLabel,
                onPressed: _finish,
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                context.l10n.onboardingPhotoNote,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colors.ink3, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
