// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Конструктор зондировки: профиль по параметрам или по точкам, файл input_sounding
// (isnd=7) и индексы для показа (CAPE, CIN, уровни, сдвиг, SRH). Только для
// редактора: счёт модели берёт готовый файл и разбирает его ядром порта
// (Sounding в core/base.js), так что точность здесь - double, без f32.
// Постоянные - CM1 (constants.incl).
export const C = { rd: 287.04, rv: 461.5, cp: 1005.7, g: 9.81, p00: 1.0e5, lv: 2.501e6 };
const eps = C.rd / C.rv, kap = C.rd / C.cp;

// насыщающее отношение смеси над водой (CM1 rslf), p Па, t K -> кг/кг
export function rsat(p, t) {
  const es = 611.2 * Math.exp(17.67 * (t - 273.15) / (t - 29.65));
  return eps * es / Math.max(es, p - es);
}
// точка росы по отношению смеси (обращение той же формулы)
export function dewpoint(p, qv) {
  const e = Math.max(qv, 1e-10) * p / (eps + Math.max(qv, 1e-10));
  const l = Math.log(e / 611.2);
  return (243.5 * l / (17.67 - l)) + 273.15;
}
const tv = (t, qv) => t * (1 + qv / eps) / (1 + qv);

// ---- профили

// Параметры по умолчанию дают Вейсмана-Клемпа (isnd=5, base.F:438-528):
// θ = θs + (θtr - θs)(z/ztr)^1.25, RH = 1 - 0.75 (z/ztr)^1.25, qv <= qvPbl,
// выше тропопаузы изотермия Ttr. Добавлено: RH у земли и на тропопаузе,
// задерживающий слой (Δθ на высоте zcap толщиной 500 м).
export const DEFAULT_PARAMS = {
  psfc: 1000, thSfc: 300, thTrop: 343, zTrop: 12000, tTrop: 213, qvPbl: 14,
  rhSfc: 1.0, rhTop: 0.25, capDth: 0, capZ: 1500,
};
export const DEFAULT_WIND = { kind: 'quarter', shear: 31, depth: 6000, nodes: null };

export const levelHeights = (top, step = 100) => {
  const z = [];
  for (let x = step; x <= top + 1e-6; x += step) z.push(x);
  return z;
};

// θ(z), RH(z) по параметрам; qv из RH итерацией с гидростатикой
export function paramProfile(P, zs) {
  const zt = P.zTrop;
  const th = zs.map(z => {
    let t = z < zt ? P.thSfc + (P.thTrop - P.thSfc) * Math.pow(z / zt, 1.25)
      : P.thTrop * Math.exp(C.g / (P.tTrop * C.cp) * (z - zt));
    if (P.capDth) t += P.capDth * Math.min(1, Math.max(0, (z - P.capZ) / 500));
    return t;
  });
  const rh = zs.map(z => z < zt ? P.rhSfc - (P.rhSfc - P.rhTop) * Math.pow(z / zt, 1.25) : P.rhTop);
  const ps = P.psfc * 100, qcap = P.qvPbl / 1000;
  const thS = P.thSfc, qvS = Math.min(qcap, P.rhSfc * rsat(ps, thS * Math.pow(ps / C.p00, kap)));
  let qv = zs.map(() => 0);
  let p = [];
  for (let it = 0; it < 20; it++) {
    p = hydrostatic(ps, thS, qvS, zs, th, qv);
    qv = zs.map((_, k) => {
      const t = th[k] * Math.pow(p[k] / C.p00, kap);
      return Math.min(qcap, rh[k] * rsat(p[k], t));
    });
  }
  return { psfc: P.psfc, thSfc: thS, qvSfc: qvS, z: zs, th, qv };
}

// давление на уровнях из приземных и профиля θ, qv (через π по θv, как CM1)
export function hydrostatic(ps, thS, qvS, zs, th, qv) {
  const pi = [], thv = (t, q) => t * (1 + q / eps) / (1 + q);
  let piPrev = Math.pow(ps / C.p00, kap), zPrev = 0, tvPrev = thv(thS, qvS);
  for (let k = 0; k < zs.length; k++) {
    const t = thv(th[k], qv[k]);
    piPrev -= C.g * (zs[k] - zPrev) / (C.cp * 0.5 * (t + tvPrev));
    pi.push(piPrev); zPrev = zs[k]; tvPrev = t;
  }
  return pi.map(x => C.p00 * Math.pow(x, 1 / kap));
}

// Профиль по точкам: [{ z, t, td }] (°C), между точками линейно по высоте.
// Первая точка - у земли (z = 0).
export function nodeProfile(psfc, nodes, zs) {
  const n = [...nodes].sort((a, b) => a.z - b.z);
  const at = (z, key) => {
    if (z <= n[0].z) return n[0][key];
    for (let i = 1; i < n.length; i++) if (z <= n[i].z) {
      const fr = (z - n[i - 1].z) / (n[i].z - n[i - 1].z);
      return n[i - 1][key] + fr * (n[i][key] - n[i - 1][key]);
    }
    return n[n.length - 1][key];
  };
  const ps = psfc * 100;
  // давление интегрируется по виртуальной температуре сразу в z
  const all = [0, ...zs];
  const p = [ps];
  for (let k = 1; k < all.length; k++) {
    const z0 = all[k - 1], z1 = all[k];
    const T0 = at(z0, 't') + 273.15, T1 = at(z1, 't') + 273.15;
    const q0 = rsat(p[k - 1], Math.min(at(z0, 'td'), at(z0, 't')) + 273.15);
    const pGuess = p[k - 1] * Math.exp(-C.g * (z1 - z0) / (C.rd * T0));
    const q1 = rsat(pGuess, Math.min(at(z1, 'td'), at(z1, 't')) + 273.15);
    const tvm = 0.5 * (tv(T0, q0) + tv(T1, q1));
    p.push(p[k - 1] * Math.exp(-C.g * (z1 - z0) / (C.rd * tvm)));
  }
  const th = [], qv = [];
  all.forEach((z, k) => {
    const T = at(z, 't') + 273.15, Td = Math.min(at(z, 'td'), at(z, 't')) + 273.15;
    th.push(T * Math.pow(C.p00 / p[k], kap));
    qv.push(rsat(p[k], Td));
  });
  return { psfc, thSfc: th[0], qvSfc: qv[0], z: zs, th: th.slice(1), qv: qv.slice(1) };
}

// точки из любого профиля (для перехода «параметры -> точки»)
export const NODE_Z = [0, 250, 500, 750, 1000, 1500, 2000, 2500, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000,
  11000, 12000, 13000, 14000, 16000, 18000, 20000];
export function nodesFrom(prof) {
  const d = derive(prof);
  return NODE_Z.filter(z => z <= d.z[d.z.length - 1]).map(z => {
    let k = d.z.findIndex(x => x >= z);
    if (k < 0) k = d.z.length - 1;
    return { z, t: +(d.t[k] - 273.15).toFixed(1), td: +(d.td[k] - 273.15).toFixed(1) };
  });
}

// ---- ветер
export const WIND_KINDS = {
  calm: 'штиль', straight: 'прямой', quarter: 'четверть круга', half: 'полукруг', nodes: 'свои точки',
};
export function windAt(W, z) {
  const s = W.shear, d = W.depth;
  switch (W.kind) {
    case 'calm': return { u: 0, v: 0 };
    case 'straight': return { u: s * Math.min(z / d, 1), v: 0 };
    case 'quarter': {
      // форма iwnd=2: четверть окружности до d/3, дальше прямая (base.F:1006)
      const d1 = d / 3, m1 = s * 7 / 31;
      if (z <= d1) { const a = Math.PI / 2 * z / d1; return { u: m1 - m1 * Math.cos(a), v: m1 * Math.sin(a) }; }
      if (z <= d) return { u: m1 + (z - d1) * (s - m1) / (d - d1), v: m1 };
      return { u: s, v: m1 };
    }
    case 'half': {
      const r = s / 2, a = Math.PI * Math.min(z / d, 1);
      return { u: r - r * Math.cos(a), v: r * Math.sin(a) };
    }
    case 'nodes': {
      const n = W.nodes;
      if (z <= n[0].z) return { u: n[0].u, v: n[0].v };
      for (let i = 1; i < n.length; i++) if (z <= n[i].z) {
        const fr = (z - n[i - 1].z) / (n[i].z - n[i - 1].z);
        return { u: n[i - 1].u + fr * (n[i].u - n[i - 1].u), v: n[i - 1].v + fr * (n[i].v - n[i - 1].v) };
      }
      const l = n[n.length - 1]; return { u: l.u, v: l.v };
    }
  }
  return { u: 0, v: 0 };
}
export const WIND_NODE_Z = [0, 500, 1000, 1500, 2000, 3000, 4000, 5000, 6000, 8000, 10000, 12000];
export const windNodesFrom = W => WIND_NODE_Z.map(z => { const w = windAt(W, z); return { z, u: +w.u.toFixed(1), v: +w.v.toFixed(1) }; });

// ---- файл
const fx = (x, w, n) => x.toFixed(n).padStart(w);
export function soundingText(prof, W) {
  let s = `${fx(prof.psfc, 12, 4)} ${fx(prof.thSfc, 12, 6)} ${fx(prof.qvSfc * 1000, 12, 6)}\n`;
  prof.z.forEach((z, k) => {
    const w = windAt(W, z);
    s += `${fx(z, 12, 4)} ${fx(prof.th[k], 12, 6)} ${fx(prof.qv[k] * 1000, 12, 6)} ${fx(w.u, 10, 4)} ${fx(w.v, 10, 4)}\n`;
  });
  return s;
}
// файл -> профиль и ветер по точкам (для показа чужого файла)
export function fromText(text) {
  const rows = text.replace(/\r\n?/g, '\n').split('\n').map(s => s.trim()).filter(Boolean)
    .map(r => r.split(/\s+/).map(Number));
  const h = rows.shift();
  const z = [], th = [], qv = [], wn = [];
  for (const r of rows) { z.push(r[0]); th.push(r[1]); qv.push(r[2] / 1000); wn.push({ z: r[0], u: r[3] ?? 0, v: r[4] ?? 0 }); }
  return { prof: { psfc: h[0], thSfc: h[1], qvSfc: h[2] / 1000, z, th, qv }, wind: { kind: 'nodes', nodes: wn } };
}

// ---- производные величины и индексы
export function derive(prof) {
  const z = [0, ...prof.z], th = [prof.thSfc, ...prof.th], qv = [prof.qvSfc, ...prof.qv];
  const p = [prof.psfc * 100, ...hydrostatic(prof.psfc * 100, prof.thSfc, prof.qvSfc, prof.z, prof.th, prof.qv)];
  const t = th.map((x, k) => x * Math.pow(p[k] / C.p00, kap));
  const td = qv.map((q, k) => Math.min(dewpoint(p[k], q), t[k]));
  return { z, p, t, td, th, qv };
}

// влажная псевдоадиабата: шаг по давлению от (p, t) насыщенной частицы
function moistStep(p, t, dp) {
  const f = (pp, tt) => {
    const rs = rsat(pp, tt);
    const num = (C.rd * tt + C.lv * rs) / pp;
    const den = C.cp + C.lv * C.lv * rs * eps / (C.rd * tt * tt);
    return num / den;
  };
  const k1 = f(p, t), k2 = f(p + dp / 2, t + k1 * dp / 2), k3 = f(p + dp / 2, t + k2 * dp / 2), k4 = f(p + dp, t + k3 * dp);
  return t + dp * (k1 + 2 * k2 + 2 * k3 + k4) / 6;
}

// подъём частицы (p0 Па, t0 K, q0 кг/кг) по уровням d; виртуальная поправка
export function parcel(d, p0, t0, q0) {
  // НУК: сухой подъём с сохранением q, пока T не дойдёт до точки росы
  let pl = p0, tl = t0;
  const th0 = t0 * Math.pow(C.p00 / p0, kap);
  for (let i = 0; i < 2000; i++) {
    const tt = th0 * Math.pow(pl / C.p00, kap);
    if (rsat(pl, tt) <= q0) { tl = tt; break; }
    pl -= 100; tl = tt;
  }
  const tp = [];
  let pm = pl, tm = tl;
  for (let k = 0; k < d.p.length; k++) {
    const pk = d.p[k];
    if (pk > p0) { tp.push(NaN); continue; }
    if (pk >= pl) {
      const tt = th0 * Math.pow(pk / C.p00, kap);
      tp.push(tv(tt, q0));
    } else {
      while (pm - 500 > pk) { tm = moistStep(pm, tm, -500); pm -= 500; }
      const tk = moistStep(pm, tm, pk - pm);
      tm = tk; pm = pk;
      tp.push(tv(tk, rsat(pk, tk)));
    }
  }
  // CAPE/CIN по виртуальной разнице, интеграл по z
  const tve = d.t.map((x, k) => tv(x, d.qv[k]));
  let cape = 0, cin = 0, lfc = null, el = null, below = true;
  for (let k = 1; k < d.p.length; k++) {
    if (isNaN(tp[k - 1]) || isNaN(tp[k])) continue;
    const b0 = (tp[k - 1] - tve[k - 1]) / tve[k - 1], b1 = (tp[k] - tve[k]) / tve[k];
    const dz = d.z[k] - d.z[k - 1], b = C.g * 0.5 * (b0 + b1) * dz;
    if (b > 0) { cape += b; if (lfc === null) lfc = d.z[k - 1]; el = d.z[k]; below = false; }
    else if (below) cin += b;
  }
  // CIN после LFC не считается; если положительной части нет - CIN нет смысла
  if (lfc === null) cin = 0;
  const zl = interpZ(d, pl);
  return { tp, cape, cin, lcl: zl, lfc, el, plcl: pl };
}
const interpZ = (d, p) => {
  for (let k = 1; k < d.p.length; k++) if (d.p[k] <= p) {
    const fr = Math.log(d.p[k - 1] / p) / Math.log(d.p[k - 1] / d.p[k]);
    return d.z[k - 1] + fr * (d.z[k] - d.z[k - 1]);
  }
  return d.z[d.z.length - 1];
};

export function indices(prof, W) {
  const d = derive(prof);
  const sb = parcel(d, d.p[0], d.t[0], d.qv[0]);
  // ML: средние θ и q нижних 100 гПа
  let n = 0, ths = 0, qs = 0;
  for (let k = 0; k < d.p.length && d.p[k] >= d.p[0] - 10000; k++) { ths += d.th[k]; qs += d.qv[k]; n++; }
  const ml = parcel(d, d.p[0], (ths / n) * Math.pow(d.p[0] / C.p00, kap), qs / n);
  // MU: самая неустойчивая частица в нижних 300 гПа
  let mu = sb;
  for (let k = 1; k < d.p.length && d.p[k] >= d.p[0] - 30000; k += 3) {
    const r = parcel(d, d.p[k], d.t[k], d.qv[k]);
    if (r.cape > mu.cape) mu = r;
  }
  const w = z => windAt(W, z);
  const shear = (z0, z1) => { const a = w(z0), b = w(z1); return Math.hypot(b.u - a.u, b.v - a.v); };
  // движение правой ячейки по Банкерсу: средний ветер 0-6 км + 7.5 м/с вправо от сдвига
  let mu6 = 0, mv6 = 0;
  for (let z = 0; z <= 6000; z += 100) { const x = w(z); mu6 += x.u; mv6 += x.v; }
  mu6 /= 61; mv6 /= 61;
  const s0 = w(0), s6 = w(6000), su = s6.u - s0.u, sv = s6.v - s0.v, sm = Math.hypot(su, sv) || 1;
  const storm = { u: mu6 + 7.5 * sv / sm, v: mv6 - 7.5 * su / sm };
  const srh = top => {
    let h = 0;
    for (let z = 0; z < top; z += 100) {
      const a = w(z), b = w(z + 100);
      h += (b.u - storm.u) * (a.v - storm.v) - (a.u - storm.u) * (b.v - storm.v);
    }
    return h;
  };
  let pw = 0;
  for (let k = 1; k < d.p.length; k++) pw += 0.5 * (d.qv[k] + d.qv[k - 1]) * (d.p[k - 1] - d.p[k]) / C.g;
  const k500 = d.p.findIndex(x => x <= 50000);
  const li = k500 > 0 ? d.t[k500] * (1 + d.qv[k500] / eps) / (1 + d.qv[k500]) - sb.tp[k500] : NaN;
  return { d, sb, ml, mu, storm, shear1: shear(0, 1000), shear6: shear(0, 6000), srh1: srh(1000), srh3: srh(3000),
    pw, li };
}
export const moistStepPub = moistStep;
