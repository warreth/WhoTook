/// Compile-time QA switches. A normal release build leaves these false, so the
/// web playtest harness can never leak into the shipped app.
abstract final class PlaytestConfig {
  static const bool enabled = bool.fromEnvironment(
    'PLAYTEST_MODE',
    defaultValue: false,
  );
}
