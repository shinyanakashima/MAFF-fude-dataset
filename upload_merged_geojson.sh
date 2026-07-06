#!/bin/bash
# 統合GeoJSONをGitHub Releaseとしてアップロードします。
#
# 使い方:
#   ./upload_merged_geojson.sh [YEAR] [PREF]
#     YEAR: 年度 (例: 2024, 2025, 2026)。省略時は 2025
#     PREF: 都道府県コード2桁ディレクトリ (例: 01)。省略時は 01

YEAR="${1:-2025}"
PREF="${2:-01}"

# ----------- 設定（年度・都道府県を反映）-------------
TAG_NAME="v${YEAR}-merged"
RELEASE_TITLE="${YEAR}年統合GeoJSON"
RELEASE_NOTES="サイズが大きいため、GitHub Releaseで配布しています。"
FILE_TO_UPLOAD="${YEAR}/${PREF}/merged_${PREF}.geojson"
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
