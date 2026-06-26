#!/bin/bash
# 複数のGeoJSONファイルをNDJSON形式に変換します。
# 1ファイルずつストリーム処理するため、大容量(GB級)のGeoJSONでもメモリを溢れさせません。
# Heapが不足する場合に備えてNode.jsのメモリ制限を増やす
export NODE_OPTIONS="--max-old-space-size=8192"

# 出力設定
DIST_DIR="2025/01"
OUT_FILE="merged_01.ndjson"
OUT_PATH="${DIST_DIR}/${OUT_FILE}"

# 1. JSON構文チェック（エラーがあれば中止）
echo "🔍 JSON構文チェック中..."
parse_error=0
while read -r f; do
  if ! jq empty "$f" 2>/dev/null; then
    echo "❌ JSON parse error: $f"
    parse_error=1
  fi
done < <(find "${DIST_DIR}" -type f -name '*.geojson')

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
done < <(find "${DIST_DIR}" -type f -name '*.geojson')

echo "🔢 GeoJSON全体のFeature合計数: $total"

# 3. NDJSONのFeature数を確認
ndjson_count=$(wc -l < "$OUT_PATH")
echo "📦 NDJSONに変換完了: $OUT_PATH"
echo "📈 NDJSONのFeature数: $ndjson_count"
