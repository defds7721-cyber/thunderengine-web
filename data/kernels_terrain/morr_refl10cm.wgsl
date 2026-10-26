// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// morr_refl10cm: сгенерировано, не править руками.

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


struct S_MorrParams {
    nx: i32,
    ny: i32,
    nz: i32,
    strideJ: i32,
    strideK: i32,
    dt: f32,
    rdt: f32,
    tsmall: f32,
    ai: f32,
    ac: f32,
    as_: f32,
    ar: f32,
    ag: f32,
    bi: f32,
    bc: f32,
    bs: f32,
    br: f32,
    bg: f32,
    r: f32,
    rv: f32,
    cp: f32,
    ep2: f32,
    cv: f32,
    cvv: f32,
    cpv: f32,
    cpl: f32,
    cpi: f32,
    lv1: f32,
    lv2: f32,
    ls1: f32,
    ls2: f32,
    tmelt: f32,
    rhosu: f32,
    rhow: f32,
    rhoi: f32,
    rhosn: f32,
    rhog: f32,
    aimm: f32,
    bimm: f32,
    dcs: f32,
    mi0: f32,
    mg0: f32,
    f1s: f32,
    f2s: f32,
    f1r: f32,
    f2r: f32,
    g: f32,
    qsmall: f32,
    qthr: f32,
    cpw: f32,
    ci: f32,
    di: f32,
    cs: f32,
    ds: f32,
    cg: f32,
    dg: f32,
    mmult: f32,
    lammaxi: f32,
    lammini: f32,
    lammaxr: f32,
    lamminr: f32,
    lammaxs: f32,
    lammins: f32,
    lammaxg: f32,
    lamming: f32,
    dB: f32,
    ndcnst: f32,
    pi: f32,
    drizzleVt: f32,
    cons: array<f32, 42>,
    dnu: array<f32, 16>,
}

struct S_MorrRadarHead {
    mw: vec2<f32>,
    mi: vec2<f32>,
    kw: f32,
    pi5: f32,
    lamda4: f32,
    zfac_s: f32,
    zfac_g: f32,
    ocms: f32,
    obms: f32,
    ocmg: f32,
    obmg: f32,
    pad: f32,
}

struct S_MorrRadarBin {
    D: f32,
    dt: f32,
    x: f32,
    vg: f32,
    rhog: f32,
    grenz: f32,
}

fn ld_MorrParams(o: u32) -> S_MorrParams {
    var s: S_MorrParams;
    s.nx = bitcast<i32>(mem_ld((o + 0u)));
    s.ny = bitcast<i32>(mem_ld((o + 1u)));
    s.nz = bitcast<i32>(mem_ld((o + 2u)));
    s.strideJ = bitcast<i32>(mem_ld((o + 3u)));
    s.strideK = bitcast<i32>(mem_ld((o + 4u)));
    s.dt = bitcast<f32>(mem_ld((o + 5u)));
    s.rdt = bitcast<f32>(mem_ld((o + 6u)));
    s.tsmall = bitcast<f32>(mem_ld((o + 7u)));
    s.ai = bitcast<f32>(mem_ld((o + 8u)));
    s.ac = bitcast<f32>(mem_ld((o + 9u)));
    s.as_ = bitcast<f32>(mem_ld((o + 10u)));
    s.ar = bitcast<f32>(mem_ld((o + 11u)));
    s.ag = bitcast<f32>(mem_ld((o + 12u)));
    s.bi = bitcast<f32>(mem_ld((o + 13u)));
    s.bc = bitcast<f32>(mem_ld((o + 14u)));
    s.bs = bitcast<f32>(mem_ld((o + 15u)));
    s.br = bitcast<f32>(mem_ld((o + 16u)));
    s.bg = bitcast<f32>(mem_ld((o + 17u)));
    s.r = bitcast<f32>(mem_ld((o + 18u)));
    s.rv = bitcast<f32>(mem_ld((o + 19u)));
    s.cp = bitcast<f32>(mem_ld((o + 20u)));
    s.ep2 = bitcast<f32>(mem_ld((o + 21u)));
    s.cv = bitcast<f32>(mem_ld((o + 22u)));
    s.cvv = bitcast<f32>(mem_ld((o + 23u)));
    s.cpv = bitcast<f32>(mem_ld((o + 24u)));
    s.cpl = bitcast<f32>(mem_ld((o + 25u)));
    s.cpi = bitcast<f32>(mem_ld((o + 26u)));
    s.lv1 = bitcast<f32>(mem_ld((o + 27u)));
    s.lv2 = bitcast<f32>(mem_ld((o + 28u)));
    s.ls1 = bitcast<f32>(mem_ld((o + 29u)));
    s.ls2 = bitcast<f32>(mem_ld((o + 30u)));
    s.tmelt = bitcast<f32>(mem_ld((o + 31u)));
    s.rhosu = bitcast<f32>(mem_ld((o + 32u)));
    s.rhow = bitcast<f32>(mem_ld((o + 33u)));
    s.rhoi = bitcast<f32>(mem_ld((o + 34u)));
    s.rhosn = bitcast<f32>(mem_ld((o + 35u)));
    s.rhog = bitcast<f32>(mem_ld((o + 36u)));
    s.aimm = bitcast<f32>(mem_ld((o + 37u)));
    s.bimm = bitcast<f32>(mem_ld((o + 38u)));
    s.dcs = bitcast<f32>(mem_ld((o + 39u)));
    s.mi0 = bitcast<f32>(mem_ld((o + 40u)));
    s.mg0 = bitcast<f32>(mem_ld((o + 41u)));
    s.f1s = bitcast<f32>(mem_ld((o + 42u)));
    s.f2s = bitcast<f32>(mem_ld((o + 43u)));
    s.f1r = bitcast<f32>(mem_ld((o + 44u)));
    s.f2r = bitcast<f32>(mem_ld((o + 45u)));
    s.g = bitcast<f32>(mem_ld((o + 46u)));
    s.qsmall = bitcast<f32>(mem_ld((o + 47u)));
    s.qthr = bitcast<f32>(mem_ld((o + 48u)));
    s.cpw = bitcast<f32>(mem_ld((o + 49u)));
    s.ci = bitcast<f32>(mem_ld((o + 50u)));
    s.di = bitcast<f32>(mem_ld((o + 51u)));
    s.cs = bitcast<f32>(mem_ld((o + 52u)));
    s.ds = bitcast<f32>(mem_ld((o + 53u)));
    s.cg = bitcast<f32>(mem_ld((o + 54u)));
    s.dg = bitcast<f32>(mem_ld((o + 55u)));
    s.mmult = bitcast<f32>(mem_ld((o + 56u)));
    s.lammaxi = bitcast<f32>(mem_ld((o + 57u)));
    s.lammini = bitcast<f32>(mem_ld((o + 58u)));
    s.lammaxr = bitcast<f32>(mem_ld((o + 59u)));
    s.lamminr = bitcast<f32>(mem_ld((o + 60u)));
    s.lammaxs = bitcast<f32>(mem_ld((o + 61u)));
    s.lammins = bitcast<f32>(mem_ld((o + 62u)));
    s.lammaxg = bitcast<f32>(mem_ld((o + 63u)));
    s.lamming = bitcast<f32>(mem_ld((o + 64u)));
    s.dB = bitcast<f32>(mem_ld((o + 65u)));
    s.ndcnst = bitcast<f32>(mem_ld((o + 66u)));
    s.pi = bitcast<f32>(mem_ld((o + 67u)));
    s.drizzleVt = bitcast<f32>(mem_ld((o + 68u)));
    s.cons[0] = bitcast<f32>(mem_ld((o + 69u)));
    s.cons[1] = bitcast<f32>(mem_ld((o + 70u)));
    s.cons[2] = bitcast<f32>(mem_ld((o + 71u)));
    s.cons[3] = bitcast<f32>(mem_ld((o + 72u)));
    s.cons[4] = bitcast<f32>(mem_ld((o + 73u)));
    s.cons[5] = bitcast<f32>(mem_ld((o + 74u)));
    s.cons[6] = bitcast<f32>(mem_ld((o + 75u)));
    s.cons[7] = bitcast<f32>(mem_ld((o + 76u)));
    s.cons[8] = bitcast<f32>(mem_ld((o + 77u)));
    s.cons[9] = bitcast<f32>(mem_ld((o + 78u)));
    s.cons[10] = bitcast<f32>(mem_ld((o + 79u)));
    s.cons[11] = bitcast<f32>(mem_ld((o + 80u)));
    s.cons[12] = bitcast<f32>(mem_ld((o + 81u)));
    s.cons[13] = bitcast<f32>(mem_ld((o + 82u)));
    s.cons[14] = bitcast<f32>(mem_ld((o + 83u)));
    s.cons[15] = bitcast<f32>(mem_ld((o + 84u)));
    s.cons[16] = bitcast<f32>(mem_ld((o + 85u)));
    s.cons[17] = bitcast<f32>(mem_ld((o + 86u)));
    s.cons[18] = bitcast<f32>(mem_ld((o + 87u)));
    s.cons[19] = bitcast<f32>(mem_ld((o + 88u)));
    s.cons[20] = bitcast<f32>(mem_ld((o + 89u)));
    s.cons[21] = bitcast<f32>(mem_ld((o + 90u)));
    s.cons[22] = bitcast<f32>(mem_ld((o + 91u)));
    s.cons[23] = bitcast<f32>(mem_ld((o + 92u)));
    s.cons[24] = bitcast<f32>(mem_ld((o + 93u)));
    s.cons[25] = bitcast<f32>(mem_ld((o + 94u)));
    s.cons[26] = bitcast<f32>(mem_ld((o + 95u)));
    s.cons[27] = bitcast<f32>(mem_ld((o + 96u)));
    s.cons[28] = bitcast<f32>(mem_ld((o + 97u)));
    s.cons[29] = bitcast<f32>(mem_ld((o + 98u)));
    s.cons[30] = bitcast<f32>(mem_ld((o + 99u)));
    s.cons[31] = bitcast<f32>(mem_ld((o + 100u)));
    s.cons[32] = bitcast<f32>(mem_ld((o + 101u)));
    s.cons[33] = bitcast<f32>(mem_ld((o + 102u)));
    s.cons[34] = bitcast<f32>(mem_ld((o + 103u)));
    s.cons[35] = bitcast<f32>(mem_ld((o + 104u)));
    s.cons[36] = bitcast<f32>(mem_ld((o + 105u)));
    s.cons[37] = bitcast<f32>(mem_ld((o + 106u)));
    s.cons[38] = bitcast<f32>(mem_ld((o + 107u)));
    s.cons[39] = bitcast<f32>(mem_ld((o + 108u)));
    s.cons[40] = bitcast<f32>(mem_ld((o + 109u)));
    s.cons[41] = bitcast<f32>(mem_ld((o + 110u)));
    s.dnu[0] = bitcast<f32>(mem_ld((o + 111u)));
    s.dnu[1] = bitcast<f32>(mem_ld((o + 112u)));
    s.dnu[2] = bitcast<f32>(mem_ld((o + 113u)));
    s.dnu[3] = bitcast<f32>(mem_ld((o + 114u)));
    s.dnu[4] = bitcast<f32>(mem_ld((o + 115u)));
    s.dnu[5] = bitcast<f32>(mem_ld((o + 116u)));
    s.dnu[6] = bitcast<f32>(mem_ld((o + 117u)));
    s.dnu[7] = bitcast<f32>(mem_ld((o + 118u)));
    s.dnu[8] = bitcast<f32>(mem_ld((o + 119u)));
    s.dnu[9] = bitcast<f32>(mem_ld((o + 120u)));
    s.dnu[10] = bitcast<f32>(mem_ld((o + 121u)));
    s.dnu[11] = bitcast<f32>(mem_ld((o + 122u)));
    s.dnu[12] = bitcast<f32>(mem_ld((o + 123u)));
    s.dnu[13] = bitcast<f32>(mem_ld((o + 124u)));
    s.dnu[14] = bitcast<f32>(mem_ld((o + 125u)));
    s.dnu[15] = bitcast<f32>(mem_ld((o + 126u)));
    return s;
}

fn ld_MorrRadarHead(o: u32) -> S_MorrRadarHead {
    var s: S_MorrRadarHead;
    s.mw = vec2<f32>(bitcast<f32>(mem_ld(((o + 0u) + 0u))), bitcast<f32>(mem_ld(((o + 0u) + 1u))));
    s.mi = vec2<f32>(bitcast<f32>(mem_ld(((o + 2u) + 0u))), bitcast<f32>(mem_ld(((o + 2u) + 1u))));
    s.kw = bitcast<f32>(mem_ld((o + 4u)));
    s.pi5 = bitcast<f32>(mem_ld((o + 5u)));
    s.lamda4 = bitcast<f32>(mem_ld((o + 6u)));
    s.zfac_s = bitcast<f32>(mem_ld((o + 7u)));
    s.zfac_g = bitcast<f32>(mem_ld((o + 8u)));
    s.ocms = bitcast<f32>(mem_ld((o + 9u)));
    s.obms = bitcast<f32>(mem_ld((o + 10u)));
    s.ocmg = bitcast<f32>(mem_ld((o + 11u)));
    s.obmg = bitcast<f32>(mem_ld((o + 12u)));
    s.pad = bitcast<f32>(mem_ld((o + 13u)));
    return s;
}

fn ld_MorrRadarBin(o: u32) -> S_MorrRadarBin {
    var s: S_MorrRadarBin;
    s.D = bitcast<f32>(mem_ld((o + 0u)));
    s.dt = bitcast<f32>(mem_ld((o + 1u)));
    s.x = bitcast<f32>(mem_ld((o + 2u)));
    s.vg = bitcast<f32>(mem_ld((o + 3u)));
    s.rhog = bitcast<f32>(mem_ld((o + 4u)));
    s.grenz = bitcast<f32>(mem_ld((o + 5u)));
    return s;
}

fn f_mi(p_in: S_MorrParams, i_in: i32, j_in: i32, k_in: i32) -> i32 {
    var p: S_MorrParams = p_in;
    var i: i32 = i_in;
    var j: i32 = j_in;
    var k: i32 = k_in;
    return ((i + 3i) + (p.strideJ * ((j + 3i) + (p.strideK * k))));
}

fn f_morr_cbrt_cr(x_in: f32) -> f32 {
    var x: f32 = x_in;
    if (((!(x > 0.0f)) || ((bitcast<u32>(x) & 0x7fffffffu) == 0x7f800000u))) {
        return opq(pow(x, div_cr(1.0f, 3.0f)));
    }
    var y0: f32 = opq(pow(x, div_cr(1.0f, 3.0f)));
    var p1: f32 = opq((opq(y0)) * (opq(y0)));
    var e1: f32 = opq(fma(opq(y0), opq(y0), opq((-(opq(p1))))));
    var p2: f32 = opq((opq(p1)) * (opq(y0)));
    var e2: f32 = opq(fma(opq(p1), opq(y0), opq((-(opq(p2))))));
    var e3: f32 = opq((opq(e1)) * (opq(y0)));
    var r: f32 = opq((opq((opq((opq(x)) - (opq(p2)))) - (opq(e2)))) - (opq(e3)));
    var c: f32 = div_cr(r, (opq((opq(3.0f)) * (opq(p1)))));
    var delta: f32 = 9.934107e-09f;
    var t: f32 = opq((opq(delta)) * (opq(log(x))));
    return opq((opq(y0)) + (opq(fma(opq(y0), opq(t), opq(c)))));
}

fn f_pow4(x_in: f32) -> f32 {
    var x: f32 = x_in;
    var t: f32 = opq((opq(x)) * (opq(x)));
    return opq((opq(t)) * (opq(t)));
}

fn f_morr_soak(h_in: S_MorrRadarHead, b_in: S_MorrRadarBin, fmelt_in: f32) -> f32 {
    var h: S_MorrRadarHead = h_in;
    var b: S_MorrRadarBin = b_in;
    var fmelt: f32 = fmelt_in;
    var rho_i: f32 = 9e+02f;
    var rho_w: f32 = 1e+03f;
    var fm: f32 = opq(max(opq(min(fmelt, 1.0f)), 0.0f));
    var mra: f32 = 0.7f;
    mra = opq(fma((opq((opq(1.0f)) - (opq(mra)))), opq(fm), opq(mra)));
    var x_w: f32 = opq((opq(b.x)) * (opq(fm)));
    var volg: f32;
    if ((mra <= b.grenz)) {
        volg = opq((opq(b.vg)) * (opq(fma(opq((-(opq(mra)))), opq(fm), opq(1.0f)))));
    } else {
        var fmgrenz: f32 = div_cr((opq((opq(rho_i)) - (opq(b.rhog)))), (opq((opq(fma(opq(mra), opq(rho_i), opq((-(opq(b.rhog))))))) + (opq(div_cr(opq((opq(rho_i)) * (opq(b.rhog))), rho_w))))));
        if ((fm <= fmgrenz)) {
            volg = opq((opq(fma(opq((-(opq(mra)))), opq(fm), opq(1.0f)))) * (opq(b.vg)));
        } else {
            volg = opq((opq(div_cr((opq((opq(b.x)) - (opq(x_w)))), rho_i))) + (opq(div_cr(x_w, rho_w))));
        }
    }
    var dlarge: f32 = opq(pow(opq((opq(div_cr(6.0f, 3.1415927f))) * (opq(volg))), div_cr(1.0f, 3.0f)));
    var volice: f32 = div_cr((opq((opq(b.x)) - (opq(x_w)))), (opq((opq(volg)) * (opq(rho_i)))));
    var volwater: f32 = div_cr(x_w, (opq((opq(rho_w)) * (opq(volg)))));
    var volair: f32 = opq((opq((opq(1.0f)) - (opq(volice)))) - (opq(volwater)));
    var v1: f32 = div_cr(volice, opq(max(opq((opq(volice)) + (opq(volwater))), 1e-10f)));
    var v2: f32 = opq((opq(1.0f)) - (opq(v1)));
    var ma: vec2<f32> = vec2<f32>(1.0f, 0.0f);
    var mtmp: vec2<f32>;
    var mcore: vec2<f32>;
    if ((!(f_c_mg(v2, 0.0f, v1, h.mw, ma, h.mi, &mtmp)))) {
        return 0.0f;
    }
    if ((!(f_c_mg(opq((opq(1.0f)) - (opq(volair))), volair, 0.0f, mtmp, ma, opq2((opq2(vec2<f32>(2.0f))) * (opq2(ma))), &mcore)))) {
        return 0.0f;
    }
    var m2: vec2<f32> = f_c_mul(mcore, mcore);
    var k: vec2<f32> = f_c_div(opq2((opq2(m2)) - (opq2(vec2<f32>(1.0f, 0.0f)))), opq2((opq2(m2)) + (opq2(vec2<f32>(2.0f, 0.0f)))));
    var d3: f32 = opq((opq((opq(dlarge)) * (opq(dlarge)))) * (opq(dlarge)));
    return div_cr(opq((opq((opq(dot(k, k))) * (opq(h.pi5)))) * (opq((opq(d3)) * (opq(d3))))), h.lamda4);
}

fn f_c_mg(v1_in: f32, v2_in: f32, v3_in: f32, m1_in: vec2<f32>, m2_in: vec2<f32>, m3_in: vec2<f32>, out: ptr<function, vec2<f32>>) -> bool {
    var v1: f32 = v1_in;
    var v2: f32 = v2_in;
    var v3: f32 = v3_in;
    var m1: vec2<f32> = m1_in;
    var m2: vec2<f32> = m2_in;
    var m3: vec2<f32> = m3_in;
    if (((abs(opq((opq((opq((opq(v1)) + (opq(v2)))) + (opq(v3)))) - (opq(1.0f))))) > (1e-06f))) {
        return false;
    }
    var m1t: vec2<f32> = f_c_mul(m1, m1);
    var m2t: vec2<f32> = f_c_mul(m2, m2);
    var m3t: vec2<f32> = f_c_mul(m3, m3);
    var one: vec2<f32> = vec2<f32>(1.0f, 0.0f);
    var b2: vec2<f32> = f_c_mul(f_c_div(opq2((opq2(vec2<f32>(2.0f))) * (opq2(m1t))), opq2((opq2(m2t)) - (opq2(m1t)))), opq2((opq2(f_c_mul(f_c_div(m2t, opq2((opq2(m2t)) - (opq2(m1t)))), f_c_log(f_c_div(m2t, m1t))))) - (opq2(one))));
    var b3: vec2<f32> = f_c_mul(f_c_div(opq2((opq2(vec2<f32>(2.0f))) * (opq2(m1t))), opq2((opq2(m3t)) - (opq2(m1t)))), opq2((opq2(f_c_mul(f_c_div(m3t, opq2((opq2(m3t)) - (opq2(m1t)))), f_c_log(f_c_div(m3t, m1t))))) - (opq2(one))));
    var num: vec2<f32> = opq2(fma(opq2(vec2<f32>(v3)), opq2(f_c_mul(b3, m3t)), opq2(fma(opq2(vec2<f32>((opq((opq((opq(1.0f)) - (opq(v2)))) - (opq(v3)))))), opq2(m1t), opq2((opq2(vec2<f32>(v2))) * (opq2(f_c_mul(b2, m2t))))))));
    var den: vec2<f32> = opq2(fma(opq2(vec2<f32>(v3)), opq2(b3), opq2(fma(opq2(vec2<f32>(v2)), opq2(b2), opq2(vec2<f32>(opq((opq((opq(1.0f)) - (opq(v2)))) - (opq(v3))), 0.0f))))));
    (*out) = f_c_sqrt(f_c_div(num, den));
    return true;
}

fn f_c_mul(a_in: vec2<f32>, b_in: vec2<f32>) -> vec2<f32> {
    var a: vec2<f32> = a_in;
    var b: vec2<f32> = b_in;
    return vec2<f32>(opq(fma(opq(a.x), opq(b.x), opq((-(opq((opq(a.y)) * (opq(b.y)))))))), opq(fma(opq(a.x), opq(b.y), opq((opq(a.y)) * (opq(b.x))))));
}

fn f_c_div(a_in: vec2<f32>, b_in: vec2<f32>) -> vec2<f32> {
    var a: vec2<f32> = a_in;
    var b: vec2<f32> = b_in;
    var d: f32 = opq(fma(opq(b.x), opq(b.x), opq((opq(b.y)) * (opq(b.y)))));
    return vec2<f32>(div_cr((opq(fma(opq(a.x), opq(b.x), opq((opq(a.y)) * (opq(b.y)))))), d), div_cr((opq(fma(opq(a.y), opq(b.x), opq((-(opq((opq(a.x)) * (opq(b.y))))))))), d));
}

fn f_c_log(a_in: vec2<f32>) -> vec2<f32> {
    var a: vec2<f32> = a_in;
    return vec2<f32>(opq(log(opq(length(a)))), opq(atan2(a.y, a.x)));
}

fn f_c_sqrt(a_in: vec2<f32>) -> vec2<f32> {
    var a: vec2<f32> = a_in;
    var r: f32 = opq(length(a));
    if ((r == 0.0f)) {
        return vec2<f32>(vec2<f32>(0.0f));
    }
    if ((a.x >= 0.0f)) {
        var t: f32 = sqrt_cr(opq((opq(0.5f)) * (opq((opq(r)) + (opq(a.x))))));
        return vec2<f32>(t, div_cr(a.y, (opq((opq(2.0f)) * (opq(t))))));
    }
    var t: f32 = sqrt_cr(opq((opq(0.5f)) * (opq((opq(r)) - (opq(a.x))))));
    return vec2<f32>(div_cr(abs(a.y), (opq((opq(2.0f)) * (opq(t))))), bitcast<f32>((bitcast<u32>(t) & 0x7fffffffu) | (bitcast<u32>(a.y) & 0x80000000u)));
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    SCRB = ARG[36] + (gid.x + ARG[0] * (gid.y + ARG[1] * gid.z)) * 1408u;
    var p: S_MorrParams = ld_MorrParams(ARG[4]);
    var h: S_MorrRadarHead = ld_MorrRadarHead(ARG[5]);
    var bs: u32 = ARG[6];
    var bg: u32 = ARG[7];
    var simpson: u32 = ARG[8];
    var T: u32 = ARG[9];
    var QR: u32 = ARG[10];
    var QS: u32 = ARG[11];
    var QG: u32 = ARG[12];
    var NR: u32 = ARG[13];
    var NS: u32 = ARG[14];
    var NG: u32 = ARG[15];
    var RH: u32 = ARG[16];
    var dbz: u32 = ARG[17];
    var tid: vec2<u32> = gid.xy;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    if (((i >= p.nx) || (j >= p.ny))) {
        return;
    }
    var nk: i32 = p.nz;
    var R1: f32 = 1e-12f;
    var T_0: f32 = 273.15f;
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 0u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 128u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 256u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 384u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 512u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 640u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 768u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 896u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 1024u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 1152u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 1280u + _z, 0u); }
    var lr: array<bool, 128>;
    var ls: array<bool, 128>;
    var lg: array<bool, 128>;
    {
        var k: i32 = 0i;
        loop {
            if (!((k < nk))) { break; }
                var c: i32 = f_mi(p, i, j, k);
                var rho: f32 = bitcast<f32>(mem_ld((RH + bitcast<u32>(c))));
                mem_st(((SCRB + 384u) + bitcast<u32>(k)), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>(c))))));
                var qr: f32 = bitcast<f32>(mem_ld((QR + bitcast<u32>(c))));
                var qs: f32 = bitcast<f32>(mem_ld((QS + bitcast<u32>(c))));
                var qg: f32 = bitcast<f32>(mem_ld((QG + bitcast<u32>(c))));
                var nr: f32 = bitcast<f32>(mem_ld((NR + bitcast<u32>(c))));
                var ns: f32 = bitcast<f32>(mem_ld((NS + bitcast<u32>(c))));
                var ng: f32 = bitcast<f32>(mem_ld((NG + bitcast<u32>(c))));
                (*&lr)[k] = (qr > R1);
                mem_st(((SCRB + 0u) + bitcast<u32>(k)), bitcast<u32>(select(R1, opq((opq(qr)) * (opq(rho))), (*&lr)[k])));
                (*&ls)[k] = (qs > R1);
                mem_st(((SCRB + 128u) + bitcast<u32>(k)), bitcast<u32>(select(R1, opq((opq(qs)) * (opq(rho))), (*&ls)[k])));
                (*&lg)[k] = (qg > R1);
                mem_st(((SCRB + 256u) + bitcast<u32>(k)), bitcast<u32>(select(R1, opq((opq(qg)) * (opq(rho))), (*&lg)[k])));
                var rnr: f32 = select(R1, opq((opq(nr)) * (opq(rho))), (nr > R1));
                var rns: f32 = select(R1, opq((opq(ns)) * (opq(rho))), (ns > R1));
                var rng: f32 = select(R1, opq((opq(ng)) * (opq(rho))), (ng > R1));
                var lam: f32 = f_morr_cbrt_cr(div_cr(opq((opq((*&p.cons)[1i])) * (opq(rns))), bitcast<f32>(mem_ld(((SCRB + 128u) + bitcast<u32>(k))))));
                var n0: f32 = div_cr(opq((opq(rns)) * (opq(lam))), rho);
                if ((lam < p.lammins)) {
                    lam = p.lammins;
                    n0 = div_cr(opq((opq(f_pow4(lam))) * (bitcast<f32>(mem_ld(((SCRB + 128u) + bitcast<u32>(k)))))), (*&p.cons)[1i]);
                } else {
                    if ((lam > p.lammaxs)) {
                        lam = p.lammaxs;
                        n0 = div_cr(opq((opq(f_pow4(lam))) * (bitcast<f32>(mem_ld(((SCRB + 128u) + bitcast<u32>(k)))))), (*&p.cons)[1i]);
                    }
                }
                mem_st(((SCRB + 512u) + bitcast<u32>(k)), bitcast<u32>(div_cr(1.0f, lam)));
                mem_st(((SCRB + 640u) + bitcast<u32>(k)), bitcast<u32>(n0));
                lam = f_morr_cbrt_cr(div_cr(opq((opq((*&p.cons)[2i])) * (opq(rng))), bitcast<f32>(mem_ld(((SCRB + 256u) + bitcast<u32>(k))))));
                n0 = div_cr(opq((opq(rng)) * (opq(lam))), rho);
                if ((lam < p.lamming)) {
                    lam = p.lamming;
                    n0 = div_cr(opq((opq(f_pow4(lam))) * (bitcast<f32>(mem_ld(((SCRB + 256u) + bitcast<u32>(k)))))), (*&p.cons)[2i]);
                } else {
                    if ((lam > p.lammaxg)) {
                        lam = p.lammaxg;
                        n0 = div_cr(opq((opq(f_pow4(lam))) * (bitcast<f32>(mem_ld(((SCRB + 256u) + bitcast<u32>(k)))))), (*&p.cons)[2i]);
                    }
                }
                mem_st(((SCRB + 768u) + bitcast<u32>(k)), bitcast<u32>(div_cr(1.0f, lam)));
                mem_st(((SCRB + 896u) + bitcast<u32>(k)), bitcast<u32>(n0));
                lam = f_morr_cbrt_cr(div_cr(opq((opq((opq(p.pi)) * (opq(p.rhow)))) * (opq(rnr))), bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k))))));
                n0 = div_cr(opq((opq(rnr)) * (opq(lam))), rho);
                if ((lam < p.lamminr)) {
                    lam = p.lamminr;
                    n0 = div_cr(opq((opq(f_pow4(lam))) * (bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k)))))), (opq((opq(p.pi)) * (opq(p.rhow)))));
                } else {
                    if ((lam > p.lammaxr)) {
                        lam = p.lammaxr;
                        n0 = div_cr(opq((opq(f_pow4(lam))) * (bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k)))))), (opq((opq(p.pi)) * (opq(p.rhow)))));
                    }
                }
                var il: f32 = div_cr(1.0f, lam);
                var il2: f32 = opq((opq(il)) * (opq(il)));
                var il4: f32 = opq((opq(il2)) * (opq(il2)));
                var il7: f32 = opq((opq((opq(il4)) * (opq(il2)))) * (opq(il)));
                mem_st(((SCRB + 1024u) + bitcast<u32>(k)), bitcast<u32>(select(1e-22f, opq((opq((opq(n0)) * (opq(7.2e+02f)))) * (opq(il7))), (*&lr)[k])));
                var s2: f32 = opq((bitcast<f32>(mem_ld(((SCRB + 512u) + bitcast<u32>(k))))) * (bitcast<f32>(mem_ld(((SCRB + 512u) + bitcast<u32>(k))))));
                var s4: f32 = opq((opq(s2)) * (opq(s2)));
                var s7: f32 = opq((opq((opq(s4)) * (opq(s2)))) * (bitcast<f32>(mem_ld(((SCRB + 512u) + bitcast<u32>(k))))));
                mem_st(((SCRB + 1152u) + bitcast<u32>(k)), bitcast<u32>(select(1e-22f, opq((opq((opq((opq(h.zfac_s)) * (bitcast<f32>(mem_ld(((SCRB + 640u) + bitcast<u32>(k))))))) * (opq(7.2e+02f)))) * (opq(s7))), (*&ls)[k])));
                var g2: f32 = opq((bitcast<f32>(mem_ld(((SCRB + 768u) + bitcast<u32>(k))))) * (bitcast<f32>(mem_ld(((SCRB + 768u) + bitcast<u32>(k))))));
                var g4: f32 = opq((opq(g2)) * (opq(g2)));
                var g7: f32 = opq((opq((opq(g4)) * (opq(g2)))) * (bitcast<f32>(mem_ld(((SCRB + 768u) + bitcast<u32>(k))))));
                mem_st(((SCRB + 1280u) + bitcast<u32>(k)), bitcast<u32>(select(1e-22f, opq((opq((opq((opq(h.zfac_g)) * (bitcast<f32>(mem_ld(((SCRB + 896u) + bitcast<u32>(k))))))) * (opq(7.2e+02f)))) * (opq(g7))), (*&lg)[k])));
            continuing {
                k = (k + 1i);
            }
        }
    }
    var melti: bool = false;
    var k0: i32 = 0i;
    {
        var k: i32 = (nk - 2i);
        loop {
            if (!((k >= 0i))) { break; }
                if (((((bitcast<f32>(mem_ld(((SCRB + 384u) + bitcast<u32>(k))))) > T_0) && ((bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k))))) > (1e-06f))) && ((opq((bitcast<f32>(mem_ld(((SCRB + 128u) + bitcast<u32>((k + 1i)))))) + (bitcast<f32>(mem_ld(((SCRB + 256u) + bitcast<u32>((k + 1i)))))))) > (1e-05f)))) {
                    k0 = max((k + 1i), k0);
                    melti = true;
                    break;
                }
            continuing {
                k = (k - 1i);
            }
        }
    }
    if ((melti && (k0 >= 1i))) {
        var kfac: f32 = div_cr(h.lamda4, (opq((opq(h.pi5)) * (opq(h.kw)))));
        {
            var k: i32 = (k0 - 1i);
            loop {
                if (!((k >= 0i))) { break; }
                    var fs: f32 = opq(min(opq((opq(1.0f)) - (opq(div_cr(bitcast<f32>(mem_ld(((SCRB + 128u) + bitcast<u32>(k)))), bitcast<f32>(mem_ld(((SCRB + 128u) + bitcast<u32>(k0)))))))), 1.0f));
                    if ((((fs > 0.01f) && (fs < 0.99f)) && ((bitcast<f32>(mem_ld(((SCRB + 128u) + bitcast<u32>(k))))) > R1))) {
                        var eta: f32 = 0.0f;
                        {
                            var n: i32 = 0i;
                            loop {
                                if (!((n < 100i))) { break; }
                                    var cb: f32 = f_morr_soak(h, ld_MorrRadarBin((bs + (bitcast<u32>(n) * 6u))), fs);
                                    var fd: f32 = opq((bitcast<f32>(mem_ld(((SCRB + 640u) + bitcast<u32>(k))))) * (opq(exp(div_cr(opq((-(bitcast<f32>(mem_ld(((bs + (bitcast<u32>(n) * 6u)) + 0u)))))), bitcast<f32>(mem_ld(((SCRB + 512u) + bitcast<u32>(k)))))))));
                                    eta = opq(fma(opq((opq((opq(fd)) * (opq(cb)))) * (bitcast<f32>(mem_ld((simpson + bitcast<u32>(n)))))), bitcast<f32>(mem_ld(((bs + (bitcast<u32>(n) * 6u)) + 1u))), opq(eta)));
                                continuing {
                                    n = (n + 1i);
                                }
                            }
                        }
                        mem_st(((SCRB + 1152u) + bitcast<u32>(k)), bitcast<u32>(opq((opq(kfac)) * (opq(eta)))));
                    }
                    var fg: f32 = opq(min(opq((opq(1.0f)) - (opq(div_cr(bitcast<f32>(mem_ld(((SCRB + 256u) + bitcast<u32>(k)))), bitcast<f32>(mem_ld(((SCRB + 256u) + bitcast<u32>(k0)))))))), 1.0f));
                    if ((((fg > 0.01f) && (fg < 0.99f)) && ((bitcast<f32>(mem_ld(((SCRB + 256u) + bitcast<u32>(k))))) > R1))) {
                        var eta: f32 = 0.0f;
                        var lamg: f32 = div_cr(1.0f, bitcast<f32>(mem_ld(((SCRB + 768u) + bitcast<u32>(k)))));
                        {
                            var n: i32 = 0i;
                            loop {
                                if (!((n < 100i))) { break; }
                                    var cb: f32 = f_morr_soak(h, ld_MorrRadarBin((bg + (bitcast<u32>(n) * 6u))), fg);
                                    var fd: f32 = opq((bitcast<f32>(mem_ld(((SCRB + 896u) + bitcast<u32>(k))))) * (opq(exp(opq((opq((-(opq(lamg))))) * (bitcast<f32>(mem_ld(((bg + (bitcast<u32>(n) * 6u)) + 0u)))))))));
                                    eta = opq(fma(opq((opq((opq(fd)) * (opq(cb)))) * (bitcast<f32>(mem_ld((simpson + bitcast<u32>(n)))))), bitcast<f32>(mem_ld(((bg + (bitcast<u32>(n) * 6u)) + 1u))), opq(eta)));
                                continuing {
                                    n = (n + 1i);
                                }
                            }
                        }
                        mem_st(((SCRB + 1280u) + bitcast<u32>(k)), bitcast<u32>(opq((opq(kfac)) * (opq(eta)))));
                    }
                continuing {
                    k = (k - 1i);
                }
            }
        }
    }
    {
        var k: i32 = 0i;
        loop {
            if (!((k < nk))) { break; }
                let _t1 = f_mi(p, i, j, k);
                mem_st((dbz + bitcast<u32>(_t1)), bitcast<u32>(opq((opq(1e+01f)) * (opq((log2(opq((opq((opq((bitcast<f32>(mem_ld(((SCRB + 1024u) + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld(((SCRB + 1152u) + bitcast<u32>(k))))))) + (bitcast<f32>(mem_ld(((SCRB + 1280u) + bitcast<u32>(k))))))) * (opq(1e+18f)))) * 0.30103f))))));
            continuing {
                k = (k + 1i);
            }
        }
    }
}
