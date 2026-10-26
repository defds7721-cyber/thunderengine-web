// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// acoustic_fpk: сгенерировано, не править руками.

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

struct S_AcousticParams {
    dts: f32,
    alph: f32,
    beta: f32,
    kdiv: f32,
    smeps: f32,
}

struct S_TerrainParams {
    zt: f32,
    rzt: f32,
    cgs1: f32,
    cgs2: f32,
    cgs3: f32,
    cgt1: f32,
    cgt2: f32,
    cgt3: f32,
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

fn ld_AcousticParams(o: u32) -> S_AcousticParams {
    var s: S_AcousticParams;
    s.dts = bitcast<f32>(mem_ld((o + 0u)));
    s.alph = bitcast<f32>(mem_ld((o + 1u)));
    s.beta = bitcast<f32>(mem_ld((o + 2u)));
    s.kdiv = bitcast<f32>(mem_ld((o + 3u)));
    s.smeps = bitcast<f32>(mem_ld((o + 4u)));
    return s;
}

fn ld_TerrainParams(o: u32) -> S_TerrainParams {
    var s: S_TerrainParams;
    s.zt = bitcast<f32>(mem_ld((o + 0u)));
    s.rzt = bitcast<f32>(mem_ld((o + 1u)));
    s.cgs1 = bitcast<f32>(mem_ld((o + 2u)));
    s.cgs2 = bitcast<f32>(mem_ld((o + 3u)));
    s.cgs3 = bitcast<f32>(mem_ld((o + 4u)));
    s.cgt1 = bitcast<f32>(mem_ld((o + 5u)));
    s.cgt2 = bitcast<f32>(mem_ld((o + 6u)));
    s.cgt3 = bitcast<f32>(mem_ld((o + 7u)));
    return s;
}

fn f_gidx(g_in: S_GridDims, i_in: i32, j_in: i32, k_in: i32) -> i32 {
    var g: S_GridDims = g_in;
    var i: i32 = i_in;
    var j: i32 = j_in;
    var k: i32 = k_in;
    return ((i + 3i) + (g.strideJ * ((j + 3i) + (g.strideK * k))));
}

fn f_tplane(g_in: S_GridDims, tpl_in: u32, n_in: i32, i_in: i32, j_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var tpl: u32 = tpl_in;
    var n: i32 = n_in;
    var i: i32 = i_in;
    var j: i32 = j_in;
    let _t1 = (((n * g.strideJ) * g.strideK) + (f_gidx(g, i, j, 0i)));
    return bitcast<f32>(mem_ld((tpl + bitcast<u32>(_t1))));
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

fn lam_1(ii_in: i32, kk_in: i32, u3d: u32, g: ptr<function, S_GridDims>, j: ptr<function, i32>, tpl: u32) -> f32 {
    var ii: i32 = ii_in;
    var kk: i32 = kk_in;
    let _t1 = f_gidx((*g), ii, (*j), kk);
    return opq((bitcast<f32>(mem_ld((u3d + bitcast<u32>(_t1))))) * (opq(f_tplane((*g), tpl, 3i, ii, (*j)))));
}

fn lam_2(jj_in: i32, kk_in: i32, v3d: u32, g: ptr<function, S_GridDims>, i: ptr<function, i32>, tpl: u32) -> f32 {
    var jj: i32 = jj_in;
    var kk: i32 = kk_in;
    let _t1 = f_gidx((*g), (*i), jj, kk);
    return opq((bitcast<f32>(mem_ld((v3d + bitcast<u32>(_t1))))) * (opq(f_tplane((*g), tpl, 5i, (*i), jj))));
}

fn lam_3(kf_in: i32, g: ptr<function, S_GridDims>, tz: u32, u3d: u32, j: ptr<function, i32>, tpl: u32, i: ptr<function, i32>, dzdx: ptr<function, f32>, v3d: u32, dzdy: ptr<function, f32>, tp: ptr<function, S_TerrainParams>, gz: ptr<function, f32>) -> f32 {
    var kf: i32 = kf_in;
    if (((kf <= 0i) || (kf >= ((*g).nz)))) {
        return 0.0f;
    }
    var r2: f32 = f_terr_r2((*g), tz, kf);
    var r1: f32 = opq((opq(1.0f)) - (opq(r2)));
    return opq((opq((opq((opq((opq(0.5f)) * (opq(fma((opq(fma(opq(r2), (opq((opq(lam_4((*i), kf, u3d, g, j, tpl))) + (opq(lam_4(((*i) + 1i), kf, u3d, g, j, tpl))))), opq((opq(r1)) * (opq((opq(lam_4((*i), (kf - 1i), u3d, g, j, tpl))) + (opq(lam_4(((*i) + 1i), (kf - 1i), u3d, g, j, tpl))))))))), opq((*dzdx)), opq((opq(fma(opq(r2), (opq((opq(lam_5((*j), kf, v3d, g, i, tpl))) + (opq(lam_5(((*j) + 1i), kf, v3d, g, i, tpl))))), opq((opq(r1)) * (opq((opq(lam_5((*j), (kf - 1i), v3d, g, i, tpl))) + (opq(lam_5(((*j) + 1i), (kf - 1i), v3d, g, i, tpl))))))))) * (opq((*dzdy))))))))) * (opq((opq(f_tsig((*g), tz, 3i, kf))) - (opq((*tp).zt)))))) * (opq((*gz))))) * (opq((*tp).rzt)));
}

fn f_terr_r2(g_in: S_GridDims, tz_in: u32, k_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var tz: u32 = tz_in;
    var k: i32 = k_in;
    return opq((opq((opq(f_tsig(g, tz, 3i, k))) - (opq(f_tsig(g, tz, 2i, (k - 1i)))))) * (opq(f_tsig(g, tz, 0i, k))));
}

fn f_tsig(g_in: S_GridDims, tz_in: u32, which_in: i32, k_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var tz: u32 = tz_in;
    var which: i32 = which_in;
    var k: i32 = k_in;
    return bitcast<f32>(mem_ld((tz + bitcast<u32>(((which * (g.nz + 1i)) + k)))));
}

fn lam_4(ii_in: i32, kk_in: i32, u3d: u32, g: ptr<function, S_GridDims>, j: ptr<function, i32>, tpl: u32) -> f32 {
    var ii: i32 = ii_in;
    var kk: i32 = kk_in;
    let _t1 = f_gidx((*g), ii, (*j), kk);
    return opq((bitcast<f32>(mem_ld((u3d + bitcast<u32>(_t1))))) * (opq(f_tplane((*g), tpl, 3i, ii, (*j)))));
}

fn lam_5(jj_in: i32, kk_in: i32, v3d: u32, g: ptr<function, S_GridDims>, i: ptr<function, i32>, tpl: u32) -> f32 {
    var jj: i32 = jj_in;
    var kk: i32 = kk_in;
    let _t1 = f_gidx((*g), (*i), jj, kk);
    return opq((bitcast<f32>(mem_ld((v3d + bitcast<u32>(_t1))))) * (opq(f_tplane((*g), tpl, 5i, (*i), jj))));
}

fn lam_6(ii_in: i32, kk_in: i32, g: ptr<function, S_GridDims>, j: ptr<function, i32>, rho0: u32, u3d: u32, tpl: u32) -> f32 {
    var ii: i32 = ii_in;
    var kk: i32 = kk_in;
    var cc: i32 = f_gidx((*g), ii, (*j), kk);
    return opq((opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((rho0 + bitcast<u32>((cc - 1i)))))) + (bitcast<f32>(mem_ld((rho0 + bitcast<u32>(cc))))))))) * (opq(lam_7(ii, kk, u3d, g, j, tpl))));
}

fn lam_7(ii_in: i32, kk_in: i32, u3d: u32, g: ptr<function, S_GridDims>, j: ptr<function, i32>, tpl: u32) -> f32 {
    var ii: i32 = ii_in;
    var kk: i32 = kk_in;
    let _t1 = f_gidx((*g), ii, (*j), kk);
    return opq((bitcast<f32>(mem_ld((u3d + bitcast<u32>(_t1))))) * (opq(f_tplane((*g), tpl, 3i, ii, (*j)))));
}

fn lam_8(jj_in: i32, kk_in: i32, g: ptr<function, S_GridDims>, i: ptr<function, i32>, rho0: u32, sj: ptr<function, i32>, v3d: u32, tpl: u32) -> f32 {
    var jj: i32 = jj_in;
    var kk: i32 = kk_in;
    var cc: i32 = f_gidx((*g), (*i), jj, kk);
    return opq((opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((rho0 + bitcast<u32>((cc - (*sj))))))) + (bitcast<f32>(mem_ld((rho0 + bitcast<u32>(cc))))))))) * (opq(lam_9(jj, kk, v3d, g, i, tpl))));
}

fn lam_9(jj_in: i32, kk_in: i32, v3d: u32, g: ptr<function, S_GridDims>, i: ptr<function, i32>, tpl: u32) -> f32 {
    var jj: i32 = jj_in;
    var kk: i32 = kk_in;
    let _t1 = f_gidx((*g), (*i), jj, kk);
    return opq((bitcast<f32>(mem_ld((v3d + bitcast<u32>(_t1))))) * (opq(f_tplane((*g), tpl, 5i, (*i), jj))));
}

fn lam_10(kf_in: i32, g: ptr<function, S_GridDims>, tz: u32, i: ptr<function, i32>, j: ptr<function, i32>, rho0: u32, u3d: u32, tpl: u32, dzdx: ptr<function, f32>, sj: ptr<function, i32>, v3d: u32, dzdy: ptr<function, f32>, tp: ptr<function, S_TerrainParams>, gz: ptr<function, f32>, rf0: u32) -> f32 {
    var kf: i32 = kf_in;
    if (((kf <= 0i) || (kf >= ((*g).nz)))) {
        return 0.0f;
    }
    var r2: f32 = f_terr_r2((*g), tz, kf);
    var r1: f32 = opq((opq(1.0f)) - (opq(r2)));
    var cf: i32 = f_gidx((*g), (*i), (*j), kf);
    return opq((opq((opq((opq((opq((opq(0.5f)) * (opq(fma((opq(fma(opq(r2), (opq((opq(lam_11((*i), kf, g, j, rho0, u3d, tpl))) + (opq(lam_11(((*i) + 1i), kf, g, j, rho0, u3d, tpl))))), opq((opq(r1)) * (opq((opq(lam_11((*i), (kf - 1i), g, j, rho0, u3d, tpl))) + (opq(lam_11(((*i) + 1i), (kf - 1i), g, j, rho0, u3d, tpl))))))))), opq((*dzdx)), opq((opq(fma(opq(r2), (opq((opq(lam_13((*j), kf, g, i, rho0, sj, v3d, tpl))) + (opq(lam_13(((*j) + 1i), kf, g, i, rho0, sj, v3d, tpl))))), opq((opq(r1)) * (opq((opq(lam_13((*j), (kf - 1i), g, i, rho0, sj, v3d, tpl))) + (opq(lam_13(((*j) + 1i), (kf - 1i), g, i, rho0, sj, v3d, tpl))))))))) * (opq((*dzdy))))))))) * (opq((opq(f_tsig((*g), tz, 3i, kf))) - (opq((*tp).zt)))))) * (opq((*gz))))) * (opq((*tp).rzt)))) * (opq((div_cr(1.0f, bitcast<f32>(mem_ld((rf0 + bitcast<u32>(cf)))))))));
}

fn lam_11(ii_in: i32, kk_in: i32, g: ptr<function, S_GridDims>, j: ptr<function, i32>, rho0: u32, u3d: u32, tpl: u32) -> f32 {
    var ii: i32 = ii_in;
    var kk: i32 = kk_in;
    var cc: i32 = f_gidx((*g), ii, (*j), kk);
    return opq((opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((rho0 + bitcast<u32>((cc - 1i)))))) + (bitcast<f32>(mem_ld((rho0 + bitcast<u32>(cc))))))))) * (opq(lam_12(ii, kk, u3d, g, j, tpl))));
}

fn lam_12(ii_in: i32, kk_in: i32, u3d: u32, g: ptr<function, S_GridDims>, j: ptr<function, i32>, tpl: u32) -> f32 {
    var ii: i32 = ii_in;
    var kk: i32 = kk_in;
    let _t1 = f_gidx((*g), ii, (*j), kk);
    return opq((bitcast<f32>(mem_ld((u3d + bitcast<u32>(_t1))))) * (opq(f_tplane((*g), tpl, 3i, ii, (*j)))));
}

fn lam_13(jj_in: i32, kk_in: i32, g: ptr<function, S_GridDims>, i: ptr<function, i32>, rho0: u32, sj: ptr<function, i32>, v3d: u32, tpl: u32) -> f32 {
    var jj: i32 = jj_in;
    var kk: i32 = kk_in;
    var cc: i32 = f_gidx((*g), (*i), jj, kk);
    return opq((opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((rho0 + bitcast<u32>((cc - (*sj))))))) + (bitcast<f32>(mem_ld((rho0 + bitcast<u32>(cc))))))))) * (opq(lam_14(jj, kk, v3d, g, i, tpl))));
}

fn lam_14(jj_in: i32, kk_in: i32, v3d: u32, g: ptr<function, S_GridDims>, i: ptr<function, i32>, tpl: u32) -> f32 {
    var jj: i32 = jj_in;
    var kk: i32 = kk_in;
    let _t1 = f_gidx((*g), (*i), jj, kk);
    return opq((bitcast<f32>(mem_ld((v3d + bitcast<u32>(_t1))))) * (opq(f_tplane((*g), tpl, 5i, (*i), jj))));
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    var g: S_GridDims = ld_GridDims(ARG[4]);
    var a: S_AcousticParams = ld_AcousticParams(ARG[5]);
    var u3d: u32 = ARG[6];
    var v3d: u32 = ARG[7];
    var w3d: u32 = ARG[8];
    var piadv: u32 = ARG[9];
    var ppten: u32 = ARG[10];
    var ppterm: u32 = ARG[11];
    var pk1: u32 = ARG[12];
    var pk2: u32 = ARG[13];
    var qk: u32 = ARG[14];
    var fpk: u32 = ARG[15];
    var hm: u32 = ARG[34];
    var rho0: u32 = ARG[19];
    var rr0: u32 = ARG[20];
    var rf0: u32 = ARG[21];
    var tpl: u32 = ARG[28];
    var tz: u32 = ARG[29];
    var tp: S_TerrainParams = ld_TerrainParams(ARG[30]);
    var tid: vec3<u32> = gid;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    var k: i32 = i32(tid.z);
    if ((((i >= g.nx) || (j >= g.ny)) || (k >= g.nz))) {
        return;
    }
    var c: i32 = f_gidx(g, i, j, k);
    var sj: i32 = g.strideJ;
    var sk: i32 = (g.strideJ * g.strideK);
    var temx: f32 = opq((opq((opq(a.dts)) * (opq(0.5f)))) * (opq(g.rdx)));
    var temy: f32 = opq((opq((opq(a.dts)) * (opq(0.5f)))) * (opq(g.rdy)));
    {
        var gz: f32 = f_tplane(g, tpl, 0i, i, j);
        var uh: f32 = f_hm_uh(g, hm, i);
        var vh: f32 = f_hm_vh(g, hm, j);
        var dzdx: f32 = f_tplane(g, tpl, 6i, i, j);
        var dzdy: f32 = f_tplane(g, tpl, 7i, i, j);
        var div: f32 = opq((opq(gz)) * (opq(fma((opq((opq(lam_3((k + 1i), &g, tz, u3d, &j, tpl, &i, &dzdx, v3d, &dzdy, &tp, &gz))) - (opq(lam_3(k, &g, tz, u3d, &j, tpl, &i, &dzdx, v3d, &dzdy, &tp, &gz))))), opq(f_tsig(g, tz, 1i, k)), (opq(fma(opq((opq((opq(lam_1((i + 1i), k, u3d, &g, &j, tpl))) - (opq(lam_1(i, k, u3d, &g, &j, tpl))))) * (opq(g.rdx))), opq(uh), opq((opq((opq((opq(lam_2((j + 1i), k, v3d, &g, &i, tpl))) - (opq(lam_2(j, k, v3d, &g, &i, tpl))))) * (opq(g.rdy)))) * (opq(vh))))))))));
        if (((abs(div)) < a.smeps)) {
            div = 0.0f;
        }
        var w1: f32 = select(bitcast<f32>(mem_ld((w3d + bitcast<u32>(c)))), 0.0f, (k == 0i));
        var w2: f32 = select(bitcast<f32>(mem_ld((w3d + bitcast<u32>((c + sk))))), 0.0f, (k == (g.nz - 1i)));
        var f: f32 = opq(fma(opq(a.dts), (opq(fma(opq((-(bitcast<f32>(mem_ld((ppterm + bitcast<u32>(c))))))), opq(div), bitcast<f32>(mem_ld((ppten + bitcast<u32>(c))))))), opq((opq(a.beta)) * (opq((opq((-(bitcast<f32>(mem_ld((qk + bitcast<u32>(c)))))))) * (opq((opq(w2)) - (opq(w1)))))))));
        var u2: f32 = opq((opq((opq(temx)) * (opq(lam_6((i + 1i), k, &g, &j, rho0, u3d, tpl))))) * (opq(uh)));
        var u1: f32 = opq((opq((opq(temx)) * (opq(lam_6(i, k, &g, &j, rho0, u3d, tpl))))) * (opq(uh)));
        var v2: f32 = opq((opq((opq(temy)) * (opq(lam_8((j + 1i), k, &g, &i, rho0, &sj, v3d, tpl))))) * (opq(vh)));
        var v1: f32 = opq((opq((opq(temy)) * (opq(lam_8(j, k, &g, &i, rho0, &sj, v3d, tpl))))) * (opq(vh)));
        var ww2: f32 = opq(fma(opq(a.beta), bitcast<f32>(mem_ld((w3d + bitcast<u32>((c + sk))))), opq(lam_10((k + 1i), &g, tz, &i, &j, rho0, u3d, tpl, &dzdx, &sj, v3d, &dzdy, &tp, &gz, rf0))));
        var ww1: f32 = opq(fma(opq(a.beta), bitcast<f32>(mem_ld((w3d + bitcast<u32>(c)))), opq(lam_10(k, &g, tz, &i, &j, rho0, u3d, tpl, &dzdx, &sj, v3d, &dzdy, &tp, &gz, rf0))));
        f = opq((opq(fma(opq((opq((opq((-(opq(fma(opq(u2), (opq((bitcast<f32>(mem_ld((piadv + bitcast<u32>((c + 1i)))))) - (bitcast<f32>(mem_ld((piadv + bitcast<u32>(c))))))), opq((opq(u1)) * (opq((bitcast<f32>(mem_ld((piadv + bitcast<u32>(c))))) - (bitcast<f32>(mem_ld((piadv + bitcast<u32>((c - 1i))))))))))))))) - (opq(fma(opq(v2), (opq((bitcast<f32>(mem_ld((piadv + bitcast<u32>((c + sj)))))) - (bitcast<f32>(mem_ld((piadv + bitcast<u32>(c))))))), opq((opq(v1)) * (opq((bitcast<f32>(mem_ld((piadv + bitcast<u32>(c))))) - (bitcast<f32>(mem_ld((piadv + bitcast<u32>((c - sj)))))))))))))) * (bitcast<f32>(mem_ld((rr0 + bitcast<u32>(c)))))), opq(gz), opq(f)))) + (opq(fma(opq(ww1), bitcast<f32>(mem_ld((pk1 + bitcast<u32>(c)))), opq((opq(ww2)) * (bitcast<f32>(mem_ld((pk2 + bitcast<u32>(c))))))))));
        mem_st((fpk + bitcast<u32>(c)), bitcast<u32>(f));
        return;
    }
    var div: f32 = opq(fma(opq((opq((bitcast<f32>(mem_ld((u3d + bitcast<u32>((c + 1i)))))) - (bitcast<f32>(mem_ld((u3d + bitcast<u32>(c))))))) * (opq(g.rdx))), opq(f_hm_uh(g, hm, i)), opq((opq((opq((bitcast<f32>(mem_ld((v3d + bitcast<u32>((c + sj)))))) - (bitcast<f32>(mem_ld((v3d + bitcast<u32>(c))))))) * (opq(g.rdy)))) * (opq(f_hm_vh(g, hm, j))))));
    if (((abs(div)) < a.smeps)) {
        div = 0.0f;
    }
    var advPi: f32 = opq(fma(opq((opq((-(opq(fma(bitcast<f32>(mem_ld((u3d + bitcast<u32>(c)))), (opq((bitcast<f32>(mem_ld((piadv + bitcast<u32>(c))))) - (bitcast<f32>(mem_ld((piadv + bitcast<u32>((c - 1i)))))))), opq((bitcast<f32>(mem_ld((u3d + bitcast<u32>((c + 1i)))))) * (opq((bitcast<f32>(mem_ld((piadv + bitcast<u32>((c + 1i)))))) - (bitcast<f32>(mem_ld((piadv + bitcast<u32>(c)))))))))))))) * (opq(temx))), opq(f_hm_uh(g, hm, i)), opq((-(opq((opq((opq(fma(bitcast<f32>(mem_ld((v3d + bitcast<u32>(c)))), (opq((bitcast<f32>(mem_ld((piadv + bitcast<u32>(c))))) - (bitcast<f32>(mem_ld((piadv + bitcast<u32>((c - sj)))))))), opq((bitcast<f32>(mem_ld((v3d + bitcast<u32>((c + sj)))))) * (opq((bitcast<f32>(mem_ld((piadv + bitcast<u32>((c + sj)))))) - (bitcast<f32>(mem_ld((piadv + bitcast<u32>(c))))))))))) * (opq(temy)))) * (opq(f_hm_vh(g, hm, j)))))))));
    mem_st((fpk + bitcast<u32>(c)), bitcast<u32>(opq(fma(opq(a.beta), (opq(fma(bitcast<f32>(mem_ld((w3d + bitcast<u32>(c)))), (opq((bitcast<f32>(mem_ld((pk1 + bitcast<u32>(c))))) + (bitcast<f32>(mem_ld((qk + bitcast<u32>(c))))))), opq((bitcast<f32>(mem_ld((w3d + bitcast<u32>((c + sk)))))) * (opq((bitcast<f32>(mem_ld((pk2 + bitcast<u32>(c))))) - (bitcast<f32>(mem_ld((qk + bitcast<u32>(c))))))))))), opq(fma(opq(a.dts), (opq(fma(opq((-(bitcast<f32>(mem_ld((ppterm + bitcast<u32>(c))))))), opq(div), bitcast<f32>(mem_ld((ppten + bitcast<u32>(c))))))), opq(advPi)))))));
}
