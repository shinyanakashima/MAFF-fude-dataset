#!/bin/bash
# 複数のGeoJSONファイルをNDJSON形式に変換します。
# 1ファイルずつストリーム処理するため、大容量(GB級)のGeoJSONでもメモリを溢れさせません。
#
# 使い方:
#   ./merge_to_ndjson.sh [YEAR] [PREF]
#     YEAR: 年度 (例: 2024, 2025, 2026)。省略時は 2025
#     PREF: 都道府県コード2桁ディレクトリ (例: 01)。省略時は 01
# Heapが不足する場合に備えてNode.jsのメモリ制限を増やす
export NODE_OPTIONS="--max-old-space-size=8192"

YEAR="${1:-2025}"
PREF="${2:-01}"

# 出力設定（年度・都道府県を反映）
DIST_DIR="${YEAR}/${PREF}"
OUT_FILE="merged_${PREF}.ndjson"
OUT_PATH="${DIST_DIR}/${OUT_FILE}"

if [[ ! -d "$DIST_DIR" ]]; then
  echo "❌ ディレクトリが存在しません: $DIST_DIR"
  exit 1
fi

# 1. JSON構文チェック（エラーがあれば中止）
echo "🔍 JSON構文チェック中..."
parse_error=0
while read -r f; do
  if ! jq empty "$f" 2>/dev/null; then
    echo "❌ JSON parse error: $f"
    parse_error=1
  fi
done < <(find "${DIST_DIR}" -type f -name '*.geojson' ! -name 'merged_*.geojson')

if [[ "$parse_error" -ne 0 ]]; then
  echo "⛔ 構文エラーが見つかったため処理を中止します。"
  exit 1
fi

# 出力ファイルを空に初期化
: > "$OUT_PATH"

# 2. 各GeoJSONをストリーム処理してNDJSON化（1ファイルずつ＝省メモリ）
#    変換と同時にFeature数を集計する（tee で追記しつつ wc -l でカウント）
echo ""
echo "📊 各GeoJSONファイルのFeature数:"
total=0
while read -r f; do
  fname=$(basename "$f")
  echo "▶ Processing ${fname}…" >&2
  # -c: compact、'.features[]'で要素ごとにストリーム出力
  count=$(jq -c '.features[]' "$f" | tee -a "$OUT_PATH" | wc -l)
  echo "  ${fname}: ${count} features"
  total=$((total + count))
done < <(find "${DIST_DIR}" -type f -name '*.geojson' ! -name 'merged_*.geojson')

echo "🔢 GeoJSON全体のFeature合計数: $total"

# 3. NDJSONのFeature数を確認
ndjson_count=$(wc -l < "$OUT_PATH")
echo "📦 NDJSONに変換完了: $OUT_PATH"
echo "📈 NDJSONのFeature数: $ndjson_count"
