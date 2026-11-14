import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/app.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/storage/settings_repository.dart';
import 'package:whotook/state/providers.dart';

class _MemorySettings extends SettingsRepository {
  _MemorySettings(this.initial);

  final AppSettings initial;

  @override
  Future<AppSettings> load() async => initial;

  @override
  Future<void> save(AppSettings settings) async {}
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('shows onboarding on first run', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _MemorySettings(const AppSettings()),
          ),
        ],
        child: const WhoTookApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guess whose photo it is'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('host and join are the only two actions on home', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _MemorySettings(const AppSettings(onboardingCompleted: true)),
          ),
        ],
        child: const WhoTookApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Host a game'), findsOneWidget);
    expect(find.text('Join a game'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });
}
