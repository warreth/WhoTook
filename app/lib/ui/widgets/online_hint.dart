import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';

/// A quiet, dismissible lobby hint for players on the internet path.
///
/// The local path is faster and keeps photos off the relay. It is not more
/// encrypted than WebRTC, so the copy never calls it safer.
class OnlinePlayHint extends StatefulWidget {
  const OnlinePlayHint({super.key, required this.mode});

  final ConnectionMode? mode;

  @override
  State<OnlinePlayHint> createState() => _OnlinePlayHintState();
}

class _OnlinePlayHintState extends State<OnlinePlayHint> {
  bool _dismissed = false;

  bool get _online =>
      widget.mode == ConnectionMode.webrtcP2p ||
      widget.mode == ConnectionMode.webrtcTurn;

  @override
  Widget build(BuildContext context) {
    if (!_online || _dismissed) return const SizedBox.shrink();
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.wifi, size: 16, color: colors.ink3),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              l10n.onlineWifiHint,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: colors.ink2,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s4),
          IconButton(
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              maximumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            iconSize: 18,
            tooltip: l10n.close,
            onPressed: () => setState(() => _dismissed = true),
            icon: Icon(Icons.close, color: colors.ink3),
          ),
        ],
      ),
    );
  }
}
