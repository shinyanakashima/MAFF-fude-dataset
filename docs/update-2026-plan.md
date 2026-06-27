# 2026年度 筆ポリゴン更新計画

農林水産省の筆ポリゴン公開サイトで令和8年度データが追加されたため、既存の2024年度ベースのデータセットを2026年度版へ更新するための作業メモです。

## 目的

- 2026年度の筆ポリゴンGeoJSONを取得する
- 都道府県・地方公共団体コード単位の個別ファイルを整理する
- 統合データを作成する
- 配信用データ形式を作成する
  - GeoJSON
  - NDJSON
  - TopoJSON
  - FlatGeobuf
  - PMTiles / MBTiles / MVT は `MAFF-fude-vectortiles` 側で管理
- GitHub Releaseで大容量ファイルを配布する
- READMEの年度表記、出典、作成手順を更新する

## 対象リポジトリ

| repository | 役割 |
| --- | --- |
| `MAFF-fude-geojson` | 元データ、GeoJSON、TopoJSON、NDJSONの作成・配布 |
| `MAFF-fude-fgb` | FlatGeobuf化したデータセットと表示ページ |
| `MAFF-fude-vectortiles` | PMTiles / MBTiles / MVT 形式の配布 |

## 推奨ディレクトリ構成

```txt
MAFF-fude-geojson/
  2026/
    raw/              # 公開サイトから取得した元ファイル
    geojson/          # 個別GeoJSON
    ndjson/           # 個別または統合NDJSON
    topojson/         # 統合TopoJSON
    merged/           # 統合GeoJSON等
  scripts/
    release_asset.sh  # Releaseアップロード共通スクリプト
```

既存の `01/` ディレクトリ方式を継続する場合でも、年度が増えると混乱しやすいため、2026年度からは `2026/01/` または `2026/geojson/01/` のように年度を明示する方針を推奨します。

## 作業手順案

### 1. データ取得

筆ポリゴン公開サイトから2026年度データを取得する。

確認事項:

- 利用規約
- データ仕様
- 座標系
- 属性名の変更有無
- 地方公共団体コード単位のファイル名規則

### 2. ファイル配置

```bash
mkdir -p 2026/raw
mkdir -p 2026/geojson
mkdir -p 2026/merged
mkdir -p 2026/ndjson
mkdir -p 2026/topojson
```

### 3. 統合GeoJSON作成

大容量になるため、ローカルPCまたは十分なメモリのあるサーバで処理する。

```bash
mapshaper 2026/geojson/*.geojson combine-files -merge-layers -o 2026/merged/merged_2026.geojson
```

### 4. NDJSON作成

```bash
ndjson-split 'd.features' < 2026/merged/merged_2026.geojson > 2026/ndjson/merged_2026.ndjson
```

### 5. TopoJSON作成

メモリ不足になりやすいため、必要に応じて `NODE_OPTIONS` を指定する。

```bash
export NODE_OPTIONS="--max-old-space-size=16384"
mapshaper 2026/geojson/*.geojson \
  combine-files \
  -merge-layers \
  -filter-fields polygon_uuid,land_type,local_government_cd \
  -simplify 10% \
  -o format=topojson 2026/topojson/merged_2026.topojson
```

### 6. FlatGeobuf作成

`MAFF-fude-fgb` 側で管理するが、GeoJSON側で中間成果物として作ってもよい。

```bash
ogr2ogr -f FlatGeobuf 2026/merged/merged_2026.fgb 2026/merged/merged_2026.geojson
```

### 7. Release配布

`release_asset.sh` を使い、年度・タグ・ファイルを明示してアップロードする。

```bash
YEAR=2026 \
TAG_NAME=v2026-merged-geojson \
RELEASE_TITLE="2026年度 統合GeoJSON" \
FILE_TO_UPLOAD=2026/merged/merged_2026.geojson \
./scripts/release_asset.sh
```

## README更新ポイント

- `2024年度` だけでなく `2026年度` の配布有無を明記する
- 取得日を明記する
- 加工内容を明記する
- Releaseリンクを年度別に整理する
- `MAFF-fude-fgb` と `MAFF-fude-vectortiles` との関係を明記する

## 未決事項

- 2025年度データを残すか、2026年度を最新として扱うか
- 都道府県単位でReleaseを分けるか、全国統合のみReleaseに置くか
- GeoJSON本体をリポジトリに置くか、Release配布のみに寄せるか
- PMTiles生成をGitHub Actions化するか、ローカル処理にするか
