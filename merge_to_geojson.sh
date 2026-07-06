#!/bin/bash
# 複数のGeoJSONファイルを1つのFeatureCollectionに統合します。
#
# 使い方:
#   ./merge_to_geojson.sh [YEAR] [PREF]
#     YEAR: 年度 (例: 2024, 2025, 2026)。省略時は 2025
#     PREF: 都道府県コード2桁ディレクトリ (例: 01)。省略時は 01
set -euo pipefail

YEAR="${1:-2025}"
PREF="${2:-01}"

# 対象ディレクトリと出力ファイル名（年度・都道府県を反映）
DIST_DIR="${YEAR}/${PREF}"
OUT_FILE="merged_${PREF}.geojson"

if [[ ! -d "$DIST_DIR" ]]; then
  echo "❌ ディレクトリが存在しません: $DIST_DIR"
  exit 1
fi

# GeoJSONを統合して1つのFeatureCollectionにする
jq -s '
  [ .[] | .features // [.] ] | add
  | {type: "FeatureCollection", features: .}
' "${DIST_DIR}"/*.geojson > "${DIST_DIR}/${OUT_FILE}"

echo "✅ GeoJSONに統合完了: ${DIST_DIR}/${OUT_FILE}"
