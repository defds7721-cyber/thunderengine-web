// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Шаг модели со структурами: AcousticParamsGPU, AcousticSchedule, GridDimsGPU,
// KernelBinder (без барьеров), SurfaceLayerRev, LargeScaleForcing.
// Соглашения - в шапке gpu.js и f32.js.
//
// Соседи (вызовы по именам эталона, позиционно):
//   microphysics.encode(e, arena, dt), .dispatchesPerCall, .setTimeStep(dt)
//   morrison.encode(e, arena, dt, radii), .dispatchesPerCall, .setTimeStep(dt)
//   rotunnoEmanuel.encode(e, arena, dt), .dispatchesPerCall
//   radiation.encodeCall(cb, arena, surface, modelTime, dt),
//     .isRadiationStep(modelTime, dt), .encodeApply(e, arena, thten1, tha, qv, dt),
//     .stateBuffer
import { f, fmaf, powf, logf, cosf, atanf } from './f32.js';
import { Grid, Constants } from './grid.js';
import { sfclayrevTables } from './sfclayrev_tables.js';

const roundHalfAway = x => Math.sign(x) * Math.round(Math.abs(x));
const bitsF = u => { const b = new Uint32Array([u]); return new Float32Array(b.buffer)[0]; };

// Байты setBytes: формат по символу на поле - f float, i int32, u uint32, d double.
export function pack(fmt, vals) {
  let n = 0;
  for (const c of fmt) n += c === 'd' ? 8 : 4;
  const dv = new DataView(new ArrayBuffer(n));
  let o = 0;
  [...fmt].forEach((c, k) => {
    const v = vals[k];
    if (c === 'f') { dv.setFloat32(o, v, true); o += 4; }
    else if (c === 'i') { dv.setInt32(o, v, true); o += 4; }
    else if (c === 'u') { dv.setUint32(o, v >>> 0, true); o += 4; }
    else { dv.setFloat64(o, v, true); o += 8; }
  });
  return new Uint8Array(dv.buffer);
}
const F1 = v => pack('f', [v]);
const I1 = v => pack('i', [v]);
const I2 = v => pack('ii', v);
const Fx2 = v => pack('ff', v);
const Fx3 = v => pack('ffff', [v[0], v[1], v[2], 0]);   // SIMD3<Float>: 16 байт, четвёртая полоса 0
const Fx4 = v => pack('ffff', v);

// ---- Акустика
export class AcousticParamsGPU {
  constructor({ dts, alph, kdiv, smeps }) {
    this.dts = f(dts); this.alph = f(alph); this.beta = f(1.0 - this.alph); this.kdiv = f(kdiv); this.smeps = f(smeps);
  }
  clone() { const p = Object.create(AcousticParamsGPU.prototype); Object.assign(p, this); return p; }
  bytes() { return pack('fffff', [this.dts, this.alph, this.beta, this.kdiv, this.smeps]); }
}

export class AcousticSchedule {
  static maxNsound = 192;
  static smallStep(minHorizontalSpacing, minVerticalSpacing = null, twoDimensional = false) {
    if (minVerticalSpacing == null) return f(f(f(0.60) * f(minHorizontalSpacing)) / f(360.0));
    const m = f(Math.min(minHorizontalSpacing, minVerticalSpacing));
    return f(f((twoDimensional ? f(0.60) : f(0.50)) * m) / f(360.0));
  }
  // init(dt:minHorizontalSpacing:twoDimensional:minVerticalSpacing:)
  static make({ dt, minHorizontalSpacing, twoDimensional, minVerticalSpacing = null }) {
    const dtsm = AcousticSchedule.smallStep(minHorizontalSpacing, minVerticalSpacing, twoDimensional);
    let n = Math.max(Math.trunc(roundHalfAway(dt / dtsm)), 4);
    if (n % 2 !== 0) n += 1;
    if (dt / n > dtsm) n += 2;
    if (n > AcousticSchedule.maxNsound) {
      throw new Error(`шаг по времени dt=${dt} с требует ${n} акустических подшагов при пределе ${AcousticSchedule.maxNsound}; нужен меньший dt`);
    }
    return new AcousticSchedule(n, dt);
  }
  // init(nsound:dt:)
  constructor(n, dt) {
    this.nsound = n; this.dt = dt;
    const l = [];
    let n1 = Math.max(Math.trunc(roundHalfAway(n / 3.0)), 1);
    let d1 = dt / (n1 * 3.0);
    if (d1 > dt / n) { n1 += 1; d1 = dt / (n1 * 3.0); }
    l.push({ count: n1, dts: d1 });
    l.push({ count: Math.trunc(n / 2), dts: dt / n });
    l.push({ count: n, dts: dt / n });
    this.loops = l;
  }
  get totalSubsteps() { return this.loops.reduce((a, x) => a + x.count, 0); }
}

// ---- Адвекция: GridDims (Layout.h)
export function gridDimsBytes(g) {
  return pack('iiiiifff', [g.nx, g.ny, g.nz, g.strideJ, g.strideK, f(1.0 / g.dx), f(1.0 / g.dy), f(1.0 / g.dz)]);
}

// ---- KernelBinder: привязки проходят в энкодер; барьеры не нужны
export class KernelBinder {
  constructor(encoder, arena, fieldStride) {
    this.encoder = encoder; this.arena = arena; this.fieldStride = fieldStride;
    this.baseOffsets = null; this.barriers = 0;
  }
  setBase(name, profile, index) {
    const o = this.baseOffsets?.[name];
    if (o !== undefined && o !== null) this.setBuffer(this.arena, o, index);
    else this.setBuffer(profile, 0, index);
  }
  // params: байты TerrainParamsGPU
  bindTerrain(planes, sigma, params) {
    const o = this.baseOffsets;
    if (!o || !planes || !sigma) return;
    ['gx', 'gxu', 'gy', 'gyv'].forEach((name, n) => { if (o[name] !== undefined) this.setBuffer(this.arena, o[name], 20 + n); });
    this.setBuffer(planes, 0, 24);
    this.setBuffer(sigma, 0, 25);
    this.setBytes(params, 26);
  }
  setBuffer(buffer, offset, index) { this.encoder.setBuffer(buffer, offset, index); }
  setBytes(bytes, index) { this.encoder.setBytes(bytes, index); }
  barrierIfNeeded() { }
}

// ---- SurfaceLayerRev
export const SurfaceLayerRev = {
  // Таблицы - копия снятых с эталона (sfclayrev_tables.js): libm эталона для
  // float даёт другие последние биты, чем счёт ниже (tablesComputed).
  tables() { return sfclayrevTables(); },
  tablesComputed() {
    const t = new Float32Array(4 * 1001);
    for (let n = 0; n <= 1000; n++) {
      const zs = f(f(n) * f(0.01));
      t[n] = SurfaceLayerRev.psimStableFull(zs);
      t[2002 + n] = SurfaceLayerRev.psihStableFull(zs);
      const zu = -f(f(0.01) * f(n));
      t[1001 + n] = SurfaceLayerRev.psimUnstableFull(zu);
      t[3003 + n] = SurfaceLayerRev.psihUnstableFull(zu);
    }
    return t;
  },
  psimStableFull(z) { return -f(f(6.1) * logf(f(z + powf(f(powf(z, 2.5) + 1), 0.4)))); },
  psihStableFull(z) { return -f(f(5.3) * logf(f(z + powf(f(powf(z, 1.1) + 1), bitsF(0x3f68ba2e))))); },
  sqrt3: bitsF(0x3fddb3d7), piHalf: bitsF(0x3fc90fdb), c4atan: bitsF(0x3fe82a95),
  psimUnstableFull(z) {
    const S = SurfaceLayerRev;
    const x = powf(fmaf(-z, 16, 1), 0.25);
    const a = logf(f(f(x + 1) * 0.5));
    const b = logf(f(fmaf(x, x, 1) * 0.5));
    const c = atanf(x);
    const psimk = f(fmaf(-c, 2, fmaf(a, 2, b)) + S.piHalf);
    const ym = powf(fmaf(-z, 10, 1), bitsF(0x3ea8f5c3));
    const d = logf(f(f(fmaf(ym, ym, ym) + 1) / 3));
    const e = f(atanf(f(fmaf(ym, 2, 1) / S.sqrt3)) * S.sqrt3);
    const psimc = f(fmaf(d, 1.5, -e) + S.c4atan);
    const z2 = f(z * z);
    return f(fmaf(psimc, z2, psimk) / f(z2 + 1));
  },
  psihUnstableFull(z) {
    const S = SurfaceLayerRev;
    const y = powf(fmaf(-z, 16, 1), 0.5);
    const a = logf(f(f(y + 1) * 0.5));
    const yh = powf(fmaf(-z, 34, 1), bitsF(0x3ea8f5c3));
    const d = logf(f(f(fmaf(yh, yh, yh) + 1) / 3));
    const e = f(atanf(f(fmaf(yh, 2, 1) / S.sqrt3)) * S.sqrt3);
    const psihc = f(fmaf(d, 1.5, -e) + S.c4atan);
    const z2 = f(z * z);
    return f(fmaf(a, 2, f(psihc * z2)) / f(z2 + 1));
  },
  // ConstsGPU: 19 float, nc int32, zero uint32
  consts(thermo, dx, dt, nc) {
    const rd = f(thermo.rd), cp = f(thermo.cp), rv = f(Constants.rv), xlv = f(thermo.xlv);
    return pack('ffffffffffffffffffiu', [cp, f(Constants.g), f(rd / cp), rd, rv, xlv, f(thermo.lv1), f(thermo.lv2),
      f(f(rv / rd) - 1), f(rd / rv), f(0.40), 100000, f(0.6112), f(17.67), f(29.65), f(273.15), dx, dt, nc, 0]);
  },
  pinFields: ['u', 'v', 'th', 't', 'qv', 'qc', 'qi', 'p', 'p8w', 'pi', 'dz', 'iamsat', 'rf'],
};

// ---- LargeScaleForcing
export class LargeScaleForcing {
  constructor({ testcase, thfrc, qvfrc, ug, vg, wprof }) {
    Object.assign(this, { testcase, thfrc, qvfrc, ug, vg, wprof });
    this.dvdr = []; this.hurricaneRadius = 1.0e30;
  }
  get needsDomainMeans() { return [6, 10].includes(this.testcase); }
  get appliesSubsidence() { return [3, 4, 5, 6, 7].includes(this.testcase); }
  get hasGeostrophic() { return this.ug.some(x => x !== 0) || this.vg.some(x => x !== 0); }
  static forTestcase(tc, zh, zf, u0, v0, umove, vmove) {
    const nk = zh.length;
    const thfrc = new Array(nk).fill(0), qvfrc = new Array(nk).fill(0), ug = new Array(nk).fill(0), vg = new Array(nk).fill(0);
    const wprof = new Array(nk + 1).fill(0);
    let dvdr = [], hurrRad = 1.0e30;
    if (tc === 6 || tc === 10) {
      hurrRad = 40000.0;
      dvdr = zh.map(z => -0.00085 * Math.max(0.0, 1.0 - z / 18000.0));
      const wmin = -0.01, z1 = 1000.0, z2 = 4000.0;
      for (let k = 0; k < nk; k++) {
        const z = zf[k];
        if (z <= z1) wprof[k] = 0.0 + (wmin - 0.0) * (z - 0.0) / (z1 - 0.0);
        else if (z <= z2) wprof[k] = wmin + (0.0 - wmin) * (z - z1) / (z2 - z1);
        else wprof[k] = 0.0;
      }
    } else if (tc === 4 || tc === 5) {
      const bigd = f(-3.75e-6);
      for (let k = 1; k < nk; k++) wprof[k] = bigd * zf[k];
    } else if (tc === 3) {
      const wmin = -0.0065, zw1 = 1500.0, zw2 = 2100.0;
      for (let k = 0; k < nk; k++) {
        const z = zf[k];
        if (z <= zw1) wprof[k] = 0.0 + (wmin - 0.0) * (z - 0.0) / (zw1 - 0.0);
        else if (z <= zw2) wprof[k] = wmin + (0.0 - wmin) * (z - zw1) / (zw2 - zw1);
        else wprof[k] = 0.0;
      }
      const radsfc = -2.0 / (3600.0 * 24.0), z1 = 1500.0, z2 = 2100.0;
      for (let k = 0; k < nk; k++) {
        const z = zh[k];
        if (z <= z1) thfrc[k] = radsfc;
        else if (z <= z2) thfrc[k] = radsfc + (0.0 - radsfc) * (z - z1) / (z2 - z1);
        else thfrc[k] = 0.0;
      }
      const qvsfc = -1.2e-8, q1 = 300.0, q2 = 500.0;
      for (let k = 0; k < nk; k++) {
        const z = zh[k];
        if (z <= q1) qvfrc[k] = -1.2e-8;
        else if (z <= q2) qvfrc[k] = qvsfc + (0.0 - qvsfc) * (z - q1) / (q2 - q1);
        else qvfrc[k] = 0.0;
      }
      for (let k = 0; k < nk; k++) { ug[k] = -10.0 + 0.0018 * zh[k]; vg[k] = 0.0; }
    } else if (tc === 7) {
      const wmin = -0.005, zw1 = 2260.0;
      for (let k = 0; k < nk; k++) { const z = zf[k]; wprof[k] = z <= zw1 ? 0.0 + (wmin - 0.0) * (z - 0.0) / (zw1 - 0.0) : wmin; }
      const thsfc = -2.5 / (3600.0 * 24.0);
      for (let k = 0; k < nk; k++) thfrc[k] = thsfc;
      const qv1 = -1.0 / 1000.0 / (3600.0 * 24.0), qv2 = 0.3456 / 1000.0 / (3600.0 * 24.0), zq = 2980.0;
      for (let k = 0; k < nk; k++) { const z = zh[k]; qvfrc[k] = z <= zq ? qv1 + (qv2 - qv1) * (z - 0.0) / (zq - 0.0) : qv2; }
      for (let k = 0; k < nk; k++) { ug[k] = u0[k]; vg[k] = v0[k]; }
    } else return null;
    for (let k = 0; k < nk; k++) { ug[k] -= umove; vg[k] -= vmove; }
    wprof[0] = 0.0; wprof[nk] = 0.0;
    const r = new LargeScaleForcing({ testcase: tc, thfrc, qvfrc, ug, vg, wprof });
    r.dvdr = dvdr; r.hurricaneRadius = hurrRad;
    return r;
  }
}

// ---- TimeStep.Fields
export class Fields {
  constructor(scalars, momentum) {
    this.scalars = [...scalars]; this.momentum = [...momentum];
    this.useTKE = false; this.usePressureTendency = true; this.terrain = false;
    this.useRayleigh = false; this.useLargeScalePG = false; this.cacheMoistureTurbulence = false;
  }
  clone() { const c = new Fields(this.scalars, this.momentum); Object.assign(c, this, { scalars: [...this.scalars], momentum: [...this.momentum] }); return c; }
  static terrainFieldNames = ['th0', 'pi0', 'rho0', 'rr0', 'rf0', 'rth0', 'qv0', 'qc0', 'qi0',
    'mh', 'mf', 'zf', 'c1', 'c2', 'tauh', 'tauf', 'gx', 'gxu', 'gy', 'gyv'];
  static kernelSpecies = ['qv', 'qc', 'qr', 'qi', 'qs', 'qg'];
  static zeroSpecies = 'qzero';
  static numberConcentrations = ['nci', 'ncs', 'ncr', 'ncg'];
  static get dry() { return new Fields(['th'], ['u', 'v', 'w']); }
  static get moistGoddardLFO() { return new Fields(['th', 'qv', 'qc', 'qr', 'qi', 'qs', 'qg'], ['u', 'v', 'w']); }
  static get moistWithTKE() { const x = Fields.moistGoddardLFO; x.useTKE = true; x.useRayleigh = true; return x; }
  static get moistWarmRain() { return new Fields(['th', 'qv', 'qc'], ['u', 'v', 'w']); }
  get advected() { return [...this.scalars, ...this.momentum]; }
  atTimeLevel(name) { return name + '_a'; }
  get isMoist() { return this.scalars.length > 1; }
  get needsZeroSpecies() { return this.isMoist && Fields.kernelSpecies.some(s => !this.scalars.includes(s)); }
  speciesField(n, suffix = '') { return this.scalars.includes(n) ? n + suffix : Fields.zeroSpecies; }
  withNumberConcentrations() {
    const x = this.clone();
    x.scalars = [...x.scalars, ...Fields.numberConcentrations.filter(s => !x.scalars.includes(s))];
    return x;
  }
  get stepTendencyFields() {
    return (this.useTKE || this.useRayleigh || this.useLargeScalePG) ? ['uten_t', 'vten_t', 'wten_t', 'thten_t'] : [];
  }
  get moistureTurbulenceFields() {
    return (this.cacheMoistureTurbulence && this.isMoist && this.useTKE) ? this.scalars.slice(1).map(s => 'qturb_' + s) : [];
  }
  get turbulenceFields() {
    return this.useTKE ? ['tke', 'tke_a', 'tketen', 'rr', 'rf', 'tketen_s', 's11', 's22', 's33', 's12', 's13', 's23',
      'defv', 'defh', 'nm', 'lenscl', 'dissten', 'epst', 'kmh', 'kmv', 'khh', 'khv', 'dwdx'] : [];
  }
  get stateFields() {
    const adv = this.advected;
    return [...adv, ...adv.map(s => s + '_a'),
      'ppterm', 'piadv', 'thv', 'pp3d', 'ppi', 'ppd', 'ppx', 'uten', 'vten', 'wten', 'ppten', 'buoy', 'prs', 'rho',
      ...(this.isMoist ? ['thterm', 'div3d'] : []),
      ...(this.isMoist && this.usePressureTendency ? ['qpten', 'qtten', 'qvten', 'qcten', 'qvten_t'] : []),
      ...this.turbulenceFields, ...this.stepTendencyFields, ...this.moistureTurbulenceFields,
      ...(this.terrain ? Fields.terrainFieldNames : []),
      ...(this.needsZeroSpecies ? [Fields.zeroSpecies] : [])];
  }
  get scratchFields() {
    return ['rru', 'rrv', 'rrw', 'fx', 'fy', 'fz', 'tend', 'divx', 'qk', 'pk1', 'pk2', 'mm', 'fpk', 'cA', 'cB', 'sadv',
      ...(this.terrain ? ['advz6'] : [])];
  }
  get arenaFields() { return [...this.stateFields, ...this.scratchFields]; }
}

// Вложенные типы TimeStep - простые объекты с умолчаниями эталона
export const SurfaceFluxes = () => ({
  constantRoughness: null, cecd: 3, cnstcd: 0.001, cnstce: 0.001, xland: 2, tsk0: 299.28, znt0: 0.01 / 100,
  mavail: 1.0, heatAndMoisture: true, constantFriction: null, constantFluxes: null, heatFluxCutoff: null,
  model: 1, testcase: 0, mostUseAverage: false,
});
export const PBL = () => ({ vertical: true, linf: 75, horizontal: true, lh: 100, lhref1: 100, lhref2: 1000 });
export const DNS = () => ({ viscosity: 16.23, prandtl: 1.0, wallCondition: 1, wallThetaBottom: 300.0, wallThetaTop: 300.0, th0r: 300.0 });
export const LandSurfacePBL = {
  make(lu, tsk, tmn) { return { lu, tsk, tmn }; },
  // (ALBD, SLMO, SFEM, SFZ0, THERIN) лета из run/LANDUSE.TBL
  summer(lu) {
    switch (lu) {
      case 3: return { albd: 18, slmo: f(0.50), sfem: f(0.985), sfz0: 10, therin: 4 };
      case 16: return { albd: 8, slmo: 1.0, sfem: f(0.98), sfz0: f(0.01), therin: 6 };
      case 18: return { albd: 14, slmo: f(0.35), sfem: f(0.95), sfz0: 40, therin: 5 };
      default: return null;
    }
  },
};

const SURFACE_PLANES = ['u1', 'v1', 's1', 'ust', 'znt', 'cd', 'ch', 'cq',
  's10', 'thflux', 'qvflux', 'psfc', 'qsfc', 'tsk',
  'avgu', 'avgv', 'avgs',
  'xland', 'mavail', 'tmn', 'emiss', 'thc', 'albd', 'hpbl',
  'zol', 'mol', 'regime', 'psim', 'psih', 'fm', 'fh',
  'hfx', 'qfx', 'lh', 'flhc', 'flqc', 'qgh', 'rmol',
  'u10', 'v10', 'th2', 't2', 'q2', 'gz1oz0', 'wspd', 'br',
  'ustm', 'ck', 'cka', 'cda', 'tst', 'qst', 'psiq', 'z0t', 'z0q',
  'chs', 'chs2', 'cqs2', 'cpmm', 'gsw', 'glw', 'capg', 'chklowq',
  'brcr', 'kpbl2d', 'wstar', 'delta', 'prkpp',
  'tslb1', 'tslb2', 'tslb3', 'tslb4', 'tslb5'];

export class TimeStep {
  static Fields = Fields;
  static SurfaceFluxes = SurfaceFluxes;
  static PBL = PBL;
  static DNS = DNS;
  static LandSurfacePBL = LandSurfacePBL;
  static surfacePlaneCount = 73;
  static surfacePlaneNames = SURFACE_PLANES;
  static threadgroup = [32, 4];
  static threadgroupColumns = [32, 1];

  static wenoEpsilon(name) {
    const epsilon = f(1.0e-18);
    if (name === 'th' || name === 'tke') return f(10 * epsilon);
    if (Fields.numberConcentrations.includes(name)) return f(1.0e6 * epsilon);
    return f(f(1.0e-2) * epsilon);
  }

  constructor({ context, grid, vertical, dt, fields, rho0, rr0, rf0, th0 = null, pi0 = null,
    qv0 = null, qc0 = null, qi0 = null, explicitAcoustics = false }) {
    this.explicitAcoustics = explicitAcoustics;
    if (vertical.nz !== grid.nz) throw new Error('вертикальная сетка не совпадает с grid.nz');
    if (rho0.length !== grid.nz || rr0.length !== grid.nz) throw new Error('профили rho0 и rr0 должны иметь nz значений');
    if (rf0.length !== grid.nz + 1) throw new Error('профиль rf0 должен иметь nz+1 значений');
    this.ctx = context; this.grid = grid; this.vertical = vertical; this.fields = fields; this.dt = dt;
    this.dimsBytes = gridDimsBytes(grid);
    this.dims = { rdx: f(1.0 / grid.dx), rdy: f(1.0 / grid.dy), rdz: f(1.0 / grid.dz) };
    this.acousticMinSpacing = grid.isTwoDimensional ? grid.hx.spacingRange.min : grid.finestSpacing;
    let minV = null;
    if (explicitAcoustics) {
      minV = Infinity;
      for (let k = 0; k < vertical.nz; k++) minV = Math.min(minV, vertical.zf[k + 1] - vertical.zf[k]);
    }
    this.acousticMinVertical = minV;
    this.schedule = AcousticSchedule.make({ dt, minHorizontalSpacing: this.acousticMinSpacing,
      twoDimensional: grid.isTwoDimensional, minVerticalSpacing: minV });
    const d = context.device;
    this.c1b = vertical.buffer(vertical.c1, d, 'c1');
    this.c2b = vertical.buffer(vertical.c2, d, 'c2');
    this.mhb = vertical.buffer(vertical.mh, d, 'mh');
    this.mfb = vertical.buffer(vertical.mf, d, 'mf');
    this.zfb = vertical.buffer(vertical.zf.map(f), d, 'zf');
    this.rho0b = vertical.buffer(rho0, d, 'rho0');
    this.hmb = d.makeBuffer(grid.metricValues(), 'hmetric');
    this.rr0b = vertical.buffer(rr0, d, 'rr0');
    this.rf0b = vertical.buffer(rf0, d, 'rf0');
    const th0v = th0 ?? new Array(grid.nz).fill(300.0);
    this.th0First = f(th0v[0]);
    const pi0v = pi0 ?? vertical.zh.map(z => f(1.0 - 9.81 * z / (1005.7 * 300.0)));
    this.th0b = vertical.buffer(th0v, d, 'th0');
    this.pi0b = vertical.buffer(pi0v, d, 'pi0');
    this.rth0b = vertical.buffer(Array.from(th0v, x => f(1.0 / f(x))), d, 'rth0');
    const edgeBuffer = (n, label) => d.makeBuffer(Math.max(n, 1) * 4, label);
    this.radbcwb = edgeBuffer(grid.ny, 'radbcw');
    this.radbceb = edgeBuffer(grid.ny, 'radbce');
    this.radbcsb = edgeBuffer(grid.nx, 'radbcs');
    this.radbcnb = edgeBuffer(grid.nx, 'radbcn');
    this.sfcb = d.makeBuffer(TimeStep.surfacePlaneCount * grid.strideJ * grid.strideK * 4, 'sfc');
    const fs = 4;
    this.massRowsb = d.makeBuffer(2 * grid.strideK * grid.nz * 2 * fs);
    this.massLevelsb = d.makeBuffer(2 * grid.nz * 2 * fs);
    this.massRefb = d.makeBuffer(3 * fs);
    this.massOutb = d.makeBuffer(5 * fs);
    const zeros = new Array(grid.nz).fill(0);
    this.qv0b = vertical.buffer(qv0 ?? zeros, d, 'qv0');
    this.qc0b = vertical.buffer(qc0 ?? zeros, d, 'qc0');
    this.qi0b = vertical.buffer(qi0 ?? zeros, d, 'qi0');

    // свойства (умолчания эталона)
    this.periodicX = false; this.periodicY = false; this.openX = false; this.openY = false; this.rigidX = false;
    this.surfaceRoughness = null;
    this._surfaceFluxes = null;
    this._landPBL = null;
    this.pblSurfaceUpdate = false;
    this.pblPinb = null; this.pblPoutb = null; this.pblTablesb = null; this.pblSatb = null;
    this.surfaceFluxAblation = false;
    this.scalarBoundaryFlux = 1;
    this.dns = null;
    this._terrain = null; this.tplanesb = null; this.tsigb = null;
    this.tparams = pack('ffffffff', [0, 0, 0, 0, 0, 0, 0, 0]);
    this.explicitVerticalDiffusion = false;
    this.noSlipBottom = false; this.noSlipTop = false;
    this.pbl = null;
    this.dissipativeHeating = false;
    this.conserveDryMass = false;
    this.coriolis = null;
    this.lspgU0b = null; this.lspgV0b = null;
    this.largeScalePGMode = 1;
    this.hurricaneRadius = 1.0e30;
    this.forcing = null;
    this.frcThb = this.frcQvb = this.frcUgb = this.frcVgb = this.frcWb = null;
    this.frcDvdrb = this.frcV0b = this.frcUb = this.frcVb = this.avgPartialb = null;
    this.tqNudge = false;
    this.nudgeTnb = this.nudgeQnb = this.nudgePartialb = null;
    this.nudgeActiveThisStep = false;
    this.modelTime = 0;
    this.domainMotion = [0, 0];
    this.skip = new Set();
    this.stopBeforeAcoustics = null; this.stopAfterSubstep = null; this.stopAfterMomentumAdvection = null;
    this.lastStageDt = 0;
    this.wenoScalars = false; this.wenoMomentum = false;
    this.turbulenceRampSeconds = null;
    this.simpleRadiation = false;
    this.kmScale = 1.0; this.momentumTurbScale = 1.0; this.kmFixed = 0.0; this.skipTkeAdvection = false;
    this.tauhb = this.taufb = this.u0b = this.v0b = null;
    this.rdalpha = f(3.3333333333e-3);
    this.rayleighToAverage = false; this.rayleighAvgb = null;
    this.rayleighZd = 15000.0;
    this._lateralDampingWidth = null; this.hdxb = null; this.hdyb = null;
    this.radiativeRelaxation = false;
    this.microphysics = null; this.morrison = null; this.rotunnoEmanuel = null;
    this.radiation = null; this.radiationStarted = false;
    this.mostPartialb = null;
    this.dispatchesPerStep = 0;
    this.concurrentDispatch = true;
    this.barriersPerStep = 0;
    this.stabilityb = null;
  }

  get usePressureTendency() { return this.fields.usePressureTendency; }
  get bbc3() { return this.surfaceRoughness != null || this._surfaceFluxes != null; }
  get hasMicrophysics() { return this.microphysics != null || this.morrison != null || this.rotunnoEmanuel != null; }

  // ---- surfaceFluxes { didSet }
  get surfaceFluxes() { return this._surfaceFluxes; }
  set surfaceFluxes(v) {
    this._surfaceFluxes = v;
    if (!v) return;
    const z0 = v.constantRoughness != null ? f(Math.max(1.0e-12, v.constantRoughness)) : f(f(0.01) / 100);
    this.setSurfacePlane(4, v.constantRoughness == null ? f(v.znt0) : z0);
    this.setSurfacePlane(13, f(v.tsk0));
  }
  get landPBL() { return this._landPBL; }
  set landPBL(v) { this._landPBL = v; if (v) this.initLandPBL(v); }

  initLandPBL(l) {
    const grid = this.grid, nc = grid.nx * grid.ny;
    if (!(l.lu.length === nc && l.tsk.length === nc && l.tmn.length === nc)) throw new Error('поверхность не по числу столбцов');
    if (!(grid.nz <= 64)) throw new Error('YSU: nz ≤ 64 (YSU_MAXK)');
    const d = this.ctx.device;
    this.pblPinb = d.makeBuffer(SurfaceLayerRev.pinFields.length * (grid.nz + 1) * nc * 4, 'pbl_in');
    this.pblPoutb = d.makeBuffer(9 * (grid.nz + 1) * nc * 4, 'pbl_out');
    this.pblTablesb = d.makeBuffer(SurfaceLayerRev.tables(), 'sfclayrev_tables');
    this.pblSatb = d.makeBuffer(grid.count * 4, 'iamsat');
    const dzs = new Array(5).fill(0), zs = new Array(5).fill(0);
    dzs[0] = f(0.01); zs[0] = f(0.5 * dzs[0]);
    for (let n = 1; n < 5; n++) { dzs[n] = f(2 * dzs[n - 1]); zs[n] = f(f(zs[n - 1] + f(0.5 * dzs[n - 1])) + f(0.5 * dzs[n])); }
    const plane = name => TimeStep.surfacePlaneNames.indexOf(name);
    const p = {};
    for (const name of ['xland', 'mavail', 'tmn', 'emiss', 'thc', 'albd', 'znt', 'tsk']) p[name] = new Array(nc).fill(0);
    for (let n = 1; n <= 5; n++) p['tslb' + n] = new Array(nc).fill(0);
    for (let c = 0; c < nc; c++) {
      const u = LandSurfacePBL.summer(l.lu[c]);
      if (!u) throw new Error(`lu_index ${l.lu[c]} не портирован (3, 16, 18)`);
      const xl = l.lu[c] === 16 ? 2 : 1;
      p.xland[c] = xl;
      p.albd[c] = f(u.albd / 100); p.thc[c] = f(u.therin / 100);
      p.emiss[c] = u.sfem; p.znt[c] = f(u.sfz0 / 100);
      p.mavail[c] = xl > 1.5 ? 1 : u.slmo;
      p.tsk[c] = f(l.tsk[c]); p.tmn[c] = f(l.tmn[c]);
      for (let n = 0; n < 5; n++) {
        p['tslb' + (n + 1)][c] = f(fmaf(p.tsk[c], f(zs[4] - zs[n]), f(p.tmn[c] * f(zs[n] - zs[0]))) / f(zs[4] - zs[0]));
      }
    }
    // порядок обхода словаря не важен: плоскости не пересекаются
    for (const [name, v] of Object.entries(p)) this.setSurfacePlane(plane(name), v);
    this.setSurfacePlane(plane('ust'), f(1.0e-6));
    this.setSurfacePlane(plane('qsfc'), f(0.00001));
    this.setSurfacePlane(plane('hpbl'), 100);
    this.setSurfacePlane(plane('psfc'), 100000);
  }

  bindSurfaceFlux(e, plane) {
    const grid = this.grid;
    const bytes = grid.strideJ * grid.strideK * 4;
    const use = ((this._surfaceFluxes?.heatAndMoisture ?? false) && plane != null && !this.surfaceFluxAblation) ? 1 : 0;
    e.setBuffer(this.sfcb, (plane ?? 0) * bytes, 14);
    e.setBytes(I1(use), 15);
    e.setBytes(I1(this.explicitVerticalDiffusion ? 1 : 0), 16);
    let wall = [0, 0, 0, 0];
    const dn = this.dns;
    if (dn && plane === 9) {
      wall = [f(dn.viscosity / dn.prandtl), f(dn.wallThetaBottom - dn.th0r), f(dn.wallThetaTop - dn.th0r), f(dn.wallCondition)];
    }
    e.setBytes(Fx4(wall), 17);
    e.setBytes(I1(this.scalarBoundaryFlux), 18);
  }

  // ---- terrain { didSet }: t - TerrainGeometry (terrain.js от F1)
  get terrain() { return this._terrain; }
  set terrain(t) {
    this._terrain = t;
    if (!t) { this.tplanesb = null; this.tsigb = null; return; }
    const d = this.ctx.device, vertical = this.vertical, grid = this.grid;
    const planes = Float32Array.from([...t.gz, ...t.rgz, ...t.gzu, ...t.rgzu, ...t.gzv, ...t.rgzv, ...t.dzdx, ...t.dzdy]);
    this.tplanesb = d.makeBuffer(planes, 'terrain_planes');
    const n1 = grid.nz + 1;
    const sig = new Float32Array(4 * n1);
    for (let k = 0; k < t.rds.length; k++) sig[k] = t.rds[k];
    for (let k = 0; k < t.rdsf.length; k++) sig[n1 + k] = t.rdsf[k];
    for (let k = 0; k < vertical.nz; k++) sig[2 * n1 + k] = vertical.zh[k];
    for (let k = 0; k <= vertical.nz; k++) sig[3 * n1 + k] = vertical.zf[k];
    this.tsigb = d.makeBuffer(sig, 'terrain_sigma');
    const cs = vertical.surfaceExtrapolation, ct = vertical.topExtrapolation;
    const zt = f(t.zt);
    this.tparams = pack('ffffffff', [zt, f(1.0 / zt), cs[0], cs[1], cs[2], ct[0], ct[1], ct[2]]);
  }
  terrainOffsets(arena) {
    if (this._terrain == null) return null;
    const o = {};
    for (const n of Fields.terrainFieldNames) o[n] = arena.handle(n).offset;
    return o;
  }

  setSurfacePlane(n, v) {
    const grid = this.grid, plane = grid.strideJ * grid.strideK, p = this.sfcb.f32;
    if (typeof v === 'number') { for (let o = 0; o < plane; o++) p[n * plane + o] = v; return; }
    if (v.length !== grid.nx * grid.ny) throw new Error('плоскость не по числу столбцов');
    for (let j = 0; j < grid.ny; j++) for (let i = 0; i < grid.nx; i++) p[n * plane + grid.index(i, j, 0)] = v[i + grid.nx * j];
  }
  surfacePlane(n) {
    const grid = this.grid, plane = grid.strideJ * grid.strideK, p = this.sfcb.f32, r = [];
    for (let c = 0; c < grid.nx * grid.ny; c++) r.push(p[n * plane + grid.index(c % grid.nx, Math.trunc(c / grid.nx), 0)]);
    return r;
  }

  setForcing(fc, v0 = []) {
    this.forcing = fc;
    if (!fc) { this.frcThb = this.frcQvb = this.frcUgb = this.frcVgb = this.frcWb = this.frcDvdrb = null; return; }
    const grid = this.grid, vertical = this.vertical, d = this.ctx.device;
    if (!(fc.thfrc.length === grid.nz && fc.wprof.length === grid.nz + 1)) throw new Error('профили форсинга не по сетке');
    this.frcThb = vertical.buffer(fc.thfrc.map(f), d, 'frc_th');
    this.frcQvb = vertical.buffer(fc.qvfrc.map(f), d, 'frc_qv');
    this.frcUgb = vertical.buffer(fc.ug.map(f), d, 'frc_ug');
    this.frcVgb = vertical.buffer(fc.vg.map(f), d, 'frc_vg');
    this.frcWb = vertical.buffer(fc.wprof.map(f), d, 'frc_wprof');
    if (fc.needsDomainMeans) {
      if (!(fc.dvdr.length === grid.nz && v0.length === grid.nz)) throw new Error('testcase 6/10: нужны dvdr и v0 по nz');
      this.frcDvdrb = vertical.buffer(fc.dvdr.map(f), d, 'frc_dvdr');
      this.frcV0b = vertical.buffer(v0.map(f), d, 'frc_v0');
      this.frcUb = d.makeBuffer(grid.nz * 4, 'frc_ufrc');
      this.frcVb = d.makeBuffer(grid.nz * 4, 'frc_vfrc');
      this.avgPartialb = d.makeBuffer(2 * grid.ny * grid.nz * 4, 'avg_uv_partial');
    }
  }

  enableTQNudge() {
    if (!(this.fields.isMoist && !this.fields.terrain)) throw new Error('tqnudge портирован для влажного набора без рельефа');
    if (!(this.fields.useTKE || this.fields.useRayleigh || this.fields.useLargeScalePG)) throw new Error('tqnudge кладёт в thten1 — нужно поле тенденций шага thten_t');
    this.tqNudge = true;
    const len = this.grid.nz * 4, d = this.ctx.device;
    this.nudgeTnb = d.makeBuffer(len, 'nudge_tn');
    this.nudgeQnb = d.makeBuffer(len, 'nudge_qn');
    this.nudgePartialb = d.makeBuffer(2 * this.grid.ny * len, 'nudge_partial');
  }

  setCoriolis(fcor, largeScalePG, mode = 1, u0 = [], v0 = []) {
    this.coriolis = f(fcor);
    if (largeScalePG !== this.fields.useLargeScalePG) throw new Error('lspgrad и Fields.useLargeScalePG расходятся');
    if (![1, 2, 3].includes(mode)) throw new Error(`lspgrad = ${mode} не портирован (есть 1, 2, 3)`);
    this.largeScalePGMode = mode;
    if (largeScalePG) {
      if (!(u0.length === this.grid.nz && v0.length === this.grid.nz)) throw new Error(`lspgrad=${mode} требует профили u0, v0 по nz значений`);
      this.lspgU0b = this.vertical.buffer(u0.map(f), this.ctx.device, 'lspg_u0');
      this.lspgV0b = this.vertical.buffer(v0.map(f), this.ctx.device, 'lspg_v0');
    }
  }

  setRayleigh(u0, v0, zd, rdalpha = f(3.3333333333e-3)) {
    this.rayleighZd = zd;
    this.rdalpha = f(rdalpha);
    const grid = this.grid, vertical = this.vertical;
    const zdF = f(zd), ztopF = f(vertical.zf[grid.nz]);
    const piF = f(3.1415926535897932384626433);
    const tau = z => {
      const zF = f(z);
      if (!(zF > zdF)) return 0;
      const arg = f(f(piF * f(zF - zdF)) / f(ztopF - zdF));
      return f(0.5 * f(1.0 - cosf(arg)));
    };
    const tauh = [], tauf = [];
    for (let k = 0; k < grid.nz; k++) tauh.push(tau(vertical.zh[k]));
    for (let k = 0; k <= grid.nz; k++) tauf.push(tau(vertical.zf[k]));
    const d = this.ctx.device;
    this.tauhb = vertical.buffer(tauh, d, 'tauh');
    this.taufb = vertical.buffer(tauf, d, 'tauf');
    this.u0b = vertical.buffer(Array.from(u0, f), d, 'u0');
    this.v0b = vertical.buffer(Array.from(v0, f), d, 'v0');
  }

  // ---- lateralDampingWidth { didSet }
  get lateralDampingWidth() { return this._lateralDampingWidth; }
  set lateralDampingWidth(xhd) {
    this._lateralDampingWidth = xhd;
    if (xhd == null) { this.hdxb = null; this.hdyb = null; return; }
    const weights = (h, n) => {
      const pi = f(Math.PI), w = f(xhd);
      const lo = f(h.face(0)), hi = f(h.face(n));
      const r = [];
      for (let i = 0; i < n; i++) {
        const x = f(h.xh[i + h.halo]);
        let v = 0;
        if (!(n > 1)) { r.push(0); continue; }
        const x1 = f(f(w + lo) - x);
        if (x1 > 0 && !h.axisymmetric) v = Math.max(v, f(0.5 * f(1.0 - cosf(f(f(pi * x1) / w)))));
        const x2 = f(x - f(hi - w));
        if (x2 > 0) v = Math.max(v, f(0.5 * f(1.0 - cosf(f(f(pi * x2) / w)))));
        r.push(v);
      }
      return r;
    };
    const d = this.ctx.device, grid = this.grid;
    const wx = weights(grid.hx, grid.nx), wy = weights(grid.hy, grid.ny);
    this.hdxb = d.makeBuffer(wx.length ? Float32Array.from(wx) : 4);
    this.hdyb = d.makeBuffer(wy.length ? Float32Array.from(wy) : 4);
  }

  enableStabilityReduction() {
    if (this.stabilityb) return;
    this.stabilityb = this.ctx.device.makeBuffer(8, 'stability');
  }

  setTimeStep(newDt, nsound) {
    this.dt = f(newDt);
    this.schedule = new AcousticSchedule(nsound, this.dt);
    this.microphysics?.setTimeStep(this.dt);
    this.morrison?.setTimeStep(this.dt);
  }

  setRadiativeSpeeds(west, east, south, north) {
    const put = (v, buf) => { const n = Math.min(v.length, buf.length / 4); for (let i = 0; i < n; i++) buf.f32[i] = v[i]; };
    put(west, this.radbcwb); put(east, this.radbceb); put(south, this.radbcsb); put(north, this.radbcnb);
  }
  radiativeSpeeds() {
    const get = b => Array.from(b.f32.subarray(0, b.length / 4));
    return { west: get(this.radbcwb), east: get(this.radbceb), south: get(this.radbcsb), north: get(this.radbcnb) };
  }
  setMassReference(mass1) {
    const p = this.massRefb.f32;
    p[0] = mass1; p[1] = mass1 - f(mass1); p[2] = 1;
  }
  get persistentStateBuffers() {
    return [this.sfcb, this.radbcwb, this.radbceb, this.radbcsb, this.radbcnb, this.massRefb,
      ...(this.radiation ? [this.radiation.stateBuffer] : [])];
  }

  encodeInitialRadiation(cb, arena) {
    const rad = this.radiation;
    if (!rad) return;
    this.radiationStarted = true;
    rad.encodeCall(cb, arena, this.sfcb, this.modelTime, this.dt);
  }

  encodeStability(cb, arena) {
    const out = this.stabilityb;
    if (!out) return;
    const e = cb.makeComputeCommandEncoder();
    const b = arena.buffer, off = n => arena.handle(n).offset, grid = this.grid;
    const d = f(this.dt), dm = this.dims;
    const p = pack('fffffii', [f(f(0.5 * d) * dm.rdx), f(f(0.5 * d) * dm.rdy), f(f(0.5 * d) * dm.rdz),
      f(f(d * dm.rdx) * dm.rdx), f(f(d * dm.rdy) * dm.rdy), grid.isTwoDimensional ? 1 : 0, this.fields.useTKE ? 1 : 0]);
    e.setComputePipelineState(this.ctx.pipeline('stability_max'));
    e.setBytes(this.dimsBytes, 0);
    e.setBytes(p, 1);
    e.setBuffer(b, off('u'), 2);
    e.setBuffer(b, off('v'), 3);
    e.setBuffer(b, off('w'), 4);
    const t = this.terrainOffsets(arena);
    if (t) e.setBuffer(b, t.mh, 5); else e.setBuffer(this.mhb, 0, 5);
    const kf = this.fields.useTKE ? ['kmh', 'kmv', 'khh'] : ['u', 'u', 'u'];
    kf.forEach((n, i) => e.setBuffer(b, off(n), 6 + i));
    e.setBuffer(out, 0, 9);
    e.setBuffer(this.hmb, 0, Grid.metricBufferIndex);
    this.ctx.checkedDispatch(e, 'stability_max', [grid.nx, grid.ny, grid.nz], [32, 4, 1]);
    e.endEncoding();
  }

  encodeStateSwap(cb, arena) {
    const blit = cb.makeBlitCommandEncoder();
    const bytes = this.grid.count * 4;
    const tkePair = this.fields.useTKE ? [['tke', 'tke_a']] : [];
    for (const [src, dst] of [...this.fields.advected.map(s => [s, this.fields.atTimeLevel(s)]), ['pp3d', 'ppi'], ...tkePair]) {
      blit.copy(arena.buffer, arena.handle(src).offset, arena.buffer, arena.handle(dst).offset, bytes);
    }
    blit.endEncoding();
  }

  encodeMassSums(enc, rhoOffset, ppOffset, b) {
    const grid = this.grid, fs = 2 * 4;
    const rowBytes = grid.strideK * grid.nz * fs;
    enc('mass_row_sums', [grid.ny, grid.nz, 1], [32, 1, 1], false, e => {
      e.setBuffer(b, rhoOffset, 1);
      e.setBase('pi0', this.pi0b, 2);
      e.setBuffer(b, ppOffset, 3);
      e.setBase('mh', this.mhb, 4);
      e.setBuffer(this.massRowsb, 0, 5);
      e.setBuffer(this.massRowsb, rowBytes, 6);
      e.setBuffer(this.hmb, 0, Grid.metricBufferIndex);
    });
    enc('mass_level_sums', [grid.nz, 1, 1], [32, 1, 1], false, e => {
      e.setBuffer(this.massRowsb, 0, 1);
      e.setBuffer(this.massRowsb, rowBytes, 2);
      e.setBuffer(this.massLevelsb, 0, 3);
      e.setBuffer(this.massLevelsb, grid.nz * fs, 4);
    });
  }

  // Один большой шаг в командный буфер.
  encode(cb, arena, base) {
    const ctx = this.ctx, grid = this.grid, vertical = this.vertical, fields = this.fields, skip = this.skip;
    const self = this;
    let count = 0;
    const params = base.clone();
    const rad0 = this.radiation;
    if (rad0 && !this.radiationStarted) {
      this.radiationStarted = true;
      if (this.modelTime === 0) {
        rad0.encodeCall(cb, arena, this.sfcb, 0, this.dt);
        count += 1;
      }
    }
    const doradThisStep = this.radiation?.isRadiationStep(this.modelTime, this.dt) ?? false;
    const b = arena.buffer;
    const off = n => arena.handle(n).offset;
    const baseOffsets = this.terrainOffsets(arena);
    const tpar = this.tparams;
    const bindTerrain = e => e.bindTerrain(this.tplanesb, this.tsigb, tpar);
    const periodic = [this.openX ? 0 : 1, this.openY ? 0 : 1];
    const tg3 = [TimeStep.threadgroup[0], TimeStep.threadgroup[1], 1];
    const tgc = [TimeStep.threadgroupColumns[0], TimeStep.threadgroupColumns[1], 1];
    const H = Grid.halo;

    let shared = null, binder = null;
    const fieldStride = arena.fieldStride;
    const endShared = () => {
      if (shared) shared.endEncoding();
      shared = null; binder = null;
    };
    const shareEncoder = () => {
      if (binder != null) endShared();
      if (!shared) shared = cb.makeComputeCommandEncoder();
      return shared;
    };
    const enc = (kernel, gs, tg, withAcoustic, bind) => {
      if (shared != null && this.concurrentDispatch && binder == null) endShared();
      if (shared == null) {
        shared = cb.makeComputeCommandEncoder();
        binder = this.concurrentDispatch ? new KernelBinder(shared, b, fieldStride) : null;
        if (binder) binder.baseOffsets = baseOffsets;
      }
      const kb = binder ?? new KernelBinder(shared, b, fieldStride);
      kb.baseOffsets = baseOffsets;
      const e = kb.encoder;
      e.setComputePipelineState(ctx.pipeline(kernel));
      kb.setBytes(this.dimsBytes, 0);
      kb.setBuffer(this.hmb, 0, Grid.metricBufferIndex);
      if (withAcoustic) kb.setBytes(params.bytes(), 1);
      bind(kb);
      e.dispatchThreads(gs, tg);
      count += 1;
    };

    const terrainBcwsfc = acoustic => {
      if (this._terrain == null) return;
      enc('terrain_bcwsfc', [grid.nx + 2 * H, grid.ny + 2 * H, 1], [8, 8, 1], acoustic, e => {
        e.setBuffer(b, off('u'), 1);
        e.setBuffer(b, off('v'), 2);
        e.setBuffer(b, off('w'), 3);
        e.setBytes(I2(periodic), 4);
        bindTerrain(e);
      });
    };
    const terrainRrw = () => {
      if (this._terrain == null) return;
      enc('terrain_rrw', [grid.nx + 2 * H, grid.ny + 2 * H, Math.max(grid.nz - 1, 1)], tg3, false, e => {
        ['rru', 'rrv', 'rrw'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
        bindTerrain(e);
      });
    };

    const full = [grid.nx, grid.ny, grid.nz];
    const fullU = [grid.nx + 1, grid.ny, grid.nz];
    const fullV = [grid.nx, grid.ny + 1, grid.nz];
    const fullW = [grid.nx, grid.ny, grid.nz + 1];
    const stag = [grid.nx + 1, grid.ny + 1, grid.nz];
    const stagCols = [grid.nx + 1, grid.ny + 1, 1];
    const cols = [grid.nx, grid.ny, 1];
    const whole = [grid.strideJ, grid.strideK, grid.nz + 1];

    const encodeDiabaticUnapply = () => {
      const dtb = F1(f(this.dt));
      enc('diabatic_unapply', full, tg3, false, e => {
        e.setBytes(dtb, 1);
        ['pp3d', 'th', 'qv', 'qc', 'qpten', 'qtten', 'qvten', 'qcten'].forEach((n, i) => e.setBuffer(b, off(n), i + 2));
      });
    };
    const open = I2([this.openX ? 1 : 0, this.openY ? 1 : 0]);
    const anyOpen = this.openX || this.openY;
    const axi = grid.hx.axisymmetric;
    const fcorAxi = F1(f(skip.has('coriolis') ? 0 : (this.coriolis ?? 0)));
    let inAcoustics = false;
    const isU = name => name.startsWith('u') || name === 'rru';
    const isV = name => name.startsWith('v') || name === 'rrv';
    const rigidHalo = name => {
      if (!this.rigidX) return;
      if (inAcoustics && isU(name)) return;
      const mode = isU(name) ? 1 : (isV(name) && grid.hx.axisymmetric ? 2 : 0);
      enc('bc_rigid_x', [H + 1, grid.ny + 1 + 2 * H, grid.nz + 1], [H + 1, 8, 1], false, e => {
        e.setBuffer(b, off(name), 1);
        e.setBytes(I1(mode), 2);
      });
    };
    const openHalo = name => {
      if (this.openX) {
        const st = isU(name) ? 1 : 0;
        enc('bc_open_x', [H + 1, grid.ny + 1 + 2 * H, grid.nz + 1], [H + 1, 8, 1], false, e => {
          e.setBuffer(b, off(name), 1);
          e.setBytes(I1(st), 2);
        });
      }
      if (this.openY) {
        const st = isV(name) ? 1 : 0;
        enc('bc_open_y', [H + 1, grid.nx + 1 + 2 * H, grid.nz + 1], [H + 1, 8, 1], false, e => {
          e.setBuffer(b, off(name), 1);
          e.setBytes(I1(st), 2);
        });
      }
    };
    const openTurbFlux = () => {
      if (!anyOpen) return;
      enc('turb_openbc_flux', [Math.max(grid.nx, grid.ny) + 1, grid.nz + 1, 1], tgc, false, e => {
        e.setBuffer(b, off('fx'), 1);
        e.setBuffer(b, off('fy'), 2);
        e.setBytes(open, 3);
      });
    };
    const openStress = () => {
      if (this.openX) {
        enc('turb_openbc_stress_x', [grid.ny + 2, grid.nz, 1], tgc, false, e => {
          e.setBuffer(b, off('s11'), 1);
          e.setBuffer(b, off('s12'), 2);
        });
      }
      if (this.openY) {
        enc('turb_openbc_stress_y', [grid.nx + 2, grid.nz, 1], tgc, false, e => {
          e.setBuffer(b, off('s22'), 1);
          e.setBuffer(b, off('s12'), 2);
        });
      }
    };

    // ---- затухание Рэлея (solve1.F:475)
    const rayleighOn = fields.useRayleigh && !skip.has('rayleigh');
    if (rayleighOn && this.tauhb && this.taufb && this.u0b && this.v0b) {
      const alpha = F1(this.rdalpha);
      const toAvg = I1(this.rayleighToAverage ? 1 : 0);
      if (this.rayleighToAverage) {
        if (!(!grid.isStretched && this._terrain == null)) throw new Error('irdamp=2 портирован без растяжения по горизонтали и без рельефа (param.F:1559)');
        if (!this.rayleighAvgb) this.rayleighAvgb = ctx.device.makeBuffer(3 * grid.nz * 4, 'rayleigh_avg');
        const tem = f(f(grid.dx) * f(grid.dy));
        const lx = f(f(grid.nx) * f(grid.dx)), ly = f(f(grid.ny) * f(grid.dy));
        const temd = pack('d', [1.0 / (lx * ly)]);
        enc('rayleigh_avg', [3 * grid.nz, 1, 1], [32, 1, 1], false, e => {
          e.setBuffer(b, off('u_a'), 1);
          e.setBuffer(b, off('v_a'), 2);
          e.setBuffer(b, off('th_a'), 3);
          e.setBase('th0', this.th0b, 4);
          e.setBytes(F1(tem), 5);
          e.setBytes(temd, 6);
          e.setBuffer(this.rayleighAvgb, 0, 7);
        });
      }
      enc('rayleigh_damping', [grid.nx + 1, grid.ny + 1, grid.nz + 1], tg3, false, e => {
        ['u_a', 'v_a', 'w_a', 'th_a'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
        e.setBuffer(this.u0b, 0, 5);
        e.setBuffer(this.v0b, 0, 6);
        e.setBase('tauh', this.tauhb, 7);
        e.setBase('tauf', this.taufb, 8);
        e.setBytes(alpha, 9);
        ['uten_t', 'vten_t', 'wten_t', 'thten_t'].forEach((n, i) => e.setBuffer(b, off(n), i + 10));
        const lat = I1(this.hdxb != null ? 1 : 0);
        e.setBuffer(this.hdxb ?? this.taufb, 0, 14);
        e.setBuffer(this.hdyb ?? this.taufb, 0, 15);
        e.setBytes(lat, 16);
        e.setBytes(toAvg, 17);
        e.setBuffer(this.rayleighAvgb ?? this.taufb, 0, 18);
        e.setBase('th0', this.th0b, 19);
      });
    }
    if (fields.useRayleigh && !rayleighOn && !fields.useTKE && !fields.useLargeScalePG) {
      for (const fl of fields.stepTendencyFields) enc('turb_zero', whole, tg3, false, e => e.setBuffer(b, off(fl), 1));
    }

    // ---- крупномасштабный градиент давления (solve1.F:659-674)
    if (fields.useLargeScalePG && this.coriolis != null && this.lspgU0b && this.lspgV0b) {
      const fcor = this.coriolis;
      if (!rayleighOn) {
        for (const fl of fields.stepTendencyFields) enc('turb_zero', whole, tg3, false, e => e.setBuffer(b, off(fl), 1));
      }
      const mode2 = this.largeScalePGMode === 2;
      if (mode2 && !(this.frcUgb && this.frcVgb)) throw new Error('lspgrad=2 без профилей ug/vg (testcase)');
      const lp = pack('ffffi', [fcor, f(this.domainMotion[0]), f(this.domainMotion[1]), f(1.0 / f(this.hurricaneRadius)),
        mode2 ? 1 : this.largeScalePGMode]);
      enc('lspgrad_uv', stag, tg3, false, e => {
        e.setBuffer(mode2 ? this.frcUgb : this.lspgU0b, 0, 1);
        e.setBuffer(mode2 ? this.frcVgb : this.lspgV0b, 0, 2);
        e.setBytes(lp, 3);
        e.setBuffer(b, off('uten_t'), 5);
        e.setBuffer(b, off('vten_t'), 6);
      });
    }

    const turbHalo = name => {
      const sizeX = [H + 1, grid.ny + 1 + 2 * H, grid.nz + 1];
      const sizeY = [H + 1, grid.nx + 1 + 2 * H, grid.nz + 1];
      const tg = [H + 1, 8, 1];
      if (this.periodicX) enc('bc_periodic_x', sizeX, tg, false, e => e.setBuffer(b, off(name), 1));
      if (this.periodicY) enc('bc_periodic_y', sizeY, tg, false, e => e.setBuffer(b, off(name), 1));
      openHalo(name);
      rigidHalo(name);
    };

    // ---- sfcmodel = 3 + SLAB + YSU
    const pblConsts = () => SurfaceLayerRev.consts(ctx.thermo, f(grid.dx), f(this.dt), grid.nx * grid.ny);
    const encodeLandPBL = () => {
      const pin = this.pblPinb, pout = this.pblPoutb, tab = this.pblTablesb, sat = this.pblSatb;
      if (!(pin && pout && tab && sat)) return;
      if (!(this._terrain == null && !grid.isStretched)) throw new Error('sfcmodel = 3: без рельефа и горизонтального растяжения');
      const pc = pblConsts();
      const cgs = vertical.surfaceExtrapolation, cgt = vertical.topExtrapolation;
      const pp = pack('fffffffi', [cgs[0], cgs[1], cgs[2], cgt[0], cgt[1], cgt[2], f(grid.dz), fields.isMoist ? 1 : 0]);
      enc('pbl_prep', [grid.nx, grid.ny, grid.nz + 1], tg3, false, e => {
        e.setBytes(pc, 1);
        e.setBytes(pp, 2);
        const q = fields.isMoist;
        ['u_a', 'v_a', 'th_a', 'ppi', q ? fields.speciesField('qv', '_a') : 'th_a',
          q ? fields.speciesField('qc', '_a') : 'th_a',
          q ? fields.speciesField('qi', '_a') : 'th_a', 'prs', 'rf'].forEach((n, i) => e.setBuffer(b, off(n), 3 + i));
        e.setBuffer(sat, 0, 12);
        e.setBase('th0', this.th0b, 13);
        e.setBase('pi0', this.pi0b, 14);
        e.setBase('c1', this.c1b, 15);
        e.setBase('c2', this.c2b, 16);
        e.setBase('mh', this.mhb, 17);
        e.setBuffer(pin, 0, 18);
        e.setBuffer(this.sfcb, 0, 19);
      });
      const cols2 = [grid.nx, grid.ny, 1], tg2 = [64, 1, 1];
      const column = (kernel, third) => enc(kernel, cols2, tg2, false, e => {
        e.setBytes(pc, 1);
        e.setBuffer(pin, 0, 2);
        e.setBuffer(third, 0, 3);
        e.setBuffer(this.sfcb, 0, 4);
      });
      column('sfclayrev_col', tab);
      if (this.pblSurfaceUpdate) column('slab_col', tab);
      const slab = I1(this.pblSurfaceUpdate ? 1 : 0);
      enc('sfc3_post', cols2, tg2, false, e => {
        e.setBytes(pc, 1);
        e.setBuffer(pin, 0, 2);
        e.setBytes(slab, 3);
        e.setBuffer(this.sfcb, 0, 4);
      });
      column('ysu_col', pout);
      this.pblSurfaceUpdate = true;
    };
    const ysuApply = (mode, field, dst) => {
      const pout = this.pblPoutb;
      if (!pout) return;
      const pc = pblConsts();
      const ap = pack('iiii', [mode, field, this.periodicX ? 1 : 0, this.periodicY ? 1 : 0]);
      enc('ysu_apply', [grid.nx + 1, grid.ny + 1, grid.nz], tg3, false, e => {
        e.setBytes(pc, 1);
        e.setBytes(ap, 2);
        e.setBuffer(pout, 0, 3);
        e.setBuffer(b, off(dst), 4);
      });
    };

    // ---- подсеточная турбулентность (solve1.F:395-440)
    if (fields.useTKE && !skip.has('turbulence')) {
      const zeroList = [...fields.turbulenceFields.filter(x => !['tke', 'tke_a', 'rr', 'rf'].includes(x)),
        ...((rayleighOn || fields.useLargeScalePG) ? [] : fields.stepTendencyFields)];
      for (const fl of zeroList) enc('turb_zero', whole, tg3, false, e => e.setBuffer(b, off(fl), 1));
      const cgs = vertical.surfaceExtrapolation, cgt = vertical.topExtrapolation;
      enc('turb_rho_faces', [grid.nx + 4, grid.ny + 4, grid.nz + 1], tg3, false, e => {
        e.setBuffer(b, off('rho'), 1);
        e.setBase('c1', this.c1b, 2);
        e.setBase('c2', this.c2b, 3);
        e.setBuffer(b, off('rr'), 4);
        e.setBuffer(b, off('rf'), 5);
        e.setBytes(Fx3(cgs), 6);
        e.setBytes(Fx3(cgt), 7);
      });
      const haloWide = [grid.nx + 2, grid.ny + 2, grid.nz + 1];
      const ysuPath = this._landPBL != null;
      if (!ysuPath) {
        enc('turb_def_centers', haloWide, tg3, false, e => {
          ['u_a', 'v_a', 'w_a', 'rho'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
          e.setBase('mh', this.mhb, 5);
          ['s11', 's22', 's33', 's12'].forEach((n, i) => e.setBuffer(b, off(n), i + 6));
        });
        enc('turb_def_faces', haloWide, tg3, false, e => {
          ['u_a', 'v_a', 'w_a', 'rf'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
          e.setBase('mf', this.mfb, 5);
          e.setBuffer(b, off('s13'), 6);
          e.setBuffer(b, off('s23'), 7);
        });
        enc('turb_def_assemble', full, tg3, false, e => {
          ['s11', 's22', 's33', 's12', 's13', 's23'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
          e.setBase('c1', this.c1b, 7);
          e.setBase('c2', this.c2b, 8);
          e.setBuffer(b, off('rf'), 9);
          e.setBuffer(b, off('defv'), 10);
          e.setBuffer(b, off('defh'), 11);
        });
        openStress();
      }
      enc('turb_nm', full, tg3, false, e => {
        e.setBuffer(b, off('th_a'), 1);
        e.setBuffer(b, off('pp3d'), 2);
        e.setBase('th0', this.th0b, 3);
        e.setBase('pi0', this.pi0b, 4);
        e.setBuffer(b, off('prs'), 5);
        Fields.kernelSpecies.forEach((n, i) => e.setBuffer(b, off(fields.isMoist ? fields.speciesField(n, '_a') : 'th_a'), i + 6));
        e.setBase('c1', this.c1b, 12);
        e.setBase('c2', this.c2b, 13);
        e.setBase('mf', this.mfb, 14);
        e.setBuffer(b, off('nm'), 15);
        e.setBytes(I1(fields.isMoist ? 1 : 0), 16);
        if (this.pblSatb && ysuPath) e.setBuffer(this.pblSatb, 0, 17);
        else e.setBuffer(b, off('nm'), 17);
        e.setBytes(I1(ysuPath ? 1 : 0), 18);
      });
      if (ysuPath) encodeLandPBL();
      const plane2D = [grid.strideJ, grid.strideK, 1];
      if (this.bbc3) {
        const sp = pack('ffffii', [f(this.domainMotion[0]), f(this.domainMotion[1]), f(vertical.zh[0]), f(this.surfaceRoughness ?? 1),
          this.periodicX ? 1 : 0, this.periodicY ? 1 : 0]);
        enc('sfc_layer', plane2D, tg3, false, e => {
          e.setBuffer(b, off('u_a'), 1);
          e.setBuffer(b, off('v_a'), 2);
          e.setBytes(sp, 3);
          e.setBuffer(this.sfcb, 0, 4);
        });
      }
      const sf = this._surfaceFluxes;
      if (sf && sf.model === 5) {
        if (fields.isMoist) throw new Error('sfcmodel=5 только для сухого прогона (sfcphys.F:905 — stop 11211)');
        const mp = pack('fffiif', [f(vertical.zh[0]), this.th0First, f(this.modelTime), sf.testcase, sf.mostUseAverage ? 1 : 0, f(0.24)]);
        if (sf.mostUseAverage) {
          if (!this.mostPartialb) this.mostPartialb = ctx.device.makeBuffer(4 * grid.ny * 4, 'most_partial');
          const th0f = F1(this.th0First);
          enc('sfc_most_sums_j', [grid.ny, 1, 1], [32, 1, 1], false, e => {
            e.setBuffer(b, off('th_a'), 1);
            e.setBytes(th0f, 2);
            e.setBuffer(this.sfcb, 0, 3);
            e.setBuffer(this.mostPartialb, 0, 4);
          });
          enc('sfc_most_avg', cols, tgc, false, e => {
            e.setBytes(mp, 1);
            e.setBuffer(b, off('th_a'), 2);
            e.setBuffer(this.mostPartialb, 0, 3);
            e.setBuffer(this.sfcb, 0, 4);
          });
        } else {
          enc('sfc_most', cols, tgc, false, e => {
            e.setBytes(mp, 1);
            e.setBuffer(b, off('th_a'), 2);
            e.setBuffer(this.sfcb, 0, 3);
          });
        }
        const per = I2([this.periodicX ? 1 : 0, this.periodicY ? 1 : 0]);
        enc('sfc_halo2d', plane2D, tg3, false, e => {
          e.setBuffer(this.sfcb, 0, 1);
          e.setBytes(per, 2);
        });
      } else if (sf) {
        const ex = vertical.surfaceExtrapolation;
        const fp = pack('ffffffffiiiiiifffffi', [f(vertical.zh[0]), f(sf.cnstcd), f(sf.cnstce), f(sf.xland), f(sf.mavail),
          ex[0], ex[1], ex[2], sf.constantRoughness != null ? 1 : 0, sf.cecd, sf.heatAndMoisture ? 1 : 0, fields.isMoist ? 1 : 0,
          sf.constantFriction != null ? 1 : 0, sf.constantFluxes != null ? 1 : 0,
          f(sf.constantFriction ?? 0), f(sf.constantFluxes?.heat ?? 0), f(sf.constantFluxes?.moisture ?? 0),
          f(sf.heatFluxCutoff ?? -1), f(this.modelTime), sf.testcase]);
        enc('sfc_cecd', cols, tgc, false, e => {
          e.setBytes(fp, 1);
          e.setBuffer(this.sfcb, 0, 2);
        });
        if (sf.heatAndMoisture) {
          enc('sfc_flux', cols, tgc, false, e => {
            e.setBytes(fp, 1);
            e.setBuffer(this.sfcb, 0, 2);
            e.setBuffer(b, off('prs'), 3);
            e.setBuffer(b, off('th_a'), 4);
            e.setBuffer(b, off(fields.isMoist ? 'qv_a' : 'th_a'), 5);
            e.setBase('th0', this.th0b, 6);
          });
        }
        const per = I2([this.periodicX ? 1 : 0, this.periodicY ? 1 : 0]);
        enc('sfc_halo2d', plane2D, tg3, false, e => {
          e.setBuffer(this.sfcb, 0, 1);
          e.setBytes(per, 2);
        });
      }
      if (ysuPath) {
        // ipbl = 1: коэффициенты - внутри YSU
      } else if (this.dns) {
        const dn = this.dns;
        const kk = Fx2([f(dn.viscosity), f(dn.viscosity / dn.prandtl)]);
        enc('turb_const_k', whole, tg3, false, e => {
          e.setBytes(kk, 1);
          ['kmh', 'kmv', 'khh', 'khv'].forEach((n, i) => e.setBuffer(b, off(n), i + 2));
        });
      } else if (this.pbl) {
        const pb = this.pbl;
        const pp = pack('fffffifiii', [f(pb.linf), f(pb.lh), f(pb.lhref1), f(pb.lhref2), f(this._surfaceFluxes?.xland ?? 2),
          this._surfaceFluxes != null ? 1 : 0,
          f(this.surfaceRoughness != null ? Math.max(1.0e-12, this.surfaceRoughness) : 1.0e-6),
          this.dissipativeHeating ? 1 : 0, pb.vertical ? 1 : 0, pb.horizontal ? 1 : 0]);
        enc('turb_pbl_coef', full, tg3, false, e => {
          e.setBytes(pp, 1);
          e.setBuffer(b, off('nm'), 2);
          e.setBuffer(b, off('defv'), 3);
          e.setBuffer(b, off('defh'), 4);
          e.setBase('zf', this.zfb, 5);
          e.setBuffer(this.sfcb, 0, 6);
          ['kmh', 'kmv', 'khh', 'khv', 'dissten'].forEach((n, i) => e.setBuffer(b, off(n), i + 7));
        });
        for (const n of ['kmh', 'kmv', 'khh', 'khv']) turbHalo(n);
        const b3 = I1(this.bbc3 ? 1 : 0);
        enc('turb_pbl_bottom', plane2D, tg3, false, e => {
          e.setBytes(pp, 1);
          e.setBuffer(this.sfcb, 0, 2);
          e.setBytes(b3, 3);
          ['kmh', 'kmv', 'khh', 'khv'].forEach((n, i) => e.setBuffer(b, off(n), i + 4));
        });
      } else {
        const kms = F1(this.kmScale);
        enc('turb_km_kh', full, tg3, false, e => {
          e.setBuffer(b, off('tke_a'), 1);
          e.setBuffer(b, off('nm'), 2);
          e.setBase('mf', this.mfb, 3);
          ['kmh', 'kmv', 'khh', 'khv', 'lenscl', 'dissten'].forEach((n, i) => e.setBuffer(b, off(n), i + 4));
          e.setBytes(kms, 10);
          e.setBytes(F1(this.kmFixed), 11);
          const tr = this.turbulenceRampSeconds;
          e.setBytes(F1(f(tr != null ? Math.min(1.0, Math.max(0.0, this.modelTime / tr)) : 1.0)), 12);
        });
        for (const n of ['kmh', 'kmv', 'khh', 'khv']) turbHalo(n);
        if (this.bbc3) {
          const znt = F1(f(this.surfaceRoughness ?? 1));
          const zntField = I1(this._surfaceFluxes != null ? 1 : 0);
          enc('tke_sfc_bc', plane2D, tg3, false, e => {
            e.setBuffer(this.sfcb, 0, 1);
            e.setBytes(znt, 2);
            e.setBytes(zntField, 7);
            ['kmh', 'kmv', 'khh', 'khv'].forEach((n, i) => e.setBuffer(b, off(n), i + 3));
          });
        }
      }
      if (this.dissipativeHeating) {
        const dp = pack('iiffi', [fields.isMoist ? 1 : 0, this.bbc3 ? 1 : 0, f(this.surfaceRoughness ?? 1),
          f(vertical.zf[1] - vertical.zf[0]), this._surfaceFluxes != null ? 1 : 0]);
        enc('turb_dissipative_heating', full, tg3, false, e => {
          e.setBuffer(b, off('dissten'), 1);
          e.setBase('pi0', this.pi0b, 2);
          e.setBuffer(b, off('ppi'), 3);
          Fields.kernelSpecies.forEach((n, i) => e.setBuffer(b, off(fields.isMoist ? fields.speciesField(n, '_a') : 'th_a'), i + 4));
          e.setBuffer(b, off('thten_t'), 10);
          e.setBytes(dp, 11);
          e.setBuffer(this.sfcb, 0, 12);
        });
      }
      if (this.radiativeRelaxation) {
        enc('rterm_apply', full, tg3, false, e => {
          e.setBuffer(b, off('th_a'), 1);
          e.setBuffer(b, off('thten_t'), 2);
        });
      }
      if (this.radiation) {
        const e = shareEncoder();
        this.radiation.encodeApply(e, arena, 'thten_t', 'th_a', fields.isMoist ? fields.speciesField('qv', '_a') : 'th_a', this.dt);
        count += 1;
      }
      if (ysuPath) {
        ysuApply(0, 0, 'thten_t');
        ysuApply(1, 0, 'uten_t');
        ysuApply(2, 0, 'vten_t');
        if (fields.isMoist && this.usePressureTendency) {
          enc('turb_zero', whole, tg3, false, e => e.setBuffer(b, off('qvten_t'), 1));
          ysuApply(3, 3, 'qvten_t');
        }
      } else {
        enc('turb_gettau', haloWide, tg3, false, e => {
          e.setBuffer(b, off('kmh'), 1);
          e.setBuffer(b, off('kmv'), 2);
          ['s11', 's22', 's33', 's12', 's13', 's23'].forEach((n, i) => e.setBuffer(b, off(n), i + 3));
        });
        let sfcMode = 0;
        if (this.bbc3) {
          sfcMode = 1;
          if ((this._surfaceFluxes?.testcase ?? 0) === 7) sfcMode = 2;
          if (sf && sf.model === 5 && sf.mostUseAverage) sfcMode = 3;
        }
        if (this.noSlipBottom) sfcMode = 4;
        const topNoSlip = I1(this.noSlipTop ? 1 : 0);
        const moveG = Fx2([f(this.domainMotion[0]), f(this.domainMotion[1])]);
        enc('turb_sfcstress', stagCols, tgc, false, e => {
          e.setBuffer(this.sfcb, 0, 1);
          e.setBuffer(b, off('rf'), 2);
          e.setBuffer(b, off('s13'), 3);
          e.setBuffer(b, off('s23'), 4);
          e.setBytes(I1(sfcMode), 5);
          e.setBuffer(b, off('u_a'), 6);
          e.setBuffer(b, off('v_a'), 7);
          e.setBytes(moveG, 8);
          e.setBuffer(b, off('kmv'), 9);
          e.setBytes(topNoSlip, 10);
          e.setBase('mf', this.mfb, 11);
        });
        for (const n of ['s11', 's22', 's33', 's12', 's13', 's23']) turbHalo(n);
        openStress();
        if (this.pbl == null && this.dns == null) {
          enc('tke_epst', full, tg3, false, e => {
            ['u_a', 'v_a', 'w_a', 's11', 's12', 's13', 's22', 's23', 's33', 'rf'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
            e.setBase('mh', this.mhb, 11);
            e.setBase('mf', this.mfb, 12);
            e.setBase('c1', this.c1b, 13);
            e.setBase('c2', this.c2b, 14);
            e.setBuffer(b, off('epst'), 15);
          });
          enc('tke_sources', full, tg3, false, e => {
            ['khv', 'nm', 'dissten', 'epst', 'tketen'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
          });
        }
        const dtBig = F1(f(this.dt));
        const explicitZ = I1(this.explicitVerticalDiffusion ? 1 : 0);
        enc('turb_u_tendency', stagCols, tgc, false, e => {
          ['u_a', 'w_a', 'rho', 'rf', 'kmv', 's11', 's12', 's13'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
          e.setBase('mh', this.mhb, 9);
          e.setBase('mf', this.mfb, 10);
          e.setBytes(dtBig, 11);
          ['cA', 'cB', 'dwdx', 'uten_t'].forEach((n, i) => e.setBuffer(b, off(n), i + 12));
          e.setBytes(open, 16);
          e.setBytes(explicitZ, 17);
        });
        enc('turb_v_tendency', stagCols, tgc, false, e => {
          ['v_a', 'w_a', 'rho', 'rf', 'kmv', 's12', 's22', 's23'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
          e.setBase('mh', this.mhb, 9);
          e.setBase('mf', this.mfb, 10);
          e.setBytes(dtBig, 11);
          ['cA', 'cB', 'dwdx', 'vten_t'].forEach((n, i) => e.setBuffer(b, off(n), i + 12));
          e.setBytes(open, 16);
          e.setBytes(explicitZ, 17);
        });
        enc('turb_w_tendency', cols, tgc, false, e => {
          ['w_a', 'rho', 'rf', 'kmh', 's13', 's23', 's33'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
          e.setBase('mh', this.mhb, 8);
          e.setBase('mf', this.mfb, 9);
          e.setBytes(dtBig, 10);
          ['cA', 'cB', 'wten_t'].forEach((n, i) => e.setBuffer(b, off(n), i + 11));
          e.setBytes(open, 14);
          e.setBytes(explicitZ, 15);
        });
        const leNum = F1(1.0);
        enc('build_sadv', whole, tg3, false, e => {
          e.setBase('th0', this.th0b, 1);
          e.setBuffer(b, off('th_a'), 2);
          e.setBuffer(b, off('sadv'), 3);
        });
        enc('turb_scalar_flux_h', stag, tg3, false, e => {
          e.setBuffer(b, off('sadv'), 1);
          e.setBuffer(b, off('rho'), 2);
          e.setBuffer(b, off('khh'), 3);
          e.setBytes(leNum, 4);
          e.setBuffer(b, off('fx'), 5);
          e.setBuffer(b, off('fy'), 6);
        });
        openTurbFlux();
        enc('turb_scalar_vert_implicit', cols, tgc, false, e => {
          ['sadv', 'rho', 'rr', 'rf', 'khv'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
          e.setBase('mh', this.mhb, 6);
          e.setBase('mf', this.mfb, 7);
          e.setBuffer(b, off('fx'), 8);
          e.setBuffer(b, off('fy'), 9);
          e.setBytes(dtBig, 10);
          e.setBuffer(b, off('cA'), 11);
          e.setBuffer(b, off('cB'), 12);
          e.setBuffer(b, off('thten_t'), 13);
          this.bindSurfaceFlux(e, 9);
        });
        if (fields.isMoist && this.usePressureTendency) {
          enc('turb_zero', whole, tg3, false, e => e.setBuffer(b, off('qvten_t'), 1));
          enc('turb_scalar_flux_h', stag, tg3, false, e => {
            e.setBuffer(b, off('qv_a'), 1);
            e.setBuffer(b, off('rho'), 2);
            e.setBuffer(b, off('khh'), 3);
            e.setBytes(leNum, 4);
            e.setBuffer(b, off('fx'), 5);
            e.setBuffer(b, off('fy'), 6);
          });
          openTurbFlux();
          enc('turb_scalar_vert_implicit', cols, tgc, false, e => {
            ['qv_a', 'rho', 'rr', 'rf', 'khv'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
            e.setBase('mh', this.mhb, 6);
            e.setBase('mf', this.mfb, 7);
            e.setBuffer(b, off('fx'), 8);
            e.setBuffer(b, off('fy'), 9);
            e.setBytes(dtBig, 10);
            e.setBuffer(b, off('cA'), 11);
            e.setBuffer(b, off('cB'), 12);
            e.setBuffer(b, off('qvten_t'), 13);
            this.bindSurfaceFlux(e, 10);
          });
        }
        if (this.pbl == null && this.dns == null) {
          enc('tke_flux_h', stag, tg3, false, e => {
            e.setBuffer(b, off('tke_a'), 1);
            e.setBuffer(b, off('rf'), 2);
            e.setBuffer(b, off('kmh'), 3);
            e.setBuffer(b, off('fx'), 4);
            e.setBuffer(b, off('fy'), 5);
          });
          openTurbFlux();
          enc('tke_transport', stagCols, tgc, false, e => {
            ['tke_a', 'rho', 'rf', 'kmh', 'kmv'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
            e.setBase('mh', this.mhb, 6);
            e.setBase('mf', this.mfb, 7);
            e.setBytes(dtBig, 8);
            ['cA', 'cB', 'fx', 'fy', 'tketen'].forEach((n, i) => e.setBuffer(b, off(n), i + 9));
            e.setBytes(open, 14);
            e.setBytes(explicitZ, 15);
          });
        }
      }
    }

    // ---- подтягивание θ (testcase 10)
    this.nudgeActiveThisStep = false;
    if (this.tqNudge && this.nudgeTnb && this.nudgeQnb && this.nudgePartialb) {
      let nf = f((this.modelTime - 0.0) / (900.0 - 0.0));
      nf = Math.max(0.0, nf);
      nf = Math.min(1.0, nf);
      const taunudge = f(300.0);
      if (Math.abs(nf) > 0.001) {
        const tem = F1(f(nf / taunudge));
        enc('avg_thq_sums_j', [grid.ny, grid.nz, 1], [8, 8, 1], false, e => {
          e.setBuffer(b, off('th_a'), 1);
          e.setBuffer(b, off('qv_a'), 2);
          e.setBase('th0', this.th0b, 3);
          e.setBuffer(this.nudgePartialb, 0, 4);
        });
        enc('tqnudge_profiles', [grid.nz, 1, 1], [32, 1, 1], false, e => {
          e.setBuffer(this.nudgePartialb, 0, 1);
          e.setBase('th0', this.th0b, 2);
          e.setBase('qv0', this.qv0b, 3);
          e.setBytes(tem, 4);
          e.setBuffer(this.nudgeTnb, 0, 5);
          e.setBuffer(this.nudgeQnb, 0, 6);
        });
        enc('add_k_profile', whole, tg3, false, e => {
          e.setBytes(I1(1), 1);
          e.setBuffer(this.nudgeTnb, 0, 2);
          e.setBuffer(b, off('thten_t'), 3);
        });
        this.nudgeActiveThisStep = true;
      }
    }
    if (this.simpleRadiation && fields.isMoist) {
      enc('simplerad_thten', [grid.nx, grid.ny, 1], [8, 8, 1], false, e => {
        e.setBuffer(b, off('qv'), 1);
        e.setBuffer(b, off('qc'), 2);
        e.setBuffer(b, off(fields.speciesField('qr')), 3);
        e.setBase('rho0', this.rho0b, 4);
        e.setBase('zf', this.zfb, 5);
        e.setBase('mh', this.mhb, 6);
        e.setBuffer(b, off('thten_t'), 7);
      });
    }
    if (this.forcing != null && this.frcThb && (fields.useTKE || fields.useRayleigh)) {
      enc('add_k_profile', whole, tg3, false, e => {
        e.setBytes(I1(1), 1);
        e.setBuffer(this.frcThb, 0, 2);
        e.setBuffer(b, off('thten_t'), 3);
      });
    }
    {
      const fc = this.forcing;
      if (fc && fc.needsDomainMeans && this.avgPartialb && this.frcUb && this.frcVb && this.frcDvdrb && this.frcV0b
        && (fields.useTKE || fields.useRayleigh)) {
        enc('avg_uv_sums_j', [grid.ny, grid.nz, 1], [8, 8, 1], false, e => {
          e.setBuffer(b, off('u_a'), 1);
          e.setBuffer(b, off('v_a'), 2);
          e.setBuffer(this.avgPartialb, 0, 3);
        });
        const rR = F1(f(1.0 / fc.hurricaneRadius));
        enc('hurr_forcing_profiles', [grid.nz, 1, 1], [32, 1, 1], false, e => {
          e.setBuffer(this.avgPartialb, 0, 1);
          e.setBuffer(this.frcV0b, 0, 2);
          e.setBuffer(this.frcDvdrb, 0, 3);
          e.setBytes(rR, 4);
          e.setBuffer(this.frcUb, 0, 5);
          e.setBuffer(this.frcVb, 0, 6);
        });
        for (const [stg, prof, dst] of [[2, this.frcUb, 'uten_t'], [3, this.frcVb, 'vten_t']]) {
          enc('add_k_profile', whole, tg3, false, e => {
            e.setBytes(I1(stg), 1);
            e.setBuffer(prof, 0, 2);
            e.setBuffer(b, off(dst), 3);
          });
        }
      }
    }

    // ---- форсинг уравнения для pi' (solve1.F:1707)
    if (!this.usePressureTendency) {
      enc('turb_zero', whole, tg3, false, e => e.setBuffer(b, off('ppten'), 1));
    }
    if (this.usePressureTendency) {
      const moistPT = fields.isMoist;
      const dtb = F1(f(this.dt));
      const hasDiabatic = I1(moistPT && this.hasMicrophysics ? 1 : 0);
      const hasThten = fields.useTKE || fields.useRayleigh;
      const hasStepTend = I1(hasThten ? 1 : 0);
      const moistFlag = I1(moistPT ? 1 : 0);
      enc('pressure_tendency', full, tg3, false, e => {
        ['th_a', moistPT ? 'qv_a' : 'th_a', 'rho', 'ppi'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
        e.setBuffer(b, off(hasThten ? 'thten_t' : 'ppten'), 5);
        e.setBuffer(b, off(moistPT ? 'qpten' : 'ppten'), 6);
        e.setBase('th0', this.th0b, 7);
        e.setBase('pi0', this.pi0b, 8);
        e.setBytes(dtb, 9);
        e.setBytes(hasDiabatic, 10);
        e.setBuffer(b, off('ppten'), 11);
        e.setBytes(hasStepTend, 12);
        e.setBuffer(b, off(moistPT ? 'qvten_t' : 'ppten'), 13);
        e.setBytes(moistFlag, 14);
      });
    }

    for (let nrk = 0; nrk < 3; nrk++) {
      const dttmpV = f(this.dt / (3 - nrk));
      const dttmp = F1(dttmpV);
      this.lastStageDt = dttmpV;

      if (fields.isMoist) {
        enc('update_diagnostics_moist', whole, tg3, false, e => {
          e.setBuffer(b, off(fields.scalars[0]), 1);
          e.setBuffer(b, off('pp3d'), 2);
          [['th0', this.th0b], ['pi0', this.pi0b], ['qv0', this.qv0b], ['qc0', this.qc0b], ['qi0', this.qi0b], ['rth0', this.rth0b]]
            .forEach(([n, p], i) => e.setBase(n, p, i + 3));
          Fields.kernelSpecies.forEach((n, i) => e.setBuffer(b, off(fields.speciesField(n)), i + 9));
          ['thv', 'ppterm', 'piadv', 'thterm', 'buoy'].forEach((n, i) => e.setBuffer(b, off(n), i + 15));
        });
      } else {
        enc('update_diagnostics', whole, tg3, false, e => {
          e.setBuffer(b, off(fields.scalars[0]), 1);
          e.setBuffer(b, off('pp3d'), 2);
          e.setBase('th0', this.th0b, 3);
          e.setBase('pi0', this.pi0b, 4);
          ['thv', 'ppterm', 'piadv'].forEach((n, i) => e.setBuffer(b, off(n), i + 5));
          e.setBase('rth0', this.rth0b, 8);
          e.setBuffer(b, off('buoy'), 9);
        });
      }

      enc('stage_tendency_reset', whole, tg3, false, e => {
        ['uten', 'vten', 'wten'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
      });

      if (((fields.useTKE || fields.useRayleigh) && !skip.has('turbulence')) || fields.useLargeScalePG) {
        for (const [src, dst] of [['uten_t', 'uten'], ['vten_t', 'vten'], ['wten_t', 'wten']]) {
          const ms = F1(this.momentumTurbScale);
          enc('turb_add_tendency', whole, tg3, false, e => {
            e.setBuffer(b, off(src), 1);
            e.setBuffer(b, off(dst), 2);
            e.setBytes(ms, 3);
          });
        }
      }

      if (axi) {
        enc('axi_uten_terms', [grid.nx + 1, grid.ny, grid.nz], tg3, false, e => {
          e.setBuffer(b, off('v'), 1);
          e.setBytes(fcorAxi, 2);
          e.setBuffer(b, off('uten'), 3);
        });
      } else if (this.coriolis != null && !skip.has('coriolis')) {
        const fcr = F1(this.coriolis);
        const move = Fx2([f(this.domainMotion[0]), f(this.domainMotion[1])]);
        enc('coriolis_uv', stag, tg3, false, e => {
          e.setBuffer(b, off('u'), 1);
          e.setBuffer(b, off('v'), 2);
          e.setBytes(fcr, 3);
          e.setBytes(move, 4);
          e.setBuffer(b, off('uten'), 5);
          e.setBuffer(b, off('vten'), 6);
        });
      }

      const haloFill = name => {
        if (this.periodicX) enc('bc_periodic_x', [H + 1, grid.ny + 1 + 2 * H, grid.nz + 1], [H + 1, 8, 1], false, e => e.setBuffer(b, off(name), 1));
        if (this.periodicY) enc('bc_periodic_y', [H + 1, grid.nx + 1 + 2 * H, grid.nz + 1], [H + 1, 8, 1], false, e => e.setBuffer(b, off(name), 1));
        openHalo(name);
        rigidHalo(name);
      };
      const computeDiv = () => {
        enc('div_massflux', whole, tg3, false, e => {
          ['rru', 'rrv', 'rrw'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
          e.setBase('mh', this.mhb, 4);
          e.setBuffer(b, off('divx'), 5);
          bindTerrain(e);
        });
      };
      const axiFluxX = (src, st, weno, weps, size) => {
        enc('axi_flux_x', size, tg3, false, e => {
          e.setBytes(I1(st), 1);
          e.setBuffer(b, off(src), 2);
          e.setBuffer(b, off('rru'), 3);
          e.setBase('c2', this.c2b, 4);
          e.setBytes(I1(weno ? 1 : 0), 5);
          e.setBytes(F1(weps), 6);
          e.setBuffer(b, off('fx'), 7);
        });
      };
      const axiSource = (s, stagger) => {
        if (stagger !== 3) return s;
        enc('axi_angular_momentum', whole, tg3, false, e => {
          e.setBuffer(b, off(s), 1);
          e.setBytes(fcorAxi, 2);
          e.setBuffer(b, off('sadv'), 3);
        });
        return 'sadv';
      };

      // stagger: 1 скаляр, 2 u, 3 v, 4 w
      const advect = (s, { stagger = 1, into: dest = 'tend', accumulate = false, state = null } = {}) => {
        if (stagger === 1) {
          const target = state ?? s;
          const isTheta = target === fields.scalars[0];
          const doWeno = this.wenoScalars && nrk === 2 && !skip.has('weno');
          if (doWeno) {
            const weps = F1(TimeStep.wenoEpsilon(target));
            const pdef = I1(isTheta ? 0 : 1);
            const pdw = I1((isTheta || target === 'qv') ? 0 : 1);
            if (axi) axiFluxX(s, 1, true, TimeStep.wenoEpsilon(target), fullU);
            else enc('adv_flux_x_weno', fullU, tg3, false, e => {
              e.setBuffer(b, off(s), 1);
              e.setBuffer(b, off('rru'), 2);
              e.setBytes(weps, 3);
              e.setBytes(pdef, 4);
              e.setBuffer(b, off('fx'), 5);
            });
            enc('adv_flux_y_weno', fullV, tg3, false, e => {
              e.setBuffer(b, off(s), 1);
              e.setBuffer(b, off('rrv'), 2);
              e.setBytes(weps, 3);
              e.setBytes(pdef, 4);
              e.setBuffer(b, off('fy'), 5);
            });
            enc('adv_flux_z_weno', fullW, tg3, false, e => {
              e.setBuffer(b, off(s), 1);
              e.setBuffer(b, off('rrw'), 2);
              e.setBase('c1', this.c1b, 3);
              e.setBase('c2', this.c2b, 4);
              e.setBytes(weps, 5);
              e.setBytes(pdef, 6);
              e.setBytes(pdw, 7);
              e.setBuffer(b, off('fz'), 8);
            });
          } else {
            if (axi) axiFluxX(s, 1, false, 0, fullU);
            else enc('adv_flux_x', fullU, tg3, false, e => {
              e.setBuffer(b, off(s), 1);
              e.setBuffer(b, off('rru'), 2);
              e.setBuffer(b, off('fx'), 3);
            });
            enc('adv_flux_y', fullV, tg3, false, e => {
              e.setBuffer(b, off(s), 1);
              e.setBuffer(b, off('rrv'), 2);
              e.setBuffer(b, off('fy'), 3);
            });
            enc('adv_flux_z', fullW, tg3, false, e => {
              e.setBuffer(b, off(s), 1);
              e.setBuffer(b, off('rrw'), 2);
              e.setBase('c1', this.c1b, 3);
              e.setBase('c2', this.c2b, 4);
              e.setBuffer(b, off('fz'), 5);
            });
          }
        } else {
          const st = I1(skip.has('verticalMetric') ? -stagger : stagger);
          const stagLo = [grid.nx + 2, grid.ny + 2, grid.nz];
          const wenoTke = stagger === 4 && s === 'tke' && this.wenoScalars && nrk === 2 && !skip.has('weno');
          const wenoW = stagger === 4 && s === 'w' && this.wenoMomentum && nrk === 2 && !skip.has('weno');
          const wenoUV = (stagger === 2 || stagger === 3) && this.wenoMomentum && nrk === 2 && !skip.has('weno');
          const axiSrc = axi ? axiSource(s, stagger) : s;
          if (wenoUV) {
            const wepsV = f(100.0 * 1.0e-18), weps = F1(wepsV);
            for (const [kernel, flux, rr] of [['adv_flux_x_weno_uv', 'fx', 'rru'], ['adv_flux_y_weno_uv', 'fy', 'rrv']]) {
              if (axi && kernel === 'adv_flux_x_weno_uv') { axiFluxX(axiSrc, stagger, true, wepsV, stagLo); continue; }
              enc(kernel, stagLo, tg3, false, e => {
                e.setBytes(st, 1);
                e.setBuffer(b, off(s), 2);
                e.setBuffer(b, off(rr), 3);
                e.setBytes(weps, 4);
                e.setBuffer(b, off(flux), 5);
              });
            }
            enc('adv_flux_z_weno_uv', [grid.nx + 1, grid.ny + 1, grid.nz + 1], tg3, false, e => {
              e.setBytes(st, 1);
              e.setBuffer(b, off(s), 2);
              e.setBuffer(b, off('rrw'), 3);
              e.setBase('c1', this.c1b, 4);
              e.setBase('c2', this.c2b, 5);
              e.setBytes(weps, 6);
              e.setBuffer(b, off('fz'), 7);
            });
          } else if (wenoTke || wenoW) {
            const wepsV = wenoW ? f(100.0 * 1.0e-18) : TimeStep.wenoEpsilon('tke'), weps = F1(wepsV);
            for (const [kernel, flux, rr] of [['adv_flux_x_weno_w', 'fx', 'rru'], ['adv_flux_y_weno_w', 'fy', 'rrv']]) {
              if (axi && kernel === 'adv_flux_x_weno_w') { axiFluxX(axiSrc, stagger, true, wepsV, stagLo); continue; }
              enc(kernel, stagLo, tg3, false, e => {
                e.setBuffer(b, off(s), 1);
                e.setBuffer(b, off(rr), 2);
                e.setBase('c2', this.c2b, 3);
                e.setBytes(weps, 4);
                e.setBuffer(b, off(flux), 5);
              });
            }
            enc('adv_flux_z_weno_w', [grid.nx + 1, grid.ny + 1, grid.nz + 1], tg3, false, e => {
              e.setBuffer(b, off(s), 1);
              e.setBuffer(b, off('rrw'), 2);
              e.setBytes(weps, 3);
              e.setBuffer(b, off('fz'), 4);
            });
          } else {
            for (const [kernel, flux, gs] of [['adv_flux_x_stag', 'fx', stagLo], ['adv_flux_y_stag', 'fy', stagLo],
              ['adv_flux_z_stag', 'fz', [grid.nx + 1, grid.ny + 1, grid.nz + 1]]]) {
              if (axi && kernel === 'adv_flux_x_stag') { axiFluxX(axiSrc, stagger, false, 0, stagLo); continue; }
              enc(kernel, gs, tg3, false, e => {
                e.setBytes(st, 1);
                e.setBuffer(b, off(s), 2);
                ['rru', 'rrv', 'rrw'].forEach((n, i) => e.setBuffer(b, off(n), i + 3));
                e.setBase('c1', this.c1b, 6);
                e.setBase('c2', this.c2b, 7);
                e.setBuffer(b, off(flux), 8);
              });
            }
          }
        }
        const st = I1(skip.has('verticalMetric') ? -stagger : stagger);
        const acc = I1(accumulate ? 1 : 0);
        const asmSize = [grid.nx + (stagger === 2 ? 1 : 0), grid.ny + (stagger === 3 ? 1 : 0), grid.nz];
        enc('adv_assemble', asmSize, tg3, false, e => {
          e.setBytes(st, 1);
          e.setBuffer(b, off(s), 2);
          ['fx', 'fy', 'fz', 'divx'].forEach((n, i) => e.setBuffer(b, off(n), i + 3));
          e.setBase('rho0', this.rho0b, 7);
          e.setBase('rf0', this.rf0b, 8);
          e.setBase('mh', this.mhb, 9);
          e.setBase('mf', this.mfb, 10);
          e.setBuffer(b, off(dest), 11);
          e.setBytes(acc, 12);
          e.setBuffer(b, off('rru'), 13);
          e.setBuffer(b, off('rrv'), 14);
          e.setBase('c1', this.c1b, 15);
          e.setBase('c2', this.c2b, 16);
          e.setBytes(open, 17);
          e.setBase('rr0', this.rr0b, 18);
          e.setBuffer(b, off(this._terrain != null ? 'advz6' : 'tend'), 19);
          e.setBytes(fcorAxi, 27);
          bindTerrain(e);
        });
        if (this.forcing && this.forcing.appliesSubsidence && stagger !== 4 && this.frcWb) {
          const weps = F1(stagger === 1 ? TimeStep.wenoEpsilon(state ?? s) : f(100.0 * 1.0e-18));
          enc('wsub_tendency', asmSize, tg3, false, e => {
            e.setBytes(I1(stagger), 1);
            e.setBuffer(b, off(s), 2);
            e.setBuffer(this.frcWb, 0, 3);
            e.setBase('c1', this.c1b, 4);
            e.setBase('c2', this.c2b, 5);
            e.setBase('mh', this.mhb, 6);
            e.setBase('rr0', this.rr0b, 7);
            e.setBase('rf0', this.rf0b, 8);
            e.setBytes(weps, 9);
            e.setBuffer(b, off(dest), 10);
          });
        }
        if (accumulate) return;
        if (stagger === 1 && fields.isMoist && nrk === 2 && (state ?? s) !== fields.scalars[0] && !skip.has('pdef')) {
          const pdTarget = state ?? s;
          const s0 = fields.atTimeLevel(pdTarget);
          [['fx', 'rru', 'pk1'], ['fy', 'rrv', 'pk2'], ['fz', 'rrw', 'fpk']].forEach((names, dd) => {
            enc('pdef_dum', asmSize, tg3, false, e => {
              e.setBytes(I1(dd), 1);
              e.setBuffer(b, off(s), 2);
              e.setBuffer(b, off(s0), 3);
              e.setBuffer(b, off(names[0]), 4);
              e.setBuffer(b, off(names[1]), 5);
              e.setBase('rho0', this.rho0b, 6);
              e.setBase('mh', this.mhb, 7);
              e.setBytes(dttmp, 8);
              e.setBytes(open, 9);
              e.setBuffer(b, off(names[2]), 10);
            });
          });
          haloFill('pk1');
          haloFill('pk2');
          enc('pdef_apply', asmSize, tg3, false, e => {
            [s, s0, 'fx', 'fy', 'fz', 'rru', 'rrv', 'rrw', 'pk1', 'pk2', 'fpk'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
            e.setBase('rho0', this.rho0b, 12);
            e.setBase('mh', this.mhb, 13);
            e.setBytes(dttmp, 14);
            e.setBytes(open, 15);
            e.setBuffer(b, off('tend'), 16);
          });
        }
        if (fields.isMoist && (state ?? s) === fields.scalars[0] && !skip.has('thterm')) {
          enc('apply_thterm', full, tg3, false, e => {
            e.setBuffer(b, off('div3d'), 1);
            e.setBuffer(b, off('thterm'), 2);
            e.setBuffer(b, off('tend'), 3);
          });
        }
        if ((fields.useTKE || fields.useRayleigh) && !skip.has('turbulence') && (state ?? s) === fields.scalars[0]) {
          enc('turb_add_tendency', whole, tg3, false, e => {
            e.setBuffer(b, off('thten_t'), 1);
            e.setBuffer(b, off('tend'), 2);
            e.setBytes(F1(1.0), 3);
          });
        }
        if (this._landPBL != null && fields.isMoist && !skip.has('turbulence') && (state ?? s) !== fields.scalars[0]) {
          const slot = { qv: 3, qc: 4, qi: 5 }[state ?? s];
          if (slot !== undefined) ysuApply(3, slot, 'tend');
        } else if (fields.isMoist && fields.useTKE && !skip.has('turbulence') && (state ?? s) !== fields.scalars[0]) {
          const le = F1(1.0);
          const dtb = F1(f(this.dt));
          const qa = fields.atTimeLevel(state ?? s);
          const cached = fields.cacheMoistureTurbulence;
          const sink = cached ? 'qturb_' + (state ?? s) : 'tend';
          if (cached && nrk === 0) enc('turb_zero', whole, tg3, false, e => e.setBuffer(b, off(sink), 1));
          if (!cached || nrk === 0) {
            enc('turb_scalar_flux_h', stag, tg3, false, e => {
              e.setBuffer(b, off(qa), 1);
              e.setBuffer(b, off('rho'), 2);
              e.setBuffer(b, off('khh'), 3);
              e.setBytes(le, 4);
              e.setBuffer(b, off('fx'), 5);
              e.setBuffer(b, off('fy'), 6);
            });
            openTurbFlux();
            enc('turb_scalar_vert_implicit', cols, tgc, false, e => {
              [qa, 'rho', 'rr', 'rf', 'khv'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
              e.setBase('mh', this.mhb, 6);
              e.setBase('mf', this.mfb, 7);
              e.setBuffer(b, off('fx'), 8);
              e.setBuffer(b, off('fy'), 9);
              e.setBytes(dtb, 10);
              e.setBuffer(b, off('cA'), 11);
              e.setBuffer(b, off('cB'), 12);
              e.setBuffer(b, off(sink), 13);
              this.bindSurfaceFlux(e, qa === 'qv_a' ? 10 : null);
            });
          }
          if (cached) {
            enc('turb_add_tendency', whole, tg3, false, e => {
              e.setBuffer(b, off(sink), 1);
              e.setBuffer(b, off('tend'), 2);
              e.setBytes(F1(1.0), 3);
            });
          }
        }
        if (this.nudgeActiveThisStep && this.nudgeQnb && (state ?? s) === fields.scalars[1]) {
          enc('add_k_profile', whole, tg3, false, e => {
            e.setBytes(I1(1), 1);
            e.setBuffer(this.nudgeQnb, 0, 2);
            e.setBuffer(b, off('tend'), 3);
          });
        }
        if (this.forcing != null && this.frcQvb && fields.isMoist && (state ?? s) === fields.scalars[1]) {
          enc('add_k_profile', whole, tg3, false, e => {
            e.setBytes(I1(1), 1);
            e.setBuffer(this.frcQvb, 0, 2);
            e.setBuffer(b, off('tend'), 3);
          });
        }
        if (fields.isMoist && this.hasMicrophysics && this.usePressureTendency) {
          const src = { th: 'qtten', qv: 'qvten', qc: 'qcten' }[state ?? s];
          if (src) {
            enc('turb_add_tendency', whole, tg3, false, e => {
              e.setBuffer(b, off(src), 1);
              e.setBuffer(b, off('tend'), 2);
              e.setBytes(F1(1.0), 3);
            });
          }
        }
        if (skip.has('rkUpdate')) return;
        const target = state ?? s;
        enc('rk_update', asmSize, tg3, false, e => {
          e.setBytes(I1(stagger), 1);
          e.setBuffer(b, off(fields.atTimeLevel(target)), 2);
          e.setBuffer(b, off('tend'), 3);
          e.setBuffer(b, off(target), 4);
          e.setBytes(dttmp, 5);
        });
        haloFill(target);
      };

      // 1. потоки массы из мгновенного состояния
      terrainBcwsfc(false);
      enc('massflux_from_state', whole, tg3, false, e => {
        ['u', 'v', 'w'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
        e.setBase('rho0', this.rho0b, 4);
        e.setBase('rf0', this.rf0b, 5);
        ['rru', 'rrv', 'rrw'].forEach((n, i) => e.setBuffer(b, off(n), i + 6));
        bindTerrain(e);
      });
      terrainRrw();
      computeDiv();

      // 2. адвекция импульса
      if (!skip.has('momentumAdvection')) {
        for (let n = 0; n < fields.momentum.length; n++) {
          const s = fields.momentum[n];
          if (n === 2 && skip.has('advectionOfW')) continue;
          if (n < 2 && skip.has('advectionOfUV')) continue;
          advect(s, { stagger: n + 2, into: ['uten', 'vten', 'wten'][n], accumulate: true });
          if (this.stopAfterMomentumAdvection === s && this.stopBeforeAcoustics != null && nrk + 1 >= this.stopBeforeAcoustics) {
            endShared(); this.dispatchesPerStep = count; return;
          }
        }
      }

      // TKE
      if (fields.useTKE && this.pbl == null && this.dns == null && !skip.has('turbulence')) {
        enc('turb_zero', whole, tg3, false, e => e.setBuffer(b, off('tketen_s'), 1));
        if (!this.skipTkeAdvection) advect('tke', { stagger: 4, into: 'tketen_s', accumulate: true });
        enc('turb_add_tendency', whole, tg3, false, e => {
          e.setBuffer(b, off('tketen'), 1);
          e.setBuffer(b, off('tketen_s'), 2);
          e.setBytes(F1(1.0), 3);
        });
        enc('tke_advance', full, tg3, false, e => {
          e.setBuffer(b, off('tke_a'), 1);
          e.setBuffer(b, off('tketen_s'), 2);
          e.setBytes(dttmp, 3);
          e.setBuffer(b, off('tke'), 4);
        });
        haloFill('tke');
      }

      // плавучесть
      if (!skip.has('buoyancy')) {
        enc('buoyancy_apply', [grid.nx, grid.ny, Math.max(grid.nz - 1, 1)], tg3, false, e => {
          e.setBuffer(b, off('buoy'), 1);
          e.setBase('c1', this.c1b, 2);
          e.setBase('c2', this.c2b, 3);
          e.setBuffer(b, off('wten'), 4);
        });
        if (this._terrain != null) {
          haloFill('advz6');
          enc('terrain_buoy_uv', [grid.nx + 1, grid.ny + 1, grid.nz], tg3, false, e => {
            e.setBuffer(b, off('advz6'), 1);
            e.setBase('c1', this.c1b, 2);
            e.setBase('c2', this.c2b, 3);
            e.setBuffer(b, off('uten'), 4);
            e.setBuffer(b, off('vten'), 5);
            e.setBytes(open, 6);
            bindTerrain(e);
          });
        }
      }

      // 3. акустические подшаги
      if (this.stopBeforeAcoustics != null && nrk + 1 >= this.stopBeforeAcoustics && this.stopAfterSubstep == null) {
        endShared(); this.dispatchesPerStep = count; return;
      }
      enc('stage_state_reset', whole, tg3, false, e => {
        ['u_a', 'v_a', 'w_a', 'ppi'].forEach((n, i) => e.setBuffer(b, off(n), i + 1));
        ['u', 'v', 'w', 'pp3d', 'ppd'].forEach((n, i) => e.setBuffer(b, off(n), i + 5));
        e.setBuffer(b, off(skip.has('ppx') ? 'ppi' : 'ppx'), 10);
      });

      if (!skip.has('acoustic')) {
        params.dts = f(this.schedule.loops[nrk].dts);
        if (this.explicitAcoustics) { params.alph = 1.0; params.beta = 0.0; }
        enc('acoustic_prepare', full, tg3, true, e => {
          ['ppterm', 'piadv', 'thv'].forEach((n, i) => e.setBuffer(b, off(n), i + 2));
          e.setBase('rr0', this.rr0b, 5);
          e.setBase('rf0', this.rf0b, 6);
          e.setBase('mh', this.mhb, 7);
          e.setBase('mf', this.mfb, 8);
          e.setBase('c1', this.c1b, 9);
          e.setBase('c2', this.c2b, 10);
          bindTerrain(e);
          ['qk', 'pk1', 'pk2', 'mm'].forEach((n, i) => e.setBuffer(b, off(n), i + 11));
        });
        enc('acoustic_begin', whole, tg3, true, e => {
          e.setBuffer(b, off('w'), 2);
          ['rru', 'rrv', 'rrw'].forEach((n, i) => e.setBuffer(b, off(n), i + 3));
        });
        const nloop = this.schedule.loops[nrk].count;
        inAcoustics = true;
        for (let n = 0; n < nloop; n++) {
          if (anyOpen) {
            enc('openbc_uv_tendency', [Math.max(grid.nx, grid.ny), grid.nz, 1], tgc, true, e => {
              [this.radbcwb, this.radbceb, this.radbcsb, this.radbcnb].forEach((buf, i) => e.setBuffer(buf, 0, i + 2));
              ['uten', 'vten', 'u', 'v'].forEach((nm, i) => e.setBuffer(b, off(nm), i + 6));
              e.setBytes(open, 10);
              bindTerrain(e);
            });
          }
          enc('acoustic_uv', stag, tg3, true, e => {
            ['ppd', 'thv', 'uten', 'vten', 'u', 'v'].forEach((nm, i) => e.setBuffer(b, off(nm), i + 2));
            e.setBytes(open, 8);
            bindTerrain(e);
          });
          const saveX = I1(nrk === 2 ? 1 : 0);
          if (this.explicitAcoustics) {
            enc('acoustic_w_explicit', [grid.nx, grid.ny, grid.nz + 1], tg3, true, e => {
              ['mm', 'wten', 'ppd', 'w'].forEach((nm, i) => e.setBuffer(b, off(nm), i + 2));
            });
            enc('acoustic_pp_explicit', full, tg3, true, e => {
              ['u', 'v', 'w', 'piadv', 'ppten', 'ppterm', 'pk1', 'pk2', 'pp3d', 'ppd', 'ppx'].forEach((nm, i) => e.setBuffer(b, off(nm), i + 2));
              e.setBytes(saveX, 13);
              e.setBase('mh', this.mhb, 14);
            });
          } else {
            terrainBcwsfc(true);
            enc('acoustic_fpk', full, tg3, true, e => {
              ['u', 'v', 'w', 'piadv', 'ppten', 'ppterm', 'pk1', 'pk2', 'qk', 'fpk'].forEach((nm, i) => e.setBuffer(b, off(nm), i + 2));
              e.setBase('rho0', this.rho0b, 15);
              e.setBase('rr0', this.rr0b, 16);
              e.setBase('rf0', this.rf0b, 17);
              bindTerrain(e);
            });
            enc('acoustic_w_solve', cols, tgc, true, e => {
              ['pk1', 'pk2', 'qk', 'mm', 'fpk', 'wten', 'pp3d', 'w', 'cA', 'cB'].forEach((nm, i) => e.setBuffer(b, off(nm), i + 2));
            });
            enc('acoustic_pp', full, tg3, true, e => {
              ['w', 'pk1', 'pk2', 'qk', 'fpk', 'pp3d', 'ppd'].forEach((nm, i) => e.setBuffer(b, off(nm), i + 2));
              e.setBuffer(b, off('ppx'), 9);
              e.setBytes(saveX, 10);
            });
          }
          haloFill('ppd');
          const tavg = F1(f(n === nloop - 1 && !skip.has('substepAveraging') ? 1.0 / nloop : 0.0));
          enc('acoustic_accumulate', whole, tg3, true, e => {
            ['u', 'v', 'w', 'rru', 'rrv', 'rrw'].forEach((nm, i) => e.setBuffer(b, off(nm), i + 2));
            e.setBytes(tavg, 8);
          });
          haloFill('u'); haloFill('v'); haloFill('w');
          if (this.stopBeforeAcoustics != null && this.stopAfterSubstep != null
            && nrk + 1 === this.stopBeforeAcoustics && n + 1 === this.stopAfterSubstep) {
            haloFill('pp3d');
            endShared(); this.dispatchesPerStep = count; return;
          }
        }
        inAcoustics = false;
        if (axi) {
          enc('axi_v_update', full, tg3, false, e => {
            e.setBuffer(b, off('v_a'), 1);
            e.setBuffer(b, off('vten'), 2);
            e.setBytes(dttmp, 3);
            e.setBuffer(b, off('v'), 4);
          });
          haloFill('v');
          haloFill('u');
        }
        haloFill('pp3d');
        if (this.openX) {
          enc('radbc_ew', [grid.ny, 1, 1], tgc, false, e => {
            e.setBuffer(b, off('u_a'), 1);
            e.setBuffer(b, off('u'), 2);
            e.setBytes(dttmp, 3);
            e.setBuffer(this.radbcwb, 0, 4);
            e.setBuffer(this.radbceb, 0, 5);
          });
        }
        if (this.openY) {
          enc('radbc_ns', [grid.nx, 1, 1], tgc, false, e => {
            e.setBuffer(b, off('v_a'), 1);
            e.setBuffer(b, off('v'), 2);
            e.setBytes(dttmp, 3);
            e.setBuffer(this.radbcsb, 0, 4);
            e.setBuffer(this.radbcnb, 0, 5);
          });
        }
      }

      if (fields.isMoist && !skip.has('thterm')) {
        const velocities = skip.has('acoustic') ? ['u', 'v', 'w'] : ['rru', 'rrv', 'rrw'];
        enc('divergence3d', full, tg3, false, e => {
          velocities.forEach((n, i) => e.setBuffer(b, off(n), i + 1));
          e.setBase('mh', this.mhb, 4);
          e.setBuffer(b, off('div3d'), 5);
        });
      }

      // 4. осреднённые скорости -> потоки массы
      if (!skip.has('velocityToMassflux') && !skip.has('acoustic')) {
        terrainBcwsfc(false);
        enc('velocity_to_massflux', whole, tg3, false, e => {
          e.setBase('rho0', this.rho0b, 1);
          e.setBase('rf0', this.rf0b, 2);
          ['rru', 'rrv', 'rrw'].forEach((n, i) => e.setBuffer(b, off(n), i + 3));
          bindTerrain(e);
        });
        terrainRrw();
      }
      if (!skip.has('acoustic')) computeDiv();

      // 5. адвекция скаляров
      if (!skip.has('scalarAdvection')) {
        fields.scalars.forEach((s, n) => {
          if (n === 0) {
            enc('build_sadv', whole, tg3, false, e => {
              e.setBase('th0', this.th0b, 1);
              e.setBuffer(b, off(s), 2);
              e.setBuffer(b, off('sadv'), 3);
            });
            advect('sadv', { state: s });
          } else advect(s);
        });
      }

      if (nrk === 2 && !skip.has('diagnostics')) {
        if (fields.isMoist && this.usePressureTendency) encodeDiabaticUnapply();
        const moistFlag = I1(fields.isMoist ? 1 : 0);
        enc('update_rho_prs', full, tg3, false, e => {
          e.setBytes(moistFlag, 1);
          e.setBuffer(b, off(fields.scalars[0]), 2);
          e.setBuffer(b, off('pp3d'), 3);
          e.setBase('th0', this.th0b, 4);
          e.setBase('pi0', this.pi0b, 5);
          e.setBuffer(b, off(fields.isMoist ? 'qv' : 'th'), 6);
          e.setBuffer(b, off('prs'), 7);
          e.setBuffer(b, off('rho'), 8);
        });
        if (this.conserveDryMass) {
          this.encodeMassSums(enc, off('rho'), off('pp3d'), b);
          enc('mass_reference_init', [1, 1, 1], [1, 1, 1], false, e => {
            e.setBuffer(this.massLevelsb, 0, 1);
            e.setBuffer(this.massRefb, 0, 2);
          });
          enc('mass_correction_apply', full, tg3, false, e => {
            e.setBytes(moistFlag, 1);
            e.setBuffer(this.massLevelsb, 0, 2);
            e.setBuffer(this.massLevelsb, grid.nz * 2 * 4, 3);
            e.setBuffer(this.massRefb, 0, 4);
            e.setBuffer(b, off(fields.scalars[0]), 5);
            e.setBuffer(b, off('pp3d'), 6);
            e.setBase('th0', this.th0b, 7);
            e.setBase('pi0', this.pi0b, 8);
            e.setBuffer(b, off(fields.isMoist ? 'qv' : 'th'), 9);
            e.setBuffer(b, off('prs'), 10);
            e.setBuffer(b, off('rho'), 11);
            e.setBuffer(this.massOutb, 0, 12);
          });
        }
      }
    }

    if (fields.isMoist && this.usePressureTendency && skip.has('diagnostics')) encodeDiabaticUnapply();
    if (this.hasMicrophysics && !skip.has('microphysics')) {
      enc('mp_pdefq', cols, tgc, false, e => {
        e.setBuffer(b, off('rho'), 1);
        e.setBuffer(b, off('qv'), 2);
        e.setBytes(F1(0.0), 3);
      });
      const e = shareEncoder();
      if (this.microphysics) { this.microphysics.encode(e, arena, this.dt); count += this.microphysics.dispatchesPerCall ?? 0; }
      else if (this.morrison) { this.morrison.encode(e, arena, this.dt, doradThisStep); count += this.morrison.dispatchesPerCall ?? 0; }
      else if (this.rotunnoEmanuel) { this.rotunnoEmanuel.encode(e, arena, this.dt); count += this.rotunnoEmanuel.dispatchesPerCall ?? 0; }
    }
    if (fields.isMoist && this.usePressureTendency) {
      const dtb = F1(f(this.dt));
      enc('diabatic_rates', full, tg3, false, e => {
        e.setBytes(dtb, 1);
        ['pp3d', 'th', 'qv', 'qc', 'qpten', 'qtten', 'qvten', 'qcten'].forEach((n, i) => e.setBuffer(b, off(n), i + 2));
      });
    }
    enc('ppx_finish', full, tg3, false, e => {
      e.setBuffer(b, off('pp3d'), 1);
      e.setBuffer(b, off('ppx'), 2);
    });
    if (this.periodicX) enc('bc_periodic_x', [H + 1, grid.ny + 1 + 2 * H, grid.nz + 1], [H + 1, 8, 1], false, e => e.setBuffer(b, off('ppx'), 1));
    if (this.periodicY) enc('bc_periodic_y', [H + 1, grid.nx + 1 + 2 * H, grid.nz + 1], [H + 1, 8, 1], false, e => e.setBuffer(b, off('ppx'), 1));
    openHalo('ppx');
    endShared();
    if (this.stabilityb) { this.encodeStability(cb, arena); count += 1; }
    this.encodeStateSwap(cb, arena);
    this.modelTime += this.dt;
    if (this.radiation && doradThisStep) {
      this.radiation.encodeCall(cb, arena, this.sfcb, this.modelTime, this.dt);
      count += 1;
    }
    this.dispatchesPerStep = count;
  }
}
