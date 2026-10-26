// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// pbl_prep: сгенерировано, не править руками.

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

struct S_PblConsts {
    cp: f32,
    g: f32,
    rovcp: f32,
    rd: f32,
    rv: f32,
    xlv: f32,
    lv1: f32,
    lv2: f32,
    ep1: f32,
    ep2: f32,
    karman: f32,
    p1000mb: f32,
    svp1: f32,
    svp2: f32,
    svp3: f32,
    svpt0: f32,
    dx: f32,
    dt: f32,
    nc: i32,
    zero: u32,
}

struct S_PblPrepParams {
    cgs1: f32,
    cgs2: f32,
    cgs3: f32,
    cgt1: f32,
    cgt2: f32,
    cgt3: f32,
    dz: f32,
    moist: i32,
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

fn ld_PblConsts(o: u32) -> S_PblConsts {
    var s: S_PblConsts;
    s.cp = bitcast<f32>(mem_ld((o + 0u)));
    s.g = bitcast<f32>(mem_ld((o + 1u)));
    s.rovcp = bitcast<f32>(mem_ld((o + 2u)));
    s.rd = bitcast<f32>(mem_ld((o + 3u)));
    s.rv = bitcast<f32>(mem_ld((o + 4u)));
    s.xlv = bitcast<f32>(mem_ld((o + 5u)));
    s.lv1 = bitcast<f32>(mem_ld((o + 6u)));
    s.lv2 = bitcast<f32>(mem_ld((o + 7u)));
    s.ep1 = bitcast<f32>(mem_ld((o + 8u)));
    s.ep2 = bitcast<f32>(mem_ld((o + 9u)));
    s.karman = bitcast<f32>(mem_ld((o + 10u)));
    s.p1000mb = bitcast<f32>(mem_ld((o + 11u)));
    s.svp1 = bitcast<f32>(mem_ld((o + 12u)));
    s.svp2 = bitcast<f32>(mem_ld((o + 13u)));
    s.svp3 = bitcast<f32>(mem_ld((o + 14u)));
    s.svpt0 = bitcast<f32>(mem_ld((o + 15u)));
    s.dx = bitcast<f32>(mem_ld((o + 16u)));
    s.dt = bitcast<f32>(mem_ld((o + 17u)));
    s.nc = bitcast<i32>(mem_ld((o + 18u)));
    s.zero = mem_ld((o + 19u));
    return s;
}

fn ld_PblPrepParams(o: u32) -> S_PblPrepParams {
    var s: S_PblPrepParams;
    s.cgs1 = bitcast<f32>(mem_ld((o + 0u)));
    s.cgs2 = bitcast<f32>(mem_ld((o + 1u)));
    s.cgs3 = bitcast<f32>(mem_ld((o + 2u)));
    s.cgt1 = bitcast<f32>(mem_ld((o + 3u)));
    s.cgt2 = bitcast<f32>(mem_ld((o + 4u)));
    s.cgt3 = bitcast<f32>(mem_ld((o + 5u)));
    s.dz = bitcast<f32>(mem_ld((o + 6u)));
    s.moist = bitcast<i32>(mem_ld((o + 7u)));
    return s;
}

fn f_gidx(g_in: S_GridDims, i_in: i32, j_in: i32, k_in: i32) -> i32 {
    var g: S_GridDims = g_in;
    var i: i32 = i_in;
    var j: i32 = j_in;
    var k: i32 = k_in;
    return ((i + 3i) + (g.strideJ * ((j + 3i) + (g.strideK * k))));
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    var g: S_GridDims = ld_GridDims(ARG[4]);
    var pc: S_PblConsts = ld_PblConsts(ARG[5]);
    var pp: S_PblPrepParams = ld_PblPrepParams(ARG[6]);
    var u: u32 = ARG[7];
    var v: u32 = ARG[8];
    var tha: u32 = ARG[9];
    var ppi: u32 = ARG[10];
    var qv: u32 = ARG[11];
    var qc: u32 = ARG[12];
    var qi: u32 = ARG[13];
    var prs: u32 = ARG[14];
    var rf: u32 = ARG[15];
    var sat: u32 = ARG[16];
    var th0: u32 = ARG[17];
    var pi0: u32 = ARG[18];
    var c1: u32 = ARG[19];
    var c2: u32 = ARG[20];
    var mh: u32 = ARG[21];
    var pin: u32 = ARG[22];
    var sfc: u32 = ARG[23];
    var tid: vec3<u32> = gid;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    var k: i32 = i32(tid.z);
    if ((((i >= g.nx) || (j >= g.ny)) || (k > g.nz))) {
        return;
    }
    var c: i32 = (i + (g.nx * j));
    var sk: i32 = (g.strideJ * g.strideK);
    var a0: i32 = f_gidx(g, i, j, 0i);
    var psfc: f32 = opq(fma(opq(pp.cgs3), bitcast<f32>(mem_ld((prs + bitcast<u32>((a0 + (2i * sk)))))), opq(fma(opq(pp.cgs1), bitcast<f32>(mem_ld((prs + bitcast<u32>(a0)))), opq((opq(pp.cgs2)) * (bitcast<f32>(mem_ld((prs + bitcast<u32>((a0 + sk)))))))))));
    if ((k == 0i)) {
        var plane: i32 = sk;
        var o: i32 = a0;
        mem_st((sfc + bitcast<u32>((((11i) * plane) + o))), bitcast<u32>(psfc));
    }
    var p8: f32;
    if ((k == 0i)) {
        p8 = psfc;
    } else {
        if ((k == g.nz)) {
            var b1: i32 = f_gidx(g, i, j, (g.nz - 1i));
            p8 = opq(fma(opq(pp.cgt3), bitcast<f32>(mem_ld((prs + bitcast<u32>((b1 - (2i * sk)))))), opq(fma(opq(pp.cgt1), bitcast<f32>(mem_ld((prs + bitcast<u32>(b1)))), opq((opq(pp.cgt2)) * (bitcast<f32>(mem_ld((prs + bitcast<u32>((b1 - sk)))))))))));
        } else {
            var a: i32 = f_gidx(g, i, j, k);
            p8 = opq(fma(bitcast<f32>(mem_ld((c1 + bitcast<u32>(k)))), bitcast<f32>(mem_ld((prs + bitcast<u32>((a - sk))))), opq((bitcast<f32>(mem_ld((c2 + bitcast<u32>(k))))) * (bitcast<f32>(mem_ld((prs + bitcast<u32>(a))))))));
        }
    }
    mem_st((pin + bitcast<u32>((((((8i) * (g.nz + 1i)) + k) * pc.nc) + c))), bitcast<u32>(p8));
    if ((k == g.nz)) {
        return;
    }
    var a: i32 = f_gidx(g, i, j, k);
    var th: f32 = opq((bitcast<f32>(mem_ld((th0 + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((tha + bitcast<u32>(a))))));
    var pi: f32 = opq((bitcast<f32>(mem_ld((pi0 + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((ppi + bitcast<u32>(a))))));
    mem_st((pin + bitcast<u32>((((((0i) * (g.nz + 1i)) + k) * pc.nc) + c))), bitcast<u32>(opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((u + bitcast<u32>(a))))) + (bitcast<f32>(mem_ld((u + bitcast<u32>((a + 1i)))))))))));
    mem_st((pin + bitcast<u32>((((((1i) * (g.nz + 1i)) + k) * pc.nc) + c))), bitcast<u32>(opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((v + bitcast<u32>(a))))) + (bitcast<f32>(mem_ld((v + bitcast<u32>((a + g.strideJ)))))))))));
    mem_st((pin + bitcast<u32>((((((2i) * (g.nz + 1i)) + k) * pc.nc) + c))), bitcast<u32>(th));
    mem_st((pin + bitcast<u32>((((((9i) * (g.nz + 1i)) + k) * pc.nc) + c))), bitcast<u32>(pi));
    mem_st((pin + bitcast<u32>((((((3i) * (g.nz + 1i)) + k) * pc.nc) + c))), bitcast<u32>(opq((opq(th)) * (opq(pi)))));
    mem_st((pin + bitcast<u32>((((((4i) * (g.nz + 1i)) + k) * pc.nc) + c))), bitcast<u32>(bitcast<f32>(mem_ld((qv + bitcast<u32>(a))))));
    mem_st((pin + bitcast<u32>((((((5i) * (g.nz + 1i)) + k) * pc.nc) + c))), bitcast<u32>(select(0.0f, bitcast<f32>(mem_ld((qc + bitcast<u32>(a)))), (pp.moist != 0i))));
    mem_st((pin + bitcast<u32>((((((6i) * (g.nz + 1i)) + k) * pc.nc) + c))), bitcast<u32>(select(0.0f, bitcast<f32>(mem_ld((qi + bitcast<u32>(a)))), (pp.moist != 0i))));
    mem_st((pin + bitcast<u32>((((((7i) * (g.nz + 1i)) + k) * pc.nc) + c))), bitcast<u32>(bitcast<f32>(mem_ld((prs + bitcast<u32>(a))))));
    mem_st((pin + bitcast<u32>((((((10i) * (g.nz + 1i)) + k) * pc.nc) + c))), bitcast<u32>(opq((opq(pp.dz)) * (opq((div_cr(1.0f, bitcast<f32>(mem_ld((mh + bitcast<u32>(k)))))))))));
    mem_st((pin + bitcast<u32>((((((11i) * (g.nz + 1i)) + k) * pc.nc) + c))), bitcast<u32>(select(bitcast<f32>(mem_ld((sat + bitcast<u32>(a)))), 0.0f, (k == 0i))));
    mem_st((pin + bitcast<u32>((((((12i) * (g.nz + 1i)) + k) * pc.nc) + c))), bitcast<u32>(bitcast<f32>(mem_ld((rf + bitcast<u32>(a))))));
}
