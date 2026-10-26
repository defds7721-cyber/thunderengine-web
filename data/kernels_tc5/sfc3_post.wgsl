// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// sfc3_post: сгенерировано, не править руками.

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
    var pin: u32 = ARG[6];
    var slab: i32 = bitcast<i32>(mem_ld(ARG[7]));
    var sfc: u32 = ARG[8];
    var tid: vec2<u32> = gid.xy;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    if (((i >= g.nx) || (j >= g.ny))) {
        return;
    }
    var plane: i32 = (g.strideJ * g.strideK);
    var o: i32 = f_gidx(g, i, j, 0i);
    var c: i32 = (i + (g.nx * j));
    if ((slab == 0i)) {
        var qx: f32 = bitcast<f32>(mem_ld((pin + bitcast<u32>((((((4i) * (g.nz + 1i)) + (0i)) * pc.nc) + c)))));
        var flqc: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((35i) * plane) + o)))));
        mem_st((sfc + bitcast<u32>((((12i) * plane) + o))), bitcast<u32>(select(qx, opq((opq(qx)) + (opq(div_cr(bitcast<f32>(mem_ld((sfc + bitcast<u32>((((32i) * plane) + o))))), flqc)))), (flqc != 0.0f))));
        mem_st((sfc + bitcast<u32>((((62i) * plane) + o))), bitcast<u32>(bitcast<f32>(mem_ld((sfc + bitcast<u32>((((18i) * plane) + o)))))));
    }
    mem_st((sfc + bitcast<u32>((((6i) * plane) + o))), bitcast<u32>(bitcast<f32>(mem_ld((sfc + bitcast<u32>((((56i) * plane) + o)))))));
    mem_st((sfc + bitcast<u32>((((7i) * plane) + o))), bitcast<u32>(bitcast<f32>(mem_ld((sfc + bitcast<u32>((((57i) * plane) + o)))))));
    var u10: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((38i) * plane) + o)))));
    var v10: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((39i) * plane) + o)))));
    mem_st((sfc + bitcast<u32>((((8i) * plane) + o))), bitcast<u32>(sqrt_cr(opq(fma(opq(u10), opq(u10), opq((opq(v10)) * (opq(v10))))))));
    var rf1: f32 = bitcast<f32>(mem_ld((pin + bitcast<u32>((((((12i) * (g.nz + 1i)) + (0i)) * pc.nc) + c)))));
    mem_st((sfc + bitcast<u32>((((9i) * plane) + o))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((sfc + bitcast<u32>((((31i) * plane) + o))))), (opq((bitcast<f32>(mem_ld((sfc + bitcast<u32>((((58i) * plane) + o)))))) * (opq(rf1)))))));
    mem_st((sfc + bitcast<u32>((((10i) * plane) + o))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((sfc + bitcast<u32>((((32i) * plane) + o))))), rf1)));
}
