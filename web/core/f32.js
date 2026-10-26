// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Арифметика Float (IEEE binary32) на числах JS.
//
// Правило: КАЖДАЯ операция над Float обёрнута в f()
// (Math.fround) здесь: f(a + b), f(a * b), f(a / b). Double - обычные числа
// JS, без обёртки. Float(x) -> f(x), Double(float) -> как есть.
// Нарушение правила даёт не «почти то же», а другие биты начального
// состояния, и сверка с эталоном их ловит (web/test/core.html).

export const f = Math.fround;

const F = new Float32Array(1), U = new Uint32Array(F.buffer);
function nextUp(x) {   // соседний float вверх (x - конечный float)
  if (x === 0) return 1.401298464324817e-45;
  F[0] = x; U[0] += x > 0 ? 1 : -1; return F[0];
}
function nextDown(x) {
  if (x === 0) return -1.401298464324817e-45;
  F[0] = x; U[0] += x > 0 ? -1 : 1; return F[0];
}

// fmaf(a, b, c) с одним округлением. a*b двух float точно в double (48 бит);
// сумма с c округляется в double, и это округление может попасть ровно в
// середину между соседними float - тогда направление решает знак ошибки
// суммы (TwoSum). Перескочить середину округление в double не может:
// середины float представимы в double.
export function fmaf(a, b, c) {
  const p = a * b, s = p + c;
  const r = f(s);
  if (r === s || !isFinite(s)) return r;
  const bb = s - p, err = (p - (s - bb)) + (c - bb);
  if (err === 0) return r;
  const other = r > s ? nextDown(r) : nextUp(r);
  if (Math.abs(s - r) !== Math.abs(other - s)) return r;   // не середина
  // середина: истинное значение s + err - по ту сторону, куда err
  const up = err > 0;
  return up ? Math.max(r, other) : Math.min(r, other);
}

// Функции libm для float. эталонная libm округляет их НЕ правильно (cosf/sinf - 1,3 %
// аргументов на 1 ulp, powf/expf - 0,6 %), поэтому powf, expf, logf, sinf,
// cosf, tanhf - копии алгоритмов эталонной libm (libm.js, сверены на 1,8 млн
// аргументов). sqrt округляется правильно везде; atan2f пока через double.
export { powf, expf, logf, cosf, sinf, tanhf, asinf, atanf } from './libm.js';
export const sqrtf = x => f(Math.sqrt(x));
export const atan2f = (y, x) => f(Math.atan2(y, x));

// Float(Int)/Int(Float): усечение к нулю
export const trunc = Math.trunc;

// Байты структур для setBytes: раскладка C (выравнивание по типу;
// SIMD2<Float> - 8, SIMD3/SIMD4<Float> - 16 байт, stride кратен
// наибольшему выравниванию). Пример:
//   new Bytes().f32(a).i32(n).align(16).f32x4(v).end()
export class Bytes {
  constructor() { this.dv = new DataView(new ArrayBuffer(256)); this.n = 0; this.maxAlign = 1; }
  grow(k) {
    if (this.n + k <= this.dv.byteLength) return;
    const b = new ArrayBuffer(Math.max(this.dv.byteLength * 2, this.n + k));
    new Uint8Array(b).set(new Uint8Array(this.dv.buffer)); this.dv = new DataView(b);
  }
  align(a) { this.maxAlign = Math.max(this.maxAlign, a); while (this.n % a) { this.grow(1); this.dv.setUint8(this.n++, 0); } return this; }
  f32(v) { this.align(4); this.grow(4); this.dv.setFloat32(this.n, v, true); this.n += 4; return this; }
  i32(v) { this.align(4); this.grow(4); this.dv.setInt32(this.n, v, true); this.n += 4; return this; }
  u32(v) { this.align(4); this.grow(4); this.dv.setUint32(this.n, v >>> 0, true); this.n += 4; return this; }
  bool(v) { this.grow(1); this.dv.setUint8(this.n++, v ? 1 : 0); return this; }
  u8(v) { this.grow(1); this.dv.setUint8(this.n++, v); return this; }
  f32x2(v) { this.align(8); this.f32(v[0]); this.f32(v[1]); return this; }
  i32x2(v) { this.align(8); this.i32(v[0]); this.i32(v[1]); return this; }
  f32x3(v) { this.align(16); this.f32(v[0]); this.f32(v[1]); this.f32(v[2]); this.f32(0); return this; }   // SIMD3: 16 байт
  f32x4(v) { this.align(16); for (let i = 0; i < 4; i++) this.f32(v[i]); return this; }
  i32x4(v) { this.align(16); for (let i = 0; i < 4; i++) this.i32(v[i]); return this; }
  // конец структуры: размер до кратного выравниванию (MemoryLayout.stride)
  end() { this.align(this.maxAlign); return new Uint8Array(this.dv.buffer.slice(0, this.n)); }
}
