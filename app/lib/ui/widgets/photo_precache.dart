import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/media/photo_memory_cache.dart';

/// Warms Flutter's decoded-image cache while a screen is still visible. The
/// widget paints nothing; it only schedules work after the frame.
class PhotoPrecache extends StatefulWidget {
  const PhotoPrecache({
    super.key,
    this.photoIds = const <String>[],
    this.includeCached = false,
  });

  final List<String> photoIds;
  final bool includeCached;

  @override
  State<PhotoPrecache> createState() => _PhotoPrecacheState();
}

class _PhotoPrecacheState extends State<PhotoPrecache> {
  bool _scheduled = false;
  final Set<String> _warmedIds = <String>{};

  Set<String> _targetIds() => <String>{
    ...widget.photoIds,
    if (widget.includeCached) ...PhotoMemoryCache.instance.photoIds,
  };

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant PhotoPrecache oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasUnwarmed = _targetIds().any((id) => !_warmedIds.contains(id));
    if (hasUnwarmed || widget.includeCached != oldWidget.includeCached) {
      _schedule();
    }
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) unawaited(_warm());
    });
  }

  Future<void> _warm() async {
    for (final id in _targetIds()) {
      if (!mounted) break;
      if (_warmedIds.contains(id)) continue;
      final provider = PhotoMemoryCache.instance.providerFor(id);
      if (provider == null) continue;
      _warmedIds.add(id);
      try {
        await precacheImage(provider, context);
      } on Object {
        // A single unreadable photo must not stop the vault.
      }
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
