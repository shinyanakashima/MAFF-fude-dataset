#!/bin/bash
# FlatGeobuf(FGB)を Cloudflare R2 (geo-opendata バケット) へアップロードします。
# レンサバ(Conoha)や CI から実行することを想定しています。
#
# 使い方:
#   ./upload_fgb_r2.sh [YEAR] [PREF] [INPUT]
#     YEAR : 年度 (例: 2024, 2025, 2026)。省略時は 2025
#     PREF : 都道府県コード2桁 (例: 01)。省略時は 01
#     INPUT: アップロードするFGBのパス。省略時は fude_<YEAR>_<PREF>.fgb
#
# 事前準備(いずれか):
#   A) rclone に remote を設定しておく(既定の remote 名は "r2"、R2_REMOTE で変更可)
#        rclone config  # type=s3, provider=Cloudflare, endpoint=<account>.r2.cloudflarestorage.com
#   B) 環境変数で remote を注入する(CI向け。rclone.conf 不要)
#        export RCLONE_CONFIG_R2_TYPE=s3
#        export RCLONE_CONFIG_R2_PROVIDER=Cloudflare
#        export RCLONE_CONFIG_R2_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
#        export RCLONE_CONFIG_R2_ACCESS_KEY_ID=<KEY>
#        export RCLONE_CONFIG_R2_SECRET_ACCESS_KEY=<SECRET>
#        export RCLONE_CONFIG_R2_REGION=auto
#
# 配置先キー(全フォーマット共通の階層):
#   <bucket>/maff-fude/fgb/<YEAR>/<PREF>/fude_<YEAR>_<PREF>.fgb
set -euo pipefail

YEAR="${1:-2025}"
PREF="${2:-01}"
INPUT="${3:-fude_${YEAR}_${PREF}.fgb}"

R2_REMOTE="${R2_REMOTE:-r2}"
R2_BUCKET="${R2_BUCKET:-geo-opendata}"
DATASET="maff-fude"
DEST_KEY="${DATASET}/fgb/${YEAR}/${PREF}/fude_${YEAR}_${PREF}.fgb"
DEST="${R2_REMOTE}:${R2_BUCKET}/${DEST_KEY}"

# 引数チェック
[[ "$YEAR" =~ ^[0-9]{4}$ ]] || { echo "❌ YEAR は4桁で指定してください: $YEAR"; exit 1; }
[[ "$PREF" =~ ^[0-9]{2}$ ]] || { echo "❌ PREF は2桁で指定してください: $PREF"; exit 1; }

# 前提ツール・入力の存在確認
command -v rclone >/dev/null 2>&1 || { echo "❌ rclone が見つかりません。https://rclone.org/install.sh でインストールしてください"; exit 1; }
[ -f "$INPUT" ] || { echo "❌ 入力FGBが存在しません: $INPUT"; exit 1; }

echo "🚀 R2 へアップロードします"
echo "   from: $INPUT"
echo "   to  : $DEST"

# copyto はファイル名までキーに反映できるため、ローカル名が違っても規約通りに置ける
rclone copyto --progress ${DRYRUN:+--dry-run} "$INPUT" "$DEST"

echo "✅ アップロード完了: $DEST_KEY"
echo "🔎 確認: rclone ls ${R2_REMOTE}:${R2_BUCKET}/${DATASET}/fgb/${YEAR}/"
