// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Микрофизика: MorrisonColumn, MorrisonMicrophysics, MorrisonRadar,
// MorrisonConstants, Годдард-LFO, GoddardConstants, GoddardParamsGPU,
// RotunnoEmanuelMicrophysics. Диагностика града на CPU шагом не вызывается
// и здесь не реализована.
//
// Литерал, типизированный как Float, здесь - L(…) (= Math.fround).
// encode(e, …) принимает энкодер (как TimeStep), encode(cb, …) - командный
// буфер.
import { f, sqrtf, powf, expf, logf, sinf, Bytes } from './f32.js';
import { PWR81_FIX, PWR2_FIX } from './micro_powfix.js';

const L = f;

// ---- Advection: GridDimsGPU (5 int + 3 float = 32 байта)
export class GridDimsGPU {
  constructor(g) {
    this.nx = g.nx; this.ny = g.ny; this.nz = g.nz; this.strideJ = g.strideJ; this.strideK = g.strideK;
    this.rdx = f(1.0 / g.dx); this.rdy = f(1.0 / g.dy); this.rdz = f(1.0 / g.dz);
  }
  bytes() {
    return new Bytes().i32(this.nx).i32(this.ny).i32(this.nz).i32(this.strideJ).i32(this.strideK)
      .f32(this.rdx).f32(this.rdy).f32(this.rdz).end();
  }
}

const f32bytes = v => new Uint8Array(Float32Array.of(v).buffer);
const i32bytes = v => new Uint8Array(Int32Array.of(v).buffer);
const u32bytes = v => new Uint8Array(Uint32Array.of(v).buffer);
const isCB = x => typeof x.makeComputeCommandEncoder === 'function';
const bitsOf = v => { const a = new Float32Array([v]); return new Uint32Array(a.buffer)[0]; };

// ======================================================================
// MorrisonConstants
export class MorrisonConstants {
  static pi = L(3.1415926535897932384626434);
  static xxx = L(0.9189385332046727417803297);

  // Гамма Коди-Штольц в real(4) - дословно
  static gamma(x) {
    const one = 1, half = 0.5, twelve = 12, two = 2, zero = 0;
    const xbig = L(35.040), xminin = L(1.18e-38), eps = L(1.19e-7), xinf = L(3.4e38);
    const p = [-1.71618513886549492533811e+0, 2.47656508055759199108314e+1,
      -3.79804256470945635097577e+2, 6.29331155312818442661052e+2,
      8.66966202790413211295064e+2, -3.14512729688483675254357e+4,
      -3.61444134186911729807069e+4, 6.64561438202405440627855e+4].map(L);
    const q = [-3.08402300119738975254353e+1, 3.15350626979604161529144e+2,
      -1.01515636749021914166146e+3, -3.10777167157231109440444e+3,
      2.25381184209801510330112e+4, 4.75584627752788110767815e+3,
      -1.34659959864969306392456e+5, -1.15132259675553483497211e+5].map(L);
    const c = [-1.910444077728e-03, 8.4171387781295e-04,
      -5.952379913043012e-04, 7.93650793500350248e-04,
      -2.777777777777681622553e-03, 8.333333333333333331554247e-02,
      5.7083835261e-03].map(L);
    const pi = MorrisonConstants.pi;
    let parity = false, fact = one, n = 0, y = x, res;
    if (y <= zero) {
      y = -x;
      const y1 = Math.trunc(y);
      res = f(y - y1);
      if (res !== zero) {
        if (y1 !== f(Math.trunc(f(y1 * half)) * two)) parity = true;
        fact = f(-pi / sinf(f(pi * res)));
        y = f(y + one);
      } else return xinf;
    }
    if (y < eps) {
      if (y >= xminin) res = f(one / y); else return xinf;
    } else if (y < twelve) {
      const y1 = y;
      let z;
      if (y < one) { z = y; y = f(y + one); }
      else { n = Math.trunc(y) - 1; y = f(y - n); z = f(y - one); }
      let xnum = zero, xden = one;
      for (let i = 0; i < 8; i++) {
        xnum = f(f(xnum + p[i]) * z);
        xden = f(f(xden * z) + q[i]);
      }
      res = f(f(xnum / xden) + one);
      if (y1 < y) res = f(res / y1);
      else if (y1 > y) for (let k = 0; k < n; k++) { res = f(res * y); y = f(y + one); }
    } else {
      if (y <= xbig) {
        const ysq = f(y * y);
        let sum = c[6];
        for (let i = 0; i < 6; i++) sum = f(f(sum / ysq) + c[i]);
        sum = f(f(f(sum / y) - y) + MorrisonConstants.xxx);
        sum = f(sum + f(f(y - half) * logf(y)));
        res = expf(sum);
      } else return xinf;
    }
    if (parity) res = -res;
    if (fact !== one) res = f(fact / res);
    return res;
  }

  static cube(x) { return f(x * x * x); }   // Float(Double(x)^3): x*x точно в double, *x - одно округление в double, затем Float
  static sq(x) { return f(x * x); }

  constructor({ ihail, ndcnst }) {
    const m = this;
    m.ihail = ihail;
    m.ndcnst = f(ndcnst);
    m.drizzleFallSpeed = false;
    const PI = MorrisonConstants.pi, gamma = MorrisonConstants.gamma, cube = MorrisonConstants.cube;
    const F4_3 = f(L(4) / L(3)), F5_2 = f(L(5) / L(2));
    m.ai = L(700); m.ac = L(3.0e7); m.asn = L(11.72); m.ar = L(841.99667);
    m.bi = L(1); m.bc = L(2); m.bs = L(0.41); m.br = L(0.8);
    if (ihail === 0) { m.ag = L(19.3); m.bg = L(0.37); } else { m.ag = L(114.5); m.bg = L(0.5); }
    m.r = L(287.04); m.rv = L(461.5); m.cp = L(1005.7);
    m.ep2 = f(m.r / m.rv);
    m.cv = f(m.cp - m.r);
    m.cvv = L(1408.5); m.cpv = L(1870.0); m.cpl = L(4190.0); m.cpi = L(2106.0);
    m.xlv0 = L(2501000.0); m.xls0 = L(2834000.0);
    m.lv1 = f(m.xlv0 + f(f(m.cpl - m.cpv) * L(273.15)));
    m.lv2 = f(m.cpl - m.cpv);
    m.ls1 = f(m.xls0 + f(f(m.cpi - m.cpv) * L(273.15)));
    m.ls2 = f(m.cpi - m.cpv);
    m.tmelt = L(273.15);
    m.rhosu = f(L(85000.0) / f(m.r * m.tmelt));
    m.rhow = L(997.0); m.rhoi = L(500.0); m.rhosn = L(100.0);
    m.rhog = ihail === 0 ? L(400.0) : L(900.0);
    m.aimm = L(0.66); m.bimm = L(100.0); m.ecr = L(1.0); m.dcs = L(125.0e-6);
    m.mi0 = f(f(f(F4_3 * PI) * m.rhoi) * cube(L(10.0e-6)));
    m.mg0 = L(1.6e-10);
    m.f1s = L(0.86); m.f2s = L(0.28); m.f1r = L(0.78); m.f2r = L(0.308);
    m.g = L(9.81); m.qsmall = L(1.0e-14); m.qthr = L(1.0e-10); m.eii = L(0.1); m.eci = L(0.7);
    m.cpw = m.cpl;
    m.ci = f(f(m.rhoi * PI) / 6); m.di = L(3);
    m.cs = f(f(m.rhosn * PI) / 6); m.ds = L(3);
    m.cg = f(f(m.rhog * PI) / 6); m.dg = L(3);
    m.rin = L(0.1e-6);
    m.mmult = f(f(f(F4_3 * PI) * m.rhoi) * cube(L(5.0e-6)));
    m.lammaxi = f(1 / L(1.0e-6));
    m.lammini = f(1 / f(f(2 * m.dcs) + L(100.0e-6)));
    m.lammaxr = f(1 / L(20.0e-6));
    m.lamminr = f(1 / L(2800.0e-6));
    m.dB = L(300.0e-6);
    m.lammaxs = f(1 / L(10.0e-6));
    m.lammins = f(1 / L(2000.0e-6));
    m.lammaxg = f(1 / L(20.0e-6));
    m.lamming = f(1 / L(2000.0e-6));
    m.k1 = L(0.4); m.c1 = L(120.0);
    m.mw = L(0.018); m.osm = L(1.0); m.vi = L(3.0); m.epsm = L(0.7); m.rhoa = L(1777.0);
    m.map = L(0.132); m.ma = L(0.0284);
    m.rr = L(8.3145);
    m.bact = f(f(f(f(f(m.vi * m.osm) * m.epsm) * m.mw) * m.rhoa) / f(m.map * m.rhow));
    m.rm1 = L(0.052e-6); m.sig1 = L(2.04); m.nanew1 = L(72.2e6);
    m.f11 = f(L(0.5) * expf(f(L(2.5) * MorrisonConstants.sq(logf(m.sig1)))));
    m.f21 = f(1 + f(L(0.25) * logf(m.sig1)));
    m.rm2 = L(1.3e-6); m.sig2 = L(2.5); m.nanew2 = L(1.8e6);
    m.f12 = f(L(0.5) * expf(f(L(2.5) * MorrisonConstants.sq(logf(m.sig2)))));
    m.f22 = f(1 + f(L(0.25) * logf(m.sig2)));
    const { ds, dg, cs, cg, bs, br, bg, di, ci, eci, eii, rhosn, rhosu, rhog, rhow, rhoi, bimm, dcs, ecr, bi, rin } = m;
    const cons = new Array(42).fill(0);
    cons[1] = f(gamma(f(1 + ds)) * cs);
    cons[2] = f(gamma(f(1 + dg)) * cg);
    cons[3] = f(gamma(f(4 + bs)) / 6);
    cons[4] = f(gamma(f(4 + br)) / 6);
    cons[5] = gamma(f(1 + bs));
    cons[6] = gamma(f(1 + br));
    cons[7] = f(gamma(f(4 + bg)) / 6);
    cons[8] = gamma(f(1 + bg));
    cons[9] = gamma(f(F5_2 + f(br / 2)));
    cons[10] = gamma(f(F5_2 + f(bs / 2)));
    cons[11] = gamma(f(F5_2 + f(bg / 2)));
    cons[12] = f(gamma(f(1 + di)) * ci);
    cons[13] = f(f(f(gamma(f(bs + 3)) * PI) / 4) * eci);
    cons[14] = f(f(f(gamma(f(bg + 3)) * PI) / 4) * eci);
    cons[15] = f(f(f(f(L(-1108) * eii) * powf(PI, f(f(1 - bs) / 3))) * powf(rhosn, f(f(-2 - bs) / 3))) / f(4 * 720));
    cons[16] = f(f(f(gamma(f(bi + 3)) * PI) / 4) * eci);
    cons[17] = f(f(f(f(f(f(f(4 * 2 * 3) * rhosu) * PI) * eci) * eci) * gamma(f(f(2 * bs) + 2))) / f(8 * f(rhog - rhosn)));
    cons[18] = f(rhosn * rhosn);
    cons[19] = f(rhow * rhow);
    cons[20] = f(f(f(f(20 * PI) * PI) * rhow) * bimm);
    cons[21] = f(4 / f(dcs * rhoi));
    cons[22] = f(f(f(PI * rhoi) * f(f(dcs * dcs) * dcs)) / 6);
    cons[23] = f(f(f(PI / 4) * eii) * gamma(f(bs + 3)));
    cons[24] = f(f(f(PI / 4) * ecr) * gamma(f(br + 3)));
    cons[25] = f(f(f(f(f(PI * PI) / 24) * rhow) * ecr) * gamma(f(br + 6)));
    cons[26] = f(f(PI / 6) * rhow);
    cons[27] = gamma(f(1 + bi));
    cons[28] = f(gamma(f(4 + bi)) / 6);
    cons[29] = f(f(f(F4_3 * PI) * rhow) * cube(L(25.0e-6)));
    cons[30] = f(f(F4_3 * PI) * rhow);
    cons[31] = f(f(f(PI * PI) * ecr) * rhosn);
    cons[32] = f(f(PI / 2) * ecr);
    cons[33] = f(f(f(PI * PI) * ecr) * rhog);
    cons[34] = f(F5_2 + f(br / 2));
    cons[35] = f(F5_2 + f(bs / 2));
    cons[36] = f(F5_2 + f(bg / 2));
    cons[37] = f(f(f(f(4 * PI) * L(1.38e-23))) / f(f(6 * PI) * rin));
    cons[38] = f(f(f(PI * PI) / 3) * rhow);
    cons[39] = f(f(f(f(PI * PI) / 36) * rhow) * bimm);
    cons[40] = f(f(PI / 6) * bimm);
    cons[41] = f(f(f(PI * PI) * ecr) * rhow);
    m.cons = cons;
    m.dnu = [-0.557, -0.557, -0.430, -0.307, -0.186, -0.067, 0.050, 0.167,
      0.282, 0.397, 0.512, 0.626, 0.739, 0.853, 0.966, 0.966].map(L);
  }
}

// ======================================================================
// MorrisonRadar (MorrisonColumn)
export class MorrisonRadar {
  static nbins = 100;
  static csqrt(re, im) {
    const r = Math.sqrt(re * re + im * im);
    if (r === 0) return [0, 0];
    if (re >= 0) { const t = Math.sqrt(0.5 * (r + re)); return [t, im / (2 * t)]; }
    const t = Math.sqrt(0.5 * (r - re));
    return [Math.abs(im) / (2 * t), im < 0 ? -t : t];
  }
  constructor(m) {
    const PI = MorrisonConstants.pi;
    const lamda = 0.10;
    const Fd = x => f(x);   // f(_ x: Float) -> Double: литерал real в выражении double
    const water = T => {
      const epsinf = 5.27137 + 0.02164740 * T - 0.00131198 * T * T;
      const d = T - Fd(25.0);
      const epss = 78.54 * (Fd(1.0) - 4.579e-3 * d + 1.190e-5 * d * d - 2.800e-8 * d * d * d);
      const alpha = -16.8129 / (T + Fd(273.16)) + 0.0609265;
      const lambdas = 0.00033836 * Math.exp(2513.98 / (T + Fd(273.16))) * Fd(1e-2);
      const q = lambdas / lamda;
      const sa = Math.sin(alpha * PI * Fd(0.5)), ca = Math.cos(alpha * PI * Fd(0.5));
      const nenner = 1.0 + 2.0 * Math.pow(q, 1.0 - alpha) * sa + Math.pow(q, 2.0 - 2.0 * alpha);
      const epsr = epsinf + ((epss - epsinf) * (Math.pow(q, 1.0 - alpha) * sa + 1.0)) / nenner;
      const epsi = ((epss - epsinf) * (Math.pow(q, 1.0 - alpha) * ca + 0.0)) / nenner
        + lamda * Fd(1.25664) / Fd(1.88496);
      return MorrisonRadar.csqrt(f(epsr), f(-epsi));
    };
    const ice = T => {
      const c = 2.99e8;
      const TK = T + Fd(273.16);
      const fr = c / lamda * 1e-9;
      const B1 = Fd(0.0207), B2 = 1.16e-11, b = 335.0;
      const deltabeta = Math.exp(Fd(-10.02) + Fd(0.0364) * (TK - Fd(273.16)));
      const eb = Math.exp(b / TK);
      const betam = (B1 / TK) * (eb / ((eb - 1) * (eb - 1))) + B2 * fr * fr;
      const beta = betam + deltabeta;
      const theta = Fd(300.0) / TK - 1.0;
      const alfa = (0.00504 + 0.0062 * theta) * Math.exp(-22.1 * theta);
      const re = Fd(3.1884) + Fd(9.1e-4) * (TK - Fd(273.16));
      const im = f(alfa / fr + beta * fr);
      return MorrisonRadar.csqrt(re, -im);
    };
    this.mw = water(0); this.mi = ice(0);
    const mw = this.mw;
    const m2 = [mw[0] * mw[0] - mw[1] * mw[1], 2 * mw[0] * mw[1]];
    const num = [m2[0] - 1, m2[1]], den = [m2[0] + 2, m2[1]];
    const dd = den[0] * den[0] + den[1] * den[1];
    const kr = (num[0] * den[0] + num[1] * den[1]) / dd, ki = (num[1] * den[0] - num[0] * den[1]) / dd;
    this.kw = kr * kr + ki * ki;
    this.pi5 = f(f(f(f(PI * PI) * PI) * PI) * PI);
    this.lamda4 = lamda * lamda * lamda * lamda;
    const zfac = rho => {
      const a = f(f(f(L(0.176) / L(0.93)) * f(L(6.0) / PI)) * f(L(6.0) / PI));
      const b = f(f(f(PI * rho) / L(6.0)) / L(900.0));
      return f(f(a * b) * b);
    };
    this.zfacS = zfac(m.rhosn); this.zfacG = zfac(m.rhog);
    this.obms = f(1.0 / m.ds); this.ocms = powf(f(1.0 / f(f(PI * m.rhosn) / L(6.0))), this.obms);
    this.obmg = f(1.0 / m.dg); this.ocmg = powf(f(1.0 / f(f(PI * m.rhog) / L(6.0))), this.obmg);
    const bins = (d0, dmax, rho, oc, ob) => {
      const nb = MorrisonRadar.nbins;
      const ddx = new Array(nb + 1).fill(0);
      ddx[0] = d0 * 1.0; ddx[nb] = dmax;
      for (let n = 2; n <= nb; n++) {
        ddx[n - 1] = Math.exp((n - 1) / nb * Math.log(ddx[nb] / ddx[0]) + Math.log(ddx[0]));
      }
      const out = [];
      for (let n = 0; n < nb; n++) {
        const D = Math.sqrt(ddx[n] * ddx[n + 1]), dt = ddx[n + 1] - ddx[n];
        const x = f(f(PI * rho) / L(6.0)) * (D * D * D);
        const dg = oc * Math.pow(x, ob);
        let vg = f(PI / L(6.0)) * (dg * dg * dg);
        const rhog = Math.max(Math.min(x / vg, f(900)), 10.0);
        vg = x / rhog;
        const grenz = 1.0 - rhog / f(1000);
        out.push([D, dt, x, vg, rhog, grenz]);
      }
      return out;
    };
    this.snow = bins(L(100e-6), 0.02, m.rhosn, this.ocms, this.obms);
    this.graupel = bins(L(100e-6), 0.05, m.rhog, this.ocmg, this.obmg);
    const s = new Array(MorrisonRadar.nbins + 1).fill(0);
    const basis = [1.0 / 3.0, 4.0 / 3.0, 1.0 / 3.0];
    for (let n = 0; n < MorrisonRadar.nbins - 1; n += 2) { s[n] += basis[0]; s[n + 1] += basis[1]; s[n + 2] += basis[2]; }
    this.simpson = s;
  }
  get headWords() {
    return [this.mw[0], this.mw[1], this.mi[0], this.mi[1], this.kw, this.pi5, this.lamda4,
      this.zfacS, this.zfacG, this.ocms, this.obms, this.ocmg, this.obmg, 0, 0, 0].map(f);
  }
  binWords(b) { return b.flat().map(f); }
}

// ======================================================================
// MorrisonColumn
export const MorrisonColumn = {
  kernel: 'morr_column',
  maxLevels: 128,
  paramWords(m, g, dt, tsmall) {
    if (g.nz > MorrisonColumn.maxLevels) throw new Error(`схема Моррисона: nz ${g.nz} > ${MorrisonColumn.maxLevels} (MORR_MAXK)`);
    const w = [g.nx, g.ny, g.nz, g.strideJ, g.strideK].map(x => x >>> 0);
    const fl = [dt, f(1.0 / dt), tsmall,
      m.ai, m.ac, m.asn, m.ar, m.ag, m.bi, m.bc, m.bs, m.br, m.bg,
      m.r, m.rv, m.cp, m.ep2, m.cv, m.cvv, m.cpv, m.cpl, m.cpi,
      m.lv1, m.lv2, m.ls1, m.ls2, m.tmelt, m.rhosu, m.rhow, m.rhoi, m.rhosn, m.rhog,
      m.aimm, m.bimm, m.dcs, m.mi0, m.mg0, m.f1s, m.f2s, m.f1r, m.f2r, m.g,
      m.qsmall, m.qthr, m.cpw,
      m.ci, m.di, m.cs, m.ds, m.cg, m.dg, m.mmult,
      m.lammaxi, m.lammini, m.lammaxr, m.lamminr, m.lammaxs, m.lammins,
      m.lammaxg, m.lamming, m.dB,
      m.ndcnst, MorrisonConstants.pi, m.drizzleFallSpeed ? 1.0 : 0.0, ...m.cons, ...m.dnu];
    return Uint32Array.from([...w, ...fl.map(bitsOf)]);
  },
  // fields: [[buf, off]] ×13; surface: [buf, off]; radii: null или [[buf, off]] ×3
  encode(e, context, params, g, fields, dzq, surface, radii = null) {
    if (fields.length !== 13) throw new Error('morr_column: 13 полей');
    const p = context.pipeline(MorrisonColumn.kernel);
    e.setComputePipelineState(p);
    e.setBytes(new Uint8Array(params.buffer, params.byteOffset, params.byteLength), 0);
    fields.forEach(([b, o], n) => e.setBuffer(b, o, n + 1));
    e.setBuffer(dzq, 0, 14);
    e.setBuffer(surface[0], surface[1], 15);
    const dorad = radii == null ? 0 : 1;
    const r = radii ?? [surface, surface, surface];
    r.forEach(([b, o], n) => e.setBuffer(b, o, 16 + n));
    e.setBytes(i32bytes(dorad), 19);
    const w = 8;
    context.checkedDispatch(e, MorrisonColumn.kernel, [g.nx, g.ny, 1], [w, w, 1]);
  },
  layerThickness(v) {
    const dz = f(v.dzNominal);
    return v.mh.map(x => f(dz * f(1.0 / x)));
  },
};

// ======================================================================
// MorrisonMicrophysics (MorrisonColumn)
export class MorrisonMicrophysics {
  static species = ['qv', 'qc', 'qr', 'qi', 'qs', 'qg'];
  static numbers = ['nci', 'ncs', 'ncr', 'ncg'];
  static scratch = ['morr_t', 'morr_qv0'];
  static get arenaFields() {
    return [...MorrisonMicrophysics.species, ...MorrisonMicrophysics.numbers,
      'th', 'pp3d', 'prs', 'rho', 'surface_accum', 'dbz', ...MorrisonMicrophysics.scratch];
  }
  static Skip = { positivity: 1, column: 2, update: 4 };

  constructor({ context, grid, vertical, th0, pi0, dt, ihail = 1, ndcnst = 250, tsmall = L(0.0001), drizzleFallSpeed = false }) {
    this.skip = 0;
    this.dispatchesPerCall = 0;
    this.ctx = context;
    this.grid = grid;
    const m = new MorrisonConstants({ ihail, ndcnst });
    m.drizzleFallSpeed = drizzleFallSpeed;
    this.constants = m;
    this.dims = new GridDimsGPU(grid);
    const d = context.device;
    this.th0b = vertical.buffer(th0, d, 'morr.th0');
    this.pi0b = vertical.buffer(pi0, d, 'morr.pi0');
    this.dzqb = vertical.buffer(MorrisonColumn.layerThickness(vertical), d, 'morr.dzq');
    this.params = MorrisonColumn.paramWords(m, grid, f(dt), tsmall);
    if (!(m.ds === 3 && m.dg === 3)) throw new Error('ds/dg ≠ 3: morr_cbrt_cr не годится');
    const radar = new MorrisonRadar(m);
    this.radar = radar;
    const buf = (v, label) => d.makeBuffer(Float32Array.from(v), label);
    this.radHeadb = buf(radar.headWords, 'morr.radar.head');
    this.radSnowb = buf(radar.binWords(radar.snow), 'morr.radar.snow');
    this.radGraupelb = buf(radar.binWords(radar.graupel), 'morr.radar.graupel');
    this.radSimpsonb = buf(radar.simpson.map(f), 'morr.radar.simpson');
  }

  encodeReflectivity(cb, arena) {
    const e = cb.makeComputeCommandEncoder();
    const b = arena.buffer, off = n => arena.handle(n).offset, grid = this.grid, ctx = this.ctx;
    e.setComputePipelineState(ctx.pipeline('morr_prep'));
    e.setBytes(this.dims.bytes(), 0);
    e.setBuffer(this.th0b, 0, 1);
    e.setBuffer(this.pi0b, 0, 2);
    ['th', 'pp3d', 'qv', 'morr_t', 'morr_qv0'].forEach((n, i) => e.setBuffer(b, off(n), i + 3));
    ctx.checkedDispatch(e, 'morr_prep', [grid.nx, grid.ny, grid.nz], [32, 4, 1]);
    e.setComputePipelineState(ctx.pipeline('morr_refl10cm'));
    e.setBytes(new Uint8Array(this.params.buffer), 0);
    e.setBuffer(this.radHeadb, 0, 1);
    e.setBuffer(this.radSnowb, 0, 2);
    e.setBuffer(this.radGraupelb, 0, 3);
    e.setBuffer(this.radSimpsonb, 0, 4);
    ['morr_t', 'qr', 'qs', 'qg', 'ncr', 'ncs', 'ncg', 'rho', 'dbz'].forEach((n, i) => e.setBuffer(b, off(n), i + 5));
    ctx.checkedDispatch(e, 'morr_refl10cm', [grid.nx, grid.ny, 1], [8, 8, 1]);
    e.endEncoding();
  }

  setTimeStep(dt) {
    const d = f(dt);
    this.params[5] = bitsOf(d);
    this.params[6] = bitsOf(f(1.0 / d));
  }

  // encode(into: e, arena:, dt:, radii:)
  encode(e, arena, dt, radii = false) {
    if (isCB(e)) { const enc = e.makeComputeCommandEncoder(); this.encode(enc, arena, dt, radii); enc.endEncoding(); return; }
    let count = 0;
    const b = arena.buffer, off = n => arena.handle(n).offset, grid = this.grid, ctx = this.ctx;
    const cols = [grid.nx, grid.ny, 1], full = [grid.nx, grid.ny, grid.nz], tg3 = [32, 4, 1];
    const S = MorrisonMicrophysics.Skip;
    if (!(this.skip & S.positivity)) {
      MorrisonMicrophysics.species.forEach((sp, n) => {
        const thr = n === 0 ? 0.0 : L(1.0e-14);
        e.setComputePipelineState(ctx.pipeline('mp_pdefq'));
        e.setBytes(this.dims.bytes(), 0);
        e.setBuffer(b, off('rho'), 1);
        e.setBuffer(b, off(sp), 2);
        e.setBytes(f32bytes(thr), 3);
        ctx.checkedDispatch(e, 'mp_pdefq', cols, [32, 1, 1]);
        count++;
      });
    }
    e.setComputePipelineState(ctx.pipeline('morr_prep'));
    e.setBytes(this.dims.bytes(), 0);
    e.setBuffer(this.th0b, 0, 1);
    e.setBuffer(this.pi0b, 0, 2);
    ['th', 'pp3d', 'qv', 'morr_t', 'morr_qv0'].forEach((n, i) => e.setBuffer(b, off(n), i + 3));
    ctx.checkedDispatch(e, 'morr_prep', full, tg3);
    count++;
    if (!(this.skip & S.column)) {
      const fl = ['morr_t', ...MorrisonMicrophysics.species, ...MorrisonMicrophysics.numbers, 'prs', 'rho'].map(n => [b, off(n)]);
      MorrisonColumn.encode(e, ctx, this.params, grid, fl, this.dzqb, [b, off('surface_accum')],
        radii ? ['effc', 'effi', 'effs'].map(n => [b, off(n)]) : null);
      count++;
    }
    if (!(this.skip & S.update)) {
      e.setComputePipelineState(ctx.pipeline('morr_post'));
      e.setBytes(this.dims.bytes(), 0);
      e.setBuffer(this.th0b, 0, 1);
      e.setBuffer(this.pi0b, 0, 2);
      ['rho', 'morr_t', 'morr_qv0', 'qv', 'th', 'pp3d', 'prs'].forEach((n, i) => e.setBuffer(b, off(n), i + 3));
      ctx.checkedDispatch(e, 'morr_post', full, tg3);
      count++;
    }
    this.dispatchesPerCall = count;
  }
}

// ======================================================================
// tgamma в double (эталонная libm). Ланцош g=607/128, 15 членов (Годфри):
// относительная ошибка ~1e-15, после Float(…) совпадает с libm.
const LG = 607 / 128;
const LC = [0.99999999999999709182, 57.156235665862923517, -59.597960355475491248,
  14.136097974741747174, -0.49191381609762019978, 0.33994649984811888699e-4,
  0.46523628927048575665e-4, -0.98374475304879564677e-4, 0.15808870322491248884e-3,
  -0.21026444172410488319e-3, 0.21743961811521264320e-3, -0.16431810653676389022e-3,
  0.84418223983852743293e-4, -0.26190838401581408670e-4, 0.36899182659531622704e-5];
export function tgamma(x) {
  if (x < 0.5) return Math.PI / (Math.sin(Math.PI * x) * tgamma(1 - x));
  x -= 1;
  let a = LC[0];
  const t = x + LG + 0.5;
  for (let i = 1; i < 15; i++) a += LC[i] / (x + i);
  return Math.sqrt(2 * Math.PI) * Math.pow(t, x + 0.5) * Math.exp(-t) * a;
}
const gammaF = x => f(tgamma(x));

// ======================================================================
// GoddardConstants
export class GoddardConstants {
  static a1 = [
    0.7939e-7, 0.7841e-6, 0.3369e-5, 0.4336e-5, 0.5285e-5, 0.3728e-5,
    0.1852e-5, 0.2991e-6, 0.4248e-6, 0.7434e-6, 0.1812e-5, 0.4394e-5,
    0.9145e-5, 0.1725e-4, 0.3348e-4, 0.1725e-4, 0.9175e-5, 0.4412e-5,
    0.2252e-5, 0.9115e-6, 0.4876e-6, 0.3473e-6, 0.4758e-6, 0.6306e-6,
    0.8573e-6, 0.7868e-6, 0.7192e-6, 0.6513e-6, 0.5956e-6, 0.5333e-6,
    0.4834e-6].map(L);
  static a2 = [
    0.4006, 0.4831, 0.5320, 0.5307, 0.5319, 0.5249, 0.4888, 0.3894,
    0.4047, 0.4318, 0.4771, 0.5183, 0.5463, 0.5651, 0.5813, 0.5655,
    0.5478, 0.5203, 0.4906, 0.4447, 0.4126, 0.3960, 0.4149, 0.4320,
    0.4506, 0.4483, 0.4460, 0.4433, 0.4413, 0.4382, 0.4361].map(L);

  constructor({ dt, ihail = 0 }) {
    const c = this, A1 = GoddardConstants.a1, A2 = GoddardConstants.a2;
    c.ihail = ihail; c.dt = dt;
    const cp = L(1.0057e7);
    const cpi = f(4.0 * f(Math.atan(1.0)));
    const cpi2 = f(cpi * cpi);
    const grvt = L(981.0), tca = L(2.43e3), dwv = L(0.226), amw = L(18.016), ars = L(8.314e7);
    c.t0k = L(273.15); c.t00k = L(233.15);
    c.alv = L(2.501000e10); c.als = L(2.834000e10);
    c.alf = f(c.als - c.alv);
    c.avc = f(c.alv / cp); c.afc = f(c.alf / cp); c.asc = f(c.als / cp);
    const rw = L(4.615e6), cw = L(4.190e7), ci = L(2.106000e7);
    c.c76 = L(7.66); c.c358 = L(29.65); c.c172 = L(17.67);
    c.c409 = f(L(17.67) * f(L(273.15) - L(29.65)));
    c.c218 = L(21.8745584);
    c.c580 = f(L(21.8745584) * f(L(273.15) - L(7.66)));
    c.c380 = f(f(f(L(10.0) * L(611.2)) * L(287.04)) / L(461.5));
    c.c610 = L(6.1078e3); c.c149 = L(1.496286e-5); c.c879 = L(8.794142); c.c141 = L(1.4144354e7);
    if (ihail === 1) {
      c.roqg = L(0.9); c.tng = L(0.0002);
      const cd1 = L(6.0e-1);
      const cd2 = f(f(4.0 * grvt) / f(3.0 * cd1));
      c.agg = sqrtf(f(cd2 * c.roqg));
      c.bgg = L(0.5);
    } else {
      c.roqg = L(0.4); c.tng = L(0.04); c.agg = L(351.2); c.bgg = L(0.37);
    }
    c.roqs = L(0.1); c.roqsPotter = L(1.0); c.tnss = L(1.0); c.ass = L(179.2); c.bss = L(0.42);
    c.roqr = L(1.0); c.tnw = L(0.08); c.aww = L(2115.0); c.bww = L(0.8);
    c.bgh = f(0.5 * c.bgg); c.bsh = f(0.5 * c.bss); c.bwh = f(0.5 * c.bww);
    c.bgq = f(0.25 * c.bgg); c.bsq = f(0.25 * c.bss); c.bwq = f(0.25 * c.bww);
    const ga3b = gammaF(f(3.0 + c.bww)), ga4b = gammaF(f(4.0 + c.bww)), ga6b = gammaF(f(6.0 + c.bww));
    const ga5bh = gammaF(f(f(5.0 + c.bww) / 2.0));
    const ga3g = gammaF(f(3.0 + c.bgg)), ga4g = gammaF(f(4.0 + c.bgg)), ga5gh = gammaF(f(f(5.0 + c.bgg) / 2.0));
    const ga3d = gammaF(f(3.0 + c.bss)), ga4d = gammaF(f(4.0 + c.bss)), ga5dh = gammaF(f(f(5.0 + c.bss) / 2.0));
    c.zrc = powf(f(f(cpi * c.roqr) * c.tnw), 0.25);
    c.zsc = powf(f(f(cpi * c.roqsPotter) * c.tnss), 0.25);
    c.zgc = powf(f(f(cpi * c.roqg) * c.tng), 0.25);
    c.vrc = f(f(c.aww * ga4b) / f(6.0 * powf(c.zrc, c.bww)));
    c.vsc = f(f(c.ass * ga4d) / f(6.0 * powf(c.zsc, c.bss)));
    c.vgc = f(f(c.agg * ga4g) / f(6.0 * powf(c.zgc, c.bgg)));
    c.rn1 = L(1.0e-3); c.rn2 = L(1.0e-3); c.bnd1 = L(5.0e-4); c.bnd2 = L(1.25e-3);
    c.rn3 = f(f(f(f(0.25 * cpi) * c.tnss) * c.ass) * ga3d);
    const esw = 1;
    c.rn4 = f(f(f(f(f(0.25 * cpi) * esw) * c.tnss) * c.ass) * ga3d);
    const eri = 1;
    c.rn5 = f(f(f(f(f(0.25 * cpi) * eri) * c.tnw) * c.aww) * ga3b);
    const ami = f(1.0 / f(24.0 * L(4.19e-10)));
    c.rn6 = f(f(f(f(f(f(cpi2 * eri) * c.tnw) * c.aww) * c.roqr) * ga6b) * ami);
    const esr = 1;
    c.rn7 = f(f(f(f(cpi2 * esr) * c.tnw) * c.tnss) * c.roqs);
    c.rn8 = f(f(f(f(cpi2 * esr) * c.tnw) * c.tnss) * c.roqr);
    c.rn9 = f(f(f(cpi2 * c.tnss) * c.tng) * c.roqs);
    c.rn10 = f(f(2.0 * cpi) * c.tnss);
    c.rn101 = f(f(L(0.31) * ga5dh) * sqrtf(c.ass));
    c.rn10a = f(f(c.als * c.als) / rw);
    c.rn11 = f(f(f(2.0 * cpi) * c.tnss) / c.alf);
    c.rn11a = f(cw / c.alf);
    c.ami40 = L(2.41e-8); c.ami50 = L(3.76e-8); c.ami100 = L(1.51e-7);
    const eiw = 1, ui50 = L(20.0), ri50 = L(10.0e-3), cmn = L(1.05e-15);
    c.rn12 = f(f(f(f(cpi * eiw) * ui50) * ri50) * ri50);
    c.rn12a = new Array(31).fill(0); c.rn12b = new Array(31).fill(0); c.rn25a = new Array(31).fill(0);
    for (let k = 0; k < 31; k++) {
      const y1 = f(1.0 - A2[k]);
      const rn13 = f(f(A1[k] * y1) / f(powf(c.ami100, y1) - powf(c.ami40, y1)));
      c.rn12a[k] = f(rn13 / c.ami100);
      c.rn12b[k] = f(A1[k] * powf(c.ami100, A2[k]));
      c.rn25a[k] = f(A1[k] * powf(cmn, A2[k]));
    }
    const egw = 1, egi = L(0.1), egi2 = 1;
    c.rn14 = f(f(f(f(f(0.25 * cpi) * egw) * c.tng) * ga3g) * c.agg);
    c.rn15 = f(f(f(f(f(0.25 * cpi) * egi) * c.tng) * ga3g) * c.agg);
    c.rn15a = f(f(f(f(f(0.25 * cpi) * egi2) * c.tng) * ga3g) * c.agg);
    const egr = 1;
    c.rn16 = f(f(f(f(cpi2 * egr) * c.tng) * c.tnw) * c.roqr);
    c.rn17 = f(f(2.0 * cpi) * c.tng);
    c.rn17a = f(f(L(0.31) * ga5gh) * sqrtf(c.agg));
    c.rn17b = f(cw - ci);
    c.rn17c = cw;
    const apri = L(0.66), bpri = L(1.0e-4);
    c.rn18 = f(f(f(f(f(20.0 * cpi2) * bpri) * c.tnw) * c.roqr));
    c.rn18a = apri;
    c.rn19 = f(f(f(2.0 * cpi) * c.tng) / c.alf);
    c.rn19a = f(f(L(0.31) * ga5gh) * sqrtf(c.agg));
    c.rn19b = f(cw / c.alf);
    c.rn20 = f(f(2.0 * cpi) * c.tng);
    c.rn20a = f(f(c.als * c.als) / rw);
    c.rn20b = f(f(L(0.31) * ga5gh) * sqrtf(c.agg));
    c.bnd3 = L(2.0e-3);
    c.rn21 = f(f(L(1.0e3) * L(1.569e-12)) / L(0.15));
    const erw = 1;
    c.rn22 = f(f(f(f(f(0.25 * cpi) * erw) * c.aww) * c.tnw) * ga3b);
    c.rn23 = f(f(2.0 * cpi) * c.tnw);
    c.rn23a = f(f(L(0.31) * ga5bh) * sqrtf(c.aww));
    c.rn23b = f(f(c.alv * c.alv) / rw);
    c.rn25 = L(1.0e-6);
    c.rn30a = f(f(f(c.alv * c.als) * amw) / f(tca * ars));
    c.rn30b = f(c.alv / tca);
    c.rn30c = f(ars / f(dwv * amw));
    c.rn31 = L(1.0e-17);
    c.beta = L(-0.46);
    c.rn32 = f(4.0 * L(51.545e-4));
    c.rt0 = f(1.0 / f(c.t0k - c.t00k));
    c.bw3 = f(c.bww + 3.0); c.bs3 = f(c.bss + 3.0); c.bg3 = f(c.bgg + 3.0);
    c.bwh5 = f(2.5 + c.bwh); c.bsh5 = f(2.5 + c.bsh); c.bgh5 = f(2.5 + c.bgh);
    c.bw6 = f(c.bww + 6.0); c.bs6 = f(c.bss + 6.0);
    c.betah = f(0.5 * c.beta);
    const d2t = f(dt);
    c.r10t = f(c.rn10 * d2t);
    c.r11at = f(c.rn11a * d2t);
    c.r19bt = f(c.rn19b * d2t);
    c.r20t = f(-c.rn20 * d2t);
    c.r23t = f(-c.rn23 * d2t);
  }
  // Таблицы - powf эталонной libm: правильно округлённый pow плюс поправки, снятые с
  // эталона (micro_powfix.js). bwq = 0.25·0.8 у Годдарда постоянен.
  get pwr81() {
    const r = new Float32Array(152);
    for (let i = 0; i <= 151; i++) r[i] = powf(f(L(173.15) + i), L(0.81));
    const u = new Uint32Array(r.buffer); for (const [i, w] of PWR81_FIX) u[i] = w;
    return Array.from(r);
  }
  get pwr2() {
    const r = new Float32Array(50002);
    for (let i = 0; i <= 50001; i++) r[i] = powf(f(i * L(1.0e-9)), this.bwq);
    if (this.bwq === f(0.25 * L(0.8))) { const u = new Uint32Array(r.buffer); for (const [i, w] of PWR2_FIX) u[i] = w; }
    return Array.from(r);
  }
}

// ======================================================================
// GoddardParamsGPU: 111 float + 2 int32 = 452 байта
export class GoddardParamsGPU {
  static fieldNames = [
    'tnw', 'tnss', 'tng', 'roqr', 'roqs', 'roqsPotter',
    'roqg', 'zrc', 'zsc', 'zgc', 'vrc', 'vsc',
    'vgc', 'agg', 'bgg', 'ass', 'bss', 'aww',
    'bww', 'bgh', 'bgq', 'bsh', 'bsq', 'bwh',
    'bwq', 'alv', 'alf', 'als', 't0k', 't00k',
    'avc', 'afc', 'asc', 'rn1', 'bnd1', 'rn2',
    'bnd2', 'rn3', 'rn4', 'rn5', 'rn6', 'rn7',
    'rn8', 'rn9', 'rn10', 'rn101', 'rn10a', 'rn11',
    'rn11a', 'rn12', 'rn14', 'rn15', 'rn15a', 'rn16',
    'rn17', 'rn17a', 'rn17b', 'rn17c', 'rn18', 'rn18a',
    'rn19', 'rn19a', 'rn19b', 'rn20', 'rn20a', 'rn20b',
    'bnd3', 'rn21', 'rn22', 'rn23', 'rn23a', 'rn23b',
    'rn25', 'rn30a', 'rn30b', 'rn30c', 'rn31', 'beta',
    'rn32', 'ami40', 'ami50', 'ami100', 'rt0', 'bw3',
    'bs3', 'bg3', 'bwh5', 'bsh5', 'bgh5', 'bw6',
    'bs6', 'betah', 'r10t', 'r11at', 'r19bt', 'r20t',
    'r23t', 'c76', 'c358', 'c172', 'c409', 'c218',
    'c580', 'c380', 'c610', 'c149', 'c879', 'c141',
    'tem5', 'dt', 'rdt'];
  constructor(c, iautoc) {
    for (const n of GoddardParamsGPU.fieldNames) if (n in c) this[n] = f(c[n]);
    this.tem5 = f(0.5 / f(sqrtf(c.ami100) - sqrtf(c.ami40)));
    this.dt = f(c.dt);
    this.rdt = f(1.0 / c.dt);
    this.ihail = c.ihail;
    this.iautoc = iautoc;
  }
  get values() { return GoddardParamsGPU.fieldNames.map(n => this[n]); }
  bytes() {
    const b = new Bytes();
    for (const v of this.values) b.f32(v);
    return b.i32(this.ihail).i32(this.iautoc).end();
  }
}

// ======================================================================
// Годдард-LFO
export class Microphysics {
  static species = ['qv', 'qc', 'qr', 'qi', 'qs', 'qg'];
  static falling = ['qr', 'qi', 'qs', 'qg'];
  static Skip = { conversions: 1, satAdjust: 2, sedimentation: 4, positivity: 8 };
  static get arenaFields() {
    return [...Microphysics.species, 'th', 'pp3d', 'prs', 'rho', 'mp_flux', 'surface_accum', 'dbz',
      ...Microphysics.falling.map(x => 'vt_' + x)];
  }

  constructor({ context, grid, vertical, th0 = null, pi0 = null, mh = null, dt = 6.0, ihail = 0, iautoc = 1 }) {
    this.missingProcesses = [];
    this.ablateBlocks = 0;
    this.skip = 0;
    this.dispatchesPerCall = 0;
    this.ctx = context;
    this.constants = new GoddardConstants({ dt, ihail });
    this.gparams = new GoddardParamsGPU(this.constants, iautoc);
    this.ihail = ihail; this.iautoc = iautoc;
    this.grid = grid; this.vertical = vertical;
    this.dims = new GridDimsGPU(grid);
    const d = context.device;
    const th0v = th0 ?? new Array(grid.nz).fill(L(300.0));
    const pi0v = pi0 ?? vertical.zh.slice(0, grid.nz).map(z => f(1.0 - 9.81 * z / (1005.7 * 300.0)));
    this.th0b = vertical.buffer(th0v, d, 'mp.th0');
    this.pi0b = vertical.buffer(pi0v, d, 'mp.pi0');
    this.mhb = vertical.buffer(mh ?? vertical.mh, d, 'mp.mh');
    const tbl = (v, label) => {
      const b = d.makeBuffer(Math.max(1, v.length) * 4, label);
      b.f32.set(v);
      return b;
    };
    const c = this.constants;
    this.rn12ab = tbl(c.rn12a, 'mp.rn12a');
    this.rn12bb = tbl(c.rn12b, 'mp.rn12b');
    this.rn25ab = tbl(c.rn25a, 'mp.rn25a');
    this.pwr81b = tbl(c.pwr81, 'mp.pwr81');
    this.pwr2b = tbl(c.pwr2, 'mp.pwr2');
  }
  get goddard() { return this.gparams; }

  encodeReflectivity(cb, arena) {
    const e = cb.makeComputeCommandEncoder(), grid = this.grid, ctx = this.ctx;
    e.setComputePipelineState(ctx.pipeline('mp_calcdbz'));
    e.setBytes(new GridDimsGPU(grid).bytes(), 0);
    e.setBytes(this.gparams.bytes(), 1);
    ['rho', 'qr', 'qs', 'qg', 'dbz'].forEach((n, i) => e.setBuffer(arena.buffer, arena.handle(n).offset, i + 2));
    ctx.checkedDispatch(e, 'mp_calcdbz', [grid.nx, grid.ny, grid.nz], [32, 4, 1]);
    e.endEncoding();
  }

  setTimeStep(dt) {
    if (dt === this.constants.dt) return;
    this.constants = new GoddardConstants({ dt, ihail: this.ihail });
    this.gparams = new GoddardParamsGPU(this.constants, this.iautoc);
    const c = this.constants;
    for (const [v, buf] of [[c.rn12a, this.rn12ab], [c.rn12b, this.rn12bb], [c.rn25a, this.rn25ab],
      [c.pwr81, this.pwr81b], [c.pwr2, this.pwr2b]]) buf.f32.set(v);
  }

  encode(e, arena, dt) {
    if (isCB(e)) { const enc = e.makeComputeCommandEncoder(); this.encode(enc, arena, dt); enc.endEncoding(); return; }
    let count = 0;
    const b = arena.buffer, off = n => arena.handle(n).offset, grid = this.grid, ctx = this.ctx;
    const S = Microphysics.Skip;
    if (!(this.skip & S.positivity)) {
      Microphysics.species.forEach((sp, n) => {
        const thr = n === 0 ? 0.0 : L(1.0e-14);
        e.setComputePipelineState(ctx.pipeline('mp_pdefq'));
        e.setBytes(this.dims.bytes(), 0);
        e.setBuffer(b, off('rho'), 1);
        e.setBuffer(b, off(sp), 2);
        e.setBytes(f32bytes(thr), 3);
        ctx.checkedDispatch(e, 'mp_pdefq', [grid.nx, grid.ny, 1], [32, 1, 1]);
        count++;
      });
    }
    if (!(this.skip & S.conversions)) {
      e.setComputePipelineState(ctx.pipeline('mp_goddard'));
      e.setBytes(this.dims.bytes(), 0);
      e.setBytes(this.gparams.bytes(), 1);
      e.setBuffer(this.th0b, 0, 2);
      e.setBuffer(this.pi0b, 0, 3);
      [this.rn12ab, this.rn12bb, this.rn25ab, this.pwr81b, this.pwr2b].forEach((t, i) => e.setBuffer(t, 0, i + 4));
      ['rho', 'prs', 'pp3d', 'th'].forEach((n, i) => e.setBuffer(b, off(n), i + 9));
      Microphysics.species.forEach((n, i) => e.setBuffer(b, off(n), i + 13));
      ['vt_qr', 'vt_qi', 'vt_qs', 'vt_qg'].forEach((n, i) => e.setBuffer(b, off(n), i + 19));
      e.setBytes(u32bytes(this.ablateBlocks), 23);
      ctx.checkedDispatch(e, 'mp_goddard', [grid.nx, grid.ny, grid.nz], [32, 4, 1]);
      count++;
    }
    if (!(this.skip & S.satAdjust)) {
      e.setComputePipelineState(ctx.pipeline('mp_satadj_ice'));
      e.setBytes(this.dims.bytes(), 0);
      e.setBuffer(this.th0b, 0, 1);
      e.setBuffer(this.pi0b, 0, 2);
      ['rho', 'prs', 'pp3d', 'th'].forEach((n, i) => e.setBuffer(b, off(n), i + 3));
      Microphysics.species.forEach((n, i) => e.setBuffer(b, off(n), i + 7));
      ctx.checkedDispatch(e, 'mp_satadj_ice', [grid.nx, grid.ny, grid.nz], [32, 4, 1]);
      count++;
    }
    if (!(this.skip & S.sedimentation)) {
      const dtf = f(dt);
      for (const sp of Microphysics.falling) {
        e.setComputePipelineState(ctx.pipeline('mp_fallout'));
        e.setBytes(this.dims.bytes(), 0);
        e.setBuffer(b, off('rho'), 1);
        e.setBuffer(this.mhb, 0, 2);
        e.setBuffer(b, off(sp), 3);
        e.setBuffer(b, off('vt_' + sp), 4);
        e.setBuffer(b, off('mp_flux'), 5);
        e.setBuffer(b, off('surface_accum'), 6);
        e.setBytes(f32bytes(dtf), 7);
        ctx.checkedDispatch(e, 'mp_fallout', [grid.nx, grid.ny, 1], [32, 1, 1]);
        count++;
      }
    }
    this.dispatchesPerCall = count;
  }
}

// ======================================================================
// RotunnoEmanuelMicrophysics (ptype = 6)
export class RotunnoEmanuelMicrophysics {
  static species = ['qv', 'qc'];
  static get arenaFields() {
    return [...RotunnoEmanuelMicrophysics.species, 'th', 'pp3d', 'prs', 'rho', 'vt_qc', 'mp_flux', 'surface_accum'];
  }
  static Skip = { positivity: 1, sedimentation: 2, satAdjust: 4, cap: 8 };

  constructor({ context, grid, vertical, th0, pi0, vT }) {
    if (!context.warmOnly) throw new Error('ptype 6 требует контекст без льда: GpuContext(warmOnly: true)');
    this.skip = 0;
    this.dispatchesPerCall = 0;
    this.ctx = context; this.grid = grid; this.vT = f(vT);
    this.dims = new GridDimsGPU(grid);
    const d = context.device;
    this.th0b = vertical.buffer(th0, d, 're87.th0');
    this.pi0b = vertical.buffer(pi0, d, 're87.pi0');
    this.mhb = vertical.buffer(vertical.mh, d, 're87.mh');
    this.convergenceFailures = d.makeBuffer(4, 're87.satadj_fail');
  }
  get failedCells() { return this.convergenceFailures.u32[0]; }

  encode(e, arena, dt) {
    if (isCB(e)) { const enc = e.makeComputeCommandEncoder(); this.encode(enc, arena, dt); enc.endEncoding(); return; }
    let count = 0;
    const b = arena.buffer, off = n => arena.handle(n).offset, grid = this.grid, ctx = this.ctx;
    const full = [grid.nx, grid.ny, grid.nz], tg3 = [32, 4, 1], cols = [grid.nx, grid.ny, 1], tgc = [32, 1, 1];
    const S = RotunnoEmanuelMicrophysics.Skip;
    if (!(this.skip & S.positivity)) {
      for (const [sp, thr] of [['qv', 0], ['qc', L(1.0e-14)]]) {
        e.setComputePipelineState(ctx.pipeline('mp_pdefq'));
        e.setBytes(this.dims.bytes(), 0);
        e.setBuffer(b, off('rho'), 1);
        e.setBuffer(b, off(sp), 2);
        e.setBytes(f32bytes(thr), 3);
        ctx.checkedDispatch(e, 'mp_pdefq', cols, tgc);
        count++;
      }
    }
    if (!(this.skip & S.sedimentation)) {
      e.setComputePipelineState(ctx.pipeline('mp_re87_fallspeed'));
      e.setBytes(this.dims.bytes(), 0);
      e.setBuffer(b, off('qc'), 1);
      e.setBuffer(b, off('vt_qc'), 2);
      e.setBytes(f32bytes(this.vT), 3);
      ctx.checkedDispatch(e, 'mp_re87_fallspeed', full, tg3);
      count++;
      e.setComputePipelineState(ctx.pipeline('mp_fallout'));
      e.setBytes(this.dims.bytes(), 0);
      e.setBuffer(b, off('rho'), 1);
      e.setBuffer(this.mhb, 0, 2);
      e.setBuffer(b, off('qc'), 3);
      e.setBuffer(b, off('vt_qc'), 4);
      e.setBuffer(b, off('mp_flux'), 5);
      e.setBuffer(b, off('surface_accum'), 6);
      e.setBytes(f32bytes(f(dt)), 7);
      ctx.checkedDispatch(e, 'mp_fallout', cols, tgc);
      count++;
    }
    if (!(this.skip & S.satAdjust)) {
      e.setComputePipelineState(ctx.pipeline('mp_satadj_warm'));
      e.setBytes(this.dims.bytes(), 0);
      e.setBuffer(this.th0b, 0, 1);
      e.setBuffer(this.pi0b, 0, 2);
      ['rho', 'prs', 'pp3d', 'th', 'qv', 'qc'].forEach((n, i) => e.setBuffer(b, off(n), i + 3));
      e.setBuffer(this.convergenceFailures, 0, 9);
      ctx.checkedDispatch(e, 'mp_satadj_warm', full, tg3);
      count++;
    }
    if (this.vT < L(-0.0001) && !(this.skip & S.cap)) {
      e.setComputePipelineState(ctx.pipeline('mp_re87_cap'));
      e.setBytes(this.dims.bytes(), 0);
      e.setBuffer(b, off('qc'), 1);
      ctx.checkedDispatch(e, 'mp_re87_cap', full, tg3);
      count++;
    }
    this.dispatchesPerCall = count;
  }
}
