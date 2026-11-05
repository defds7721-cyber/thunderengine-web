// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// rayleigh_avg: написано вручную (транслятор не переводит ulong). Источник -
// эталонное rayleigh_avg + sd_from_float/sd_add/sd_mul/sd_to_float:
// средние по горизонтали для irdamp=2 (get_avg_uvtq, testcase_simple_phys.F:221)
// в программном double с округлением к ближайшему чётному на каждом сложении,
// порядок сложения - цикл CM1 (j, затем i). 64-битное - пара u32 (x - младшее).
// TERRAIN подставляет tools/install_manual.py.

@group(0) @binding(0) var<storage, read_write> M: array<u32>;
@group(0) @binding(1) var<storage, read> ARG: array<u32>;
var<private> Z0: u32;
fn opq(x: f32) -> f32 { return bitcast<f32>(bitcast<u32>(x) | Z0); }
const TERRAIN: bool = true;

alias U64 = vec2<u32>;
fn add64(a: U64, b: U64) -> U64 { let lo = a.x + b.x; return U64(lo, a.y + b.y + select(0u, 1u, lo < a.x)); }
fn sub64(a: U64, b: U64) -> U64 { return U64(a.x - b.x, a.y - b.y - select(0u, 1u, a.x < b.x)); }
fn shl64(a: U64, n: u32) -> U64 {
  if (n == 0u) { return a; }
  if (n >= 64u) { return U64(0u, 0u); }
  if (n >= 32u) { return U64(0u, a.x << (n - 32u)); }
  return U64(a.x << n, (a.y << n) | (a.x >> (32u - n)));
}
fn shr64(a: U64, n: u32) -> U64 {
  if (n == 0u) { return a; }
  if (n >= 64u) { return U64(0u, 0u); }
  if (n >= 32u) { return U64(a.y >> (n - 32u), 0u); }
  return U64((a.x >> n) | (a.y << (32u - n)), a.y >> n);
}
fn gt64(a: U64, b: U64) -> bool { return a.y > b.y || (a.y == b.y && a.x > b.x); }
fn nz64(a: U64) -> bool { return (a.x | a.y) != 0u; }
fn clz64(a: U64) -> u32 { if (a.y != 0u) { return countLeadingZeros(a.y); } return 32u + countLeadingZeros(a.x); }
// 32x32 -> 64
fn mul32(x: u32, y: u32) -> U64 {
  let x0 = x & 0xffffu; let x1 = x >> 16u; let y0 = y & 0xffffu; let y1 = y >> 16u;
  let p00 = x0 * y0; let p01 = x0 * y1; let p10 = x1 * y0; let p11 = x1 * y1;
  let mid = p01 + p10; let midc = select(0u, 1u, mid < p01);
  let lo = p00 + (mid << 16u); let loc = select(0u, 1u, lo < p00);
  return U64(lo, p11 + (mid >> 16u) + (midc << 16u) + loc);
}

const MANT_HI: u32 = 0xfffffu;   // младшие 20 бит старшего слова - мантисса

fn sd_from_float(x: f32) -> U64 {
  let u = bitcast<u32>(x);
  let e8 = (u >> 23u) & 0xffu;
  let s = (u >> 31u) << 31u;
  if (e8 == 0u) { return U64(0u, s); }
  let m = u & 0x7fffffu;
  return U64((m & 7u) << 29u, s | ((e8 - 127u + 1023u) << 20u) | (m >> 3u));
}

fn mant(a: U64) -> U64 { return U64(a.x, (a.y & MANT_HI) | 0x100000u); }

fn sd_add(a0: U64, b0: U64) -> U64 {
  var a = a0; var b = b0;
  if (((a.y & 0x7fffffffu) | a.x) == 0u) { return b; }
  if (((b.y & 0x7fffffffu) | b.x) == 0u) { return a; }
  if (gt64(U64(b.x, b.y & 0x7fffffffu), U64(a.x, a.y & 0x7fffffffu))) { let t = a; a = b; b = t; }
  let ea = i32((a.y >> 20u) & 0x7ffu); let eb = i32((b.y >> 20u) & 0x7ffu);
  let ma = shl64(mant(a), 3u);
  var mb = shl64(mant(b), 3u);
  let d = ea - eb;
  if (d > 0) {
    if (d >= 58) { mb = U64(1u, 0u); }
    else {
      let lost = nz64(shl64(mb, u32(64 - d)));
      mb = shr64(mb, u32(d));
      if (lost) { mb.x = mb.x | 1u; }
    }
  }
  let sign = a.y & 0x80000000u;
  var m: U64; var e = ea;
  if (((a.y ^ b.y) >> 31u) == 0u) {
    m = add64(ma, mb);
    if ((m.y >> 24u) != 0u) { let low = m.x & 1u; m = shr64(m, 1u); m.x = m.x | low; e += 1; }
  } else {
    m = sub64(ma, mb);
    if (!nz64(m)) { return U64(0u, 0u); }
    let sh = clz64(m) - 8u;
    m = shl64(m, sh); e -= i32(sh);
  }
  let g = m.x & 7u; m = shr64(m, 3u);
  if (g > 4u || (g == 4u && (m.x & 1u) != 0u)) { m = add64(m, U64(1u, 0u)); }
  if ((m.y >> 21u) != 0u) { m = shr64(m, 1u); e += 1; }
  if (e <= 0) { return U64(0u, sign); }
  return U64(m.x, sign | (u32(e) << 20u) | (m.y & MANT_HI));
}

fn sd_mul(a: U64, b: U64) -> U64 {
  let sign = (a.y ^ b.y) & 0x80000000u;
  if (((a.y & 0x7fffffffu) | a.x) == 0u || ((b.y & 0x7fffffffu) | b.x) == 0u) { return U64(0u, sign); }
  var e = i32((a.y >> 20u) & 0x7ffu) + i32((b.y >> 20u) & 0x7ffu) - 1023;
  let ma = mant(a); let mb = mant(b);
  // 128-битное произведение: r0..r3
  let p00 = mul32(ma.x, mb.x); let p01 = mul32(ma.x, mb.y); let p10 = mul32(ma.y, mb.x); let p11 = mul32(ma.y, mb.y);
  var midA = add64(U64(p00.y, 0u), U64(p01.x, 0u));
  midA = add64(midA, U64(p10.x, 0u));          // разряд 32..63 и перенос
  let r1 = midA.x;
  var hiS = add64(p11, U64(p01.y, 0u));
  hiS = add64(hiS, U64(p10.y, 0u));
  hiS = add64(hiS, U64(midA.y, 0u));
  let lo = U64(p00.x, r1);
  let hi = hiS;
  var sh = 52u;
  if ((hi.y >> 9u) != 0u) { sh = 53u; e += 1; }
  var m = U64(0u, 0u);
  m = shl64(hi, 64u - sh);
  let lsh = shr64(lo, sh);
  m = U64(m.x | lsh.x, m.y | lsh.y);
  let maskR = sub64(shl64(U64(1u, 0u), sh), U64(1u, 0u));
  let rem = U64(lo.x & maskR.x, lo.y & maskR.y);
  let mid = shl64(U64(1u, 0u), sh - 1u);
  if (gt64(rem, mid) || (rem.x == mid.x && rem.y == mid.y && (m.x & 1u) != 0u)) { m = add64(m, U64(1u, 0u)); }
  if ((m.y >> 21u) != 0u) { m = shr64(m, 1u); e += 1; }
  return U64(m.x, sign | (u32(e) << 20u) | (m.y & MANT_HI));
}

fn sd_to_float(a: U64) -> f32 {
  let s = (a.y >> 31u) << 31u;
  let e = i32((a.y >> 20u) & 0x7ffu);
  if (e == 0) { return bitcast<f32>(s); }
  let m = mant(a);
  let rem = m.x & 0x1fffffffu; let mid = 0x10000000u;
  var r = (m.x >> 29u) | (m.y << 3u);
  if (rem > mid || (rem == mid && (r & 1u) != 0u)) { r += 1u; }
  var e8 = e - 1023 + 127;
  if ((r >> 24u) != 0u) { r = r >> 1u; e8 += 1; }
  return bitcast<f32>(s | (u32(e8) << 23u) | (r & 0x7fffffu));
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

// параметры: 0 GridDims, 1 u, 2 v, 3 th, 4 th0, 5 tem (float), 6 temd (биты double), 7 avg
@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
  if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
  Z0 = ARG[3];
  let g = ARG[4];
  let nx = bitcast<i32>(M[g]); let ny = bitcast<i32>(M[g + 1u]); let nz = bitcast<i32>(M[g + 2u]);
  let sJ = bitcast<i32>(M[g + 3u]); let sK = bitcast<i32>(M[g + 4u]);
  let pu = ARG[5]; let pv = ARG[6]; let pth = ARG[7]; let pth0 = ARG[8];
  let tem = bitcast<f32>(M[ARG[9]]);
  let temd = U64(M[ARG[10]], M[ARG[10] + 1u]);
  let pavg = ARG[11];
  let t = i32(gid.x);
  let f = t / nz; let k = t % nz;
  if (f > 2) { return; }
  var sum = U64(0u, 0u);
  for (var j = 0; j < ny; j++) {
    for (var i = 0; i < nx; i++) {
      let c = u32((i + 3) + sJ * ((j + 3) + sK * k));
      var x: f32;
      if (f == 0) { x = opq(bitcast<f32>(M[pu + c]) * tem); }
      else if (f == 1) { x = opq(bitcast<f32>(M[pv + c]) * tem); }
      else {
        let b = bitcast<f32>(M[pth0 + select(u32(k), c, TERRAIN)]);
        x = opq(opq(b + bitcast<f32>(M[pth + c])) * tem);
      }
      sum = sd_add(sum, sd_from_float(x));
    }
  }
  M[pavg + u32(f * nz + k)] = bitcast<u32>(sd_to_float(sd_mul(sum, temd)));
}
