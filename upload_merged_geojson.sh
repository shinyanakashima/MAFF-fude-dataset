#!/bin/bash

# ----------- 設定（必要に応じて変更）-------------
TAG_NAME="v2024-merged"
RELEASE_TITLE="2024年統合GeoJSON"
RELEASE_NOTES="サイズが大きいため、GitHub Releaseで配布しています。"
FILE_TO_UPLOAD="01/merged_01.geojson"
GH_BIN="$HOME/bin/gh"
# -----------------------------------------------

# バイナリ存在確認
if [ ! -x "$GH_BIN" ]; then
  echo "❌ gh コマンドが見つかりません: $GH_BIN"
  exit 1
fi

# アップロード対象ファイル存在確認
if [ ! -f "$FILE_TO_UPLOAD" ]; then
  echo "❌ アップロード対象ファイルが存在しません: $FILE_TO_UPLOAD"
  exit 1
fi

# リリース作成＆ファイルアップロード
echo "🚀 GitHub Releaseを作成します..."
"$GH_BIN" release create "$TAG_NAME" "$FILE_TO_UPLOAD" \
  --title "$RELEASE_TITLE" \
  --notes "$RELEASE_NOTES"

echo "✅ アップロード完了: $FILE_TO_UPLOAD → リリース $TAG_NAME"

