import 'dart:async';
import 'dart:collection';
import 'dart:io' show File, Platform;
import 'dart:math' show min;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';
import '../constants.dart';
import '../distribution.dart';

enum BugReportDelivery { launched, copied, failed }

/// In-memory diagnostics for the email report. Nothing is uploaded and no
/// photo, photo name, room secret, receipt or IP address belongs in this log.
class BugReportService {
  BugReportService({
    Future<bool> Function(Uri uri)? launch,
    Future<void> Function(String text)? copy,
    Future<File> Function(String name, String contents)? writeFile,
    Future<bool> Function(File file, String subject, String text)? shareFile,
  }) : _launch = launch ?? _launchExternal,
       _copy = copy ?? _copyToClipboard,
       _writeFile = writeFile ?? _writeTempReport,
       _shareFile = shareFile ?? _shareReportFile;

  static final BugReportService instance = BugReportService();

  static const int maxEvents = 50;
  static const int maxMessageLength = 480;
  static const int maxMailtoLength = 1800;

  final ListQueue<_DiagnosticEvent> _events = ListQueue<_DiagnosticEvent>();
  final Future<bool> Function(Uri uri) _launch;
  final Future<void> Function(String text) _copy;
  final Future<File> Function(String name, String contents) _writeFile;
  final Future<bool> Function(File file, String subject, String text)
  _shareFile;

  String _version = kAppVersion;
  int _build = kAppBuildNumber;
  String? _osLabelOverride;
  String? _deviceLabel;
  String _mode = '-';
  String _role = '-';
  String _phase = '-';
  String _connection = '-';
  String _screen = '-';
  bool _demo = false;
  bool _hooksInstalled = false;

  /// File sharing is unavailable on the web build; email and clipboard work.
  bool get canShareFile => !kIsWeb;

  void configure({
    String? version,
    int? build,
    String? osLabel,
    String? deviceLabel,
  }) {
    if (version != null && version.isNotEmpty) _version = version;
    if (build != null && build > 0) _build = build;
    if (osLabel != null && osLabel.isNotEmpty) _osLabelOverride = osLabel;
    if (deviceLabel != null && deviceLabel.isNotEmpty) {
      _deviceLabel = deviceLabel;
    }
  }

  void installErrorHooks() {
    if (_hooksInstalled) return;
    _hooksInstalled = true;
    final previousFlutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      record('FLUTTER', details.exceptionAsString(), stack: details.stack);
      previousFlutterError?.call(details);
    };
    final previousPlatformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      record('ERROR', '$error', stack: stack);
      return previousPlatformError?.call(error, stack) ?? false;
    };
  }

  void updateGame({
    String? mode,
    String? role,
    String? phase,
    String? connection,
    bool? demo,
  }) {
    if (mode != null) _mode = mode;
    if (role != null) _role = role;
    if (phase != null) _phase = phase;
    if (connection != null) _connection = connection;
    if (demo != null) _demo = demo;
  }

  void updateScreen(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    _screen = '${size.width.round()}x${size.height.round()}';
  }

  /// A short, redacted line for one subsystem. Never include a receipt,
  /// purchase token, room secret or photo name here.
  void record(String tag, String message, {StackTrace? stack}) {
    final safeTag = _safeTag(tag);
    final safeMessage = _redact(message).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (safeMessage.isEmpty) return;
    _events.addLast(
      _DiagnosticEvent(
        at: DateTime.now(),
        tag: safeTag,
        message: safeMessage.length > maxMessageLength
            ? '${safeMessage.substring(0, maxMessageLength)}...'
            : safeMessage,
      ),
    );
    if (stack != null && (safeTag == 'ERROR' || safeTag == 'FLUTTER')) {
      final firstFrames = stack
          .toString()
          .split('\n')
          .take(4)
          .map(_redact)
          .where((line) => line.trim().isNotEmpty)
          .join(' | ');
      if (firstFrames.isNotEmpty) {
        _events.addLast(
          _DiagnosticEvent(
            at: DateTime.now(),
            tag: safeTag,
            message: firstFrames.length > maxMessageLength
                ? '${firstFrames.substring(0, maxMessageLength)}...'
                : firstFrames,
          ),
        );
      }
    }
    while (_events.length > maxEvents) {
      _events.removeFirst();
    }
  }

  void recordError(String tag, Object error, [StackTrace? stack]) {
    record('$tag/ERROR', '$error', stack: stack);
  }

  String get appLine =>
      'App: v$_version+$_build (${_osLabelOverride ?? _fallbackOsLabel()} - ${_distributionLabel()})';

  String get contextLine =>
      'Mode: $_mode | Role: $_role${_demo ? ' (demo)' : ''} | Phase: $_phase';

  String get connectionLine => 'Connection: $_connection';

  String get recentLogs => _events.map((event) => event.format()).join('\n');

  String buildSubject() =>
      'WhoTook Bug Report - v$_version (${_platformLabel()})';

  String buildReport({
    required String intro,
    required String diagnosticsLabel,
    required String logsLabel,
    String? screenOverride,
    String? logsOverride,
  }) {
    final override = screenOverride?.trim();
    final screen = <String>[
      if (override != null && override.isNotEmpty) override,
      if (_screen != '-') _screen,
    ].join(' ');
    final buffer = StringBuffer()
      ..writeln(intro)
      ..writeln('-----------------------------------------')
      ..writeln()
      ..writeln('--- $diagnosticsLabel ---')
      ..writeln(appLine)
      ..writeln(contextLine)
      ..writeln(connectionLine)
      ..writeln('Screen: $screen');
    final device = _deviceLabel;
    if (device != null && device.isNotEmpty) {
      buffer.writeln('Device: $device');
    }
    buffer
      ..writeln()
      ..writeln('$logsLabel:')
      ..write(logsOverride ?? recentLogs);
    return buffer.toString().trimRight();
  }

  Uri buildMailto({required String subject, required String body}) {
    // Build the query by hand: Uri's queryParameters encodes spaces as '+',
    // which iOS Mail shows literally in a mailto body.
    return Uri.parse(
      'mailto:$kSupportEmail'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}',
    );
  }

  /// Sends the report or copies the full report when no mail app is available.
  /// The mailto body is capped at 1,800 encoded characters.
  Future<BugReportDelivery> deliver({
    required String intro,
    required String diagnosticsLabel,
    required String logsLabel,
    String? screenOverride,
  }) async {
    final fullBody = buildReport(
      intro: intro,
      diagnosticsLabel: diagnosticsLabel,
      logsLabel: logsLabel,
      screenOverride: screenOverride,
    );
    final body = _fitBody(
      intro: intro,
      diagnosticsLabel: diagnosticsLabel,
      logsLabel: logsLabel,
      screenOverride: screenOverride,
    );
    final uri = buildMailto(subject: buildSubject(), body: body);
    try {
      if (await _launch(uri)) return BugReportDelivery.launched;
    } on Object {
      // Fall through to the clipboard fallback.
    }
    try {
      await _copy(fullBody);
      return BugReportDelivery.copied;
    } on Object {
      return BugReportDelivery.failed;
    }
  }

  Future<void> reportIssue(
    BuildContext context, {
    String? screenOverride,
    String? screenLabel,
  }) async {
    final l10n = context.l10n;
    final result = await deliver(
      intro: l10n.reportBodyIntro,
      diagnosticsLabel: l10n.reportDiagnostics,
      logsLabel: l10n.reportRecentLogs,
      screenOverride: screenLabel ?? screenOverride,
    );
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    switch (result) {
      case BugReportDelivery.launched:
        return;
      case BugReportDelivery.copied:
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.reportNoMailApp(kSupportEmail))),
        );
      case BugReportDelivery.failed:
        messenger.showSnackBar(SnackBar(content: Text(l10n.reportCopyFailed)));
    }
  }

  /// Shares the full, untruncated report as a .txt file. A mailto link cannot
  /// carry an attachment, so the share sheet is the zero-server route: the
  /// player picks Mail or Gmail and the file is attached to the message.
  Future<bool> shareReport(
    BuildContext context, {
    String? screenOverride,
    String? screenLabel,
  }) {
    final l10n = context.l10n;
    return deliverFile(
      report: buildReport(
        intro: l10n.reportBodyIntro,
        diagnosticsLabel: l10n.reportDiagnostics,
        logsLabel: l10n.reportRecentLogs,
        screenOverride: screenLabel ?? screenOverride,
      ),
      text: l10n.reportShareMessage(kSupportEmail),
    );
  }

  /// Writes the report to a temp file and opens the system share sheet.
  Future<bool> deliverFile({
    required String report,
    required String text,
  }) async {
    try {
      final file = await _writeFile(reportFileName(), report);
      await _shareFile(file, buildSubject(), text);
      return true;
    } on Object {
      return false;
    }
  }

  /// Copies the full report, not the mailto-truncated version.
  Future<bool> copyReport(
    BuildContext context, {
    String? screenOverride,
    String? screenLabel,
  }) async {
    final l10n = context.l10n;
    try {
      await _copy(
        buildReport(
          intro: l10n.reportBodyIntro,
          diagnosticsLabel: l10n.reportDiagnostics,
          logsLabel: l10n.reportRecentLogs,
          screenOverride: screenLabel ?? screenOverride,
        ),
      );
      return true;
    } on Object {
      return false;
    }
  }

  String reportFileName([DateTime? now]) {
    final at = now ?? DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'whotook-diagnostics-${at.year}${two(at.month)}${two(at.day)}-'
        '${two(at.hour)}${two(at.minute)}.txt';
  }

  String _fitBody({
    required String intro,
    required String diagnosticsLabel,
    required String logsLabel,
    String? screenOverride,
  }) {
    var logs = recentLogs;
    var body = buildReport(
      intro: intro,
      diagnosticsLabel: diagnosticsLabel,
      logsLabel: logsLabel,
      screenOverride: screenOverride,
      logsOverride: logs,
    );
    while (buildMailto(subject: buildSubject(), body: body).toString().length >
            maxMailtoLength &&
        logs.isNotEmpty) {
      final newline = logs.indexOf('\n');
      logs = newline < 0 ? '' : logs.substring(newline + 1);
      body = buildReport(
        intro: intro,
        diagnosticsLabel: diagnosticsLabel,
        logsLabel: logsLabel,
        screenOverride: screenOverride,
        logsOverride: logs,
      );
    }
    if (buildMailto(subject: buildSubject(), body: body).toString().length <=
        maxMailtoLength) {
      return body;
    }
    // A single very long line can still be over the limit. Keep the newest
    // diagnostic header and cut the tail rather than send an invalid mailto.
    final maxBody = maxMailtoLength - 240;
    return body.length <= maxBody ? body : body.substring(0, maxBody);
  }

  String _safeTag(String tag) {
    final normalized = tag.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_/]'), '');
    return normalized.isEmpty
        ? 'APP'
        : normalized.substring(0, min(normalized.length, 24));
  }

  String _redact(String value) {
    return value
        .replaceAll(
          RegExp(
            r'(token|secret|receipt|license|purchaseRef|verificationToken|room|authorization)[=:]\s*[^\s,;]+',
            caseSensitive: false,
          ),
          r'$1=[redacted]',
        )
        .replaceAll(
          RegExp(r'(https?://[^\s/]+)/j/[^\s]+', caseSensitive: false),
          r'$1/j/[redacted]',
        )
        .replaceAll(RegExp(r'\b\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?\b'), '[ip]')
        .replaceAll(
          RegExp(
            r'(?:[A-Za-z]:)?(?:[\\/][^\s\\/]+)+\.(?:jpe?g|png|heic|heif|gif|webp)\b',
            caseSensitive: false,
          ),
          '[photo]',
        )
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _platformLabel() {
    if (kIsWeb) return 'Web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.android => 'Android',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }

  String _fallbackOsLabel() {
    if (kIsWeb) return 'Web';
    final platform = _platformLabel();
    var raw = Platform.operatingSystemVersion.trim();
    for (final prefix in <String>[
      'Version ',
      platform,
      'Android ',
      'Windows ',
      'macOS ',
    ]) {
      if (raw.toLowerCase().startsWith(prefix.toLowerCase())) {
        raw = raw.substring(prefix.length).trim();
      }
    }
    raw = raw
        .replaceFirst(RegExp(r'\s*\(Build.*$', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*\(SDK.*$', caseSensitive: false), '')
        .trim();
    if (raw.isEmpty) return platform;
    // Some Android ROMs put a long build id where the release belongs. Keep a
    // human version (14, 15, 16) and treat anything else as the SDK fallback.
    if (platform == 'Android' && !RegExp(r'^\d+(\.\d+)*$').hasMatch(raw)) {
      return 'Android';
    }
    return '$platform $raw';
  }

  String _distributionLabel() {
    if (kIsWeb) return 'Web';
    if (isFfossBuild) return 'FFOSS';
    if (isSideloadedIos || appDistribution == AppDistribution.direct) {
      return 'Sideloaded';
    }
    return 'Store';
  }

  static Future<bool> _launchExternal(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }

  static Future<void> _copyToClipboard(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  static Future<File> _writeTempReport(String name, String contents) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$name');
    // The OS cleans the temporary directory; the share target keeps its own
    // copy after the sheet closes.
    return file.writeAsString(contents, flush: true);
  }

  static Future<bool> _shareReportFile(
    File file,
    String subject,
    String text,
  ) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path, mimeType: 'text/plain')],
        subject: subject,
        title: subject,
        text: text,
      ),
    );
    return true;
  }
}

class _DiagnosticEvent {
  const _DiagnosticEvent({
    required this.at,
    required this.tag,
    required this.message,
  });

  final DateTime at;
  final String tag;
  final String message;

  String format() {
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    final s = at.second.toString().padLeft(2, '0');
    final ms = at.millisecond.toString().padLeft(3, '0');
    return '[$h:$m:$s.$ms][$tag] $message';
  }
}
