// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// ThunderEngine Web: гроза считается в браузере на WebGPU, шаг побитово
// равен эталону. Сценарии - пресеты, начальное состояние t = 0 записано
// с эталона.
const { Replayer } = await import('./replay.js?v=' + Date.now());
const { T } = await import('./i18n.js');
const { Volume, SURFACES, PLANE } = await import('./volume.js?v=' + Date.now());

const $ = id => document.getElementById(id);
const q = new URLSearchParams(location.search);
const get = u => fetch(u, { cache: 'no-store' });
// .gz распаковываем сами: сервер отдаёт файл как есть, без Content-Encoding
async function gunzip(u) {
  const res = await get(u);
  if (!res.ok) throw new Error(u + ': ' + res.status);
  return new Uint8Array(await new Response(res.body.pipeThrough(new DecompressionStream('gzip'))).arrayBuffer());
}
const dbg = s => window.webkit?.messageHandlers?.out?.postMessage(s);
const hud = $('hud'), cv = $('view'), ctx = cv.getContext('2d');
function post(s) { hud.textContent = s; dbg(s); }

const NS = 256;   // точек вдоль линии разреза
const st = { mode: q.get('mode') === '3d' ? '3d' : '2d', layer: +(q.get('layer') || 0), level: 4, composite: true,
  arrows: q.get('arrows') === '1', perFrame: 4, steps: 0, msPerStep: 0, verify: '', busy: false, dirty: true, line: null, lineAuto: true };
let index, scen, gi, tape, grid, r, device, vol, pre;
let viewPipe, viewBind, viewParams, viewOut, viewRead, derivePipe, deriveBind, samples, D, X;
let plan, cross, wind, secWind;
// Шкала времени: кольцо снимков полей показа на GPU (после диагностики
// отражаемости). Перемотка подставляет показу снимок вместо памяти модели,
// счёт не трогается; «вживую» - снова память модели.
const TL_FIELDS = ['dbz', 'w', 'qc', 'qi', 'qr', 'qg', 'th', 'u', 'v'];
const TL_BUDGET = 1536 * 2 ** 20;   // меньше предела буфера 2 ГБ
const tl = { buf: null, fields: [], stride: 0, size: 0, count: 0, every: 0, next: 0, times: [], head: 0, view: null };
// iPad/iPhone (в том числе iPad, который называет себя Маком): памяти меньше, бюджет скромнее
const MOBILE = /iPhone|iPad/.test(navigator.userAgent) || (navigator.maxTouchPoints > 1 && /Macintosh/.test(navigator.userAgent));
async function tlSetup() {
  tl.buf?.destroy(); tl.buf = null;
  tl.fields = TL_FIELDS.filter(n => tape.fields[n] !== undefined);
  tl.stride = tape.fieldStride; tl.size = tl.fields.length * tl.stride;
  // бюджет: не больше, чем даёт устройство; при отказе - вдвое меньше, пока не создастся.
  // Без проверки неудачный буфер молча «пустой»: снимки копятся, показать нечего (iPad, 2026-10-26)
  let budget = Math.min(MOBILE ? 384 * 2 ** 20 : TL_BUDGET, r.chunkCapacity, device.limits.maxBufferSize, device.limits.maxStorageBufferBindingSize);
  for (;;) {
    tl.count = Math.floor(budget / tl.size);
    if (tl.count < 2) { tl.count = 0; break; }
    tl.count = Math.min(240, tl.count);
    device.pushErrorScope('out-of-memory'); device.pushErrorScope('validation');
    const buf = device.createBuffer({ size: tl.count * tl.size, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST });
    const bad = (await device.popErrorScope()) || (await device.popErrorScope());
    if (!bad) { tl.buf = buf; break; }
    buf.destroy(); budget /= 2;
  }
  // снимок раз в минуту модели, реже - если не влезает весь прогон
  tl.every = tl.count ? Math.max(60, Math.ceil(scen.timax / tl.count / 60) * 60) : Infinity;
  tl.times = []; tl.head = 0; tl.next = tl.buf ? 0 : Infinity; tl.view = null; tl.srcs = new Map();
  dbg(`шкала времени: ${tl.count} снимков по ${(tl.size / 2 ** 20).toFixed(0)} МБ, раз в ${tl.every} с`);
}
// снимок, если время дошло (в кодировщик кадра, после диагностики)
function tlCapture(enc, t) {
  if (t < tl.next - 1e-6) return false;
  const slot = tl.head % tl.count, arena = tape.buffers.find(b => b.arena).id;
  tl.fields.forEach((n, i) => r.copyOut(enc, r.base[arena] + tape.fields[n] / 4, tl.stride / 4, tl.buf, slot * tl.size + i * tl.stride));
  tl.times[slot] = t; tl.head++;
  tl.srcs.delete(slot);
  while (tl.next <= t + 1e-6) tl.next += tl.every;
  return true;
}
// номер снимка по позиции ползунка (0 - самый старый из хранимых)
const tlSlots = () => { const n = Math.min(tl.head, tl.count); return Array.from({ length: n }, (_, k) => (tl.head - n + k) % tl.count); };
function tlSource(slot) {
  let s = tl.srcs.get(slot);
  if (s) return s;
  const fw = n => (slot * tl.size + tl.fields.indexOf(n) * tl.stride) / 4;
  s = { slot, fw, entries: r.memEntriesFor(tl.buf, 0) };
  tl.srcs.set(slot, s);
  return s;
}
function tlUI() {
  const el = $('tl'), slots = tlSlots();
  if (!tl.buf) { el.disabled = true; $('tlv').textContent = 'нет памяти'; return; }
  el.disabled = slots.length < 2;
  el.max = Math.max(0, slots.length - 1);
  if (tl.view == null) { el.value = el.max; $('tlv').textContent = 'вживую'; }
  else $('tlv').textContent = clock(tl.times[tl.view]) + ':' + String(Math.floor(tl.times[tl.view] % 60)).padStart(2, '0');
}

// ---- шкалы данных (цвет данных - не акцент интерфейса)
const DBZ = [[5, '#04e9e7'], [10, '#019ff4'], [15, '#0300f4'], [20, '#02fd02'], [25, '#01c501'], [30, '#008e00'],
  [35, '#fdf802'], [40, '#e5bc00'], [45, '#fd9500'], [50, '#fd0000'], [55, '#d40000'], [60, '#bc0000'],
  [65, '#f800fd'], [70, '#9854c6']];
const hex = h => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
const DBZRGB = DBZ.map(([v, c]) => [v, hex(c)]);
const lerp = (a, b, t) => [0, 1, 2].map(i => Math.round(a[i] + (b[i] - a[i]) * t));
const BG = [13, 18, 22];
function diverge(t) {
  t = Math.max(-1, Math.min(1, t));
  if (Math.abs(t) < 0.02) return BG;
  return t > 0 ? lerp([70, 30, 30], [255, 70, 50], Math.sqrt(t)) : lerp([30, 40, 80], [70, 140, 255], Math.sqrt(-t));
}
const SPEED = [[0, [13, 18, 22]], [5, [40, 60, 90]], [10, [40, 120, 160]], [15, [60, 170, 120]], [20, [200, 200, 70]],
  [25, [240, 150, 40]], [30, [230, 70, 40]], [40, [200, 40, 160]]];
function ramp(stops, v) {
  if (!(v > stops[0][0])) return stops[0][1];
  for (let i = 1; i < stops.length; i++) if (v < stops[i][0]) {
    const [a, ca] = stops[i - 1], [b, cb] = stops[i];
    return lerp(ca, cb, (v - a) / (b - a));
  }
  return stops[stops.length - 1][1];
}
// level: величина берётся на уровне (иначе - максимум по столбцу)
const LAYERS = [
  { name: 'Отражаемость', unit: 'дБZ', lo: 5, hi: 75, level: 'opt', color: v => { if (!(v >= 5)) return BG; let c = DBZRGB[0][1];
    for (const [t, rgb] of DBZRGB) if (v >= t) c = rgb; return c; } },
  { name: 'Вертикальная скорость', unit: 'м/с', lo: -20, hi: 20, level: true, color: v => diverge(v / 20) },
  { name: 'Вихрь ζ', unit: '10⁻³ 1/с', lo: -20, hi: 20, level: true, color: v => diverge(v / 20) },
  { name: 'Облака', unit: 'г/кг', lo: 0, hi: 3, level: false, color: v => { const t = Math.min(1, Math.max(0, v / 3)); return t < 0.003 ? BG : lerp([60, 70, 80], [255, 255, 255], Math.sqrt(t)); } },
  { name: 'θ′', unit: 'K', lo: -8, hi: 8, level: true, color: v => diverge(v / 8) },
  { name: 'Ветер', unit: 'м/с', lo: 0, hi: 40, level: true, color: v => ramp(SPEED, v) },
  // от радара: к радару - зелёный, от радара - красный (как у NWS)
  { name: 'Радиальная скорость', unit: 'м/с', lo: -30, hi: 30, level: true, radar: true, color: v => vrColor(v) },
];
function vrColor(v) {
  if (!(Math.abs(v) >= 0.5) || v > 1e8) return BG;
  const t = Math.min(1, Math.abs(v) / 30);
  return v < 0 ? lerp([20, 70, 30], [80, 255, 120], Math.sqrt(t)) : lerp([80, 25, 25], [255, 80, 80], Math.sqrt(t));
}

// ---- ζ в центрах ячеек: среднее четырёх углов, на углу
// (v[i] - v[i-1]) / (xh[i] - xh[i-1]) - (u[j] - u[j-1]) / (yh[j] - yh[j-1])
// (CM1 solve3.F:1067, zv_at эталона). D - той же раскладки, что поле арены.
const DERIVE_WGSL = `
@group(0) @binding(0) var<storage, read> M: array<u32>;
@group(0) @binding(1) var<storage, read> P: array<u32>;
@group(0) @binding(2) var<storage, read> X: array<f32>;
@group(0) @binding(3) var<storage, read_write> D: array<f32>;
fn c(i: i32, j: i32, k: i32) -> u32 { return u32((i + 3) + i32(P[3]) * ((j + 3) + i32(P[4]) * k)); }
fn fu(i: i32, j: i32, k: i32) -> f32 { return bitcast<f32>(M[P[14] + c(i, j, k)]); }
fn fv(i: i32, j: i32, k: i32) -> f32 { return bitcast<f32>(M[P[15] + c(i, j, k)]); }
fn xh(i: i32) -> f32 { return X[P[16] + u32(clamp(i, 0, i32(P[0]) - 1))]; }
fn yh(j: i32) -> f32 { return X[P[17] + u32(clamp(j, 0, i32(P[1]) - 1))]; }
fn corner(i0: i32, j0: i32, k: i32) -> f32 {
  let i = clamp(i0, 1, i32(P[0]) - 1); let j = clamp(j0, 1, i32(P[1]) - 1);
  let z = (fv(i, j, k) - fv(i - 1, j, k)) / (xh(i) - xh(i - 1)) - (fu(i, j, k) - fu(i, j - 1, k)) / (yh(j) - yh(j - 1));
  return select(0.0, z, abs(z) < 1.0e6);
}
@compute @workgroup_size(4, 4, 4)
fn main(@builtin(global_invocation_id) g: vec3<u32>) {
  let i = i32(g.x); let j = i32(g.y); let k = i32(g.z);
  if (i >= i32(P[0]) || j >= i32(P[1]) || k >= i32(P[2])) { return; }
  D[c(i, j, k)] = 0.25 * (corner(i, j, k) + corner(i + 1, j, k) + corner(i, j + 1, k) + corner(i + 1, j + 1, k));
}`;

// ---- показ: карта (композит или уровень), разрез по точкам S, ветер на уровне
const VIEW_WGSL = `
@group(0) @binding(0) var<storage, read> M: array<u32>;
@group(0) @binding(1) var<storage, read> P: array<u32>;
@group(0) @binding(2) var<storage, read> D: array<f32>;
@group(0) @binding(3) var<storage, read> S: array<vec2<f32>>;
@group(0) @binding(4) var<storage, read_write> O: array<f32>;
@group(0) @binding(5) var<storage, read> X: array<f32>;
fn c(i: u32, j: u32, k: u32) -> u32 { return (i + 3u) + P[3] * ((j + 3u) + P[4] * k); }
fn f(off: u32, i: u32, j: u32, k: u32) -> f32 { return bitcast<f32>(M[off + c(i, j, k)]); }
fn value(layer: u32, i: u32, j: u32, k: u32) -> f32 {
  switch (layer) {
    case 0u: { return f(P[9], i, j, k); }
    case 1u: { return 0.5 * (f(P[10], i, j, k) + f(P[10], i, j, k + 1u)); }
    case 2u: { return D[c(i, j, k)] * 1000.0; }
    case 3u: { return (f(P[11], i, j, k) + f(P[12], i, j, k)) * 1000.0; }
    case 4u: { return f(P[13], i, j, k); }
    case 5u: {
      let u = 0.5 * (f(P[14], i, j, k) + f(P[14], i + 1u, j, k));
      let v = 0.5 * (f(P[15], i, j, k) + f(P[15], i, j + 1u, k));
      return sqrt(u * u + v * v);
    }
    case 7u: { return 0.5 * (f(P[14], i, j, k) + f(P[14], i + 1u, j, k)); }
    case 8u: { return 0.5 * (f(P[15], i, j, k) + f(P[15], i, j + 1u, k)); }
    default: {
      // радиальная от радара в (P[18], P[19]) м; ветер относительно земли:
      // область движется со скоростью (umove, vmove) - P[20], P[21]
      let u = 0.5 * (f(P[14], i, j, k) + f(P[14], i + 1u, j, k)) + bitcast<f32>(P[20]);
      let v = 0.5 * (f(P[15], i, j, k) + f(P[15], i, j + 1u, k)) + bitcast<f32>(P[21]);
      let dx = X[i] - bitcast<f32>(P[18]); let dy = X[P[0] + j] - bitcast<f32>(P[19]);
      let r = sqrt(dx * dx + dy * dy);
      // радар видит скорость только по эху: ниже 5 дБZ - пусто
      if (f(P[9], i, j, k) < 5.0) { return 1.0e9; }
      return select(0.0, (u * dx + v * dy) / r, r > 1.0);
    }
  }
}
@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) g: vec3<u32>) {
  let nx = P[0]; let ny = P[1]; let nz = P[2]; let layer = P[5]; let lev = P[6];
  if (g.z == 0u) {
    let i = g.x; let j = g.y;
    if (i >= nx || j >= ny) { return; }
    var v: f32;
    if (P[7] != 0u) {
      v = -1e9;
      for (var k = 0u; k < nz; k++) { v = max(v, value(layer, i, j, k)); }
    } else {
      v = value(layer, i, j, lev);
    }
    O[j * nx + i] = v;
  } else if (g.z == 1u) {
    let s = g.x; let k = g.y;
    if (s >= P[8] || k >= nz) { return; }
    let p = S[s];
    let i0 = u32(clamp(floor(p.x), 0.0, f32(nx - 1u))); let j0 = u32(clamp(floor(p.y), 0.0, f32(ny - 1u)));
    let i1 = min(i0 + 1u, nx - 1u); let j1 = min(j0 + 1u, ny - 1u);
    let tx = clamp(p.x - f32(i0), 0.0, 1.0); let ty = clamp(p.y - f32(j0), 0.0, 1.0);
    let a = mix(value(layer, i0, j0, k), value(layer, i1, j0, k), tx);
    let b = mix(value(layer, i0, j1, k), value(layer, i1, j1, k), tx);
    O[nx * ny + k * P[8] + s] = mix(a, b, ty);
    // ветер в плоскости разреза: вдоль линии (направление P[22], P[23]) и w
    let ua = mix(value(7u, i0, j0, k), value(7u, i1, j0, k), tx);
    let ub = mix(value(7u, i0, j1, k), value(7u, i1, j1, k), tx);
    let va = mix(value(8u, i0, j0, k), value(8u, i1, j0, k), tx);
    let vb = mix(value(8u, i0, j1, k), value(8u, i1, j1, k), tx);
    let wa = mix(value(1u, i0, j0, k), value(1u, i1, j0, k), tx);
    let wb = mix(value(1u, i0, j1, k), value(1u, i1, j1, k), tx);
    let o = nx * ny + nz * P[8] + 2u * nx * ny + 2u * (k * P[8] + s);
    O[o] = mix(ua, ub, ty) * bitcast<f32>(P[22]) + mix(va, vb, ty) * bitcast<f32>(P[23]);
    O[o + 1u] = mix(wa, wb, ty);
  } else {
    let i = g.x; let j = g.y;
    if (i >= nx || j >= ny) { return; }
    let o = nx * ny + nz * P[8] + 2u * (j * nx + i);
    O[o] = 0.5 * (f(P[14], i, j, lev) + f(P[14], i + 1u, j, lev));
    O[o + 1u] = 0.5 * (f(P[15], i, j, lev) + f(P[15], i, j + 1u, lev));
  }
}`;

// ---- сетка: физические координаты (м) от угла области
let XF, YF, XH, YH, ZH, ZF, Lx, Ly, Ztop;
function setupGeo() {
  const x0 = gi.x.xf[0], y0 = gi.y.xf[0];
  XF = gi.x.xf.map(v => v - x0); YF = gi.y.xf.map(v => v - y0);
  XH = gi.x.xh.map(v => v - x0); YH = gi.y.xh.map(v => v - y0);
  ZH = gi.zh; ZF = gi.zf;
  Lx = XF[XF.length - 1]; Ly = YF[YF.length - 1]; Ztop = ZF[ZF.length - 1];
}
// ячейка, в которой лежит x (по граням)
function cellOf(F, x) {
  let lo = 0, hi = F.length - 2;
  while (lo < hi) { const m = (lo + hi + 1) >> 1; if (F[m] <= x) lo = m; else hi = m - 1; }
  return lo;
}
// дробный индекс по центрам
function fracIdx(H, x) {
  if (x <= H[0]) return 0;
  if (x >= H[H.length - 1]) return H.length - 1;
  let lo = 0, hi = H.length - 1;
  while (hi - lo > 1) { const m = (lo + hi) >> 1; if (H[m] <= x) lo = m; else hi = m; }
  return lo + (x - H[lo]) / (H[hi] - H[lo]);
}
const km = v => (v / 1000).toFixed(v < 10000 ? 1 : 0).replace(/\.0$/, '');

// ---- свой пресет: сценарий и шаг собираются в браузере (web/core), без записи эталона
let live = null;
async function buildLive(rec) {
  const v = '?v=' + Date.now();
  const C = await import('./core/config.js' + v);
  const { buildRun } = await import('./core/driver.js' + v);
  const conf = C.ConfigParser.parseText(rec.text);
  const isnd = conf.int('isnd') ?? 5;
  const snd = rec.sounding && (isnd === 7 || isnd === 17) ? C.parseSounding(rec.sounding, { windsFromFile: isnd === 7, moist: (conf.int('imoist') ?? 1) !== 0 })
    : await C.loadSounding(rec.base, conf, f => get('../data/presets/' + f).then(r => r.ok ? r.text() : null));
  if ((conf.int('radopt') ?? 0) === 2) {
    const R = await import('./core/radiation.js' + v);
    await R.loadRRTMG(n => get('../data/rrtmg/' + n).then(r => r.arrayBuffer()));
  }
  const run = buildRun(conf, snd);
  // adapt_dt=1: первая лента - только устойчивость начального состояния
  const first = run.adaptive ? run.adaptive.encodeInitial() : run.encodeStep();
  for (const b of run.ctx.device.all) run.ctx.rec.id(b);   // номера и тем буферам, что понадобятся позже
  return { run, conf, first, used: false };
}
function gridInfo(sc) {
  const h = 3, inner = g => ({ xh: g.xh.slice(h, h + g.n), xf: g.xf.slice(h, h + g.n + 1) });
  return { x: inner(sc.grid.hx), y: inner(sc.grid.hy), zh: sc.vertical.zh, zf: sc.vertical.zf, dt: sc.dt, move: [sc.umove, sc.vmove] };
}
let kdir = '../data/kernels/';

async function init() {
  if (!navigator.gpu) { post('WebGPU недоступен в этом браузере'); return; }
  post('загрузка');
  index = await (await get('../data/index.json')).json();
  const P = await import('./presets.js?v=' + Date.now());
  // ?cfg=путь[&base=пресет] - конфиг из файла (проверка своих пресетов без localStorage)
  // встроенный пресет без ленты (live в index.json) - собирается в браузере, как свой
  const liveEntry = !q.get('u') && !q.get('cfg') ? index.find(s => s.name === q.get('s') && s.live) : null;
  const own = liveEntry ? { id: liveEntry.name, builtin: true, base: liveEntry.name, title: liveEntry.title,
      text: await (await get(`../data/presets/${liveEntry.name}.json`)).text(), sounding: null }
    : q.get('u') ? P.getPreset(q.get('u'))
    : q.get('cfg') ? { id: 'cfg', base: q.get('base') || 'supercell', title: q.get('cfg').split('/').pop(),
      text: await (await get(q.get('cfg'))).text(), sounding: q.get('snd') ? await (await get(q.get('snd'))).text() : null } : null;
  let sources = {}, kernels;
  if (own) {
    ownRec = own;
    post('сборка сценария');
    live = await buildLive(own);
    const sc = live.run.sc;
    scen = { name: own.builtin ? own.id : 'u:' + own.id, title: own.title, summary: own.builtin ? liveEntry.summary : 'свой пресет',
      timax: live.conf.double('timax') ?? 7200, move: [sc.umove, sc.vmove], own: true, builtin: !!own.builtin };
    tape = live.run.tape([live.first]);
    gi = gridInfo(sc);
    const c = tape.constants;
    // набор ядер по константам сборки: kernels[_tc4|_tc5][_terrain|_axisymmetric|_warmOnly]
    const flags = [c.testcase ? 'tc' + c.testcase : null, c.terrain ? 'terrain' : null, c.axisymmetric ? 'axisymmetric' : null,
      c.warmOnly ? 'warmOnly' : null].filter(Boolean);
    if (!c.thermoDefault && !c.testcase) throw new Error('нестандартные термодинамические константы вне testcase 4/5 в браузере не идут');
    kdir = '../data/kernels' + flags.map(x => '_' + x).join('') + '/';
    const kres = await get(kdir + 'kernels.json');
    if (!kres.ok) throw new Error('нет набора ядер для сочетания ' + flags.join(' + '));
    kernels = await kres.json();
    // все ядра: структура шага может смениться (излучение раз в dtrad)
    await Promise.all(Object.keys(kernels).map(async n => { sources[n] = await (await get(kdir + n + '.wgsl')).text(); }));
  } else {
    scen = index.find(s => s.name === q.get('s') && !s.off) || index.find(s => s.name === 'supercell');
    const base = '../data/' + scen.name + '/';
    [tape, gi] = await Promise.all([get(base + 'tape.json').then(x => x.json()), get(base + 'grid.json').then(x => x.json())]);
    kernels = await (await get(kdir + 'kernels.json')).json();
    const names = [...new Set([...tape.steps[0], ...(tape.diag || [])].filter(c => c.op === 'pipe').map(c => c.name))];
    await Promise.all(names.map(async n => { sources[n] = await (await get(kdir + n + '.wgsl')).text(); }));
  }
  fillScenarios(P.listPresets());
  setupGeo();
  const adapter = await navigator.gpu.requestAdapter();
  // WebGPU объявлен, но видеокарта не выдана (Android вне Chrome 121+/Android 12+, чёрный список драйверов)
  if (!adapter) { post('браузер не дал доступ к видеокарте (WebGPU): на Android откройте сайт в Chrome, на компьютере - в Chrome, Edge или Safari'); return; }
  device = await adapter.requestDevice({ requiredLimits: {
    maxStorageBufferBindingSize: adapter.limits.maxStorageBufferBindingSize, maxBufferSize: adapter.limits.maxBufferSize, maxStorageBuffersPerShaderStage: adapter.limits.maxStorageBuffersPerShaderStage } });
  device.addEventListener('uncapturederror', e => dbg('ОШИБКА GPU ' + e.error.message));
  device.lost.then(i => post('видеокарта отключила страницу: ' + (i.message || i.reason)));
  r = new Replayer(device, tape, kernels, sources);
  r.plan(true);
  post('сборка ядер');
  await r.build();
  post('загрузка состояния');
  if (live) {
    // арена - без копии: после загрузки она освобождается (releaseArena)
    pre = live.run.ctx.rec.buffers.map(b => b === live.run.arena.buffer ? b.u8 : b.u8.slice());
    live.up = pre.map(x => x);
    const g = live.run.sc.grid;
    grid = { nx: g.nx, ny: g.ny, nz: g.nz, sJ: g.strideJ, sK: g.strideK };
  } else {
    pre = await Promise.all(tape.buffers.map(b => gunzip(`../data/${scen.name}/state/${b.id}.bin.gz`)));
    for (const c of tape.steps[0]) if (c.op === 'bytes') {
      const b = Uint8Array.from(atob(c.data), ch => ch.charCodeAt(0));
      if (b.length === 32) { const v = new Int32Array(b.buffer, 0, 5); if (v[0] === tape.nx && v[1] === tape.ny) { grid = { nx: v[0], ny: v[1], nz: v[2], sJ: v[3], sK: v[4] }; break; } }
    }
  }
  await reset(true);
  if (live) await releaseLive();
  st.level = Math.min(grid.nz - 1, ZH.findIndex(z => z >= 1000));
  $('level').max = grid.nz - 1; $('level').value = st.level;

  // координаты на GPU: xh, yh, zh, zf
  const coords = new Float32Array([...XH, ...YH, ...ZH, ...ZF]);
  X = device.createBuffer({ size: coords.byteLength, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST });
  device.queue.writeBuffer(X, 0, coords);
  const geo = { X, ox: 0, oy: grid.nx, ozh: grid.nx + grid.ny, ozf: grid.nx + grid.ny + grid.nz, Lx, Ly, top: Ztop };
  D = device.createBuffer({ size: tape.fieldStride, usage: GPUBufferUsage.STORAGE });

  const arena = tape.buffers.find(b => b.arena).id;
  const fw = n => r.base[arena] + tape.fields[n] / 4;
  viewParams = new Uint32Array(24);
  viewParams.set([grid.nx, grid.ny, grid.nz, grid.sJ, grid.sK, 0, 0, 0, NS,
    fw('dbz'), fw('w'), fw('qc'), fw('qi'), fw('th'), fw('u'), fw('v'), 0, grid.nx]);
  const pbuf = device.createBuffer({ size: viewParams.byteLength, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST });
  viewParams.buf = pbuf;
  device.queue.writeBuffer(pbuf, 0, viewParams);
  samples = device.createBuffer({ size: NS * 8, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST });
  const words = grid.nx * grid.ny + grid.nz * NS + 2 * grid.nx * grid.ny + 2 * grid.nz * NS;
  viewOut = device.createBuffer({ size: words * 4, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC });
  viewRead = device.createBuffer({ size: words * 4, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST });
  viewPipe = await device.createComputePipelineAsync({ layout: 'auto', compute: { module: device.createShaderModule({ code: r.wgsl(VIEW_WGSL) }), entryPoint: 'main' } });
  derivePipe = await device.createComputePipelineAsync({ layout: 'auto', compute: { module: device.createShaderModule({ code: r.wgsl(DERIVE_WGSL) }), entryPoint: 'main' } });
  bindView();
  setLine(0, Ly / 2, Lx, Ly / 2);
  st.radar = [Lx * 0.3, Ly * 0.3];
  st.move = scen.move || [0, 0];
  vol = new Volume(device, r, tape, grid, $('vol'), geo, D);
  await vol.init();
  await tlSetup();
  window.__te = { vol, tl, r, st, get vp() { return viewParams; }, get plan() { return plan; } };   // для проверок (web/test)
  wire();
  loop();
}

// привязки показа к памяти модели (M может вырасти - тогда заново)
let boundMem = null;
function bindView() {
  boundMem = r.mem;
  const pbuf = viewParams.buf;
  const src = tl.view != null ? tlSource(tl.view) : null;
  const mem = src ? src.entries : r.memEntries(0);
  const arena = tape.buffers.find(b => b.arena).id;
  const fw = src ? src.fw : n => r.base[arena] + tape.fields[n] / 4;
  ['dbz', 'w', 'qc', 'qi', 'th', 'u', 'v'].forEach((n, i) => { viewParams[9 + i] = tape.fields[n] !== undefined ? fw(n) : 0; });
  device.queue.writeBuffer(pbuf, 0, viewParams);
  vol?.setSource(src);
  viewBind = device.createBindGroup({ layout: viewPipe.getBindGroupLayout(0), entries: [
    ...mem, { binding: 1, resource: { buffer: pbuf } }, { binding: 2, resource: { buffer: D } },
    { binding: 3, resource: { buffer: samples } }, { binding: 4, resource: { buffer: viewOut } },
    { binding: 5, resource: { buffer: X } }] });
  deriveBind = device.createBindGroup({ layout: derivePipe.getBindGroupLayout(0), entries: [
    ...mem, { binding: 1, resource: { buffer: pbuf } },
    { binding: 2, resource: { buffer: X } }, { binding: 3, resource: { buffer: D } }] });
  if (vol && !src) vol.dropSurfaces();
}

async function reset(initial = false) {
  if (live && !initial) {
    // шаг помнит своё время: свой пресет собирается заново
    live = await buildLive(P_own());
    pre = live.run.ctx.rec.buffers.map(b => b === live.run.arena.buffer ? b.u8 : b.u8.slice());
    live.up = pre.map(x => x);
  }
  for (const [i, b] of tape.buffers.entries()) await r.uploadAsync(b.id, pre[i]);
  if (live && !initial) await releaseLive();
  st.steps = 0; st.msPerStep = 0; st.lineAuto = true;
  if (tl.buf) { tl.times = []; tl.head = 0; tl.next = 0; tl.srcs = new Map(); if (tl.view != null) { tl.view = null; bindView(); } tlUI(); }
  st.dirty = true;
}
// копия арены на процессоре после загрузки не нужна: освободить (и все ссылки на неё)
async function releaseLive() {
  await device.queue.onSubmittedWorkDone();
  const id = live.run.ctx.rec.buffers.indexOf(live.run.arena.buffer);
  live.run.releaseArena();
  if (id >= 0) live.up[id] = null;
  pre = null;
}
// с перемотки - обратно к памяти модели
function tlLive() { if (tl.view == null) return; tl.view = null; bindView(); tlUI(); }
let ownRec = null;
const P_own = () => ownRec;

// следующий шаг своего пресета: команды из TimeStep и догрузка буферов,
// которые шаг поменял на процессоре (при общей памяти они общие с GPU)
async function liveStep() {
  const ad = live.run.adaptive;
  if (ad && !live.started) {
    // t=0: cflmax/ksmax начального состояния -> dt первого шага
    await r.useStep(live.first);
    if (r.mem !== boundMem) bindView();
    const e0 = device.createCommandEncoder();
    r.encodeSteps(e0, 1, false);
    device.queue.submit([e0.finish()]);
    ad.start(await readStability(ad));
    live.started = true; live.used = true;
  }
  if (ad) ad.clock.beginStep();
  const cmds = live.used ? live.run.encodeStep() : live.first;
  live.used = true;
  const bufs = live.run.ctx.rec.buffers, arena = live.run.arena.buffer;
  for (let id = 0; id < bufs.length; id++) {
    const b = bufs[id];
    if (b === arena) continue;
    const old = live.up[id];
    if (!old) { r.upload(id, b.u8); live.up[id] = b.u8.slice(); continue; }
    let same = old.length === b.u8.length;
    for (let i = 0; same && i < old.length; i++) if (old[i] !== b.u8[i]) same = false;
    if (!same) { r.upload(id, b.u8); live.up[id] = b.u8.slice(); }
  }
  await r.useStep(cmds);
  if (r.mem !== boundMem) bindView();
}

// 8 байт буфера stability после шага; обнуление на следующий (TimeStep.readStability)
async function readStability(ad) {
  const w = await r.read(2, r.base[ad.stabilityId]);
  r.writeWords(r.base[ad.stabilityId], new Uint32Array(2));
  return w;
}
const modelTime = () => live?.run.adaptive ? live.run.adaptive.clock.mtime : st.steps * tape.dt;
const stepDt = () => live?.run.adaptive ? live.run.adaptive.clock.dt : tape.dt;

// линия разреза в метрах; точки отбора - дробные индексы центров
function setLine(ax, ay, bx, by) {
  st.line = { ax, ay, bx, by };
  // направление линии для ветра вдоль разреза
  const len = Math.hypot(bx - ax, by - ay) || 1, pf = new Float32Array(viewParams.buffer);
  pf[22] = (bx - ax) / len; pf[23] = (by - ay) / len;
  const s = new Float32Array(NS * 2);
  for (let n = 0; n < NS; n++) {
    const t = n / (NS - 1);
    s[2 * n] = fracIdx(XH, ax + (bx - ax) * t);
    s[2 * n + 1] = fracIdx(YH, ay + (by - ay) * t);
  }
  device.queue.writeBuffer(samples, 0, s);
}

// Кадр: n шагов модели, отражаемость, поля для показа.
async function frame() {
  if (tl.view != null && st.perFrame) tlLive();
  const left = live?.run.adaptive ? (modelTime() < scen.timax - 1e-6 ? Infinity : 0)
    : Math.max(0, Math.round(scen.timax / tape.dt) - st.steps);
  let n = Math.min(st.perFrame, left);
  // кадр кончается на моменте снимка шкалы времени (ровно раз в tl.every)
  // снимок на t = 0 и любой просроченный - сначала, кадром без шагов
  if (n && tl.buf && tl.view == null && modelTime() >= tl.next - 1e-6) n = 0;
  else if (n && tl.buf && !live?.run.adaptive) n = Math.min(n, Math.max(1, Math.ceil((tl.next - st.steps * tape.dt) / tape.dt - 1e-9)));
  if (!left && st.perFrame) { setSpeed(0); }
  const layer = st.mode === '3d' ? 0 : st.layer;
  const L = LAYERS[layer];
  const composite = st.mode === '3d' || L.level === false || (L.level === 'opt' && st.composite);
  viewParams[5] = layer; viewParams[6] = st.level; viewParams[7] = composite ? 1 : 0;
  const pf = new Float32Array(viewParams.buffer);
  pf[18] = st.radar[0]; pf[19] = st.radar[1]; pf[20] = st.move[0]; pf[21] = st.move[1];
  device.queue.writeBuffer(viewParams.buf, 0, viewParams);
  const tf = performance.now();
  let done = n;
  if (live) {
    const ad = live.run.adaptive;
    for (let k = 0; k < n; k++) {
      if (ad && k && (modelTime() >= scen.timax - 1e-6 || modelTime() >= tl.next - 1e-6)) { done = k; break; }
      await liveStep();
      const e1 = device.createCommandEncoder();
      r.encodeSteps(e1, 1, false);
      device.queue.submit([e1.finish()]);
      if (ad) ad.endStep(await readStability(ad));
    }
  }
  const enc = device.createCommandEncoder();
  if (n && !live) r.encodeSteps(enc, n, false);
  // время нового состояния: счётчик шагов растёт после кадра
  if (tl.view == null) { r.encodeDiag(enc); if (tlCapture(enc, live?.run.adaptive ? modelTime() : (st.steps + done) * tape.dt)) tlUI(); }
  if ((st.mode === '2d' && layer === 2) || (st.mode === '3d' && vol.needsZeta)) {
    const p = enc.beginComputePass();
    p.setPipeline(derivePipe); p.setBindGroup(0, deriveBind);
    p.dispatchWorkgroups(Math.ceil(grid.nx / 4), Math.ceil(grid.ny / 4), Math.ceil(grid.nz / 4));
    p.end();
  }
  if (st.mode === '3d') vol.encodeBuild(enc);
  const pass = enc.beginComputePass();
  pass.setPipeline(viewPipe); pass.setBindGroup(0, viewBind);
  pass.dispatchWorkgroups(Math.ceil(Math.max(grid.nx, NS) / 8), Math.ceil(Math.max(grid.ny, grid.nz) / 8), 3);
  pass.end();
  enc.copyBufferToBuffer(viewOut, 0, viewRead, 0, viewRead.size);
  const t0 = performance.now();
  device.queue.submit([enc.finish()]);
  await viewRead.mapAsync(GPUMapMode.READ);
  const dt = performance.now() - (live ? tf : t0);
  const all = new Float32Array(viewRead.getMappedRange().slice(0));
  viewRead.unmap();
  if (done) { st.steps += done; st.msPerStep = st.msPerStep ? st.msPerStep * 0.8 + 0.2 * dt / done : dt / done; }
  plan = all.subarray(0, grid.nx * grid.ny);
  cross = all.subarray(grid.nx * grid.ny, grid.nx * grid.ny + grid.nz * NS);
  wind = all.subarray(grid.nx * grid.ny + grid.nz * NS, grid.nx * grid.ny + grid.nz * NS + 2 * grid.nx * grid.ny);
  secWind = all.subarray(grid.nx * grid.ny + grid.nz * NS + 2 * grid.nx * grid.ny);
  if (st.mode === '3d') {
    vol.setPlane(resample(plan, LAYERS[0], PLANE, PLANE, true));
    drawVol();
  } else {
    if (st.lineAuto && layer === 0) autoLine();
    draw();
  }
  hudTime();
  kv();
}

// пока линию не трогали - через самое сильное эхо, вдоль длинной стороны
function autoLine() {
  let best = 5, bi = -1, bj = -1;
  for (let j = 0; j < grid.ny; j++) for (let i = 0; i < grid.nx; i++) if (plan[j * grid.nx + i] > best) { best = plan[j * grid.nx + i]; bi = i; bj = j; }
  if (bi < 0) return;
  const l = st.line;
  if (Lx >= Ly) { if (Math.abs(l.ay - YH[bj]) > 1 || l.ay !== l.by) { setLine(0, YH[bj], Lx, YH[bj]); st.dirty = true; } }
  else if (Math.abs(l.ax - XH[bi]) > 1 || l.ax !== l.bx) { setLine(XH[bi], 0, XH[bi], Ly); st.dirty = true; }
}

// Цикл без таймеров: следующий кадр - сразу после ответа GPU; на паузе
// ждёт пинка от интерфейса (таймеры в фоновой вкладке душатся).
let kick = null;
function poke() { st.dirty = true; if (kick) { const k = kick; kick = null; k(); } }
async function loop() {
  for (;;) {
    if (!st.busy && (st.perFrame || st.dirty || st.once)) {
      st.busy = true; st.dirty = false;
      try { await frame(); } catch (e) { post('ошибка кадра: ' + (e?.message || e)); st.busy = false; return; }
      st.busy = false;
      if (st.once) { st.once = false; setSpeed(0); }
    } else {
      await new Promise(res => { kick = res; });
    }
  }
}

// ---- рисование
// карта на картинку w×h: пиксель -> точка области -> ячейка по граням
function resample(data, L, w, h, alpha) {
  const ci = new Int32Array(w), cj = new Int32Array(h);
  for (let x = 0; x < w; x++) ci[x] = cellOf(XF, (x + 0.5) / w * Lx);
  for (let y = 0; y < h; y++) cj[y] = cellOf(YF, (1 - (y + 0.5) / h) * Ly);
  const out = new Uint8ClampedArray(w * h * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const v = data[cj[y] * grid.nx + ci[x]], c = L.color(v), o = (y * w + x) * 4;
    out[o] = c[0]; out[o + 1] = c[1]; out[o + 2] = c[2]; out[o + 3] = alpha ? (v >= 5 ? 255 : 0) : 255;
  }
  return out;
}

function drawVol() {
  const panel = $('panel'), W = innerWidth, H = innerHeight, open = !panel.classList.contains('hidden');
  vol.free = W <= 640 ? [0, open ? panel.offsetHeight / H : 0] : [open ? panel.offsetWidth / W : 0, 0];
  vol.draw();
}

let geoPx = null;
function draw() {
  const dpr = devicePixelRatio || 1;
  const W = innerWidth, H = innerHeight;
  if (cv.width !== W * dpr || cv.height !== H * dpr) { cv.width = W * dpr; cv.height = H * dpr; }
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.fillStyle = '#0d1216'; ctx.fillRect(0, 0, W, H);
  const panel = $('panel'), mobile = W <= 640, open = !panel.classList.contains('hidden');
  const freeW = W - (open && !mobile ? panel.offsetWidth : 0) - 32;
  const freeH = H - (open && mobile ? panel.offsetHeight : 0) - 32 - 32;   // поля и строка времени
  // разрез: 0.4 ширины карты, у вытянутой области - не выше карты (но не ниже 0.2 ширины)
  const a = Ly / Lx, cr = Math.min(0.4, Math.max(a, 0.2)), gap = 16;
  const pw = Math.floor(Math.max(120, Math.min(freeW, (freeH - gap) / (a + cr))));
  const ph = Math.round(pw * a), ch = Math.round(pw * cr);
  const x0 = 16 + Math.floor((freeW - pw) / 2), y0 = 16 + Math.max(0, Math.floor((freeH - ph - gap - ch) / 2));
  const yc = y0 + ph + gap;
  geoPx = { x0, y0, pw, ph };
  const L = LAYERS[st.layer];
  const pwd = Math.round(pw * dpr), phd = Math.max(1, Math.round(ph * dpr));
  putImage(resample(plan, L, pwd, phd, false), pwd, phd, x0, y0, pw, ph);
  drawCross(L, x0, yc, pw, ch, dpr);
  ctx.strokeStyle = 'rgba(255,255,255,.18)'; ctx.lineWidth = 1;
  ctx.strokeRect(x0 + 0.5, y0 + 0.5, pw - 1, ph - 1);
  ctx.strokeRect(x0 + 0.5, yc + 0.5, pw - 1, ch - 1);
  if (st.arrows) { drawArrows(x0, y0, pw, ph); drawSectionArrows(x0, yc, pw, ch); }
  // линия разреза
  const P = (x, y) => [x0 + x / Lx * pw, y0 + ph - y / Ly * ph];
  const [ax, ay] = P(st.line.ax, st.line.ay), [bx, by] = P(st.line.bx, st.line.by);
  ctx.strokeStyle = 'rgba(255,255,255,.7)'; ctx.setLineDash([4, 4]);
  ctx.beginPath(); ctx.moveTo(ax, ay); ctx.lineTo(bx, by); ctx.stroke(); ctx.setLineDash([]);
  ctx.fillStyle = 'rgba(255,255,255,.85)';
  ctx.beginPath(); ctx.arc(ax, ay, 3, 0, 7); ctx.fill();
  ctx.beginPath(); ctx.arc(bx, by, 3, 0, 7); ctx.fill();
  if (L.radar) {
    const [rx, ry] = P(st.radar[0], st.radar[1]);
    ctx.strokeStyle = 'rgba(255,255,255,.9)'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.arc(rx, ry, 5, 0, 7); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(rx - 9, ry); ctx.lineTo(rx + 9, ry); ctx.moveTo(rx, ry - 9); ctx.lineTo(rx, ry + 9); ctx.stroke();
    ctx.lineWidth = 1;
  }
  // уровень среза (или стрелок на карте) на разрезе
  if (!composite2d() || st.arrows) {
    const yl = yc + ch - ZH[st.level] / Ztop * ch;
    ctx.strokeStyle = 'rgba(255,255,255,.35)'; ctx.beginPath(); ctx.moveTo(x0, yl); ctx.lineTo(x0 + pw, yl); ctx.stroke();
  }
  // подписи осей: длина области и высота
  ctx.fillStyle = 'rgba(207,213,220,.8)'; ctx.font = '11px ui-monospace, Menlo, monospace'; ctx.textBaseline = 'top';
  ctx.textAlign = 'right'; ctx.fillText(T(`${km(Lx)} км`), x0 + pw, y0 + ph + 2);
  ctx.textAlign = 'left'; ctx.fillText(T(`${km(Ztop)} км`), x0 + 4, yc + 4);
}
const composite2d = () => { const L = LAYERS[st.layer]; return L.level === false || (L.level === 'opt' && st.composite); };

const off = document.createElement('canvas'), octx = off.getContext('2d');
function putImage(rgba, w, h, x, y, dw, dh) {
  off.width = w; off.height = h;
  octx.putImageData(new ImageData(rgba, w, h), 0, 0);
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(off, x, y, dw, dh);
}

// разрез: по горизонтали - точки линии, по вертикали - высота (уровни по граням)
function drawCross(L, x, y, w, h, dpr) {
  const wd = Math.max(1, Math.round(w * dpr)), hd = Math.max(1, Math.round(h * dpr));
  const ks = new Int32Array(hd), ss = new Int32Array(wd);
  for (let r = 0; r < hd; r++) ks[r] = cellOf(ZF, (1 - (r + 0.5) / hd) * Ztop);
  for (let c = 0; c < wd; c++) ss[c] = Math.min(NS - 1, Math.round((c + 0.5) / wd * (NS - 1)));
  const out = new Uint8ClampedArray(wd * hd * 4);
  for (let r = 0; r < hd; r++) for (let c = 0; c < wd; c++) {
    const col = L.color(cross[ks[r] * NS + ss[c]]), o = (r * wd + c) * 4;
    out[o] = col[0]; out[o + 1] = col[1]; out[o + 2] = col[2]; out[o + 3] = 255;
  }
  putImage(out, wd, hd, x, y, w, h);
}

// стрелки ветра на уровне среза, через ~28 пикселей; 20 м/с = 24 пикселя
function drawArrows(x0, y0, pw, ph) {
  const step = 28, n = Math.max(2, Math.floor(pw / step)), m = Math.max(2, Math.floor(ph / step));
  ctx.strokeStyle = 'rgba(255,255,255,.75)'; ctx.lineWidth = 1.2;
  for (let b = 0; b < m; b++) for (let a = 0; a < n; a++) {
    const px = x0 + (a + 0.5) * pw / n, py = y0 + (b + 0.5) * ph / m;
    const i = cellOf(XF, (px - x0) / pw * Lx), j = cellOf(YF, (1 - (py - y0) / ph) * Ly);
    const u = wind[2 * (j * grid.nx + i)], v = wind[2 * (j * grid.nx + i) + 1];
    const s = 24 / 20, dx = u * s, dy = -v * s, len = Math.hypot(dx, dy);
    if (!(len > 1)) continue;
    const ex = px + dx / 2, ey = py + dy / 2, sx = px - dx / 2, sy = py - dy / 2;
    const ux = dx / len, uy = dy / len;
    ctx.beginPath(); ctx.moveTo(sx, sy); ctx.lineTo(ex, ey);
    ctx.lineTo(ex - 5 * ux - 3 * uy, ey - 5 * uy + 3 * ux); ctx.moveTo(ex, ey);
    ctx.lineTo(ex - 5 * ux + 3 * uy, ey - 5 * uy - 3 * ux); ctx.stroke();
  }
}

// стрелки на разрезе: ветер вдоль линии (вправо - от начала к концу) и w;
// тот же масштаб, что на карте (20 м/с = 24 пикселя) по обеим осям
function drawSectionArrows(x0, y0, pw, ph) {
  const step = 28, n = Math.max(2, Math.floor(pw / step)), m = Math.max(2, Math.floor(ph / step));
  ctx.strokeStyle = 'rgba(255,255,255,.75)'; ctx.lineWidth = 1.2;
  for (let b = 0; b < m; b++) for (let a = 0; a < n; a++) {
    const px = x0 + (a + 0.5) * pw / n, py = y0 + (b + 0.5) * ph / m;
    const sI = Math.min(NS - 1, Math.round((px - x0) / pw * (NS - 1))), k = cellOf(ZF, (1 - (py - y0) / ph) * Ztop);
    const o = 2 * (k * NS + sI), u = secWind[o], w = secWind[o + 1];
    const sc = 24 / 20, dx = u * sc, dy = -w * sc, len = Math.hypot(dx, dy);
    if (!(len > 1)) continue;
    const ex = px + dx / 2, ey = py + dy / 2, sx = px - dx / 2, sy = py - dy / 2;
    const ux = dx / len, uy = dy / len;
    ctx.beginPath(); ctx.moveTo(sx, sy); ctx.lineTo(ex, ey);
    ctx.lineTo(ex - 5 * ux - 3 * uy, ey - 5 * uy + 3 * ux); ctx.moveTo(ex, ey);
    ctx.lineTo(ex - 5 * ux + 3 * uy, ey - 5 * uy - 3 * ux); ctx.stroke();
  }
}

const clock = t => `${String(Math.floor(t / 3600)).padStart(2, '0')}:${String(Math.floor(t / 60) % 60).padStart(2, '0')}`;
function hudTime() {
  const t = tl.view != null ? tl.times[tl.view] : modelTime();
  hud.textContent = `t ${clock(t)}:${String(Math.floor(t % 60)).padStart(2, '0')}   ${st.msPerStep ? st.msPerStep.toFixed(0) + ' мс/шаг' : ''}`;
}

function legend() {
  const c = $('legend'), dpr = devicePixelRatio || 1, w = c.clientWidth, h = 36;
  if (!w) return;
  c.width = w * dpr; c.height = h * dpr;
  const g = c.getContext('2d'); g.setTransform(dpr, 0, 0, dpr, 0, 0);
  const L = LAYERS[st.layer];
  for (let x = 0; x < w; x++) {
    const v = L.lo + (L.hi - L.lo) * x / (w - 1);
    const col = L.color(v); g.fillStyle = `rgb(${col})`; g.fillRect(x, 8, 1, 12);
  }
  const cs = getComputedStyle(document.body);
  g.fillStyle = cs.getPropertyValue('--muted') || '#5c6370';
  g.font = '11px ' + cs.getPropertyValue('--mono');
  g.textBaseline = 'top';
  g.textAlign = 'left'; g.fillText(String(L.lo), 0, 24);
  g.textAlign = 'center'; g.fillText(T(L.unit), w / 2, 24);
  g.textAlign = 'right'; g.fillText(String(L.hi), w, 24);
}

function spacing(F) {
  const d = F.slice(1).map((v, i) => v - F[i]);
  const lo = Math.min(...d), hi = Math.max(...d);
  const f = v => v >= 1000 ? `${+(v / 1000).toFixed(2)} км` : `${Math.round(v)} м`;
  return Math.abs(hi - lo) < 1 ? f(lo) : `${f(lo)}–${f(hi)}`;
}
function kv() {
  const t = modelTime();
  const rows = [
    ['Время модели', `${clock(t)} из ${clock(scen.timax)}`],
    ['Шагов', String(st.steps)],
    ['Сетка', `${grid.nx}×${grid.ny}×${grid.nz}`],
    ['Область', `${km(Lx)}×${km(Ly)}×${km(Ztop)} км`],
    ['Шаг по x', spacing(XF)],
    ['Шаг по z', spacing(ZF)],
    ['dt', live?.run.adaptive ? `${+stepDt().toFixed(3)} с, переменный` : `${tape.dt} с`],
  ];
  let html = rows.map(([k, v]) => `<tr><td>${k}</td><td>${v}</td></tr>`).join('');
  if (st.verify) html += `<tr><td>Сверка с эталоном</td><td class="${st.verifyOk ? 'ok' : 'bad'}">${st.verify}</td></tr>`;
  $('kv').innerHTML = html;
}

function fillScenarios(own = []) {
  const sel = $('scen');
  const opt = (v, t, dis, on) => `<option value="${v}" ${dis ? 'disabled' : ''} ${on ? 'selected' : ''}>${t}</option>`;
  sel.innerHTML = (own.length ? `<optgroup label="Свои">${own.map(p => opt('u:' + p.id, esc(p.title), false, scen.name === 'u:' + p.id)).join('')}</optgroup>` : '')
    + `<optgroup label="Встроенные">${index.map(s => opt(s.name, s.title + (s.off ? ' (не идёт в браузере)' : ''), s.off, s.name === scen.name)).join('')}</optgroup>`
    + `<optgroup label="Ещё">${opt('editor', 'Свой пресет…', false, false)}</optgroup>`;
  $('summary').textContent = scen.summary || '';
  $('verify').hidden = !!scen.own;
  sel.onchange = () => {
    if (sel.value === 'editor') { location.href = 'editor.html' + (scen.own && !scen.builtin ? '?u=' + scen.name.slice(2) : '?s=' + scen.name); return; }
    const u = new URL(location.href);
    u.searchParams.delete('s'); u.searchParams.delete('u');
    if (sel.value.startsWith('u:')) u.searchParams.set('u', sel.value.slice(2)); else u.searchParams.set('s', sel.value);
    u.searchParams.set('mode', st.mode); u.searchParams.set('layer', st.layer);
    location.href = u.toString();
  };
}
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

// ---- управление
let setSpeed;
function wire() {
  const panel = $('panel'), tog = $('toggle');
  tog.onclick = () => { panel.classList.toggle('hidden'); tog.classList.toggle('closed'); $('hud').classList.toggle('low');
    setTimeout(poke, 260); };
  $('layer').innerHTML = LAYERS.map((L, i) => `<option value="${i}">${L.name}</option>`).join('');
  $('layer').value = st.layer;
  const lv = () => { $('levelv').textContent = `${km(ZH[st.level])} км`; };
  const shown = () => {
    const L = LAYERS[st.layer], is2d = st.mode === '2d';
    $('compRow').hidden = !(is2d && L.level === 'opt');
    $('levelGrp').hidden = !(is2d && (L.level === true || L.level === 'opt' || st.arrows));
    // сумма по столбцу (облака): срез по высоте не бывает, ползунок двигает только стрелки
    $('levelCap').textContent = composite2d() ? 'Высота стрелок' : 'Высота среза';
    $('grp2d').hidden = !is2d; $('grp3d').hidden = is2d;
    $('view').hidden = !is2d; $('vol').hidden = is2d;
  };
  $('layer').onchange = e => { st.layer = +e.target.value; shown(); legend(); poke(); };
  $('composite').checked = st.composite;
  $('composite').onchange = e => { st.composite = e.target.checked; shown(); poke(); };
  $('arrows').checked = st.arrows;
  $('arrows').onchange = e => { st.arrows = e.target.checked; shown(); poke(); };
  $('level').oninput = e => {
    st.level = +e.target.value; lv();
    // ползунок двигает срез: с композита карта сама переходит на выбранную высоту
    if (LAYERS[st.layer].level === 'opt' && st.composite) { st.composite = false; $('composite').checked = false; shown(); }
    poke();
  };
  lv();
  const chips = [...$('speed').children];
  setSpeed = n => { st.perFrame = n; chips.forEach(x => x.classList.toggle('on', +x.dataset.n === n)); };
  chips.forEach(b => b.onclick = () => { setSpeed(+b.dataset.n); poke(); });
  setSpeed(q.has('speed') ? +q.get('speed') : 4);
  $('tl').oninput = e => {
    const slots = tlSlots(), k = +e.target.value;
    if (k >= slots.length - 1) { tlLive(); poke(); return; }
    setSpeed(0);
    tl.view = slots[k]; bindView(); tlUI(); poke();
  };
  $('stepOnce').onclick = () => { if (st.busy) return; setSpeed(1); st.once = true; poke(); };
  const modes = [...$('mode').children];
  const setMode = m => { st.mode = m; modes.forEach(x => x.classList.toggle('on', x.dataset.m === m)); shown(); poke(); };
  modes.forEach(b => b.onclick = () => setMode(b.dataset.m));
  modes.forEach(x => x.classList.toggle('on', x.dataset.m === st.mode));
  // поверхности: по группам, как в порте
  $('surfs').innerHTML = SURFACES.map(s => `<label><input type="checkbox" data-k="${s.key}" ${vol.on.has(s.key) ? 'checked' : ''}>${s.label}</label>`).join('');
  $('surfs').onchange = e => { const k = e.target.dataset.k; if (e.target.checked) vol.on.add(k); else vol.on.delete(k); poke(); };
  // вид: сверху (облёт) или с земли - из точки радара, взгляд на самое сильное эхо
  const cams = [...$('camMode').children];
  const setCam = c => {
    if (c === 'ground') {
      let bi = -1, best = -1e9;
      if (plan) for (let k = 0; k < plan.length; k++) if (plan[k] > best) { best = plan[k]; bi = k; }
      const tx = bi >= 0 ? XH[bi % grid.nx] : Lx / 2, ty = bi >= 0 ? YH[Math.floor(bi / grid.nx)] : Ly / 2;
      // из точки радара; ближе 30 км к ядру - отойти назад по той же линии (в пределах области)
      let [x, y] = st.radar;
      const dd = Math.hypot(tx - x, ty - y), want = Math.min(30000, 0.45 * Math.max(Lx, Ly));
      if (dd < want) {
        const ux = dd > 1 ? (x - tx) / dd : -0.7071, uy = dd > 1 ? (y - ty) / dd : -0.7071;
        x = Math.min(Lx, Math.max(0, tx + ux * want)); y = Math.min(Ly, Math.max(0, ty + uy * want));
      }
      // с земли - в истинном масштабе по вертикали
      if (!vol.ground) { vol.vsOrbit = vol.vs; vol.vs = 1; $('vscale').value = 1; $('vscalev').textContent = '×1'; }
      vol.ground = { x, y, az: Math.atan2(tx - x, ty - y), el: 0.15 };
    } else if (vol.ground) {
      vol.ground = null;
      vol.vs = vol.vsOrbit ?? 2; $('vscale').value = vol.vs; $('vscalev').textContent = '×' + vol.vs;
    }
    cams.forEach(b => b.classList.toggle('on', b.dataset.c === c));
    if (!st.perFrame) drawVol();
  };
  cams.forEach(b => b.onclick = () => setCam(b.dataset.c));
  cams[0].classList.add('on');
  if (q.get('cam') === 'ground') { const t = setInterval(() => { if (plan && Math.max(...plan) > 30) { clearInterval(t); setCam('ground'); } }, 500); }
  $('vscale').oninput = e => { vol.vs = +e.target.value; $('vscalev').textContent = '×' + vol.vs; poke(); };
  // пороги: логарифмические ползунки
  const logSlider = (id, lo, hi, init, fmt, apply) => {
    const el = $(id), out = $(id + 'v');
    const val = () => lo * Math.pow(hi / lo, +el.value / 100);
    el.value = Math.round(100 * Math.log(init / lo) / Math.log(hi / lo));
    out.textContent = fmt(init);
    el.oninput = () => { const v = val(); out.textContent = fmt(v); apply(v); poke(); };
  };
  logSlider('cloudThr', 0.01, 1, 0.1, v => `${v.toFixed(2)} г/кг`, v => vol.setIso('cloud', v / 1000));
  logSlider('tornThr', 0.03, 1, 0.1, v => `${v.toFixed(2)} 1/с`, v => vol.setIso('tornado', v));
  // вращение и приближение объёма
  const vc = $('vol');
  const pts = new Map();
  let drag = null, pinch = 0;
  const zoom = k => {
    if (vol.ground) {
      // с земли: колесо и щипок - шаг вперёд/назад по взгляду, в пределах области
      const g = vol.ground, d = Math.max(Lx, Ly) * 0.05 * Math.log(k);
      g.x = Math.min(Lx, Math.max(0, g.x - Math.sin(g.az) * d));
      g.y = Math.min(Ly, Math.max(0, g.y - Math.cos(g.az) * d));
    } else vol.cam.dist = Math.min(3, Math.max(0.15, vol.cam.dist * k));
    if (!st.perFrame) drawVol();
  };
  const spread = () => { const [a, b] = [...pts.values()]; return Math.hypot(a.x - b.x, a.y - b.y); };
  vc.addEventListener('pointerdown', e => {
    pts.set(e.pointerId, { x: e.clientX, y: e.clientY }); vc.setPointerCapture(e.pointerId);
    if (pts.size === 2) { drag = null; pinch = spread(); } else { drag = { x: e.clientX, y: e.clientY }; vc.style.cursor = 'grabbing'; }
  });
  vc.addEventListener('pointermove', e => {
    if (!pts.has(e.pointerId)) return;
    pts.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pts.size === 2) { const d = spread(); if (pinch > 0 && d > 0) zoom(pinch / d); pinch = d; return; }
    if (!drag) return;
    if (vol.ground) {
      // с земли: перетаскивание поворачивает взгляд
      vol.ground.az -= (e.clientX - drag.x) * 0.004;
      vol.ground.el = Math.min(1.4, Math.max(-0.2, vol.ground.el + (e.clientY - drag.y) * 0.004));
    } else {
      vol.cam.az -= (e.clientX - drag.x) * 0.006;
      vol.cam.el = Math.min(1.45, Math.max(0.02, vol.cam.el + (e.clientY - drag.y) * 0.006));
    }
    drag = { x: e.clientX, y: e.clientY };
    if (!st.perFrame) drawVol();
  });
  const up = e => { pts.delete(e.pointerId); pinch = 0; drag = null; vc.style.cursor = 'grab'; };
  vc.addEventListener('pointerup', up);
  vc.addEventListener('pointercancel', up);
  vc.addEventListener('wheel', e => { e.preventDefault(); zoom(Math.exp(e.deltaY * 0.001)); }, { passive: false });
  $('reset').onclick = async () => {
    const keep = st.perFrame; setSpeed(0);
    while (st.busy) await new Promise(r => setTimeout(r, 20));
    st.busy = true;
    try { await reset(); } catch (e) { post('ошибка: ' + (e?.message || e)); }
    st.busy = false; st.verify = ''; setSpeed(keep); poke();
  };
  $('verify').onclick = verify;
  // разрез: протянуть линию по карте; короткое нажатие - разрез вдоль длинной стороны через точку
  const toM = e => {
    const { x0, y0, pw, ph } = geoPx;
    return [Math.min(Lx, Math.max(0, (e.clientX - x0) / pw * Lx)), Math.min(Ly, Math.max(0, (1 - (e.clientY - y0) / ph) * Ly))];
  };
  let lineDrag = null;
  cv.addEventListener('pointerdown', e => {
    if (!geoPx) return;
    const { x0, y0, pw, ph } = geoPx;
    if (e.clientX < x0 || e.clientX > x0 + pw || e.clientY < y0 || e.clientY > y0 + ph) return;
    lineDrag = { sx: e.clientX, sy: e.clientY, a: toM(e) };
    cv.setPointerCapture(e.pointerId);
  });
  cv.addEventListener('pointermove', e => {
    if (!lineDrag || Math.hypot(e.clientX - lineDrag.sx, e.clientY - lineDrag.sy) < 6) return;
    const b = toM(e);
    st.lineAuto = false;
    setLine(lineDrag.a[0], lineDrag.a[1], b[0], b[1]);
    if (!st.perFrame) poke(); else draw();
  });
  cv.addEventListener('pointerup', e => {
    if (!lineDrag) return;
    if (Math.hypot(e.clientX - lineDrag.sx, e.clientY - lineDrag.sy) < 6) {
      const [x, y] = lineDrag.a;
      if (LAYERS[st.layer].radar) st.radar = [x, y];
      else {
        st.lineAuto = false;
        if (Lx >= Ly) setLine(0, y, Lx, y); else setLine(x, 0, x, Ly);
      }
    }
    lineDrag = null;
    poke();
  });
  addEventListener('resize', () => { legend(); poke(); });
  shown();
  legend();
  if (q.get('verify') === '1') verify().then(() => dbg('СВЕРКА ' + st.verify));
}

// Сверка: с исходного состояния один шаг с хэшами после каждого ядра.
async function verify() {
  const btn = $('verify'); btn.disabled = true;
  const keep = st.perFrame; setSpeed(0);
  while (st.busy) await new Promise(r => setTimeout(r, 20));
  st.busy = true;
  try {
    await reset();
    const enc = device.createCommandEncoder();
    r.encodeSteps(enc, 1, false);
    device.queue.submit([enc.finish()]);
    // итог шага - все буферы после него против записанных с эталона
    // (хэши после каждого ядра - в web/replay.html: черновые поля tend и fpk
    // там расходятся, на итог это не влияет)
    const want = await (await get(`../data/${scen.name}/step1.json`)).json();
    const mem = await r.read(r.buffersEnd);
    let bad = 0;
    for (const b of tape.buffers) if (fnv(mem.subarray(r.base[b.id], r.base[b.id] + b.length / 4)) !== want[b.id]) bad++;
    st.steps = 1;
    st.verifyOk = bad === 0;
    st.verify = bad === 0 ? `шаг 1 побитово, ${tape.buffers.length} буферов` : `разошлось буферов: ${bad}`;
  } catch (e) { st.verifyOk = false; st.verify = 'ошибка: ' + e.message; }
  st.busy = false; setSpeed(keep); btn.disabled = false; poke();
}

// FNV-1a по словам - как tools/step1_hash.py
function fnv(w) {
  let h = 0x811c9dc5;
  for (let i = 0; i < w.length; i++) h = Math.imul(h ^ w[i], 0x01000193) >>> 0;
  return h;
}

init().catch(e => post('ошибка: ' + (e?.message || e)));
