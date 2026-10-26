// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// terrain_rrw: сгенерировано, не править руками.

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

fn f_tplane(g_in: S_GridDims, tpl_in: u32, n_in: i32, i_in: i32, j_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var tpl: u32 = tpl_in;
    var n: i32 = n_in;
    var i: i32 = i_in;
    var j: i32 = j_in;
    let _t1 = (((n * g.strideJ) * g.strideK) + (f_gidx(g, i, j, 0i)));
    return bitcast<f32>(mem_ld((tpl + bitcast<u32>(_t1))));
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    var g: S_GridDims = ld_GridDims(ARG[4]);
    var rru: u32 = ARG[5];
    var rrv: u32 = ARG[6];
    var rrw: u32 = ARG[7];
    var tpl: u32 = ARG[28];
    var tz: u32 = ARG[29];
    var tp: S_TerrainParams = ld_TerrainParams(ARG[30]);
    var tid: vec3<u32> = gid;
    var i: i32 = ((i32(tid.x)) - 3i);
    var j: i32 = ((i32(tid.y)) - 3i);
    var k: i32 = ((i32(tid.z)) + 1i);
    if ((((i > ((g.nx - 1i) + 3i)) || (j > ((g.ny - 1i) + 3i))) || (k > (g.nz - 1i)))) {
        return;
    }
    var ii: i32 = min(i, ((g.nx - 2i) + 3i));
    var jj: i32 = min(j, ((g.ny - 2i) + 3i));
    var sj: i32 = g.strideJ;
    var sk: i32 = (g.strideJ * g.strideK);
    var c: i32 = f_gidx(g, ii, jj, k);
    var cm: i32 = (c - sk);
    var r2: f32 = f_terr_r2(g, tz, k);
    var r1: f32 = opq((opq(1.0f)) - (opq(r2)));
    r1 = opq((opq(0.5f)) * (opq(r1)));
    r2 = opq((opq(0.5f)) * (opq(r2)));
    var term: f32 = opq((opq((opq((opq(fma((opq(fma(opq(r2), (opq((bitcast<f32>(mem_ld((rru + bitcast<u32>(c))))) + (bitcast<f32>(mem_ld((rru + bitcast<u32>((c + 1i)))))))), opq((opq(r1)) * (opq((bitcast<f32>(mem_ld((rru + bitcast<u32>(cm))))) + (bitcast<f32>(mem_ld((rru + bitcast<u32>((cm + 1i)))))))))))), opq(f_tplane(g, tpl, 6i, ii, jj)), opq((opq(fma(opq(r2), (opq((bitcast<f32>(mem_ld((rrv + bitcast<u32>(c))))) + (bitcast<f32>(mem_ld((rrv + bitcast<u32>((c + sj)))))))), opq((opq(r1)) * (opq((bitcast<f32>(mem_ld((rrv + bitcast<u32>(cm))))) + (bitcast<f32>(mem_ld((rrv + bitcast<u32>((cm + sj)))))))))))) * (opq(f_tplane(g, tpl, 7i, ii, jj))))))) * (opq((opq(f_tsig(g, tz, 3i, k))) - (opq(tp.zt)))))) * (opq(f_tplane(g, tpl, 0i, ii, jj))))) * (opq(tp.rzt)));
    var cw: i32 = f_gidx(g, i, j, k);
    mem_st((rrw + bitcast<u32>(cw)), bitcast<u32>(select(opq((bitcast<f32>(mem_ld((rrw + bitcast<u32>(c))))) + (opq(term))), opq((bitcast<f32>(mem_ld((rrw + bitcast<u32>(cw))))) + (opq(term))), ((ii == i) && (jj == j)))));
}
