// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// turb_km_kh: сгенерировано, не править руками.

@group(0) @binding(0) var<storage, read_write> M: array<u32>;
@group(0) @binding(1) var<storage, read> ARG: array<u32>;
fn mem_ld(o: u32) -> u32 { return M[o]; }
fn mem_st(o: u32, v: u32) { M[o] = v; }


var<private> Z0: u32;
var<private> SCRB: u32;
// opq: та же величина, но компилятор не видит, что Z0 = 0, и не сворачивает через неё.
// Именно ИЛИ, а не xor: opq(opq(x)) с xor компилятор сокращал до x (x^z^z = x) и
// переставлял слагаемые (turb_def_centers, 2026-10-17); x|z|z = x|z - барьер остаётся.
fn opq(x: f32) -> f32 { return bitcast<f32>(bitcast<u32>(x) | Z0); }
fn opq2(x: vec2<f32>) -> vec2<f32> { return bitcast<vec2<f32>>(bitcast<vec2<u32>>(x) | vec2<u32>(Z0)); }
fn opq3(x: vec3<f32>) -> vec3<f32> { return bitcast<vec3<f32>>(bitcast<vec3<u32>>(x) | vec3<u32>(Z0)); }
fn opq4(x: vec4<f32>) -> vec4<f32> { return bitcast<vec4<f32>>(bitcast<vec4<u32>>(x) | vec4<u32>(Z0)); }
fn nego(x: f32) -> f32 { return bitcast<f32>(bitcast<u32>(x) ^ (0x80000000u ^ Z0)); }
// Частное с корректным округлением (probe/ops: 0 промахов на 2 млн).
// Остаток fma(-q, b, a) - порядка ulp(a); при |a| < 2^-60 он ушёл бы ниже
// FLT_MIN и обнулился (GPU сбрасывает субнормальные), поправка молча не
// сработала бы. Поэтому малый числитель масштабируется на 2^64 - точно.
fn div_core(a: f32, b: f32) -> f32 {
    var q = opq(a / b);
    if (q == 0.0f || abs(q) > 3.0e38f || q != q || abs(q) < 1.0e-37f) { return q; }
    var r = abs(fma(nego(q), b, a));
    for (var k = 0; k < 4; k++) {
        let qu = bitcast<f32>(bitcast<u32>(q) + 1u);
        let qd = bitcast<f32>(bitcast<u32>(q) - 1u);
        let ru = abs(fma(nego(qu), b, a));
        let rd = abs(fma(nego(qd), b, a));
        if (ru < r) { q = qu; r = ru; } else if (rd < r) { q = qd; r = rd; } else { break; }
    }
    return q;
}
fn div_cr(a: f32, b: f32) -> f32 {
    if (abs(a) < 8.67361738e-19f && a != 0.0f) {
        let q = div_core(opq(a * 1.8446744e19f), b);
        return opq(q * 5.42101086e-20f);
    }
    return div_core(a, b);
}
// Корень с корректным округлением (probe/ops: 0 промахов). Малый аргумент -
// масштабом 2^64 (корень - 2^32), по той же причине, что у div_cr.
fn sqrt_core(x: f32) -> f32 {
    var s = opq(sqrt(x));
    if (!(x > 1.0e-30f) || x > 3.0e38f) { return s; }
    for (var k = 0; k < 4; k++) {
        let r = fma(nego(s), s, x);
        let su = bitcast<f32>(bitcast<u32>(s) + 1u);
        let sd = bitcast<f32>(bitcast<u32>(s) - 1u);
        if (r > s * opq(su - s)) { s = su; }
        else if (r <= nego(s * opq(s - sd))) { s = sd; }
        else { break; }
    }
    return s;
}
fn sqrt_cr(x: f32) -> f32 {
    if (x < 8.67361738e-19f && x > 0.0f) {
        return opq(sqrt_core(opq(x * 1.8446744e19f)) * 2.32830644e-10f);
    }
    return sqrt_core(x);
}


struct S_GridDims {
    nx: i32,
    ny: i32,
    nz: i32,
    strideJ: i32,
    strideK: i32,
    rdx: f32,
    rdy: f32,
    rdz: f32,
}

fn ld_GridDims(o: u32) -> S_GridDims {
    var s: S_GridDims;
    s.nx = bitcast<i32>(mem_ld((o + 0u)));
    s.ny = bitcast<i32>(mem_ld((o + 1u)));
    s.nz = bitcast<i32>(mem_ld((o + 2u)));
    s.strideJ = bitcast<i32>(mem_ld((o + 3u)));
    s.strideK = bitcast<i32>(mem_ld((o + 4u)));
    s.rdx = bitcast<f32>(mem_ld((o + 5u)));
    s.rdy = bitcast<f32>(mem_ld((o + 6u)));
    s.rdz = bitcast<f32>(mem_ld((o + 7u)));
    return s;
}

fn f_gidx(g_in: S_GridDims, i_in: i32, j_in: i32, k_in: i32) -> i32 {
    var g: S_GridDims = g_in;
    var i: i32 = i_in;
    var j: i32 = j_in;
    var k: i32 = k_in;
    return ((i + 3i) + (g.strideJ * ((j + 3i) + (g.strideK * k))));
}

fn f_hm_uh(g_in: S_GridDims, hm_in: u32, i_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var hm: u32 = hm_in;
    var i: i32 = i_in;
    return bitcast<f32>(mem_ld((hm + bitcast<u32>((i + 3i)))));
}

fn f_hm_vh(g_in: S_GridDims, hm_in: u32, j_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var hm: u32 = hm_in;
    var j: i32 = j_in;
    return bitcast<f32>(mem_ld((hm + bitcast<u32>((((2i * g.strideJ) + j) + 3i)))));
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    var g: S_GridDims = ld_GridDims(ARG[4]);
    var tkea: u32 = ARG[5];
    var nm: u32 = ARG[6];
    var mf: u32 = ARG[7];
    var kmh: u32 = ARG[8];
    var kmv: u32 = ARG[9];
    var khh: u32 = ARG[10];
    var khv: u32 = ARG[11];
    var lenscl: u32 = ARG[12];
    var dissten: u32 = ARG[13];
    var kmScale: f32 = bitcast<f32>(mem_ld(ARG[14]));
    var kmFixed: f32 = bitcast<f32>(mem_ld(ARG[15]));
    var turbfac: f32 = bitcast<f32>(mem_ld(ARG[16]));
    var hm: u32 = ARG[34];
    var tid: vec3<u32> = gid;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    var k: i32 = ((i32(tid.z)) + 1i);
    if ((((i >= g.nx) || (j >= g.ny)) || (k > (g.nz - 1i)))) {
        return;
    }
    var c: i32 = f_gidx(g, i, j, k);
    var c_m: f32 = 0.1f;
    var c_l: f32 = 0.8165f;
    var ri_c: f32 = 0.25f;
    var tke_min: f32 = 1e-10f;
    var nm_min: f32 = 1e-06f;
    var small_len_frac: f32 = 0.001f;
    var cmz: f32 = opq(max(0.001f, opq((opq(turbfac)) * (opq(c_m)))));
    var ce1z: f32 = opq((opq((opq((opq(cmz)) * (opq(c_l)))) * (opq(c_l)))) * (opq((opq(div_cr(1.0f, ri_c))) - (opq(1.0f)))));
    var ce2z: f32 = opq(max(0.0f, opq(fma(opq((opq(cmz)) * (opq(3.1415927f))), opq(3.1415927f), opq((-(opq(ce1z))))))));
    var dzk: f32 = div_cr((div_cr(1.0f, g.rdz)), bitcast<f32>(mem_ld((mf + bitcast<u32>(c)))));
    var grdscl: f32 = opq(pow(opq((opq((opq((div_cr((div_cr(1.0f, g.rdx)), f_hm_uh(g, hm, i))))) * (opq((div_cr((div_cr(1.0f, g.rdy)), f_hm_vh(g, hm, j))))))) * (opq(dzk))), 0.33333334f));
    var rgrdscl: f32 = div_cr(1.0f, grdscl);
    var tk: f32;
    var len: f32;
    if (((bitcast<f32>(mem_ld((tkea + bitcast<u32>(c))))) <= tke_min)) {
        tk = tke_min;
        len = opq((opq(small_len_frac)) * (opq(grdscl)));
    } else {
        tk = bitcast<f32>(mem_ld((tkea + bitcast<u32>(c))));
        len = grdscl;
        if (((bitcast<f32>(mem_ld((nm + bitcast<u32>(c))))) > nm_min)) {
            len = opq((opq(c_l)) * (opq(sqrt_cr(div_cr(tk, bitcast<f32>(mem_ld((nm + bitcast<u32>(c)))))))));
            len = opq(min(len, grdscl));
            len = opq(max(len, opq((opq(small_len_frac)) * (opq(grdscl)))));
        }
    }
    mem_st((lenscl + bitcast<u32>(c)), bitcast<u32>(len));
    mem_st((dissten + bitcast<u32>(c)), bitcast<u32>(opq((bitcast<f32>(mem_ld((dissten + bitcast<u32>(c))))) + (opq(div_cr(opq((opq((opq(fma(opq((opq(ce2z)) * (opq(len))), opq(rgrdscl), opq(ce1z)))) * (opq(tk)))) * (opq(sqrt_cr(tk)))), len))))));
    var km: f32 = select((opq((opq((opq((opq(cmz)) * (opq(sqrt_cr(tk))))) * (opq(len)))) * (opq(kmScale)))), kmFixed, (kmFixed > 0.0f));
    mem_st((kmh + bitcast<u32>(c)), bitcast<u32>(km));
    mem_st((kmv + bitcast<u32>(c)), bitcast<u32>(km));
    var prinv: f32 = 3.0f;
    if (((bitcast<f32>(mem_ld((nm + bitcast<u32>(c))))) > nm_min)) {
        prinv = opq(min(opq(fma(opq((opq(2.0f)) * (opq(len))), opq(rgrdscl), opq(1.0f))), 3.0f));
    }
    mem_st((khh + bitcast<u32>(c)), bitcast<u32>(opq((opq(km)) * (opq(prinv)))));
    mem_st((khv + bitcast<u32>(c)), bitcast<u32>(bitcast<f32>(mem_ld((khh + bitcast<u32>(c))))));
}
