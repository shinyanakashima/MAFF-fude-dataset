# MAFF-fude-geojson

農林水産省の筆ポリゴンを、年度別に `GeoJSON` / `NDJSON` / `TopoJSON` 形式へ変換・配布するためのデータセット管理リポジトリです。

## データについて

- 筆ポリゴンとして配布される `GeoJSON` ファイルは、主に地方公共団体コード（`local_government_cd`）単位で扱う。
- 個別ファイルを統合し、配布用の統合ファイルを作成する。
- 大容量データはGitHubリポジトリ本体ではなく、原則としてGitHub Releaseで配布する。

## 年度別データ

| 年度 | 状態 | 備考 |
| --- | --- | --- |
| 2024 | 作成済み | 既存の統合GeoJSON / TopoJSON / NDJSONをRelease配布 |
| 2025 | 一部追加済み | 追加コミットあり。配布単位・README整理が必要 |
| 2026 | 作業準備中 | `docs/update-2026-plan.md` に更新計画を整理 |

## 関連リポジトリ

| repository | 役割 |
| --- | --- |
| `MAFF-fude-geojson` | 元データ、GeoJSON、TopoJSON、NDJSONの作成・配布 |
| `MAFF-fude-fgb` | FlatGeobuf化したデータセットと表示ページ |
| `MAFF-fude-vectortiles` | PMTiles / MBTiles / MVT形式の配布 |

## セットアップ

Linux、WSL2、ConoHaなどの環境で実行する想定です。

```bash
npm install -g mapshaper
```

加えて、以下のCLIが必要です。

```bash
# GeoJSON / FlatGeobuf 変換
ogr2ogr --version

# Release配布
gh --version
```

## 2026年度データ更新フロー

### 1. ダウンロードURL一覧を作成

公式の筆ポリゴン公開サイトから取得したダウンロードURLを、以下の形式で保存します。

```bash
cp docs/download-urls-2026.example.txt docs/download-urls-2026.txt
```

`docs/download-urls-2026.txt` にURLを1行1件で追加します。

```txt
https://example.invalid/path/01234.geojson 01234.geojson
https://example.invalid/path/01235.geojson 01235.geojson
```

### 2. 元データを取得

```bash
YEAR=2026 ./scripts/download_from_url_list.sh
```

出力先:

```txt
2026/raw/
2026/raw/manifest.tsv
```

`manifest.tsv` には、URL、保存ファイル、サイズ、SHA-256を記録します。

### 3. GeoJSON配置

取得したファイルがZIP等の場合は展開し、GeoJSONを以下に配置します。

```txt
2026/geojson/
```

### 4. 統合・変換

```bash
YEAR=2026 ./scripts/build_merged_assets.sh
```

出力例:

```txt
2026/merged/merged_2026.geojson
2026/merged/merged_2026.fgb
2026/ndjson/merged_2026.ndjson
2026/topojson/merged_2026.topojson
```

### 5. GitHub Releaseで配布

```bash
YEAR=2026 \
TAG_NAME=v2026-merged-geojson \
RELEASE_TITLE="2026年度 統合GeoJSON" \
FILE_TO_UPLOAD=2026/merged/merged_2026.geojson \
./scripts/release_asset.sh
```

TopoJSONやNDJSONも同様にタグ名・ファイル名を変えて配布します。

```bash
YEAR=2026 \
TAG_NAME=v2026-merged-topojson \
RELEASE_TITLE="2026年度 統合TopoJSON" \
FILE_TO_UPLOAD=2026/topojson/merged_2026.topojson \
./scripts/release_asset.sh

YEAR=2026 \
TAG_NAME=v2026-merged-ndjson \
RELEASE_TITLE="2026年度 統合NDJSON" \
FILE_TO_UPLOAD=2026/ndjson/merged_2026.ndjson \
./scripts/release_asset.sh
```

## 既存メモ

### 2024年度のRelease例

```bash
gh release create v2024-merged 01/merged_01.geojson --title "2024年統合GeoJSON" --notes "サイズが大きいためReleaseで配布"
```

### TopoJSON作成時のメモリ設定

TopoJSON作成時はメモリ不足になりやすいため、必要に応じてNode.jsのメモリ上限を増やします。

```bash
export NODE_OPTIONS="--max-old-space-size=16384"
```

## 出典・利用条件

本プロジェクトでは「筆ポリゴン」の名称を用いていますが、農林水産省が公開する「筆ポリゴン」を独自に取得し、変換・加工したものです。

- 「筆ポリゴンデータ」（農林水産省）を加工して作成
- 詳細な利用条件は、筆ポリゴン公開サイトおよび利用マニュアルを確認してください

## 免責

コンテンツの完全性・正確性・有用性・安全性等について、利用者に対して一切の保証をしません。
