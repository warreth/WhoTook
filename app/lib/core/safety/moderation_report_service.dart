import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';
import '../storage/settings_repository.dart';

enum ModerationReportReason {
  inappropriate('inappropriate'),
  harassment('harassment'),
  hateSpeech('hate_speech'),
  nonConsensual('non_consensual'),
  other('other');

  const ModerationReportReason(this.wire);

  final String wire;
}

enum ModerationTargetType {
  photo('photo'),
  meme('meme'),
  sabotage('sabotage'),
  player('player'),
  general('general');

  const ModerationTargetType(this.wire);

  final String wire;
}

class ModerationReportResult {
  const ModerationReportResult({
    required this.submittedOnline,
    this.reportId,
  });

  final bool submittedOnline;
  final String? reportId;
}

/// Sends voluntary user-safety reports to the signaling server without
/// uploading photos, player accounts, or local room secrets.
class ModerationReportService {
  ModerationReportService({
    this.baseUrl = kDefaultSignalingUrl,
    http.Client? client,
  }) : _client = client;

  final String baseUrl;
  final http.Client? _client;

  Future<ModerationReportResult> submitReport({
    required ModerationReportReason reason,
    required ModerationTargetType targetType,
    String? roomId,
    String? details,
    bool isDemo = false,
    String? signalingOverrideUrl,
  }) async {
    if (isDemo) {
      return const ModerationReportResult(submittedOnline: false);
    }
    final override = signalingOverrideUrl?.trim() ?? '';
    final root = (override.isNotEmpty ? override : baseUrl).replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final uri = Uri.tryParse('$root/api/v1/reports');
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return const ModerationReportResult(submittedOnline: false);
    }

    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    try {
      final trimmed = details?.trim() ?? '';
      final capped = trimmed.length > 500 ? trimmed.substring(0, 500) : trimmed;
      final response = await client
          .post(
            uri,
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'reason': reason.wire,
              'targetType': targetType.wire,
              if (roomId != null && roomId.isNotEmpty) 'roomId': roomId,
              if (capped.isNotEmpty) 'details': capped,
              'appVersion': kAppVersion,
              'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final reportId = decoded is Map<String, dynamic>
            ? decoded['reportId'] as String?
            : null;
        return ModerationReportResult(
          submittedOnline: true,
          reportId: reportId,
        );
      }
    } on Object {
      // Local LAN or offline play still confirms the immediate on-device block.
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
    return const ModerationReportResult(submittedOnline: false);
  }
}
