import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import 'common.dart';

/// Host-only mid-game invite. It floats above the current round but does not
/// pause timers or change match state; closing it drops the Host right back.
Future<void> showRoomQrDialog(
  BuildContext context, {
  required String roomId,
  required String inviteUrl,
}) {
  return showDialog<void>(
    context: context,
    useSafeArea: true,
    barrierDismissible: true,
    builder: (_) => RoomQrDialog(roomId: roomId, inviteUrl: inviteUrl),
  );
}

class RoomQrDialog extends StatelessWidget {
  const RoomQrDialog({
    super.key,
    required this.roomId,
    required this.inviteUrl,
  });

  final String roomId;
  final String inviteUrl;

  static const Color _qrInk = Color(0xFF1F1B16);

  Future<void> _share(BuildContext context) async {
    final l10n = context.l10n;
    final box = context.findRenderObject() as RenderBox?;
    final shareOrigin = box != null && box.hasSize
        ? (box.localToGlobal(Offset.zero) & box.size)
        : null;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: inviteUrl,
          subject: l10n.roomQrShareText,
          title: l10n.roomQrShareText,
          sharePositionOrigin: shareOrigin,
        ),
      );
    } on Object {
      await Clipboard.setData(ClipboardData(text: inviteUrl));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.copied)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final qrSize = math.min(MediaQuery.sizeOf(context).width - 136, 220.0);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppRadii.rCard),
            border: Border.all(color: colors.ink, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colors.ink,
                offset: const Offset(0, 6),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.scanToJoin,
                      style: TextStyle(
                        fontSize: 22,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: colors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                l10n.scanToJoinBody,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: colors.ink2,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.rSm),
                    border: Border.all(color: colors.ink, width: 1),
                  ),
                  child: QrImageView(
                    data: inviteUrl,
                    version: QrVersions.auto,
                    size: qrSize,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: _qrInk,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: _qrInk,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.raised,
                    borderRadius: BorderRadius.circular(AppRadii.rSm),
                  ),
                  child: Text(
                    l10n.roomCode(roomId),
                    style: tabularFigures(
                      const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              SecondaryButton(
                label: l10n.shareInviteLink,
                icon: Icons.ios_share,
                onPressed: () => unawaited(_share(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
