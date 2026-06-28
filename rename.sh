#!/bin/bash
# ダウンロード直後の .json ファイルを .geojson にリネームします。
#
# 使い方:
#   ./rename.sh [YEAR] [PREF]
#     YEAR: 年度 (例: 2024, 2025, 2026)。省略時は 2025
#     PREF: 都道府県コード2桁ディレクトリ (例: 01)。省略時は 01

YEAR="${1:-2025}"
PREF="${2:-01}"

TARGET_DIR="${YEAR}/${PREF}"

find "${TARGET_DIR}" -type f -name '*.json' -print0 \
  | while IFS= read -r -d '' f; do
      git mv "$f" "${f%.json}.geojson"
    done

exit 0;
