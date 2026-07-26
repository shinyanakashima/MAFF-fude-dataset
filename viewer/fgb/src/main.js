import 'maplibre-gl/dist/maplibre-gl.css';
import './style.css';
import style from './assets/style.json';

import maplibregl from 'maplibre-gl';
import { deserialize } from 'flatgeobuf/lib/mjs/geojson';
import throttle from 'lodash.throttle';

// 対応年度（新しい順に並べると初期値が最新になる）。
// データ配信URLは年度をパスとファイル名に埋め込む共通フォーマット。
const YEARS = [2026, 2025, 2024];
const DEFAULT_YEAR = 2024; // 既存データが存在する年度を既定にする
let currentYear = DEFAULT_YEAR;

// 年度切替時に進行中の読み込み結果が後から上書きするのを防ぐためのトークン
let loadToken = 0;

const buildFgbUrl = (year) =>
  `https://zksdx.org/map/opendata/maff/fude_polygon/${year}/fgb/fude_${year}_01.fgb`;

const map = new maplibregl.Map({
  container: "map",
  style,
  center: [143.15950914681895, 42.92919045913274], // 初期位置
  zoom: 12,
  minZoom: 9,
  maxZoom: 18,
  hash: true,
});

function fgbBoundingBox() {
  const { _sw, _ne } = map.getBounds();
  return {
    minX: _sw.lng,
    minY: _sw.lat,
    maxX: _ne.lng,
    maxY: _ne.lat,
  };
}

async function updateResults() {
  // polygons-fillレイヤーと連動。こちらはデータ読み込みをスキップするための制御
  if (map.getZoom() < 9) return;

  const token = ++loadToken; // この読み込みの世代を記録
  document.getElementById("loading-ui")?.classList.remove("hidden"); // 表示
  const fc = { type: "FeatureCollection", features: [] };
  let i = 0;
  try {
    for await (const feature of deserialize(buildFgbUrl(currentYear), fgbBoundingBox())) {
      // 年度切替などで新しい読み込みが始まっていたら、この世代は破棄する
      if (token !== loadToken) return;
      fc.features.push({ ...feature, id: feature.properties.polygon_uuid ?? `fude-${i++}` });
    }
    if (token !== loadToken) return;
    map.getSource("polygons")?.setData(fc);
  } catch (err) {
    // 対象年度のデータが未配信の場合などはコンソールに記録し、地図は維持する
    console.error(`筆ポリゴン(${currentYear})の読み込みに失敗しました:`, err);
  } finally {
    if (token === loadToken) {
      document.getElementById("loading-ui")?.classList.add("hidden"); // 非表示
    }
  }
}

// 年度切替UI（地図左上に配置するセレクタ）
function addYearSelector() {
  const wrapper = document.createElement("div");
  wrapper.className = "year-selector";

  const label = document.createElement("label");
  label.htmlFor = "year-select";
  label.textContent = "年度";

  const select = document.createElement("select");
  select.id = "year-select";
  for (const year of YEARS) {
    const opt = document.createElement("option");
    opt.value = String(year);
    opt.textContent = `${year}年度`;
    if (year === currentYear) opt.selected = true;
    select.appendChild(opt);
  }

  select.addEventListener("change", (e) => {
    currentYear = Number(e.target.value);
    // 旧年度のポリゴンを即座に消去してから読み込み直す
    map.getSource("polygons")?.setData({ type: "FeatureCollection", features: [] });
    updateResults();
  });

  wrapper.appendChild(label);
  wrapper.appendChild(select);
  map.getContainer().appendChild(wrapper);
}

map.on("load", () => {
  addYearSelector();
  map.on("moveend", throttle(updateResults, 1000));
  updateResults();
});
