// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Лёгкая прослойка над GPU для ядра модели: буферы, устройство, энкодер.
//
//  - MBuf - буфер: length, label, u8/f32/i32/u32 (общая память,
//    contents() отдаёт f32). Отдельного приватного режима хранения нет.
//  - Device создаёт буферы и помнит их все по порядку.
//  - Энкодер ничего не считает: записывает команды pipe, buf, bufoff, bytes,
//    dispatch, barrier, end, copy, которые потом исполняет проигрыватель
//    WebGPU. Барьеры записываются, но проигрыватель их не использует.
//  - Кернел по имени: ctx.pipeline('name') -> { name }.
//  - Параметры конструкторов - один объект с именованными полями,
//    nil -> null, enum с данными -> { kind: 'имя', ...данные },
//    векторы SIMD2/3/4 -> массивы. Float - через f() из f32.js.

export class MBuf {
  constructor(length, label = '') {
    this.length = length;
    this.label = label;
    this.ab = new ArrayBuffer(Math.ceil(length / 4) * 4);
    this.u8 = new Uint8Array(this.ab, 0, length);
    this.f32 = new Float32Array(this.ab);
    this.i32 = new Int32Array(this.ab);
    this.u32 = new Uint32Array(this.ab);
  }
  contents() { return this.f32; }
}

// makeBuffer(length) / makeBuffer(typedArray) - копия байт, как bytes:length:
// all - все созданные буферы по порядку (прогону в браузере нужны и те, что
// впервые используются на поздних шагах, например излучением).
export class Device {
  constructor() { this.all = []; }
  makeBuffer(src, label = '') {
    let b;
    if (typeof src === 'number') b = new MBuf(src, label);
    else {
      const bytes = src instanceof Uint8Array ? src : new Uint8Array(src.buffer, src.byteOffset, src.byteLength);
      b = new MBuf(bytes.length, label);
      b.u8.set(bytes);
    }
    this.all.push(b);
    return b;
  }
}

const b64 = bytes => { let s = ''; for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]); return btoa(s); };

// Список команд с нумерацией буферов по первому появлению - как у
// записывателя: сначала диагностика, потом шаг (порядок задаёт вызывающий).
export class Recorder {
  constructor() { this.ids = new Map(); this.buffers = []; this.commands = []; }
  id(buf) {
    if (!this.ids.has(buf)) { this.ids.set(buf, this.buffers.length); this.buffers.push(buf); }
    return this.ids.get(buf);
  }
  take() { const c = this.commands; this.commands = []; return c; }
}

export class ComputeEncoder {
  constructor(rec) { this.rec = rec; }
  setComputePipelineState(p) { this.rec.commands.push({ op: 'pipe', name: p.name }); }
  setBuffer(buf, offset, index) {
    this.rec.commands.push(buf ? { op: 'buf', index, buf: this.rec.id(buf), offset } : { op: 'buf', index, buf: -1, offset: 0 });
  }
  setBufferOffset(offset, index) { this.rec.commands.push({ op: 'bufoff', index, offset }); }
  // bytes: Uint8Array (Bytes.end()) или типизированный массив
  setBytes(bytes, index) {
    const u = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    this.rec.commands.push({ op: 'bytes', index, data: b64(u) });
  }
  dispatchThreads(grid, tg) { this.rec.commands.push({ op: 'dispatch', kind: 'threads', grid: [...grid], tg: [...tg] }); }
  dispatchThreadgroups(groups, tg) { this.rec.commands.push({ op: 'dispatch', kind: 'groups', grid: [...groups], tg: [...tg] }); }
  memoryBarrier() { this.rec.commands.push({ op: 'barrier' }); }
  endEncoding() { this.rec.commands.push({ op: 'end' }); }
}

export class BlitEncoder {
  constructor(rec) { this.rec = rec; }
  copy(src, srcOffset, dst, dstOffset, size) {
    this.rec.commands.push({ op: 'copy', src: this.rec.id(src), srcOffset, dst: this.rec.id(dst), dstOffset, size });
  }
  fill(buf, range, value) { throw new Error('fill не перенесён: нет в записывателе'); }
  endEncoding() { }
}

export class CommandBuffer {
  constructor(rec) { this.rec = rec; }
  makeComputeCommandEncoder() { return new ComputeEncoder(this.rec); }
  makeBlitCommandEncoder() { return new BlitEncoder(this.rec); }
}

// GpuContext: device, флаги сборки, pipeline(name), checkedDispatch.
export class GpuContext {
  constructor({ thermo = null, terrain = false, axisymmetric = false, warmOnly = false } = {}) {
    this.device = new Device();
    this.thermo = thermo;
    this.terrain = terrain; this.axisymmetric = axisymmetric; this.warmOnly = warmOnly;
    this.rec = new Recorder();
  }
  pipeline(name) { return { name }; }
  hasKernel(name) { return true; }
  makeCommandBuffer() { return new CommandBuffer(this.rec); }
  checkedDispatch(e, kernel, gs, tg) { e.dispatchThreads(gs, tg); }
}
