// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Прогон из конфигурации CM1 целиком в браузере: сценарий, начальное
// состояние и лента шага - то же, что в записи эталона.
//
//   const run = buildRun(configuration, sounding)
//   run.diag           - команды отражаемости (как tape.diag)
//   run.encodeStep()   - команды одного шага (как tape.steps[k]); шаг сам
//                        ведёт своё время, как TimeStep в эталоне
//   run.tape()         - заголовок ленты для web/replay.js (buffers, fields, ...)
//   run.ctx.rec.buffers[id] - MBuf с начальным содержимым
//   run.adaptive       - adapt_dt=1: часы шага (AdaptiveStepper); шаг
//                        за шагом: beginStep, encodeStep, GPU, endStep(слова
//                        буфера stability) - dt и nsound следующего шага
import { GpuContext } from './gpu.js';
import { ThermoConstants } from './grid.js';
import { ScenarioBuilder } from './config.js';
import { AcousticParamsGPU } from './timestep.js';
import { AdaptiveTimeStep, stabilityFromWords } from './adaptive.js';

export function buildRun(configuration, sounding = null) {
  const sc = ScenarioBuilder.scenario(configuration, sounding);
  const ctx = new GpuContext({ thermo: sc.thermo, terrain: sc.terrain != null, axisymmetric: sc.axisymmetric,
    warmOnly: sc.warmOnlyContext });
  const { step, arena } = sc.build(ctx);
  const acoustic = new AcousticParamsGPU({ dts: 0.1, alph: 0.6, kdiv: 0.1, smeps: 0 });
  const rec = ctx.rec;
  rec.take();
  let diag = [];
  if (step.morrison) {
    step.morrison.encodeReflectivity(ctx.makeCommandBuffer(), arena);
    diag = rec.take();
  }
  let adaptive = null;
  if (sc.adaptiveTimeStep) {
    step.enableStabilityReduction();
    const clock = new AdaptiveTimeStep(sc.adaptiveTimeStep, { minHorizontalSpacing: step.acousticMinSpacing,
      twoDimensional: step.grid.isTwoDimensional, minVerticalSpacing: step.acousticMinVertical });
    step.setTimeStep(clock.dt, 4);
    const two = step.grid.isTwoDimensional;
    adaptive = {
      clock, stabilityId: rec.id(step.stabilityb),
      // t=0: только cflmax/ksmax начального состояния (cm1.F:2612-2636)
      encodeInitial() { step.encodeStability(ctx.makeCommandBuffer(), arena); return rec.take(); },
      start(words) { const s = stabilityFromWords(words, two); clock.start(s.cflmax, s.ksmax); step.setTimeStep(clock.dt, clock.nsound); },
      endStep(words) { const s = stabilityFromWords(words, two); clock.endStep(s.cflmax, s.ksmax); step.setTimeStep(clock.dt, clock.nsound); },
    };
  }
  return {
    sc, ctx, step, arena, acoustic, diag, adaptive,
    encodeStep() { step.encode(ctx.makeCommandBuffer(), arena, acoustic); return rec.take(); },
    // после загрузки на GPU копия арены на процессоре не нужна (шаг её не читает);
    // на ураган это 3.8 ГБ - без освобождения страница падает по памяти
    releaseArena() {
      const b = arena.buffer;
      b.ab = new ArrayBuffer(4); b.u8 = new Uint8Array(0); b.f32 = new Float32Array(0);
      if (b.i32) b.i32 = new Int32Array(0);
      if (b.u32) b.u32 = new Uint32Array(0);
    },
    tape(steps) {
      const fields = {};
      for (const [n, h] of Object.entries(arena.handles)) fields[n] = h.offset;
      return {
        nx: sc.grid.nx, ny: sc.grid.ny, nz: sc.grid.nz, dt: sc.dt, halo: 3, warmSteps: 0,
        constants: { terrain: sc.terrain != null, axisymmetric: sc.axisymmetric, warmOnly: sc.warmOnlyContext,
          thermoDefault: sc.thermo.isCM1Default,
          // DYCOMS: свои константы (testcase 4/5) - свой набор ядер
          testcase: [4, 5].find(t => sc.thermo.equals(ThermoConstants.forTestcase(t))) ?? 0 },
        buffers: rec.buffers.map((b, i) => ({ id: i, length: b.length, label: b.label, arena: b === arena.buffer })),
        fields, fieldStride: arena.fieldStride, steps, diag,
      };
    },
  };
}
