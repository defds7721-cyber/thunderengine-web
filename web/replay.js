// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Проигрыватель ленты эталона на WebGPU.
//
// Все буферы порта - в одной памяти M (array<u32>), указатель ядра -
// смещение в словах. Для каждого запуска собирается слот ARG (64 слова):
// [0..2] сетка запуска, [3] ноль для opq, [4 + n] смещение буфера n,
// [36] начало участка нитей (массивы, вынесенные из регистров).
// Лента одинакова на каждом шаге, поэтому слоты и конвейеры строятся раз.

import { splitWGSL, CHUNK_WORDS, chunkBinding, FORCE_SPLIT } from './memsplit.js';

const SLOT = 64;          // слов на слот ARG (256 байт - выравнивание смещения)
const ALIGN = 64;         // выравнивание буферов в M, слов
const BYTES_SPARE = 1 << 18;   // слов под байты новых структур шага (1 МБ)
const SCRATCH_CAP = 1 << 26;   // слов участка нитей (256 МБ); больше - запуск плитками по y
const MAX_BUFFER = 2147483644;  // предел буфера Safari (maxBufferSize); больше - куски (memsplit.js)

// Запуск плитками по y: индекс нити сдвигается на ARG[37], участок нитей
// считается по нити внутри плитки высотой ARG[38]. Арифметика ядра не меняется.
function tileWGSL(src) {
  const sig = 'fn main(@builtin(global_invocation_id) gid: vec3<u32>) {';
  const scr = /SCRB = ARG\[36\] \+ \(gid\.x \+ ARG\[0\] \* \(gid\.y \+ ARG\[1\] \* gid\.z\)\) \* (\d+)u;/;
  if (!src.includes(sig) || !scr.test(src)) throw new Error('плитки: у ядра нет ожидаемого входа');
  return src.replace(sig, 'fn main(@builtin(global_invocation_id) gid0: vec3<u32>) {\n    let gid = gid0 + vec3<u32>(0u, ARG[37], 0u);')
    .replace(scr, (_, n) => `SCRB = ARG[36] + (gid0.x + ARG[0] * (gid0.y + ARG[38] * gid0.z)) * ${n}u;`);
}

const unb64 = s => Uint8Array.from(atob(s), ch => ch.charCodeAt(0));
// Структура шага: команды без данных setBytes (длина остаётся)
const signature = cmds => cmds.map(c => c.op === 'bytes' ? `b${c.index}:${c.data.length}` : c.op === 'barrier' ? '' : JSON.stringify(c)).join('|');
const dataOf = cmds => new Map(cmds.map((c, i) => [i, c.op === 'bytes' ? c.data : null]).filter(x => x[1]));

export class Replayer {
  constructor(device, tape, kernels, sources) {
    this.d = device;
    this.tape = tape;
    this.kernels = kernels;
    this.sources = sources;
  }

  // Раскладка памяти и слотов по ленте шага (и диагностики, если есть).
  // Память M: буферы ленты | байты setBytes | запас байтов | участок нитей.
  plan(withHashes) {
    const t = this.tape;
    let top = 0;
    this.base = t.buffers.map(b => { const o = top; top += Math.ceil(b.length / 4 / ALIGN) * ALIGN; return o; });
    this.buffersEnd = top;
    this.bytes = [];
    this.bytesTop = top;
    this.scratchNeed = 0;
    this.hashCount = 0;
    this.withHashes = withHashes;
    const e0 = this.layoutBytes(t.steps[0]), eD = this.layoutBytes(t.diag || []);
    // запас под байты других структур шага (ленты, закодированные в браузере)
    this.bytesSpareEnd = this.bytesTop + BYTES_SPARE;
    top = Math.ceil(this.bytesSpareEnd / ALIGN) * ALIGN;
    this.ops = this.buildOps(t.steps[0], e0, withHashes);
    this.diagOps = this.buildOps(t.diag || [], eD, false);
    this.cache = new Map([[signature(t.steps[0]), { ops: this.ops, offs: e0, data: dataOf(t.steps[0]) }]]);
    this.scratchBase = top;
    top += Math.ceil(this.scratchNeed / ALIGN) * ALIGN;
    this.memWords = top;
  }

  // Места для данных setBytes списка команд: индекс команды -> слово M.
  layoutBytes(cmds) {
    const offs = new Map();
    cmds.forEach((c, i) => {
      if (c.op !== 'bytes') return;
      const raw = unb64(c.data);
      const words = Math.ceil(raw.length / 4);
      const padded = new Uint8Array(words * 4); padded.set(raw);
      if (this.bytesSpareEnd !== undefined && this.bytesTop + words + 4 > this.bytesSpareEnd)
        throw new Error('нет места под байты новой структуры шага (BYTES_SPARE)');
      offs.set(i, this.bytesTop);
      this.bytes.push([this.bytesTop, padded]);
      this.bytesTop += Math.ceil(words / 4) * 4 + 4;
    });
    return offs;
  }

  buildOps(cmds, offs, hashes) {
    const ops = [];
    let bind = new Map(), last = new Map(), pipe = null;
    cmds.forEach((c, i) => {
      switch (c.op) {
        case 'pipe': pipe = c.name; break;
        case 'buf': bind.set(c.index, c.buf < 0 ? 0 : this.base[c.buf] + c.offset / 4); last.set(c.index, c.buf); break;
        case 'bufoff': bind.set(c.index, this.base[last.get(c.index)] + c.offset / 4); break;
        case 'bytes': bind.set(c.index, offs.get(i)); break;
        case 'end': bind = new Map(); break;
        case 'copy':
          ops.push({ kind: 'copy', src: this.base[c.src] + c.srcOffset / 4, dst: this.base[c.dst] + c.dstOffset / 4, n: c.size / 4 });
          break;
        case 'dispatch': {
          const k = this.kernels[pipe];
          if (!k) throw new Error('нет ядра ' + pipe);
          const threads = c.grid[0] * c.grid[1] * c.grid[2];
          // ядро с участком нитей на большой сетке - плитками по y: участок на плитку,
          // столбцы независимы (morr_column, ysu_col, morr_refl10cm)
          let tileY = c.grid[1];
          if (k.scratch && k.scratch * threads > SCRATCH_CAP) {
            const row = k.scratch * c.grid[0] * c.grid[2];
            tileY = Math.max(c.tg[1], Math.floor(SCRATCH_CAP / row / c.tg[1]) * c.tg[1]);
          }
          this.scratchNeed = Math.max(this.scratchNeed, (k.scratch || 0) * c.grid[0] * c.grid[2] * tileY);
          const op = { kind: 'k', name: pipe, grid: c.grid, tg: c.tg, bind: new Map(bind), hashes: [], tileY };
          if (hashes) for (const p of k.params) {
            if (!p.write) continue;
            const off = bind.get(p.index);
            op.hashes.push({ slot: this.hashCount++, off, len: this.regionLen(off) });
          }
          ops.push(op);
        }
      }
    });
    return ops;
  }

  // Шаг, закодированный в браузере (web/core): та же структура - только
  // новые байты параметров; новая структура - свои слоты и конвейеры
  // (один раз). Байты пишутся в очередь до следующей отправки, поэтому
  // шаги с разными байтами отправляются по одному.
  async useStep(cmds) {
    const sig = signature(cmds);
    let e = this.cache.get(sig);
    if (!e) {
      const offs = this.layoutBytes(cmds);
      const ops = this.buildOps(cmds, offs, false);
      e = { ops, offs, data: new Map() };
      this.cache.set(sig, e);
      if (this.scratchBase + Math.ceil(this.scratchNeed / ALIGN) * ALIGN > this.memWords) await this.growScratch();
      await this.addPipelines(ops);
      this.addSlots(ops);
    }
    cmds.forEach((c, i) => {
      if (c.op !== 'bytes' || e.data.get(i) === c.data) return;
      e.data.set(i, c.data);
      const raw = unb64(c.data), padded = new Uint8Array(Math.ceil(raw.length / 4) * 4); padded.set(raw);
      this.writeWords(e.offs.get(i), padded);
    });
    this.ops = e.ops;
  }

  // Участок нитей в конце M: при нехватке - новая M больше, старое копируется.
  async growScratch() {
    const d = this.d, words = this.scratchBase + Math.ceil(this.scratchNeed / ALIGN) * ALIGN;
    if (this.mems.length > 1) {
      // куски: последний выделен целиком (1 ГБ), число кусков - в тексте ядер
      if (words > this.mems.length * CHUNK_WORDS) throw new Error('участок нитей не помещается в память модели');
      this.memWords = words;
      return;
    }
    if (words * 4 > MAX_BUFFER) throw new Error('память модели с участком нитей больше 2 ГБ: нужна раскладка кусками с начала');
    const mem = d.createBuffer({ size: words * 4, usage: this.mem.usage });
    const enc = d.createCommandEncoder();
    enc.copyBufferToBuffer(this.mem, 0, mem, 0, this.scratchBase * 4);
    d.queue.submit([enc.finish()]);
    this.mem.destroy();
    this.mem = mem; this.mems = [mem]; this.memWords = words;
    this.rebind();
  }

  // Длина участка, который пишет ядро: поле арены или остаток буфера.
  regionLen(off) {
    const t = this.tape;
    for (let b = t.buffers.length - 1; b >= 0; b--) {
      if (off >= this.base[b]) {
        const end = this.base[b] + t.buffers[b].length / 4;
        if (t.buffers[b].arena) return Math.min(t.fieldStride / 4, end - off);
        return end - off;
      }
    }
    return 0;
  }

  async build() {
    const d = this.d;
    const usage = GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC;
    // запас под участок нитей структур шага, которых ещё нет (излучение раз в dtrad и т. п.):
    // без него growScratch упирается в предел буфера или в число кусков
    const room = this.memWords + SCRATCH_CAP;
    if (room * 4 <= MAX_BUFFER && !FORCE_SPLIT) this.mems = [d.createBuffer({ size: this.memWords * 4, usage })];
    else {
      // куски по 1 ГБ; последний тоже целый
      const n = Math.ceil(room / CHUNK_WORDS);
      this.mems = Array.from({ length: n }, () => d.createBuffer({ size: CHUNK_WORDS * 4, usage }));
    }
    this.mem = this.mems[0];
    this.hash = d.createBuffer({ size: Math.max(16, this.hashCount * 4), usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST });
    this.bgl = d.createBindGroupLayout({ entries: [
      ...this.mems.map((_, j) => ({ binding: chunkBinding(0, j), visibility: GPUShaderStage.COMPUTE, buffer: { type: 'storage' } })),
      { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: 'read-only-storage', hasDynamicOffset: true, minBindingSize: SLOT * 4 } },
      { binding: 2, visibility: GPUShaderStage.COMPUTE, buffer: { type: 'storage' } },
    ] });
    this.layout = d.createPipelineLayout({ bindGroupLayouts: [this.bgl] });
    this.pipes = new Map();
    this.modules = new Map();
    await this.addPipelines([...this.ops, ...this.diagOps]);
    const util = d.createShaderModule({ code: this.wgsl(UTIL_WGSL) });
    this.pipes.set('_copy', await d.createComputePipelineAsync({ layout: this.layout, compute: { module: util, entryPoint: 'copy_words' } }));
    this.pipes.set('_hash', await d.createComputePipelineAsync({ layout: this.layout, compute: { module: util, entryPoint: 'region_hash' } }));
    this.slots = [];
    this.addSlots([...this.ops, ...this.diagOps]);
    for (const [off, data] of this.bytes) this.writeWords(off, data);
  }

  // текст шейдера под раскладку памяти (при одном куске - как есть)
  wgsl(src) { return splitWGSL(src, this.mems.length); }
  // привязки M для группы шейдера (M на привязке base)
  memEntries(base = 0) { return this.mems.map((buffer, j) => ({ binding: chunkBinding(base, j), resource: { buffer } })); }
  // запись в M по сплошному адресу (слова), через границы кусков
  writeWords(off, data) {
    const u8 = data instanceof Uint8Array ? data : new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
    let done = 0;
    while (done < u8.length) {
      // один буфер (до 2 ГБ) - без кусков: адрес как есть, хоть и больше 2^28 слов
      const w = off + done / 4, j = this.mems.length === 1 ? 0 : Math.floor(w / CHUNK_WORDS), at = w - j * CHUNK_WORDS;
      const n = this.mems.length === 1 ? u8.length - done : Math.min(u8.length - done, (CHUNK_WORDS - at) * 4);
      // writeBuffer: размер кратен 4
      const part = u8.subarray(done, done + n);
      if (n % 4) { const pad = new Uint8Array(Math.ceil(n / 4) * 4); pad.set(part); this.d.queue.writeBuffer(this.mems[j], at * 4, pad); }
      else this.d.queue.writeBuffer(this.mems[j], at * 4, part);
      done += n;
    }
  }

  async addPipelines(ops) {
    const d = this.d;
    for (const op of ops) {
      if (op.kind !== 'k') continue;
      const tiled = op.tileY !== op.grid[1];
      const mkey = op.name + (tiled ? '#плитки' : '');
      op.pkey = mkey + ':' + op.tg.join('x');
      if (this.pipes.has(op.pkey)) continue;
      if (!this.modules.has(mkey)) {
        if (!this.sources[op.name]) throw new Error('нет WGSL ядра ' + op.name);
        this.modules.set(mkey, d.createShaderModule({ code: this.wgsl(tiled ? tileWGSL(this.sources[op.name]) : this.sources[op.name]) }));
      }
      // По одной: десятки одновременных createComputePipelineAsync в WebKit
      // зависали без нагрузки на процессор (2026-10-16).
      const t0 = performance.now();
      const desc = { layout: this.layout, compute: { module: this.modules.get(mkey), entryPoint: 'main',
        constants: { WGX: op.tg[0], WGY: op.tg[1], WGZ: op.tg[2] } } };
      try { this.pipes.set(op.pkey, await d.createComputePipelineAsync(desc)); }
      catch (e) { throw new Error(`конвейер ${op.pkey}: ${e.reason || ''} ${e.message || e}`); }
      const dt = performance.now() - t0;
      if (dt > 2000 && this.onSlow) this.onSlow(op.pkey, dt);
    }
  }

  // Слоты ARG запусков; буфер ARG пересоздаётся целиком.
  addSlots(ops) {
    const slot = a => { const s = new Uint32Array(SLOT); s.set(a); this.slots.push(s); return this.slots.length - 1; };
    for (const op of ops) {
      if (op.kind === 'copy') {
        const a = [op.n, 1, 1, 0]; a[4] = op.src; a[5] = op.dst;
        op.slot = slot(a);
        continue;
      }
      const a = new Array(39).fill(0);
      a[0] = op.grid[0]; a[1] = op.grid[1]; a[2] = op.grid[2]; a[3] = 0;
      for (const [i, o] of op.bind) a[4 + i] = o;
      a[36] = this.scratchBase;
      // плитки: [37] сдвиг по y, [38] высота плитки (участок нитей - по плитке)
      op.tiles = [];
      for (let y = 0; y < op.grid[1]; y += op.tileY ?? op.grid[1]) {
        a[37] = y; a[38] = op.tileY ?? op.grid[1];
        op.tiles.push(slot(a));
      }
      op.slot = op.tiles[0];
      for (const h of op.hashes) {
        const b = [64 * 256, 1, 1, 0]; b[4] = h.off; b[5] = h.len; b[6] = h.slot;
        h.argSlot = slot(b);
      }
    }
    const argData = new Uint32Array(this.slots.length * SLOT);
    this.slots.forEach((s, i) => argData.set(s, i * SLOT));
    this.arg?.destroy();
    this.arg = this.d.createBuffer({ size: argData.byteLength, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST });
    this.d.queue.writeBuffer(this.arg, 0, argData);
    this.rebind();
  }

  rebind() {
    if (!this.arg) return;
    this.bind = this.d.createBindGroup({ layout: this.bgl, entries: [
      ...this.memEntries(0),
      { binding: 1, resource: { buffer: this.arg, size: SLOT * 4 } },
      { binding: 2, resource: { buffer: this.hash } },
    ] });
  }

  encodeDiag(enc) { this.encodeSteps(enc, 1, false, Infinity, this.diagOps); }

  upload(id, data) { this.writeWords(this.base[id], data); }
  // копия участка M (слова) в другой буфер - через границы кусков
  copyOut(enc, off, words, dst, dstByte) {
    for (let done = 0; done < words;) {
      const w = off + done, j = this.mems.length === 1 ? 0 : Math.floor(w / CHUNK_WORDS), at = w - j * CHUNK_WORDS;
      const n = this.mems.length === 1 ? words : Math.min(words - done, CHUNK_WORDS - at);
      enc.copyBufferToBuffer(this.mems[j], at * 4, dst, dstByte + done * 4, n * 4);
      done += n;
    }
  }
  // привязки M на чужой буфер (снимки шкалы времени) теми же кусками, что память
  // модели: шейдеры показа те же; кусков буфера не больше, чем у M (chunkCapacity)
  memEntriesFor(buffer, base = 0) {
    if (this.mems.length === 1) return [{ binding: chunkBinding(base, 0), resource: { buffer } }];
    this.stub ??= this.d.createBuffer({ size: 16, usage: GPUBufferUsage.STORAGE });
    return this.mems.map((_, j) => {
      const offset = j * CHUNK_WORDS * 4;
      return { binding: chunkBinding(base, j), resource: offset < buffer.size
        ? { buffer, offset, size: Math.min(CHUNK_WORDS * 4, buffer.size - offset) } : { buffer: this.stub } };
    });
  }
  get chunkCapacity() { return this.mems.length === 1 ? MAX_BUFFER : this.mems.length * CHUNK_WORDS * 4; }
  // большой буфер - порциями с ожиданием GPU: промежуточная копия writeBuffer
  // не копится (ураган: 3.8 ГБ разом роняли процесс страницы)
  async uploadAsync(id, data, part = 1 << 28) {
    const u8 = data instanceof Uint8Array ? data : new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
    for (let o = 0; o < u8.length; o += part) {
      this.writeWords(this.base[id] + o / 4, u8.subarray(o, Math.min(u8.length, o + part)));
      await this.d.queue.onSubmittedWorkDone();
    }
  }

  // Один шаг (или n шагов) ленты.
  encodeSteps(enc, n, withHashes, lastOp = Infinity, list = this.ops) {
    const pass = enc.beginComputePass();
    for (let s = 0; s < n; s++) {
      for (let oi = 0; oi < list.length && oi <= lastOp; oi++) {
        const op = list[oi];
        if (op.kind === 'copy') {
          pass.setPipeline(this.pipes.get('_copy'));
          pass.setBindGroup(0, this.bind, [op.slot * SLOT * 4]);
          pass.dispatchWorkgroups(Math.ceil(op.n / 256));
          continue;
        }
        pass.setPipeline(this.pipes.get(op.pkey));
        if (op.tiles.length > 1) {
          for (const t of op.tiles) {
            pass.setBindGroup(0, this.bind, [t * SLOT * 4]);
            pass.dispatchWorkgroups(Math.ceil(op.grid[0] / op.tg[0]), Math.ceil(op.tileY / op.tg[1]), Math.ceil(op.grid[2] / op.tg[2]));
          }
        } else {
          pass.setBindGroup(0, this.bind, [op.slot * SLOT * 4]);
          pass.dispatchWorkgroups(Math.ceil(op.grid[0] / op.tg[0]), Math.ceil(op.grid[1] / op.tg[1]), Math.ceil(op.grid[2] / op.tg[2]));
        }
        if (withHashes) {
          for (const h of op.hashes) {
            pass.setPipeline(this.pipes.get('_hash'));
            pass.setBindGroup(0, this.bind, [h.argSlot * SLOT * 4]);
            pass.dispatchWorkgroups(64);
          }
        }
      }
    }
    pass.end();
  }

  async read(words, offWords = 0) {
    const d = this.d;
    const rb = d.createBuffer({ size: words * 4, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST });
    const enc = d.createCommandEncoder();
    for (let done = 0; done < words;) {
      const w = offWords + done, j = this.mems.length === 1 ? 0 : Math.floor(w / CHUNK_WORDS), at = w - j * CHUNK_WORDS;
      const n = this.mems.length === 1 ? words : Math.min(words - done, CHUNK_WORDS - at);
      enc.copyBufferToBuffer(this.mems[j], at * 4, rb, done * 4, n * 4);
      done += n;
    }
    d.queue.submit([enc.finish()]);
    await rb.mapAsync(GPUMapMode.READ);
    const out = new Uint32Array(rb.getMappedRange().slice(0));
    rb.unmap(); rb.destroy();
    return out;
  }

  async readHashes() {
    const d = this.d;
    const rb = d.createBuffer({ size: this.hashCount * 4, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST });
    const enc = d.createCommandEncoder();
    enc.copyBufferToBuffer(this.hash, 0, rb, 0, this.hashCount * 4);
    d.queue.submit([enc.finish()]);
    await rb.mapAsync(GPUMapMode.READ);
    const out = new Uint32Array(rb.getMappedRange().slice(0));
    rb.unmap(); rb.destroy();
    return out;
  }
}

const UTIL_WGSL = `
@group(0) @binding(0) var<storage, read_write> M: array<u32>;
@group(0) @binding(1) var<storage, read> ARG: array<u32>;
@group(0) @binding(2) var<storage, read_write> H: array<atomic<u32>>;
@compute @workgroup_size(256)
fn copy_words(@builtin(global_invocation_id) g: vec3<u32>) {
  if (g.x >= ARG[0]) { return; }
  M[ARG[5] + g.x] = M[ARG[4] + g.x];
}
// Хэш участка - та же формула, что при записи эталона.
@compute @workgroup_size(256)
fn region_hash(@builtin(global_invocation_id) g: vec3<u32>) {
  let n = ARG[0];
  var s = 0u;
  for (var i = g.x; i < ARG[5]; i += n) {
    var h = (M[ARG[4] + i] ^ (i * 0x9E3779B1u)) * 0x85EBCA6Bu;
    h ^= h >> 13u; h *= 0xC2B2AE35u; h ^= h >> 16u;
    s += h;
  }
  atomicAdd(&H[ARG[6]], s);
}
`;
