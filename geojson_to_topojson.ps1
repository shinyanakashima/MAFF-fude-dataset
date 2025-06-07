$srcDir = "01"
$files = Get-ChildItem "$srcDir\*.geojson"

foreach ($file in $files) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $input = $file.FullName
    $output = "$srcDir\$name.topojson"

    mapshaper -i "$input" -o format=topojson "$output"
    Write-Host "✅ $name を TopoJSON に変換しました"
}
