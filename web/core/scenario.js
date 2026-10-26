// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Сценарий суперячейки: сетка, профили и начальное заполнение арены.
// Соседние модули (шаг, микрофизика, радиация) подключаются, если уже
// есть: заполнение арены от них не зависит и сверяется без них.
import { f, fmaf } from './f32.js';
import { powf, cosf } from './libm.js';
import { Grid, VerticalGrid, ThermoConstants, FieldArena } from './grid.js';
import { BaseState, WarmBubble, LineThermal, ColdPool, RotunnoEmanuelVortex, HashRand } from './base.js';

async function optional(path) {
  try { return await import(path); }
  catch (e) { if (e instanceof SyntaxError) throw e; return {}; }
}
const TS = await optional('./timestep.js');
const MP = await optional('./micro.js');
const RAD = await optional('./radiation.js');

// SupercellScenario.Radiation
export class ScenarioRadiation {
  constructor({ sun, lu0 = 16, tsk0 }) {
    this.sun = sun; this.tsk0 = tsk0;
    if (lu0 === 16) { this.emiss = f(0.98); this.albd = f(f(8.0) / f(100.0)); this.xland = f(2); }
    else if (lu0 === 3) { this.emiss = f(0.985); this.albd = f(f(18.0) / f(100.0)); this.xland = f(1); }
    else throw new Error(`lu0 = ${lu0}: LANDUSE.TBL портирован для 3 и 16`);
  }
}

export class SupercellScenario {
  // init(nx:ny:nz:dx:dy:dz:dt:umove:vmove:base:wind:hx:hy:vertical:)
  constructor({ nx = 120, ny = 120, nz = 40, dx = 1000, dy = 1000, dz = 500, dt = 6.0, umove = 12.5, vmove = 3.0,
    base = null, wind = { kind: 'weismanKlemp' }, hx = null, hy = null, vertical = null } = {}) {
    this.grid = new Grid({ nx, ny, nz, dx, dy, dz, hx, hy });
    if (vertical && vertical.nz !== nz) throw new Error('вертикальная сетка не того размера');
    this.vertical = vertical ?? VerticalGrid.uniform(nz, dz);
    this.base = base ?? BaseState.weismanKlemp({ zh: this.vertical.zh, moist: true, umove, vmove, wind });
    this.bubble = new WarmBubble();
    this.dt = dt;
    this.umove = umove; this.vmove = vmove;
    this.perturbation = { kind: 'warmBubble' };
    this.originAtCorner = false;
    this.useTKE = false;
    this.usePressureTendency = true;
    this._openX = true; this._openY = true;
    this.surfaceRoughness = null;
    this.surfaceFluxes = null;
    this.pbl = null; this.dns = null; this.landPBL = null;
    this.explicitAcoustics = false;
    this.simpleRadiation = false;
    this.radiation = null;
    this.bcturbs = 1;
    this.terrain = null; this.columnBase = null;
    this.axisymmetric = false; this.rigidX = false;
    this.morrisonDrizzleFallSpeed = false;
    this.initialTKETestcase = 0;
    this.thermo = ThermoConstants.cm1;
    this.turbulenceRampSeconds = null;
    this.explicitVerticalDiffusion = false;
    this.noSlipBottom = false; this.noSlipTop = false;
    this.lateralDampingWidth = null;
    this.radiativeRelaxation = false;
    this.randomPerturbationSeed = null;
    this.randomPerturbationTestcase = 0;
    this.adaptiveTimeStep = null;
    this.rayleighDamping = true; this.rayleighToAverage = false;
    this.rayleighZd = 15000.0; this.rayleighAlpha = 3.3333333333e-3;
    this.dissipativeHeating = false; this.conserveDryMass = false;
    this.coriolis = null; this.largeScalePG = false; this.largeScalePGMode = 1; this.hurricaneRadius = 1.0e30;
    this.cacheMoistureTurbulence = true;   // как в эталоне: он снят с этой настройкой
    this.numberConcentrations = false;
    this.morrison = false; this.ndcnst = 250; this.ihail = 1; this.iautoc = 1;
    this.rotunnoEmanuel = false; this.fallSpeedVT = 0;
    this.tqNudge = false;
    this.updraftNudging = null;   // iinit=12 (UpdraftNudging)
    this.moist = true;
    this.wenoMomentum = false;
    this.forcing = null;
    this.diagnosticFields = [];
  }
  get openBoundaries() { return this._openX && this._openY; }
  set openBoundaries(v) { this._openX = v; this._openY = v; }
  get openX() { return this._openX; } set openX(v) { this._openX = v; }
  get openY() { return this._openY; } set openY(v) { this._openY = v; }
  get warmOnlyContext() { return this.moist && this.rotunnoEmanuel; }

  get stepFields() {
    const F = TS.TimeStep?.Fields;
    if (!F) throw new Error('timestep.js не подключён: состав арены считает TimeStep.Fields');
    let fl;
    if (this.moist) {
      if (this.rotunnoEmanuel) { fl = F.moistWarmRain; if (this.useTKE) { fl.useTKE = true; fl.useRayleigh = true; } }
      else fl = this.useTKE ? F.moistWithTKE : F.moistGoddardLFO;
    } else {
      fl = F.dry;
      if (this.useTKE) { fl.useTKE = true; fl.useRayleigh = true; }
    }
    if (this.moist && (this.numberConcentrations || this.morrison)) fl = fl.withNumberConcentrations();
    fl.usePressureTendency = this.usePressureTendency;
    fl.terrain = this.terrain != null;
    fl.useRayleigh = this.rayleighDamping;
    fl.useLargeScalePG = this.coriolis != null && this.largeScalePG;
    fl.cacheMoistureTurbulence = this.cacheMoistureTurbulence;
    fl.updraftNudging = this.updraftNudging != null;
    return fl;
  }

  get arenaFields() {
    const set = new Set([
      ...this.stepFields.arenaFields,
      ...(this.moist && !this.rotunnoEmanuel ? MP.Microphysics.arenaFields : []),
      ...this.diagnosticFields,
      ...(this.moist && this.morrison ? MP.MorrisonMicrophysics.arenaFields : []),
      ...(this.radiation ? RAD.RadiationDriver.arenaFields : []),
      ...(this.moist && this.rotunnoEmanuel ? MP.RotunnoEmanuelMicrophysics.arenaFields : []),
    ]);
    return [...set].sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));   // как в эталоне: по байтам UTF-8
  }

  // Профили, которые build отдаёт шагу (в эталоне - локальные переменные build).
  stepProfiles() {
    const nz = this.grid.nz;
    const rho0f = this.base.rho0.map(f);
    const cgs = this.vertical.surfaceExtrapolation, cgt = this.vertical.topExtrapolation;
    const rf0 = [];
    for (let k = 0; k <= nz; k++) {
      if (k === 0) rf0.push(fmaf(cgs[2], rho0f[2], fmaf(cgs[0], rho0f[0], f(cgs[1] * rho0f[1]))));
      else if (k === nz) rf0.push(fmaf(cgt[2], rho0f[nz - 3], fmaf(cgt[0], rho0f[nz - 1], f(cgt[1] * rho0f[nz - 2]))));
      else rf0.push(fmaf(this.vertical.c1[k], rho0f[k - 1], f(this.vertical.c2[k] * rho0f[k])));
    }
    return {
      rho0: rho0f, rr0: rho0f.map(x => f(1.0 / x)), rf0,
      th0: this.base.th0.map(f), pi0: this.base.pi0.map(f), qv0: this.base.qv0.map(f), qc0: this.base.qc0.map(f),
    };
  }

  build(ctx) {
    const TimeStep = TS.TimeStep;
    if (!TimeStep) throw new Error('timestep.js не подключён');
    const f32 = v => v.map(f);
    const p = this.stepProfiles();
    if (!(ctx.thermo == null || ctx.thermo.equals(this.thermo))) throw new Error('константы контекста не совпадают со сценарием');
    if (ctx.terrain !== (this.terrain != null)) throw new Error('флаг рельефа контекста не совпадает со сценарием');
    if (ctx.warmOnly !== this.warmOnlyContext) throw new Error('флаг схемы без льда контекста не совпадает со сценарием');
    if (this.rotunnoEmanuel && this.morrison) throw new Error('две схемы микрофизики сразу: ptype 6 и 5');
    if (ctx.axisymmetric !== this.axisymmetric || this.grid.hx.axisymmetric !== this.axisymmetric) {
      throw new Error('флаг осесимметрии контекста / сетки не совпадает со сценарием');
    }
    const step = new TimeStep({
      context: ctx, grid: this.grid, vertical: this.vertical, dt: this.dt, fields: this.stepFields,
      rho0: p.rho0, rr0: p.rr0, rf0: p.rf0, th0: p.th0, pi0: p.pi0, qv0: p.qv0, qc0: p.qc0,
      explicitAcoustics: this.explicitAcoustics,
    });
    const b = this.base;
    if (!this.moist) { /* imoist=0: микрофизики нет */ }
    else if (this.rotunnoEmanuel) {
      step.rotunnoEmanuel = new MP.RotunnoEmanuelMicrophysics({ context: ctx, grid: this.grid, vertical: this.vertical,
        th0: f32(b.th0), pi0: f32(b.pi0), vT: this.fallSpeedVT });
    } else if (this.morrison) {
      step.morrison = new MP.MorrisonMicrophysics({ context: ctx, grid: this.grid, vertical: this.vertical,
        th0: f32(b.th0), pi0: f32(b.pi0), dt: this.dt, ihail: this.ihail, ndcnst: this.ndcnst,
        drizzleFallSpeed: this.morrisonDrizzleFallSpeed });
    } else {
      step.microphysics = new MP.Microphysics({ context: ctx, grid: this.grid, vertical: this.vertical,
        th0: f32(b.th0), pi0: f32(b.pi0), dt: this.dt, ihail: this.ihail, iautoc: this.iautoc });
    }
    step.wenoScalars = true;
    step.wenoMomentum = this.wenoMomentum;
    step.setForcing(this.forcing, b.v0);
    if (this.tqNudge) step.enableTQNudge();
    step.updraftNudging = this.updraftNudging;
    if (this.adaptiveTimeStep != null) step.enableStabilityReduction();
    if (this.stepFields.useRayleigh) step.setRayleigh(b.u0, b.v0, this.rayleighZd, f(this.rayleighAlpha));
    step.periodicX = !this.openX && !this.rigidX;
    step.periodicY = !this.openY;
    step.openX = this.openX;
    step.openY = this.openY;
    step.rigidX = this.rigidX;
    step.surfaceRoughness = this.surfaceRoughness;
    step.surfaceFluxes = this.surfaceFluxes;
    step.pbl = this.pbl;
    step.dns = this.dns;
    step.turbulenceRampSeconds = this.turbulenceRampSeconds;
    step.simpleRadiation = this.simpleRadiation;
    step.explicitVerticalDiffusion = this.explicitVerticalDiffusion;
    step.noSlipBottom = this.noSlipBottom;
    step.noSlipTop = this.noSlipTop;
    step.lateralDampingWidth = this.lateralDampingWidth;
    step.radiativeRelaxation = this.radiativeRelaxation;
    step.scalarBoundaryFlux = this.bcturbs;
    step.rayleighToAverage = this.rayleighToAverage;
    step.domainMotion = [this.umove, this.vmove];
    step.dissipativeHeating = this.dissipativeHeating && this.useTKE;
    step.conserveDryMass = this.conserveDryMass;
    if (this.coriolis != null) {
      step.hurricaneRadius = this.hurricaneRadius;
      step.setCoriolis(this.coriolis, this.largeScalePG, this.largeScalePGMode, b.u0, b.v0);
    }
    if (this.radiation) {
      if (!(this.moist && this.morrison)) throw new Error('radopt = 2 только с Моррисоном (param.F:2109)');
      const nk = this.grid.nz, cgt = this.vertical.topExtrapolation;
      const p0 = b.prs0.map(f);
      const pTop = fmaf(cgt[2], p0[nk - 3], fmaf(cgt[0], p0[nk - 1], f(cgt[1] * p0[nk - 2])));
      const r = this.radiation;
      // таблицы RRTMG грузятся заранее: await loadRRTMG(fetch) из radiation.js
      const lw = new RAD.RRTMGLongwave({ context: ctx, lw: RAD.RRTMGLongwaveTables.bundled(), nk, pTop });
      const sw = new RAD.RRTMGShortwave({ context: ctx, sw: RAD.RRTMGShortwaveTables.bundled(), common: lw.common, nk });
      const rad = new RAD.RadiationDriver({ context: ctx, grid: this.grid, vertical: this.vertical,
        th0: f32(b.th0), pi0: f32(b.pi0), lw, sw, sun: r.sun, co2: RAD.RRTMGLongwave.co2(r.sun.year),
        emiss: r.emiss, albd: r.albd, xland: r.xland });
      step.radiation = rad;
      if (this.surfaceFluxes == null) step.setSurfacePlane(13, r.tsk0);
      rad.surfacePerPoint = this.landPBL != null;
    }
    if (this.landPBL) {
      if (!(this.useTKE && this.moist)) throw new Error('sfcmodel = 3 + YSU требует useTKE и влагу');
      step.landPBL = this.landPBL;
    }
    const arena = new FieldArena({ context: ctx, grid: this.grid, fields: this.arenaFields });
    arena.zero(this.arenaFields);
    this.fill(arena);
    if (this.radiation) for (const n of ['effc', 'effi', 'effs']) arena.field(n).fill(25.0);
    if (this.terrain) { this.fillTerrain(arena, this.terrain); step.terrain = this.terrain; }
    return { step, arena };
  }

  put(arena, name, c, v) {
    arena.field(name)[c] = v;
    arena.field(name + '_a')[c] = v;
  }

  // Начальное состояние: базовое плюс возмущение (init3d.F).
  fill(arena) {
    const g = this.grid, hi = Grid.halo, th = this.thermo, b = this.base;
    const fth = arena.field('th'), fth_a = arena.field('th_a');
    const fu = arena.field('u'), fu_a = arena.field('u_a'), fv = arena.field('v'), fv_a = arena.field('v_a');
    const fprs = arena.field('prs'), frho = arena.field('rho');
    const hasQc = arena.handles.qc != null;
    const fqv = this.moist ? arena.field('qv') : null, fqv_a = this.moist ? arena.field('qv_a') : null;
    const fqc = this.moist && hasQc ? arena.field('qc') : null, fqc_a = this.moist && hasQc ? arena.field('qc_a') : null;
    const p00 = f(th.p00), cpdrd = f(f(th.cp) / f(th.rd)), rd = f(th.rd), rv = f(th.rv);
    const pt = this.perturbation;
    const lt = pt.kind === 'lineThermal' ? new LineThermal(pt.seed) : null;
    for (let k = 0; k < g.nz; k++) {
      const z = this.vertical.zh[k];
      const pi = f(b.pi0[k]);
      const p = f(p00 * powf(pi, cpdrd));
      const th0k = f(b.th0[k]);
      const u0 = f(b.u0[k]), v0 = f(b.v0[k]), qc0 = f(b.qc0[k]);
      for (let j = -hi; j <= g.ny + hi; j++) {
        const y = g.hy.centre(j);
        for (let i = -hi; i <= g.nx + hi; i++) {
          const x = g.hx.centre(i);
          const c = g.index(i, j, k);
          let tha;
          let qvCell = b.qv0[k];
          switch (pt.kind) {
            case 'none': tha = 0.0; break;
            case 'warmBubble': tha = this.bubble.perturbation(x, y, z); break;
            case 'lineThermal':
              if (i < 0 || i >= g.nx || j < 0 || j >= g.ny) tha = 0.0;
              else tha = lt.perturbation(g.hx.centre(i) - g.hx.face(0), z, i + 1, j + 1, k + 1);
              break;
            case 'coldPool': {
              const interior = i >= 0 && i < g.nx && j >= 0 && j < g.ny;
              const xc = x - 0.5 * (g.hx.face(0) + g.hx.face(g.nx));
              tha = interior ? pt.cp.perturbation(xc, z) : 0.0;
              qvCell = ColdPool.maintainedQv(b.qv0[k], b.th0[k], b.pi0[k], b.prs0[k], tha);
              break;
            }
            case 'bubbleLine': {
              const xo = this.originAtCorner ? x - g.hx.face(0) : x;
              const yo = this.originAtCorner ? y - g.hy.face(0) : y;
              tha = pt.bl.perturbation(xo, yo, z);
              break;
            }
            case 'vortex': tha = 0.0; break;
            default: throw new Error('возмущение ' + pt.kind);
          }
          const thf = f(tha);
          fth[c] = thf; fth_a[c] = thf;
          if (this.moist) { const q = f(qvCell); fqv[c] = q; fqv_a[c] = q; } else qvCell = 0;
          if (this.moist && hasQc) { fqc[c] = qc0; fqc_a[c] = qc0; }
          fu[c] = u0; fu_a[c] = u0; fv[c] = v0; fv_a[c] = v0;
          const rmix = f(rd + f(Math.max(0, f(qvCell)) * rv));
          const thFull = f(th0k + thf);
          fprs[c] = p;
          frho[c] = f(p / f(f(thFull * pi) * rmix));
        }
      }
    }
    if (pt.kind === 'vortex') this.applyVortex(arena, pt.vx);
    if (this.randomPerturbationSeed != null) this.applyRandomPerturbation(arena, this.randomPerturbationSeed);
    this.applyInitialTKE(arena);
  }

  // Рельеф: базовое состояние по столбцам и трёхмерные метрики.
  fillTerrain(arena, t) {
    if (!this.columnBase) throw new Error('рельеф без columnBase: базовое состояние по столбцам не задано');
    const g = this.grid, h = Grid.halo, nz = g.nz;
    const zd = this.rayleighZd, ztop = t.zt;
    const piF = f(3.1415926535897932384626433), zdF = f(zd), ztopF = f(ztop);
    const tau = z => {
      const zF = f(z);
      if (!(zF > zdF)) return 0;
      return f(f(0.5) * f(1.0 - cosf(f(f(piF * f(zF - zdF)) / f(ztopF - zdF)))));
    };
    for (const name of ['mh', 'mf', 'zf', 'c1', 'c2', 'gx', 'gxu', 'gy', 'gyv']) {
      const src = t[name], p = arena.field(name);
      for (let n = 0; n < Math.min(p.length, src.length); n++) p[n] = src[n];
    }
    const w = arena.field('w'), u = arena.field('u'), v = arena.field('v');
    for (let j = -h; j <= g.ny - 1 + h; j++) for (let i = -h; i <= g.nx - 1 + h; i++) {
      const ii = Math.max(-1, Math.min(g.nx, i)), jj = Math.max(-1, Math.min(g.ny, j));
      const c = g.index(ii, jj, 0), c0 = g.index(i, j, 0);
      const p0 = g.index(ii, jj, 0);
      w[c0] = f(f(f(0.5) * f(f(f(u[c] + u[c + 1]) * t.dzdx[p0]) + f(f(v[c] + v[c + g.strideJ]) * t.dzdy[p0]))) * t.gz[p0]);
    }
    const fields = {};
    for (const n of ['th0', 'pi0', 'rho0', 'rr0', 'rth0', 'qv0', 'qc0', 'qi0', 'tauh', 'rf0', 'tauf']) fields[n] = arena.field(n);
    const cgs = this.vertical.surfaceExtrapolation, cgt = this.vertical.topExtrapolation;
    for (let j = -h; j <= g.ny - 1 + h; j++) for (let i = -h; i <= g.nx - 1 + h; i++) {
      const col = t.column(i, j);
      const bs = this.columnBase(col);
      for (let k = 0; k < nz; k++) {
        const c = g.index(i, j, k);
        const th = f(bs.th0[k]), rho = f(bs.rho0[k]);
        fields.th0[c] = th; fields.pi0[c] = f(bs.pi0[k]); fields.rho0[c] = rho;
        fields.rr0[c] = f(1.0 / rho); fields.rth0[c] = f(1.0 / th);
        fields.qv0[c] = f(bs.qv0[k]); fields.qc0[c] = f(bs.qc0[k]); fields.qi0[c] = 0;
        fields.tauh[c] = tau(col[k]);
      }
      const r0 = bs.rho0.map(f);
      for (let k = 0; k <= nz; k++) {
        const c = g.index(i, j, k);
        let rf;
        if (k === 0) rf = fmaf(cgs[2], r0[2], fmaf(cgs[0], r0[0], f(cgs[1] * r0[1])));
        else if (k === nz) rf = fmaf(cgt[2], r0[nz - 3], fmaf(cgt[0], r0[nz - 1], f(cgt[1] * r0[nz - 2])));
        else rf = fmaf(t.c1[c], r0[k - 1], f(t.c2[c] * r0[k]));
        fields.rf0[c] = rf;
        fields.tauf[c] = tau(t.zf[c]);
      }
    }
  }

  // Начальная TKE по testcase (init3d.F:230-258).
  applyInitialTKE(arena) {
    if (!(this.useTKE && arena.handles.tke != null)) return;
    const tc = this.initialTKETestcase;
    if (![3, 4, 5, 9, 11].includes(tc)) return;
    const nz = this.grid.nz;
    const prof = new Array(nz + 1).fill(0);
    for (let k = 0; k <= nz; k++) {
      const zf = this.vertical.zf[k];
      const zh = this.vertical.zh[Math.min(k, nz - 1)];
      if (tc === 3) prof[k] = f(Math.max(0.0, 1.0 - zf / 3000.0));
      else if (tc === 4 || tc === 5) prof[k] = f(1.0);
      else if (zh < 255.0) { const r = 1.0 - zf / 255.0; prof[k] = f(0.4 * r * r * r); }
    }
    prof[0] = 0; prof[nz] = 0;
    const hi = Grid.halo, g = this.grid;
    for (const name of ['tke', 'tke_a']) {
      if (arena.handles[name] == null) continue;
      const p = arena.field(name);
      for (let k = 0; k <= nz; k++) for (let j = -hi; j <= g.ny + hi; j++) for (let i = -hi; i <= g.nx + hi; i++) {
        p[g.index(i, j, k)] = prof[k];
      }
    }
  }

  // Шум θ irandp=1 (init3d.F:1491-1632) и плотность из итогового состояния.
  applyRandomPerturbation(arena, seed) {
    const tc = this.randomPerturbationTestcase;
    if (tc === 12 || tc === 13) throw new Error(`testcase ${tc} (возмущения u, v) не портирован`);
    if (!(tc >= 0 && tc <= 11)) throw new Error(`testcase ${tc} не портирован`);
    const rd = f(this.thermo.rd), rv = f(this.thermo.rv);
    const top = tc === 0 ? 2 : 1;
    const g = this.grid;
    const fth = arena.field('th'), fth_a = arena.field('th_a');
    const fqv = this.moist ? arena.field('qv') : null, fqv_a = this.moist ? arena.field('qv_a') : null;
    const fpp = arena.field('pp3d'), fprs = arena.field('prs'), frho = arena.field('rho');
    for (let k = 0; k < g.nz; k++) {
      const zh = this.vertical.zh[k];
      let amplitude = 0, withQv = false;
      switch (tc) {
        case 0: amplitude = f(0.01); break;
        case 1: case 2: case 6: case 10: case 11: amplitude = zh <= 100.0 ? f(0.1) : 0; break;
        case 3: amplitude = zh <= 1600.0 ? f(0.1) : 0; withQv = true; break;
        case 4: case 5: case 7: amplitude = zh <= 1000.0 ? f(0.1) : 0; break;
        case 8: amplitude = k < 5 ? f(f(0.10) - f(f(k) * f(0.02))) : 0; break;
        case 9: amplitude = zh < 50.0 ? f(0.1) : 0; break;
      }
      if (amplitude === 0) continue;
      const th0 = f(this.base.th0[k]), pi0 = f(this.base.pi0[k]);
      for (let jj = 0; jj <= g.ny + top; jj++) for (let ii = 0; ii <= g.nx + top; ii++) {
        const i = ii - 1, j = jj - 1;
        if (!(i <= g.nx + Grid.halo && j <= g.ny + Grid.halo)) continue;
        const c = g.index(i, j, k);
        const rand = HashRand.value(seed, ii, jj, k + 1);
        const th = f(fth[c] + f(amplitude * f(f(2.0 * rand) - 1.0)));
        fth[c] = th; fth_a[c] = th;
        if (withQv && this.moist) {
          const rand2 = HashRand.value(seed + 1000003, ii, jj, k + 1);
          const q = f(fqv[c] + f(f(f(0.001) * f(0.025)) * f(f(2.0 * rand2) - 1.0)));
          fqv[c] = q; fqv_a[c] = q;
        }
        const pp = fpp[c];
        const qv = this.moist ? fqv[c] : 0;
        const p = fprs[c];
        frho[c] = f(p / f(f(f(th0 + th) * f(pi0 + pp)) * f(rd + f(Math.max(0, qv) * rv))));
      }
    }
  }

  // Вихрь iinit=7 (init3d.F:1100-1260) и prs, rho из полученного состояния.
  applyVortex(arena, vx) {
    const g = this.grid, nk = g.nz, b = this.base;
    const th0 = b.th0.map(f), pi0 = b.pi0.map(f), prs0 = b.prs0.map(f), qv0 = b.qv0.map(f), thv0 = b.thv0.map(f);
    const zh = this.vertical.zh.map(f);
    const minx = f(g.hx.face(0)), maxx = f(g.hx.face(g.nx));
    const miny = f(g.hy.face(0)), maxy = f(g.hy.face(g.ny));
    let dr = Math.min(f(g.dx), f(g.dy));
    if (!g.hx.isUniform) dr = Math.min(dr, f(g.hx.spacingRange.min));
    if (!g.hy.isUniform) dr = Math.min(dr, f(g.hy.spacingRange.min));
    const rrmax = Math.max(f(f(0.5) * f(maxx - minx)), f(f(0.5) * f(maxy - miny)));
    const fcor = f(this.coriolis ?? 0);
    const dzN = f(this.vertical.dzNominal);
    const p00 = f(this.thermo.p00), cpdrd = f(f(this.thermo.cp) / f(this.thermo.rd));
    const rd = f(this.thermo.rd), rv = f(this.thermo.rv);
    const pp3 = ['pp3d', 'ppi', 'ppd', 'ppx'].filter(n => arena.handles[n] != null).map(n => arena.field(n));
    const fprs = arena.field('prs'), frho = arena.field('rho');
    const ref = vx.reference(th0, pi0, prs0, qv0, thv0, zh, this.vertical.mf, dzN, fcor, dr, rrmax);
    if (g.hx.axisymmetric) {
      const rrefAxi = []; for (let i = 0; i < g.nx; i++) rrefAxi.push(f(g.hx.centre(i)));
      const refA = vx.reference(th0, pi0, prs0, qv0, thv0, zh, this.vertical.mf, dzN, fcor, dr,
        rrefAxi.length ? rrefAxi[rrefAxi.length - 1] : rrmax, rrefAxi);
      const nx = g.nx, ny = g.ny;
      const mirror = i => i < 0 ? -1 - i : (i >= nx ? 2 * nx - 1 - i : i);
      for (let k = 0; k < nk; k++) for (let j = -1; j <= ny + 1; j++) for (let i = -1; i <= nx + 1; i++) {
        const kk = k + 1, c = g.index(i, j, k);
        const im = mirror(i);
        const sgnV = i < 0 ? -1 : 1;
        this.put(arena, 'u', c, f(b.u0[k]));
        this.put(arena, 'v', c, f(f(sgnV * refA.vref[im][kk]) + f(b.v0[k])));
        if (!(i <= nx && j <= ny)) continue;
        const th = refA.thref[im][kk], q = refA.qvref[im][kk], pp = refA.piref[im][kk];
        this.put(arena, 'th', c, th);
        this.put(arena, 'qv', c, q);
        for (const a of pp3) a[c] = pp;
        const pi = f(pi0[k] + pp);
        const pr = f(p00 * powf(pi, cpdrd));
        fprs[c] = pr;
        frho[c] = f(pr / f(f(f(th0[k] + th) * pi) * f(rd + f(Math.max(0, q) * rv))));
      }
      return;
    }
    const centerx = f(minx + f(f(0.5) * f(maxx - minx))), centery = f(miny + f(f(0.5) * f(maxy - miny)));
    const lx = f(maxx - minx), ly = f(maxy - miny);
    const px = !this.openX, py = !this.openY;
    const copies = [[centerx, centery]];
    if (px && py) copies.push([f(centerx + lx), f(centery + ly)], [f(centerx - lx), f(centery - ly)],
      [f(centerx + lx), f(centery - ly)], [f(centerx - lx), f(centery + ly)]);
    if (px) copies.push([f(centerx + lx), centery], [f(centerx - lx), centery]);
    if (py) copies.push([centerx, f(centery + ly)], [centerx, f(centery - ly)]);
    const tsmall = f(1.0e-4);
    const nx = g.nx, ny = g.ny;
    const ppi = new Float32Array(g.count), tha = new Float32Array(g.count);
    const qv = new Float32Array(g.count), ua = new Float32Array(g.count), va = new Float32Array(g.count);
    for (let k = 0; k < nk; k++) for (let j = -1; j <= ny; j++) for (let i = -1; i <= nx; i++) qv[g.index(i, j, k)] = qv0[k];
    const interp = (a, i1, i2, kk, frac) => a[i1][kk] + f(a[i2][kk] - a[i1][kk]) * frac;
    for (const [xr, yr] of copies) {
      for (let k = 0; k < nk; k++) {
        const kk = k + 1;
        for (let j = -1; j <= ny; j++) for (let i = -1; i <= nx; i++) {
          const tem1 = f(f(g.hx.centre(i)) - xr), tem2 = f(f(g.hy.centre(j)) - yr);
          const rr = f(Math.sqrt(tem1 * tem1 + tem2 * tem2));
          const br = RotunnoEmanuelVortex.bracket(rr, ref);
          if (!br) continue;
          const [i1, i2] = br;
          const frac = f(f(rr - ref.rref[i1]) / f(ref.rref[i2] - ref.rref[i1]));
          const c = g.index(i, j, k);
          ppi[c] = interp(ref.piref, i1, i2, kk, frac);
          tha[c] = interp(ref.thref, i1, i2, kk, frac);
          qv[c] = interp(ref.qvref, i1, i2, kk, frac);
        }
        for (let j = -1; j <= ny; j++) for (let i = -1; i <= nx + 1; i++) {
          const tem1 = f(f(g.hx.face(i)) - xr), tem2 = f(f(g.hy.centre(j)) - yr);
          const rr = f(Math.sqrt(tem1 * tem1 + tem2 * tem2));
          const c = g.index(i, j, k);
          if (rr < tsmall) { ua[c] = 0; continue; }
          const br = RotunnoEmanuelVortex.bracket(rr, ref);
          if (!br) continue;
          const [i1, i2] = br;
          const frac = f(f(rr - ref.rref[i1]) / f(ref.rref[i2] - ref.rref[i1]));
          const temd = -Math.sin(Math.atan2(tem2, tem1));
          ua[c] = ua[c] + interp(ref.vref, i1, i2, kk, frac) * temd;
        }
        for (let j = -1; j <= ny + 1; j++) for (let i = -1; i <= nx; i++) {
          const tem1 = f(f(g.hx.centre(i)) - xr), tem2 = f(f(g.hy.face(j)) - yr);
          const rr = f(Math.sqrt(tem1 * tem1 + tem2 * tem2));
          const c = g.index(i, j, k);
          if (rr < tsmall) { va[c] = 0; continue; }
          const br = RotunnoEmanuelVortex.bracket(rr, ref);
          if (!br) continue;
          const [i1, i2] = br;
          const frac = f(f(rr - ref.rref[i1]) / f(ref.rref[i2] - ref.rref[i1]));
          const temd = Math.cos(Math.atan2(tem2, tem1));
          va[c] = va[c] + interp(ref.vref, i1, i2, kk, frac) * temd;
        }
      }
    }
    if (nx > 3 && ny > 3) {
      const amplitude = f(0.1);
      for (let k = 0; k < nk; k++) for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++) {
        const c = g.index(i, j, k);
        const rand = HashRand.value(vx.seed, i + 1, j + 1, k + 1);
        if (tha[c] >= f(0.1)) tha[c] = f(tha[c] + f(amplitude * f(f(2.0 * rand) - 1.0)));
      }
    }
    for (let k = 0; k < nk; k++) for (let j = -1; j <= ny + 1; j++) for (let i = -1; i <= nx + 1; i++) {
      const c = g.index(i, j, k);
      this.put(arena, 'u', c, f(ua[c] + f(b.u0[k])));
      this.put(arena, 'v', c, f(va[c] + f(b.v0[k])));
      if (!(i <= nx && j <= ny)) continue;
      this.put(arena, 'th', c, tha[c]);
      this.put(arena, 'qv', c, qv[c]);
      for (const a of pp3) a[c] = ppi[c];
      const pi = f(pi0[k] + ppi[c]);
      const p = f(p00 * powf(pi, cpdrd));
      const rmix = f(rd + f(Math.max(0, qv[c]) * rv));
      fprs[c] = p;
      frho[c] = f(p / f(f(f(th0[k] + tha[c]) * pi) * rmix));
    }
  }
}
