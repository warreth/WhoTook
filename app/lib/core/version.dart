/// Version compatibility is semantic, never build-number based. TestFlight
/// and Android increments the `+N` build independently, so two phones running
/// the same 1.9.2 must be allowed in the same room even when their builds
/// differ.
String normalizeAppVersion(String version) => version.split('+').first.trim();

List<int> _parts(String version) {
  final normalized = normalizeAppVersion(version);
  final pieces = normalized.split('.');
  return <int>[
    for (var i = 0; i < 3; i++)
      i < pieces.length ? (int.tryParse(pieces[i]) ?? 0) : 0,
  ];
}

/// Returns a negative number when [a] is older, zero when the major, minor and
/// patch numbers match, and a positive number when [a] is newer.
int compareAppVersions(String a, String b) {
  final left = _parts(a);
  final right = _parts(b);
  for (var i = 0; i < 3; i++) {
    final difference = left[i].compareTo(right[i]);
    if (difference != 0) return difference;
  }
  return 0;
}

bool isNewerAppVersion(String candidate, String current) =>
    compareAppVersions(candidate, current) > 0;
