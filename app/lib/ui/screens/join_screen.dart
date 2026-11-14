import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/whotook_theme.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

/// Join is one action: open the scanner. A pasted or shared link also works,
/// which is how remote friends get in from a chat app.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );
  final TextEditingController _paste = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _paste.dispose();
    super.dispose();
  }

  Future<void> _join(String raw) async {
    if (_busy) return;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    await _controller.stop();
    await ref.read(matchCoordinatorProvider).joinMatch(trimmed);
    if (!mounted) return;
    setState(() => _busy = false);
    final state = ref.read(matchCoordinatorProvider).state;
    if (state.errorMessage != null) {
      setState(() => _error = state.errorMessage);
      await _controller.start();
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a match'),
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                MobileScanner(
                  controller: _controller,
                  errorBuilder: (context, error) => const _CameraUnavailable(),
                  onDetect: (capture) {
                    for (final barcode in capture.barcodes) {
                      final value = barcode.rawValue;
                      if (value != null && value.isNotEmpty) {
                        unawaited(_join(value));
                        return;
                      }
                    }
                  },
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 232,
                      height: 232,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.rCard),
                        border: Border.all(color: colors.onAccent, width: 2),
                      ),
                    ),
                  ),
                ),
                if (_busy)
                  Container(
                    color: colors.bg.withValues(alpha: 0.85),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        CircularProgressIndicator(color: colors.accent),
                        const SizedBox(height: AppSpacing.s16),
                        Text(
                          'Connecting to the host',
                          style: TextStyle(fontSize: 14, color: colors.ink2),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (_error != null) ...<Widget>[
                    NoticeBanner(
                      message: _error!,
                      tone: StatusTone.warning,
                      icon: Icons.error_outline,
                    ),
                    const SizedBox(height: AppSpacing.s12),
                  ],
                  TextField(
                    controller: _paste,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Or paste an invite link',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.rControl),
                      ),
                    ),
                    onSubmitted: (value) => unawaited(_join(value)),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  SecondaryButton(
                    label: 'Use this link',
                    icon: Icons.link,
                    onPressed: () => unawaited(_join(_paste.text)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps the screen usable when the camera is missing, denied or busy: the
/// paste field below still gets the player into the match.
class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable();

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Container(
      color: colors.raised,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: const NoticeBanner(
        message: 'Camera unavailable. Allow camera access in system settings or paste an invite link below.',
        tone: StatusTone.warning,
        icon: Icons.no_photography_outlined,
      ),
    );
  }
}
