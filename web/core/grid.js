// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Сетка модели: константы, горизонтальная и вертикальная сетки, арена полей.
import { f, fmaf } from './f32.js';

// Округление к ближайшему, половина от нуля
export const roundHalfAway = x => Math.sign(x) * Math.round(Math.abs(x));
const range = (a, b) => { const r = []; for (let i = a; i <= b; i++) r.push(i); return r; };   // a...b

// ---- Константы
export const Constants = {
  g: 9.81, rd: 287.04, cp: 1005.7, cpv: 1870.0, xlv: 2501000.0, xls: 2834000.0, rv: 461.5, p00: 1.0e5,
  cpl: 4190.0, cpi: 2106.0,
};
Constants.cv = Constants.cp - Constants.rd;
Constants.cvv = Constants.cpv - Constants.rv;
Constants.rovcp = Constants.rd / Constants.cp;
Constants.reps = Constants.rv / Constants.rd;

export class ThermoConstants {
  constructor() {
    this.g = Constants.g; this.rd = Constants.rd; this.cp = Constants.cp; this.cpv = Constants.cpv;
    this.xlv = Constants.xlv; this.xls = Constants.xls; this.rv = Constants.rv; this.p00 = Constants.p00;
    this.cpl = Constants.cpl; this.cpi = Constants.cpi; this.dycomsLatentHeat = false;
  }
  static get cm1() { return new ThermoConstants(); }
  get cv() { return this.cp - this.rd; }
  get cvv() { return this.cpv - this.rv; }
  get rovcp() { return this.rd / this.cp; }
  get rddcv() { return this.rd / this.cv; }
  get reps() { return this.rv / this.rd; }
  get eps() { return this.rd / this.rv; }
  get lv1() { return this.dycomsLatentHeat ? this.xlv : this.xlv + (this.cpl - this.cpv) * 273.15; }
  get lv2() { return this.dycomsLatentHeat ? 0.0 : this.cpl - this.cpv; }
  equals(o) {
    return ['g', 'rd', 'cp', 'cpv', 'xlv', 'xls', 'rv', 'p00', 'cpl', 'cpi', 'dycomsLatentHeat'].every(k => this[k] === o[k]);
  }
  get isCM1Default() { return this.equals(ThermoConstants.cm1); }
  static forTestcase(tc) {
    const t = new ThermoConstants();
    if (tc === 4) { t.rd = 287.0; t.cp = 1015.0; t.xlv = 2.47e6; t.dycomsLatentHeat = true; }
    if (tc === 5) { t.rd = 287.0; t.cp = 1004.0; t.xlv = 2.50e6; t.dycomsLatentHeat = true; }
    return t;
  }
}

// ---- Горизонтальная сетка
export const Stretch = { none: 0, both: 1, westOnly: 2 };

export class HorizontalGrid {
  face(i) { return this.xf[i + this.halo]; }
  centre(i) { return this.xh[i + this.halo]; }
  metricCentre(i) { return this.uh[i + this.halo]; }
  metricFace(i) { return this.uf[i + this.halo]; }
  get isUniform() { return this.stretch === Stretch.none; }

  static axiMetrics(xf, xh, on) {
    const n = xf.length;
    const h1 = new Array(n).fill(1), h2 = new Array(n).fill(1), f1 = new Array(n).fill(1), f2 = new Array(n).fill(1);
    const rx = new Array(n).fill(0);
    if (!on) return [h1, h2, f1, f2, rx];
    const smeps = 1.0e-30;
    for (let i = 0; i < n - 1; i++) {
      const xbar = 0.5 * (xf[i + 1] + xf[i]);
      h1[i] = xf[i] / xbar; h2[i] = xf[i + 1] / xbar;
    }
    for (let i = 1; i < n - 1; i++) if (Math.abs(xf[i]) > smeps) {
      f1[i] = 0.5 * (xf[i - 1] + xf[i]) / xf[i];
      f2[i] = 0.5 * (xf[i + 1] + xf[i]) / xf[i];
    }
    for (let i = 0; i < Math.min(n, xh.length); i++) rx[i] = 1.0 / (smeps + xh[i]);
    return [h1, h2, f1, f2, rx];
  }

  static uniformArrays(n, dx, centred, halo) {
    const mult = centred ? 0.5 : 0.0, total = n * dx;
    return {
      xf: range(-halo, n + halo).map(i => i * dx - mult * total),
      xh: range(-halo, n + halo).map(i => (i + 0.5) * dx - mult * total),
      uh: new Array(n + 1 + 2 * halo).fill(1),
      uf: new Array(n + 1 + 2 * halo).fill(1),
    };
  }

  setAxi(on) {
    this.axisymmetric = on;
    [this.arh1, this.arh2, this.arf1, this.arf2, this.rxh] = HorizontalGrid.axiMetrics(this.xf, this.xh, on);
  }

  // init(uniform:dx:centred:halo:axisymmetric:)
  static uniform({ n, dx, centred = true, halo = 3, axisymmetric = false }) {
    const g = new HorizontalGrid();
    g.n = n; g.dx = dx; g.stretch = Stretch.none; g.halo = halo;
    Object.assign(g, HorizontalGrid.uniformArrays(n, dx, centred, halo));
    g.setAxi(axisymmetric);
    return g;
  }

  // init(n:dx:stretch:inner:outer:noStretchLength:totalLength:centred:openWest:openEast:halo:axisymmetric:)
  static stretched({ n, dx, stretch, inner, outer, noStretchLength: nos, totalLength: tot,
    centred = true, openWest = false, openEast = false, halo = 3, axisymmetric = false }) {
    if (stretch === Stretch.none) return HorizontalGrid.uniform({ n, dx, centred, halo, axisymmetric });
    const nominal = 0.5 * (inner + outer);
    let ni1, ni2, ni3;
    if (stretch === Stretch.both) {
      ni1 = Math.trunc(roundHalfAway((tot - nos) * 0.5 / nominal));
      ni2 = Math.trunc(roundHalfAway(nos / inner));
      ni3 = ni1;
    } else {
      ni1 = 0;
      ni2 = Math.trunc(roundHalfAway(nos / inner));
      ni3 = Math.trunc(roundHalfAway((tot - nos) / nominal));
    }
    if (!(n === ni1 + ni2 + ni3 && ni1 >= 0 && ni2 >= 0 && ni3 >= 0)) {
      throw new Error(`растяжение сетки: задано ${n} точек, а параметры требуют ${nos / inner + (tot - nos) / nominal} `
        + `(зоны ${ni1}+${ni2}+${ni3}); CM1 на этом останавливается (param.F:6805)`);
    }
    const c2 = (nominal - inner) / (nominal * nominal * (ni3 - 1));
    const c1 = (inner / nominal) - c2 * nominal;
    const mult = centred ? 0.5 : 0.0;
    const xfdp = new Map();
    for (let i = ni1 + 1; i <= ni1 + ni2 + 1; i++) xfdp.set(i, ni1 * nominal + (i - ni1 - 1) * inner - mult * tot);
    const eastEnd = ni1 + ni2 + ni3 + (stretch === Stretch.both ? halo + 1 : halo);
    for (let i = ni1 + ni2 + 2; i <= eastEnd; i++) {
      const m = (i - 1 - ni1 - ni2) * nominal;
      xfdp.set(i, ni1 * nominal + ni2 * inner + (c1 + c2 * m) * m - mult * tot);
    }
    for (let i = 1 - halo; i <= ni1; i++) {
      const m = (ni1 + 1 - i) * nominal;
      xfdp.set(i, ni1 * nominal - (c1 + c2 * m) * m - mult * tot);
    }
    const westStep = stretch === Stretch.both ? outer : inner;
    for (let i = 1; i <= halo; i++) {
      xfdp.set(1 - i, xfdp.get(1) - i * westStep);
      xfdp.set(n + 1 + i, xfdp.get(n + 1) + i * outer);
    }
    const a = HorizontalGrid.derive(xfdp, n, dx, halo, openWest, openEast);
    const g = new HorizontalGrid();
    g.n = n; g.dx = dx; g.stretch = stretch; g.halo = halo;
    Object.assign(g, a);
    g.setAxi(axisymmetric);
    return g;
  }

  static derive(xfdp, n, dx, halo, openWest, openEast) {
    const F = [], h = [], mh = [], mf = [];
    for (let i = -halo; i <= n + halo; i++) F.push(xfdp.get(i + 1));
    for (let i = -halo; i <= n - 1 + halo; i++) {
      const a = xfdp.get(i + 1), b = xfdp.get(i + 2);
      h.push(0.5 * (b + a));
      mh.push(dx / (b - a));
    }
    h.push(h[h.length - 1] + (xfdp.get(n + 1 + halo) - xfdp.get(n + halo)));
    mh.push(mh[mh.length - 1]);
    mf.push(1.0);
    for (let i = -halo + 1; i <= n + halo - 1; i++) {
      const xhi = 0.5 * (xfdp.get(i + 1) + xfdp.get(i + 2));
      const xhm = 0.5 * (xfdp.get(i) + xfdp.get(i + 1));
      mf.push(dx / (xhi - xhm));
    }
    mf.push(1.0);
    if (openWest) for (let i = 0; i < halo; i++) mf[i] = mf[halo];
    if (openEast) for (let i = n + 1 + halo; i < mf.length; i++) mf[i] = mf[n + halo];
    return { xf: F, xh: h, uh: mh, uf: mf };
  }

  get spacingRange() {
    let lo = Infinity, hi = 0;
    for (let i = 0; i < this.n; i++) { const d = this.face(i + 1) - this.face(i); lo = Math.min(lo, d); hi = Math.max(hi, d); }
    return { min: lo, max: hi };
  }
  get length() { return this.face(this.n) - this.face(0); }
  static requiredPoints({ inner, outer, noStretchLength: nos, totalLength: tot }) {
    return nos / inner + (tot - nos) / (0.5 * (inner + outer));
  }
}

// ---- Сетка
export class Grid {
  static halo = 3;
  static metricBufferIndex = 30;
  constructor({ nx, ny, nz, dx, dy, dz, alignRows = false, hx = null, hy = null }) {
    if (!(nx >= 1 && ny >= 1 && nz >= 1)) throw new Error('размеры сетки должны быть положительными');
    this.nx = nx; this.ny = ny; this.nz = nz; this.dx = dx; this.dy = dy; this.dz = dz;
    this.alignsRows = alignRows;
    this.hx = hx ?? HorizontalGrid.uniform({ n: nx, dx });
    this.hy = hy ?? HorizontalGrid.uniform({ n: ny, dx: dy });
    const rawJ = nx + 1 + 2 * Grid.halo;
    this.strideJ = alignRows ? Math.ceil(rawJ / 32) * 32 : rawJ;
    this.strideK = ny + 1 + 2 * Grid.halo;
    this.count = this.strideJ * this.strideK * (nz + 1);
  }
  get isStretched() { return !this.hx.isUniform || !this.hy.isUniform; }
  get finestSpacing() { return Math.min(this.hx.spacingRange.min, this.hy.spacingRange.min); }
  get isTwoDimensional() { return this.ny === 1; }
  index(i, j, k) { return (i + Grid.halo) + this.strideJ * ((j + Grid.halo) + this.strideK * k); }
  get fieldBytes() { return this.count * 4; }
  metricValues() {
    const sJ = this.strideJ, sK = this.strideK, hx = this.hx, hy = this.hy;
    const v = new Float32Array(9 * sJ + 3 * sK).fill(1);
    for (let i = 0; i < hx.uh.length && i < sJ; i++) v[i] = hx.uh[i];
    for (let i = 0; i < hx.uf.length && i < sJ; i++) v[sJ + i] = hx.uf[i];
    for (let j = 0; j < hy.uh.length && j < sK; j++) v[2 * sJ + j] = hy.uh[j];
    for (let j = 0; j < hy.uf.length && j < sK; j++) v[2 * sJ + sK + j] = hy.uf[j];
    for (let i = 0; i < hx.xf.length && i < sJ; i++) v[2 * sJ + 2 * sK + i] = hx.xf[i];
    for (let j = 0; j < hy.xf.length && j < sK; j++) v[3 * sJ + 2 * sK + j] = hy.xf[j];
    const base = 3 * sJ + 3 * sK;
    [hx.arh1, hx.arh2, hx.arf1, hx.arf2, hx.rxh, hx.xh].forEach((arr, b) => {
      for (let i = 0; i < arr.length && i < sJ; i++) v[base + b * sJ + i] = arr[i];
    });
    return v;
  }
}

// ---- Вертикальная сетка
export class VerticalGrid {
  static fornbergCM1(x0f, af) {
    const x0 = x0f, alpha = af;
    const d = [[0, 0, 0], [0, 0, 0], [0, 0, 0]];
    d[0][0] = 1.0;
    let b1 = 1.0;
    for (let n = 1; n <= 2; n++) {
      let b2 = 1.0;
      for (let nu = 0; nu < n; nu++) {
        const b3 = alpha[n] - alpha[nu];
        b2 = b2 * b3;
        d[n][nu] = ((alpha[n] - x0) * d[n - 1][nu]) / b3;
      }
      d[n][n] = (b1 / b2) * (-((alpha[n - 1] - x0) * d[n - 1][n - 1]));
      b1 = b2;
    }
    return [f(d[2][0]), f(d[2][1]), f(d[2][2])];
  }
  static lagrange(x, x0) {
    const n = Math.min(3, x.length), w = [0, 0, 0];
    for (let i = 0; i < n; i++) {
      let p = 1.0;
      for (let j = 0; j < n; j++) if (j !== i) p *= (x0 - x[j]) / (x[i] - x[j]);
      w[i] = p;
    }
    return [f(w[0]), f(w[1]), f(w[2])];
  }
  static facesFromHalfLevels(sigma, nz) {
    if (!(sigma.length >= nz && nz >= 2)) return null;
    const F = new Array(nz + 1).fill(0);
    for (let k = 0; k < nz; k++) F[k + 1] = f(f(2.0 * sigma[k]) - F[k]);
    for (let k = 0; k < nz; k++) if (!(F[k] < F[k + 1])) return null;
    return F;
  }
  // init(nz:dz:)
  static uniform(nz, dz) { return new VerticalGrid(range(0, nz).map(k => k * dz), dz); }

  // init(faceHeights:nominalDz:)
  constructor(F, nominalDz = null) {
    if (F.length < 3) throw new Error('нужно минимум две ячейки');
    for (let k = 0; k + 1 < F.length; k++) if (!(F[k] < F[k + 1])) throw new Error('высоты граней должны строго возрастать');
    const n = F.length - 1;
    const centers32 = range(0, n - 1).map(k => f(0.5 * (F[k] + F[k + 1])));
    const centers = centers32;
    const dzNom = nominalDz ?? ((F[n] - F[0]) / n);
    const zhGhostLo = -centers32[0];
    const zhGhostHi = f(centers32[n - 1] + f(2.0 * f(f(F[n]) - centers32[n - 1])));
    const dz32 = f(dzNom);
    const mfv = new Array(n + 1).fill(0);
    mfv[0] = f(dz32 / f(centers32[0] - zhGhostLo));
    for (let k = 1; k < n; k++) mfv[k] = f(dz32 / f(centers32[k] - centers32[k - 1]));
    mfv[n] = f(dz32 / f(zhGhostHi - centers32[n - 1]));
    const w2 = new Array(n + 1).fill(0);
    w2[0] = f(f(f(F[0]) - zhGhostLo) / f(centers32[0] - zhGhostLo));
    for (let k = 1; k < n; k++) w2[k] = f(f(f(F[k]) - centers32[k - 1]) / f(centers32[k] - centers32[k - 1]));
    w2[n] = f(f(f(F[n]) - centers32[n - 1]) / f(zhGhostHi - centers32[n - 1]));
    this.nz = n;
    this.zf = F;
    this.zh = centers;
    this.dzNominal = dzNom;
    this.mh = range(0, n - 1).map(k => f(dz32 / f(f(F[k + 1]) - f(F[k]))));
    this.mf = mfv;
    this.c2 = w2;
    this.c1 = w2.map(x => f(1.0 - x));
    if (n >= 3) {
      const zh32 = centers.map(f), zf32 = F.map(f);
      const dBot = f(zf32[1] - zf32[0]), dTop = f(zf32[n] - zf32[n - 1]);
      this.surfaceExtrapolation = VerticalGrid.fornbergCM1(f(zf32[0] / dBot),
        [f(zh32[0] / dBot), f(zh32[1] / dBot), f(zh32[2] / dBot)]);
      this.topExtrapolation = VerticalGrid.fornbergCM1(f(zf32[n] / dTop),
        [f(zh32[n - 1] / dTop), f(zh32[n - 2] / dTop), f(zh32[n - 3] / dTop)]);
    } else {
      this.surfaceExtrapolation = VerticalGrid.lagrange(centers.slice(0, 3), F[0]);
      this.topExtrapolation = VerticalGrid.lagrange(centers.slice(-3).reverse(), F[n]);
    }
  }

  static williamsonChenFaces({ nz, ztop, strBot, strTop, dzBot, dzTop }) {
    const zt = f(ztop), sb = f(strBot), st = f(strTop), db = f(dzBot), dt = f(dzTop);
    let nominalDz = f(0.5 * f(db + dt));
    const nk1 = Math.trunc(roundHalfAway(f(sb / db))), nk3 = Math.trunc(roundHalfAway(f(f(zt - st) / dt)));
    const nk2 = nz - (nk1 + nk3);
    if (!(Math.abs(f(f(nk1 * db) - sb)) <= 0.01 && Math.abs(f(f(f(nk2) * nominalDz) - f(st - sb))) < 0.01
      && Math.abs(f(f(f(nk3) * dt) - f(zt - st))) <= 0.01 && nk1 >= 0 && nk2 > 1 && nk3 >= 0)) return null;
    nominalDz = f(f(st - sb) / f(nk2));
    const c2 = f(f(nominalDz - db) / f(f(nominalDz * nominalDz) * f(nk2 - 1)));
    const c1 = fmaf(-c2, nominalDz, f(db / nominalDz));
    const zf = new Array(nz + 1).fill(0);
    for (let k = 1; k <= nk1 + 1; k++) zf[k - 1] = f(f(k - 1) * db);
    for (let k = nk1 + 1; k <= nk1 + nk2 + 1; k++) {
      const m = f(k - 1 - nk1);
      zf[k - 1] = fmaf(f(fmaf(f(c2 * m), nominalDz, c1) * m), nominalDz, zf[nk1]);
    }
    if (nk3 > 0) for (let k = nk1 + nk2 + 2; k <= nk1 + nk2 + nk3 + 1; k++) zf[k - 1] = f(zf[k - 2] + dt);
    return zf;
  }
  static requiredLevels({ ztop, strBot, strTop, dzBot, dzTop }) {
    return strBot / dzBot + (ztop - strTop) / dzTop + (strTop - strBot) / (0.5 * (dzBot + dzTop));
  }
  // buffer(values, device, label:)
  buffer(values, device, label) { return device.makeBuffer(Float32Array.from(values), label); }
}

// ---- Арена полей (заполнение нулями, как в выпускной сборке)
export class FieldArena {
  constructor({ context, grid, fields }) {
    this.grid = grid;
    const raw = grid.fieldBytes;
    this.stride = Math.ceil(raw / 256) * 256;
    const total = this.stride * fields.length;
    this.buffer = context.device.makeBuffer(total, 'arena');
    this.handles = {};
    fields.forEach((name, n) => { this.handles[name] = { name, offset: n * this.stride }; });
  }
  get fieldStride() { return this.stride; }
  get availableFields() { return Object.keys(this.handles); }
  zero(names) { for (const n of names) this.field(n).fill(0); }
  handle(name) {
    const h = this.handles[name];
    if (!h) throw new Error(`поле ${name} не выделено в арене; есть: ${Object.keys(this.handles).sort()}`);
    return h;
  }
  // withField(name) { p in ... } -> field(name) возвращает Float32Array поля
  field(name) { return new Float32Array(this.buffer.ab, this.handle(name).offset, this.grid.count); }
  withField(name, body) { return body(this.field(name)); }
  read(name, i, j, k) { return this.field(name)[this.grid.index(i, j, k)]; }
  write(name, i, j, k, v) { this.field(name)[this.grid.index(i, j, k)] = v; }
  get byteLength() { return this.buffer.length; }
}
