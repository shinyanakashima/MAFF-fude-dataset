#!/usr/bin/env bash
set -euo pipefail

YEAR="${YEAR:-2026}"
TAG_NAME="${TAG_NAME:-v${YEAR}-merged}"
RELEASE_TITLE="${RELEASE_TITLE:-${YEAR}年度 筆ポリゴン配布データ}"
RELEASE_NOTES="${RELEASE_NOTES:-サイズが大きいため、GitHub Releaseで配布しています。}"
FILE_TO_UPLOAD="${FILE_TO_UPLOAD:-}"
GH_BIN="${GH_BIN:-gh}"

if ! command -v "$GH_BIN" >/dev/null 2>&1; then
  echo "gh command not found: $GH_BIN" >&2
  exit 1
fi

if [ -z "$FILE_TO_UPLOAD" ]; then
  echo "FILE_TO_UPLOAD is required." >&2
  echo "Example:" >&2
  echo "  YEAR=2026 TAG_NAME=v2026-merged-geojson FILE_TO_UPLOAD=2026/merged/merged_2026.geojson ./scripts/release_asset.sh" >&2
  exit 1
fi

if [ ! -f "$FILE_TO_UPLOAD" ]; then
  echo "Upload target does not exist: $FILE_TO_UPLOAD" >&2
  exit 1
fi

if "$GH_BIN" release view "$TAG_NAME" >/dev/null 2>&1; then
  echo "Release already exists: $TAG_NAME"
  echo "Uploading asset with --clobber: $FILE_TO_UPLOAD"
  "$GH_BIN" release upload "$TAG_NAME" "$FILE_TO_UPLOAD" --clobber
else
  echo "Creating release: $TAG_NAME"
  "$GH_BIN" release create "$TAG_NAME" "$FILE_TO_UPLOAD" \
    --title "$RELEASE_TITLE" \
    --notes "$RELEASE_NOTES"
fi

echo "Uploaded: $FILE_TO_UPLOAD -> $TAG_NAME"
