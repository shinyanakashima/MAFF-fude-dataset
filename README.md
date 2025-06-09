# MAFF-fude-geojson-2024
農水省 筆ポリゴンのGeoJSON（2024年度）


# Setup
ConohaではGlobal Installで対応した。
```bash
npm install -g ndjson-cli
npm install -g topojson
npm install -g mapshaper
```

# 統合ファイルの作成
`GeoJSON`, `TopoJSON`, `NDJSON`それぞれで統合ファイルを作成した。

## GeoJSON

```bash
gh release create v2024-merged 01/merged_01.geojson --title "2024年統合GeoJSON" --notes "サイズが大きいためReleaseで配布"
```

## TopoJSON
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
