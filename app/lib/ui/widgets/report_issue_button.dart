import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/diagnostics/bug_report_service.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';

enum _ReportAction { email, share, copy }

/// Opens the report sheet: a compact mailto report, the full log as a shared
/// text file, or the report on the clipboard.
///
/// A mailto link cannot carry an attachment, so "Share log file" uses the
/// system share sheet; picking Mail or Gmail there attaches the file.
class ReportIssueButton extends StatelessWidget {
  const ReportIssueButton({
    super.key,
    this.tile = false,
    this.compact = false,
    this.screenLabel,
  });

  final bool tile;
  final bool compact;
  final String? screenLabel;

  Future<void> _open(BuildContext context) async {
    final action = await showModalBottomSheet<_ReportAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: WhoTookColors.of(context).card,
      builder: (_) => const _ReportSheet(),
    );
    if (action == null || !context.mounted) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case _ReportAction.email:
        await BugReportService.instance.reportIssue(
          context,
          screenLabel: screenLabel,
        );
      case _ReportAction.share:
        final shared = await BugReportService.instance.shareReport(
          context,
          screenLabel: screenLabel,
        );
        if (!shared) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.reportShareFailed)),
          );
        }
      case _ReportAction.copy:
        final copied = await BugReportService.instance.copyReport(
          context,
          screenLabel: screenLabel,
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(copied ? l10n.reportCopied : l10n.reportCopyFailed),
          ),
        );
    }
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
        onTap: () => _open(context),
      );
    }
    if (compact) {
      final colors = WhoTookColors.of(context);
      return OutlinedButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.bug_report_outlined, size: 16),
        label: Text(l10n.reportIssue, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.ink2,
          backgroundColor: colors.card,
          side: BorderSide(color: colors.hairline),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      );
    }
    return TextButton.icon(
      onPressed: () => _open(context),
      icon: const Icon(Icons.bug_report_outlined, size: 18),
      label: Text(l10n.reportIssue),
    );
  }
}

class _ReportSheet extends StatelessWidget {
  const _ReportSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = WhoTookColors.of(context);
    final canShare = BugReportService.instance.canShareFile;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.reportIssue,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.reportIssueBody(kSupportEmail),
                    style: TextStyle(fontSize: 12, color: colors.ink2),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline, size: 20),
              title: Text(
                l10n.reportEmailAction,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                l10n.reportEmailBody,
                style: TextStyle(fontSize: 12, color: colors.ink2),
              ),
              onTap: () => Navigator.of(context).pop(_ReportAction.email),
            ),
            if (canShare)
              ListTile(
                leading: const Icon(Icons.attach_file, size: 20),
                title: Text(
                  l10n.reportShareAction,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  l10n.reportShareBody,
                  style: TextStyle(fontSize: 12, color: colors.ink2),
                ),
                onTap: () => Navigator.of(context).pop(_ReportAction.share),
              ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined, size: 20),
              title: Text(
                l10n.reportCopyAction,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () => Navigator.of(context).pop(_ReportAction.copy),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
