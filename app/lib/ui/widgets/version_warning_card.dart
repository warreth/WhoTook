import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/links.dart';
import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';

/// A skippable warning shown over the room when this phone runs an older
/// build than someone else. The room keeps playing; updating is optional.
class VersionWarningCard extends StatelessWidget {
  const VersionWarningCard({
    super.key,
    required this.warning,
    required this.onDismiss,
  });

  final VersionWarning warning;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Material(
      elevation: 3,
      shadowColor: colors.ink.withValues(alpha: 0.18),
      color: colors.card,
      borderRadius: BorderRadius.circular(AppRadii.rCard),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s12,
          AppSpacing.s8,
          AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.rCard),
          border: Border.all(color: colors.negative),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.system_update_alt, color: colors.negative, size: 22),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Different app versions',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Someone is on ${warning.latestVersion} (build ${warning.latestBuild}). '
                    'You are on ${warning.ownVersion} (build ${warning.ownBuild}). Update so rounds and photos stay in sync.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: colors.ink2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextButton(
                        onPressed: () =>
                            unawaited(openExternal(context, appStoreUrl())),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s8,
                          ),
                        ),
                        child: const Text('Get the update'),
                      ),
                      const SizedBox(width: AppSpacing.s4),
                      TextButton(
                        onPressed: onDismiss,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s8,
                          ),
                          foregroundColor: colors.ink2,
                        ),
                        child: const Text('Keep playing'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Keep playing',
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
