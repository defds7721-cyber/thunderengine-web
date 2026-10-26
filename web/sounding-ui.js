// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Конструктор зондировки в редакторе: Skew-T, годограф, параметры, индексы.
// Состояние (spec) хранится в пресете рядом с файлом:
//   { mode: 'params' | 'nodes', params, nodes, wind }
// Любое перетаскивание точки переводит профиль (или ветер) в «свои точки».
import * as T from './thermo.js';
import { T as tr } from './i18n.js';

const $ = (root, sel) => root.querySelector(sel);
const css = n => getComputedStyle(document.documentElement).getPropertyValue(n).trim();

const PARAM_UI = [
  ['thSfc', 'θ у земли', 'K', 290, 310, 0.5],
  ['qvPbl', 'влага в ПС', 'г/кг', 6, 22, 0.5],
  ['rhSfc', 'RH у земли', '', 0.3, 1, 0.01],
  ['rhTop', 'RH наверху', '', 0.05, 0.8, 0.01],
  ['capDth', 'задерживающий слой', 'K', 0, 8, 0.25],
  ['capZ', 'его высота', 'м', 500, 4000, 100],
  ['zTrop', 'тропопауза', 'м', 9000, 16000, 250],
  ['thTrop', 'θ тропопаузы', 'K', 325, 365, 1],
  ['tTrop', 'T тропопаузы', 'K', 195, 230, 1],
  ['psfc', 'давление у земли', 'гПа', 850, 1030, 1],
];

export function mountSounding(root, { spec, gridTop, readOnly, onChange }) {
  spec = structuredClone(spec);
  const top = Math.max(22000, Math.ceil((gridTop + 1000) / 1000) * 1000);
  const zs = T.levelHeights(top);
  root.innerHTML = `
    <div class="snd">
      <div class="snd-plots">
        <canvas class="skewt" aria-label="Skew-T"></canvas>
        <div class="snd-right">
          <canvas class="hodo" aria-label="Годограф"></canvas>
          <table class="kv snd-idx"></table>
        </div>
      </div>
      <div class="snd-ctl">
        <div class="seg"><button data-m="params">Параметры</button><button data-m="nodes">Свои точки</button></div>
        <div class="snd-params grid"></div>
        <p class="snd-hint"></p>
        <p class="snd-hint snd-warn"></p>
        <h3>Ветер</h3>
        <div class="grid">
          <div class="fld"><label>форма</label><select class="wkind">${Object.entries(T.WIND_KINDS).map(([k, l]) => `<option value="${k}">${l}</option>`).join('')}</select></div>
          <div class="fld wsh"><label><span>сдвиг</span><b class="v-shear"></b></label><input type="range" class="shear" min="0" max="60" step="1"></div>
          <div class="fld wsh"><label><span>глубина</span><b class="v-depth"></b></label><input type="range" class="depth" min="1000" max="12000" step="250"></div>
        </div>
      </div>
    </div>`;
  const sk = $(root, '.skewt'), ho = $(root, '.hodo');
  const fields = $(root, '.snd-params');
  fields.innerHTML = PARAM_UI.map(([k, l, u, a, b, s]) =>
    `<div class="fld"><label><span>${l}</span><b class="v-${k}"></b></label><input type="range" data-k="${k}" min="${a}" max="${b}" step="${s}"></div>`).join('');

  let prof = null, idx = null;
  const recompute = () => {
    prof = spec.mode === 'nodes' ? T.nodeProfile(spec.params.psfc, spec.nodes, zs) : T.paramProfile(spec.params, zs);
    idx = T.indices(prof, spec.wind);
  };
  const emit = () => onChange?.(structuredClone(spec), T.soundingText(prof, spec.wind));

  // ---- элементы управления
  const syncControls = () => {
    root.querySelectorAll('.seg button').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.m === spec.mode)));
    fields.classList.toggle('hidden', spec.mode !== 'params');
    $(root, '.snd-hint').textContent = spec.mode === 'nodes'
      ? 'Тяни точки на Skew-T: красные - температура, зелёные - точка росы.'
      : 'Потяни точку на графике - профиль перейдёт в «свои точки».';
    // тёплый пузырь CM1 - 1-2 K на 1.4 км: слой сильнее может не дать грозе начаться
    $(root, '.snd-warn').textContent = idx.sb.cin < -50 || (spec.mode === 'params' && spec.params.capDth >= 1)
      ? `CIN ${Math.round(idx.sb.cin)} Дж/кг: начальный пузырь (iinit, обычно +1-2 K) может не пробить слой, тогда гроза не начнётся.` : '';
    for (const [k, , u] of PARAM_UI) {
      $(root, `[data-k="${k}"]`).value = spec.params[k];
      $(root, `.v-${k}`).textContent = `${(+spec.params[k]).toFixed(k.startsWith('rh') ? 2 : k === 'capDth' || k === 'qvPbl' || k === 'thSfc' ? 1 : 0)} ${u}`;
    }
    $(root, '.wkind').value = spec.wind.kind;
    $(root, '.shear').value = spec.wind.shear; $(root, '.depth').value = spec.wind.depth;
    $(root, '.v-shear').textContent = `${spec.wind.shear} м/с`; $(root, '.v-depth').textContent = `${(spec.wind.depth / 1000).toFixed(2)} км`;
    root.querySelectorAll('.wsh').forEach(e => e.classList.toggle('hidden', spec.wind.kind === 'calm' || spec.wind.kind === 'nodes'));
    root.querySelectorAll('input,select,.seg button').forEach(e => { e.disabled = readOnly; });
  };
  const changed = () => { recompute(); syncControls(); draw(); emit(); };
  root.querySelectorAll('.seg button').forEach(b => b.onclick = () => {
    if (b.dataset.m === spec.mode) return;
    if (b.dataset.m === 'nodes') spec.nodes = T.nodesFrom(prof);
    spec.mode = b.dataset.m;
    changed();
  });
  fields.addEventListener('input', e => { const k = e.target.dataset.k; if (!k) return; spec.params[k] = +e.target.value; changed(); });
  $(root, '.wkind').onchange = e => {
    if (e.target.value === 'nodes') spec.wind.nodes = T.windNodesFrom(spec.wind);
    spec.wind.kind = e.target.value; changed();
  };
  $(root, '.shear').oninput = e => { spec.wind.shear = +e.target.value; changed(); };
  $(root, '.depth').oninput = e => { spec.wind.depth = +e.target.value; changed(); };

  // ---- Skew-T
  const P0 = 1050, P1 = 100, TMIN = -40, TMAX = 50;
  let sw = 0, shh = 0, dpr = 1;
  const sy = p => shh * Math.log(P0 / p) / Math.log(P0 / P1);
  const sx = (t, p) => (t - TMIN) / (TMAX - TMIN) * sw + sy(p) * 0.9;   // наклон изотерм ~42°
  const tAt = (x, p) => (x - sy(p) * 0.9) / sw * (TMAX - TMIN) + TMIN;
  const PAD = { l: 34, r: 8, t: 8, b: 20 };
  function size(c, w, h) {
    dpr = window.devicePixelRatio || 1;
    // ширина - от колонки (CSS width: 100%), задаётся только высота
    c.width = Math.round(w * dpr); c.height = Math.round(h * dpr);
    c.style.height = h + 'px';
  }
  function drawSkew() {
    const W = sk.parentElement.clientWidth ? sk.clientWidth : 520, H = Math.round(Math.min(620, Math.max(420, W * 1.05)));
    if (sk.width !== Math.round(W * dpr) || sk.height !== Math.round(H * dpr)) size(sk, W, H);
    sw = W - PAD.l - PAD.r; shh = H - PAD.t - PAD.b;
    const g = sk.getContext('2d');
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.clearRect(0, 0, W, H);
    g.save(); g.translate(PAD.l, PAD.t);
    // y растёт вверх от низа: переворот
    const Y = p => shh - sy(p);
    const X = (t, p) => sx(t, p);
    g.beginPath(); g.rect(0, 0, sw, shh); g.clip();
    const grid = css('--line'), muted = css('--muted');
    g.lineWidth = 1;
    const path = (pts, color, dash = [], w = 1) => {
      g.strokeStyle = color; g.setLineDash(dash); g.lineWidth = w; g.beginPath();
      let on = false;
      for (const [x, y] of pts) { if (!isFinite(x) || !isFinite(y)) { on = false; continue; } on ? g.lineTo(x, y) : g.moveTo(x, y); on = true; }
      g.stroke(); g.setLineDash([]);
    };
    const ps = []; for (let p = P0; p >= P1; p -= 10) ps.push(p);
    for (let t = -120; t <= 50; t += 10) path(ps.map(p => [X(t, p), Y(p)]), grid);
    for (const p of [1000, 850, 700, 500, 400, 300, 250, 200, 150, 100]) path([[0, Y(p)], [sw, Y(p)]], grid);
    for (let th = 250; th <= 460; th += 10) path(ps.map(p => [X(th * Math.pow(p / 1000, 0.2854) - 273.15, p), Y(p)]), grid, [4, 4]);
    for (let tw = 0; tw <= 32; tw += 4) {
      let t = tw + 273.15, pp = 100000; const pts = [];
      for (let p = 1000; p >= 200; p -= 10) { t = T.moistStepPub(pp, t, p * 100 - pp); pp = p * 100; pts.push([X(t - 273.15, p), Y(p)]); }
      path(pts, grid, [1, 3]);
    }
    for (const q of [2, 4, 8, 12, 16, 20]) {
      const pts = []; for (let p = 1050; p >= 600; p -= 10) pts.push([X(T.dewpoint(p * 100, q / 1000) - 273.15, p), Y(p)]);
      path(pts, grid, [2, 6]);
    }
    const d = idx.d;
    const pp = d.p.map(x => x / 100);
    // CAPE: между частицей и средой (виртуальные)
    const sb = idx.sb, tve = d.t.map((x, k) => x * (1 + d.qv[k] / 0.622) / (1 + d.qv[k]));
    g.fillStyle = 'rgba(217,45,32,0.14)';
    for (let k = 1; k < pp.length; k++) {
      const a = sb.tp[k - 1], b = sb.tp[k];
      if (!(a > tve[k - 1] && b > tve[k])) continue;
      g.beginPath();
      g.moveTo(X(tve[k - 1] - 273.15, pp[k - 1]), Y(pp[k - 1])); g.lineTo(X(a - 273.15, pp[k - 1]), Y(pp[k - 1]));
      g.lineTo(X(b - 273.15, pp[k]), Y(pp[k])); g.lineTo(X(tve[k] - 273.15, pp[k]), Y(pp[k])); g.closePath(); g.fill();
    }
    path(pp.map((p, k) => [X(sb.tp[k] - 273.15, p), Y(p)]), css('--text'), [6, 4], 1.2);
    path(pp.map((p, k) => [X(d.td[k] - 273.15, p), Y(p)]), css('--success'), [], 2);
    path(pp.map((p, k) => [X(d.t[k] - 273.15, p), Y(p)]), css('--error'), [], 2);
    // точки
    nodePix = [];
    if (spec.mode === 'nodes' && !readOnly) {
      for (const [i, n] of spec.nodes.entries()) {
        const k = Math.min(d.z.length - 1, Math.round(n.z / 100));
        const p = pp[k];
        for (const [key, col] of [['t', css('--error')], ['td', css('--success')]]) {
          const x = X(n[key], p), y = Y(p);
          nodePix.push({ i, key, x: x + PAD.l, y: y + PAD.t, p });
          g.fillStyle = col; g.beginPath(); g.arc(x, y, 4, 0, 7); g.fill();
        }
      }
    }
    // уровни НУК / УСК / РН
    g.font = '11px ' + css('--mono'); g.fillStyle = muted;
    const zP = z => { for (let k = 1; k < d.z.length; k++) if (d.z[k] >= z) return pp[k]; return P1; };
    const mark = (z, l) => { if (z == null) return; const y = Y(zP(z)); g.fillRect(sw - 50, y, 14, 1); g.fillText(tr(l), sw - 34, y + 4); };
    mark(sb.lcl, 'НУК'); mark(sb.lfc, 'УСК'); mark(sb.el, 'РН');
    g.restore();
    // подписи
    g.font = '11px ' + css('--mono'); g.fillStyle = muted; g.textAlign = 'right';
    for (const p of [1000, 850, 700, 500, 300, 200, 100]) g.fillText(String(p), PAD.l - 4, PAD.t + shh - sy(p) + 4);
    g.textAlign = 'center';
    for (let t = -40; t <= 40; t += 20) g.fillText(t + '°', PAD.l + X(t, P0), H - 5);
    g.textAlign = 'left';
  }
  let nodePix = [];

  // ---- годограф
  let hscale = 1, hc = 0, hodoPix = [];
  function drawHodo() {
    const W = Math.max(160, ho.clientWidth || 300), H = W;
    if (ho.width !== Math.round(W * dpr) || ho.height !== Math.round(H * dpr)) size(ho, W, H);
    const g = ho.getContext('2d');
    g.setTransform(dpr, 0, 0, dpr, 0, 0); g.clearRect(0, 0, W, H);
    const pts = []; for (let z = 0; z <= 12000; z += 100) pts.push({ z, ...T.windAt(spec.wind, z) });
    const R = Math.max(20, Math.ceil(Math.max(...pts.map(p => Math.hypot(p.u, p.v)), Math.hypot(idx.storm.u, idx.storm.v)) / 10) * 10 + 5);
    hc = W / 2; hscale = (W / 2 - 8) / R;
    const X = u => hc + u * hscale, Y = v => hc - v * hscale;
    g.strokeStyle = css('--line'); g.lineWidth = 1;
    for (let r = 10; r <= R; r += 10) { g.beginPath(); g.arc(hc, hc, r * hscale, 0, 7); g.stroke(); }
    g.beginPath(); g.moveTo(0, hc); g.lineTo(W, hc); g.moveTo(hc, 0); g.lineTo(hc, H); g.stroke();
    g.font = '11px ' + css('--mono'); g.fillStyle = css('--muted');
    for (let r = 10; r <= R; r += 10) g.fillText(r, X(r) + 2, hc - 3);
    const seg = [[0, 1000, '#d92d20'], [1000, 3000, '#188038'], [3000, 6000, '#c58a00'], [6000, 12000, '#1f5fd6']];
    g.lineWidth = 2.5;
    for (const [a, b, col] of seg) {
      g.strokeStyle = col; g.beginPath();
      pts.filter(p => p.z >= a && p.z <= b).forEach((p, i) => i ? g.lineTo(X(p.u), Y(p.v)) : g.moveTo(X(p.u), Y(p.v)));
      g.stroke();
    }
    hodoPix = [];
    if (spec.wind.kind === 'nodes' && !readOnly) {
      g.fillStyle = css('--text');
      for (const [i, n] of spec.wind.nodes.entries()) {
        g.beginPath(); g.arc(X(n.u), Y(n.v), 4, 0, 7); g.fill();
        hodoPix.push({ i, x: X(n.u), y: Y(n.v) });
      }
    }
    // движение правой ячейки
    g.strokeStyle = css('--text'); g.lineWidth = 1.5;
    const sx_ = X(idx.storm.u), sy_ = Y(idx.storm.v);
    g.beginPath(); g.moveTo(sx_ - 5, sy_ - 5); g.lineTo(sx_ + 5, sy_ + 5); g.moveTo(sx_ + 5, sy_ - 5); g.lineTo(sx_ - 5, sy_ + 5); g.stroke();
    g.fillStyle = css('--muted'); g.fillText('RM', sx_ + 7, sy_ + 4);
  }

  function drawIdx() {
    const r = idx, f0 = x => x == null ? '-' : Math.round(x);
    const km = x => x == null ? '-' : (x / 1000).toFixed(1) + ' км';
    const rows = [
      ['CAPE приземная', `${f0(r.sb.cape)} Дж/кг`], ['CIN приземная', `${f0(r.sb.cin)} Дж/кг`],
      ['CAPE слоя 100 гПа', `${f0(r.ml.cape)} Дж/кг`], ['CAPE наибольшая', `${f0(r.mu.cape)} Дж/кг`],
      ['НУК / УСК / РН', `${km(r.sb.lcl)} / ${km(r.sb.lfc)} / ${km(r.sb.el)}`],
      ['LI', r.li.toFixed(1)], ['Осаждённая вода', `${r.pw.toFixed(0)} мм`],
      ['Сдвиг 0-1 / 0-6 км', `${r.shear1.toFixed(0)} / ${r.shear6.toFixed(0)} м/с`],
      ['SRH 0-1 / 0-3 км', `${f0(r.srh1)} / ${f0(r.srh3)} м²/с²`],
    ];
    $(root, '.snd-idx').innerHTML = rows.map(([k, v]) => `<tr><td>${k}</td><td>${v}</td></tr>`).join('');
  }
  const draw = () => { drawSkew(); drawHodo(); drawIdx(); };

  // ---- перетаскивание
  const pos = (c, e) => { const b = c.getBoundingClientRect(); return { x: e.clientX - b.left, y: e.clientY - b.top }; };
  let drag = null;
  sk.addEventListener('pointerdown', e => {
    if (readOnly) return;
    const m = pos(sk, e);
    // из параметров - в свои точки, только если касание попало в точку; иначе всё как было
    const undo = spec.mode !== 'nodes' ? structuredClone(spec) : null;
    if (undo) { spec.nodes = T.nodesFrom(prof); spec.mode = 'nodes'; recompute(); draw(); }
    let best = null, bd = 14;
    for (const n of nodePix) { const dd = Math.hypot(n.x - m.x, n.y - m.y); if (dd < bd) { bd = dd; best = n; } }
    if (!best) { if (undo) { spec = undo; recompute(); draw(); } return; }
    if (undo) syncControls();
    drag = { c: 'sk', ...best }; sk.setPointerCapture(e.pointerId); e.preventDefault();
  });
  sk.addEventListener('pointermove', e => {
    if (drag?.c !== 'sk') return;
    const m = pos(sk, e);
    let t = Math.round(tAt(m.x - PAD.l, drag.p) * 2) / 2;
    const n = spec.nodes[drag.i];
    if (drag.key === 'td') t = Math.min(t, n.t); else t = Math.max(t, n.td);
    if (n[drag.key] === t) return;
    n[drag.key] = t; recompute(); draw();
  });
  ho.addEventListener('pointerdown', e => {
    if (readOnly) return;
    const m = pos(ho, e);
    const undo = spec.wind.kind !== 'nodes' ? structuredClone(spec.wind) : null;
    if (undo) { spec.wind.nodes = T.windNodesFrom(spec.wind); spec.wind.kind = 'nodes'; recompute(); draw(); }
    let best = null, bd = 14;
    for (const n of hodoPix) { const dd = Math.hypot(n.x - m.x, n.y - m.y); if (dd < bd) { bd = dd; best = n; } }
    if (!best) { if (undo) { spec.wind = undo; recompute(); draw(); } return; }
    if (undo) syncControls();
    drag = { c: 'ho', ...best }; ho.setPointerCapture(e.pointerId); e.preventDefault();
  });
  ho.addEventListener('pointermove', e => {
    if (drag?.c !== 'ho') return;
    const m = pos(ho, e), n = spec.wind.nodes[drag.i];
    n.u = Math.round((m.x - hc) / hscale * 2) / 2; n.v = Math.round((hc - m.y) / hscale * 2) / 2;
    recompute(); draw();
  });
  const end = () => { if (drag) { drag = null; emit(); } };
  for (const c of [sk, ho]) { c.addEventListener('pointerup', end); c.addEventListener('pointercancel', end); c.style.touchAction = 'none'; }
  // высота холста зависит от ширины: перерисовка только при смене ширины и вне цикла наблюдателя
  let lastW = 0;
  const ro = new ResizeObserver(() => {
    if (!sk.clientWidth || sk.clientWidth === lastW) return;
    lastW = sk.clientWidth; requestAnimationFrame(draw);
  });
  ro.observe(sk);

  recompute(); syncControls(); draw();
  return { text: () => T.soundingText(prof, spec.wind), spec: () => structuredClone(spec), destroy: () => ro.disconnect() };
}
