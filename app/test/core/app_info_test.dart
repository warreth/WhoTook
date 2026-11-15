import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/app_info.dart';
import 'package:whotook/state/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('the coordinator reads the runtime build info', () {
    final container = ProviderContainer(
      overrides: [
        appInfoProvider.overrideWithValue(
          const AppInfo(version: '9.9.9', build: 99),
        ),
      ],
    );
    addTearDown(container.dispose);
    final coordinator = container.read(matchCoordinatorProvider);
    expect(coordinator.appVersion, '9.9.9');
    expect(coordinator.appBuild, 99);
  });
}
