# MAFF-fude-geojson
農水省 筆ポリゴンのGeoJSON（2024 / 2025 / 2026年度）

# データについて
- 筆ポリゴンとして配布される`GeoJSON`ファイルは、『地方公共団体コード（`local_government_cd`）』単位で配布されている。
- それらファイルを変換したものを『個別ファイル』とする
- それらファイルを１ファイルに統合したファイルを『統合ファイル』とする

## 年度別ディレクトリ
各年度のデータは年度ごとのディレクトリ配下に、さらに都道府県コード2桁のディレクトリ単位で格納する。

```
<YEAR>/<PREF>/   例: 2025/01/, 2026/01/
```

| 年度 | ディレクトリ | 状態 |
| ---- | ------------ | ---- |
| 2024 | [2024/](2024) | 整備済み |
| 2025 | [2025/](2025) | 整備済み |
| 2026 | [2026/](2026) | 受け入れ準備済み（データ追加待ち） |

## 個別ファイル
- 個別ファイルを各年度ディレクトリ（例: [2025/01](2025/01)）に追加した
- ファイル形式は、`GeoJSON`, `TopoJSON`を追加した

## 統合ファイル
- 統合データを、`GeoJSON`, `TopoJSON`, `NDJSON`それぞれで作成した
- サイズが大きいため[release](https://github.com/shinyanakashima/MAFF-fude-geojson/releases)から入手できる

# データ作成
## Setup
Linux環境は`podman`, `WSL2`, `Conoha`を利用。
✔️ Conohaでは下記をGlobal Installして対応した。
```bash
npm install -g ndjson-cli
npm install -g topojson
npm install -g mapshaper
```

## 年度の指定方法
各スクリプトは第1引数で年度（`YEAR`）、第2引数で都道府県コード（`PREF`）を受け取る。
いずれも省略可能で、省略時は `YEAR=2025`, `PREF=01`。

```bash
# 例: 2026年度・北海道(01)を処理する
./download_geojson.sh 2026 01     # 配布GeoJSONを 2026/01/ へダウンロード
./rename.sh           2026 01     # .json → .geojson にリネーム
./merge_to_geojson.sh 2026 01     # 統合GeoJSONを作成
./merge_to_ndjson.sh  2026 01     # 統合NDJSONを作成（省メモリのストリーム処理）
./geojson_to_topojson.sh 2026 01  # 個別TopoJSONを作成
./upload_merged_geojson.sh 2026 01 # 統合GeoJSONをGitHub Releaseへアップロード
```

## 統合ファイル生成＋Release（一括）
`build_release.sh` は、統合 GeoJSON / NDJSON / TopoJSON の生成から GitHub Release への
アップロードまでを1コマンドで実行する（2024年度と同じ配布フロー）。

```bash
# 例: 2025年度・北海道(01) を生成してReleaseまで作成
./build_release.sh 2025 01

# 生成だけ行い、アップロードはしない（gh不要）
./build_release.sh 2025 01 --no-release

# mapshaperが無い環境ではTopoJSONをスキップ
./build_release.sh 2025 01 --no-topojson
```

生成物と Release タグ（`<YEAR>/<PREF>/` 配下）:

| ファイル | Release タグ |
| -------- | ------------ |
| `merged_<PREF>.geojson`  | `v<YEAR>-merged<PREF>-geojson` |
| `merged_<PREF>.ndjson`   | `v<YEAR>-merged<PREF>-ndjson` |
| `merged_<PREF>.topojson` | `v<YEAR>-merged<PREF>-topojson` |

> 前提ツール: `jq`（必須）, `mapshaper`（TopoJSON統合）, `gh`（Release作成）。
> NDJSONは1ファイルずつのストリーム処理、GeoJSONはNDJSONから包む方式で、いずれも省メモリ。

## FGB生成とR2配置（GitHub Actions）
個別GeoJSONから`FlatGeobuf`を生成し、Cloudflare R2（`geo-opendata`バケット）へ配置する
ワークフロー（`.github/workflows/build-fgb-to-r2.yml`）。Actionsタブから
`Build FGB to R2` を実行し、年度と都道府県コードを指定する。

| 入力 | 例 | 説明 |
| ---- | -- | ---- |
| `year` | `2025` | 年度 |
| `prefs` | `01` / `01,13` / `all` | 対象県。`all`で01〜47を並列処理 |

元データの所在で自動的に分岐する（上から順に探す）。

1. `<YEAR>/<PREF>/*.geojson` がリポジトリにある → そのまま変換
2. R2 に `maff-fude/source/<YEAR>/<YEAR>_<PREF>.zip` がある → 展開して変換
3. `maff_list_<PREF>.csv` がある → ダウンロードしてから変換
4. いずれも無い → 警告を出してスキップ

配布zipは中身が `.json`、リポジトリ内は `.geojson` だが、GDALは拡張子に依存せず
GeoJSONを読めるため、両方をそのまま変換対象にしている。

### 配布zipのR2退避
農水省サイトの配布物（アンケート回答が必要で自動取得できない）は、入手したら
R2へ退避しておくとワークフローから再利用できる。再取得の手間を避けられる。

```bash
rclone copy --progress . r2:geo-opendata/maff-fude/source/<YEAR>/ --include "*.zip"
```

配置先は `maff-fude/fgb/<YEAR>/<PREF>/fude_<YEAR>_<PREF>.fgb`。
アップロード後にサイズ突合で検証する。事前にSecretsへ`R2_ACCESS_KEY_ID`,
`R2_SECRET_ACCESS_KEY`, `R2_ENDPOINT` を登録すること。

> FGBへ1ファイルずつappendすると空間インデックスを都度再構築して極端に遅いため、
> 一旦NDJSON（GeoJSONSeq）へ連結してから1パスで変換している。

## 解析用Parquetの生成（GitHub Actions）
R2上のFGBから解析用のGeoParquetを生成する
（`.github/workflows/build-parquet-from-fgb.yml`）。Actionsタブから
`Build Parquet from FGB` を実行し、年度と都道府県コードを指定する。

ジオメトリはWKB、bbox（`min_lng`/`min_lat`/`max_lng`/`max_lat`）と`year`/`pref`を
カラムとして保持する。DuckDBはrow groupのmin/max統計で絞り込むため、Hiveパーティションに
頼らずカラムだけで実用的なプルーニングが効く。

```sql
INSTALL spatial; LOAD spatial;
SELECT land_type, count(*) FROM 'fude_2025_01.parquet' GROUP BY land_type;
```

北海道（812,259 features）での実測値:

| 形式 | サイズ | 用途 |
| ---- | ------ | ---- |
| 元GeoJSON（展開） | 1,971 MB | — |
| FGB | 845 MB | APIの空間検索 |
| Parquet（ZSTD） | 304 MB | 解析 |

集計クエリは全81万件に対して0.02秒、bbox絞り込みは0.04秒。

## D1への属性投入（GitHub Actions）
R2上のParquetから、D1の属性インデックスを投入する
（`.github/workflows/load-d1-from-parquet.yml`）。Actionsタブから
`Load D1 from Parquet` を実行する。

D1は**筆ID（`polygon_uuid`）から場所・属性を引く索引**として使う。FGBは位置でしか
引けず、ParquetはWorkerから読めないため、`GET /api/fude/:uuid` はD1が担う。
ジオメトリ本体はD1に入れない（R2のFGBが持つ）。

| 入力 | 例 | 説明 |
| ---- | -- | ---- |
| `year` | `2026` | 年度 |
| `prefs` | `01` / `all` | 対象県 |
| `replace` | `true` | 投入前に対象年度・県の既存行を削除する |

処理の流れと実測値（北海道・808,973行）:

1. R2からParquetを取得
2. 値に想定外の文字が無いか確認（SQLへ直に埋め込むため）
3. DuckDBでVALUES行を生成
4. 500行/INSERT・50,000行/ファイルに分割 → **17ファイル・計85MB**
5. `wrangler d1 execute --remote --file` で順に投入
6. Parquetの件数とD1の件数を突合

D1への同時書き込みを避けるため、複数県を指定した場合も直列に実行する。
Secretsに`CLOUDFLARE_API_TOKEN`（D1:Edit）と`CLOUDFLARE_ACCOUNT_ID`の登録が必要。

## 保持スコープの方針
**データの保持は北海道（01）のみ**とする。パイプライン自体は全国対応で、`prefs=all` を
指定すれば47都道府県を処理できるが、実務上の対象が道内であるため保存はしない。

| 種別 | 保持範囲 | 備考 |
| ---- | -------- | ---- |
| `source/` の配布zip | 入手できた年度の全県 | 再取得にアンケート回答が必要なため原本として保管 |
| `fgb/` `pmtiles/` `parquet/` | 北海道のみ | 道外はzipから随時再生成できる |
| リポジトリ内のGeoJSON | 北海道のみ | サンプル・パイプライン検証用 |

道外が必要になった場合は、`prefs=all` で実行すれば数十分で再生成できる。

## データ取得
get_download_link.js でダウンロードリンク一覧（CSV）を生成し、`download_geojson.sh` で取得する。
取得したCSVはリポジトリに残しておくと、上記ワークフローがダウンロードから自動実行できる。

## merged GeoJSON → FGB
```bash
ogr2ogr -f FlatGeobuf merged_01.fgb 2026/01/merged_01.geojson
```

### TopoJSON（統合）
Conohaでメモリエラーが起きるのでローカルPCにて作成。

- メモリを16GBに設定し、mapshaperで変換後、Releaseで配布

```powershell
$env:NODE_OPTIONS="--max-old-space-size=16384"

mapshaper 2026/01/*.geojson combine-files -merge-layers -filter-fields polygon_uuid,land_type,local_government_cd -simplify 10% -o format=topojson 2026/01/merged_01.topojson

gh release create v2026-merged01 2026/01/merged_01.topojson -t "2026統合TopoJSON" -n "サイズが大きいためReleaseで配布"
```
