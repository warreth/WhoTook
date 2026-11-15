import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/media/photo_service.dart';
import '../core/models/models.dart';
import '../core/storage/last_room_repository.dart';
import '../core/storage/settings_repository.dart';
import '../core/app_info.dart';
import '../state/match_coordinator.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(),
);

final photoLibraryProvider = Provider<PhotoLibraryService>(
  (ref) => DevicePhotoLibraryService(),
);

final lastRoomRepositoryProvider = Provider<LastRoomRepository>(
  (ref) => LastRoomRepository(),
);

/// Persisted preferences, loaded once at startup.
final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

class AppSettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    return ref.watch(settingsRepositoryProvider).load();
  }

  Future<void> apply(AppSettings Function(AppSettings current) change) async {
    final current = state.value ?? const AppSettings();
    final next = change(current);
    await ref.read(settingsRepositoryProvider).save(next);
    state = AsyncData(next);
  }
}

/// One coordinator per app session; it owns sockets, timers and photo memory.
final matchCoordinatorProvider = Provider<MatchCoordinator>((ref) {
  final info = ref.watch(appInfoProvider);
  final coordinator = MatchCoordinator(
    photos: ref.watch(photoLibraryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    appVersion: info.version,
    appBuild: info.build,
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

final matchStateProvider = StreamProvider<MatchUiState>((ref) {
  final coordinator = ref.watch(matchCoordinatorProvider);
  return coordinator.states;
});
