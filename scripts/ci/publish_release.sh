#!/usr/bin/env bash
# Attach build artifacts to the GitHub Release for the tag being built.
#
# This is called by codemagic.yaml after the build. It is deliberately quiet
# when publishing is not configured: a branch build and a tag build should not
# differ in whether the build itself succeeds. Tokens and response bodies are
# never printed.
set -euo pipefail
set +x
umask 077

platform="${1:-}"
case "$platform" in
  ios|macos) ;;
  *) echo "usage: $0 ios|macos" >&2; exit 64 ;;
esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
artifact_dir="${ARTIFACT_ROOT:-$root/artifacts}/$platform"
token="${GH_RELEASE_TOKEN:-}"
ref="${SOURCE_REF:-}"
ref_type="${SOURCE_REF_TYPE:-}"
repository="${SOURCE_REPO:-}"

skip() {
  echo "Release upload skipped: $1"
  exit 0
}

[ -n "$token" ] || skip "GH_RELEASE_TOKEN is not set."
[ "$ref_type" = "tag" ] || skip "this is a $ref_type build, not a tag."
[ -n "$ref" ] || skip "SOURCE_REF is not set."
[ -n "$repository" ] || skip "SOURCE_REPO is not set."
[ -d "$artifact_dir" ] || skip "$artifact_dir does not exist."
command -v jq >/dev/null 2>&1 || skip "jq is not installed."
command -v curl >/dev/null 2>&1 || skip "curl is not installed."

api="${GITHUB_API_URL:-https://api.github.com}"
api="${api%/}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
header_file="$tmpdir/auth.header"
printf 'Authorization: Bearer %s\n' "$token" > "$header_file"

encoded_tag="$(jq -rn --arg value "$ref" '$value | @uri')"
release_file="$tmpdir/release.json"
http_code="000"
if ! http_code="$(
  curl --silent --show-error --max-time 30 \
    --header "@$header_file" \
    --header 'Accept: application/vnd.github+json' \
    --output "$release_file" \
    --write-out '%{http_code}' \
    "$api/repos/$repository/releases/tags/$encoded_tag"
)"; then
  http_code="000"
fi
if [ "$http_code" != "200" ]; then
  skip "no release for tag $ref in $repository (HTTP $http_code)."
fi

upload_url="$(jq -r '.upload_url // empty' "$release_file" 2>/dev/null || true)"
upload_url="${upload_url%%\{*}"
[ -n "$upload_url" ] || skip "the release response had no upload_url."

uploaded=0
for file in "$artifact_dir"/*; do
  [ -f "$file" ] || continue
  name="$(basename "$file")"
  encoded_name="$(jq -rn --arg value "$name" '$value | @uri')"

  # A rerun for the same tag produces the same asset names. Replace the old
  # asset first; GitHub rejects a second upload with the same name.
  existing_id="$(
    jq -r --arg name "$name" '.assets[]? | select(.name == $name) | .id' \
      "$release_file" 2>/dev/null | head -1 || true
  )"
  if [ -n "$existing_id" ]; then
    delete_code="000"
    if ! delete_code="$(
      curl --silent --show-error --max-time 30 \
        --request DELETE \
        --header "@$header_file" \
        --output /dev/null \
        --write-out '%{http_code}' \
        "$api/repos/$repository/releases/assets/$existing_id"
    )"; then
      delete_code="000"
    fi
    case "$delete_code" in
      200|204) ;;
      *)
        echo "::warning::Could not replace existing asset $name (HTTP $delete_code); leaving it in place."
        continue
        ;;
    esac
  fi

  code="000"
  if ! code="$(
    curl --silent --show-error --max-time 300 --retry 2 \
      --request POST \
      --header "@$header_file" \
      --header 'Content-Type: application/octet-stream' \
      --output /dev/null \
      --write-out '%{http_code}' \
      --data-binary "@$file" \
      "$upload_url?name=$encoded_name"
  )"; then
    code="000"
  fi
  case "$code" in
    200|201) echo "Uploaded $name"; uploaded=$((uploaded + 1)) ;;
    *) echo "::warning::GitHub rejected $name (HTTP $code); the Codemagic artifact still holds it." ;;
  esac
done

[ "$uploaded" -gt 0 ] || echo "No artifact was uploaded for $platform."
