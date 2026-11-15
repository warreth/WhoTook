import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatars.dart';
import '../../core/media/avatar_photo_service.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../screens/avatar_crop_screen.dart';
import 'avatar_picker.dart';
import 'common.dart';

/// Icon avatars plus the optional selfie or gallery photo. The callback gets
/// the short id and, for a photo, the base64 JPEG.
class AvatarEditor extends ConsumerStatefulWidget {
  const AvatarEditor({
    super.key,
    required this.avatar,
    required this.photoBase64,
    required this.onChanged,
  });

  final String avatar;
  final String? photoBase64;
  final void Function(String avatar, String? photoBase64) onChanged;

  @override
  ConsumerState<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends ConsumerState<AvatarEditor> {
  bool _picking = false;

  Future<void> _pick(bool camera) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final bytes = await ref
          .read(avatarPhotoServiceProvider)
          .pick(camera: camera);
      if (bytes == null || !mounted) return;
      final cropped = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute<Uint8List>(
          builder: (_) => AvatarCropScreen(imageBytes: bytes),
        ),
      );
      if (cropped == null || !mounted) return;
      widget.onChanged(kPhotoAvatar, encodeAvatarPhoto(cropped));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final hasPhoto =
        widget.avatar == kPhotoAvatar && widget.photoBase64 != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            PlayerAvatar(
              initial: l10n.you,
              avatar: widget.avatar,
              photoBase64: widget.photoBase64,
              size: 64,
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    hasPhoto ? l10n.yourPhotoAvatar : l10n.pickAnAvatar,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasPhoto ? l10n.photoAvatarStored : l10n.avatarChoices,
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
        const SizedBox(height: AppSpacing.s12),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: _picking ? null : () => unawaited(_pick(true)),
              icon: const Icon(Icons.photo_camera_front_outlined, size: 18),
              label: Text(l10n.takeSelfie),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                foregroundColor: colors.ink,
                side: BorderSide(color: colors.hairline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.rControl),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _picking ? null : () => unawaited(_pick(false)),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(l10n.choosePhoto),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                foregroundColor: colors.ink,
                side: BorderSide(color: colors.hairline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.rControl),
                ),
              ),
            ),
            if (hasPhoto)
              TextButton(
                onPressed: () => widget.onChanged(kAvatarIds.first, null),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  foregroundColor: colors.ink2,
                ),
                child: Text(l10n.useIcon),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        AvatarPicker(
          selected: widget.avatar,
          onSelect: (avatar) => widget.onChanged(avatar, null),
        ),
      ],
    );
  }
}
