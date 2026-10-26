// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// mp_calcdbz: сгенерировано, не править руками.

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

struct S_GoddardParams {
    tnw: f32,
    tnss: f32,
    tng: f32,
    roqr: f32,
    roqs: f32,
    roqsPotter: f32,
    roqg: f32,
    zrc: f32,
    zsc: f32,
    zgc: f32,
    vrc: f32,
    vsc: f32,
    vgc: f32,
    agg: f32,
    bgg: f32,
    ass: f32,
    bss: f32,
    aww: f32,
    bww: f32,
    bgh: f32,
    bgq: f32,
    bsh: f32,
    bsq: f32,
    bwh: f32,
    bwq: f32,
    alv: f32,
    alf: f32,
    als: f32,
    t0k: f32,
    t00k: f32,
    avc: f32,
    afc: f32,
    asc: f32,
    rn1: f32,
    bnd1: f32,
    rn2: f32,
    bnd2: f32,
    rn3: f32,
    rn4: f32,
    rn5: f32,
    rn6: f32,
    rn7: f32,
    rn8: f32,
    rn9: f32,
    rn10: f32,
    rn101: f32,
    rn10a: f32,
    rn11: f32,
    rn11a: f32,
    rn12: f32,
    rn14: f32,
    rn15: f32,
    rn15a: f32,
    rn16: f32,
    rn17: f32,
    rn17a: f32,
    rn17b: f32,
    rn17c: f32,
    rn18: f32,
    rn18a: f32,
    rn19: f32,
    rn19a: f32,
    rn19b: f32,
    rn20: f32,
    rn20a: f32,
    rn20b: f32,
    bnd3: f32,
    rn21: f32,
    rn22: f32,
    rn23: f32,
    rn23a: f32,
    rn23b: f32,
    rn25: f32,
    rn30a: f32,
    rn30b: f32,
    rn30c: f32,
    rn31: f32,
    beta: f32,
    rn32: f32,
    ami40: f32,
    ami50: f32,
    ami100: f32,
    rt0: f32,
    bw3: f32,
    bs3: f32,
    bg3: f32,
    bwh5: f32,
    bsh5: f32,
    bgh5: f32,
    bw6: f32,
    bs6: f32,
    betah: f32,
    r10t: f32,
    r11at: f32,
    r19bt: f32,
    r20t: f32,
    r23t: f32,
    c76: f32,
    c358: f32,
    c172: f32,
    c409: f32,
    c218: f32,
    c580: f32,
    c380: f32,
    c610: f32,
    c149: f32,
    c879: f32,
    c141: f32,
    tem5: f32,
    dt: f32,
    rdt: f32,
    ihail: i32,
    iautoc: i32,
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

fn ld_GoddardParams(o: u32) -> S_GoddardParams {
    var s: S_GoddardParams;
    s.tnw = bitcast<f32>(mem_ld((o + 0u)));
    s.tnss = bitcast<f32>(mem_ld((o + 1u)));
    s.tng = bitcast<f32>(mem_ld((o + 2u)));
    s.roqr = bitcast<f32>(mem_ld((o + 3u)));
    s.roqs = bitcast<f32>(mem_ld((o + 4u)));
    s.roqsPotter = bitcast<f32>(mem_ld((o + 5u)));
    s.roqg = bitcast<f32>(mem_ld((o + 6u)));
    s.zrc = bitcast<f32>(mem_ld((o + 7u)));
    s.zsc = bitcast<f32>(mem_ld((o + 8u)));
    s.zgc = bitcast<f32>(mem_ld((o + 9u)));
    s.vrc = bitcast<f32>(mem_ld((o + 10u)));
    s.vsc = bitcast<f32>(mem_ld((o + 11u)));
    s.vgc = bitcast<f32>(mem_ld((o + 12u)));
    s.agg = bitcast<f32>(mem_ld((o + 13u)));
    s.bgg = bitcast<f32>(mem_ld((o + 14u)));
    s.ass = bitcast<f32>(mem_ld((o + 15u)));
    s.bss = bitcast<f32>(mem_ld((o + 16u)));
    s.aww = bitcast<f32>(mem_ld((o + 17u)));
    s.bww = bitcast<f32>(mem_ld((o + 18u)));
    s.bgh = bitcast<f32>(mem_ld((o + 19u)));
    s.bgq = bitcast<f32>(mem_ld((o + 20u)));
    s.bsh = bitcast<f32>(mem_ld((o + 21u)));
    s.bsq = bitcast<f32>(mem_ld((o + 22u)));
    s.bwh = bitcast<f32>(mem_ld((o + 23u)));
    s.bwq = bitcast<f32>(mem_ld((o + 24u)));
    s.alv = bitcast<f32>(mem_ld((o + 25u)));
    s.alf = bitcast<f32>(mem_ld((o + 26u)));
    s.als = bitcast<f32>(mem_ld((o + 27u)));
    s.t0k = bitcast<f32>(mem_ld((o + 28u)));
    s.t00k = bitcast<f32>(mem_ld((o + 29u)));
    s.avc = bitcast<f32>(mem_ld((o + 30u)));
    s.afc = bitcast<f32>(mem_ld((o + 31u)));
    s.asc = bitcast<f32>(mem_ld((o + 32u)));
    s.rn1 = bitcast<f32>(mem_ld((o + 33u)));
    s.bnd1 = bitcast<f32>(mem_ld((o + 34u)));
    s.rn2 = bitcast<f32>(mem_ld((o + 35u)));
    s.bnd2 = bitcast<f32>(mem_ld((o + 36u)));
    s.rn3 = bitcast<f32>(mem_ld((o + 37u)));
    s.rn4 = bitcast<f32>(mem_ld((o + 38u)));
    s.rn5 = bitcast<f32>(mem_ld((o + 39u)));
    s.rn6 = bitcast<f32>(mem_ld((o + 40u)));
    s.rn7 = bitcast<f32>(mem_ld((o + 41u)));
    s.rn8 = bitcast<f32>(mem_ld((o + 42u)));
    s.rn9 = bitcast<f32>(mem_ld((o + 43u)));
    s.rn10 = bitcast<f32>(mem_ld((o + 44u)));
    s.rn101 = bitcast<f32>(mem_ld((o + 45u)));
    s.rn10a = bitcast<f32>(mem_ld((o + 46u)));
    s.rn11 = bitcast<f32>(mem_ld((o + 47u)));
    s.rn11a = bitcast<f32>(mem_ld((o + 48u)));
    s.rn12 = bitcast<f32>(mem_ld((o + 49u)));
    s.rn14 = bitcast<f32>(mem_ld((o + 50u)));
    s.rn15 = bitcast<f32>(mem_ld((o + 51u)));
    s.rn15a = bitcast<f32>(mem_ld((o + 52u)));
    s.rn16 = bitcast<f32>(mem_ld((o + 53u)));
    s.rn17 = bitcast<f32>(mem_ld((o + 54u)));
    s.rn17a = bitcast<f32>(mem_ld((o + 55u)));
    s.rn17b = bitcast<f32>(mem_ld((o + 56u)));
    s.rn17c = bitcast<f32>(mem_ld((o + 57u)));
    s.rn18 = bitcast<f32>(mem_ld((o + 58u)));
    s.rn18a = bitcast<f32>(mem_ld((o + 59u)));
    s.rn19 = bitcast<f32>(mem_ld((o + 60u)));
    s.rn19a = bitcast<f32>(mem_ld((o + 61u)));
    s.rn19b = bitcast<f32>(mem_ld((o + 62u)));
    s.rn20 = bitcast<f32>(mem_ld((o + 63u)));
    s.rn20a = bitcast<f32>(mem_ld((o + 64u)));
    s.rn20b = bitcast<f32>(mem_ld((o + 65u)));
    s.bnd3 = bitcast<f32>(mem_ld((o + 66u)));
    s.rn21 = bitcast<f32>(mem_ld((o + 67u)));
    s.rn22 = bitcast<f32>(mem_ld((o + 68u)));
    s.rn23 = bitcast<f32>(mem_ld((o + 69u)));
    s.rn23a = bitcast<f32>(mem_ld((o + 70u)));
    s.rn23b = bitcast<f32>(mem_ld((o + 71u)));
    s.rn25 = bitcast<f32>(mem_ld((o + 72u)));
    s.rn30a = bitcast<f32>(mem_ld((o + 73u)));
    s.rn30b = bitcast<f32>(mem_ld((o + 74u)));
    s.rn30c = bitcast<f32>(mem_ld((o + 75u)));
    s.rn31 = bitcast<f32>(mem_ld((o + 76u)));
    s.beta = bitcast<f32>(mem_ld((o + 77u)));
    s.rn32 = bitcast<f32>(mem_ld((o + 78u)));
    s.ami40 = bitcast<f32>(mem_ld((o + 79u)));
    s.ami50 = bitcast<f32>(mem_ld((o + 80u)));
    s.ami100 = bitcast<f32>(mem_ld((o + 81u)));
    s.rt0 = bitcast<f32>(mem_ld((o + 82u)));
    s.bw3 = bitcast<f32>(mem_ld((o + 83u)));
    s.bs3 = bitcast<f32>(mem_ld((o + 84u)));
    s.bg3 = bitcast<f32>(mem_ld((o + 85u)));
    s.bwh5 = bitcast<f32>(mem_ld((o + 86u)));
    s.bsh5 = bitcast<f32>(mem_ld((o + 87u)));
    s.bgh5 = bitcast<f32>(mem_ld((o + 88u)));
    s.bw6 = bitcast<f32>(mem_ld((o + 89u)));
    s.bs6 = bitcast<f32>(mem_ld((o + 90u)));
    s.betah = bitcast<f32>(mem_ld((o + 91u)));
    s.r10t = bitcast<f32>(mem_ld((o + 92u)));
    s.r11at = bitcast<f32>(mem_ld((o + 93u)));
    s.r19bt = bitcast<f32>(mem_ld((o + 94u)));
    s.r20t = bitcast<f32>(mem_ld((o + 95u)));
    s.r23t = bitcast<f32>(mem_ld((o + 96u)));
    s.c76 = bitcast<f32>(mem_ld((o + 97u)));
    s.c358 = bitcast<f32>(mem_ld((o + 98u)));
    s.c172 = bitcast<f32>(mem_ld((o + 99u)));
    s.c409 = bitcast<f32>(mem_ld((o + 100u)));
    s.c218 = bitcast<f32>(mem_ld((o + 101u)));
    s.c580 = bitcast<f32>(mem_ld((o + 102u)));
    s.c380 = bitcast<f32>(mem_ld((o + 103u)));
    s.c610 = bitcast<f32>(mem_ld((o + 104u)));
    s.c149 = bitcast<f32>(mem_ld((o + 105u)));
    s.c879 = bitcast<f32>(mem_ld((o + 106u)));
    s.c141 = bitcast<f32>(mem_ld((o + 107u)));
    s.tem5 = bitcast<f32>(mem_ld((o + 108u)));
    s.dt = bitcast<f32>(mem_ld((o + 109u)));
    s.rdt = bitcast<f32>(mem_ld((o + 110u)));
    s.ihail = bitcast<i32>(mem_ld((o + 111u)));
    s.iautoc = bitcast<i32>(mem_ld((o + 112u)));
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
    var gp: S_GoddardParams = ld_GoddardParams(ARG[5]);
    var rho: u32 = ARG[6];
    var qr: u32 = ARG[7];
    var qs: u32 = ARG[8];
    var qg: u32 = ARG[9];
    var dbz: u32 = ARG[10];
    var tid: vec3<u32> = gid;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    var k: i32 = i32(tid.z);
    if ((((i >= g.nx) || (j >= g.ny)) || (k >= g.nz))) {
        return;
    }
    var c: i32 = f_gidx(g, i, j, k);
    var epp: f32 = 1e-08f;
    var rhor: f32 = opq((opq(1e+03f)) * (opq(gp.roqr)));
    var rhog: f32 = opq((opq(1e+03f)) * (opq(gp.roqg)));
    var rhos: f32 = opq((opq(1e+03f)) * (opq(gp.roqs)));
    var n0r: f32 = opq((opq(1e+08f)) * (opq(gp.tnw)));
    var n0g: f32 = opq((opq(1e+08f)) * (opq(gp.tng)));
    var n0s: f32 = opq((opq(1e+08f)) * (opq(gp.tnss)));
    var r: f32 = bitcast<f32>(mem_ld((rho + bitcast<u32>(c))));
    var zer: f32 = 0.0f;
    var zeg: f32 = 0.0f;
    var zes: f32 = 0.0f;
    if (((bitcast<f32>(mem_ld((qr + bitcast<u32>(c))))) >= epp)) {
        var gamma: f32 = opq(pow(div_cr(opq((opq((opq(3.14159f)) * (opq(n0r)))) * (opq(rhor))), (opq((opq(r)) * (bitcast<f32>(mem_ld((qr + bitcast<u32>(c)))))))), 0.25f));
        zer = opq((opq((opq(7.2e+02f)) * (opq(n0r)))) * (opq(pow(gamma, opq((-(opq(7.0f))))))));
    }
    if (((bitcast<f32>(mem_ld((qg + bitcast<u32>(c))))) >= epp)) {
        var gamma: f32 = opq(pow(div_cr(opq((opq((opq(3.14159f)) * (opq(n0g)))) * (opq(rhog))), (opq((opq(r)) * (bitcast<f32>(mem_ld((qg + bitcast<u32>(c)))))))), 0.25f));
        zeg = opq((opq((opq((opq((opq((opq(7.2e+02f)) * (opq(n0g)))) * (opq(pow(gamma, opq((-(opq(7.0f))))))))) * (opq((div_cr(rhog, rhor)))))) * (opq((div_cr(rhog, rhor)))))) * (opq(0.224f)));
    }
    if (((bitcast<f32>(mem_ld((qs + bitcast<u32>(c))))) >= epp)) {
        var gamma: f32 = opq(pow(div_cr(opq((opq((opq(3.14159f)) * (opq(n0s)))) * (opq(rhos))), (opq((opq(r)) * (bitcast<f32>(mem_ld((qs + bitcast<u32>(c)))))))), 0.25f));
        zes = opq((opq((opq((opq((opq((opq(7.2e+02f)) * (opq(n0s)))) * (opq(pow(gamma, opq((-(opq(7.0f))))))))) * (opq((div_cr(rhos, rhor)))))) * (opq((div_cr(rhos, rhor)))))) * (opq(0.224f)));
    }
    var z: f32 = opq((opq((opq(zer)) + (opq(zeg)))) + (opq(zes)));
    mem_st((dbz + bitcast<u32>(c)), bitcast<u32>(select(0.0f, opq((opq(1e+01f)) * (opq((log2(opq((opq(z)) * (opq(1e+18f)))) * 0.30103f)))), (z > (1e-18f)))));
}
