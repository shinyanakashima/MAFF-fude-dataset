import 'maplibre-gl/dist/maplibre-gl.css';
import './style.css';
import style from './assets/style.json';

import maplibregl from 'maplibre-gl';
import throttle from 'lodash.throttle';

// 対応年度（新しい順に並べると初期値が最新になる）
const YEARS = [2026, 2025, 2024];
const DEFAULT_YEAR = 2026;
const PREF = '01'; // 北海道
let currentYear = DEFAULT_YEAR;

// 年度切替時に進行中の読み込み結果が後から上書きするのを防ぐためのトークン
let loadToken = 0;

// 筆ポリゴンAPI。R2上のFGBをサーバ側でbbox検索してGeoJSONを返す。
// ビルド時に VITE_API_BASE で差し替えられる。
const API_BASE = import.meta.env.VITE_API_BASE ?? 'https://maff-fude-api.it-zukosha.workers.dev';

// APIのbbox上限（一辺0.2度）。これを超えるとエラーになるため、
// 表示範囲が広いときは読み込みをスキップする。
const MAX_BBOX_SPAN = 0.2;
// APIの取得上限。これに達した場合は表示が欠けるため警告する。
const FEATURE_LIMIT = 5000;

const buildApiUrl = (year, bbox) => {
  const q = new URLSearchParams({
    bbox: `${bbox.minX},${bbox.minY},${bbox.maxX},${bbox.maxY}`,
    year: String(year),
    pref: PREF,
    limit: String(FEATURE_LIMIT),
  });
  return `${API_BASE}/api/fude?${q}`;
};

const map = new maplibregl.Map({
  container: "map",
  style,
  center: [143.15950914681895, 42.92919045913274], // 初期位置
  // z13以下では表示範囲がAPIのbbox上限(0.2度)を超えるため、初期値はz14にする
  zoom: 14,
  minZoom: 9,
  maxZoom: 18,
  hash: true,
});

function currentBoundingBox() {
  const { _sw, _ne } = map.getBounds();
  return {
    minX: _sw.lng,
    minY: _sw.lat,
    maxX: _ne.lng,
    maxY: _ne.lat,
  };
}

const EMPTY = { type: "FeatureCollection", features: [] };

function setHint(text) {
  const el = document.getElementById("hint-ui");
  if (!el) return;
  el.textContent = text ?? "";
  el.classList.toggle("hidden", !text);
}

async function updateResults() {
  const bbox = currentBoundingBox();
  // 表示範囲がAPIのbbox上限を超えるときは要求せず、ズームを促す。
  // 広範囲を一度に描画しても実用的でないため、あえて読み込まない。
  if (bbox.maxX - bbox.minX > MAX_BBOX_SPAN || bbox.maxY - bbox.minY > MAX_BBOX_SPAN) {
    map.getSource("polygons")?.setData(EMPTY);
    setHint("ズームすると筆ポリゴンを表示します");
    return;
  }

  const token = ++loadToken; // この読み込みの世代を記録
  document.getElementById("loading-ui")?.classList.remove("hidden");
  try {
    const res = await fetch(buildApiUrl(currentYear, bbox));
    // 年度切替などで新しい読み込みが始まっていたら、この世代は破棄する
    if (token !== loadToken) return;
    if (!res.ok) throw new Error(`API ${res.status}`);
    const fc = await res.json();
    if (token !== loadToken) return;

    // maplibreのfeature-state用にIDを振る（APIのidは年度内で一意でないため筆IDを使う）
    fc.features = fc.features.map((f, i) => ({
      ...f,
      id: f.properties?.polygon_uuid ?? `fude-${i}`,
    }));
    map.getSource("polygons")?.setData(fc);

    setHint(
      fc.features.length >= FEATURE_LIMIT
        ? `表示上限(${FEATURE_LIMIT}件)に達しました。ズームすると全件表示されます`
        : null,
    );
  } catch (err) {
    // 対象年度のデータが未配信の場合などはコンソールに記録し、地図は維持する
    console.error(`筆ポリゴン(${currentYear})の読み込みに失敗しました:`, err);
    setHint("筆ポリゴンの読み込みに失敗しました");
  } finally {
    if (token === loadToken) {
      document.getElementById("loading-ui")?.classList.add("hidden");
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
    map.getSource("polygons")?.setData(EMPTY);
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
