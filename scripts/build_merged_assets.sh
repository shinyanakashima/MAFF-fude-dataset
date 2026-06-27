#!/usr/bin/env bash
set -euo pipefail

YEAR="${YEAR:-2026}"
SRC_DIR="${SRC_DIR:-${YEAR}/geojson}"
OUT_DIR="${OUT_DIR:-${YEAR}/merged}"
NDJSON_DIR="${NDJSON_DIR:-${YEAR}/ndjson}"
TOPOJSON_DIR="${TOPOJSON_DIR:-${YEAR}/topojson}"
FIELDS="${FIELDS:-polygon_uuid,land_type,local_government_cd}"
SIMPLIFY="${SIMPLIFY:-10%}"
NODE_MAX_OLD_SPACE_SIZE="${NODE_MAX_OLD_SPACE_SIZE:-16384}"

MERGED_GEOJSON="${OUT_DIR}/merged_${YEAR}.geojson"
MERGED_NDJSON="${NDJSON_DIR}/merged_${YEAR}.ndjson"
MERGED_TOPOJSON="${TOPOJSON_DIR}/merged_${YEAR}.topojson"
MERGED_FGB="${OUT_DIR}/merged_${YEAR}.fgb"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required." >&2
    exit 1
  fi
}

require_cmd mapshaper
require_cmd ogr2ogr
require_cmd node

mkdir -p "$OUT_DIR" "$NDJSON_DIR" "$TOPOJSON_DIR"

shopt -s nullglob
files=("$SRC_DIR"/*.geojson "$SRC_DIR"/*.json)
if [ "${#files[@]}" -eq 0 ]; then
  echo "No GeoJSON files found in $SRC_DIR" >&2
  exit 1
fi

printf "Building merged GeoJSON from %s files...\n" "${#files[@]}"
mapshaper "${files[@]}" combine-files -merge-layers -o format=geojson "$MERGED_GEOJSON"

printf "Building NDJSON...\n"
node - "$MERGED_GEOJSON" "$MERGED_NDJSON" <<'NODE'
const fs = require('fs');
const inputPath = process.argv[2];
const outputPath = process.argv[3];
const data = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
const features = data.type === 'FeatureCollection' ? data.features : [];
const out = fs.createWriteStream(outputPath);
for (const feature of features) {
  out.write(JSON.stringify(feature) + '\n');
}
out.end();
NODE

printf "Building TopoJSON with simplify=%s and fields=%s...\n" "$SIMPLIFY" "$FIELDS"
export NODE_OPTIONS="--max-old-space-size=${NODE_MAX_OLD_SPACE_SIZE}"
mapshaper "${files[@]}" \
  combine-files \
  -merge-layers \
  -filter-fields "$FIELDS" \
  -simplify "$SIMPLIFY" \
  -o format=topojson "$MERGED_TOPOJSON"

printf "Building FlatGeobuf...\n"
ogr2ogr -f FlatGeobuf "$MERGED_FGB" "$MERGED_GEOJSON"

printf "Build complete.\n"
printf "- %s\n" "$MERGED_GEOJSON" "$MERGED_NDJSON" "$MERGED_TOPOJSON" "$MERGED_FGB"
