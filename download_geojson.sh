#!/bin/bash
CSV_FILE="maff_list_01.csv"
ARIA2C="$HOME/bin/aria2c"
REFERER="https://download.fude.maff.go.jp/"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36"

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
    -o output/"$filename" "$url"
done


