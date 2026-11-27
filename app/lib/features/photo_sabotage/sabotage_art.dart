import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/media/photo_memory_cache.dart';
import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import 'sabotage_painter.dart';

/// A cached photo with one or more sabotage strokes layered on top. The image
/// comes from [PhotoMemoryCache] and uses a stable key, so a vote tick or a
/// timer rebuild never flickers the photo.
class SabotageArt extends StatelessWidget {
  const SabotageArt({
    super.key,
    required this.photoId,
    required this.strokes,
    this.stickers = const <SabotageSticker>[],
    this.selectedStickerIndex,
    this.photoBytes,
    this.progress = 1,
    this.showWatermark = false,
    this.borderColor,
    this.fit = BoxFit.cover,
  });

  final String photoId;
  final List<SabotageStroke> strokes;
  final List<SabotageSticker> stickers;
  final int? selectedStickerIndex;
  final Uint8List? photoBytes;
  final double progress;
  final bool showWatermark;
  final Color? borderColor;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final bytes = photoBytes ?? PhotoMemoryCache.instance.bytesFor(photoId);
    final provider = bytes == null
        ? PhotoMemoryCache.instance.providerFor(photoId)
        : MemoryImage(bytes);
    return Semantics(
      container: true,
      image: true,
      label: context.l10n.gamePhoto,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.rControl),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.raised,
            border: Border.all(color: borderColor ?? colors.ink, width: 2),
            borderRadius: BorderRadius.circular(AppRadii.rControl),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (provider == null)
                Center(
                  child: Icon(
                    Icons.photo_outlined,
                    size: 40,
                    color: colors.ink3,
                  ),
                )
              else
                Image(
                  key: ValueKey<String>('sabotage-$photoId'),
                  image: provider,
                  fit: fit,
                  gaplessPlayback: true,
                ),
              CustomPaint(
                painter: SabotageDrawingPainter(
                  strokes: strokes,
                  stickers: stickers,
                  selectedStickerIndex: selectedStickerIndex,
                  progress: progress,
                ),
              ),
              if (showWatermark)
                Positioned(
                  right: 8,
                  bottom: 6,
                  child: Text(
                    'whotook.party',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.72),
                      shadows: const <Shadow>[
                        Shadow(color: Colors.black54, blurRadius: 3),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
