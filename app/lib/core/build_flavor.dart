/// Compile-time product flavor.
///
/// `--dart-define=FOSS_BUILD=true` produces the tracker-free build for GitHub
/// and F-Droid: no store billing, no official relay client, and every party
/// feature included for free. Store builds leave the flag at its default.
abstract final class BuildFlavor {
  static const bool foss = bool.fromEnvironment(
    'FOSS_BUILD',
    defaultValue: false,
  );

  static const bool official = !foss;
}
