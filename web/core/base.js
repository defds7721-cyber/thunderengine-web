// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Базовое состояние и начальные возмущения: BaseState, InitialPerturbations,
// WarmBubble, LineThermal, HashRand, а также Sounding и SoundingFactory.
//
// Float-арифметика - через f() после каждой операции и литералы
// Float - через f(литерал); fma - fmaf. Double - как есть.
import { f, fmaf } from './f32.js';
import { powf, expf, logf, cosf, sinf, tanhf } from './libm.js';   // копии эталонной libm, не fround(Math.*)
import { ThermoConstants } from './grid.js';

const zerosF = n => new Array(n).fill(0);

// ---- Float(String): десятичная строка -> ближайший float одним округлением.
// Через double - два округления; расходятся только когда double попал ровно
// в середину между соседними float: тогда решает точное сравнение (BigInt).
const F1 = new Float32Array(1), U1 = new Uint32Array(F1.buffer);
const NUM = /^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/;
function bigRational(s) {               // точное значение десятичной строки: [num, den]
  let m = s.match(/^([+-]?)(\d*)\.?(\d*)(?:[eE]([+-]?\d+))?$/);
  const sign = m[1] === '-' ? -1n : 1n;
  const digits = (m[2] || '') + (m[3] || '');
  let exp = BigInt(m[4] || 0) - BigInt((m[3] || '').length);
  let num = BigInt(digits || '0') * sign, den = 1n;
  if (exp >= 0n) num *= 10n ** exp; else den = 10n ** (-exp);
  return [num, den];
}
function doubleRational(x) {            // точное значение double: [num, den]
  const dv = new DataView(new ArrayBuffer(8)); dv.setFloat64(0, x);
  const hi = dv.getUint32(0), lo = dv.getUint32(4);
  const sign = hi >>> 31 ? -1n : 1n, e = (hi >>> 20) & 0x7ff;
  let mant = (BigInt(hi & 0xfffff) << 32n) | BigInt(lo);
  let ex;
  if (e === 0) ex = -1074n; else { mant |= 1n << 52n; ex = BigInt(e) - 1075n; }
  return ex >= 0n ? [sign * (mant << ex), 1n] : [sign * mant, 1n << (-ex)];
}
export function parseFloat32(s) {
  if (!NUM.test(s)) return null;
  const x = Number(s);
  const r = f(x);
  if (r === x || !isFinite(x)) return r;
  F1[0] = r; U1[0] += (r > x) === (r > 0) ? -1 : 1;
  const other = F1[0];
  if (Math.abs(x - r) !== Math.abs(other - x)) return r;   // не середина
  const [an, ad] = bigRational(s), [mn, md] = doubleRational(x);   // x - ровно середина
  const cmp = an * md - mn * ad;                                    // знак (строка - середина)
  if (cmp === 0n) return r;                                         // настоящая середина: к чётному, как fround
  return cmp > 0n ? Math.max(r, other) : Math.min(r, other);
}

// ---- String(format: "%W.Nf"): точная двоичная величина, середина - к чётному
function digitsOf(x, n) {               // строка с n знаками после точки, |x|
  const exact = x.toFixed(100);         // для наших величин - точное разложение
  const i = exact.indexOf('.');
  const kept = exact.slice(0, i + 1 + n), rest = exact.slice(i + 1 + n);
  const t = x.toFixed(n);               // округлено «середина от нуля»
  if (/^50*$/.test(rest)) {             // ровно середина
    const last = kept.endsWith('.') ? +kept[kept.length - 2] : +kept[kept.length - 1];
    if (last % 2 === 0) return n === 0 ? kept.slice(0, -1) : kept;
  }
  return t;
}
export function printfFixed(x, width, n) {
  let s = Object.is(x, -0) ? '-' + digitsOf(0, n) : x < 0 ? '-' + digitsOf(-x, n) : digitsOf(x, n);
  return s.padStart(width, ' ');
}

// ---- BaseState
export class BaseStateF32 {
  constructor(t) {
    this.g = f(t.g); this.rd = f(t.rd); this.cp = f(t.cp); this.rv = f(t.rv);
    this.p00 = f(t.p00); this.rp00 = f(1.0 / f(t.p00));
    this.reps = f(this.rv / this.rd); this.eps = f(this.rd / this.rv);
    this.rovcp = f(this.rd / this.cp); this.cpdrd = f(this.cp / this.rd);
    this.xlv = f(t.xlv);
  }
}

const pi32 = f(Math.PI);

export class BaseState {
  static zTrop = 12000.0; static thTrop = 343.0; static tTrop = 213.0; static thSfc = 300.0;
  static prsSfc = 100000.0; static qvPbl = 0.014;
  static uDep1 = 2000.0; static uDep2 = 6000.0; static uMax1 = 7.0; static uMax2 = 31.0;
  static fma(a, b, c) { return fmaf(a, b, c); }
  static F32 = BaseStateF32;

  static rslf(p, t, eps = ThermoConstants.cm1.eps) {
    let esl = 611.2 * Math.exp(17.67 * (t - 273.15) / (t - 29.65));
    esl = Math.min(esl, p * 0.5);
    return eps * esl / (p - esl);
  }
  static rslf32(p, t, eps) {
    let esl = f(f(611.2) * expf(f(f(f(17.67) * f(t - f(273.15))) / f(t - f(29.65)))));
    esl = Math.min(esl, f(p * 0.5));
    return f(f(eps * esl) / f(p - esl));
  }
  static rsif(p, t, eps = ThermoConstants.cm1.eps) {
    let esi = 611.2 * Math.exp(21.8745584 * (t - 273.15) / (t - 7.66));
    esi = Math.min(esi, p * 0.5);
    return eps * esi / (p - esi);
  }

  // init(zh:moist:umove:vmove:iterations:wind:qvPbl:)
  static weismanKlemp({ zh, moist = true, umove = 0.0, vmove = 0.0, iterations = 20, wind = { kind: 'weismanKlemp' },
    qvPbl = BaseState.qvPbl }) {
    return new BaseState({ sounding: { kind: 'weismanKlemp', qvPbl }, zh, moist, umove, vmove, wind, iterations });
  }

  // init(sounding:zh:moist:umove:vmove:wind:iterations:thermo:) или
  // init(th0:qv0:pi0:u0:v0:rh0:thermo:) - по наличию th0
  constructor(a) {
    if (a.th0) { this.initProfiles(a); return; }
    const { sounding, zh: zhD, moist, umove, vmove, wind, iterations = 20, thermo = ThermoConstants.cm1 } = a;
    this.thermo = thermo;
    const c = new BaseStateF32(thermo);
    const zh = zhD.map(f);
    let p;
    switch (sounding.kind) {
      case 'weismanKlemp': p = BaseState.weismanKlempProfiles(zh, moist, f(sounding.qvPbl), iterations, c); break;
      case 'constantLapse': p = BaseState.constantLapseProfiles(zh, sounding.testcase, c); break;
      case 'constantN': p = BaseState.constantNProfiles(zh, c); break;
      case 'convectiveBoundaryLayer':
        p = BaseState.inversionProfiles(zh, f(300.0), f(974.0), f(0.08), f(1074.0), f(0.003), c); break;
      case 'shearBoundaryLayer': {
        const delz = f(60.0);
        p = BaseState.inversionProfiles(zh, f(300.0), f(f(465.0) - f(delz / f(2.0))), f(f(8.0) / delz),
          f(f(465.0) + f(delz / f(2.0))), f(0.003), c);
        break;
      }
      case 'stableBoundaryLayer': p = BaseState.inversionProfiles(zh, f(265.0), f(100.0), f(0.01), null, 0, c); break;
      case 'bomex': p = BaseState.piecewiseProfiles(zh, sounding.testcase, c); break;
      case 'rico': p = BaseState.piecewiseProfiles(zh, null, c); break;
      case 'dycoms': p = BaseState.dycomsProfiles(zh, sounding.testcase, c); break;
      default: throw new Error('зондировка ' + sounding.kind);
    }
    const t = BaseState.tail(p.th, p.qv, p.rh, p.pi, p.qc ?? null, moist, c);
    this.th0 = t.th; this.qv0 = t.qv; this.rh0 = t.rh; this.thv0 = t.thv; this.pi0 = t.pi;
    this.prs0 = t.prs; this.rho0 = t.rho; this.t0 = t.t; this.qc0 = t.qc;
    const w = BaseState.windProfile(wind, zh);
    const um = f(umove), vm = f(vmove);
    this.u0 = w.u.map(x => f(x - um));
    this.v0 = w.v.map(x => f(x - vm));
  }

  initProfiles({ th0, qv0, pi0, u0, v0, rh0, thermo = ThermoConstants.cm1 }) {
    this.thermo = thermo;
    const nk = th0.length;
    const c = new BaseStateF32(thermo);
    const t = BaseState.tail(th0.map(f), qv0.map(f), rh0.map(f), pi0.map(f), null, true, c);
    this.th0 = th0; this.qv0 = qv0; this.pi0 = pi0;
    this.prs0 = t.prs; this.t0 = t.t; this.rho0 = t.rho; this.thv0 = t.thv;
    this.rh0 = rh0; this.u0 = u0; this.v0 = v0;
    this.qc0 = zerosF(nk);
  }

  static tail(th, qvIn, rhIn, pi, qcIn, moist, c) {
    const nk = th.length;
    const qv = qvIn.slice(), rh = rhIn.slice();
    const qc = qcIn ? qcIn.slice() : zerosF(nk);
    const thv = zerosF(nk);
    if (moist) {
      for (let k = 0; k < nk; k++) thv[k] = f(f(th[k] * fmaf(c.reps, qv[k], 1.0)) / f(f(f(1.0 + qv[k]) + qc[k]) + 0.0));
    } else {
      for (let k = 0; k < nk; k++) { qv[k] = 0.0; rh[k] = 0.0; thv[k] = th[k]; qc[k] = 0.0; }
    }
    const prs = pi.map(x => f(c.p00 * powf(x, c.cpdrd)));
    const rho = th.map((_, k) => f(prs[k] / f(f(f(c.rd * th[k]) * pi[k]) * fmaf(qv[k], c.reps, 1.0))));
    const t = th.map((_, k) => f(th[k] * pi[k]));
    if (moist) {
      for (let k = 0; k < nk; k++) {
        const q = Math.max(0.0, qv[k]);
        thv[k] = f(f(f(th[k] + 0.0) * fmaf(c.reps, q, 1.0)) / f(f(1.0 + q) + Math.max(0.0, f(qc[k] + 0.0))));
      }
    }
    return { th, qv, rh, thv, pi, prs, rho, t, qc };
  }

  static weismanKlempProfiles(zh, moist, qvPbl, iterations, c) {
    const nk = zh.length;
    const zTrop = f(BaseState.zTrop), thTrop = f(BaseState.thTrop), tTrop = f(BaseState.tTrop);
    const thSfc = f(BaseState.thSfc), prsSfc = f(BaseState.prsSfc);
    const piSfc = powf(f(prsSfc / c.p00), f(c.rd / c.cp));
    const qvSfc = BaseState.rslf32(prsSfc, f(thSfc * piSfc), c.eps);
    const thvSfc = f(f(thSfc * fmaf(qvSfc, c.reps, 1.0)) / f(1.0 + qvSfc));
    const th = zerosF(nk), rh = zerosF(nk);
    for (let k = 0; k < nk; k++) {
      const z = zh[k];
      if (z < zTrop) {
        const fr = powf(f(z / zTrop), f(1.25));
        th[k] = fmaf(f(thTrop - thSfc), fr, thSfc);
        if (moist) rh[k] = fmaf(f(-0.75), fr, 1.0);
      } else {
        th[k] = f(thTrop * expf(f(f(c.g / f(tTrop * c.cp)) * f(z - zTrop))));
        if (moist) rh[k] = f(0.25);
      }
    }
    const qv = zerosF(nk), thv = zerosF(nk), pi = zerosF(nk), prs = zerosF(nk);
    const cpOverRd = f(c.cp / c.rd);
    for (let it = 0; it < iterations; it++) {
      for (let k = 0; k < nk; k++) thv[k] = f(f(th[k] * fmaf(c.reps, qv[k], 1.0)) / f(1.0 + qv[k]));
      pi[0] = f(piSfc - f(f(c.g * zh[0]) / f(f(c.cp * 0.5) * f(thvSfc + thv[0]))));
      for (let k = 1; k < nk; k++) {
        pi[k] = f(pi[k - 1] - f(f(c.g * f(zh[k] - zh[k - 1])) / f(f(c.cp * 0.5) * f(thv[k] + thv[k - 1]))));
      }
      for (let k = 0; k < nk; k++) prs[k] = f(c.p00 * powf(pi[k], cpOverRd));
      for (let k = 0; k < nk; k++) {
        qv[k] = f(rh[k] * BaseState.rslf32(prs[k], f(th[k] * pi[k]), c.eps));
        if (qv[k] > qvPbl) qv[k] = qvPbl;
      }
    }
    for (let k = 0; k < nk; k++) rh[k] = f(qv[k] / BaseState.rslf32(prs[k], f(th[k] * pi[k]), c.eps));
    return { th, qv, rh, pi };
  }

  static constantLapseProfiles(zh, testcase, c) {
    const nk = zh.length;
    const thSfc = f(300.0), piSfc = f(1.0);
    let lapse = f(-0.0030581), rhval = 0.0;
    if (testcase === 6 || testcase === 10) lapse = f(0.005);
    if (testcase === 10) rhval = f(0.90);
    const th = zerosF(nk), pi = zerosF(nk), qv = zerosF(nk), rh = zerosF(nk);
    for (let k = 0; k < nk; k++) {
      th[k] = fmaf(lapse, zh[k], thSfc);
      pi[k] = fmaf(-f(c.g / f(c.cp * lapse)), logf(f(th[k] / thSfc)), piSfc);
      const prs = f(c.p00 * powf(pi[k], f(c.cp / c.rd)));
      const t = f(th[k] * pi[k]);
      rh[k] = rhval;
      qv[k] = f(rhval * BaseState.rslf32(prs, t, c.eps));
    }
    return { th, qv, rh, pi };
  }

  static constantNProfiles(zh, c) {
    const nk = zh.length;
    const thSfc = f(288.0), piSfc = f(1.0), ns = f(0.0001), zl1 = f(40000.0), zsfc = 0.0;
    if (!zh.every(z => z < zl1)) throw new Error('isnd=9: уровень выше zl1 = 40 км - ветвь ns2 не портирована');
    const th = zerosF(nk), pi = zerosF(nk), qv = zerosF(nk), rh = zerosF(nk);
    const a = f(f(c.g * c.g) / f(f(c.cp * ns) * thSfc));
    for (let k = 0; k < nk; k++) {
      th[k] = f(thSfc * expf(f(f(ns * f(zh[k] - zsfc)) / c.g)));
      pi[k] = fmaf(a, f(expf(f(-f(ns * f(zh[k] - zsfc)) / c.g)) - 1.0), piSfc);
    }
    return { th, qv, rh, pi };
  }

  static inversionProfiles(zh, thSfc, zl1, lr1, zl2, lr2, c) {
    const nk = zh.length;
    const piSfc = f(1.0);
    const thAtZl2 = zl2 != null ? f(thSfc + f(f(zl2 - zl1) * lr1)) : 0;
    const th = zerosF(nk), pi = zerosF(nk);
    for (let k = 0; k < nk; k++) {
      const z = zh[k];
      if (z <= zl1) {
        th[k] = thSfc;
        pi[k] = f(piSfc - f(f(c.g * z) / f(c.cp * thSfc)));
      } else {
        if (zl2 != null && z > zl2) th[k] = fmaf(f(z - zl2), lr2, thAtZl2);
        else th[k] = fmaf(f(z - zl1), lr1, thSfc);
        if (!(k > 0)) throw new Error(`первый уровень zh=${z} выше нижнего слоя zl1=${zl1}: base.F читает pi0(0)`);
        pi[k] = f(pi[k - 1] - f(f(c.g * f(z - zh[k - 1])) / f(f(c.cp * 0.5) * f(th[k] + th[k - 1]))));
      }
    }
    return { th, qv: zerosF(nk), rh: zerosF(nk), pi };
  }

  static piecewiseProfiles(zh, bomexTestcase, c) {
    const nk = zh.length;
    let z, thN, qN, prsSfc, clampNonNegative;
    if (bomexTestcase != null) {
      clampNonNegative = true;
      if (bomexTestcase === 11) {
        prsSfc = f(100000.0);
        z = [0.0, 352.5, 442.5, 3000.0, 10000.0].map(f);
        const th3 = f(298.1);
        thN = [f(296.6), f(296.6), th3, f(th3 + f(f(0.003) * f(z[3] - z[2]))), f(th3 + f(f(0.003) * f(z[4] - z[2])))];
        const qv3 = f(7.8e-3);
        qN = [f(11.8e-3), f(11.8e-3), qv3, f(qv3 - f(f(0.004e-3) * f(z[3] - z[2]))), f(qv3 - f(f(0.004e-3) * f(z[4] - z[2])))];
      } else {
        prsSfc = f(101500.0);
        z = [0.0, 520.0, 1480.0, 2000.0, 3000.0].map(f);
        thN = [298.7, 298.7, 302.4, 308.2, 311.85].map(f);
        qN = [0.0170, 0.0163, 0.0107, 0.0042, 0.0030].map(f);
      }
    } else {
      clampNonNegative = false;
      prsSfc = f(101540.0);
      z = [0.0, 740.0, 3260.0, 4000.0].map(f);
      thN = [297.9, 297.9, 312.6644, 317.0].map(f);
      qN = [0.0160, 0.0138, 0.0024, 0.0018].map(f);
    }
    const piSfc = powf(f(prsSfc * c.rp00), c.rovcp);
    const thvSfc = f(f(thN[0] * fmaf(c.reps, qN[0], 1.0)) / f(1.0 + qN[0]));
    const th = zerosF(nk), qv = zerosF(nk), thv = zerosF(nk), pi = zerosF(nk), rh = zerosF(nk);
    for (let k = 0; k < nk; k++) {
      const zk = zh[k];
      let seg = -1;
      for (let n = 1; n < z.length; n++) if (zk <= z[n]) { seg = n; break; }
      if (!(seg > 0)) throw new Error(`уровень zh=${zk} выше последнего узла профиля ${z[z.length - 1]} м`);
      const lerp = (a) => f(a[seg - 1] + f(f(f(a[seg] - a[seg - 1]) * f(zk - z[seg - 1])) / f(z[seg] - z[seg - 1])));
      th[k] = lerp(thN);
      let q = lerp(qN);
      q = f(q / f(1.0 - q));
      if (clampNonNegative) q = Math.max(0.0, q);
      qv[k] = q;
      thv[k] = f(f(th[k] * fmaf(c.reps, q, 1.0)) / f(1.0 + q));
    }
    pi[0] = f(piSfc - f(f(c.g * zh[0]) / f(f(c.cp * 0.5) * f(thvSfc + thv[0]))));
    for (let k = 1; k < nk; k++) {
      pi[k] = f(pi[k - 1] - f(f(c.g * f(zh[k] - zh[k - 1])) / f(f(c.cp * 0.5) * f(thv[k] + thv[k - 1]))));
    }
    for (let k = 0; k < nk; k++) {
      const prs = f(c.p00 * powf(pi[k], f(c.cp / c.rd)));
      rh[k] = f(qv[k] / BaseState.rslf32(prs, f(th[k] * pi[k]), c.eps));
    }
    return { th, qv, rh, pi };
  }

  static dycomsProfiles(zh, testcase, c) {
    if (!(testcase === 4 || testcase === 5)) throw new Error('isnd=15: testcase обязан быть 4 или 5 (base.F:1545)');
    const nk = zh.length;
    let thSfc, qvSfc, zInv;
    const prsSfc = f(101780.0);
    if (testcase === 4) { thSfc = f(289.0); qvSfc = f(0.009); zInv = f(840.0); }
    else { thSfc = f(288.3); qvSfc = f(0.00945); zInv = f(795.0); }
    const piSfc = powf(f(prsSfc / c.p00), f(c.rd / c.cp));
    const thvSfc = f(f(thSfc * fmaf(qvSfc, c.reps, 1.0)) / f(1.0 + qvSfc));
    const th = zerosF(nk), qv = zerosF(nk), qc = zerosF(nk), pi = zerosF(nk), rh = zerosF(nk);
    let thvlast = thvSfc, pilast = piSfc, zlast = 0.0;
    const third = f(1.0 / 3.0);
    const cpOverRd = f(c.cp / c.rd);
    for (let k = 0; k < nk; k++) {
      const z = zh[k];
      let thl, qt;
      if (z <= zInv) { thl = thSfc; qt = qvSfc; }
      else if (testcase === 4) {
        thl = f(f(297.5) + powf(f(z - zInv), third));
        const q = f(0.0015); qt = f(q / f(1.0 - q));
      } else {
        thl = f(f(295.0) + powf(f(z - zInv), third));
        qt = f(f(0.001) * fmaf(f(-3.0), f(1.0 - expf(f(f(zInv - z) / f(500.0)))), f(5.0)));
      }
      let thlast = 0.0;
      let th0k = thl, qv0k = qt, qc0k = 0.0, pi0k = 0.0, thv0k = 0.0;
      let n = 0;
      while (Math.abs(f(th0k - thlast)) >= f(0.0001)) {
        thlast = th0k;
        thv0k = f(f(th0k * fmaf(c.reps, qv0k, 1.0)) / f(f(1.0 + qv0k) + qc0k));
        pi0k = f(pilast - f(f(c.g * f(z - zlast)) / f(f(c.cp * 0.5) * f(thvlast + thv0k))));
        const prs0k = f(c.p00 * powf(pi0k, cpOverRd));
        const t0k = f(th0k * pi0k);
        const qvs = BaseState.rslf32(prs0k, t0k, c.eps);
        if (qt < qvs) { qv0k = qt; qc0k = 0.0; th0k = thl; }
        else { qv0k = qvs; qc0k = f(qt - qvs); th0k = f(thl / f(1.0 - f(f(c.xlv * qc0k) / f(c.cp * t0k)))); }
        th0k = fmaf(f(0.3), f(th0k - thlast), thlast);
        n++;
        if (n > 100) throw new Error('isnd=15: итерация θ не сошлась за 100 шагов (base.F:1637 - stop 1111)');
      }
      th[k] = th0k; qv[k] = qv0k; qc[k] = qc0k; pi[k] = pi0k;
      thvlast = thv0k; pilast = pi0k; zlast = z;
      rh[k] = f(qv0k / BaseState.rslf32(f(c.p00 * powf(pi0k, cpOverRd)), f(th0k * pi0k), c.eps));
    }
    return { th, qv, rh, pi, qc };
  }

  static windProfile(wind, zh) {
    const nk = zh.length;
    const u = zerosF(nk), v = zerosF(nk);
    switch (wind.kind) {
      case 'calm': break;
      case 'cm1Multicell': {
        const udep1 = 0.0, udep2 = f(7500.0);
        const umax1 = f(f(-40.0) / pi32), umax2 = f(f(f(40.0) / pi32) + f(40.0));
        for (let k = 0; k < nk; k++) {
          const zu = zh[k];
          u[k] = zu <= udep2 ? f(umax1 + f(f(f(zu - udep1) * f(umax2 - umax1)) / f(udep2 - udep1))) : umax2;
          v[k] = f(f(40.0) / pi32);
        }
        break;
      }
      case 'weismanKlempMulticell':
        for (let k = 0; k < nk; k++) u[k] = f(f(35.0) * tanhf(f(zh[k] / f(3000.0))));
        break;
      case 'uniform':
        for (let k = 0; k < nk; k++) { u[k] = f(wind.u); v[k] = f(wind.v); }
        break;
      case 'rkw88': {
        const udep1 = 0.0, udep2 = f(2500.0), uconst1 = 0.0, uconst2 = f(10.0);
        for (let k = 0; k < nk; k++) {
          const zu = zh[k];
          if (zu < udep1) u[k] = uconst1;
          else if (zu > udep1 && zu < udep2) u[k] = f(f(f(f(uconst2 - uconst1) * f(zu - udep1)) / f(udep2 - udep1)) + uconst1);
          else u[k] = uconst2;
          v[k] = 0.0;
        }
        break;
      }
      case 'weismanKlemp': {
        const udep1 = f(BaseState.uDep1), udep2 = f(BaseState.uDep2);
        const umax1 = f(BaseState.uMax1), umax2 = f(BaseState.uMax2);
        const vMax1 = umax1;
        const deg = f(pi32 / f(180.0));
        for (let k = 0; k < nk; k++) {
          const z = zh[k];
          if (z <= udep1) {
            const angle = f(f(f(90.0) * f(z / udep1)) * deg);
            u[k] = fmaf(-umax1, cosf(angle), umax1);
            v[k] = f(vMax1 * sinf(angle));
          } else if (z <= udep2) {
            u[k] = f(umax1 + f(f(f(z - udep1) * f(umax2 - umax1)) / f(udep2 - udep1)));
            v[k] = vMax1;
          } else { u[k] = umax2; v[k] = vMax1; }
        }
        break;
      }
      case 'hurricaneBoundaryLayer':
        for (let k = 0; k < nk; k++) v[k] = f(f(40.0) * Math.max(0.0, f(1.0 - f(zh[k] / f(18000.0)))));
        break;
      case 'bomex': case 'rico': {
        const [udep1, udep2, uconst1, uconst2, vconst] = (wind.kind === 'bomex'
          ? [700.0, 3000.0, -8.75, -4.61, 0.0] : [0.0, 4000.0, -9.9, -1.9, -3.8]).map(f);
        for (let k = 0; k < nk; k++) {
          const zu = zh[k];
          if (zu <= udep1) u[k] = uconst1;
          else if (zu > udep1 && zu < udep2) u[k] = f(f(f(f(uconst2 - uconst1) * f(zu - udep1)) / f(udep2 - udep1)) + uconst1);
          else u[k] = uconst2;
          v[k] = vconst;
        }
        break;
      }
      case 'dycomsDrizzle':
        for (let k = 0; k < nk; k++) {
          u[k] = f(f(3.0) + f(f(f(4.3) * zh[k]) / f(1000.0)));
          v[k] = f(f(-9.0) + f(f(f(5.6) * zh[k]) / f(1000.0)));
        }
        break;
      default: throw new Error('ветер ' + wind.kind);
    }
    return { u, v };
  }
}

// WindProfile.uniform(testcase:) - base.F:2414-2436
export function uniformWind(testcase) {
  switch (testcase) {
    case 1: return { kind: 'uniform', u: 1.0, v: 0.0 };
    case 2: return { kind: 'uniform', u: 15.0, v: 0.0 };
    case 4: return { kind: 'uniform', u: 7.0, v: -5.5 };
    case 9: return { kind: 'uniform', u: 8.0, v: 0.0 };
    case 11: return { kind: 'uniform', u: 2.0, v: 0.0 };
    default: return { kind: 'uniform', u: 10.0, v: 0.0 };
  }
}

// ---- HashRand
export const HashRand = {
  value(seed, i, j, k) {
    const low = (a, b) => Number(BigInt.asUintN(32, BigInt(a) * BigInt(b)));   // wrap(Int64 a &* b) & m32
    let x = low(seed, 2654435761);
    x = (x + low(i, 40503)) >>> 0;
    x = (x + low(j, 1073741827)) >>> 0;
    x = (x + low(k, 3145739)) >>> 0;
    x = (x ^ (x >>> 16)) >>> 0;
    x = Math.imul(x, 2246822519) >>> 0;
    x = (x ^ (x >>> 13)) >>> 0;
    x = Math.imul(x, 3266489917) >>> 0;
    x = (x ^ (x >>> 16)) >>> 0;
    return f(f(x) / f(4294967296.0));
  },
};

// ---- WarmBubble
export class WarmBubble {
  constructor() {
    this.centerZ = 1400.0; this.radiusH = 10000.0; this.radiusV = 1400.0; this.amplitude = 1.0;
    this.offsetX = 0.0; this.offsetY = 0.0;
  }
  perturbation(x, y, z) {
    const bx = (x - this.offsetX) / this.radiusH;
    const by = (y - this.offsetY) / this.radiusH;
    const bz = (z - this.centerZ) / this.radiusV;
    const beta = Math.sqrt(bx * bx + by * by + bz * bz);
    if (!(beta < 1.0)) return 0.0;
    const c = Math.cos(0.5 * Math.PI * beta);
    return this.amplitude * c * c;
  }
}

// ---- LineThermal
export class LineThermal {
  constructor(seed = 1) {
    this.centerXFromWest = 150000.0; this.centerZ = 1500.0; this.radiusH = 10000.0; this.radiusV = 1500.0;
    this.amplitude = 2.0; this.noise = 0.20; this.seed = seed;
  }
  perturbation(x, z, ii, jj, k) {
    const bx = (x - this.centerXFromWest) / this.radiusH;
    const bz = (z - this.centerZ) / this.radiusV;
    const beta = Math.sqrt(bx * bx + bz * bz);
    if (!(beta < 1.0)) return 0.0;
    const c = Math.cos(0.5 * Math.PI * beta);
    const rand = HashRand.value(this.seed, ii, jj, k);
    const noiseTerm = f(f(this.noise) * f(f(2.0 * rand) - 1.0));
    return this.amplitude * c * c + noiseTerm;
  }
}

// ---- InitialPerturbations
export class ColdPool {
  constructor() { this.depth = 2500.0; this.amplitude = -6.0; }
  perturbation(x, z) {
    if (!(x <= 0 && z < this.depth)) return 0;
    return this.amplitude * (this.depth - z) / this.depth;
  }
  static maintainedQv(qv0, th0, pi0, prs0, tha) {
    const rh = qv0 / BaseState.rslf(prs0, th0 * pi0);
    return rh * BaseState.rslf(prs0, (th0 + tha) * pi0);
  }
}

export class BubbleLine {
  constructor() {
    this.centreX = 30000.0; this.centresY = [3000.0, 33000.0, 63000.0]; this.centreZ = 1400.0;
    this.radiusH = 10000.0; this.radiusV = 1400.0; this.amplitude = 2.0;
  }
  perturbation(x, y, z) {
    let tha = 0.0;
    for (const rjc of this.centresY) {
      const bx = (x - this.centreX) / this.radiusH;
      const by = (y - rjc) / this.radiusH;
      const bz = (z - this.centreZ) / this.radiusV;
      const beta = Math.sqrt(bx * bx + by * by + bz * bz);
      if (beta < 1.0) { const c = Math.cos(0.5 * Math.PI * beta); tha = this.amplitude * c * c; }
      else tha = Math.max(0.0, tha);
    }
    return tha;
  }
}

export class RotunnoEmanuelVortex {
  constructor(seed = 0) {
    this.vmax = f(15.0); this.rm1 = f(75000.0); this.rm2 = f(200000.0); this.rm3 = f(500000.0);
    this.rdc = f(-0.35); this.zdd = f(15000.0); this.seed = seed;
  }

  // reference(th0:pi0:prs0:qv0:thv0:zh:mf:dz:fcor:dr:rrmax:rref:) - все входы float
  reference(th0, pi0, prs0, qv0, thv0, zh, mf, dz, fcor, dr, rrmax, given = null) {
    const nk = th0.length;
    const cp = f(1005.7), rd = f(287.04), rv = f(461.5), g = f(9.81), p00 = f(1.0e5);
    const reps = f(rv / rd), cpdrd = f(cp / rd), eps = f(rd / rv);
    const rdz = f(1.0 / dz);
    const F273 = f(273.15), F233 = f(233.15);
    const rslf = (p, t) => {
      let esl = f(f(611.2) * expf(f(f(f(17.67) * f(t - F273)) / f(t - f(29.65)))));
      esl = Math.min(esl, f(p * 0.5));
      return f(f(eps * esl) / f(p - esl));
    };
    const rsif = (p, t) => {
      let esi = f(f(611.2) * expf(f(f(f(21.8745584) * f(t - F273)) / f(t - f(7.66)))));
      esi = Math.min(esi, f(p * 0.5));
      return f(f(eps * esi) / f(p - esi));
    };
    const { vmax, rm1, rm2, rm3, rdc, zdd } = this;
    let rref;
    if (given) rref = given;
    else {
      const n = 1 + Math.trunc(f(rrmax / dr));
      rref = []; for (let i = 0; i < n; i++) rref.push(f(f(0.5 * dr) + f(f(i) * dr)));
    }
    const nref = rref.length;
    const vt = rref.map(r => {
      if (r < rm1) return f(f(vmax * r) / rm1);
      if (r < rm2) return f(vmax * powf(f(r / rm1), rdc));
      if (r < rm3) {
        const v2 = f(vmax * powf(f(r / rm1), rdc));
        const v3 = f(f(f(vmax * 0.5) * f(1.0 - f(f(r - rm2) / f(rm3 - rm2)))));
        const w3 = f(f(r - rm2) / f(rm3 - rm2));
        const w2 = f(1.0 - w3);
        return f(f(w2 * v2) + f(w3 * v3));
      }
      return 0;
    });
    const mk = () => Array.from({ length: nref }, () => new Array(nk + 2).fill(0));
    const vref = mk(), piref = mk(), pref = mk(), thref = mk(), thvref = mk(), qvref = mk(), rhref = mk();
    for (let kk = 1; kk <= nk; kk++) {
      const z = zh[kk - 1];
      for (let i = 0; i < nref; i++) vref[i][kk] = z < zdd ? f(f(f(vt[i] * f(zdd - z))) / f(zdd - 0.0)) : 0;
    }
    for (let kk = 1; kk <= nk; kk++) {
      const k = kk - 1;
      const d2 = f(qv0[k] / rslf(prs0[k], f(th0[k] * pi0[k])));
      for (let i = 0; i < nref; i++) { rhref[i][kk] = d2; thref[i][kk] = 0; piref[i][kk] = 0; pref[i][kk] = prs0[k]; }
    }
    for (let it = 1; it <= 20; it++) {
      for (let kk = 1; kk <= nk; kk++) {
        const k = kk - 1;
        for (let i = 0; i < nref; i++) {
          pref[i][kk] = f(p00 * powf(f(pi0[k] + piref[i][kk]), cpdrd));
          const tnew = f(f(th0[k] + thref[i][kk]) * f(pi0[k] + piref[i][kk]));
          const fliq = Math.max(Math.min(f(f(tnew - F233) / f(F273 - F233)), 1.0), 0.0);
          const fice = f(1.0 - fliq);
          let qsw = 0;
          if (tnew > F233) qsw = f(fliq * rslf(pref[i][kk], tnew));
          let qsi = 0;
          if (tnew < F273) qsi = f(fice * rsif(pref[i][kk], tnew));
          const qvs = f(qsw + qsi);
          qvref[i][kk] = f(rhref[i][kk] * qvs);
          thvref[i][kk] = f(f(f(th0[k] + thref[i][kk]) * f(1.0 + f(reps * qvref[i][kk]))) / f(1.0 + qvref[i][kk]));
        }
      }
      for (let kk = 1; kk <= nk; kk++) {
        piref[nref - 1][kk] = 0;
        for (let i = nref - 1; i >= 1; i--) {
          const a = f(f(f(rref[i - 1] - rref[i]) / f(f(cp * 0.5) * f(thvref[i - 1][kk] + thvref[i][kk]))) * 0.5);
          const b = f(f(f(f(vref[i][kk] * vref[i][kk]) / rref[i])
            + f(f(vref[i - 1][kk] * vref[i - 1][kk]) / rref[i - 1]))
            + f(fcor * f(vref[i][kk] + vref[i - 1][kk])));
          piref[i - 1][kk] = f(piref[i][kk] + f(a * b));
        }
      }
      for (let i = 0; i < nref; i++) { piref[i][0] = piref[i][1]; piref[i][nk + 1] = piref[i][nk]; }
      if (nk >= 2) {
        for (let kk = 2; kk <= nk; kk++) {
          const k = kk - 1;
          for (let i = 0; i < nref; i++) {
            const t1 = f(f(f(f(f(cp * 0.5) * f(thvref[i][kk] + thvref[i][kk + 1])) * f(piref[i][kk + 1] - piref[i][kk])) * rdz) * mf[kk]);
            const t2 = f(f(f(f(f(cp * 0.5) * f(thvref[i][kk] + thvref[i][kk - 1])) * f(piref[i][kk] - piref[i][kk - 1])) * rdz) * mf[kk - 1]);
            let th = f(f(f(f(0.5 * f(t1 + t2)) * thv0[k])) / g);
            th = f(f(f(f(thv0[k] + th) * f(1.0 + qvref[i][kk])) / f(1.0 + f(reps * qvref[i][kk]))) - th0[k]);
            thref[i][kk] = th;
          }
        }
      }
      for (let i = 0; i < nref; i++) {
        let th = f(f(f(f(f(f(f(cp * 0.5) * f(thvref[i][1] + thvref[i][2])) * f(piref[i][2] - piref[i][1])) * rdz) * mf[1]) * thv0[0]) / g);
        th = f(f(f(f(thv0[0] + th) * f(1.0 + qvref[i][1])) / f(1.0 + f(reps * qvref[i][1]))) - th0[0]);
        thref[i][1] = th;
      }
    }
    return { rref, vref, piref, thref, qvref, rrmax };
  }

  static bracket(rr, ref, tsmall = f(1.0e-4)) {
    if (!(rr <= ref.rrmax)) return null;
    let ii = 0, diff = -1.0e20;
    while (diff < 0) {
      ii++;
      if (ii > ref.rref.length) throw new Error(`вихрь: радиус ${rr} вне опорной сетки`);
      diff = f(ref.rref[ii - 1] - rr);
    }
    if (Math.abs(f(rr - ref.rref[ii - 1])) < tsmall && ii === 1) ii = 2;
    if (!(ii >= 2)) throw new Error(`вихрь: r = ${rr} ближе к центру, чем первый опорный узел`);
    return [ii - 2, ii - 1];
  }
}

// ---- Sounding
export class Sounding {
  // init(text:windsFromFile:moist:thermo:)
  constructor({ text, windsFromFile = true, moist = true, thermo = ThermoConstants.cm1 }) {
    // CRLF -> LF: эталонный разбор отверг бы файл с \r (токен «1.5\r» не число);
    // здесь он принимается - на корректных файлах это ничего не меняет.
    const norm = text.replace(/\r\n?/g, '\n');
    const rows = norm.split('\n').map(s => s.replace(/^[ \t]+|[ \t]+$/g, '')).filter(s => s.length);
    if (!rows.length) throw new Error('файл зондировки пуст');
    const nums = row => row.split(/[ \t]/).filter(t => t.length).map(parseFloat32).filter(x => x !== null);
    const head = rows.shift();
    const h = nums(head);
    if (h.length < 3) throw new Error(`шапка зондировки не разобрана: ожидались три числа (p_sfc мб, th_sfc K, qv_sfc г/кг), прочитано «${head}»`);
    const pS = f(h[0] * 100.0), thS = h[1], qvS = moist ? f(h[2] / 1000.0) : 0.0;
    const file = [];
    rows.forEach((row, n) => {
      const v = nums(row), need = windsFromFile ? 5 : 3;
      if (v.length < need) throw new Error(`строка ${n + 2} зондировки не разобрана: ожидались z, theta, qv, u, v, прочитано «${row}»`);
      file.push({ z: v[0], th: v[1], qv: moist ? f(v[2] / 1000.0) : 0.0, u: windsFromFile ? v[3] : 0.0, v: windsFromFile ? v[4] : 0.0 });
    });
    if (file.length < 2) throw new Error(`в зондировке ${file.length} уровней (с приземным ${file.length + 1}); нужно не меньше 2 в файле - CM1 отказывает при nsnd <= 2 (base.F:627-634)`);
    for (let i = 1; i < file.length; i++) if (file[i].z <= file[i - 1].z) {
      throw new Error(`высоты в зондировке не возрастают: уровень ${i + 1} равен ${file[i].z} м при предыдущем ${file[i - 1].z} м. CM1 монотонность не проверяет и на таком файле молча даёт мусор (base.F:744)`);
    }
    const dz = f(file[1].z - file[0].z);
    const uS = dz !== 0 ? f(file[0].u - f(f(f(file[0].z - 0.0) * f(file[1].u - file[0].u)) / dz)) : file[0].u;
    const vS = dz !== 0 ? f(file[0].v - f(f(f(file[0].z - 0.0) * f(file[1].v - file[0].v)) / dz)) : file[0].v;
    const all = [{ z: 0.0, th: thS, qv: qvS, u: uS, v: vS }, ...file];
    if (!(all[1].z > all[0].z)) throw new Error(`высоты в зондировке не возрастают: уровень 1 равен ${all[1].z} м при предыдущем 0 м`);
    const c = new BaseStateF32(thermo);
    const thvA = all.map(r => f(f(r.th * fmaf(c.reps, r.qv, 1.0)) / f(1.0 + r.qv)));
    const piA = zerosF(all.length);
    piA[0] = powf(f(pS / c.p00), f(c.rd / c.cp));
    for (let k = 1; k < all.length; k++) {
      piA[k] = f(piA[k - 1] - f(f(c.g * f(all[k].z - all[k - 1].z)) / f(f(c.cp * 0.5) * f(thvA[k] + thvA[k - 1]))));
    }
    const cpOverRd = f(c.cp / c.rd);
    const prsA = piA.map(x => f(c.p00 * powf(x, cpOverRd)));
    const tA = all.map((r, k) => f(r.th * piA[k]));
    let bumped = 0;
    const rhA = zerosF(all.length);
    if (moist) {
      for (let k = 0; k < all.length; k++) {
        if (all[k].qv < 1.0e-12) {
          bumped++;
          all[k].qv = f(f(0.001) * BaseState.rslf32(prsA[k], f(all[k].th * piA[k]), c.eps));
        }
        rhA[k] = f(all[k].qv / BaseState.rslf32(prsA[k], tA[k], c.eps));
      }
    }
    this.levels = all.map(r => ({ z: r.z, theta: r.th, qv: r.qv, u: r.u, v: r.v }));
    this.text = text;
    this.pSfc = pS; this.thSfc = thS; this.qvSfc = qvS;
    this.pi = piA; this.prs = prsA; this.t = tA; this.thv = thvA; this.rh = rhA;
    this.levelsWithMinimumHumidity = bumped;
  }
  get top() { return this.levels[this.levels.length - 1].z; }

  interpolated(zh, { moist = true, umove = 0, vmove = 0, thermo = ThermoConstants.cm1 } = {}) {
    if (!zh.length) return { th0: [], qv0: [], u0: [], v0: [], prs0: [], t0: [], rh0: [], pi0: [] };
    const gridTop = zh[zh.length - 1];
    if (!(this.top >= gridTop)) {
      throw new Error(`зондировка достаёт до ${this.top} м, верхний скалярный уровень сетки ${gridTop} м, не хватает ${gridTop - this.top} м (base.F:734-739)`);
    }
    const nk = zh.length;
    const c = new BaseStateF32(thermo);
    const zF = zh.map(f);
    const zs = this.levels.map(l => f(l.z)), thS = this.levels.map(l => f(l.theta));
    const uS = this.levels.map(l => f(l.u)), vS = this.levels.map(l => f(l.v));
    const prsS = this.prs.map(f), tS = this.t.map(f), rhS = this.rh.map(f);
    const th0 = [], u0 = [], v0 = [], prsI = [], tI = [], rhI = [];
    for (const z of zF) {
      let kk = 1;
      while (zs[kk] < z) kk++;
      const dn = kk - 1, up = kk;
      const fr = f(f(z - zs[dn]) / f(zs[up] - zs[dn]));
      const lerp = (a, b) => fmaf(f(b - a), fr, a);
      th0.push(lerp(thS[dn], thS[up])); u0.push(lerp(uS[dn], uS[up])); v0.push(lerp(vS[dn], vS[up]));
      prsI.push(lerp(prsS[dn], prsS[up])); tI.push(lerp(tS[dn], tS[up])); rhI.push(lerp(rhS[dn], rhS[up]));
    }
    const qv0 = moist ? th0.map((_, k) => f(rhI[k] * BaseState.rslf32(prsI[k], tI[k], c.eps))) : zerosF(nk);
    const thv0 = th0.map((_, k) => f(f(th0[k] * fmaf(c.reps, qv0[k], 1.0)) / f(1.0 + qv0[k])));
    const pS = f(this.pSfc), thSf = f(this.thSfc), qvSf = f(this.qvSfc);
    const piSfc = powf(f(pS / c.p00), f(c.rd / c.cp));
    const thvSfc = f(f(thSf * fmaf(qvSf, c.reps, 1.0)) / f(1.0 + qvSf));
    const pi0 = zerosF(nk);
    pi0[0] = f(piSfc - f(f(c.g * zF[0]) / f(f(c.cp * 0.5) * f(thvSfc + thv0[0]))));
    for (let k = 1; k < nk; k++) {
      pi0[k] = f(pi0[k - 1] - f(f(c.g * f(zF[k] - zF[k - 1])) / f(f(c.cp * 0.5) * f(thv0[k] + thv0[k - 1]))));
    }
    const cpOverRd = f(c.cp / c.rd);
    const prs0 = pi0.map(x => f(c.p00 * powf(x, cpOverRd)));
    const t0 = th0.map((_, k) => f(th0[k] * pi0[k]));
    const rh0 = moist ? qv0.map((q, k) => f(q / BaseState.rslf32(prs0[k], t0[k], c.eps))) : zerosF(nk);
    const um = f(umove), vm = f(vmove);
    return { th0, qv0, u0: u0.map(x => f(x - um)), v0: v0.map(x => f(x - vm)), prs0, t0, rh0, pi0 };
  }
}

// ---- SoundingFactory
export const SoundingFactory = {
  text({ qvPbl = BaseState.qvPbl, levelStep = 100, top = 22000, wind }) {
    const zh = [];
    for (let i = 0; ; i++) { const z = levelStep + i * levelStep; if (z > top) break; zh.push(z); }
    const b = BaseState.weismanKlemp({ zh, moist: true, umove: 0, vmove: 0, wind: { kind: 'weismanKlemp' }, qvPbl });
    let s = `${printfFixed(BaseState.prsSfc / 100, 12, 4)} ${printfFixed(BaseState.thSfc, 12, 6)} ${printfFixed(b.qv0[0] * 1000, 12, 6)}\n`;
    zh.forEach((z, k) => {
      const w = wind(z);
      s += `${printfFixed(z, 12, 4)} ${printfFixed(b.th0[k], 12, 6)} ${printfFixed(b.qv0[k] * 1000, 12, 6)} ${printfFixed(w.u, 10, 4)} ${printfFixed(w.v, 10, 4)}\n`;
    });
    return s;
  },
  weismanKlempText({ shearTop, depth = 6000, levelStep = 100, top = 22000 }) {
    return SoundingFactory.text({ levelStep, top, wind: z => ({ u: shearTop * Math.min(z / depth, 1.0), v: 0.0 }) });
  },
  weismanKlemp({ shearTop, depth = 6000 }) {
    return new Sounding({ text: SoundingFactory.weismanKlempText({ shearTop, depth }) });
  },
  straight({ shear, depth }) { return z => ({ u: shear * Math.min(z / depth, 1.0), v: 0.0 }); },
  quarterCircle({ scale }) {
    return z => {
      const udep1 = BaseState.uDep1, udep2 = BaseState.uDep2;
      const umax1 = BaseState.uMax1 * scale, umax2 = BaseState.uMax2 * scale;
      if (z <= udep1) {
        const a = 90.0 * (z / udep1) * (Math.PI / 180.0);
        return { u: umax1 - umax1 * Math.cos(a), v: umax1 * Math.sin(a) };
      } else if (z <= udep2) return { u: umax1 + (z - udep1) * (umax2 - umax1) / (udep2 - udep1), v: umax1 };
      return { u: umax2, v: umax1 };
    };
  },
  sounding({ qvPbl = BaseState.qvPbl, wind }) { return new Sounding({ text: SoundingFactory.text({ qvPbl, wind }) }); },
};
