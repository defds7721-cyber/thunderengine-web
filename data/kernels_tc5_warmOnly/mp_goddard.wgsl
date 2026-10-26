// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// mp_goddard: сгенерировано, не править руками.

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

const K_MP_CPL: f32 = 4.19e+03f;

const K_MP_CPI: f32 = 2106.0f;

const K_MP_CV: f32 = 717.0f;

const K_MP_CVV: f32 = 1408.5f;

const K_MP_CP: f32 = 1004.0f;

const K_MP_CPV: f32 = 1.87e+03f;

const K_MP_RD: f32 = 287.0f;

const K_MP_RV: f32 = 461.5f;

const K_MP_ROVCP: f32 = 0.28585657f;

const K_MP_LV1: f32 = 2.5e+06f;

const K_MP_LV2: f32 = 0.0f;

const K_MP_LS1: f32 = 2898463.5f;

const K_MP_LS2: f32 = 236.0f;

const K_MP_RP00: f32 = 1e-05f;

const K_MP_RDDCV: f32 = 0.40027893f;

const K_MP_P00: f32 = 1e+05f;

const K_MP_CPDRD: f32 = 3.4982579f;

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

fn f_lookup_lerp(tab_in: u32, temp_in: f32) -> f32 {
    var tab: u32 = tab_in;
    var temp: f32 = temp_in;
    var idx: i32 = i32(temp);
    var f1: f32 = bitcast<f32>(mem_ld((tab + bitcast<u32>(idx))));
    var f2: f32 = bitcast<f32>(mem_ld((tab + bitcast<u32>((idx + 1i)))));
    return opq(fma((opq((opq(f2)) - (opq(f1)))), (opq((opq(temp)) - (opq(f32(idx))))), opq(f1)));
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    var gd: S_GridDims = ld_GridDims(ARG[4]);
    var g: S_GoddardParams = ld_GoddardParams(ARG[5]);
    var th0: u32 = ARG[6];
    var pi0: u32 = ARG[7];
    var rn12a: u32 = ARG[8];
    var rn12b: u32 = ARG[9];
    var rn25a: u32 = ARG[10];
    var pwr81: u32 = ARG[11];
    var pwr2: u32 = ARG[12];
    var rhod: u32 = ARG[13];
    var prs: u32 = ARG[14];
    var pp3d: u32 = ARG[15];
    var th3d: u32 = ARG[16];
    var qv3d: u32 = ARG[17];
    var qc3d: u32 = ARG[18];
    var qr3d: u32 = ARG[19];
    var qi3d: u32 = ARG[20];
    var qs3d: u32 = ARG[21];
    var qg3d: u32 = ARG[22];
    var vtr: u32 = ARG[23];
    var vti: u32 = ARG[24];
    var vts: u32 = ARG[25];
    var vtg: u32 = ARG[26];
    var ablate: u32 = mem_ld(ARG[27]);
    var tid: vec3<u32> = gid;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    var k: i32 = i32(tid.z);
    if ((((i >= gd.nx) || (j >= gd.ny)) || (k >= gd.nz))) {
        return;
    }
    var c: i32 = f_gidx(gd, i, j, k);
    var cmin: f32 = 1e-14f;
    var cmin1: f32 = 1e-12f;
    var r1: f32 = div_cr(1.0f, 1e-09f);
    var d2t: f32 = g.dt;
    var rdt: f32 = g.rdt;
    let _t1 = f_gidx(gd, i, j, 0i);
    var rho0: f32 = opq((opq(0.001f)) * (bitcast<f32>(mem_ld((rhod + bitcast<u32>(_t1))))));
    mem_st((vtr + bitcast<u32>(c)), bitcast<u32>(0.0f));
    mem_st((vts + bitcast<u32>(c)), bitcast<u32>(0.0f));
    mem_st((vtg + bitcast<u32>(c)), bitcast<u32>(0.0f));
    var fv: f32 = rho0;
    var RHO: f32 = opq((opq(0.001f)) * (bitcast<f32>(mem_ld((rhod + bitcast<u32>(c))))));
    var PPI: f32 = opq((bitcast<f32>(mem_ld((pi0 + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((pp3d + bitcast<u32>(c))))));
    var P0: f32 = opq((opq(1e+01f)) * (bitcast<f32>(mem_ld((prs + bitcast<u32>(c))))));
    var PT: f32 = bitcast<f32>(mem_ld((th3d + bitcast<u32>(c))));
    var QV: f32 = bitcast<f32>(mem_ld((qv3d + bitcast<u32>(c))));
    var QC: f32 = bitcast<f32>(mem_ld((qc3d + bitcast<u32>(c))));
    var QR: f32 = bitcast<f32>(mem_ld((qr3d + bitcast<u32>(c))));
    var QI: f32 = bitcast<f32>(mem_ld((qi3d + bitcast<u32>(c))));
    var QS: f32 = bitcast<f32>(mem_ld((qs3d + bitcast<u32>(c))));
    var QG: f32 = bitcast<f32>(mem_ld((qg3d + bitcast<u32>(c))));
    QV = opq(max(QV, cmin1));
    if ((QC < cmin)) {
        QC = 0.0f;
    }
    if ((QR < cmin)) {
        QR = 0.0f;
    }
    if ((QI < cmin)) {
        QI = 0.0f;
    }
    if ((QS < cmin)) {
        QS = 0.0f;
    }
    if ((QG < cmin)) {
        QG = 0.0f;
    }
    var TAIR: f32 = opq((opq((bitcast<f32>(mem_ld((th0 + bitcast<u32>(k))))) + (opq(PT)))) * (opq(PPI)));
    var TAIRC: f32 = opq((opq(TAIR)) - (opq(g.t0k)));
    var tem1: f32 = div_cr(1.0f, sqrt_cr(sqrt_cr(RHO)));
    var tem2: f32 = sqrt_cr(div_cr(fv, RHO));
    var tem3: f32 = div_cr(1.0f, sqrt_cr(RHO));
    var tem4: f32 = sqrt_cr(sqrt_cr(div_cr(fv, RHO)));
    var rrho: f32 = div_cr(1.0f, RHO);
    var rp0: f32 = div_cr(1.0f, P0);
    var dum1: f32 = opq(fma(opq(K_MP_CPL), (opq((opq(QC)) + (opq(QR)))), opq((opq(K_MP_CPI)) * (opq((opq((opq(QI)) + (opq(QS)))) + (opq(QG)))))));
    var cvml: f32 = opq((opq(fma(opq(K_MP_CVV), opq(QV), opq(K_MP_CV)))) + (opq(dum1)));
    var cpml: f32 = opq((opq(fma(opq(K_MP_CPV), opq(QV), opq(K_MP_CP)))) + (opq(dum1)));
    var rmix: f32 = opq(fma(opq(K_MP_RV), opq(QV), opq(K_MP_RD)));
    var ene1: f32 = div_cr(K_MP_CV, (opq((opq((opq(K_MP_CP)) * (opq(cvml)))) * (opq(PPI)))));
    var ene2: f32 = opq((opq((opq((bitcast<f32>(mem_ld((th0 + bitcast<u32>(k))))) + (opq(PT)))) * (opq((div_cr(K_MP_RV, cvml)))))) * (opq((opq(1.0f)) - (opq(div_cr(opq((opq(K_MP_ROVCP)) * (opq(cpml))), rmix))))));
    var lhv: f32 = opq(fma(opq((-(opq(K_MP_LV2)))), opq(TAIR), opq(K_MP_LV1)));
    var lhs: f32 = opq(fma(opq((-(opq(K_MP_LS2)))), opq(TAIR), opq(K_MP_LS1)));
    var lhf: f32 = opq((opq(lhs)) - (opq(lhv)));
    var ZR: f32 = opq((opq((opq(1e+05f)) * (opq(g.zrc)))) * (opq(tem1)));
    var ZS: f32 = opq((opq((opq(1e+05f)) * (opq(g.zsc)))) * (opq(tem1)));
    var ZG: f32 = opq((opq((opq(1e+05f)) * (opq(g.zgc)))) * (opq(tem1)));
    var VR: f32 = 0.0f;
    var VS: f32 = 0.0f;
    var VG: f32 = 0.0f;
    var DD: f32;
    var Y1: f32;
    var Y2: f32;
    var Y3: f32;
    var Y4: f32;
    var Y5: f32;
    var temp: f32;
    if ((QR > cmin)) {
        DD = opq((opq(RHO)) * (opq(QR)));
        Y1 = sqrt_cr(sqrt_cr(DD));
        ZR = div_cr(g.zrc, Y1);
        temp = opq((opq(r1)) * (opq(min(5e-05f, opq(max(0.0f, DD))))));
        VR = opq((opq((opq(g.vrc)) * (opq(tem2)))) * (opq(f_lookup_lerp(pwr2, temp))));
    }
    if ((QS > cmin)) {
        DD = opq((opq(RHO)) * (opq(QS)));
        ZS = div_cr(g.zsc, sqrt_cr(sqrt_cr(DD)));
        VS = opq((opq((opq(g.vsc)) * (opq(tem2)))) * (opq(pow(DD, g.bsq))));
    }
    if ((QG > cmin)) {
        DD = opq((opq(RHO)) * (opq(QG)));
        Y1 = sqrt_cr(sqrt_cr(DD));
        ZG = div_cr(g.zgc, Y1);
        if ((g.ihail == 1i)) {
            VG = opq((opq((opq(g.vgc)) * (opq(tem3)))) * (opq(sqrt_cr(Y1))));
        } else {
            VG = opq((opq((opq(g.vgc)) * (opq(tem2)))) * (opq(pow(DD, g.bgq))));
        }
    }
    var VFR: f32 = VR;
    var VFS: f32 = VS;
    var VFG: f32 = VG;
    Y1 = div_cr(opq((opq((opq(g.c149)) * (opq(TAIR)))) * (opq(sqrt_cr(TAIR)))), (opq((opq(TAIR)) + (opq(1.2e+02f)))));
    temp = opq(min(1.5e+02f, opq(max(0.0f, opq((opq(TAIR)) - (opq(173.15f)))))));
    var DWV: f32 = opq((opq((opq((opq(g.c879)) * (opq(rp0)))) * (opq(TAIR)))) * (opq(f_lookup_lerp(pwr81, temp))));
    var TCA: f32 = opq((opq(g.c141)) * (opq(Y1)));
    var SCV: f32 = opq(pow(div_cr(RHO, (opq((opq((opq(Y1)) * (opq(DWV)))) * (opq(DWV))))), 0.1666667f));
    var tem5: f32 = g.tem5;
    var DEP: f32 = f32(0i);
    var DGACI: f32 = f32(0i);
    var DGACR: f32 = f32(0i);
    var DGACS: f32 = f32(0i);
    var DGACW: f32 = f32(0i);
    var DLT2: f32 = f32(0i);
    var DLT3: f32 = f32(0i);
    var DM: f32 = f32(0i);
    var ESI: f32 = f32(0i);
    var NCI: f32 = f32(0i);
    var PG: f32 = f32(0i);
    var PGACS: f32 = f32(0i);
    var PGAUT: f32 = f32(0i);
    var PGFR: f32 = f32(0i);
    var PGWET: f32 = f32(0i);
    var PIACR: f32 = f32(0i);
    var PIDEP: f32 = f32(0i);
    var PISUB: f32 = f32(0i);
    var PR: f32 = f32(0i);
    var PRACI: f32 = f32(0i);
    var PRACS: f32 = f32(0i);
    var PRACW: f32 = f32(0i);
    var PRAUT: f32 = f32(0i);
    var PRN: f32 = f32(0i);
    var PS: f32 = f32(0i);
    var PSACI: f32 = f32(0i);
    var PSACR: f32 = f32(0i);
    var PSACW: f32 = f32(0i);
    var PSAUT: f32 = f32(0i);
    var PSFI: f32 = f32(0i);
    var PSFW: f32 = f32(0i);
    var QGACR: f32 = f32(0i);
    var QGACW: f32 = f32(0i);
    var QSACR: f32 = f32(0i);
    var QSACW: f32 = f32(0i);
    var QSI: f32 = f32(0i);
    var RSUB1: f32 = f32(0i);
    var RTAIR: f32 = f32(0i);
    var SSI: f32 = f32(0i);
    var WGACI: f32 = f32(0i);
    var WGACR: f32 = f32(0i);
    var WGACS: f32 = f32(0i);
    var r3456: f32 = f32(0i);
    if ((!((ablate & (1u << 0u)) != 0u))) {
        PSAUT = f32(0i);
        PSACI = f32(0i);
        PRACI = f32(0i);
        PIACR = f32(0i);
        PSACW = f32(0i);
        QSACW = f32(0i);
        PRAUT = f32(0i);
        PRACW = f32(0i);
        r3456 = tem2;
        DD = div_cr(1.0f, opq(pow(ZS, g.bs3)));
        if (((QI > cmin) || (QC > cmin))) {
            temp = opq(pow(ZR, opq((-(opq(g.bw3))))));
        }
        if (((QI > cmin) && (TAIR < g.t0k))) {
            var ESI: f32 = opq(exp(0.025f * (opq(TAIRC))));
            PSAUT = opq(max(opq((opq((opq(g.rn1)) * (opq(ESI)))) * (opq((opq(QI)) - (opq(g.bnd1))))), 0.0f));
            PSACI = opq((opq((opq((opq((opq(g.rn3)) * (opq(r3456)))) * (opq(0.1f)))) * (opq(QI)))) * (opq(DD)));
            PRACI = opq((opq((opq((opq(g.rn5)) * (opq(r3456)))) * (opq(QI)))) * (opq(temp)));
            PIACR = opq((opq((opq((opq(g.rn6)) * (opq(r3456)))) * (opq(QI)))) * (opq(pow(ZR, opq((-(opq(g.bw6))))))));
        }
        if ((QC > cmin)) {
            if ((TAIR < g.t0k)) {
                PSACW = opq((opq((opq((opq(g.rn4)) * (opq(r3456)))) * (opq(QC)))) * (opq(DD)));
            } else {
                QSACW = opq((opq((opq((opq(g.rn4)) * (opq(r3456)))) * (opq(QC)))) * (opq(DD)));
            }
            PRACW = opq((opq((opq((opq(g.rn22)) * (opq(tem2)))) * (opq(QC)))) * (opq(temp)));
            if ((g.iautoc == 1i)) {
                Y1 = opq((opq(QC)) - (opq(g.bnd3)));
                if ((Y1 > cmin)) {
                    PRAUT = div_cr(opq((opq((opq(RHO)) * (opq(Y1)))) * (opq(Y1))), (opq((opq(0.00012f)) + (opq(div_cr(g.rn21, Y1))))));
                }
            }
        }
    }
    if ((!((ablate & (1u << 1u)) != 0u))) {
        PSFW = f32(0i);
        PSFI = f32(0i);
        PIDEP = f32(0i);
        PISUB = f32(0i);
        QSI = f32(0i);
        SSI = f32(0i);
        if (((TAIR < g.t0k) && (QI > cmin))) {
            Y1 = opq(max(opq(min(TAIRC, opq((-(opq(1.0f)))))), opq((-(opq(31.0f))))));
            var IT: i32 = i32(abs(Y1));
            Y1 = bitcast<f32>(mem_ld((rn12a + bitcast<u32>((IT - 1i)))));
            Y2 = bitcast<f32>(mem_ld((rn12b + bitcast<u32>((IT - 1i)))));
            PSFW = opq(max(opq((opq((opq((opq(d2t)) * (opq(Y1)))) * (opq((opq((opq(g.rn12)) * (opq(RHO)))) * (opq(QC)))))) * (opq(QI))), 0.0f));
            RTAIR = div_cr(1.0f, (opq((opq(TAIR)) - (opq(g.c76)))));
            Y2 = opq(exp(opq(fma(opq((-(opq(g.c580)))), opq(RTAIR), opq(g.c218)))));
            QSI = opq((opq((opq(g.c380)) * (opq(rp0)))) * (opq(Y2)));
            ESI = opq((opq(g.c610)) * (opq(Y2)));
            SSI = opq((opq(div_cr(QV, QSI))) - (opq(1.0f)));
            NCI = opq(min(opq((opq(g.rn25)) * (opq(exp(opq((opq(g.beta)) * (opq(TAIRC))))))), 1.0f));
            DM = opq((opq(QV)) - (opq(QSI)));
            RSUB1 = opq((opq((opq((opq((opq(g.c580)) * (opq(g.asc)))) * (opq(QSI)))) * (opq(RTAIR)))) * (opq(RTAIR)));
            Y3 = div_cr(1.0f, TAIR);
            DD = opq(fma(opq(Y3), (opq(fma(opq(g.rn30a), opq(Y3), opq((-(opq(g.rn30b))))))), opq(div_cr(opq((opq(g.rn30c)) * (opq(TAIR))), ESI))));
            Y1 = div_cr(opq((opq(206.18f)) * (opq(SSI))), DD);
            DEP = opq((opq(div_cr(DM, (opq((opq(1.0f)) + (opq(RSUB1))))))) * (opq(rdt)));
            PIDEP = opq((opq(Y1)) * (opq(sqrt_cr(opq((opq((opq(NCI)) * (opq(QI)))) * (opq(rrho)))))));
            if ((DM > cmin)) {
                var a2: f32 = 1.0f;
                if (((PIDEP > DEP) && (PIDEP > cmin))) {
                    a2 = div_cr(DEP, PIDEP);
                    PIDEP = DEP;
                }
                PSFI = opq((opq((opq((opq(a2)) * (opq(QI)))) * (opq(Y1)))) * (opq(tem5)));
            } else {
                if ((DM < (opq((-(opq(cmin))))))) {
                    PISUB = opq(max(opq((opq((-(opq(QI))))) * (opq(rdt))), PIDEP));
                    PISUB = opq(min(opq((-(opq(PISUB)))), opq((opq((-(opq(DM))))) * (opq(rdt)))));
                    PIDEP = 0.0f;
                    PSFI = 0.0f;
                } else {
                    PISUB = 0.0f;
                    PIDEP = 0.0f;
                    PSFI = 0.0f;
                }
            }
        }
    }
    if ((!((ablate & (1u << 2u)) != 0u))) {
        DGACS = f32(0i);
        WGACS = f32(0i);
        DGACW = f32(0i);
        DGACR = f32(0i);
        PGACS = f32(0i);
        QGACW = f32(0i);
        QGACR = f32(0i);
        DGACI = f32(0i);
        WGACI = f32(0i);
        PGWET = f32(0i);
        if ((QG > cmin)) {
            var EE1: f32 = select(1.0f, 0.01f, ((opq((opq(QC)) + (opq(QR)))) < 0.0001f));
            var EE2: f32 = 0.09f;
            var EGS: f32 = opq((opq(EE1)) * (opq(exp(0.09f * (opq(TAIRC))))));
            if ((TAIR >= g.t0k)) {
                EGS = 1.0f;
            }
            Y1 = abs(opq((opq(VG)) - (opq(VS))));
            Y2 = opq((opq(ZS)) * (opq(ZG)));
            Y3 = div_cr(5.0f, Y2);
            Y4 = opq((opq((opq(0.08f)) * (opq(Y3)))) * (opq(Y3)));
            Y5 = opq((opq((opq(0.05f)) * (opq(Y3)))) * (opq(Y4)));
            DD = opq((opq(Y1)) * (opq((opq((opq(div_cr(Y3, opq(pow(ZS, 5.0f))))) + (opq(div_cr(Y4, opq(pow(ZS, 3.0f))))))) + (opq(div_cr(Y5, ZS))))));
            PGACS = opq((opq((opq((opq(g.rn9)) * (opq(rrho)))) * (opq(EGS)))) * (opq(DD)));
            DGACS = PGACS;
            WGACS = opq((opq((opq(g.rn9)) * (opq(rrho)))) * (opq(DD)));
            if ((g.ihail == 1i)) {
                Y1 = div_cr(1.0f, (opq((opq(sqrt_cr(ZG))) * (opq(pow(ZG, 3.0f))))));
                DGACW = opq(max(opq((opq((opq((opq(g.rn14)) * (opq(QC)))) * (opq(Y1)))) * (opq(tem3))), 0.0f));
            } else {
                Y1 = opq(pow(ZG, opq((-(opq(g.bg3))))));
                DGACW = opq(max(opq((opq((opq((opq(g.rn14)) * (opq(QC)))) * (opq(Y1)))) * (opq(r3456))), 0.0f));
            }
            QGACW = DGACW;
            Y1 = abs(opq((opq(VG)) - (opq(VR))));
            Y2 = opq((opq(ZR)) * (opq(ZG)));
            Y3 = div_cr(5.0f, Y2);
            Y4 = opq((opq((opq(0.08f)) * (opq(Y3)))) * (opq(Y3)));
            Y5 = opq((opq((opq(0.05f)) * (opq(Y3)))) * (opq(Y4)));
            DD = opq((opq((opq((opq(Y1)) * (opq((opq((opq(div_cr(Y3, opq(pow(ZR, 5.0f))))) + (opq(div_cr(Y4, opq(pow(ZR, 3.0f))))))) + (opq(div_cr(Y5, ZR))))))) * (opq(g.rn16)))) * (opq(rrho)));
            DGACR = opq(max(DD, 0.0f));
            QGACR = DGACR;
            if ((TAIR >= g.t0k)) {
                DGACS = f32(0i);
                WGACS = f32(0i);
                DGACW = f32(0i);
                DGACR = f32(0i);
            } else {
                PGACS = f32(0i);
                QGACW = f32(0i);
                QGACR = f32(0i);
            }
            if (((TAIR < g.t0k) && (TAIR > (opq((opq(g.t0k)) - (opq(4e+01f))))))) {
                if ((g.ihail == 1i)) {
                    Y1 = div_cr(QI, (opq((opq(sqrt_cr(ZG))) * (opq(pow(ZG, 3.0f))))));
                    DGACI = opq((opq((opq(Y1)) * (opq(g.rn15)))) * (opq(tem3)));
                    WGACI = opq((opq((opq(Y1)) * (opq(g.rn15a)))) * (opq(tem3)));
                } else {
                    Y1 = div_cr(QI, opq(pow(ZG, g.bg3)));
                    DGACI = opq((opq((opq(Y1)) * (opq(g.rn15)))) * (opq(r3456)));
                    WGACI = opq((opq((opq(Y1)) * (opq(g.rn15a)))) * (opq(r3456)));
                }
                Y1 = div_cr(1.0f, (opq(fma(opq(g.rn17c), opq(TAIRC), opq(g.alf)))));
                if ((g.ihail == 1i)) {
                    Y3 = opq(fma(opq((opq((opq(SCV)) * (opq(g.rn17a)))) * (opq(tem1))), opq(pow(ZG, opq((-(opq(g.bgh5)))))), opq(div_cr(0.78f, (opq((opq(ZG)) * (opq(ZG))))))));
                } else {
                    Y3 = opq(fma(opq((opq((opq(SCV)) * (opq(g.rn17a)))) * (opq(tem4))), opq(pow(ZG, opq((-(opq(g.bgh5)))))), opq(div_cr(0.78f, (opq((opq(ZG)) * (opq(ZG))))))));
                }
                Y4 = opq(fma(opq((opq((opq(RHO)) * (opq(g.alv)))) * (opq(DWV))), (opq(fma(opq(g.c380), opq(rp0), opq((-(opq(QV))))))), opq((-(opq((opq(TCA)) * (opq(TAIRC))))))));
                DD = opq((opq(Y1)) * (opq(fma(opq((opq((opq(Y4)) * (opq(Y3)))) * (opq(g.rn17))), opq(rrho), opq((opq((opq(WGACI)) + (opq(WGACS)))) * (opq(fma(opq(g.rn17b), opq(TAIRC), opq(g.alf)))))))));
                PGWET = opq(max(DD, 0.0f));
            }
        }
    }
    if ((!((ablate & (1u << 3u)) != 0u))) {
        Y1 = opq((opq(QC)) * (opq(rdt)));
        PSACW = opq(min(Y1, PSACW));
        PRAUT = opq(min(Y1, PRAUT));
        PRACW = opq(min(Y1, PRACW));
        PSFW = opq(min(Y1, PSFW));
        DGACW = opq(min(Y1, DGACW));
        QSACW = opq(min(Y1, QSACW));
        QGACW = opq(min(Y1, QGACW));
        Y1 = opq((opq((opq((opq((opq((opq((opq((opq(PSACW)) + (opq(PRAUT)))) + (opq(PRACW)))) + (opq(PSFW)))) + (opq(DGACW)))) + (opq(QSACW)))) + (opq(QGACW)))) * (opq(d2t)));
        QC = opq((opq(QC)) - (opq(Y1)));
        if ((QC < 0.0f)) {
            var a1: f32 = 1.0f;
            if ((Y1 != 0.0f)) {
                a1 = opq((opq(div_cr(QC, Y1))) + (opq(1.0f)));
            }
            PSACW = opq((opq(PSACW)) * (opq(a1)));
            PRAUT = opq((opq(PRAUT)) * (opq(a1)));
            PRACW = opq((opq(PRACW)) * (opq(a1)));
            PSFW = opq((opq(PSFW)) * (opq(a1)));
            DGACW = opq((opq(DGACW)) * (opq(a1)));
            QSACW = opq((opq(QSACW)) * (opq(a1)));
            QGACW = opq((opq(QGACW)) * (opq(a1)));
            QC = 0.0f;
        }
    }
    if ((!((ablate & (1u << 4u)) != 0u))) {
        WGACR = opq((opq((opq((opq(PGWET)) - (opq(DGACW)))) - (opq(WGACI)))) - (opq(WGACS)));
        Y2 = opq((opq((opq((opq(DGACW)) + (opq(DGACI)))) + (opq(DGACR)))) + (opq(DGACS)));
        if ((PGWET >= Y2)) {
            WGACR = f32(0i);
            WGACI = f32(0i);
            WGACS = f32(0i);
        } else {
            DGACR = f32(0i);
            DGACI = f32(0i);
            DGACS = f32(0i);
        }
    }
    if ((!((ablate & (1u << 5u)) != 0u))) {
        Y1 = opq((opq(QI)) * (opq(rdt)));
        PSAUT = opq(min(Y1, PSAUT));
        PSACI = opq(min(Y1, PSACI));
        PRACI = opq(min(Y1, PRACI));
        PSFI = opq(min(Y1, PSFI));
        DGACI = opq(min(Y1, DGACI));
        WGACI = opq(min(Y1, WGACI));
        Y1 = opq((opq((opq((opq((opq((opq((opq((opq(PSAUT)) + (opq(PSACI)))) + (opq(PRACI)))) + (opq(PSFI)))) + (opq(DGACI)))) + (opq(WGACI)))) + (opq(PISUB)))) * (opq(d2t)));
        QI = opq(fma(opq(PIDEP), opq(d2t), opq((opq(QI)) - (opq(Y1)))));
        if ((QI < 0.0f)) {
            var a2: f32 = 1.0f;
            if ((Y1 != 0.0f)) {
                a2 = opq((opq(div_cr(QI, Y1))) + (opq(1.0f)));
            }
            PSAUT = opq((opq(PSAUT)) * (opq(a2)));
            PSACI = opq((opq(PSACI)) * (opq(a2)));
            PRACI = opq((opq(PRACI)) * (opq(a2)));
            PSFI = opq((opq(PSFI)) * (opq(a2)));
            DGACI = opq((opq(DGACI)) * (opq(a2)));
            WGACI = opq((opq(WGACI)) * (opq(a2)));
            PISUB = opq((opq(PISUB)) * (opq(a2)));
            QI = 0.0f;
        }
    }
    if ((!((ablate & (1u << 6u)) != 0u))) {
        DLT3 = 0.0f;
        DLT2 = 0.0f;
        if ((TAIR < g.t0k)) {
            if ((QR < 0.0001f)) {
                DLT3 = 1.0f;
                DLT2 = 1.0f;
            }
            if ((QS >= 0.0001f)) {
                DLT2 = 0.0f;
            }
        }
        PR = opq((opq((opq((opq((opq(QSACW)) + (opq(PRAUT)))) + (opq(PRACW)))) + (opq(QGACW)))) * (opq(d2t)));
        PS = opq((opq(fma(opq(DLT3), opq(PRACI), opq((opq((opq((opq((opq(PSAUT)) + (opq(PSACI)))) + (opq(PSACW)))) + (opq(PSFW)))) + (opq(PSFI)))))) * (opq(d2t)));
        PG = opq((opq((opq((opq(fma((opq((opq(1.0f)) - (opq(DLT3)))), opq(PRACI), opq(DGACI)))) + (opq(WGACI)))) + (opq(DGACW)))) * (opq(d2t)));
        PRACS = f32(0i);
        PSACR = f32(0i);
        QSACR = f32(0i);
        PGFR = f32(0i);
        PGAUT = f32(0i);
        if ((QR > cmin)) {
            Y1 = abs(opq((opq(VR)) - (opq(VS))));
            Y2 = opq((opq(ZR)) * (opq(ZS)));
            Y3 = div_cr(5.0f, Y2);
            Y4 = opq((opq((opq(0.08f)) * (opq(Y3)))) * (opq(Y3)));
            Y5 = opq((opq((opq(0.05f)) * (opq(Y3)))) * (opq(Y4)));
            PRACS = opq((opq((opq((opq(g.rn7)) * (opq(rrho)))) * (opq(Y1)))) * (opq((opq((opq(div_cr(Y3, opq(pow(ZS, 5.0f))))) + (opq(div_cr(Y4, opq(pow(ZS, 3.0f))))))) + (opq(div_cr(Y5, ZS))))));
            PSACR = opq((opq((opq((opq(g.rn8)) * (opq(rrho)))) * (opq(Y1)))) * (opq((opq((opq(div_cr(Y3, opq(pow(ZR, 5.0f))))) + (opq(div_cr(Y4, opq(pow(ZR, 3.0f))))))) + (opq(div_cr(Y5, ZR))))));
            QSACR = PSACR;
            if ((TAIR >= g.t0k)) {
                PRACS = f32(0i);
                PSACR = f32(0i);
            } else {
                QSACR = f32(0i);
            }
            if ((TAIR < g.t0k)) {
                Y2 = opq(exp(opq((opq(g.rn18a)) * (opq((opq(g.t0k)) - (opq(TAIR)))))));
                PGFR = opq(max(div_cr(opq((opq((opq((opq(Y2)) - (opq(1.0f)))) * (opq(g.rn18)))) * (opq(rrho))), opq(pow(ZR, 7.0f))), 0.0f));
            }
        }
    }
    if ((!((ablate & (1u << 7u)) != 0u))) {
        Y1 = opq((opq(QR)) * (opq(rdt)));
        Y2 = opq((opq((-(opq(QG))))) * (opq(rdt)));
        PIACR = opq(min(Y1, PIACR));
        DGACR = opq(min(Y1, DGACR));
        WGACR = opq(min(Y1, WGACR));
        WGACR = opq(max(Y2, WGACR));
        PSACR = opq(min(Y1, PSACR));
        PGFR = opq(min(Y1, PGFR));
        var del: f32 = select(0.0f, 1.0f, (WGACR < 0.0f));
        Y1 = opq((opq((opq((opq(fma((opq((opq(1.0f)) - (opq(del)))), opq(WGACR), opq((opq(PIACR)) + (opq(DGACR)))))) + (opq(PSACR)))) + (opq(PGFR)))) * (opq(d2t)));
        QR = opq(fma(opq((-(opq((opq(del)) * (opq(WGACR)))))), opq(d2t), opq((opq((opq(QR)) + (opq(PR)))) - (opq(Y1)))));
        if ((QR < 0.0f)) {
            var a1: f32 = 1.0f;
            if ((Y1 != 0.0f)) {
                a1 = opq((opq(div_cr(QR, Y1))) + (opq(1.0f)));
            }
            PIACR = opq((opq(PIACR)) * (opq(a1)));
            DGACR = opq((opq(DGACR)) * (opq(a1)));
            if ((WGACR > 0.0f)) {
                WGACR = opq((opq(WGACR)) * (opq(a1)));
            }
            PGFR = opq((opq(PGFR)) * (opq(a1)));
            PSACR = opq((opq(PSACR)) * (opq(a1)));
            QR = 0.0f;
        }
        PRN = opq((opq(d2t)) * (opq((opq(fma((opq((opq(1.0f)) - (opq(DLT2)))), opq(PSACR), opq((opq(fma((opq((opq(1.0f)) - (opq(DLT3)))), opq(PIACR), opq(DGACR)))) + (opq(WGACR)))))) + (opq(PGFR)))));
        PS = opq(fma(opq(d2t), (opq(fma(opq(DLT3), opq(PIACR), opq((opq(DLT2)) * (opq(PSACR)))))), opq(PS)));
    }
    if ((!((ablate & (1u << 8u)) != 0u))) {
        Y1 = opq((opq(QS)) * (opq(rdt)));
        PGACS = opq(min(Y1, PGACS));
        DGACS = opq(min(Y1, DGACS));
        WGACS = opq(min(Y1, WGACS));
        PGAUT = opq(min(Y1, PGAUT));
        PRACS = opq(min(Y1, PRACS));
        PRACS = opq((opq((opq(1.0f)) - (opq(DLT2)))) * (opq(PRACS)));
        var PSN: f32 = opq((opq(d2t)) * (opq((opq((opq((opq((opq(PGACS)) + (opq(DGACS)))) + (opq(WGACS)))) + (opq(PGAUT)))) + (opq(PRACS)))));
        QS = opq((opq((opq(QS)) + (opq(PS)))) - (opq(PSN)));
        if ((QS < 0.0f)) {
            var a2: f32 = 1.0f;
            if ((PSN != 0.0f)) {
                a2 = opq((opq(div_cr(QS, PSN))) + (opq(1.0f)));
            }
            PGACS = opq((opq(PGACS)) * (opq(a2)));
            DGACS = opq((opq(DGACS)) * (opq(a2)));
            WGACS = opq((opq(WGACS)) * (opq(a2)));
            PGAUT = opq((opq(PGAUT)) * (opq(a2)));
            PRACS = opq((opq(PRACS)) * (opq(a2)));
            PSN = opq((opq(PSN)) * (opq(a2)));
            QS = 0.0f;
        }
        Y2 = opq((opq(d2t)) * (opq((opq((opq((opq((opq((opq((opq((opq(PSACW)) + (opq(PSFW)))) + (opq(DGACW)))) + (opq(PIACR)))) + (opq(DGACR)))) + (opq(WGACR)))) + (opq(PSACR)))) + (opq(PGFR)))));
        PT = opq(fma(opq((opq(lhf)) * (opq(ene1))), opq(Y2), opq(PT)));
        QG = opq((opq((opq((opq(QG)) + (opq(PG)))) + (opq(PRN)))) + (opq(PSN)));
    }
    if ((!((ablate & (1u << 9u)) != 0u))) {
        var PSMLT: f32 = f32(0i);
        var PGMLT: f32 = f32(0i);
        TAIR = opq((opq((bitcast<f32>(mem_ld((th0 + bitcast<u32>(k))))) + (opq(PT)))) * (opq(PPI)));
        r3456 = tem2;
        if (((TAIR >= g.t0k) && ((opq((opq(QS)) + (opq(QG)))) > cmin))) {
            TAIRC = opq((opq(TAIR)) - (opq(g.t0k)));
            Y1 = opq(fma(opq(TCA), opq(TAIRC), opq((-(opq((opq((opq((opq(RHO)) * (opq(g.alv)))) * (opq(DWV)))) * (opq(fma(opq(g.c380), opq(rp0), opq((-(opq(QV)))))))))))));
            Y2 = opq(fma(opq((opq((opq(g.rn101)) * (opq(tem4)))) * (opq(SCV))), opq(pow(ZS, opq((-(opq(g.bsh5)))))), opq(div_cr(0.78f, (opq((opq(ZS)) * (opq(ZS))))))));
            var R11RT: f32 = opq((opq((opq(g.rn11)) * (opq(d2t)))) * (opq(rrho)));
            DD = opq(fma(opq((opq(R11RT)) * (opq(Y1))), opq(Y2), opq((opq((opq(g.r11at)) * (opq(TAIRC)))) * (opq((opq(QSACW)) + (opq(QSACR)))))));
            PSMLT = opq(max(0.0f, opq(min(DD, QS))));
            if ((g.ihail == 1i)) {
                Y3 = opq(fma(opq((opq((opq(SCV)) * (opq(g.rn19a)))) * (opq(tem1))), opq(pow(ZG, opq((-(opq(g.bgh5)))))), opq(div_cr(0.78f, (opq((opq(ZG)) * (opq(ZG))))))));
            } else {
                Y3 = opq(fma(opq((opq((opq(SCV)) * (opq(g.rn19a)))) * (opq(tem4))), opq(pow(ZG, opq((-(opq(g.bgh5)))))), opq(div_cr(0.78f, (opq((opq(ZG)) * (opq(ZG))))))));
            }
            var DD1: f32 = opq(fma(opq((opq((opq((opq(Y1)) * (opq(Y3)))) * (opq(g.rn19)))) * (opq(d2t))), opq(rrho), opq((opq((opq(g.r19bt)) * (opq(TAIRC)))) * (opq((opq(QGACW)) + (opq(QGACR)))))));
            PGMLT = opq(max(0.0f, opq(min(DD1, QG))));
            PT = opq(fma(opq((-(opq((opq(lhf)) * (opq(ene1)))))), (opq((opq(PSMLT)) + (opq(PGMLT)))), opq(PT)));
            QR = opq((opq((opq(QR)) + (opq(PSMLT)))) + (opq(PGMLT)));
            QS = opq((opq(QS)) - (opq(PSMLT)));
            QG = opq((opq(QG)) - (opq(PGMLT)));
        }
    }
    if ((!((ablate & (1u << 10u)) != 0u))) {
        if ((QC <= cmin)) {
            QC = 0.0f;
        }
        if ((QI <= cmin)) {
            QI = 0.0f;
        }
        var PIHOM: f32 = 0.0f;
        var PIMLT: f32 = 0.0f;
        var PIDW: f32 = 0.0f;
        TAIR = opq((opq((bitcast<f32>(mem_ld((th0 + bitcast<u32>(k))))) + (opq(PT)))) * (opq(PPI)));
        if (((opq((opq(TAIR)) - (opq(g.t00k)))) <= 0.0f)) {
            PIHOM = QC;
        }
        if (((opq((opq(TAIR)) - (opq(g.t0k)))) >= 0.0f)) {
            PIMLT = QI;
        }
        if ((((TAIR < g.t0k) && (TAIR > g.t00k)) && (QC > cmin))) {
            TAIRC = opq((opq(TAIR)) - (opq(g.t0k)));
            Y1 = opq(max(opq(min(TAIRC, opq((-(opq(1.0f)))))), opq((-(opq(31.0f))))));
            Y2 = bitcast<f32>(mem_ld((rn25a + bitcast<u32>(((i32(abs(Y1))) - 1i)))));
            Y3 = opq(min(opq((opq(g.rn25)) * (opq(exp(opq((opq(g.beta)) * (opq(TAIRC))))))), 1.0f));
            PIDW = opq(min(opq((opq((opq((opq(Y2)) * (opq(Y3)))) * (opq(d2t)))) * (opq(rrho))), QC));
        }
        Y1 = opq((opq((opq(PIHOM)) - (opq(PIMLT)))) + (opq(PIDW)));
        PT = opq(fma(opq((opq(fma(opq(lhs), opq(ene1), opq((-(opq(ene2))))))) * (opq((opq(PIDEP)) - (opq(PISUB))))), opq(d2t), opq(fma(opq((opq(lhf)) * (opq(ene1))), opq(Y1), opq(PT)))));
        QV = opq(fma(opq((-(opq((opq(PIDEP)) - (opq(PISUB)))))), opq(d2t), opq(QV)));
        QC = opq((opq(QC)) - (opq(Y1)));
        QI = opq((opq(QI)) + (opq(Y1)));
    }
    if ((!((ablate & (1u << 11u)) != 0u))) {
        var PINT: f32 = 0.0f;
        TAIR = opq((opq((bitcast<f32>(mem_ld((th0 + bitcast<u32>(k))))) + (opq(PT)))) * (opq(PPI)));
        if ((QI <= cmin)) {
            QI = 0.0f;
        }
        if ((TAIR < g.t0k)) {
            TAIRC = opq((opq(TAIR)) - (opq(g.t0k)));
            RTAIR = div_cr(1.0f, (opq((opq(TAIR)) - (opq(g.c76)))));
            Y2 = opq(exp(opq(fma(opq((-(opq(g.c580)))), opq(RTAIR), opq(g.c218)))));
            QSI = opq((opq((opq(g.c380)) * (opq(rp0)))) * (opq(Y2)));
            SSI = opq((opq(div_cr(QV, QSI))) - (opq(1.0f)));
            NCI = opq(min(opq((opq(g.rn25)) * (opq(exp(opq((opq(g.beta)) * (opq(TAIRC))))))), 1.0f));
            DD = opq(max(opq(fma(opq((opq(1e-09f)) * (opq(NCI))), opq(rrho), opq((-(opq(div_cr(opq((opq(QI)) * (opq(1e-09f))), g.ami50))))))), 0.0f));
            DM = opq(max(opq((opq(QV)) - (opq(QSI))), 0.0f));
            RSUB1 = opq((opq((opq((opq((opq(g.c580)) * (opq(g.asc)))) * (opq(QSI)))) * (opq(RTAIR)))) * (opq(RTAIR)));
            PINT = opq(min(DD, DM));
            DEP = div_cr(DM, (opq((opq(1.0f)) + (opq(RSUB1)))));
            PINT = opq(min(PINT, DEP));
            if ((PINT <= cmin)) {
                PINT = 0.0f;
            }
            PT = opq(fma((opq(fma(opq(lhs), opq(ene1), opq((-(opq(ene2))))))), opq(PINT), opq(PT)));
            QV = opq((opq(QV)) - (opq(PINT)));
            QI = opq((opq(QI)) + (opq(PINT)));
        }
    }
    if ((!((ablate & (1u << 12u)) != 0u))) {
        var PSDEP: f32 = f32(0i);
        var PSSUB: f32 = f32(0i);
        var PGSUB: f32 = f32(0i);
        r3456 = tem2;
        TAIR = opq((opq((bitcast<f32>(mem_ld((th0 + bitcast<u32>(k))))) + (opq(PT)))) * (opq(PPI)));
        if (((opq((opq(QS)) + (opq(QG)))) > cmin)) {
            if ((QS < cmin)) {
                QS = 0.0f;
            }
            if ((QG < cmin)) {
                QG = 0.0f;
            }
            RTAIR = div_cr(1.0f, (opq((opq(TAIR)) - (opq(g.c76)))));
            QSI = opq((opq((opq(g.c380)) * (opq(rp0)))) * (opq(exp(opq(fma(opq((-(opq(g.c580)))), opq(RTAIR), opq(g.c218)))))));
            SSI = opq((opq(div_cr(QV, QSI))) - (opq(1.0f)));
            Y1 = opq((opq(div_cr(opq((opq(g.rn10a)) * (opq(RHO))), (opq((opq((opq(TCA)) * (opq(TAIR)))) * (opq(TAIR))))))) + (opq(div_cr(1.0f, (opq((opq(DWV)) * (opq(QSI))))))));
            Y2 = opq(fma(opq((opq((opq(g.rn101)) * (opq(tem4)))) * (opq(SCV))), opq(pow(ZS, opq((-(opq(g.bsh5)))))), opq(div_cr(0.78f, (opq((opq(ZS)) * (opq(ZS))))))));
            PSDEP = div_cr(opq((opq((opq(g.r10t)) * (opq(SSI)))) * (opq(Y2))), Y1);
            PSSUB = PSDEP;
            PSDEP = opq(max(PSDEP, 0.0f));
            PSSUB = opq(max(opq((-(opq(QS)))), opq(min(PSSUB, 0.0f))));
            if ((g.ihail == 1i)) {
                Y2 = opq(fma(opq((opq((opq(SCV)) * (opq(g.rn20b)))) * (opq(tem1))), opq(pow(ZG, opq((-(opq(g.bgh5)))))), opq(div_cr(0.78f, (opq((opq(ZG)) * (opq(ZG))))))));
            } else {
                Y2 = opq(fma(opq((opq((opq(SCV)) * (opq(g.rn20b)))) * (opq(tem4))), opq(pow(ZG, opq((-(opq(g.bgh5)))))), opq(div_cr(0.78f, (opq((opq(ZG)) * (opq(ZG))))))));
            }
            PGSUB = div_cr(opq((opq((opq(g.r20t)) * (opq(SSI)))) * (opq(Y2))), Y1);
            DM = opq((opq(QV)) - (opq(QSI)));
            RSUB1 = opq((opq((opq((opq((opq(g.c580)) * (opq(g.asc)))) * (opq(QSI)))) * (opq(RTAIR)))) * (opq(RTAIR)));
            Y1 = div_cr(DM, (opq((opq(1.0f)) + (opq(RSUB1)))));
            PSDEP = opq(min(PSDEP, opq(max(Y1, 0.0f))));
            Y2 = opq(min(Y1, 0.0f));
            PSSUB = opq(max(PSSUB, Y2));
            DD = opq(max(opq((opq((-(opq(Y2))))) - (opq(QS))), 0.0f));
            PGSUB = opq(min(opq(min(DD, QG)), opq(max(PGSUB, 0.0f))));
            var DLT1: f32 = select(0.0f, 1.0f, ((opq((opq((opq(QC)) + (opq(QI)))) - (opq(1e-05f)))) >= 0.0f));
            PSDEP = opq((opq(DLT1)) * (opq(PSDEP)));
            PSSUB = opq((opq((opq(1.0f)) - (opq(DLT1)))) * (opq(PSSUB)));
            PGSUB = opq((opq((opq(1.0f)) - (opq(DLT1)))) * (opq(PGSUB)));
            PT = opq(fma((opq(fma(opq(lhs), opq(ene1), opq((-(opq(ene2))))))), (opq((opq((opq(PSDEP)) + (opq(PSSUB)))) - (opq(PGSUB)))), opq(PT)));
            QV = opq((opq((opq((opq(QV)) + (opq(PGSUB)))) - (opq(PSSUB)))) - (opq(PSDEP)));
            QS = opq((opq((opq(QS)) + (opq(PSDEP)))) + (opq(PSSUB)));
            QG = opq((opq(QG)) - (opq(PGSUB)));
        }
    }
    if ((!((ablate & (1u << 13u)) != 0u))) {
        var ERN: f32 = 0.0f;
        if ((QR > cmin)) {
            TAIR = opq((opq((bitcast<f32>(mem_ld((th0 + bitcast<u32>(k))))) + (opq(PT)))) * (opq(PPI)));
            RTAIR = div_cr(1.0f, (opq((opq(TAIR)) - (opq(g.c358)))));
            var QSW: f32 = opq((opq((opq(g.c380)) * (opq(rp0)))) * (opq(exp(opq(fma(opq((-(opq(g.c409)))), opq(RTAIR), opq(g.c172)))))));
            var SSW: f32 = opq((opq(div_cr(QV, QSW))) - (opq(1.0f)));
            DM = opq((opq(QV)) - (opq(QSW)));
            RSUB1 = opq((opq((opq((opq((opq(g.c409)) * (opq(g.avc)))) * (opq(QSW)))) * (opq(RTAIR)))) * (opq(RTAIR)));
            var DD1: f32 = opq(max(div_cr(opq((-(opq(DM)))), (opq((opq(1.0f)) + (opq(RSUB1))))), 0.0f));
            Y1 = opq(fma(opq((opq((opq(g.rn23a)) * (opq(tem4)))) * (opq(SCV))), opq(pow(ZR, opq((-(opq(g.bwh5)))))), opq(div_cr(0.78f, (opq((opq(ZR)) * (opq(ZR))))))));
            Y2 = opq((opq(div_cr(opq((opq(g.rn23b)) * (opq(RHO))), (opq((opq((opq(TCA)) * (opq(TAIR)))) * (opq(TAIR))))))) + (opq(div_cr(1.0f, (opq((opq(DWV)) * (opq(QSW))))))));
            ERN = div_cr(opq((opq((opq(g.r23t)) * (opq(SSW)))) * (opq(Y1))), Y2);
            ERN = opq(min(opq(min(DD1, QR)), opq(max(ERN, 0.0f))));
            PT = opq(fma(opq((-(opq(fma(opq(lhv), opq(ene1), opq((-(opq(ene2))))))))), opq(ERN), opq(PT)));
            QV = opq((opq(QV)) + (opq(ERN)));
            QR = opq((opq(QR)) - (opq(ERN)));
        }
    }
    if ((QC <= cmin)) {
        QC = 0.0f;
    }
    if ((QR <= cmin)) {
        QR = 0.0f;
    }
    if ((QI <= cmin)) {
        QI = 0.0f;
    }
    if ((QS <= cmin)) {
        QS = 0.0f;
    }
    if ((QG <= cmin)) {
        QG = 0.0f;
    }
    var dq: f32 = opq((opq((opq((opq((opq((opq(abs(opq((opq(QV)) - (bitcast<f32>(mem_ld((qv3d + bitcast<u32>(c))))))))) + (opq(abs(opq((opq(QC)) - (bitcast<f32>(mem_ld((qc3d + bitcast<u32>(c))))))))))) + (opq(abs(opq((opq(QR)) - (bitcast<f32>(mem_ld((qr3d + bitcast<u32>(c))))))))))) + (opq(abs(opq((opq(QI)) - (bitcast<f32>(mem_ld((qi3d + bitcast<u32>(c))))))))))) + (opq(abs(opq((opq(QS)) - (bitcast<f32>(mem_ld((qs3d + bitcast<u32>(c))))))))))) + (opq(abs(opq((opq(QG)) - (bitcast<f32>(mem_ld((qg3d + bitcast<u32>(c))))))))));
    if ((dq > (1e-07f))) {
        var pp: f32 = opq((opq(pow(opq((opq((opq((bitcast<f32>(mem_ld((rhod + bitcast<u32>(c))))) * (opq(fma(opq(K_MP_RV), opq(QV), opq(K_MP_RD)))))) * (opq((bitcast<f32>(mem_ld((th0 + bitcast<u32>(k))))) + (opq(PT)))))) * (opq(K_MP_RP00))), K_MP_RDDCV))) - (bitcast<f32>(mem_ld((pi0 + bitcast<u32>(k))))));
        mem_st((pp3d + bitcast<u32>(c)), bitcast<u32>(pp));
        mem_st((prs + bitcast<u32>(c)), bitcast<u32>(opq((opq(K_MP_P00)) * (opq(pow(opq((bitcast<f32>(mem_ld((pi0 + bitcast<u32>(k))))) + (opq(pp))), K_MP_CPDRD))))));
    }
    mem_st((th3d + bitcast<u32>(c)), bitcast<u32>(PT));
    mem_st((qv3d + bitcast<u32>(c)), bitcast<u32>(QV));
    mem_st((qc3d + bitcast<u32>(c)), bitcast<u32>(QC));
    mem_st((qr3d + bitcast<u32>(c)), bitcast<u32>(QR));
    mem_st((qi3d + bitcast<u32>(c)), bitcast<u32>(QI));
    mem_st((qs3d + bitcast<u32>(c)), bitcast<u32>(QS));
    mem_st((qg3d + bitcast<u32>(c)), bitcast<u32>(QG));
    mem_st((vtr + bitcast<u32>(c)), bitcast<u32>(opq((opq(VFR)) * (opq(0.01f)))));
    mem_st((vts + bitcast<u32>(c)), bitcast<u32>(opq((opq(VFS)) * (opq(0.01f)))));
    mem_st((vtg + bitcast<u32>(c)), bitcast<u32>(opq((opq(VFG)) * (opq(0.01f)))));
    mem_st((vti + bitcast<u32>(c)), bitcast<u32>(0.2f));
}
