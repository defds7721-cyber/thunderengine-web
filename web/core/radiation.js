// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Излучение RRTMG (radopt = 2): RRTMGLongwaveTables, RRTMGShortwaveTables,
// RRTMGLongwave, RRTMGShortwave, RadiationDriver, RadiationSun,
// SolarPosition. Правила float-арифметики - в шапке f32.js.
//
// Таблицы - файлы (data/rrtmg): до сборки сценария их загружает
//   await loadRRTMG(name => fetch('../data/rrtmg/' + name).then(r => r.arrayBuffer()))
// после чего RRTMGLongwaveTables.bundled() / RRTMGShortwaveTables.bundled()
// синхронны.
//
// Прогона RRTMG с ожиданием GPU (compute(...)) здесь нет: в браузере шаг
// только кодируется.
import { f, fmaf, expf, sinf, cosf, asinf } from './f32.js';
import { Constants } from './grid.js';
import { RRTMGLongwaveLayout, RRTMGShortwaveLayout } from './radiation_layout.js';

const fl = a => a.map(f);    // литералы [Float]
const prod = a => a.reduce((x, y) => x * y, 1);
const sumF = a => a.reduce((x, y) => x + y, 0);   // reduce(0, +) по целым в Float - точно

// GridDimsGPU (Advection): nx, ny, nz, strideJ, strideK (Int32), rdx, rdy, rdz (Float)
export function gridDims(g) {
  const b = new ArrayBuffer(32), dv = new DataView(b);
  [g.nx, g.ny, g.nz, g.strideJ, g.strideK].forEach((v, i) => dv.setInt32(4 * i, v, true));
  dv.setFloat32(20, 1.0 / g.dx, true); dv.setFloat32(24, 1.0 / g.dy, true); dv.setFloat32(28, 1.0 / g.dz, true);
  return new Uint8Array(b);
}
function packed(fields) {   // [['f', v] | ['i', v] | ['u', v]] - всё по 4 байта
  const b = new ArrayBuffer(4 * fields.length), dv = new DataView(b);
  fields.forEach(([t, v], k) => {
    if (t === 'f') dv.setFloat32(4 * k, v, true);
    else if (t === 'i') dv.setInt32(4 * k, v, true);
    else dv.setUint32(4 * k, v >>> 0, true);
  });
  return new Uint8Array(b);
}

// ---- данные RRTMG
const raw = {};
let lwCache = null, swCache = null;
// expf_tables.bin - expf системной libm, снятый с эталона:
// exp_tbl (10001 float, общий у LW и SW) и expf(0.02·(год−2000)) для
// 1900...2100 (201 float). Системный expf не всегда правильно округлён: на
// exp_tbl 81 точка из 10001 расходится с f(Math.exp) на 1 ulp, - поэтому
// таблица, а не счёт.
export const RRTMG_FILES = ['RRTMG_LW_DATA', 'rrtmg_lw_static.e1tab', 'RRTMG_SW_DATA', 'rrtmg_sw_static.e1tab', 'expf_tables.bin'];
function libmExp() {
  const b = need('expf_tables.bin');
  const v = new Float32Array(b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength));
  if (v.length !== 10001 + 201) throw new Error('RRTMG: expf_tables.bin не той длины');
  return v;
}
export async function loadRRTMG(fetchBinary) {
  await Promise.all(RRTMG_FILES.map(async n => {
    if (raw[n]) return;
    const x = await fetchBinary(n);
    raw[n] = x instanceof Uint8Array ? x : new Uint8Array(x);
  }));
}
const need = n => { if (!raw[n]) throw new Error(`нет ресурса RRTMG: ${n} (сначала loadRRTMG)`); return raw[n]; };

// ---- RRTMGLongwaveTables
export class RRTMGLongwaveTables {
  static recordLayout = (() => {
    const fa = ['fracrefao', [16]], fb = ['fracrefbo', [16]];
    const fa9 = ['fracrefao', [16, 9]], fb5 = ['fracrefbo', [16, 5]];
    const ka = ['kao', [5, 13, 16]], kb = ['kbo', [5, 47, 16]];
    const ka9 = ['kao', [9, 5, 13, 16]], kb5 = ['kbo', [5, 5, 47, 16]];
    const sf = ['selfrefo', [10, 16]], fo = ['forrefo', [4, 16]];
    return [
      [fa, fb, ka, kb, ['kao_mn2', [19, 16]], ['kbo_mn2', [19, 16]], sf, fo],
      [fa, fb, ka, kb, sf, fo],
      [fa9, fb5, ka9, kb5, ['kao_mn2o', [9, 19, 16]], ['kbo_mn2o', [5, 19, 16]], sf, fo],
      [fa9, fb5, ka9, kb5, sf, fo],
      [fa9, fb5, ka9, kb5, ['kao_mo3', [9, 19, 16]], ['ccl4o', [16]], sf, fo],
      [fa, ka, ['kao_mco2', [19, 16]], ['cfc11adjo', [16]], ['cfc12o', [16]], sf, fo],
      [fa9, fb, ka9, kb, ['kao_mco2', [9, 19, 16]], ['kbo_mco2', [19, 16]], sf, fo],
      [fa, fb, ka, kb, ['kao_mco2', [19, 16]], ['kbo_mco2', [19, 16]], ['kao_mn2o', [19, 16]],
        ['kbo_mn2o', [19, 16]], ['kao_mo3', [19, 16]], ['cfc12o', [16]], ['cfc22adjo', [16]], sf, fo],
      [fa9, fb, ka9, kb, ['kao_mn2o', [9, 19, 16]], ['kbo_mn2o', [19, 16]], sf, fo],
      [fa, fb, ka, kb, sf, fo],
      [fa, fb, ka, kb, ['kao_mo2', [19, 16]], ['kbo_mo2', [19, 16]], sf, fo],
      [fa9, ka9, sf, fo],
      [fa9, fb, ka9, ['kao_mco2', [9, 19, 16]], ['kao_mco', [9, 19, 16]], ['kbo_mo3', [19, 16]], sf, fo],
      [fa, fb, ka, kb, sf, fo],
      [fa9, ka9, ['kao_mn2', [9, 19, 16]], sf, fo],
      [fa9, fb, ka9, kb, sf, fo],
    ];
  })();

  static reducedName(n) {
    const u = n.indexOf('_');
    if (u >= 0) return n.slice(0, u - 1) + n.slice(u);
    return n.slice(0, -1);
  }

  static bundled() {
    if (!lwCache) lwCache = new RRTMGLongwaveTables({ dataFile: need('RRTMG_LW_DATA'), staticFile: need('rrtmg_lw_static.e1tab') });
    return lwCache;
  }

  // dataFile, staticFile - байты файлов (Uint8Array)
  constructor({ dataFile, staticFile }) {
    this.bands = []; this.common = {};
    const lit = RRTMGLongwaveTables.readE1Table(staticFile);
    Object.assign(this.common, lit);
    const { ngc, ngn, ngm, wt, ng } = lit;
    if (!ngc || !ngn || !ngm || !wt || !ng) throw new Error('RRTMG: в литеральных таблицах нет ngc/ngn/ngm/wt/ng');
    const mg = 16, nband = 16;
    const rwgt = RRTMGLongwaveTables.weights(ngc, ngn, ngm, wt, ng, nband, mg);
    this.common.rwgt = rwgt;

    const records = RRTMGLongwaveTables.readFortranRecords(dataFile);
    if (records.length !== nband) throw new Error(`RRTMG: в RRTMG_LW_DATA ${records.length} записей вместо 16`);
    for (let b = 0; b < nband; b++) {
      const layout = RRTMGLongwaveTables.recordLayout[b];
      const want = layout.reduce((s, [, sh]) => s + prod(sh), 0);
      if (records[b].f.length !== want) throw new Error(`RRTMG: полоса ${b + 1}: в записи ${records[b].f.length} чисел, по раскладке READ ${want}`);
      const band = { arrays: {}, shapes: {} };
      let off = 0;
      const nNew = ngc[b];
      for (const [name, shape] of layout) {
        const n = prod(shape);
        const src = records[b].f.subarray(off, off + n); off += n;
        const weighted = !name.startsWith('fracref');
        const igcStart = sumF(Array.from(ngc.slice(0, b)));
        const [out, newShape] = RRTMGLongwaveTables.fold(src, shape, nNew, weighted, rwgt, b, i => ngn[igcStart + i]);
        const rn = RRTMGLongwaveTables.reducedName(name);
        band.arrays[rn] = out; band.shapes[rn] = newShape;
      }
      this.bands.push(band);
    }

    // таблицы экспоненты (7966-7983)
    const ntbl = 10000;
    const pade = f(0.278), expeps = f(1.0e-20);
    const tau = new Float32Array(ntbl + 1), ex = new Float32Array(ntbl + 1), tfn = new Float32Array(ntbl + 1);
    tau[0] = 0; tau[ntbl] = 1.0e10; ex[0] = 1; ex[ntbl] = expeps; tfn[0] = 0; tfn[ntbl] = 1;
    const bpade = f(1.0 / pade);
    for (let itr = 1; itr < ntbl; itr++) {
      const t = f(itr / ntbl);
      tau[itr] = f(f(bpade * t) / f(1.0 - t));
      ex[itr] = libmExp()[itr];          // expf(-tau[itr]) системной libm
      if (ex[itr] <= expeps) ex[itr] = expeps;
      if (tau[itr] < 0.06) tfn[itr] = f(tau[itr] / 6.0);
      else tfn[itr] = fmaf(-2.0, f(f(1.0 / tau[itr]) - f(ex[itr] / f(1.0 - ex[itr]))), 1.0);
    }
    this.common.tau_tbl = tau; this.common.exp_tbl = ex; this.common.tfn_tbl = tfn;
    this.common.bpade = [bpade];
    // константы (8088-8145)
    const grav = f(9.8066), secdy = f(8.6400e4), cpdair = f(7.0 * 287.0 / 2.0);
    const pi = f(2.0 * f(Math.asin(1.0)));
    this.common.pi = [pi];
    this.common.fluxfac = [f(pi * 2.0e4)];
    this.common.heatfac = [f(f(grav * secdy) / f(cpdair * 1.0e2))];
    this.common.oneminus = [f(1.0 - f(1.0e-6))];
    this.common.grav = [grav]; this.common.secdy = [secdy];
  }

  // rwgt (7990-8014 LW, rrtmg_sw_ini 4680-4703 SW) - одна формула
  static weights(ngc, ngn, ngm, wt, ng, nband, mg) {
    const rwgt = new Float32Array(nband * mg);
    let igcsm = 0;
    for (let ibnd = 0; ibnd < nband; ibnd++) {
      let iprsm = 0;
      if (ngc[ibnd] < mg) {
        const wtsm = new Float32Array(mg);
        for (let igc = 0; igc < ngc[ibnd]; igc++) {
          igcsm += 1;
          let wtsum = 0;
          for (let r = 0; r < ngn[igcsm - 1]; r++) { iprsm += 1; wtsum = f(wtsum + wt[iprsm - 1]); }
          wtsm[igc] = wtsum;
        }
        for (let ig = 0; ig < ng[ibnd]; ig++) {
          const ind = ibnd * mg + ig;
          rwgt[ind] = f(wt[ig] / wtsm[ngm[ind] - 1]);
        }
      } else {
        for (let ig = 0; ig < ng[ibnd]; ig++) { igcsm += 1; rwgt[ibnd * mg + ig] = 1.0; }
      }
    }
    return rwgt;
  }

  // свёртка g-точек: сумма по исходным g нового g по порядку, с весом
  // rwgt (fma) или без (доли Планка, sfluxref). count(igc) - ngn нового g.
  static fold(src, shape, nNew, weighted, rwgt, b, count) {
    const gAxis = shape.indexOf(16);
    if (gAxis < 0) throw new Error('RRTMG: нет оси g');
    const newShape = shape.slice(); newShape[gAxis] = nNew;
    const stride = prod(shape.slice(0, gAxis)), outer = prod(shape.slice(gAxis + 1));
    const out = new Float32Array(prod(newShape));
    for (let o = 0; o < outer; o++) for (let s = 0; s < stride; s++) {
      let iprsm = 0;
      for (let igc = 0; igc < nNew; igc++) {
        let sum = 0;
        const cnt = count(igc);
        for (let r = 0; r < cnt; r++) {
          const x = src[s + stride * (iprsm + 16 * o)];
          sum = weighted ? fmaf(x, rwgt[iprsm + 16 * b], sum) : f(sum + x);
          iprsm += 1;
        }
        out[s + stride * (igc + nNew * o)] = sum;
      }
    }
    return [out, newShape];
  }

  // последовательный неформатированный Фортран, big-endian; запись -
  // { f: Float32Array, u: Uint32Array } на одних и тех же битах
  static readFortranRecords(d) {
    const dv = new DataView(d.buffer, d.byteOffset, d.byteLength);
    const recs = [];
    let o = 0;
    while (o < d.length) {
      const n = dv.getUint32(o, false);
      if (!(o + 8 + n <= d.length && dv.getUint32(o + 4 + n, false) === n && n % 4 === 0)) {
        throw new Error(`RRTMG: испорчена запись RRTMG_LW_DATA на байте ${o}`);
      }
      const u = new Uint32Array(n / 4);
      for (let k = 0; k < n / 4; k++) u[k] = dv.getUint32(o + 4 + 4 * k, false);
      recs.push({ u, f: new Float32Array(u.buffer) });
      o += 8 + n;
    }
    return recs;
  }

  // .e1state: «E1STATE\0», 4 int, число полей; поле - имя 16 байт, три размера, float32
  static readE1Table(d) {
    const head = 'E1STATE\0';
    if (d.length < 28 || [...head].some((c, i) => d[i] !== c.charCodeAt(0))) throw new Error('RRTMG: не e1state');
    const dv = new DataView(d.buffer, d.byteOffset, d.byteLength);
    let o = 24;
    const n = dv.getInt32(o, true); o += 4;
    const out = {};
    for (let q = 0; q < n; q++) {
      let name = '';
      for (let i = 0; i < 16 && d[o + i] !== 0; i++) name += String.fromCharCode(d[o + i]);
      o += 16;
      const cnt = dv.getInt32(o, true) * dv.getInt32(o + 4, true) * dv.getInt32(o + 8, true); o += 12;
      const u = new Uint32Array(cnt);
      for (let k = 0; k < cnt; k++) u[k] = dv.getUint32(o + 4 * k, true);
      out[name] = new Float32Array(u.buffer);
      o += 4 * cnt;
    }
    if (o !== d.length) throw new Error(`RRTMG: разобрано ${o} из ${d.length} байт`);
    return out;
  }
}

// ---- RRTMGShortwaveTables
export class RRTMGShortwaveTables {
  static recordLayout = (() => {
    const s = n => ({ name: n, shape: [], isInt: false });
    const lr = { name: 'layreffr', shape: [], isInt: true };
    const a = (n, sh) => ({ name: n, shape: sh, isInt: false });
    const ka9 = a('kao', [9, 5, 13, 16]), ka = a('kao', [5, 13, 16]);
    const kb = a('kbo', [5, 47, 16]), kb5 = a('kbo', [5, 5, 47, 16]);
    const sf = a('selfrefo', [10, 16]), fo3 = a('forrefo', [3, 16]), fo4 = a('forrefo', [4, 16]);
    const sfl = a('sfluxrefo', [16]), sfl5 = a('sfluxrefo', [16, 5]), sfl9 = a('sfluxrefo', [16, 9]);
    return [
      [s('rayl'), s('strrat1'), lr, ka9, kb, sf, fo3, sfl],
      [s('rayl'), s('strrat'), lr, ka9, kb5, sf, fo4, sfl5],
      [s('rayl'), s('strrat'), lr, ka9, kb, sf, fo3, sfl9],
      [s('rayl'), s('strrat'), lr, ka9, kb, sf, fo3, sfl9],
      [s('rayl'), lr, a('absch4o', [16]), ka, kb, sf, fo4, sfl],
      [s('rayl'), s('strrat'), lr, ka9, kb5, sf, fo4, sfl9],
      [s('rayl'), s('strrat'), lr, ka9, kb, sf, fo3, sfl9],
      [a('raylo', [16]), s('givfac'), lr, ka, sf, fo3, sfl],
      [a('raylao', [16, 9]), a('raylbo', [16]), s('strrat'), lr, a('abso3ao', [16]),
        a('abso3bo', [16]), ka9, kb, sf, fo3, sfl9],
      [a('raylo', [16]), lr, a('abso3ao', [16]), a('abso3bo', [16]), ka, sfl],
      [a('raylo', [16]), sfl],
      [a('raylo', [16]), s('scalekur'), lr, ka, kb, sfl],
      [s('rayl'), s('strrat'), lr, ka9, kb5, sfl5],
      [s('rayl'), lr, a('absh2oo', [16]), a('absco2o', [16]), ka, kb, sf, fo4, sfl],
    ];
  })();

  static bundled() {
    if (!swCache) swCache = new RRTMGShortwaveTables({ dataFile: need('RRTMG_SW_DATA'), staticFile: need('rrtmg_sw_static.e1tab') });
    return swCache;
  }

  constructor({ dataFile, staticFile }) {
    this.bands = []; this.common = {};
    const lit = RRTMGLongwaveTables.readE1Table(staticFile);
    Object.assign(this.common, lit);
    const { ngc, ngn, ngm, wt, ng } = lit;
    if (!ngc || !ngn || !ngm || !wt || !ng) throw new Error('RRTMG: в литеральных таблицах SW нет ngc/ngn/ngm/wt/ng');
    const mg = 16, nband = 14;
    const rwgt = RRTMGLongwaveTables.weights(ngc, ngn, ngm, wt, ng, nband, mg);
    this.common.rwgt = rwgt;
    const records = RRTMGLongwaveTables.readFortranRecords(dataFile);
    if (records.length !== nband) throw new Error(`RRTMG: в RRTMG_SW_DATA ${records.length} записей вместо 14`);
    for (let b = 0; b < nband; b++) {
      const layout = RRTMGShortwaveTables.recordLayout[b];
      const want = layout.reduce((s, fd) => s + prod(fd.shape), 0);
      if (records[b].f.length !== want) throw new Error(`RRTMG: полоса ${b + 16}: в записи ${records[b].f.length} чисел, по раскладке READ ${want}`);
      const band = { arrays: {}, shapes: {} };
      let off = 0;
      const nNew = ngc[b];
      const gBase = sumF(Array.from(ngc.slice(0, b)));
      for (const fd of layout) {
        const n = prod(fd.shape);
        const src = records[b].f.subarray(off, off + n), srcU = records[b].u.subarray(off, off + n); off += n;
        if (!fd.shape.length) {
          band.arrays[fd.name] = [fd.isInt ? f(srcU[0] | 0) : src[0]];
          band.shapes[fd.name] = [];
          continue;
        }
        const weighted = fd.name !== 'sfluxrefo';
        const [out, newShape] = RRTMGLongwaveTables.fold(src, fd.shape, nNew, weighted, rwgt, b, i => ngn[gBase + i]);
        const rn = fd.name.slice(0, -1);
        band.arrays[rn] = out; band.shapes[rn] = newShape;
      }
      this.bands.push(band);
    }
    const ntbl = 10000;
    const pade = f(0.278), expeps = f(1.0e-20);
    const ex = new Float32Array(ntbl + 1);
    ex[0] = 1; ex[ntbl] = expeps;
    const bpade = f(1.0 / pade);
    for (let itr = 1; itr < ntbl; itr++) {
      const t = f(itr / ntbl);
      const tau = f(f(bpade * t) / f(1.0 - t));
      ex[itr] = libmExp()[itr];          // expf(-tau) системной libm
      if (ex[itr] <= expeps) ex[itr] = expeps;
    }
    this.common.exp_tbl = ex;
    this.common.bpade = [bpade];
    const grav = f(9.8066), secdy = f(8.6400e4), cpdair = f(7.0 * 287.0 / 2.0);
    this.common.heatfac = [f(f(grav * secdy) / f(cpdair * 1.0e2))];
    this.common.oneminus = [f(1.0 - f(1.0e-6))];
    this.common.grav = [grav]; this.common.secdy = [secdy];
    this.common.pi = [f(2.0 * f(Math.asin(1.0)))];
  }
}

// ---- RRTMGLongwave
// BufRef(buffer, offset)
export class BufRef { constructor(buffer, offset = 0) { this.buffer = buffer; this.offset = offset; } }

export class RRTMGLongwave {
  static layers(nk, pTop) {
    const x = f(f(pTop * f(0.01)) / 4.0);
    return (nk + 1) + Math.sign(x) * Math.round(Math.abs(x)) - 1;
  }

  constructor({ context, lw, nk, pTop }) {
    this.ctx = context;
    this.nk = nk;
    this.nlayers = RRTMGLongwave.layers(nk, pTop);
    if (!(this.nlayers >= nk)) throw new Error('p_top < 2 гПа: слоёв над верхом нет (12324) — не проверено');
    this.chunk = 4096;
    this.debugColumn = -1;
    this.scratch = null; this.iscratch = null; this.dbgBuffer = null;
    const t = new Float32Array(RRTMGLongwaveLayout.floats);
    for (const [name, off, size] of RRTMGLongwaveLayout.entries) {
      const v = name === 'chi_mls' ? lw.common.chi_mls : lw.bands[+name.slice(0, 2) - 1].arrays[name.slice(3)];
      if (!v || v.length !== size) throw new Error(`RRTMG: таблица ${name}: нет или не того размера (${size})`);
      t.set(v, off);
    }
    const g = new Float32Array(35034);
    const put = (at, v, n) => {
      if (!v || v.length !== n) throw new Error(`RRTMG: общая таблица у ${at}: ${v?.length} вместо ${n}`);
      g.set(v, at);
    };
    const c = lw.common;
    put(0, c.pref, 59); put(59, c.preflog, 59); put(118, c.tref, 59);
    put(177, c.totplnk, 181 * 16); put(3073, c.delwave, 16);
    put(3089, c.tau_tbl, 10001); put(13090, c.exp_tbl, 10001); put(23091, c.tfn_tbl, 10001);
    const [o3wrk, ppwrkh] = RRTMGLongwave.ozoneClimatology();
    put(33092, o3wrk, 31); put(33123, ppwrkh, 32);
    put(33155, fl(RRTMGLongwaveLayout.pprof), 60); put(33215, fl(RRTMGLongwaveLayout.tprof), 60);
    put(33275, fl(RRTMGLongwaveLayout.retab), 95);
    put(33370, c.absliq1, 58 * 16); put(34298, c.absice3, 46 * 16);
    const d = context.device;
    this.tables = d.makeBuffer(t, 'rrtmg_lw.tables');
    this.common = d.makeBuffer(g, 'rrtmg_lw.common');
    this.fluxfac = c.fluxfac[0]; this.heatfac = c.heatfac[0]; this.bpade = c.bpade[0];
  }

  static ozoneClimatology() {
    const o3sum = fl(RRTMGLongwaveLayout.o3sum), ppsum = fl(RRTMGLongwaveLayout.ppsum);
    const o3win = fl(RRTMGLongwaveLayout.o3win), ppwin = fl(RRTMGLongwaveLayout.ppwin);
    const o3ann = new Array(31).fill(0);
    const ppann = ppsum;
    o3ann[0] = f(0.5 * f(o3sum[0] + o3win[0]));
    for (let k = 1; k < 31; k++) {
      const slope = f(f(o3win[k] - o3win[k - 1]) / f(ppwin[k] - ppwin[k - 1]));
      o3ann[k] = fmaf(slope, f(ppsum[k] - ppwin[k - 1]), o3win[k - 1]);
    }
    for (let k = 1; k < 31; k++) o3ann[k] = f(0.5 * f(o3ann[k] + o3sum[k]));
    const ppwrkh = new Array(32).fill(0);
    ppwrkh[0] = 1100.0;
    for (let k = 1; k < 31; k++) ppwrkh[k] = f(f(ppann[k] + ppann[k - 1]) / 2.0);
    ppwrkh[31] = 0.0;
    return [o3ann, ppwrkh];
  }

  static co2(year) {
    // системный expf из таблицы; вне 1900...2100 - счёт в double (может разойтись на 1 ulp)
    const e = year >= 1900 && year <= 2100 && raw['expf_tables.bin'] ? libmExp()[10001 + year - 1900]
      : expf(f(f(0.02) * f(year - 2000)));
    return f(fmaf(90.0, e, 280.0) * f(1.0e-6));
  }

  // encode(into: cb, ncol:, co2:, inputs:, heating:, surface:, failures:)
  // inputs: { p8w, p3d, t3d, t8w, qv, tsk, emiss, qc, qi, qs, cldfra, effc, effi, effs, xland } - BufRef
  encode(cb, ncol, co2, x, heating, surface, failures) {
    const d = this.ctx.device, nl = this.nlayers;
    const dbgCount = 2 + 14 * nl + 2 * (nl + 1) + 16 * nl + 16 * (nl + 1) + 16 + 280 * nl + 2 * (nl + 1) + nl;
    if (!this.dbgBuffer) this.dbgBuffer = d.makeBuffer(dbgCount * 4);
    const per = 60 * nl + 9 * (nl + 1) + 48 * nl + 16 * (nl + 1) + 16 + 11 * nl;
    const iper = 7 * nl + Math.trunc((140 * nl + 31) / 32);
    const n = Math.min(this.chunk, ncol);
    if (!this.scratch || this.scratch.length < n * per * 4) {
      this.scratch = d.makeBuffer(n * per * 4);
      this.iscratch = d.makeBuffer(n * iper * 4);
    }
    const ins = [x.p8w, x.p3d, x.t3d, x.t8w, x.qv, x.tsk, x.emiss];
    const clouds = [x.qc, x.qi, x.qs, x.cldfra, x.effc, x.effi, x.effs, x.xland];
    let off = 0;
    while (off < ncol) {
      const m = Math.min(n, ncol - off);
      // RRLWParamsGPU: nk, nlayers, ncol, colOffset, co2, fluxfac, heatfac, bpade, debugCol, zero
      const p = packed([['i', this.nk], ['i', nl], ['i', m], ['i', off], ['f', co2], ['f', this.fluxfac],
        ['f', this.heatfac], ['f', this.bpade], ['i', this.debugColumn], ['u', 0]]);
      const e = cb.makeComputeCommandEncoder();
      e.label = 'rrlw_columns';
      e.setComputePipelineState(this.ctx.pipeline('rrlw_columns'));
      e.setBytes(p, 0);
      e.setBuffer(this.tables, 0, 1);
      e.setBuffer(this.common, 0, 2);
      ins.forEach((b, i) => e.setBuffer(b.buffer, b.offset, 3 + i));
      e.setBuffer(this.scratch, 0, 10);
      e.setBuffer(this.iscratch, 0, 11);
      e.setBuffer(heating, 0, 12);
      e.setBuffer(surface, 0, 13);
      e.setBytes(packed([['i', ncol]]), 14);
      clouds.forEach((b, i) => e.setBuffer(b.buffer, b.offset, 15 + i));
      e.setBuffer(failures, 0, 23);
      e.setBuffer(this.dbgBuffer, 0, 24);
      this.ctx.checkedDispatch(e, 'rrlw_columns', [m, 1, 1], [32, 1, 1]);
      e.endEncoding();
      off += m;
    }
  }
}

// ---- RRTMGShortwave
export class RRTMGShortwave {
  constructor({ context, sw, common, nk }) {
    this.ctx = context;
    this.nk = nk;
    this.common = common;
    this.chunk = 512;
    this.debugColumn = -1;
    this.scratch = null; this.iscratch = null; this.dbgBuffer = null;
    const t = new Float32Array(RRTMGShortwaveLayout.floats);
    for (const [name, off, size] of RRTMGShortwaveLayout.entries) {
      const dot = name.indexOf('.');
      const v = dot >= 0 ? sw.bands[+name.slice(0, dot) - 16].arrays[name.slice(dot + 1)] : sw.common[name];
      if (!v || v.length !== size) throw new Error(`RRTMG: таблица SW ${name}: нет или не того размера (${size})`);
      t.set(v, off);
    }
    this.tables = context.device.makeBuffer(t, 'rrtmg_sw.tables');
    this.heatfac = sw.common.heatfac[0];
  }
  get nlayers() { return this.nk + 1; }

  // encode(into: cb, ncol:, co2:, scon:, inputs:, heating:, surface:, failures:)
  // inputs: { p8w, p3d, t3d, t8w, qv, tsk, albd, qc, qi, qs, cldfra, effc, effi, effs, xland, coszen } - BufRef
  encode(cb, ncol, co2, scon, x, heating, surface, failures) {
    const d = this.ctx.device, nl = this.nlayers;
    const dbgCount = 3 + 28 + 2 * nl + (nl + 1) + nl + 7 * nl + 3 * nl + 4 * nl + 6 * nl + 6 * nl
      + 8 * 112 * nl + 3 * nl + 4 * (nl + 1) + nl + 2 * 112 * nl + 112;
    if (!this.dbgBuffer) this.dbgBuffer = d.makeBuffer(dbgCount * 4);
    const per = 22 * nl + 2 * (nl + 1) + 7 * nl + 9 * 112 * nl + 2 * 112 * nl + 112 + 14 + 14 + 29
      + 14 * (nl + 1) + 20 * nl + 2 * (nl + 1) + 13 * 112 + 45 * (nl + 1) + 112;
    const iper = 5 * nl + 2 * nl + Math.trunc((112 * nl + 31) / 32);
    const n = Math.min(this.chunk, ncol);
    if (!this.scratch || this.scratch.length < n * per * 4) {
      this.scratch = d.makeBuffer(n * per * 4);
      this.iscratch = d.makeBuffer(n * iper * 4);
    }
    const ins = [x.p8w, x.p3d, x.t3d, x.t8w, x.qv, x.tsk, x.albd];
    const clouds = [x.qc, x.qi, x.qs, x.cldfra, x.effc, x.effi, x.effs, x.xland];
    let off = 0;
    while (off < ncol) {
      const m = Math.min(n, ncol - off);
      // RRSWParamsGPU: nk, ncol, colOffset, co2, scon, heatfac, debugCol, zero
      const p = packed([['i', this.nk], ['i', m], ['i', off], ['f', co2], ['f', scon], ['f', this.heatfac],
        ['i', this.debugColumn], ['u', 0]]);
      const e = cb.makeComputeCommandEncoder();
      e.label = 'rrsw_columns';
      e.setComputePipelineState(this.ctx.pipeline('rrsw_columns'));
      e.setBytes(p, 0);
      e.setBuffer(this.tables, 0, 1);
      e.setBuffer(this.common, 0, 2);
      ins.forEach((b, i) => e.setBuffer(b.buffer, b.offset, 3 + i));
      e.setBuffer(this.scratch, 0, 10);
      e.setBuffer(this.iscratch, 0, 11);
      e.setBuffer(heating, 0, 12);
      e.setBuffer(surface, 0, 13);
      e.setBytes(packed([['i', ncol]]), 14);
      clouds.forEach((b, i) => e.setBuffer(b.buffer, b.offset, 15 + i));
      e.setBuffer(failures, 0, 23);
      e.setBuffer(x.coszen.buffer, x.coszen.offset, 24);
      e.setBuffer(this.dbgBuffer, 0, 25);
      this.ctx.checkedDispatch(e, 'rrsw_columns', [m, 1, 1], [32, 1, 1]);
      e.endEncoding();
      off += m;
    }
  }
}

// ---- RadiationSun
// sin и cos одного аргумента у CM1 - cexpf(i·x) из системной libm (gfortran),
// а не sinf/cosf. Здесь - sin/cos в double с округлением во float: где
// системный cexpf округляет иначе, julian/coszen/solcon разойдутся на 1 ulp
// (видно по байтам rad_prep / rrsw_columns в сверке).
const sincos = x => ({ sin: f(Math.sin(x)), cos: f(Math.cos(x)) });   // системный cexpf - правильно округлён

export class RadiationSun {
  constructor({ year, month, day, hour, minute, second, ctrlat, ctrlon, dtrad, testcase = 0 }) {
    Object.assign(this, { year, month, day, hour, minute, second, ctrlat: f(ctrlat), ctrlon: f(ctrlon), dtrad: f(dtrad), testcase });
  }
  static julday(year, month, day) {
    const mndys = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    const lpyear = (year % 400 === 0 || (year % 4 === 0 && year % 100 !== 0)) ? 1 : 0;
    const lp = month > 2 ? lpyear : 0;
    return mndys[month - 1] + day + lp;
  }
  static dpd = f(360.0 / 365.0);
  static degrad = f(f(Math.PI) / 180.0);

  // compute(mtime:, dt:) -> { julian, declin, solcon, coszen }
  compute(mtime, dt) {
    const S = RadiationSun, degrad = S.degrad;
    const jday = S.julday(this.year, this.month, this.day);
    const a = f(f(f(f(jday) - 1.0) + f(f(this.hour) / 24.0)) + f(f(this.minute) / f(60.0 * 24.0)));
    const julian = f(a + (this.second + mtime) / f(60.0 * 60.0 * 24.0));
    const dtradE = Math.max(this.dtrad, f(dt));
    const obecl = f(23.5 * degrad);
    const sinob = sinf(obecl);
    let sxlong = julian >= 80.0 ? f(S.dpd * f(julian - 80.0)) : f(S.dpd * f(julian + 285.0));
    sxlong = f(sxlong * degrad);
    const arg = f(sinob * sinf(sxlong));
    const declin = asinf(arg);
    const djul = f(f(julian * 360.0) / 365.0);
    const rjul = f(djul * degrad);
    const r1 = sincos(rjul), r2 = sincos(f(2.0 * rjul));
    let ecc = fmaf(f(0.034221), r1.cos, f(1.000110));
    ecc = fmaf(f(0.001280), r1.sin, ecc);
    ecc = fmaf(f(0.000719), r2.cos, ecc);
    ecc = fmaf(f(0.000077), r2.sin, ecc);
    let solcon = f(1370.0 * ecc);
    const tfoo = f((mtime + f(0.5 * dtradE)) / 60.0);
    const da = f(f(f(6.2831853071795862) * f(julian - 1.0)) / 365.0);
    const d1 = sincos(da), d2 = sincos(f(2.0 * da));
    let eot = fmaf(f(0.001868), d1.cos, f(0.000075));
    eot = fmaf(f(-0.032077), d1.sin, eot);
    eot = fmaf(f(-0.014615), d2.cos, eot);
    eot = fmaf(f(-0.04089), d2.sin, eot);
    eot = f(eot * f(229.18));
    const xt24 = f(f(tfoo % 1440.0) + eot);
    const gmt = f(this.hour);
    const tloctm = f(f(gmt + f(xt24 / 60.0)) + f(this.ctrlon / 15.0));
    const hrang = f(f(15.0 * f(tloctm - 12.0)) * degrad);
    const xxlat = f(this.ctrlat * degrad);
    const lat = sincos(xxlat), dec = sincos(declin);
    let coszen = fmaf(lat.sin, dec.sin, f(f(lat.cos * dec.cos) * cosf(hrang)));
    if (this.testcase === 8) {
      solcon = f(650.83);
      const piF = f(Math.PI);
      coszen = f(Math.cos(f(f(f(50.5) * piF) / 180.0)));   // константа: cos в double
    }
    return { julian, declin, solcon, coszen };
  }
}

// ---- RadiationDriver
export class RadiationDriver {
  static arenaFields = ['lwten', 'swten', 'effc', 'effi', 'effs'];

  constructor({ context, grid, vertical, th0, pi0, lw, sw, sun, co2, emiss, albd, xland }) {
    this.ctx = context; this.grid = grid; this.lw = lw; this.sw = sw; this.sun = sun; this.co2 = f(co2);
    this.emiss = f(emiss); this.albd = f(albd); this.xland = f(xland);
    this.eqtset = 2;
    this.surfacePerPoint = false;
    this.lastSun = null;
    if (!(lw.nk === grid.nz && sw.nk === grid.nz)) throw new Error('RRTMG собран на другое nk');
    const d = context.device;
    this.th0b = vertical.buffer(th0, d, 'rad.th0');
    this.pi0b = vertical.buffer(pi0, d, 'rad.pi0');
    const buf = (v, l) => { const b = d.makeBuffer(Math.max(4, v.length * 4), l); b.f32.set(v); return b; };
    this.c1b = buf(vertical.c1, 'rad.c1'); this.c2b = buf(vertical.c2, 'rad.c2');
    this.cgs = vertical.surfaceExtrapolation; this.cgt = vertical.topExtrapolation;
    const nc = grid.nx * grid.ny, nk = grid.nz;
    const priv = (n, l) => d.makeBuffer(Math.max(4, n * 4), l);
    this.prep = d.makeBuffer((2 * nc * (nk + 1) + 10 * nc * nk + 5 * nc) * 4, 'rad.inputs');
    this.lwh = priv(nc * nk, 'rad.lw.heat'); this.swh = priv(nc * nk, 'rad.sw.heat');
    this.lws = d.makeBuffer(nc * 8 * 4);
    this.sws = d.makeBuffer(nc * 8 * 4);
    this.fail = d.makeBuffer(8);
    this.stateBuffer = d.makeBuffer(8, 'rad.radtim');
    this.radtim = 0;
    this.dims = gridDims(grid);
  }

  get radtim() { return new DataView(this.stateBuffer.ab).getFloat64(0, true); }
  set radtim(v) { new DataView(this.stateBuffer.ab).setFloat64(0, v, true); }
  get failures() { return this.fail.u32[0]; }
  get surfaceLW() { return this.lws; }
  get surfaceSW() { return this.sws; }

  isRadiationStep(modelTime, dt) { return modelTime + dt >= this.radtim - 0.1 * dt; }

  inputs() {
    const nc = this.grid.nx * this.grid.ny, nk = this.grid.nz, p = this.prep.f32;
    const out = {}; let o = 0;
    const take = (n, c) => { out[n] = Array.from(p.subarray(o, o + c)); o += c; };
    take('p8w', nc * (nk + 1)); take('t8w', nc * (nk + 1));
    for (const n of ['p3d', 't3d', 'qv', 'qc', 'qi', 'qs', 'cldfra', 'effc', 'effi', 'effs']) take(n, nc * nk);
    for (const n of ['tsk', 'emiss', 'albd', 'xland', 'coszen']) take(n, nc);
    return out;
  }

  // encodeCall(into: cb, arena:, surface:, modelTime:, dt:)
  encodeCall(cb, arena, sfc, modelTime, dt) {
    const r = this.sun.compute(modelTime, f(dt));
    this.lastSun = r;
    const b = arena.buffer, off = n => arena.handle(n).offset;
    const g = this.grid, nc = g.nx * g.ny, nk = g.nz;
    const e = cb.makeComputeCommandEncoder();
    e.label = 'rad_prep';
    e.setComputePipelineState(this.ctx.pipeline('rad_prep'));
    // RadPrepParamsGPU: cgs1..3, cgt1..3, emiss, albd, xland, coszen (Float), zero (UInt32), perPoint (Int32)
    const rp = packed([['f', this.cgs[0]], ['f', this.cgs[1]], ['f', this.cgs[2]], ['f', this.cgt[0]], ['f', this.cgt[1]],
      ['f', this.cgt[2]], ['f', this.emiss], ['f', this.albd], ['f', this.xland], ['f', r.coszen], ['u', 0],
      ['i', this.surfacePerPoint ? 1 : 0]]);
    e.setBytes(this.dims, 0);
    e.setBytes(rp, 1);
    e.setBuffer(this.th0b, 0, 2); e.setBuffer(this.pi0b, 0, 3);
    e.setBuffer(this.c1b, 0, 4); e.setBuffer(this.c2b, 0, 5);
    ['th', 'pp3d', 'prs', 'qv', 'qc', 'qi', 'qs', 'effc', 'effi', 'effs'].forEach((n, i) => e.setBuffer(b, off(n), 6 + i));
    e.setBuffer(sfc, 0, 16);
    e.setBuffer(this.prep, 0, 17);
    this.ctx.checkedDispatch(e, 'rad_prep', [g.nx, g.ny, 1], [8, 8, 1]);
    e.endEncoding();

    const at = floats => new BufRef(this.prep, floats * 4);
    const face = nc * (nk + 1), lay = nc * nk, base = 2 * face;
    const p8w = at(0), t8w = at(face);
    const p3d = at(base), t3d = at(base + lay), qv = at(base + 2 * lay), qc = at(base + 3 * lay);
    const qi = at(base + 4 * lay), qs = at(base + 5 * lay), cf = at(base + 6 * lay);
    const ec = at(base + 7 * lay), ei = at(base + 8 * lay), es = at(base + 9 * lay);
    const col = base + 10 * lay;
    const tsk = at(col), em = at(col + nc), al = at(col + 2 * nc), xl = at(col + 3 * nc), cz = at(col + 4 * nc);
    this.lw.encode(cb, nc, this.co2,
      { p8w, p3d, t3d, t8w, qv, tsk, emiss: em, qc, qi, qs, cldfra: cf, effc: ec, effi: ei, effs: es, xland: xl },
      this.lwh, this.lws, this.fail);
    this.sw.encode(cb, nc, this.co2, r.solcon,
      { p8w, p3d, t3d, t8w, qv, tsk, albd: al, qc, qi, qs, cldfra: cf, effc: ec, effi: ei, effs: es, xland: xl, coszen: cz },
      this.swh, this.sws, this.fail);

    const e2 = cb.makeComputeCommandEncoder();
    e2.label = 'rad_post';
    e2.setComputePipelineState(this.ctx.pipeline('rad_post'));
    const cp = f(Constants.cp), rd = f(Constants.rd), rv = f(Constants.rv), cpv = f(Constants.cpv);
    // RadPostParamsGPU: cp, cv, cvv, cpl, cpi (Float), eqtset (Int32)
    const pp = packed([['f', cp], ['f', f(cp - rd)], ['f', f(cpv - rv)], ['f', f(Constants.cpl)], ['f', f(Constants.cpi)],
      ['i', this.eqtset]]);
    e2.setBytes(this.dims, 0);
    e2.setBytes(pp, 1);
    e2.setBuffer(this.lwh, 0, 2); e2.setBuffer(this.swh, 0, 3);
    ['qv', 'qc', 'qr', 'qi', 'qs', 'qg', 'lwten', 'swten'].forEach((n, i) => e2.setBuffer(b, off(n), 4 + i));
    this.ctx.checkedDispatch(e2, 'rad_post', [g.nx, g.ny, g.nz], [32, 4, 1]);
    e2.endEncoding();

    if (this.surfacePerPoint) {
      const e3 = cb.makeComputeCommandEncoder();
      e3.label = 'rad_sfc_copy';
      e3.setComputePipelineState(this.ctx.pipeline('rad_sfc_copy'));
      e3.setBytes(this.dims, 0);
      e3.setBuffer(this.lws, 0, 1); e3.setBuffer(this.sws, 0, 2);
      e3.setBuffer(sfc, 0, 3);
      this.ctx.checkedDispatch(e3, 'rad_sfc_copy', [g.nx, g.ny, 1], [8, 8, 1]);
      e3.endEncoding();
    }
    // cm1.F:3213-3218
    const dtrad = Math.max(this.sun.dtrad, dt);
    do { this.radtim = this.radtim + dtrad; } while (!(this.radtim > modelTime));
  }

  // encodeApply(e, arena:, thten1:, tha:, qv:, dt:) - в общий энкодер шага
  encodeApply(e, arena, thten1, tha, qv, dt) {
    const b = arena.buffer, off = n => arena.handle(n).offset, g = this.grid;
    e.setComputePipelineState(this.ctx.pipeline('rad_apply'));
    const rd = f(Constants.rd), cp = f(Constants.cp);
    // RadApplyParamsGPU: dt, rdt, rd, rv, rp00, rovcp (Float), eqtset (Int32)
    const ap = packed([['f', f(dt)], ['f', f(1.0 / f(dt))], ['f', rd], ['f', f(Constants.rv)], ['f', f(1.0 / f(Constants.p00))],
      ['f', f(rd / cp)], ['i', this.eqtset]]);
    e.setBytes(this.dims, 0);
    e.setBytes(ap, 1);
    e.setBuffer(this.th0b, 0, 2); e.setBuffer(this.pi0b, 0, 3);
    [tha, 'ppi', 'rho', qv, 'lwten', 'swten', thten1].forEach((n, i) => e.setBuffer(b, off(n), 4 + i));
    this.ctx.checkedDispatch(e, 'rad_apply', [g.nx, g.ny, g.nz], [32, 4, 1]);
  }
}

// ---- SolarPosition (наш расчёт для изображения, не CM1); date - Date (UTC)
export const SolarPosition = {
  obliquity: 23.439,
  at(date, latitude, longitude) {
    const e = SolarPosition.ecliptic(date);
    const lst = (e.gmstHours * 15 + longitude) * Math.PI / 180;
    const ha = lst - e.rightAscension;
    const lat = latitude * Math.PI / 180;
    const sinEl = Math.sin(lat) * Math.sin(e.declination) + Math.cos(lat) * Math.cos(e.declination) * Math.cos(ha);
    const el = Math.asin(Math.max(-1, Math.min(1, sinEl)));
    const y = -Math.sin(ha) * Math.cos(e.declination);
    const x = Math.sin(e.declination) * Math.cos(lat) - Math.cos(e.declination) * Math.sin(lat) * Math.cos(ha);
    let az = Math.atan2(y, x);
    if (az < 0) az += 2 * Math.PI;
    return { elevation: el, azimuth: az, get cosZenith() { return Math.sin(el); } };
  },
  ecliptic(date) {
    const jd = date.getTime() / 1000 / 86400 + 2440587.5;
    const n = jd - 2451545.0;
    const rad = Math.PI / 180;
    const meanLongitude = (280.460 + 0.9856474 * n) % 360;
    const meanAnomaly = ((357.528 + 0.9856003 * n) % 360) * rad;
    const lambda = (meanLongitude + 1.915 * Math.sin(meanAnomaly) + 0.020 * Math.sin(2 * meanAnomaly)) * rad;
    const obliquityRad = (SolarPosition.obliquity - 0.0000004 * n) * rad;
    const decl = Math.asin(Math.sin(obliquityRad) * Math.sin(lambda));
    const ra = Math.atan2(Math.cos(obliquityRad) * Math.sin(lambda), Math.cos(lambda));
    const gmst = (18.697374558 + 24.06570982441908 * n) % 24;
    return { declination: decl, rightAscension: ra, gmstHours: gmst < 0 ? gmst + 24 : gmst };
  },
  declination(date) { return SolarPosition.ecliptic(date).declination * 180 / Math.PI; },
};
