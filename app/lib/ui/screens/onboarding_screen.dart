import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatars.dart';
import '../../core/constants.dart';
import '../../core/links.dart';
import '../../core/theme/whotook_theme.dart';
import '../../state/providers.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/common.dart';

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
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Pick a name your friends will recognise.');
      return;
    }
    if (!_acceptedTerms) {
      setState(() => _error = 'Agree to the terms before you continue.');
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s24),
          children: <Widget>[
            Row(
              children: <Widget>[
                WhoTookMark(size: 32, color: colors.accent),
                const SizedBox(width: AppSpacing.s12),
                const Text(
                  'WhoTook',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s32),
            const Text(
              'Guess whose photo it is',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w500,
                height: 1.15,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'One photo. One guess. Tap who you think took it.',
              style: TextStyle(fontSize: 14, color: colors.ink2, height: 1.45),
            ),
            const SizedBox(height: AppSpacing.s24),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Your name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.rControl),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s20),
            const SectionLabel('Pick an avatar'),
            AvatarPicker(
              selected: _avatar,
              onSelect: (avatar) => setState(() => _avatar = avatar),
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
                    title: const Text(
                      'I agree to the Terms of use and Community rules.',
                      style: TextStyle(fontSize: 13, height: 1.35),
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
                        child: const Text('Terms and community rules'),
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
                        child: const Text('Privacy'),
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
            PrimaryButton(label: 'Continue', onPressed: _finish),
            const SizedBox(height: AppSpacing.s12),
            Text(
              'Photos are only read when a match starts. You can keep private albums out of every game in Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.ink3, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
