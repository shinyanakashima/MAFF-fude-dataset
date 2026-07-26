# MAFF-fude-dataset
農水省 [筆ポリゴン](https://open.fude.maff.go.jp/) のデータセットと変換パイプライン。

> 旧 `MAFF-fude-geojson`。`MAFF-fude-fgb` を統合した。

## 提供しているもの

| | 用途 | 配信元 |
| --- | --- | --- |
| [ビューア](https://shinyanakashima.github.io/MAFF-fude-dataset/fgb/) | 地図上で筆ポリゴンを閲覧 | GitHub Pages |
| [API](https://maff-fude-api.it-zukosha.workers.dev/) | bbox検索・筆ID取得・集計・タイル配信 | Cloudflare Workers |
| Release | 統合ファイル（GeoJSON / TopoJSON / NDJSON）のダウンロード | GitHub Releases |
| 個別GeoJSON | 市区町村単位の元データ（北海道のみ） | このリポジトリ |

## 整備状況

対象は**北海道（都道府県コード`01`）**。パイプライン自体は47都道府県に対応しているが、
実務上の対象が道内であるため保存はしていない（後述）。

| 年度 | 個別GeoJSON | FGB | PMTiles | Parquet | D1 |
| ---- | ----------- | --- | ------- | ------- | -- |
| 2024 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2025 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2026 | — | ✅ | ✅ | ✅ | ✅ |

2026年度は配布zipをR2へ退避しており、個別GeoJSONはリポジトリに含めていない。

## 構成
```
.
├─ 2024/01/ 2025/01/       … 個別GeoJSON・TopoJSON（市区町村単位）
├─ scripts/                … R2アップロードスクリプト
├─ viewer/fgb/             … FlatGeobufビューア（GitHub Pages）
├─ .github/workflows/      … 変換パイプライン
└─ *.sh, *.ps1, *.js       … 取得・統合スクリプト（手動実行用）
```

配信用の成果物は Cloudflare R2（`geo-opendata` バケット）に置く。

| プレフィックス | 内容 | 生成 |
| -------------- | ---- | ---- |
| `maff-fude/source/<YEAR>/` | 農水省の配布zip（原本） | 手動 |
| `maff-fude/fgb/<YEAR>/<PREF>/` | FlatGeobuf | `Build FGB to R2` |
| `maff-fude/pmtiles/<YEAR>/` | PMTiles | `Build PMTiles from FGB`※ |
| `maff-fude/parquet/<YEAR>/<PREF>/` | GeoParquet | `Build Parquet from FGB` |

※ PMTiles生成は [MAFF-fude-vectortiles](https://github.com/shinyanakashima/MAFF-fude-vectortiles) にある。

# 変換パイプライン

配布zipをR2へ置いたあと、Actionsを順に実行すれば全形式が揃う。
年度が変わっても同じ手順で再現できる。

```
配布zip → [Build FGB to R2] → FGB ─┬→ [Build PMTiles from FGB] → PMTiles
                                    ├→ [Build Parquet from FGB] → Parquet
                                    └→ [Load D1 from Parquet]   → D1（筆ID索引）
```

各ワークフローは年度（`year`）と都道府県コード（`prefs`）を指定して実行する。
`prefs` に `all` を指定すると01〜47を並列処理する。

## 事前設定（Secrets）

| Secret | 用途 |
| ------ | ---- |
| `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` | R2への読み書き（`geo-opendata`限定のトークン） |
| `R2_ENDPOINT` | `https://<ACCOUNT_ID>.r2.cloudflarestorage.com` |
| `CLOUDFLARE_API_TOKEN` | D1投入用（D1:Edit権限） |
| `CLOUDFLARE_ACCOUNT_ID` | CloudflareのアカウントID |

## Build FGB to R2
個別GeoJSONから`FlatGeobuf`を生成してR2へ配置する。元データの所在で自動的に分岐する。

1. `<YEAR>/<PREF>/*.geojson` がリポジトリにある → そのまま変換
2. R2 に `maff-fude/source/<YEAR>/<YEAR>_<PREF>.zip` がある → 展開して変換
3. `maff_list_<PREF>.csv` がある → ダウンロードしてから変換
4. いずれも無い → 警告を出してスキップ

配布zipは中身が`.json`、リポジトリ内は`.geojson`だが、GDALは拡張子に依存せず読めるため
両方をそのまま変換対象にしている。

> FGBへ1ファイルずつappendすると空間インデックスを都度再構築して極端に遅い
> （188ファイルで10分以上）。一旦NDJSON（GeoJSONSeq）へ連結してから1パスで変換している（約3分）。

### 配布zipのR2退避
農水省の配布物はアンケート回答が必要で自動取得できない。入手したらR2へ退避しておくと
ワークフローから再利用でき、再取得の手間を避けられる。

```bash
rclone copy --progress . r2:geo-opendata/maff-fude/source/<YEAR>/ --include "*.zip"
```

## Build Parquet from FGB
R2上のFGBから解析用のGeoParquetを生成する。ジオメトリはWKB、bbox
（`min_lng`/`min_lat`/`max_lng`/`max_lat`）と`year`/`pref`をカラムとして保持する。

DuckDBはrow groupのmin/max統計で絞り込むため、Hiveパーティションに頼らず
カラムだけで実用的なプルーニングが効く。

```sql
INSTALL spatial; LOAD spatial;
SELECT land_type, count(*) FROM 'fude_2026_01.parquet' GROUP BY land_type;
```

北海道での実測値:

| 形式 | サイズ | 用途 |
| ---- | ------ | ---- |
| 個別GeoJSON（展開） | 1,971 MB | — |
| FGB | 845 MB | APIの空間検索 |
| Parquet（ZSTD） | 304 MB | 解析 |

81万件の集計が0.02秒、bbox絞り込みが0.04秒で返る。

## Load D1 from Parquet
R2上のParquetからD1の属性インデックスを投入する。

D1は**筆ID（`polygon_uuid`）から場所・属性を引く索引**として使う。FGBは位置でしか引けず、
ParquetはWorkerから読めないため、`GET /api/fude/:uuid` はD1が担う。
ジオメトリ本体はD1に入れない（R2のFGBが持つ）。

500行/INSERT・50,000行/ファイルに分割して`wrangler d1 execute`で順に投入し、
最後にParquetとD1の件数を突合する。北海道1年度で808,973行・17ファイル・計85MB。

# 手動での統合ファイル生成

Releaseで配布する統合ファイル（GeoJSON / TopoJSON / NDJSON）は、現状スクリプトを
手動実行して作成している。

## 年度の指定方法
各スクリプトは第1引数で年度（`YEAR`）、第2引数で都道府県コード（`PREF`）を受け取る。
省略時は `YEAR=2025`, `PREF=01`。

```bash
./download_geojson.sh 2026 01     # 配布GeoJSONを 2026/01/ へダウンロード
./rename.sh           2026 01     # .json → .geojson にリネーム
./merge_to_geojson.sh 2026 01     # 統合GeoJSONを作成
./merge_to_ndjson.sh  2026 01     # 統合NDJSONを作成（省メモリのストリーム処理）
./geojson_to_topojson.sh 2026 01  # 個別TopoJSONを作成
```

`download_geojson.sh` は `maff_list_<PREF>.csv` を参照する。CSVは農水省サイトで
`get_download_link.js` をブラウザのコンソールで実行して取得する。取得したCSVを
リポジトリに残しておくと、`Build FGB to R2` がダウンロードから自動実行できる。

## 統合ファイル生成＋Release（一括）
`build_release.sh` は生成からGitHub Releaseへのアップロードまでを1コマンドで実行する。

```bash
./build_release.sh 2025 01              # 生成してReleaseまで作成
./build_release.sh 2025 01 --no-release # 生成のみ（gh不要）
./build_release.sh 2025 01 --no-topojson# mapshaper未導入環境向け
```

> 前提ツール: `jq`（必須）, `mapshaper`（TopoJSON統合）, `gh`（Release作成）。
> NDJSONは1ファイルずつのストリーム処理、GeoJSONはNDJSONから包む方式で、いずれも省メモリ。

TopoJSONの統合はメモリを要するため、ローカルPCで実行する。

```powershell
$env:NODE_OPTIONS="--max-old-space-size=16384"
mapshaper 2026/01/*.geojson combine-files -merge-layers `
  -filter-fields polygon_uuid,land_type,local_government_cd -simplify 10% `
  -o format=topojson 2026/01/merged_01.topojson
```

## Release
統合ファイルはサイズが大きいため[Release](https://github.com/shinyanakashima/MAFF-fude-dataset/releases)で配布する。

| タグ | 内容 |
| ---- | ---- |
| `v2024-merged` | 2024年統合GeoJSON |
| `v2024-merged01` | 2024統合TopoJSON |
| `v2024-merged01-NDJSON` | 2024統合NDJSON |

> タグの命名が揺れている。今後追加する分は**年度×県ごとに1リリース**とし、
> タグ `v<YEAR>-<PREF>`（例: `v2025-01`）に3形式のファイルをまとめて添付する。

# ビューア（GitHub Pages）
`viewer/fgb/` にFlatGeobufビューアを配置し、`main`へのpushで自動デプロイする。

https://shinyanakashima.github.io/MAFF-fude-dataset/fgb/

データはAPIの`/api/fude?bbox=`から取得する（R2は非公開のため直接は読めない）。
APIのbbox上限は一辺0.2度で、z13以下では表示範囲が超過するため初期ズームはz14。
上限を超える範囲ではリクエストせず案内を出す。

複数のビューアを並べられるようサブパス構成にしている。viteの`base`は相対パス（`./`）
なので、リポジトリ名やサブパスが変わってもアセット参照は壊れない。

```bash
cd viewer/fgb && pnpm install && pnpm run dev   # ローカル開発
```

# 保持スコープの方針
**保存するデータは北海道（01）のみ**とする。パイプラインは全国対応で、`prefs=all` を
指定すれば47都道府県を処理できるが、実務上の対象が道内であるため保存しない。

| 種別 | 保持範囲 | 備考 |
| ---- | -------- | ---- |
| `source/` の配布zip | 入手できた年度の全県 | 再取得にアンケート回答が必要なため原本として保管 |
| `fgb/` `pmtiles/` `parquet/` | 北海道のみ | 道外はzipから随時再生成できる |
| リポジトリ内のGeoJSON | 北海道のみ | サンプル・パイプライン検証用 |

道外が必要になった場合は `prefs=all` で実行すれば数十分で再生成できる。

# データについて
- 筆ポリゴンは『地方公共団体コード（`local_government_cd`）』単位で配布される
- それらを変換したものを『個別ファイル』、1ファイルに統合したものを『統合ファイル』とする
- 個別ファイルは `<YEAR>/<PREF>/` に格納する（例: `2025/01/`）

## 属性
| フィールド | 内容 |
| ---------- | ---- |
| `polygon_uuid` | 筆ID。年度ごとに振り直される |
| `last_polygon_uuid` | 前年度の筆ID。年度をまたいだ追跡に使う |
| `land_type` | 地目（100=田, 200=畑） |
| `local_government_cd` | 地方公共団体コード |
| `issue_year` / `edit_year` | 公開年度 / 更新年度 |
| `point_lng` / `point_lat` | 代表点 |

# 関連リポジトリ

| リポジトリ | 役割 |
| ---------- | ---- |
| MAFF-fude-API（非公開） | 筆ポリゴンAPI（Cloudflare Workers）。APIそのものは[公開](https://maff-fude-api.it-zukosha.workers.dev/) |
| [MAFF-fude-vectortiles](https://github.com/shinyanakashima/MAFF-fude-vectortiles) | PMTiles生成・タイルビューア |

# 出典
本プロジェクトでは「筆ポリゴン」の名称を用いていますが、農林水産省が公開する
「[筆ポリゴン](https://open.fude.maff.go.jp/)」を独自に取得し変換したものです。

- 「筆ポリゴンデータ」（農林水産省）を加工して作成
- 詳細な利用については[筆ポリゴン公開サイト利用マニュアル](https://opendata.fude.maff.go.jp/筆ポリゴン公開サイト利用マニュアル.pdf)をご覧ください

# 免責
コンテンツの完全性・正確性・有用性・安全性等について利用者に対し一切の保証をしません。
