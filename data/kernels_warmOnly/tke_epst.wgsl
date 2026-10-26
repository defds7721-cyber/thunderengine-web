// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// tke_epst: сгенерировано, не править руками.

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

fn lam_1(cc_in: i32, kk_in: i32, u: u32, g: ptr<function, S_GridDims>, hm: u32, i: ptr<function, i32>, t11: u32, v: u32, sj: ptr<function, i32>, j: ptr<function, i32>, t22: u32) -> f32 {
    var cc: i32 = cc_in;
    var kk: i32 = kk_in;
    return opq(fma(opq((opq((opq((bitcast<f32>(mem_ld((u + bitcast<u32>((cc + 1i)))))) - (bitcast<f32>(mem_ld((u + bitcast<u32>(cc))))))) * (opq((*g).rdx)))) * (opq(f_hm_uh((*g), hm, (*i))))), bitcast<f32>(mem_ld((t11 + bitcast<u32>(cc)))), opq((opq((opq((opq((bitcast<f32>(mem_ld((v + bitcast<u32>((cc + (*sj))))))) - (bitcast<f32>(mem_ld((v + bitcast<u32>(cc))))))) * (opq((*g).rdy)))) * (opq(f_hm_vh((*g), hm, (*j)))))) * (bitcast<f32>(mem_ld((t22 + bitcast<u32>(cc))))))));
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

fn lam_2(cc_in: i32, ii_in: i32, jj_in: i32, t12: u32, u: u32, sj: ptr<function, i32>, g: ptr<function, S_GridDims>, hm: u32, v: u32) -> f32 {
    var cc: i32 = cc_in;
    var ii: i32 = ii_in;
    var jj: i32 = jj_in;
    return opq((bitcast<f32>(mem_ld((t12 + bitcast<u32>(cc))))) * (opq(fma(opq((opq((bitcast<f32>(mem_ld((u + bitcast<u32>(cc))))) - (bitcast<f32>(mem_ld((u + bitcast<u32>((cc - (*sj))))))))) * (opq((*g).rdy))), opq(f_hm_vf((*g), hm, jj)), opq((opq((opq((bitcast<f32>(mem_ld((v + bitcast<u32>(cc))))) - (bitcast<f32>(mem_ld((v + bitcast<u32>((cc - 1i)))))))) * (opq((*g).rdx)))) * (opq(f_hm_uf((*g), hm, ii))))))));
}

fn f_hm_vf(g_in: S_GridDims, hm_in: u32, j_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var hm: u32 = hm_in;
    var j: i32 = j_in;
    return bitcast<f32>(mem_ld((hm + bitcast<u32>(((((2i * g.strideJ) + g.strideK) + j) + 3i)))));
}

fn f_hm_uf(g_in: S_GridDims, hm_in: u32, i_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var hm: u32 = hm_in;
    var i: i32 = i_in;
    return bitcast<f32>(mem_ld((hm + bitcast<u32>(((g.strideJ + i) + 3i)))));
}

fn lam_3(cc_in: i32, ii_in: i32, w: u32, g: ptr<function, S_GridDims>, hm: u32, u: u32, sk: ptr<function, i32>, mf: u32, c: ptr<function, i32>, k: ptr<function, i32>, t13: u32) -> f32 {
    var cc: i32 = cc_in;
    var ii: i32 = ii_in;
    return opq((opq(fma(opq((opq((bitcast<f32>(mem_ld((w + bitcast<u32>(cc))))) - (bitcast<f32>(mem_ld((w + bitcast<u32>((cc - 1i)))))))) * (opq((*g).rdx))), opq(f_hm_uf((*g), hm, ii)), opq((opq((opq((bitcast<f32>(mem_ld((u + bitcast<u32>(cc))))) - (bitcast<f32>(mem_ld((u + bitcast<u32>((cc - (*sk))))))))) * (opq((*g).rdz)))) * (bitcast<f32>(mem_ld((mf + bitcast<u32>((*k)))))))))) * (bitcast<f32>(mem_ld((t13 + bitcast<u32>(cc))))));
}

fn lam_4(cc_in: i32, jj_in: i32, w: u32, sj: ptr<function, i32>, g: ptr<function, S_GridDims>, hm: u32, v: u32, sk: ptr<function, i32>, mf: u32, c: ptr<function, i32>, k: ptr<function, i32>, t23: u32) -> f32 {
    var cc: i32 = cc_in;
    var jj: i32 = jj_in;
    return opq((opq(fma(opq((opq((bitcast<f32>(mem_ld((w + bitcast<u32>(cc))))) - (bitcast<f32>(mem_ld((w + bitcast<u32>((cc - (*sj))))))))) * (opq((*g).rdy))), opq(f_hm_vf((*g), hm, jj)), opq((opq((opq((bitcast<f32>(mem_ld((v + bitcast<u32>(cc))))) - (bitcast<f32>(mem_ld((v + bitcast<u32>((cc - (*sk))))))))) * (opq((*g).rdz)))) * (bitcast<f32>(mem_ld((mf + bitcast<u32>((*k)))))))))) * (bitcast<f32>(mem_ld((t23 + bitcast<u32>(cc))))));
}

fn lam_5(cc_in: i32, kk_in: i32, w: u32, sk: ptr<function, i32>, g: ptr<function, S_GridDims>, mh: u32, t33: u32) -> f32 {
    var cc: i32 = cc_in;
    var kk: i32 = kk_in;
    return opq((opq((opq((opq((bitcast<f32>(mem_ld((w + bitcast<u32>((cc + (*sk))))))) - (bitcast<f32>(mem_ld((w + bitcast<u32>(cc))))))) * (opq((*g).rdz)))) * (bitcast<f32>(mem_ld((mh + bitcast<u32>(kk))))))) * (bitcast<f32>(mem_ld((t33 + bitcast<u32>(cc))))));
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    var g: S_GridDims = ld_GridDims(ARG[4]);
    var u: u32 = ARG[5];
    var v: u32 = ARG[6];
    var w: u32 = ARG[7];
    var t11: u32 = ARG[8];
    var t12: u32 = ARG[9];
    var t13: u32 = ARG[10];
    var t22: u32 = ARG[11];
    var t23: u32 = ARG[12];
    var t33: u32 = ARG[13];
    var rf: u32 = ARG[14];
    var mh: u32 = ARG[15];
    var mf: u32 = ARG[16];
    var c1: u32 = ARG[17];
    var c2: u32 = ARG[18];
    var epst: u32 = ARG[19];
    var hm: u32 = ARG[34];
    var tid: vec3<u32> = gid;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    var k: i32 = ((i32(tid.z)) + 1i);
    if ((((i >= g.nx) || (j >= g.ny)) || (k > (g.nz - 1i)))) {
        return;
    }
    var sj: i32 = g.strideJ;
    var sk: i32 = (g.strideJ * g.strideK);
    var c: i32 = f_gidx(g, i, j, k);
    var cd: i32 = (c - sk);
    var e: f32 = opq(fma(bitcast<f32>(mem_ld((c1 + bitcast<u32>(k)))), opq(lam_1(cd, (k - 1i), u, &g, hm, &i, t11, v, &sj, &j, t22)), opq((bitcast<f32>(mem_ld((c2 + bitcast<u32>(k))))) * (opq(lam_1(c, k, u, &g, hm, &i, t11, v, &sj, &j, t22))))));
    e = opq(fma(opq(0.25f), (opq(fma(bitcast<f32>(mem_ld((c2 + bitcast<u32>(k)))), (opq((opq((opq(lam_2(c, i, j, t12, u, &sj, &g, hm, v))) + (opq(lam_2(((c + 1i) + sj), (i + 1i), (j + 1i), t12, u, &sj, &g, hm, v))))) + (opq((opq(lam_2((c + sj), i, (j + 1i), t12, u, &sj, &g, hm, v))) + (opq(lam_2((c + 1i), (i + 1i), j, t12, u, &sj, &g, hm, v))))))), opq((bitcast<f32>(mem_ld((c1 + bitcast<u32>(k))))) * (opq((opq((opq(lam_2(cd, i, j, t12, u, &sj, &g, hm, v))) + (opq(lam_2(((cd + 1i) + sj), (i + 1i), (j + 1i), t12, u, &sj, &g, hm, v))))) + (opq((opq(lam_2((cd + sj), i, (j + 1i), t12, u, &sj, &g, hm, v))) + (opq(lam_2((cd + 1i), (i + 1i), j, t12, u, &sj, &g, hm, v))))))))))), opq(e)));
    e = opq(fma(opq(0.5f), (opq((opq((opq(lam_3(c, i, w, &g, hm, u, &sk, mf, &c, &k, t13))) + (opq(lam_3((c + 1i), (i + 1i), w, &g, hm, u, &sk, mf, &c, &k, t13))))) + (opq((opq(lam_4(c, j, w, &sj, &g, hm, v, &sk, mf, &c, &k, t23))) + (opq(lam_4((c + sj), (j + 1i), w, &sj, &g, hm, v, &sk, mf, &c, &k, t23))))))), opq(e)));
    e = opq((opq(e)) + (opq(fma(bitcast<f32>(mem_ld((c1 + bitcast<u32>(k)))), opq(lam_5(cd, (k - 1i), w, &sk, &g, mh, t33)), opq((bitcast<f32>(mem_ld((c2 + bitcast<u32>(k))))) * (opq(lam_5(c, k, w, &sk, &g, mh, t33))))))));
    mem_st((epst + bitcast<u32>(c)), bitcast<u32>(div_cr(e, bitcast<f32>(mem_ld((rf + bitcast<u32>(c)))))));
}
