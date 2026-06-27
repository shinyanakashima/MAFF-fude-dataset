#!/usr/bin/env bash
set -euo pipefail

YEAR="${YEAR:-2026}"
URL_LIST="${URL_LIST:-docs/download-urls-${YEAR}.txt}"
OUT_DIR="${OUT_DIR:-${YEAR}/raw}"
MANIFEST="${MANIFEST:-${OUT_DIR}/manifest.tsv}"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required." >&2
  exit 1
fi

if ! command -v sha256sum >/dev/null 2>&1; then
  echo "sha256sum is required." >&2
  exit 1
fi

if [ ! -f "$URL_LIST" ]; then
  echo "URL list not found: $URL_LIST" >&2
  echo "Create it from docs/download-urls-${YEAR}.example.txt" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
printf "year\turl\tfile\tbytes\tsha256\n" > "$MANIFEST"

while IFS= read -r line || [ -n "$line" ]; do
  # Skip empty lines and comments.
  case "$line" in
    ""|\#*) continue ;;
  esac

  url="${line%%[[:space:]]*}"
  rest="${line#${url}}"
  filename="$(echo "$rest" | sed 's/^[[:space:]]*//')"

  if [ -z "$filename" ]; then
    filename="$(basename "${url%%\?*}")"
  fi

  if [ -z "$filename" ] || [ "$filename" = "/" ] || [ "$filename" = "." ]; then
    echo "Could not infer filename from URL. Add filename after URL: $url" >&2
    exit 1
  fi

  target="${OUT_DIR}/${filename}"
  echo "Downloading: $url -> $target"
  curl -L --fail --retry 3 --retry-delay 5 --continue-at - --output "$target" "$url"

  bytes="$(wc -c < "$target" | tr -d ' ')"
  digest="$(sha256sum "$target" | awk '{print $1}')"
  printf "%s\t%s\t%s\t%s\t%s\n" "$YEAR" "$url" "$target" "$bytes" "$digest" >> "$MANIFEST"
done < "$URL_LIST"

echo "Manifest written: $MANIFEST"
