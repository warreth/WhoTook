#!/usr/bin/env bash
# Build WhoTook's iOS IPA. Codemagic and the GitHub macOS fallback both run
# this file, so the Flutter version, dart-defines and packaging exist once.
#
# The app lives in app/ (pubspec, ios/, pods). The FFOSS defines match the
# project's release workflow. The result is an unsigned IPA; App Store signing
# stays in the release workflow, where the same archive is exported with a
# certificate and profile.
set -euo pipefail
set +x

platform="${1:-}"
[ "$platform" = "ios" ] || {
  echo "usage: $0 ios" >&2
  exit 64
}

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
app_dir="$root/app"
[ -f "$app_dir/pubspec.yaml" ] || {
  echo "error: $app_dir/pubspec.yaml is missing" >&2
  exit 1
}
command -v flutter >/dev/null 2>&1 || {
  echo "error: flutter is not on PATH" >&2
  exit 1
}
command -v zip >/dev/null 2>&1 || {
  echo "error: zip is not installed" >&2
  exit 1
}

version="$(awk '/^version:/ {print $2; exit}' "$app_dir/pubspec.yaml")"
build_name="${version%%+*}"
build_number="${version#*+}"
[ "$build_number" != "$version" ] || build_number="1"
[ -n "$build_name" ] || {
  echo "error: cannot read the version from app/pubspec.yaml" >&2
  exit 1
}

ref="${SOURCE_REF:-local}"
ref_slug="$(printf '%s' "$ref" | tr -c 'A-Za-z0-9._-' '-')"
ref_slug="$(printf '%s' "$ref_slug" | sed -E 's/^-+//; s/-+$//' | cut -c1-80)"
[ -n "$ref_slug" ] || ref_slug="local"

artifact_root="${ARTIFACT_ROOT:-$root/artifacts}"
out="$artifact_root/ios"
rm -rf "$out"
mkdir -p "$out"

echo "Building WhoTook $build_name ($build_number) from $ref"
flutter --version
cd "$app_dir"
flutter pub get

# A stale archive must never be packaged if this build fails before producing a
# new one.
rm -rf build/ios/archive build/ios/iphoneos

flutter build ipa --release --no-codesign \
  --build-name "$build_name" \
  --build-number "$build_number" \
  --dart-define=FFOSS_BUILD=true \
  --dart-define=WHOTOOK_DISTRIBUTION=direct

archive="$(find build/ios/archive -name '*.xcarchive' -type d -print -quit)"
[ -n "$archive" ] || {
  echo "error: flutter did not produce an .xcarchive" >&2
  exit 1
}
app_bundle="$archive/Products/Applications/Runner.app"
[ -d "$app_bundle" ] || {
  echo "error: $archive does not contain Runner.app" >&2
  exit 1
}

mkdir -p "$out/Payload"
cp -R "$app_bundle" "$out/Payload/Runner.app"

# Sideloading tools re-sign the bundle themselves. Keep any signature or
# profile that might have travelled along out of the FFOSS IPA.
find "$out/Payload/Runner.app" -name _CodeSignature -type d -prune -exec rm -rf {} +
find "$out/Payload/Runner.app" -name SC_Info -type d -prune -exec rm -rf {} +
rm -f "$out/Payload/Runner.app/embedded.mobileprovision"
if command -v codesign >/dev/null 2>&1; then
  find "$out/Payload/Runner.app" -type f -perm -111 -print0 |
    xargs -0 -I{} codesign --remove-signature {} >/dev/null 2>&1 || true
fi

ipa="$out/WhoTook-iOS-FFOSS.ipa"
(
  cd "$out"
  zip -qry "$ipa" Payload
)
rm -rf "$out/Payload"
cp "$ipa" "$out/WhoTook-unsigned.ipa"
cp "$ipa" "$out/WhoTook-${build_name}-ios-${ref_slug}-unsigned.ipa"

if command -v sha256sum >/dev/null 2>&1; then
  (cd "$out" && sha256sum ./*.ipa > SHA256SUMS-ios.txt)
else
  (cd "$out" && shasum -a 256 ./*.ipa > SHA256SUMS-ios.txt)
fi

ls -lh "$out"
