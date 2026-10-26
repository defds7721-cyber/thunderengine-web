// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Объёмный вид: изоповерхности прямо с памяти модели (M), как в эталоне:
// разбиение куба на 6 тетраэдров (Кун), нормали по сглаженному
// градиенту, свет сбоку относительно камеры, рёбра области, подложка.

// Поверхности и цвета - VolumeRenderer.defaultSurfaces.
export const SURFACES = [
  { key: 'dbz0', label: '>0 дБZ', field: 'dbz', iso: 0.5, colour: [0.42, 0.60, 0.78], group: 'dbz' },
  { key: 'dbz20', label: '20 дБZ', field: 'dbz', iso: 20, colour: [0.14, 0.74, 0.30], group: 'dbz' },
  { key: 'dbz40', label: '40 дБZ', field: 'dbz', iso: 40, colour: [0.96, 0.78, 0.16], group: 'dbz' },
  { key: 'dbz55', label: '55 дБZ', field: 'dbz', iso: 55, colour: [0.85, 0.16, 0.16], group: 'dbz' },
  { key: 'cloud', label: 'Облако 0.1 г/кг', field: 'qc', second: 'qi', iso: 0.0001, colour: [0.93, 0.94, 0.97], group: 'cloud' },
  { key: 'rain1', label: 'Дождь 1 г/кг', field: 'qr', iso: 0.001, colour: [0.30, 0.50, 0.95], group: 'rain' },
  { key: 'rain3', label: 'Дождь 3 г/кг', field: 'qr', iso: 0.003, colour: [0.10, 0.22, 0.75], group: 'rain' },
  { key: 'hail1', label: 'Град 1 г/кг', field: 'qg', iso: 0.001, colour: [0.85, 0.45, 0.90], group: 'hail' },
  { key: 'hail4', label: 'Град 4 г/кг', field: 'qg', iso: 0.004, colour: [0.55, 0.15, 0.70], group: 'hail' },
  { key: 'up10', label: '↑ 10 м/с', field: 'w', iso: 10, colour: [1.00, 0.60, 0.15], group: 'flow', staggered: true },
  { key: 'up25', label: '↑ 25 м/с', field: 'w', iso: 25, colour: [0.95, 0.30, 0.10], group: 'flow', staggered: true },
  { key: 'down5', label: '↓ 5 м/с', field: 'w', iso: 5, sign: -1, colour: [0.40, 0.60, 1.00], group: 'flow', staggered: true },
  // вращение: ζ в центрах ячеек (среднее по четырём углам, CM1 solve3.F:1067) - поле D
  { key: 'zeta10', label: 'ζ 10·10⁻³ 1/с', derived: true, iso: 0.01, colour: [0.20, 0.92, 0.95], group: 'rot' },
  { key: 'zeta30', label: 'ζ 30·10⁻³ 1/с', derived: true, iso: 0.03, colour: [0.05, 0.55, 0.75], group: 'rot' },
  { key: 'tornado', label: 'Торнадо ζ', derived: true, iso: 0.1, colour: [0.58, 0.12, 0.95], group: 'rot' },
];

const CAP = 900000;   // вершин на поверхность
export const PLANE = 512;   // подложка: композит dBZ, пересчитанный на равномерную картинку области

const BUILD_WGSL = `
// src: 0 - поле арены M, 1 - производное поле D (та же раскладка);
// координаты узлов (м) - из буфера X: центры по x с ox, по y с oy, высоты с oz
struct P { nx: i32, ny: i32, nz: i32, sJ: i32, sK: i32, f1: u32, f2: u32, combine: u32,
           iso: f32, sign: f32, src: u32, ox: u32, oy: u32, oz: u32, cap: u32, pad: u32 }
@group(0) @binding(0) var<storage, read> M: array<u32>;
@group(0) @binding(1) var<uniform> p: P;
@group(0) @binding(2) var<storage, read_write> V: array<vec4<f32>>;
@group(0) @binding(3) var<storage, read_write> C: array<atomic<u32>>;
@group(0) @binding(4) var<storage, read> X: array<f32>;
@group(0) @binding(5) var<storage, read> D: array<f32>;
fn at(i0: i32, j0: i32, k0: i32) -> f32 {
  let i = clamp(i0, 0, p.nx - 1); let j = clamp(j0, 0, p.ny - 1); let k = clamp(k0, 0, p.nz - 1);
  let c = u32((i + 3) + p.sJ * ((j + 3) + p.sK * k));
  var v: f32;
  if (p.src == 1u) { v = D[c]; } else {
    v = bitcast<f32>(M[p.f1 + c]);
    if (p.combine != 0u) { v += bitcast<f32>(M[p.f2 + c]); }
  }
  v *= p.sign;
  let b = bitcast<u32>(v) & 0x7fffffffu;
  return select(v, -1.0e30, b >= 0x7f800000u);
}
fn xc(i: i32) -> f32 { return X[p.ox + u32(clamp(i, 0, p.nx - 1))]; }
fn yc(j: i32) -> f32 { return X[p.oy + u32(clamp(j, 0, p.ny - 1))]; }
fn zh(k: i32) -> f32 { return X[p.oz + u32(clamp(k, 0, p.nz - 1))]; }
fn dif(a: f32, b: f32, d: f32) -> f32 { return select(0.0, (b - a) / d, d > 0.0); }
fn grad1(i: i32, j: i32, k: i32) -> vec3<f32> {
  let gx = dif(at(i - 1, j, k), at(i + 1, j, k), xc(i + 1) - xc(i - 1));
  let gy = dif(at(i, j - 1, k), at(i, j + 1, k), yc(j + 1) - yc(j - 1));
  let gz = dif(at(i, j, k - 1), at(i, j, k + 1), zh(k + 1) - zh(k - 1));
  return vec3<f32>(gx, gy, gz);
}
fn grad(i: i32, j: i32, k: i32) -> vec3<f32> {
  var s = grad1(i, j, k) * 2.0;
  s += grad1(i - 1, j, k); s += grad1(i + 1, j, k);
  s += grad1(i, j - 1, k); s += grad1(i, j + 1, k);
  s += grad1(i, j, k - 1); s += grad1(i, j, k + 1);
  return s / 8.0;
}
struct Vx { pos: vec3<f32>, nrm: vec3<f32> }
fn cut(pa: vec3<f32>, pb: vec3<f32>, na: vec3<f32>, nb: vec3<f32>, va: f32, vb: f32) -> Vx {
  let d = vb - va;
  let t = select(0.5, clamp((p.iso - va) / d, 0.0, 1.0), abs(d) > 1.0e-20);
  let n = mix(na, nb, t);
  let len = length(n);
  return Vx(mix(pa, pb, t), select(vec3<f32>(0.0, 0.0, 1.0), -n / len, len > 1.0e-12));
}
fn emit(a: Vx, b: Vx, c: Vx) {
  let gn = cross(b.pos - a.pos, c.pos - a.pos);
  let fl = dot(gn, a.nrm + b.nrm + c.nrm) < 0.0;
  let base = atomicAdd(&C[0], 3u);
  if (base + 3u > p.cap) { return; }
  var bb = b; var cc = c;
  if (fl) { bb = c; cc = b; }
  V[2u * base] = vec4<f32>(a.pos, 1.0); V[2u * base + 1u] = vec4<f32>(a.nrm, 0.0);
  V[2u * (base + 1u)] = vec4<f32>(bb.pos, 1.0); V[2u * (base + 1u) + 1u] = vec4<f32>(bb.nrm, 0.0);
  V[2u * (base + 2u)] = vec4<f32>(cc.pos, 1.0); V[2u * (base + 2u) + 1u] = vec4<f32>(cc.nrm, 0.0);
}
var<private> PS: array<vec3<f32>, 8>;
var<private> NS: array<vec3<f32>, 8>;
var<private> VS: array<f32, 8>;
fn tet(a0: u32, b0: u32, c0: u32, d0: u32) {
  let iso = p.iso;
  let mask = select(0u, 1u, VS[a0] >= iso) | select(0u, 2u, VS[b0] >= iso) | select(0u, 4u, VS[c0] >= iso) | select(0u, 8u, VS[d0] >= iso);
  if (mask == 0u || mask == 15u) { return; }
  var o = vec4<u32>(a0, b0, c0, d0);
  switch (mask) {
    case 1u, 14u: { }
    case 2u, 13u: { o = vec4<u32>(b0, a0, d0, c0); }
    case 4u, 11u: { o = vec4<u32>(c0, d0, a0, b0); }
    case 8u, 7u:  { o = vec4<u32>(d0, c0, b0, a0); }
    case 3u, 12u: { o = vec4<u32>(a0, b0, c0, d0); }
    case 5u, 10u: { o = vec4<u32>(a0, c0, d0, b0); }
    default:      { o = vec4<u32>(a0, d0, b0, c0); }
  }
  let pair = mask == 3u || mask == 12u || mask == 5u || mask == 10u || mask == 6u || mask == 9u;
  if (!pair) {
    emit(cut(PS[o.x], PS[o.y], NS[o.x], NS[o.y], VS[o.x], VS[o.y]),
         cut(PS[o.x], PS[o.z], NS[o.x], NS[o.z], VS[o.x], VS[o.z]),
         cut(PS[o.x], PS[o.w], NS[o.x], NS[o.w], VS[o.x], VS[o.w]));
  } else {
    let a = cut(PS[o.x], PS[o.z], NS[o.x], NS[o.z], VS[o.x], VS[o.z]);
    let b = cut(PS[o.x], PS[o.w], NS[o.x], NS[o.w], VS[o.x], VS[o.w]);
    let c = cut(PS[o.y], PS[o.w], NS[o.y], NS[o.w], VS[o.y], VS[o.w]);
    let d = cut(PS[o.y], PS[o.z], NS[o.y], NS[o.z], VS[o.y], VS[o.z]);
    emit(a, b, c); emit(a, c, d);
  }
}
@compute @workgroup_size(4, 4, 4)
fn build(@builtin(global_invocation_id) g: vec3<u32>) {
  let i = i32(g.x); let j = i32(g.y); let k = i32(g.z);
  if (i >= p.nx - 1 || j >= p.ny - 1 || k >= p.nz - 1) { return; }
  for (var c = 0; c < 8; c++) {
    let ci = i + (c & 1); let cj = j + ((c >> 1) & 1); let ck = k + ((c >> 2) & 1);
    PS[c] = vec3<f32>(xc(ci), yc(cj), zh(ck));
    VS[c] = at(ci, cj, ck);
    NS[c] = grad(ci, cj, ck);
  }
  tet(0u, 1u, 3u, 7u); tet(0u, 1u, 5u, 7u); tet(0u, 2u, 3u, 7u);
  tet(0u, 2u, 6u, 7u); tet(0u, 4u, 5u, 7u); tet(0u, 4u, 6u, 7u);
}
@compute @workgroup_size(1)
fn finish() {
  let n = min(atomicLoad(&C[0]), p.cap);
  atomicStore(&C[4], n); atomicStore(&C[5], 1u); atomicStore(&C[6], 0u); atomicStore(&C[7], 0u);
}`;

const DRAW_WGSL = `
struct U { vp: mat4x4<f32>, colour: vec4<f32>, light: vec4<f32>, vs: f32, w: f32, d: f32, top: f32 }
@group(0) @binding(0) var<uniform> u: U;
@group(0) @binding(1) var<storage, read> V: array<vec4<f32>>;
@group(0) @binding(2) var tex: texture_2d<f32>;
@group(0) @binding(3) var smp: sampler;
struct IsoOut { @builtin(position) pos: vec4<f32>, @location(0) n: vec3<f32> }
@vertex fn iso_v(@builtin(vertex_index) vid: u32) -> IsoOut {
  var p = V[2u * vid].xyz; p.z *= u.vs;
  var n = V[2u * vid + 1u].xyz; n.z /= max(u.vs, 1.0e-6);
  return IsoOut(u.vp * vec4<f32>(p, 1.0), normalize(n));
}
@fragment fn iso_f(o: IsoOut, @builtin(front_facing) front: bool) -> @location(0) vec4<f32> {
  var n = normalize(o.n);
  if (!front) { n = -n; }
  let d = max(dot(n, normalize(u.light.xyz)), 0.0);
  return vec4<f32>(u.colour.rgb * (0.30 + 0.70 * d), 1.0);
}
struct BoxOut { @builtin(position) pos: vec4<f32> }
@vertex fn box_v(@builtin(vertex_index) vid: u32) -> BoxOut {
  // 12 рёбер коробки области
  var e = array<vec2<u32>, 12>(vec2(0u,1u), vec2(1u,3u), vec2(3u,2u), vec2(2u,0u), vec2(4u,5u), vec2(5u,7u), vec2(7u,6u), vec2(6u,4u), vec2(0u,4u), vec2(1u,5u), vec2(2u,6u), vec2(3u,7u));
  let c = select(e[vid / 2u].x, e[vid / 2u].y, (vid & 1u) == 1u);
  let p = vec3<f32>(f32(c & 1u) * u.w, f32((c >> 1u) & 1u) * u.d, f32((c >> 2u) & 1u) * u.top * u.vs);
  return BoxOut(u.vp * vec4<f32>(p, 1.0));
}
@fragment fn box_f() -> @location(0) vec4<f32> { return vec4<f32>(0.45, 0.45, 0.5, 1.0); }
struct PlOut { @builtin(position) pos: vec4<f32>, @location(0) uv: vec2<f32> }
@vertex fn plane_v(@builtin(vertex_index) vid: u32) -> PlOut {
  var q = array<vec2<f32>, 6>(vec2(0.0,0.0), vec2(1.0,0.0), vec2(1.0,1.0), vec2(0.0,0.0), vec2(1.0,1.0), vec2(0.0,1.0));
  let t = q[vid];
  return PlOut(u.vp * vec4<f32>(t.x * u.w, t.y * u.d, 0.0, 1.0), vec2<f32>(t.x, 1.0 - t.y));
}
@fragment fn plane_f(o: PlOut) -> @location(0) vec4<f32> {
  let c = textureSample(tex, smp, o.uv);
  return vec4<f32>(mix(vec3<f32>(0.11, 0.13, 0.15), c.rgb, c.a), 1.0);
}`;

function mat4mul(a, b) {
  const o = new Float32Array(16);
  for (let c = 0; c < 4; c++) for (let r = 0; r < 4; r++) {
    let s = 0; for (let k = 0; k < 4; k++) s += a[k * 4 + r] * b[c * 4 + k]; o[c * 4 + r] = s;
  }
  return o;
}
const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const norm = a => { const l = Math.hypot(...a); return a.map(x => x / l); };
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

export class Volume {
  // geo: { X: буфер координат, ox, oy, ozh, ozf, Lx, Ly, top }, D: буфер ζ
  constructor(device, r, tape, grid, canvas, geo, D) {
    this.d = device; this.r = r; this.tape = tape; this.g = grid; this.canvas = canvas; this.geo = geo; this.D = D;
    this.ctx = canvas.getContext('webgpu');
    this.format = navigator.gpu.getPreferredCanvasFormat();
    this.ctx.configure({ device, format: this.format, alphaMode: 'opaque' });
    this.cam = { az: -0.6, el: 0.45, dist: 1.35 };
    this.free = [0, 0];
    this.vs = 2;
    this.on = new Set(['cloud', 'up10', 'dbz40']);
    this.surf = new Map();
    this.iso = {};        // переопределённые пороги (облако, торнадо)
    this.dirty = true;
  }

  // откуда брать поля: null - живая память модели, иначе { entries, fw } (снимок шкалы времени)
  setSource(src) { if (src === this.src) return; this.src = src; this.dropSurfaces(); this.dirty = true; }
  // поверхности строятся заново; старые буферы (вершины - 29 МБ на поверхность) - сразу освободить
  dropSurfaces() {
    for (const e of this.surf.values()) { e.verts.destroy(); e.cnt.destroy(); e.params.destroy(); e.uni.destroy(); }
    this.surf = new Map();
  }

  async init() {
    const d = this.d;
    const bmod = d.createShaderModule({ code: this.r.wgsl(BUILD_WGSL) });
    this.buildPipe = await d.createComputePipelineAsync({ layout: 'auto', compute: { module: bmod, entryPoint: 'build' } });
    this.finishPipe = await d.createComputePipelineAsync({ layout: 'auto', compute: { module: bmod, entryPoint: 'finish' } });
    const dmod = d.createShaderModule({ code: DRAW_WGSL });
    this.drawBGL = d.createBindGroupLayout({ entries: [
      { binding: 0, visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT, buffer: { type: 'uniform' } },
      { binding: 1, visibility: GPUShaderStage.VERTEX, buffer: { type: 'read-only-storage' } },
      { binding: 2, visibility: GPUShaderStage.FRAGMENT, texture: {} },
      { binding: 3, visibility: GPUShaderStage.FRAGMENT, sampler: {} }] });
    const layout = d.createPipelineLayout({ bindGroupLayouts: [this.drawBGL] });
    const depth = { format: 'depth32float', depthWriteEnabled: true, depthCompare: 'less' };
    const mk = (v, f, topology, cull) => d.createRenderPipelineAsync({ layout, vertex: { module: dmod, entryPoint: v },
      fragment: { module: dmod, entryPoint: f, targets: [{ format: this.format }] }, primitive: { topology, cullMode: cull }, depthStencil: depth });
    [this.isoPipe, this.boxPipe, this.planePipe] = await Promise.all([
      mk('iso_v', 'iso_f', 'triangle-list', 'none'), mk('box_v', 'box_f', 'line-list', 'none'), mk('plane_v', 'plane_f', 'triangle-list', 'none')]);
    this.tex = d.createTexture({ size: [PLANE, PLANE], format: 'rgba8unorm', usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST });
    this.sampler = d.createSampler({ magFilter: 'nearest', minFilter: 'nearest' });
    this.dummy = d.createBuffer({ size: 32, usage: GPUBufferUsage.STORAGE });
  }

  surface(s) {
    let e = this.surf.get(s.key);
    if (e) return e;
    const d = this.d;
    e = {
      verts: d.createBuffer({ size: CAP * 32, usage: GPUBufferUsage.STORAGE }),
      cnt: d.createBuffer({ size: 32, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.INDIRECT }),
      params: d.createBuffer({ size: 64, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST }),
      uni: d.createBuffer({ size: 128, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST }),
    };
    const t = this.tape, arena = t.buffers.find(b => b.arena).id;
    const fw = this.src ? this.src.fw : n => this.r.base[arena] + t.fields[n] / 4;
    const pi = new Int32Array(16), pf = new Float32Array(pi.buffer), pu = new Uint32Array(pi.buffer);
    pi.set([this.g.nx, this.g.ny, s.staggered ? this.g.nz + 1 : this.g.nz, this.g.sJ, this.g.sK]);
    if (!s.derived) { pu[5] = fw(s.field); pu[6] = s.second ? fw(s.second) : 0; pu[7] = s.second ? 1 : 0; }
    pf[8] = this.iso[s.key] ?? s.iso; pf[9] = s.sign || 1; pu[10] = s.derived ? 1 : 0;
    pu[11] = this.geo.ox; pu[12] = this.geo.oy; pu[13] = s.staggered ? this.geo.ozf : this.geo.ozh; pu[14] = CAP;
    e.p = pi;
    d.queue.writeBuffer(e.params, 0, pi);
    e.bind = d.createBindGroup({ layout: this.buildPipe.getBindGroupLayout(0), entries: [
      ...(this.src ? this.src.entries : this.r.memEntries(0)), { binding: 1, resource: { buffer: e.params } },
      { binding: 2, resource: { buffer: e.verts } }, { binding: 3, resource: { buffer: e.cnt } },
      { binding: 4, resource: { buffer: this.geo.X } }, { binding: 5, resource: { buffer: this.D } }] });
    e.finBind = d.createBindGroup({ layout: this.finishPipe.getBindGroupLayout(0), entries: [
      { binding: 1, resource: { buffer: e.params } }, { binding: 3, resource: { buffer: e.cnt } }] });
    e.drawBind = d.createBindGroup({ layout: this.drawBGL, entries: [
      { binding: 0, resource: { buffer: e.uni } }, { binding: 1, resource: { buffer: e.verts } },
      { binding: 2, resource: this.tex.createView() }, { binding: 3, resource: this.sampler }] });
    this.surf.set(s.key, e);
    return e;
  }

  setIso(key, v) {
    this.iso[key] = v;
    const e = this.surf.get(key);
    if (e) { new Float32Array(e.p.buffer)[8] = v; this.d.queue.writeBuffer(e.params, 0, e.p); }
  }

  get needsZeta() { return SURFACES.some(s => s.derived && this.on.has(s.key)); }

  // Перестроить включённые поверхности по текущему состоянию модели.
  encodeBuild(enc) {
    for (const s of SURFACES) {
      if (!this.on.has(s.key)) continue;
      const e = this.surface(s);
      enc.clearBuffer(e.cnt);
      const pass = enc.beginComputePass();
      pass.setPipeline(this.buildPipe); pass.setBindGroup(0, e.bind);
      pass.dispatchWorkgroups(Math.ceil(this.g.nx / 4), Math.ceil(this.g.ny / 4), Math.ceil((s.staggered ? this.g.nz + 1 : this.g.nz) / 4));
      pass.setPipeline(this.finishPipe); pass.setBindGroup(0, e.finBind); pass.dispatchWorkgroups(1);
      pass.end();
    }
  }

  setPlane(rgba) {
    this.d.queue.writeTexture({ texture: this.tex }, rgba, { bytesPerRow: PLANE * 4 }, [PLANE, PLANE]);
  }

  matrices(W, H) {
    const w = this.geo.Lx, dd = this.geo.Ly, top = this.geo.top;
    const ext = Math.max(w, dd);
    if (this.ground) return this.groundMatrices(W, H, w, dd, top, ext);
    const target = [w / 2, dd / 2, top * this.vs * 0.3];
    const dist = ext * 1.35 * this.cam.dist;
    const ce = Math.cos(this.cam.el);
    const fwd = norm([Math.sin(this.cam.az) * ce * -1, Math.cos(this.cam.az) * ce, -Math.sin(this.cam.el)]);
    const eye = target.map((x, i) => x - fwd[i] * dist);
    const right = norm(cross(fwd, [0, 0, 1]));
    const up = cross(right, fwd);
    const view = new Float32Array([right[0], up[0], -fwd[0], 0, right[1], up[1], -fwd[1], 0, right[2], up[2], -fwd[2], 0,
      -dot(right, eye), -dot(up, eye), dot(fwd, eye), 1]);
    // сцена вписывается в свободную часть экрана Wf×Hf: на узкой - по ширине
    const Wf = W * (1 - this.free[0]), Hf = H * (1 - this.free[1]);
    const f = Hf / H * Math.min(1, Wf / Hf) / Math.tan(0.5 * 0.85), near = dist * 0.02, far = dist * 4;
    // центр картинки - в середину свободной от панели части (this.free: доли экрана, занятые справа и снизу)
    const cx = -this.free[0], cy = this.free[1];
    const proj = new Float32Array([f * H / W, 0, 0, 0, 0, f, 0, 0, -cx, -cy, far / (near - far), -1, 0, 0, near * far / (near - far), 0]);
    const light = norm(right.map((x, i) => x * 0.4 + up[i] * 0.5 - fwd[i] * 0.75));
    return { vp: mat4mul(proj, view), light, w, dd, top };
  }

  // Вид с земли: глаз на высоте человека в точке ground {x, y} (м), взгляд -
  // ground.az (от севера по часовой), ground.el (над горизонтом)
  groundMatrices(W, H, w, dd, top, ext) {
    const g = this.ground, ce = Math.cos(g.el);
    const fwd = norm([Math.sin(g.az) * ce, Math.cos(g.az) * ce, Math.sin(g.el)]);
    const eye = [g.x, g.y, 2 * this.vs];
    const right = norm(cross(fwd, [0, 0, 1]));
    const up = cross(right, fwd);
    const view = new Float32Array([right[0], up[0], -fwd[0], 0, right[1], up[1], -fwd[1], 0, right[2], up[2], -fwd[2], 0,
      -dot(right, eye), -dot(up, eye), dot(fwd, eye), 1]);
    const Wf = W * (1 - this.free[0]), Hf = H * (1 - this.free[1]);
    const f = Hf / H * Math.min(1, Wf / Hf) / Math.tan(0.5 * 1.1), near = 1, far = ext * 4;
    const cx = -this.free[0], cy = this.free[1];
    const proj = new Float32Array([f * H / W, 0, 0, 0, 0, f, 0, 0, -cx, -cy, far / (near - far), -1, 0, 0, near * far / (near - far), 0]);
    const light = norm(right.map((x, i) => x * 0.4 + up[i] * 0.5 - fwd[i] * 0.75));
    return { vp: mat4mul(proj, view), light, w, dd, top };
  }

  draw() {
    const dpr = devicePixelRatio || 1;
    const W = Math.max(1, Math.floor(this.canvas.clientWidth * dpr)), H = Math.max(1, Math.floor(this.canvas.clientHeight * dpr));
    if (this.canvas.width !== W || this.canvas.height !== H) { this.canvas.width = W; this.canvas.height = H; }
    if (!this.depth || this.depth.width !== W || this.depth.height !== H)
      this.depth = this.d.createTexture({ size: [W, H], format: 'depth32float', usage: GPUTextureUsage.RENDER_ATTACHMENT });
    const m = this.matrices(W, H);
    const enc = this.d.createCommandEncoder();
    const pass = enc.beginRenderPass({
      colorAttachments: [{ view: this.ctx.getCurrentTexture().createView(), clearValue: { r: 0.051, g: 0.071, b: 0.086, a: 1 }, loadOp: 'clear', storeOp: 'store' }],
      depthStencilAttachment: { view: this.depth.createView(), depthClearValue: 1, depthLoadOp: 'clear', depthStoreOp: 'store' } });
    const uni = (e, colour) => {
      const u = new Float32Array(32);
      u.set(m.vp, 0); u.set([...colour, 1], 16); u.set([...m.light, 0], 20);
      u[24] = this.vs; u[25] = m.w; u[26] = m.dd; u[27] = m.top;
      this.d.queue.writeBuffer(e.uni, 0, u);
    };
    // подложка и рёбра - через первую поверхность (общий набор привязок)
    const any = this.surface(SURFACES.find(s => s.key === 'cloud'));
    uni(any, [1, 1, 1]);
    pass.setBindGroup(0, any.drawBind);
    pass.setPipeline(this.planePipe); pass.draw(6);
    pass.setPipeline(this.boxPipe); pass.draw(24);
    pass.setPipeline(this.isoPipe);
    for (const s of SURFACES) {
      if (!this.on.has(s.key)) continue;
      const e = this.surface(s);
      uni(e, s.colour);
      pass.setBindGroup(0, e.drawBind);
      pass.drawIndirect(e.cnt, 16);
    }
    pass.end();
    this.d.queue.submit([enc.finish()]);
  }
}
