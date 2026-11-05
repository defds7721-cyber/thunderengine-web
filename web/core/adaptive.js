// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// adapt_dt=1 - переменный шаг по CM1: getnewdt
// (misclibs.F:543-742), dtsmall (misclibs.F:750-847) и часы вывода
// (cm1.F:2721-3878). Считается на процессоре в double, как у CM1; с GPU на
// шаг приходят два числа - cflmax и ksmax (ядро stability_max).
// Приведения как у Fortran: real - f32 (f), double precision - double.
import { AcousticSchedule } from './config.js';

const f = Math.fround;
const KINDS = ['tape', 'restart', 'stat', 'domainDiag', 'azimAvg', 'hifrq'];

export class AdaptiveTimeStep {
  // settings: { dtl, frequency: { tape, stat, restart, ... }, ksCheck }
  constructor(settings, { minHorizontalSpacing, twoDimensional, minVerticalSpacing = null }) {
    this.settings = settings;
    this.dtsm = AcousticSchedule.smallStep(minHorizontalSpacing, minVerticalSpacing, twoDimensional);
    this.ksLimit = twoDimensional ? f(0.18) : f(f(0.18) / f(2.0));
    this.dbldt = settings.dtl;
    this.dt = f(settings.dtl);
    this.dtlast = this.dt;
    this.nsound = 0;
    this.mtime = 0;
    this.cflmax = 0; this.ksmax = 0; this.steps = 0;
    this.clocks = KINDS.filter(k => settings.frequency[k] !== undefined)
      .map(kind => ({ kind, freq: f(settings.frequency[kind]), time: kind === 'restart' ? f(settings.frequency[kind]) : 0, fired: false }));
  }

  fired(kind) { return this.clocks.find(c => c.kind === kind)?.fired ?? false; }

  start(cflmax, ksmax) {
    this.getnewdt(cflmax, ksmax, true);
    for (const c of this.clocks) c.fired = c.kind !== 'restart';
    this.advanceClocks();
  }

  beginStep() {
    const tenth = f(f(0.1) * this.dt);
    for (const c of this.clocks) {
      const due = (this.mtime + this.dbldt) >= (c.time - tenth);
      if (c.kind === 'tape' || c.kind === 'stat') c.fired = due || c.freq < 0;
      else if (c.kind === 'restart') c.fired = due && c.freq > 0;
      else c.fired = due || c.freq <= 0;
    }
    this.mtime = this.mtime + this.dbldt;
    this.steps += 1;
  }

  endStep(cflmax, ksmax) {
    this.getnewdt(cflmax, ksmax, false);
    this.advanceClocks();
  }

  advanceClocks() {
    for (const c of this.clocks) {
      if (!(c.fired && c.freq > 0)) continue;
      do { c.time = c.time + c.freq; } while (!(c.time > this.mtime));
    }
  }

  getnewdt(cIn, kIn, doinit) {
    const cflLimit = f(1.00), maxChange = f(0.10);
    this.dtlast = this.dt;
    let cfl = f(Math.max(cIn, f(1.0e-10)));
    let ks = f(kIn);
    if (cfl > cflLimit) this.dbldt = this.dbldt * f(cflLimit / cfl);
    else this.dbldt = this.dbldt * Math.min(f(f(1.0) + maxChange), f(cflLimit / cfl));
    if (this.settings.ksCheck && (ks * this.dbldt / this.dt) > this.ksLimit) {
      this.dbldt = Math.min(this.dbldt, f(f(this.dt * this.ksLimit) / Math.max(f(1.0e-10), ks)));
    }
    this.dbldt = Math.min(this.dbldt, f(f(2.0) * this.settings.dtl));
    if (!doinit) {
      for (const c of this.clocks) {
        if (!(c.time > 0)) continue;
        const tout = c.fired ? ((c.time - this.mtime) + c.freq) : (c.time - this.mtime);
        if (tout > 2.0 * this.dbldt && tout <= 3.0 * this.dbldt) this.dbldt = tout / 3.0;
        else if (tout > this.dbldt && tout <= 2.0 * this.dbldt) this.dbldt = tout / 2.0;
        else if (tout <= this.dbldt) this.dbldt = tout;
      }
    }
    this.dt = f(this.dbldt);
    this.dtsmall();
    const tem = f(this.dt / this.dtlast);
    cfl = f(cfl * tem); ks = f(ks * tem);
    this.cflmax = cfl; this.ksmax = ks;
  }

  dtsmall() {
    const x = this.dbldt / this.dtsm;
    let n = Math.max(Math.trunc(Math.sign(x) * Math.round(Math.abs(x))), 4);
    if (n % 2 !== 0) n += 1;
    if (this.dbldt / f(n) > this.dtsm) n += 2;
    if (n > AcousticSchedule.maxNsound) {
      n = AcousticSchedule.maxNsound;
      this.dbldt = f(f(n) * this.dtsm);
      this.dt = f(this.dbldt);
    }
    this.nsound = n;
  }
}

// cflmax и ksmax из 8 байт буфера stability (биты квадратов): корень здесь,
// max √x = √max x (TimeStep.readStability)
export function stabilityFromWords(w, twoDimensional) {
  const fl = new Float32Array(w.buffer, w.byteOffset, 2);
  return { cflmax: f(Math.sqrt(fl[0])), ksmax: twoDimensional ? fl[1] : f(Math.sqrt(fl[1])) };
}
