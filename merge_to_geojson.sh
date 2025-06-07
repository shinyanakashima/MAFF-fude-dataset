#!/bin/bash

# 出力ファイル名と対象ディレクトリ
OUT_FILE="merged_01.geojson"
DIST_DIR="01"

# GeoJSONを統合して1つのFeatureCollectionにする
jq -s '
  [ .[] | .features // [.] ] | add
  | {type: "FeatureCollection", features: .}
' "${DIST_DIR}"/*.geojson > "${DIST_DIR}/${OUT_FILE}"

echo "✅ GeoJSONに統合完了: ${DIST_DIR}/${OUT_FILE}"

