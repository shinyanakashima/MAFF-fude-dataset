#!/bin/bash
# 指定年度・都道府県の統合ファイル(GeoJSON / NDJSON / TopoJSON)を生成し、
# GitHub Release として一括アップロードします（2024年度と同じ配布フロー）。
#
# 使い方:
#   ./build_release.sh [YEAR] [PREF] [options]
#     YEAR : 年度 (例: 2024, 2025, 2026)。省略時は 2025
#     PREF : 都道府県コード2桁 (例: 01)。省略時は 01
#
#   options:
#     --no-release   生成のみ行い、GitHub Release へのアップロードはしない
#     --no-topojson  TopoJSON(統合)の生成をスキップ（mapshaperが無い環境向け）
#
# 前提ツール:
#   jq        … 必須（GeoJSON/NDJSON生成）
#   mapshaper … TopoJSON統合に必要（`npm install -g mapshaper`）
#   gh        … Release作成に必要（--no-release 指定時は不要）
#
# 生成物 / Release タグ（<YEAR>/<PREF>/ 配下）:
#   merged_<PREF>.geojson   → v<YEAR>-merged<PREF>-geojson
#   merged_<PREF>.ndjson    → v<YEAR>-merged<PREF>-ndjson
#   merged_<PREF>.topojson  → v<YEAR>-merged<PREF>-topojson
set -euo pipefail

YEAR="2025"
PREF="01"
DO_RELEASE=1
DO_TOPOJSON=1

# 位置引数(YEAR PREF)とオプションを解釈
positional=()
for arg in "$@"; do
  case "$arg" in
    --no-release)  DO_RELEASE=0 ;;
    --no-topojson) DO_TOPOJSON=0 ;;
    --*) echo "❌ 不明なオプション: $arg"; exit 1 ;;
    *) positional+=("$arg") ;;
  esac
done
[[ ${#positional[@]} -ge 1 ]] && YEAR="${positional[0]}"
[[ ${#positional[@]} -ge 2 ]] && PREF="${positional[1]}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${YEAR}/${PREF}"
GEOJSON="${DIST_DIR}/merged_${PREF}.geojson"
NDJSON="${DIST_DIR}/merged_${PREF}.ndjson"
TOPOJSON="${DIST_DIR}/merged_${PREF}.topojson"

command -v jq >/dev/null 2>&1 || { echo "❌ jq が見つかりません"; exit 1; }
[[ -d "$DIST_DIR" ]] || { echo "❌ ディレクトリが存在しません: $DIST_DIR"; exit 1; }

echo "▶ 対象: ${YEAR}年度 / 都道府県${PREF}  (${DIST_DIR})"

# 1) NDJSON を生成（1ファイルずつのストリーム処理＝省メモリ）
echo "▶ [1/3] NDJSON を生成..."
bash "${SCRIPT_DIR}/merge_to_ndjson.sh" "$YEAR" "$PREF"

# 2) NDJSON から統合 GeoJSON を派生（jq -s のスラープを避け、ストリームで包む＝省メモリ）
echo "▶ [2/3] 統合 GeoJSON を生成..."
{
  printf '{"type":"FeatureCollection","features":['
  awk 'NR>1{printf ","} {printf "%s", $0}' "$NDJSON"
  printf ']}'
} > "$GEOJSON"
# 妥当性確認
jq empty "$GEOJSON"
feat=$(jq '.features | length' "$GEOJSON")
echo "  ✅ ${GEOJSON} (features: ${feat})"

# 3) 統合 TopoJSON を生成（mapshaperが必要。メモリ不足時は NODE_OPTIONS で拡張）
if [[ "$DO_TOPOJSON" -eq 1 ]]; then
  if command -v mapshaper >/dev/null 2>&1; then
    echo "▶ [3/3] 統合 TopoJSON を生成..."
    export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=16384}"
    mapshaper "${DIST_DIR}"/*.geojson combine-files -merge-layers \
      -filter-fields polygon_uuid,land_type,local_government_cd \
      -simplify 10% -o format=topojson "$TOPOJSON"
    echo "  ✅ ${TOPOJSON}"
  else
    echo "⚠ [3/3] mapshaper が無いため TopoJSON をスキップ（--no-topojson 相当）"
    DO_TOPOJSON=0
  fi
fi

# 4) GitHub Release へアップロード
if [[ "$DO_RELEASE" -eq 1 ]]; then
  command -v gh >/dev/null 2>&1 || { echo "❌ gh が見つかりません（--no-release で生成のみ可）"; exit 1; }
  echo "▶ GitHub Release を作成..."

  gh release create "v${YEAR}-merged${PREF}-geojson" "$GEOJSON" \
    -t "${YEAR}年統合GeoJSON(${PREF})" -n "サイズが大きいためReleaseで配布"

  gh release create "v${YEAR}-merged${PREF}-ndjson" "$NDJSON" \
    -t "${YEAR}年統合NDJSON(${PREF})" -n "${YEAR}年度データをもとにNDJSONを作成"

  if [[ "$DO_TOPOJSON" -eq 1 ]]; then
    gh release create "v${YEAR}-merged${PREF}-topojson" "$TOPOJSON" \
      -t "${YEAR}年統合TopoJSON(${PREF})" -n "サイズが大きいためReleaseで配布"
  fi
  echo "✅ Release 作成完了"
else
  echo "ℹ --no-release 指定のため生成のみ完了（アップロードは未実施）"
fi

echo "🎉 完了: ${DIST_DIR}"
