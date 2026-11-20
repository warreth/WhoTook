import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/diagnostics/bug_report_service.dart';

void main() {
  test('keeps the newest 50 redacted diagnostic events', () {
    final service = BugReportService(
      launch: (_) async => true,
      copy: (_) async {},
    );
    for (var i = 0; i < 60; i++) {
      service.record('DEMO', 'event $i');
    }
    service.record('IAP', 'verificationToken=secret-value');

    final logs = service.recentLogs;
    expect(logs.split('\n'), hasLength(50));
    expect(logs, contains('event 59'));
    expect(logs, isNot(contains('event 9]')));
    expect(logs, contains('[redacted]'));
    expect(logs, isNot(contains('secret-value')));
  });

  test('never keeps photo paths, invite links or IP addresses', () {
    final service = BugReportService(
      launch: (_) async => true,
      copy: (_) async {},
    );
    service.record(
      'VAULT',
      'failed /var/mobile/Media/DCIM/IMG_2042.HEIC via '
          'https://whotook.party/j/abc123 and 192.168.1.24:8080',
    );

    final logs = service.recentLogs;
    expect(logs, isNot(contains('IMG_2042')));
    expect(logs, isNot(contains('abc123')));
    expect(logs, isNot(contains('192.168.1.24')));
    expect(logs, contains('[photo]'));
    expect(logs, contains('/j/[redacted]'));
    expect(logs, contains('[ip]'));
  });

  test('formats compact app, match and screen diagnostics', () {
    final service =
        BugReportService(launch: (_) async => true, copy: (_) async {})
          ..configure(
            version: '1.9.3',
            build: 16,
            osLabel: 'Android 15',
            deviceLabel: 'Google Pixel 8 (SDK 35)',
          )
          ..updateGame(
            mode: 'Mixed Party',
            role: 'Host',
            phase: 'Vault',
            connection: 'Demo',
            demo: true,
          )
          ..updateScreen(const Size(393, 852))
          ..record('DEMO', 'Starting demo setup');

    final report = service.buildReport(
      intro: 'Wat ging er mis? (Typ hierboven je uitleg)',
      diagnosticsLabel: 'Diagnostics (Niet verwijderen)',
      logsLabel: 'Recente logs',
    );
    expect(report, contains('App: v1.9.3+16 (Android 15 - '));
    expect(report, contains('Device: Google Pixel 8 (SDK 35)'));
    expect(
      report,
      contains('Mode: Mixed Party | Role: Host (demo) | Phase: Vault'),
    );
    expect(report, contains('Connection: Demo'));
    expect(report, contains('Screen: 393x852'));
    expect(report, contains('[DEMO] Starting demo setup'));
    expect(service.buildSubject(), startsWith('WhoTook Bug Report - v1.9.3 ('));
  });

  test('shares the full report as a dated text file', () async {
    String? writtenName;
    String? writtenContents;
    String? sharedSubject;
    String? sharedText;
    final service =
        BugReportService(
            writeFile: (name, contents) async {
              writtenName = name;
              writtenContents = contents;
              return File('/tmp/$name');
            },
            shareFile: (file, subject, text) async {
              sharedSubject = subject;
              sharedText = text;
              expect(file.path, '/tmp/$writtenName');
              return true;
            },
          )
          ..configure(
            version: '1.10.0',
            build: 2017,
            osLabel: 'Android 15',
            deviceLabel: 'Google Pixel 8 (SDK 35)',
          )
          ..record('DEMO', 'Demo setup ready');

    final report = service.buildReport(
      intro: 'What went wrong?',
      diagnosticsLabel: 'Diagnostics',
      logsLabel: 'Recent logs',
    );
    expect(
      await service.deliverFile(report: report, text: 'Full report attached.'),
      isTrue,
    );

    expect(
      writtenName,
      matches(RegExp(r'^whotook-diagnostics-\d{8}-\d{4}\.txt$')),
    );
    expect(writtenContents, report);
    expect(writtenContents, contains('Device: Google Pixel 8 (SDK 35)'));
    expect(writtenContents, contains('[DEMO] Demo setup ready'));
    expect(sharedSubject, contains('WhoTook Bug Report - v1.10.0'));
    expect(sharedText, 'Full report attached.');
  });

  test('names the report file with a stable timestamp', () {
    final service = BugReportService(
      launch: (_) async => true,
      copy: (_) async {},
    );
    expect(
      service.reportFileName(DateTime(2026, 11, 20, 14, 5)),
      'whotook-diagnostics-20261120-1405.txt',
    );
  });

  test(
    'caps the mailto body below 1800 characters and keeps the newest log',
    () async {
      Uri? launched;
      String? copied;
      final service =
          BugReportService(
              launch: (uri) async {
                launched = uri;
                return false;
              },
              copy: (text) async => copied = text,
            )
            ..configure(version: '1.9.3', build: 16)
            ..updateGame(
              mode: 'Mixed Party',
              role: 'Host',
              phase: 'Vault',
              connection: 'TURN',
            )
            ..updateScreen(const Size(393, 852));
      for (var i = 0; i < 50; i++) {
        service.record('P2P', 'long diagnostic line $i ${'x' * 120}');
      }

      final result = await service.deliver(
        intro: 'Wat ging er mis?',
        diagnosticsLabel: 'Diagnostics (Niet verwijderen)',
        logsLabel: 'Recente logs',
      );

      expect(result, BugReportDelivery.copied);
      expect(launched, isNotNull);
      expect(launched.toString().length, lessThanOrEqualTo(1800));
      expect(launched.toString(), contains('mailto:hello@whotook.party'));
      expect(launched.toString(), contains('WhoTook%20Bug%20Report'));
      expect(copied, isNotNull);
      expect(copied, contains('long diagnostic line 49'));
    },
  );

  test('iOS can query the mailto scheme', () {
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    expect(info, contains('<key>LSApplicationQueriesSchemes</key>'));
    expect(info, contains('<string>mailto</string>'));
  });

  test('reports launched when a mail app accepts the link', () async {
    final service = BugReportService(
      launch: (_) async => true,
      copy: (_) async => fail('clipboard must not be used'),
    );
    final result = await service.deliver(
      intro: 'What went wrong?',
      diagnosticsLabel: 'Diagnostics',
      logsLabel: 'Recent logs',
    );
    expect(result, BugReportDelivery.launched);
  });
}
