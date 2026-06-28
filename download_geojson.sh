#!/bin/bash
# 筆ポリゴンの配布GeoJSONをCSVのダウンロードリンク一覧から取得します。
#
# 使い方:
#   ./download_geojson.sh [YEAR] [PREF]
#     YEAR: 年度 (例: 2024, 2025, 2026)。省略時は 2025
#     PREF: 都道府県コード2桁 (例: 01)。省略時は 01
#   CSVは maff_list_${PREF}.csv を参照し、${YEAR}/${PREF}/ 配下へ保存します。

YEAR="${1:-2025}"
PREF="${2:-01}"

CSV_FILE="maff_list_${PREF}.csv"
OUT_DIR="${YEAR}/${PREF}"
ARIA2C="$HOME/bin/aria2c"
REFERER="https://download.fude.maff.go.jp/"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36"

if [[ ! -f "$CSV_FILE" ]]; then
  echo "❌ CSVが存在しません: $CSV_FILE"
  exit 1
fi

mkdir -p "$OUT_DIR"

tail -n +2 "$CSV_FILE" | while IFS=, read -r text url filename; do
  url=$(echo "$url" | sed 's/^"\(.*\)"$/\1/')
  filename=$(echo "$filename" | sed 's/^"\(.*\)"$/\1/')

  if [[ -z "$url" || -z "$filename" ]]; then
    echo "スキップ: URLまたはファイル名が空です"
    continue
  fi

  echo "ダウンロード中: $filename"
  "$ARIA2C" \
    --allow-overwrite=true \
    --check-certificate=false \
    --referer="$REFERER" \
    --user-agent="$UA" \
    -o "${OUT_DIR}/${filename}" "$url"
done
