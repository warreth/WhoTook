import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/diagnostics/bug_report_service.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';

/// Opens the user's mail app with a compact, privacy-safe diagnostic report.
/// The service falls back to the clipboard when no mail app can be opened.
class ReportIssueButton extends StatelessWidget {
  const ReportIssueButton({
    super.key,
    this.tile = false,
    this.screenLabel,
  });

  final bool tile;
  final String? screenLabel;

  Future<void> _report(BuildContext context) {
    return BugReportService.instance.reportIssue(
      context,
      screenLabel: screenLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (tile) {
      final colors = WhoTookColors.of(context);
      return ListTile(
        minTileHeight: 56,
        leading: const Icon(Icons.bug_report_outlined, size: 20),
        title: Text(
          l10n.reportIssue,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          l10n.reportIssueBody(kSupportEmail),
          style: TextStyle(fontSize: 12, color: colors.ink2),
        ),
        onTap: () => _report(context),
      );
    }
    return TextButton.icon(
      onPressed: () => _report(context),
      icon: const Icon(Icons.bug_report_outlined, size: 18),
      label: Text(l10n.reportIssue),
    );
  }
}
