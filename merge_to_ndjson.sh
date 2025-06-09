#!/bin/bash

# 出力ファイル名
OUT_FILE="merged_01.ndjson"
DIST_DIR="01"

# JSON構文チェック
find "${DIST_DIR}" -name '*.geojson' | while read -r f; do
  if ! jq empty "$f" 2>/dev/null; then
    echo "❌ JSON parse error: $f"
  fi
done

echo ""
echo "📊 各GeoJSONファイルのFeature数:"
total=0

# Feature数を表示しながら合計を集計（サブシェルを回避）
while read -r f; do
  count=$(jq '.features | length' "$f" 2>/dev/null)
  if [[ "$count" =~ ^[0-9]+$ ]]; then
    fname=$(basename "$f")
    echo "  $fname: $count features"
    total=$((total + count))
  fi
done < <(find "${DIST_DIR}" -type f -name '*.geojson')

echo "🔢 GeoJSON全体のFeature合計数: $total"

# GeoJSONをNDJSONに変換して出力
find "${DIST_DIR}" -type f -name '*.geojson' \
  | xargs ndjson-cat \
  | ndjson-split 'd.features' \
  > "${DIST_DIR}/${OUT_FILE}"

# NDJSONのFeature数を確認
ndjson_count=$(wc -l < "${DIST_DIR}/${OUT_FILE}")
echo "📦 NDJSONに変換完了: ${DIST_DIR}/${OUT_FILE}"
echo "📈 NDJSONのFeature数: $ndjson_count"
