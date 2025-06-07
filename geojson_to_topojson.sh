#!/bin/bash

# ファイル定義
DIST_DIR="01"

for f in ${DIST_DIR}/*.geojson; do
  name=$(basename "$f" .geojson)
  mapshaper -i "$f" -o format=topojson "${DIST_DIR}/${name}.topojson"
done


echo "✅ TopoJSON 生成完了: $TOPOJSON（レイヤー: $LAYER_NAME）"


