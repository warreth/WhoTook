import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/app.dart';
import 'package:whotook/core/format/date_label.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:whotook/state/providers.dart';

class _FixedSettings extends AppSettingsController {
  _FixedSettings(this.value);

  final AppSettings value;

  @override
  Future<AppSettings> build() async => value;
}

Map<String, String> _arb(String locale) {
  final raw = jsonDecode(
    File('lib/l10n/app_$locale.arb').readAsStringSync(),
  ) as Map<String, dynamic>;
  return <String, String>{
    for (final entry in raw.entries)
      if (!entry.key.startsWith('@')) entry.key: entry.value as String,
  };
}

List<String> _literalProseOffenders() {
  final allowed = <String>{'WhoTook', 'Lotte', 'Bram', 'Sam', 'Noor'};
  final callSite = RegExp(
    r'''(?:\b(?:Text|SelectableText|RichText)\(\s*(?:const\s+)?|(?:tooltip|labelText|hintText|helperText|semanticLabel|message|title|body|content|actionLabel|label|errorMessage)\s*:\s*(?:const\s+)?)(['"])''',
  );
  final files = <File>[
    ...Directory('lib/ui').listSync(recursive: true).whereType<File>(),
    File('lib/app.dart'),
    File('lib/core/links.dart'),
  ];
  final offenders = <String>[];
  for (final file in files.where((file) => file.path.endsWith('.dart'))) {
    final text = file.readAsStringSync();
    for (final match in callSite.allMatches(text)) {
      final quote = match.group(1)!;
      final start = match.end;
      var end = start;
      while (end < text.length) {
        if (text[end] == r'\') {
          end += 2;
          continue;
        }
        if (text[end] == quote) break;
        end++;
      }
      if (end >= text.length) continue;
      final value = text.substring(start, end);
      if (!value.contains(RegExp('[A-Za-z]'))) continue;
      if (value.contains(r'$')) continue;
      if (allowed.contains(value)) continue;
      final line = text.substring(0, match.start).split('\n').length;
      offenders.add('${file.path}:$line  $value');
    }
  }
  return offenders;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('nl');
  });

  test('English and Dutch ARB files keep the same keys and placeholders', () {
    final en = _arb('en');
    final nl = _arb('nl');
    expect(nl.keys.toSet(), en.keys.toSet());

    final placeholder = RegExp(r'\{([a-z][A-Za-z0-9_]*)');
    for (final key in en.keys) {
      final enNames = placeholder
          .allMatches(en[key]!)
          .map((match) => match.group(1))
          .whereType<String>()
          .toSet();
      final nlNames = placeholder
          .allMatches(nl[key]!)
          .map((match) => match.group(1))
          .whereType<String>()
          .toSet();
      expect(nlNames, enNames, reason: key);
    }
  });

  test('every translated string is used and differs unless it is a name', () {
    final en = _arb('en');
    final nl = _arb('nl');
    final used = <String>{};
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.contains('/l10n/generated/')) continue;
      used.addAll(
        RegExp(r'\b_?l10n\.([A-Za-z0-9_]+)')
            .allMatches(file.readAsStringSync())
            .map((match) => match.group(1)!),
      );
    }
    expect(en.keys.toSet().difference(used), isEmpty);

    const allowedIdentical = <String>{
      'languageEnglish',
      'languageDutch',
      'privacy',
      'secondsShort',
      'paceSemantic',
      'lobby',
      'online',
      'hostLabel',
      'captionAuthorBadge',
      'exact',
      'paparazzi',
      'awardSeconds',
      'awardStreak',
      'podium',
      'avatar',
      'onlineRelay',
      'avatarOption',
      'modeSemantic',
      'modeMakeItMeme',
      'memeTemplate',
      'memeTemplatePov',
      'memeTemplateBreaking',
      'memeTemplateLive',
      'memeTemplatePoster',
      'memeTemplateSplit',
      'memeUpvote',
      'memeMeh',
      'memeDownvote',
      'memeTopMemes',
      'memeVotesUp',
      'memeVotesMeh',
      'memeVotesDown',
      'liveBadge',
      'partyPassTitle',
      'partyPassPrivacy',
      'partyPassLobbyButton',
      'partyPassLicenseHint',
      'settingsPartyPassTitle',
      'roomThemeMidnightArcade',
      'roomThemeCyberNeon',
      'roomThemeRetroPolaroid',
      'roomThemePremium',
      'lobbySoundboardLabel',
      'lobbyRelayLabel',
      'relayStatusDirect',
      'relayStatusRelay',
      'soundboardTitle',
      'soundVineBoom',
    };
    final untranslated = <String>[];
    for (final key in en.keys) {
      if (en[key] == nl[key] && !allowedIdentical.contains(key)) {
        untranslated.add(key);
      }
    }
    expect(untranslated, isEmpty, reason: untranslated.join(', '));
  });

  test('UI call sites do not pass literal prose', () {
    final offenders = _literalProseOffenders();
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('iOS permission copy exists in English and Dutch', () {
    final keys = <String>[
      'NSCameraUsageDescription',
      'NSPhotoLibraryUsageDescription',
      'NSLocalNetworkUsageDescription',
    ];
    final en = File('ios/Runner/en.lproj/InfoPlist.strings').readAsStringSync();
    final nl = File('ios/Runner/nl.lproj/InfoPlist.strings').readAsStringSync();
    for (final key in keys) {
      expect(en, contains('"$key"'));
      expect(nl, contains('"$key"'));
    }
    expect(nl, contains('camera'));
    expect(nl, contains('wifi'));
  });

  test('Dutch dates and distances are localized', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final nl = lookupAppLocalizations(const Locale('nl'));
    expect(monthName(en, 8), 'August');
    expect(monthName(nl, 8), 'augustus');
    expect(monthDistance(en, 14), '1 year 2 months');
    expect(monthDistance(nl, 14), '1 jaar 2 maanden');
  });

  testWidgets('the language setting switches the interface', (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith(
            () => _FixedSettings(
              const AppSettings(
                nickname: 'Bram',
                language: AppLanguage.dutch,
                onboardingCompleted: true,
              ),
            ),
          ),
        ],
        child: const WhoTookApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Start een spel'), findsOneWidget);
    expect(find.text('Host a game'), findsNothing);
  });

  testWidgets('the system locale picks Dutch Belgian on first launch', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final dispatcher = tester.binding.platformDispatcher;
    dispatcher.localesTestValue = <Locale>[const Locale('nl', 'BE')];
    addTearDown(dispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith(
            () => _FixedSettings(
              const AppSettings(nickname: 'Bram', onboardingCompleted: true),
            ),
          ),
        ],
        child: const WhoTookApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Start een spel'), findsOneWidget);
  });
}
