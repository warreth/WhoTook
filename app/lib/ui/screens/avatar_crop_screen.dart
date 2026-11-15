import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../widgets/common.dart';

/// The crop is a seam so widget tests can skip the rasterizer.
abstract class AvatarCropper {
  Future<Uint8List?> crop(RenderRepaintBoundary boundary);
}

class DeviceAvatarCropper implements AvatarCropper {
  const DeviceAvatarCropper();

  @override
  Future<Uint8List?> crop(RenderRepaintBoundary boundary) async {
    final image = await boundary.toImage(pixelRatio: 2.2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    final png = data.buffer.asUint8List();
    try {
      return await FlutterImageCompress.compressWithList(
        png,
        minWidth: 192,
        minHeight: 192,
        quality: 80,
        keepExif: false,
        format: CompressFormat.jpeg,
      );
    } on Object {
      return png;
    }
  }
}

final avatarCropperProvider = Provider<AvatarCropper>(
  (ref) => const DeviceAvatarCropper(),
);

/// Square crop for the optional avatar. The player zooms and drags the frame,
/// then we keep a small JPEG that stays on this phone and in the live room.
class AvatarCropScreen extends ConsumerStatefulWidget {
  const AvatarCropScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  ConsumerState<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends ConsumerState<AvatarCropScreen> {
  static const double _cropSize = 300;
  final GlobalKey _boundaryKey = GlobalKey();
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final result = await ref.read(avatarCropperProvider).crop(boundary);
      if (result == null || !mounted) return;
      Navigator.of(context).pop<Uint8List>(result);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cropTitle),
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const SizedBox(height: AppSpacing.s20),
            Text(
              l10n.cropHint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.ink2),
            ),
            const SizedBox(height: AppSpacing.s20),
            Center(
              child: RepaintBoundary(
                key: _boundaryKey,
                child: ClipRect(
                  child: SizedBox.square(
                    dimension: _cropSize,
                    child: ColoredBox(
                      color: colors.bg,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          InteractiveViewer(
                            minScale: 1,
                            maxScale: 4,
                            boundaryMargin: EdgeInsets.zero,
                            child: Image.memory(
                              widget.imageBytes,
                              fit: BoxFit.cover,
                              width: _cropSize,
                              height: _cropSize,
                              gaplessPlayback: true,
                            ),
                          ),
                          IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.onAccent,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s20),
              child: PrimaryButton(
                label: _saving ? l10n.savingPhoto : l10n.useThisPhoto,
                busy: _saving,
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
