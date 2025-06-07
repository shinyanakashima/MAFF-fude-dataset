#!/bin/bash

# 出力ファイル名
OUT_FILE="merged_01.ndjson"
DIST_DIR="01"

# GeoJSONをNDJSONに変換して出力
find "${DIST_DIR}" -type f -name '*.geojson' \
  | xargs ndjson-cat \
  | ndjson-map 'd.features || [d]' \
  | ndjson-map 'd' \
  > "${DIST_DIR}/${OUT_FILE}"

echo "✅ NDJSONに変換完了: $${DIST_DIR}/${OUT_FILE}"

