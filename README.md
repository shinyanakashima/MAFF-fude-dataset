# MAFF-fude-geojson-2024
農水省 筆ポリゴンのGeoJSON（2024年度）

# データについて
- 筆ポリゴンとして配布される`GeoJSON`ファイルは、『地方公共団体コード（`local_government_cd`）』単位で配布されている。
- それらファイルを変換したものを『個別ファイル』とする
- それらファイルを１ファイルに統合したファイルを『統合ファイル』とする

## 個別ファイル
- 個別ファイルを[01](01)に追加した
- ファイル形式は、`GeoJSON`, `TopoJSON`を追加した

## 統合ファイル
- 統合データを、`GeoJSON`, `TopoJSON`, `NDJSON`それぞれで作成した
- [release](https://github.com/shinyanakashima/MAFF-fude-geojson-2024/releases)から入手できる

# データ作成
## Setup
Linux環境は`podman`, `WSL2`, `Conoha`を利用。
✔️ Conohaでは下記をGlobal Installして対応した。
```bash
npm install -g ndjson-cli
npm install -g topojson
npm install -g mapshaper
```

### GeoJSON

```bash
gh release create v2024-merged 01/merged_01.geojson --title "2024年統合GeoJSON" --notes "サイズが大きいためReleaseで配布"
```

### TopoJSON
Conohaでメモリエラーが起きるのでローカルPC似て作成。

- メモリを16GBに設定し、mapshaperで返還後、Releaseで配布

```powershell
$env:NODE_OPTIONS="--max-old-space-size=16384"

mapshaper 01/*.geojson combine-files -merge-layers -filter-fields polygon_uuid,land_type,local_government_cd -simplify 10% -o format=topojson 01/merged_01.topojson

gh release create v2024-merged01 01/merged_01.topojson -t "2024統合TopoJSON" -n "サイズが大きいためReleaseで配布"
```

## NDJSON

```powershell
gh release create v2024-merged01 01/merged_01.ndjson -t "2024統合NDJSON" -n "2024年度データをもとにNDJSONを作成"
```
