#!/bin/bash
# 個別GeoJSONファイルをそれぞれTopoJSONに変換します。
#
# 使い方:
#   ./geojson_to_topojson.sh [YEAR] [PREF]
#     YEAR: 年度 (例: 2024, 2025, 2026)。省略時は 2025
#     PREF: 都道府県コード2桁ディレクトリ (例: 01)。省略時は 01
set -euo pipefail

YEAR="${1:-2025}"
PREF="${2:-01}"

# 対象ディレクトリ（年度・都道府県を反映）
DIST_DIR="${YEAR}/${PREF}"

if [[ ! -d "$DIST_DIR" ]]; then
  echo "❌ ディレクトリが存在しません: $DIST_DIR"
  exit 1
fi

for f in "${DIST_DIR}"/*.geojson; do
  # 統合ファイルは個別変換の対象外
  case "$(basename "$f")" in
    merged_*.geojson) continue ;;
  esac
  name=$(basename "$f" .geojson)
  mapshaper -i "$f" -o format=topojson "${DIST_DIR}/${name}.topojson"
done

echo "✅ TopoJSON 生成完了: ${DIST_DIR}"
