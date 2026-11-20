import 'dart:async';

import 'package:flutter/material.dart';

import 'report_issue_button.dart';

/// Shows a small report button after the player has not touched the screen
/// for [threshold]. A long lobby wait, a stalled round and a frozen screen all
/// end with a way to send diagnostics instead of a dead end.
///
/// Any tap outside the button hides it and restarts the timer. A phase change
/// ([resetToken]) restarts it too, so normal fast play never shows it.
class IdleReportOverlay extends StatefulWidget {
  const IdleReportOverlay({
    super.key,
    required this.child,
    required this.resetToken,
    this.enabled = true,
    this.threshold = const Duration(seconds: 45),
    this.screenLabel,
  });

  final Widget child;
  final Object resetToken;
  final bool enabled;
  final Duration threshold;
  final String? screenLabel;

  @override
  State<IdleReportOverlay> createState() => _IdleReportOverlayState();
}

class _IdleReportOverlayState extends State<IdleReportOverlay> {
  final GlobalKey _chipKey = GlobalKey();
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _restart(notify: false);
  }

  @override
  void didUpdateWidget(covariant IdleReportOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetToken != widget.resetToken ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.threshold != widget.threshold) {
      _restart(notify: false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart({bool notify = true}) {
    _timer?.cancel();
    if (_visible) {
      if (notify) {
        setState(() => _visible = false);
      } else {
        _visible = false;
      }
    }
    if (!widget.enabled) return;
    _timer = Timer(widget.threshold, () {
      if (!mounted || !widget.enabled) return;
      setState(() => _visible = true);
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    final box = _chipKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.attached) {
      final local = box.globalToLocal(event.position);
      if (local.dx >= 0 &&
          local.dy >= 0 &&
          local.dx <= box.size.width &&
          local.dy <= box.size.height) {
        return;
      }
    }
    _restart();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          widget.child,
          if (_visible)
            Positioned(
              right: 12,
              bottom: 12,
              child: SafeArea(
                top: false,
                left: false,
                child: Material(
                  key: _chipKey,
                  type: MaterialType.transparency,
                  child: ReportIssueButton(
                    compact: true,
                    screenLabel: widget.screenLabel,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
