// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// morr_column: сгенерировано, не править руками.

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

fn f_mi(p_in: S_MorrParams, i_in: i32, j_in: i32, k_in: i32) -> i32 {
    var p: S_MorrParams = p_in;
    var i: i32 = i_in;
    var j: i32 = j_in;
    var k: i32 = k_in;
    return ((i + 3i) + (p.strideJ * ((j + 3i) + (p.strideK * k))));
}

fn f_sq(x_in: f32) -> f32 {
    var x: f32 = x_in;
    return opq((opq(x)) * (opq(x)));
}

fn f_morr_lamr(p_in: S_MorrParams, q_in: f32, n: ptr<function, f32>, lam: ptr<function, f32>, n0: ptr<function, f32>) {
    var p: S_MorrParams = p_in;
    var q: f32 = q_in;
    (*lam) = opq(pow(div_cr(opq((opq((opq(p.pi)) * (opq(p.rhow)))) * (opq((*n)))), q), div_cr(1.0f, 3.0f)));
    (*n0) = opq((opq((*n))) * (opq((*lam))));
    if (((*lam) < p.lamminr)) {
        (*lam) = p.lamminr;
        (*n0) = div_cr(opq((opq(f_pow4((*lam)))) * (opq(q))), (opq((opq(p.pi)) * (opq(p.rhow)))));
        (*n) = div_cr((*n0), (*lam));
    } else {
        if (((*lam) > p.lammaxr)) {
            (*lam) = p.lammaxr;
            (*n0) = div_cr(opq((opq(f_pow4((*lam)))) * (opq(q))), (opq((opq(p.pi)) * (opq(p.rhow)))));
            (*n) = div_cr((*n0), (*lam));
        }
    }
}

fn f_pow4(x_in: f32) -> f32 {
    var x: f32 = x_in;
    var t: f32 = opq((opq(x)) * (opq(x)));
    return opq((opq(t)) * (opq(t)));
}

fn f_morr_lamc(p_in: S_MorrParams, qc_in: f32, nc: ptr<function, f32>, rho_in: f32, pgam: ptr<function, f32>, lamc: ptr<function, f32>, cdist1: ptr<function, f32>) {
    var p: S_MorrParams = p_in;
    var qc: f32 = qc_in;
    var rho: f32 = rho_in;
    (*pgam) = opq(fma(opq(0.0005714f), (opq((opq(div_cr((*nc), 1e+06f))) * (opq(rho)))), opq(0.2714f)));
    (*pgam) = opq((opq(div_cr(1.0f, f_sq((*pgam))))) - (opq(1.0f)));
    (*pgam) = opq(max((*pgam), 2.0f));
    (*pgam) = opq(min((*pgam), 1e+01f));
    (*lamc) = opq(pow(div_cr(opq((opq((opq((*&p.cons)[26i])) * (opq((*nc))))) * (opq(f_morr_gamma(opq((opq((*pgam))) + (opq(4.0f))))))), (opq((opq(qc)) * (opq(f_morr_gamma(opq((opq((*pgam))) + (opq(1.0f))))))))), div_cr(1.0f, 3.0f)));
    var lammin: f32 = div_cr((opq((opq((*pgam))) + (opq(1.0f)))), 6e-05f);
    var lammax: f32 = div_cr((opq((opq((*pgam))) + (opq(1.0f)))), 1e-06f);
    if (((*lamc) < lammin)) {
        (*lamc) = lammin;
        (*nc) = div_cr(opq(exp(opq((opq((opq(fma(opq(3.0f), opq(log((*lamc))), opq(log(qc))))) + (opq(log(f_morr_gamma(opq((opq((*pgam))) + (opq(1.0f))))))))) - (opq(log(f_morr_gamma(opq((opq((*pgam))) + (opq(4.0f)))))))))), (*&p.cons)[26i]);
    } else {
        if (((*lamc) > lammax)) {
            (*lamc) = lammax;
            (*nc) = div_cr(opq(exp(opq((opq((opq(fma(opq(3.0f), opq(log((*lamc))), opq(log(qc))))) + (opq(log(f_morr_gamma(opq((opq((*pgam))) + (opq(1.0f))))))))) - (opq(log(f_morr_gamma(opq((opq((*pgam))) + (opq(4.0f)))))))))), (*&p.cons)[26i]);
        }
    }
    (*cdist1) = div_cr((*nc), f_morr_gamma(opq((opq((*pgam))) + (opq(1.0f)))));
}

fn f_morr_gamma(x_in: f32) -> f32 {
    var x: f32 = x_in;
    var one: f32 = 1.0f;
    var chalf: f32 = 0.5f;
    var twelve: f32 = 12.0f;
    var two: f32 = 2.0f;
    var zero: f32 = 0.0f;
    var xbig: f32 = 35.04f;
    var xminin: f32 = 1.18e-38f;
    var eps: f32 = 1.19e-07f;
    var xinf: f32 = 3.4e+38f;
    var PI: f32 = 3.1415927f;
    var xxx: f32 = 0.9189385f;
    var P: array<f32, 8>;
    P[0] = opq((-(opq(1.7161851f))));
    P[1] = 24.765652f;
    P[2] = opq((-(opq(379.80426f))));
    P[3] = 629.3312f;
    P[4] = 866.9662f;
    P[5] = opq((-(opq(31451.273f))));
    P[6] = opq((-(opq(36144.414f))));
    P[7] = 66456.14f;
    var Q: array<f32, 8>;
    Q[0] = opq((-(opq(30.84023f))));
    Q[1] = 315.35062f;
    Q[2] = opq((-(opq(1015.1564f))));
    Q[3] = opq((-(opq(3107.7717f))));
    Q[4] = 22538.12f;
    Q[5] = 4755.846f;
    Q[6] = opq((-(opq(134659.95f))));
    Q[7] = opq((-(opq(115132.26f))));
    var C: array<f32, 7>;
    C[0] = opq((-(opq(0.0019104441f))));
    C[1] = 0.00084171386f;
    C[2] = opq((-(opq(0.000595238f))));
    C[3] = 0.0007936508f;
    C[4] = opq((-(opq(0.0027777778f))));
    C[5] = 0.083333336f;
    C[6] = 0.0057083834f;
    var parity: bool = false;
    var fact: f32 = one;
    var res: f32;
    var n: i32 = 0i;
    var y: f32 = x;
    if ((y <= zero)) {
        y = opq((-(opq(x))));
        var y1: f32 = opq(trunc(y));
        res = opq((opq(y)) - (opq(y1)));
        if ((res != zero)) {
            if ((y1 != (opq((opq(trunc(opq((opq(y1)) * (opq(chalf)))))) * (opq(two)))))) {
                parity = true;
            }
            fact = div_cr(opq((-(opq(PI)))), opq(sin(opq((opq(PI)) * (opq(res))))));
            y = opq((opq(y)) + (opq(one)));
        } else {
            return xinf;
        }
    }
    if ((y < eps)) {
        if ((y >= xminin)) {
            res = div_cr(one, y);
        } else {
            return xinf;
        }
    } else {
        if ((y < twelve)) {
            var y1: f32 = y;
            var z: f32;
            if ((y < one)) {
                z = y;
                y = opq((opq(y)) + (opq(one)));
            } else {
                n = ((i32(y)) - 1i);
                y = opq((opq(y)) - (opq(f32(n))));
                z = opq((opq(y)) - (opq(one)));
            }
            var xnum: f32 = zero;
            var xden: f32 = one;
            {
                var i: i32 = 0i;
                loop {
                    if (!((i < 8i))) { break; }
                        xnum = opq((opq((opq(xnum)) + (opq((*&P)[i])))) * (opq(z)));
                        xden = opq(fma(opq(xden), opq(z), opq((*&Q)[i])));
                    continuing {
                        i = (i + 1i);
                    }
                }
            }
            res = opq((opq(div_cr(xnum, xden))) + (opq(one)));
            if ((y1 < y)) {
                res = div_cr(res, y1);
            } else {
                if ((y1 > y)) {
                    {
                        var i: i32 = 0i;
                        loop {
                            if (!((i < n))) { break; }
                                res = opq((opq(res)) * (opq(y)));
                                y = opq((opq(y)) + (opq(one)));
                            continuing {
                                i = (i + 1i);
                            }
                        }
                    }
                }
            }
        } else {
            if ((y <= xbig)) {
                var ysq: f32 = opq((opq(y)) * (opq(y)));
                var sum: f32 = (*&C)[6i];
                {
                    var i: i32 = 0i;
                    loop {
                        if (!((i < 6i))) { break; }
                            sum = opq((opq(div_cr(sum, ysq))) + (opq((*&C)[i])));
                        continuing {
                            i = (i + 1i);
                        }
                    }
                }
                sum = opq((opq((opq(div_cr(sum, y))) - (opq(y)))) + (opq(xxx)));
                sum = opq(fma((opq((opq(y)) - (opq(chalf)))), opq(log(y)), opq(sum)));
                res = opq(exp(sum));
            } else {
                return xinf;
            }
        }
    }
    if (parity) {
        res = opq((-(opq(res))));
    }
    if ((fact != one)) {
        res = div_cr(fact, res);
    }
    return res;
}

fn f_morr_lam3(q_in: f32, n: ptr<function, f32>, cons_in: f32, d_in: f32, lmin_in: f32, lmax_in: f32, lam: ptr<function, f32>, n0: ptr<function, f32>) {
    var q: f32 = q_in;
    var cons: f32 = cons_in;
    var d: f32 = d_in;
    var lmin: f32 = lmin_in;
    var lmax: f32 = lmax_in;
    (*lam) = opq(pow(div_cr(opq((opq(cons)) * (opq((*n)))), q), div_cr(1.0f, d)));
    (*n0) = opq((opq((*n))) * (opq((*lam))));
    if (((*lam) < lmin)) {
        (*lam) = lmin;
        (*n0) = div_cr(opq((opq(pow((*lam), opq((opq(d)) + (opq(1.0f)))))) * (opq(q))), cons);
        (*n) = div_cr((*n0), (*lam));
    } else {
        if (((*lam) > lmax)) {
            (*lam) = lmax;
            (*n0) = div_cr(opq((opq(pow((*lam), opq((opq(d)) + (opq(1.0f)))))) * (opq(q))), cons);
            (*n) = div_cr((*n0), (*lam));
        }
    }
}

fn f_cube(x_in: f32) -> f32 {
    var x: f32 = x_in;
    return opq((opq((opq(x)) * (opq(x)))) * (opq(x)));
}

fn f_morr_satadj2(p_in: S_MorrParams, tnew: ptr<function, f32>, prs: ptr<function, f32>, qvnew: ptr<function, f32>, qcnew: ptr<function, f32>, qrnew_in: f32, qinew_in: f32, qsnew_in: f32, qgnew_in: f32, rho_in: f32) {
    var p: S_MorrParams = p_in;
    var qrnew: f32 = qrnew_in;
    var qinew: f32 = qinew_in;
    var qsnew: f32 = qsnew_in;
    var qgnew: f32 = qgnew_in;
    var rho: f32 = rho_in;
    var converge: f32 = opq((opq(2.0f)) * (opq(p.tsmall)));
    var esl: f32 = opq(min(opq((opq((*prs))) * (opq(0.5f))), opq((opq(611.2f)) * (opq(exp(div_cr(opq((opq(17.67f)) * (opq((opq((*tnew))) - (opq(273.15f))))), (opq((opq((*tnew))) - (opq(29.65f)))))))))));
    var qvs: f32 = div_cr(opq((opq(p.ep2)) * (opq(esl))), (opq((opq((*prs))) - (opq(esl)))));
    if ((((*qcnew) > p.qsmall) || ((*qvnew) > qvs))) {
        var ql: f32 = opq(max(0.0f, opq((opq((*qcnew))) + (opq(qrnew)))));
        var qi: f32 = opq(max(0.0f, opq((opq((opq(qinew)) + (opq(qsnew)))) + (opq(qgnew)))));
        var cvml: f32 = opq(fma(opq(p.cpi), opq(qi), opq(fma(opq(p.cpl), opq(ql), opq(fma(opq(p.cvv), opq((*qvnew)), opq(p.cv)))))));
        var lhv: f32 = opq(fma(opq((-(opq(p.lv2)))), opq((*tnew)), opq(p.lv1)));
        var t1: f32 = div_cr((opq(fma(opq((-(opq(p.rv)))), opq((*tnew)), opq(lhv)))), cvml);
        var d1: f32 = opq((opq((opq(t1)) * (opq(17.67f)))) * (opq(243.5f)));
        var n: i32 = 0i;
        var tlast: f32 = (*tnew);
        var doit: bool = true;
        loop {
            if (!(doit)) { break; }
                n = (n + 1i);
                var dqv: f32 = div_cr((opq((opq(qvs)) - (opq((*qvnew))))), (opq((opq(1.0f)) + (opq(div_cr(opq((opq(d1)) * (opq(qvs))), f_sq(opq((opq((*tnew))) - (opq(29.65f))))))))));
                dqv = opq(min(dqv, (*qcnew)));
                if (((opq((opq((*qvnew))) + (opq(dqv)))) < (1e-20f))) {
                    dqv = opq((opq(1e-20f)) - (opq((*qvnew))));
                }
                (*qvnew) = opq((opq((*qvnew))) + (opq(dqv)));
                (*qcnew) = opq((opq((*qcnew))) - (opq(dqv)));
                (*tnew) = opq(fma(opq((-(opq(dqv)))), opq(t1), opq((*tnew))));
                (*prs) = opq((opq((opq(rho)) * (opq(fma(opq(p.rv), opq((*qvnew)), opq(p.r)))))) * (opq((*tnew))));
                doit = false;
                if (((abs(opq((opq((*tnew))) - (opq(tlast))))) > converge)) {
                    tlast = (*tnew);
                    esl = opq(min(opq((opq((*prs))) * (opq(0.5f))), opq((opq(611.2f)) * (opq(exp(div_cr(opq((opq(17.67f)) * (opq((opq((*tnew))) - (opq(273.15f))))), (opq((opq((*tnew))) - (opq(29.65f)))))))))));
                    qvs = div_cr(opq((opq(p.ep2)) * (opq(esl))), (opq((opq((*prs))) - (opq(esl)))));
                    doit = true;
                }
                if ((n == 100i)) {
                    doit = false;
                }
        }
    }
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    SCRB = ARG[36] + (gid.x + ARG[0] * (gid.y + ARG[1] * gid.z)) * 3712u;
    var p: S_MorrParams = ld_MorrParams(ARG[4]);
    var T3: u32 = ARG[5];
    var QV: u32 = ARG[6];
    var QC: u32 = ARG[7];
    var QR: u32 = ARG[8];
    var QI: u32 = ARG[9];
    var QS: u32 = ARG[10];
    var QG: u32 = ARG[11];
    var NI: u32 = ARG[12];
    var NS: u32 = ARG[13];
    var NR: u32 = ARG[14];
    var NG: u32 = ARG[15];
    var P3: u32 = ARG[16];
    var RH3: u32 = ARG[17];
    var DZQ: u32 = ARG[18];
    var sfc: u32 = ARG[19];
    var EFFC: u32 = ARG[20];
    var EFFI: u32 = ARG[21];
    var EFFS: u32 = ARG[22];
    var dorad: i32 = bitcast<i32>(mem_ld(ARG[23]));
    var tid: vec2<u32> = gid.xy;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    if (((i >= p.nx) || (j >= p.ny))) {
        return;
    }
    var nk: i32 = p.nz;
    if ((dorad != 0i)) {
        {
            var k: i32 = 0i;
            loop {
                if (!((k < nk))) { break; }
                    var c: i32 = f_mi(p, i, j, k);
                    mem_st((EFFC + bitcast<u32>(c)), bitcast<u32>(opq((opq(25.0f)) * (opq(1e-06f)))));
                    mem_st((EFFI + bitcast<u32>(c)), bitcast<u32>(opq((opq(min(1.4e+02f, 25.0f))) * (opq(1e-06f)))));
                    mem_st((EFFS + bitcast<u32>(c)), bitcast<u32>(opq((opq(25.0f)) * (opq(1e-06f)))));
                continuing {
                    k = (k + 1i);
                }
            }
        }
    }
    var DT: f32 = p.dt;
    var RDT: f32 = p.rdt;
    var QSMALL: f32 = p.qsmall;
    var TMELT: f32 = p.tmelt;
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
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 1408u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 1536u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 1664u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 1792u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 1920u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 2048u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 2176u + _z, 0u); }
    for (var _z = 0u; _z < 640u; _z++) { mem_st(SCRB + 2304u + _z, 0u); }
    var LTRUE: i32 = 0i;
    {
        var k: i32 = 0i;
        loop {
            if (!((k < nk))) { break; }
                mem_st(((SCRB + 0u) + bitcast<u32>(k)), bitcast<u32>(f32(0i)));
                mem_st(((SCRB + 128u) + bitcast<u32>(k)), bitcast<u32>(f32(0i)));
                mem_st(((SCRB + 256u) + bitcast<u32>(k)), bitcast<u32>(f32(0i)));
                mem_st(((SCRB + 384u) + bitcast<u32>(k)), bitcast<u32>(f32(0i)));
                mem_st(((SCRB + 512u) + bitcast<u32>(k)), bitcast<u32>(f32(0i)));
                mem_st(((SCRB + 640u) + bitcast<u32>(k)), bitcast<u32>(f32(0i)));
                mem_st(((SCRB + 768u) + bitcast<u32>(k)), bitcast<u32>(f32(0i)));
                mem_st(((SCRB + 896u) + bitcast<u32>(k)), bitcast<u32>(f32(0i)));
                mem_st(((SCRB + 1024u) + bitcast<u32>(k)), bitcast<u32>(f32(0i)));
                mem_st(((SCRB + 1152u) + bitcast<u32>(k)), bitcast<u32>(f32(0i)));
                mem_st(((SCRB + 1280u) + bitcast<u32>(k)), bitcast<u32>(f32(0i)));
                mem_st(((SCRB + 1408u) + bitcast<u32>(k)), bitcast<u32>(f32(0i)));
                mem_st(((SCRB + 1920u) + bitcast<u32>(k)), bitcast<u32>(f32(0i)));
                mem_st(((SCRB + 2048u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
                {
                    var s: i32 = 0i;
                    loop {
                        if (!((s < 5i))) { break; }
                            mem_st((((SCRB + 2304u) + (bitcast<u32>(s) * 128u)) + bitcast<u32>(k)), bitcast<u32>(f32(0i)));
                        continuing {
                            s = (s + 1i);
                        }
                    }
                }
            continuing {
                k = (k + 1i);
            }
        }
    }
    {
        var k: i32 = 0i;
        loop {
            if (!((k < nk))) { break; }
                var c: i32 = f_mi(p, i, j, k);
                var t3: f32 = bitcast<f32>(mem_ld((T3 + bitcast<u32>(c))));
                var qv3: f32 = bitcast<f32>(mem_ld((QV + bitcast<u32>(c))));
                var qc3: f32 = bitcast<f32>(mem_ld((QC + bitcast<u32>(c))));
                var qr3: f32 = bitcast<f32>(mem_ld((QR + bitcast<u32>(c))));
                var qi3: f32 = bitcast<f32>(mem_ld((QI + bitcast<u32>(c))));
                var qni3: f32 = bitcast<f32>(mem_ld((QS + bitcast<u32>(c))));
                var qg3: f32 = bitcast<f32>(mem_ld((QG + bitcast<u32>(c))));
                var ni3: f32 = bitcast<f32>(mem_ld((NI + bitcast<u32>(c))));
                var ns3: f32 = bitcast<f32>(mem_ld((NS + bitcast<u32>(c))));
                var nr3: f32 = bitcast<f32>(mem_ld((NR + bitcast<u32>(c))));
                var ng3: f32 = bitcast<f32>(mem_ld((NG + bitcast<u32>(c))));
                var nc3: f32 = bitcast<f32>(mem_ld(((SCRB + 2048u) + bitcast<u32>(k))));
                var pres: f32 = bitcast<f32>(mem_ld((P3 + bitcast<u32>(c))));
                var rho: f32 = bitcast<f32>(mem_ld((RH3 + bitcast<u32>(c))));
                var xxlv: f32 = opq(fma(opq((-(opq(p.lv2)))), opq(t3), opq(p.lv1)));
                var xxls: f32 = opq(fma(opq((-(opq(p.ls2)))), opq(t3), opq(p.ls1)));
                var cpm: f32 = opq((opq(p.cp)) * (opq(fma(opq(0.887f), opq(qv3), opq(1.0f)))));
                var cvm: f32 = div_cr(1.0f, (opq(fma(opq(p.cpi), (opq((opq((opq(qi3)) + (opq(qni3)))) + (opq(qg3)))), opq(fma(opq(p.cpl), (opq((opq(qc3)) + (opq(qr3)))), opq(fma(opq(p.cvv), opq(qv3), opq(p.cv)))))))));
                var ecnd: f32 = opq((opq(fma(opq((-(opq(p.rv)))), opq(t3), opq(xxlv)))) * (opq(cvm)));
                var edep: f32 = opq((opq(fma(opq((-(opq(p.rv)))), opq(t3), opq(xxls)))) * (opq(cvm)));
                var efrz: f32 = opq((opq((opq(xxls)) - (opq(xxlv)))) * (opq(cvm)));
                mem_st(((SCRB + 1536u) + bitcast<u32>(k)), bitcast<u32>(ecnd));
                mem_st(((SCRB + 1664u) + bitcast<u32>(k)), bitcast<u32>(edep));
                mem_st(((SCRB + 1792u) + bitcast<u32>(k)), bitcast<u32>(efrz));
                var evs: f32 = opq(min(opq((opq(pres)) * (opq(0.5f))), opq((opq(611.2f)) * (opq(exp(div_cr(opq((opq(17.67f)) * (opq((opq(t3)) - (opq(273.15f))))), (opq((opq(t3)) - (opq(29.65f)))))))))));
                var eis: f32 = opq(min(opq((opq(pres)) * (opq(0.5f))), opq((opq(611.2f)) * (opq(exp(div_cr(opq((opq(21.874557f)) * (opq((opq(t3)) - (opq(273.15f))))), (opq((opq(t3)) - (opq(7.66f)))))))))));
                if ((eis > evs)) {
                    eis = evs;
                }
                var qvs: f32 = div_cr(opq((opq(p.ep2)) * (opq(evs))), (opq((opq(pres)) - (opq(evs)))));
                var qvi: f32 = div_cr(opq((opq(p.ep2)) * (opq(eis))), (opq((opq(pres)) - (opq(eis)))));
                var qvqvs: f32 = div_cr(qv3, qvs);
                var qvqvsi: f32 = div_cr(qv3, qvi);
                if ((qvqvs < 0.9f)) {
                    if ((qr3 < p.qthr)) {
                        qv3 = opq((opq(qv3)) + (opq(qr3)));
                        t3 = opq(fma(opq((-(opq(qr3)))), opq(ecnd), opq(t3)));
                        qr3 = 0.0f;
                    }
                    if ((qc3 < p.qthr)) {
                        qv3 = opq((opq(qv3)) + (opq(qc3)));
                        t3 = opq(fma(opq((-(opq(qc3)))), opq(ecnd), opq(t3)));
                        qc3 = 0.0f;
                    }
                }
                if ((qvqvsi < 0.9f)) {
                    if ((qi3 < p.qthr)) {
                        qv3 = opq((opq(qv3)) + (opq(qi3)));
                        t3 = opq(fma(opq((-(opq(qi3)))), opq(edep), opq(t3)));
                        qi3 = 0.0f;
                    }
                    if ((qni3 < p.qthr)) {
                        qv3 = opq((opq(qv3)) + (opq(qni3)));
                        t3 = opq(fma(opq((-(opq(qni3)))), opq(edep), opq(t3)));
                        qni3 = 0.0f;
                    }
                    if ((qg3 < p.qthr)) {
                        qv3 = opq((opq(qv3)) + (opq(qg3)));
                        t3 = opq(fma(opq((-(opq(qg3)))), opq(edep), opq(t3)));
                        qg3 = 0.0f;
                    }
                }
                var xlf: f32 = opq((opq(xxls)) - (opq(xxlv)));
                if ((qc3 < QSMALL)) {
                    qc3 = 0.0f;
                    nc3 = 0.0f;
                }
                if ((qr3 < QSMALL)) {
                    qr3 = 0.0f;
                    nr3 = 0.0f;
                }
                if ((qi3 < QSMALL)) {
                    qi3 = 0.0f;
                    ni3 = 0.0f;
                }
                if ((qni3 < QSMALL)) {
                    qni3 = 0.0f;
                    ns3 = 0.0f;
                }
                if ((qg3 < QSMALL)) {
                    qg3 = 0.0f;
                    ng3 = 0.0f;
                }
                var mu: f32 = div_cr(opq((opq(1.496e-06f)) * (opq(pow(t3, 1.5f)))), (opq((opq(t3)) + (opq(1.2e+02f)))));
                var dum: f32 = opq(pow(div_cr(p.rhosu, rho), 0.54f));
                var ain: f32 = opq((opq(pow(div_cr(p.rhosu, rho), 0.35f))) * (opq(p.ai)));
                var arn: f32 = opq((opq(dum)) * (opq(p.ar)));
                var asn: f32 = opq((opq(dum)) * (opq(p.as_)));
                var acn: f32 = div_cr(opq((opq(p.g)) * (opq(p.rhow))), (opq((opq(18.0f)) * (opq(mu)))));
                var agn: f32 = opq((opq(dum)) * (opq(p.ag)));
                mem_st(((SCRB + 2176u) + bitcast<u32>(k)), bitcast<u32>(acn));
                var lami: f32 = 0.0f;
                var skip200: bool = false;
                if ((((((qc3 < QSMALL) && (qi3 < QSMALL)) && (qni3 < QSMALL)) && (qr3 < QSMALL)) && (qg3 < QSMALL))) {
                    if (((t3 < TMELT) && (qvqvsi < 0.999f))) {
                        skip200 = true;
                    }
                    if (((t3 >= TMELT) && (qvqvs < 0.999f))) {
                        skip200 = true;
                    }
                }
                if ((!skip200)) {
                    var kap: f32 = opq((opq(1414.0f)) * (opq(mu)));
                    var dv: f32 = div_cr(opq((opq(8.794e-05f)) * (opq(pow(t3, 1.81f)))), pres);
                    var scn: f32 = div_cr(mu, (opq((opq(rho)) * (opq(dv)))));
                    var dumr: f32 = opq((opq(p.rv)) * (opq(f_sq(t3))));
                    var dqsdt: f32 = div_cr(opq((opq(xxlv)) * (opq(qvs))), dumr);
                    var dqsidt: f32 = div_cr(opq((opq(xxls)) * (opq(qvi))), dumr);
                    var abi: f32 = opq((opq(1.0f)) + (opq(div_cr(opq((opq(dqsidt)) * (opq(xxls))), cpm))));
                    var ab: f32 = opq((opq(1.0f)) + (opq(div_cr(opq((opq(dqsdt)) * (opq(xxlv))), cpm))));
                    if ((t3 >= TMELT)) {
                        nc3 = div_cr(opq((opq(p.ndcnst)) * (opq(1e+06f))), rho);
                        if ((qni3 < (1e-06f))) {
                            qr3 = opq((opq(qr3)) + (opq(qni3)));
                            nr3 = opq((opq(nr3)) + (opq(ns3)));
                            t3 = opq(fma(opq((-(opq(qni3)))), opq(efrz), opq(t3)));
                            qni3 = 0.0f;
                            ns3 = 0.0f;
                        }
                        if ((qg3 < (1e-06f))) {
                            qr3 = opq((opq(qr3)) + (opq(qg3)));
                            nr3 = opq((opq(nr3)) + (opq(ng3)));
                            t3 = opq(fma(opq((-(opq(qg3)))), opq(efrz), opq(t3)));
                            qg3 = 0.0f;
                            ng3 = 0.0f;
                        }
                        var goto300: bool = ((((qc3 < QSMALL) && (qni3 < (1e-08f))) && (qr3 < QSMALL)) && (qg3 < (1e-08f)));
                        if ((!goto300)) {
                            ns3 = opq(max(0.0f, ns3));
                            nr3 = opq(max(0.0f, nr3));
                            ng3 = opq(max(0.0f, ng3));
                            var lamr: f32 = f32(0i);
                            var n0rr: f32 = f32(0i);
                            var lamc: f32 = f32(0i);
                            var pgam: f32 = f32(0i);
                            var cdist1: f32 = f32(0i);
                            var lams: f32 = f32(0i);
                            var n0s: f32 = f32(0i);
                            var lamg: f32 = f32(0i);
                            var n0g: f32 = f32(0i);
                            if ((qr3 >= QSMALL)) {
                                f_morr_lamr(p, qr3, &nr3, &lamr, &n0rr);
                            }
                            if ((qc3 >= QSMALL)) {
                                f_morr_lamc(p, qc3, &nc3, rho, &pgam, &lamc, &cdist1);
                            }
                            if ((qni3 >= QSMALL)) {
                                f_morr_lam3(qni3, &ns3, (*&p.cons)[1i], p.ds, p.lammins, p.lammaxs, &lams, &n0s);
                            }
                            if ((qg3 >= QSMALL)) {
                                f_morr_lam3(qg3, &ng3, (*&p.cons)[2i], p.dg, p.lamming, p.lammaxg, &lamg, &n0g);
                            }
                            var prc: f32 = f32(0i);
                            var nprc: f32 = f32(0i);
                            var nprc1: f32 = f32(0i);
                            var pra: f32 = f32(0i);
                            var npra: f32 = f32(0i);
                            var nragg: f32 = f32(0i);
                            var nsmlts: f32 = f32(0i);
                            var nsmltr: f32 = f32(0i);
                            var evpms: f32 = f32(0i);
                            var pcc: f32 = f32(0i);
                            var pre: f32 = f32(0i);
                            var nsubr: f32 = f32(0i);
                            var pracg: f32 = f32(0i);
                            var npracg: f32 = f32(0i);
                            var psmlt: f32 = f32(0i);
                            var pgmlt: f32 = f32(0i);
                            var evpmg: f32 = f32(0i);
                            var pracs: f32 = f32(0i);
                            var npracs: f32 = f32(0i);
                            var ngmltg: f32 = f32(0i);
                            var ngmltr: f32 = f32(0i);
                            if ((qc3 >= (1e-06f))) {
                                prc = opq((opq((opq(1.35e+03f)) * (opq(pow(qc3, 2.47f))))) * (opq(pow(opq((opq(div_cr(nc3, 1e+06f))) * (opq(rho))), opq((-(opq(1.79f))))))));
                                nprc1 = div_cr(prc, (*&p.cons)[29i]);
                                nprc = div_cr(prc, (div_cr(qc3, nc3)));
                                nprc = opq(min(nprc, div_cr(nc3, DT)));
                                nprc1 = opq(min(nprc1, nprc));
                            }
                            if (((qr3 >= (1e-08f)) && (qni3 >= (1e-08f)))) {
                                var ums: f32 = div_cr(opq((opq(asn)) * (opq((*&p.cons)[3i]))), opq(pow(lams, p.bs)));
                                var umr: f32 = div_cr(opq((opq(arn)) * (opq((*&p.cons)[4i]))), opq(pow(lamr, p.br)));
                                var uns: f32 = div_cr(opq((opq(asn)) * (opq((*&p.cons)[5i]))), opq(pow(lams, p.bs)));
                                var unr: f32 = div_cr(opq((opq(arn)) * (opq((*&p.cons)[6i]))), opq(pow(lamr, p.br)));
                                var d: f32 = opq(pow(div_cr(p.rhosu, rho), 0.54f));
                                ums = opq(min(ums, opq((opq(1.2f)) * (opq(d)))));
                                uns = opq(min(uns, opq((opq(1.2f)) * (opq(d)))));
                                umr = opq(min(umr, opq((opq(9.1f)) * (opq(d)))));
                                unr = opq(min(unr, opq((opq(9.1f)) * (opq(d)))));
                                pracs = opq((opq((*&p.cons)[41i])) * (opq((opq(div_cr(opq((opq((opq((opq(pow(opq(fma(opq((opq(0.08f)) * (opq(ums))), opq(umr), opq(f_sq(opq(fma(opq(1.2f), opq(umr), opq((-(opq((opq(0.95f)) * (opq(ums)))))))))))), 0.5f))) * (opq(rho)))) * (opq(n0rr)))) * (opq(n0s))), f_cube(lamr)))) * (opq((opq((opq(div_cr(5.0f, (opq((opq(f_cube(lamr))) * (opq(lams))))))) + (opq(div_cr(2.0f, (opq((opq(f_sq(lamr))) * (opq(f_sq(lams)))))))))) + (opq(div_cr(0.5f, (opq((opq(lamr)) * (opq(f_cube(lams)))))))))))));
                            }
                            if (((qr3 >= (1e-08f)) && (qg3 >= (1e-08f)))) {
                                var umg: f32 = div_cr(opq((opq(agn)) * (opq((*&p.cons)[7i]))), opq(pow(lamg, p.bg)));
                                var umr: f32 = div_cr(opq((opq(arn)) * (opq((*&p.cons)[4i]))), opq(pow(lamr, p.br)));
                                var ung: f32 = div_cr(opq((opq(agn)) * (opq((*&p.cons)[8i]))), opq(pow(lamg, p.bg)));
                                var unr: f32 = div_cr(opq((opq(arn)) * (opq((*&p.cons)[6i]))), opq(pow(lamr, p.br)));
                                var d: f32 = opq(pow(div_cr(p.rhosu, rho), 0.54f));
                                umg = opq(min(umg, opq((opq(2e+01f)) * (opq(d)))));
                                ung = opq(min(ung, opq((opq(2e+01f)) * (opq(d)))));
                                umr = opq(min(umr, opq((opq(9.1f)) * (opq(d)))));
                                unr = opq(min(unr, opq((opq(9.1f)) * (opq(d)))));
                                pracg = opq((opq((*&p.cons)[41i])) * (opq((opq(div_cr(opq((opq((opq((opq(pow(opq(fma(opq((opq(0.08f)) * (opq(umg))), opq(umr), opq(f_sq(opq(fma(opq(1.2f), opq(umr), opq((-(opq((opq(0.95f)) * (opq(umg)))))))))))), 0.5f))) * (opq(rho)))) * (opq(n0rr)))) * (opq(n0g))), f_cube(lamr)))) * (opq((opq((opq(div_cr(5.0f, (opq((opq(f_cube(lamr))) * (opq(lamg))))))) + (opq(div_cr(2.0f, (opq((opq(f_sq(lamr))) * (opq(f_sq(lamg)))))))))) + (opq(div_cr(0.5f, (opq((opq(lamr)) * (opq(f_cube(lamg)))))))))))));
                                var dd: f32 = div_cr(pracg, 5.2e-07f);
                                npracg = opq((opq((opq((opq((opq((opq((*&p.cons)[32i])) * (opq(rho)))) * (opq(pow(opq(fma(opq(1.7f), opq(f_sq(opq((opq(unr)) - (opq(ung))))), opq((opq((opq(0.3f)) * (opq(unr)))) * (opq(ung))))), 0.5f))))) * (opq(n0rr)))) * (opq(n0g)))) * (opq((opq((opq(div_cr(1.0f, (opq((opq(f_cube(lamr))) * (opq(lamg))))))) + (opq(div_cr(1.0f, (opq((opq(f_sq(lamr))) * (opq(f_sq(lamg)))))))))) + (opq(div_cr(1.0f, (opq((opq(lamr)) * (opq(f_cube(lamg)))))))))));
                                npracg = opq((opq(npracg)) - (opq(dd)));
                            }
                            if (((qr3 >= (1e-08f)) && (qc3 >= (1e-08f)))) {
                                var d: f32 = opq((opq(qc3)) * (opq(qr3)));
                                pra = opq((opq(67.0f)) * (opq(pow(d, 1.15f))));
                                npra = div_cr(pra, (div_cr(qc3, nc3)));
                            }
                            if ((qr3 >= (1e-08f))) {
                                var dum1: f32 = p.dB;
                                var d: f32 = f32(0i);
                                if (((div_cr(1.0f, lamr)) < dum1)) {
                                    d = 1.0f;
                                } else {
                                    if (((div_cr(1.0f, lamr)) >= dum1)) {
                                        d = opq((opq(2.0f)) - (opq(exp(2.3e+03f * (opq((opq(div_cr(1.0f, lamr))) - (opq(dum1))))))));
                                    }
                                }
                                nragg = opq((opq((opq((opq((opq((-(opq(5.78f))))) * (opq(d)))) * (opq(qr3)))) * (opq(nr3)))) * (opq(rho)));
                            }
                            var epsr: f32;
                            if ((qr3 >= QSMALL)) {
                                epsr = opq((opq((opq((opq((opq((opq(2.0f)) * (opq(p.pi)))) * (opq(n0rr)))) * (opq(rho)))) * (opq(dv)))) * (opq((opq(div_cr(p.f1r, (opq((opq(lamr)) * (opq(lamr))))))) + (opq(div_cr(opq((opq((opq((opq(p.f2r)) * (opq(pow(div_cr(opq((opq(arn)) * (opq(rho))), mu), 0.5f))))) * (opq(pow(scn, div_cr(1.0f, 3.0f)))))) * (opq((*&p.cons)[9i]))), opq(pow(lamr, (*&p.cons)[34i]))))))));
                            } else {
                                epsr = 0.0f;
                            }
                            if ((qv3 < qvs)) {
                                pre = div_cr(opq((opq(epsr)) * (opq((opq(qv3)) - (opq(qvs))))), ab);
                                pre = opq(min(pre, 0.0f));
                                var d: f32 = opq(fma(opq((-(opq(pre)))), opq(DT), opq(qv3)));
                                if ((d > qvs)) {
                                    pre = div_cr((opq((opq(qv3)) - (opq(qvs)))), DT);
                                }
                            } else {
                                pre = 0.0f;
                            }
                            if ((qni3 >= (1e-08f))) {
                                var d: f32 = opq((opq((opq(div_cr(opq((-(opq(p.cpw)))), xlf))) * (opq((opq(t3)) - (opq(273.15f)))))) * (opq(pracs)));
                                psmlt = opq(fma(opq(div_cr(opq((opq((opq((opq((opq(2.0f)) * (opq(p.pi)))) * (opq(n0s)))) * (opq(kap)))) * (opq((opq(TMELT)) - (opq(t3))))), xlf)), (opq((opq(div_cr(p.f1s, (opq((opq(lams)) * (opq(lams))))))) + (opq(div_cr(opq((opq((opq((opq(p.f2s)) * (opq(pow(div_cr(opq((opq(asn)) * (opq(rho))), mu), 0.5f))))) * (opq(pow(scn, div_cr(1.0f, 3.0f)))))) * (opq((*&p.cons)[10i]))), opq(pow(lams, (*&p.cons)[35i]))))))), opq(d)));
                                if ((qvqvs < 1.0f)) {
                                    var epss: f32 = opq((opq((opq((opq((opq((opq(2.0f)) * (opq(p.pi)))) * (opq(n0s)))) * (opq(rho)))) * (opq(dv)))) * (opq((opq(div_cr(p.f1s, (opq((opq(lams)) * (opq(lams))))))) + (opq(div_cr(opq((opq((opq((opq(p.f2s)) * (opq(pow(div_cr(opq((opq(asn)) * (opq(rho))), mu), 0.5f))))) * (opq(pow(scn, div_cr(1.0f, 3.0f)))))) * (opq((*&p.cons)[10i]))), opq(pow(lams, (*&p.cons)[35i]))))))));
                                    evpms = div_cr(opq((opq((opq(qv3)) - (opq(qvs)))) * (opq(epss))), ab);
                                    evpms = opq(max(evpms, psmlt));
                                    psmlt = opq((opq(psmlt)) - (opq(evpms)));
                                }
                            }
                            if ((qg3 >= (1e-08f))) {
                                var d: f32 = opq((opq((opq(div_cr(opq((-(opq(p.cpw)))), xlf))) * (opq((opq(t3)) - (opq(273.15f)))))) * (opq(pracg)));
                                pgmlt = opq(fma(opq(div_cr(opq((opq((opq((opq((opq(2.0f)) * (opq(p.pi)))) * (opq(n0g)))) * (opq(kap)))) * (opq((opq(TMELT)) - (opq(t3))))), xlf)), (opq((opq(div_cr(p.f1s, (opq((opq(lamg)) * (opq(lamg))))))) + (opq(div_cr(opq((opq((opq((opq(p.f2s)) * (opq(pow(div_cr(opq((opq(agn)) * (opq(rho))), mu), 0.5f))))) * (opq(pow(scn, div_cr(1.0f, 3.0f)))))) * (opq((*&p.cons)[11i]))), opq(pow(lamg, (*&p.cons)[36i]))))))), opq(d)));
                                if ((qvqvs < 1.0f)) {
                                    var epsg: f32 = opq((opq((opq((opq((opq((opq(2.0f)) * (opq(p.pi)))) * (opq(n0g)))) * (opq(rho)))) * (opq(dv)))) * (opq((opq(div_cr(p.f1s, (opq((opq(lamg)) * (opq(lamg))))))) + (opq(div_cr(opq((opq((opq((opq(p.f2s)) * (opq(pow(div_cr(opq((opq(agn)) * (opq(rho))), mu), 0.5f))))) * (opq(pow(scn, div_cr(1.0f, 3.0f)))))) * (opq((*&p.cons)[11i]))), opq(pow(lamg, (*&p.cons)[36i]))))))));
                                    evpmg = div_cr(opq((opq((opq(qv3)) - (opq(qvs)))) * (opq(epsg))), ab);
                                    evpmg = opq(max(evpmg, pgmlt));
                                    pgmlt = opq((opq(pgmlt)) - (opq(evpmg)));
                                }
                            }
                            pracg = 0.0f;
                            pracs = 0.0f;
                            var d: f32 = opq((opq((opq(prc)) + (opq(pra)))) * (opq(DT)));
                            if (((d > qc3) && (qc3 >= QSMALL))) {
                                var ratio: f32 = div_cr(qc3, d);
                                prc = opq((opq(prc)) * (opq(ratio)));
                                pra = opq((opq(pra)) * (opq(ratio)));
                            }
                            d = opq((opq((opq((opq((-(opq(psmlt))))) - (opq(evpms)))) + (opq(pracs)))) * (opq(DT)));
                            if (((d > qni3) && (qni3 >= QSMALL))) {
                                var ratio: f32 = div_cr(qni3, d);
                                psmlt = opq((opq(psmlt)) * (opq(ratio)));
                                evpms = opq((opq(evpms)) * (opq(ratio)));
                                pracs = opq((opq(pracs)) * (opq(ratio)));
                            }
                            d = opq((opq((opq((opq((-(opq(pgmlt))))) - (opq(evpmg)))) + (opq(pracg)))) * (opq(DT)));
                            if (((d > qg3) && (qg3 >= QSMALL))) {
                                var ratio: f32 = div_cr(qg3, d);
                                pgmlt = opq((opq(pgmlt)) * (opq(ratio)));
                                evpmg = opq((opq(evpmg)) * (opq(ratio)));
                                pracg = opq((opq(pracg)) * (opq(ratio)));
                            }
                            d = opq((opq((opq((opq((opq((opq((opq((opq((-(opq(pracs))))) - (opq(pracg)))) - (opq(pre)))) - (opq(pra)))) - (opq(prc)))) + (opq(psmlt)))) + (opq(pgmlt)))) * (opq(DT)));
                            if (((d > qr3) && (qr3 >= QSMALL))) {
                                var ratio: f32 = div_cr((opq((opq((opq((opq((opq((opq((opq(div_cr(qr3, DT))) + (opq(pracs)))) + (opq(pracg)))) + (opq(pra)))) + (opq(prc)))) - (opq(psmlt)))) - (opq(pgmlt)))), (opq((-(opq(pre))))));
                                pre = opq((opq(pre)) * (opq(ratio)));
                            }
                            mem_st(((SCRB + 0u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k))))) + (opq((opq((opq((-(opq(pre))))) - (opq(evpms)))) - (opq(evpmg)))))));
                            mem_st(((SCRB + 128u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 128u) + bitcast<u32>(k))))) + (opq(fma((opq((opq((opq((opq(psmlt)) + (opq(pgmlt)))) - (opq(pracs)))) - (opq(pracg)))), opq(efrz), opq(fma(opq(pre), opq(ecnd), opq((opq((opq(evpms)) + (opq(evpmg)))) * (opq(edep)))))))))));
                            mem_st(((SCRB + 256u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 256u) + bitcast<u32>(k))))) + (opq((opq((-(opq(pra))))) - (opq(prc)))))));
                            mem_st(((SCRB + 640u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 640u) + bitcast<u32>(k))))) + (opq((opq((opq((opq((opq((opq((opq(pre)) + (opq(pra)))) + (opq(prc)))) - (opq(psmlt)))) - (opq(pgmlt)))) + (opq(pracs)))) + (opq(pracg)))))));
                            mem_st(((SCRB + 512u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 512u) + bitcast<u32>(k))))) + (opq((opq((opq(psmlt)) + (opq(evpms)))) - (opq(pracs)))))));
                            mem_st(((SCRB + 768u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 768u) + bitcast<u32>(k))))) + (opq((opq((opq(pgmlt)) + (opq(evpmg)))) - (opq(pracg)))))));
                            mem_st(((SCRB + 1408u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1408u) + bitcast<u32>(k))))) + (opq((opq((-(opq(npra))))) - (opq(nprc)))))));
                            mem_st(((SCRB + 1152u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1152u) + bitcast<u32>(k))))) + (opq((opq((opq(nprc1)) + (opq(nragg)))) - (opq(npracg)))))));
                            if ((pre < 0.0f)) {
                                var dd: f32 = div_cr(opq((opq(pre)) * (opq(DT))), qr3);
                                dd = opq(max(opq((-(opq(1.0f)))), dd));
                                nsubr = div_cr(opq((opq(dd)) * (opq(nr3))), DT);
                            }
                            if (((opq((opq(evpms)) + (opq(psmlt)))) < 0.0f)) {
                                var dd: f32 = div_cr(opq((opq((opq(evpms)) + (opq(psmlt)))) * (opq(DT))), qni3);
                                dd = opq(max(opq((-(opq(1.0f)))), dd));
                                nsmlts = div_cr(opq((opq(dd)) * (opq(ns3))), DT);
                            }
                            if ((psmlt < 0.0f)) {
                                var dd: f32 = div_cr(opq((opq(psmlt)) * (opq(DT))), qni3);
                                dd = opq(max(opq((-(opq(1.0f)))), dd));
                                nsmltr = div_cr(opq((opq(dd)) * (opq(ns3))), DT);
                            }
                            if (((opq((opq(evpmg)) + (opq(pgmlt)))) < 0.0f)) {
                                var dd: f32 = div_cr(opq((opq((opq(evpmg)) + (opq(pgmlt)))) * (opq(DT))), qg3);
                                dd = opq(max(opq((-(opq(1.0f)))), dd));
                                ngmltg = div_cr(opq((opq(dd)) * (opq(ng3))), DT);
                            }
                            if ((pgmlt < 0.0f)) {
                                var dd: f32 = div_cr(opq((opq(pgmlt)) * (opq(DT))), qg3);
                                dd = opq(max(opq((-(opq(1.0f)))), dd));
                                ngmltr = div_cr(opq((opq(dd)) * (opq(ng3))), DT);
                            }
                            mem_st(((SCRB + 1024u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1024u) + bitcast<u32>(k))))) + (opq(nsmlts)))));
                            mem_st(((SCRB + 1280u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1280u) + bitcast<u32>(k))))) + (opq(ngmltg)))));
                            mem_st(((SCRB + 1152u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1152u) + bitcast<u32>(k))))) + (opq((opq((opq(nsubr)) - (opq(nsmltr)))) - (opq(ngmltr)))))));
                        }
                        {
                            var dumt: f32 = opq(fma(opq(DT), bitcast<f32>(mem_ld(((SCRB + 128u) + bitcast<u32>(k)))), opq(t3)));
                            var dumqv: f32 = opq(fma(opq(DT), bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k)))), opq(qv3)));
                            var dumqc: f32 = opq(fma(opq(DT), bitcast<f32>(mem_ld(((SCRB + 256u) + bitcast<u32>(k)))), opq(qc3)));
                            var dumqr: f32 = opq(fma(opq(DT), bitcast<f32>(mem_ld(((SCRB + 640u) + bitcast<u32>(k)))), opq(qr3)));
                            var dummqs: f32 = opq(fma(opq(DT), bitcast<f32>(mem_ld(((SCRB + 512u) + bitcast<u32>(k)))), opq(qni3)));
                            var dumqg: f32 = opq(fma(opq(DT), bitcast<f32>(mem_ld(((SCRB + 768u) + bitcast<u32>(k)))), opq(qg3)));
                            var dumqi: f32 = 0.0f;
                            pres = opq((opq((opq(rho)) * (opq(dumt)))) * (opq(fma(opq(p.rv), opq(dumqv), opq(p.r)))));
                            var saveqc: f32 = dumqc;
                            var savet: f32 = dumt;
                            f_morr_satadj2(p, &dumt, &pres, &dumqv, &dumqc, dumqr, dumqi, dummqs, dumqg, rho);
                            if (((abs(opq((opq(dumt)) - (opq(savet))))) >= 0.0001f)) {
                                var pccv: f32 = opq((opq((opq(dumqc)) - (opq(saveqc)))) * (opq(RDT)));
                                mem_st(((SCRB + 0u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k))))) - (opq(pccv)))));
                                mem_st(((SCRB + 256u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 256u) + bitcast<u32>(k))))) + (opq(pccv)))));
                                mem_st(((SCRB + 128u) + bitcast<u32>(k)), bitcast<u32>(opq(fma((opq((opq(dumt)) - (opq(savet)))), opq(RDT), bitcast<f32>(mem_ld(((SCRB + 128u) + bitcast<u32>(k))))))));
                            }
                        }
                    } else {
                        nc3 = div_cr(opq((opq(p.ndcnst)) * (opq(1e+06f))), rho);
                        ni3 = opq(max(0.0f, ni3));
                        ns3 = opq(max(0.0f, ns3));
                        nr3 = opq(max(0.0f, nr3));
                        ng3 = opq(max(0.0f, ng3));
                        var n0i: f32 = f32(0i);
                        var lamr: f32 = f32(0i);
                        var n0rr: f32 = f32(0i);
                        var lamc: f32 = f32(0i);
                        var pgam: f32 = f32(0i);
                        var cdist1: f32 = f32(0i);
                        var lams: f32 = f32(0i);
                        var n0s: f32 = f32(0i);
                        var lamg: f32 = f32(0i);
                        var n0g: f32 = f32(0i);
                        if ((qi3 >= QSMALL)) {
                            f_morr_lam3(qi3, &ni3, (*&p.cons)[12i], p.di, p.lammini, p.lammaxi, &lami, &n0i);
                        }
                        if ((qr3 >= QSMALL)) {
                            f_morr_lamr(p, qr3, &nr3, &lamr, &n0rr);
                        }
                        if ((qc3 >= QSMALL)) {
                            f_morr_lamc(p, qc3, &nc3, rho, &pgam, &lamc, &cdist1);
                        }
                        if ((qni3 >= QSMALL)) {
                            f_morr_lam3(qni3, &ns3, (*&p.cons)[1i], p.ds, p.lammins, p.lammaxs, &lams, &n0s);
                        }
                        if ((qg3 >= QSMALL)) {
                            f_morr_lam3(qg3, &ng3, (*&p.cons)[2i], p.dg, p.lamming, p.lammaxg, &lamg, &n0g);
                        }
                        var mnuccc: f32 = f32(0i);
                        var nnuccc: f32 = f32(0i);
                        var prc: f32 = f32(0i);
                        var nprc: f32 = f32(0i);
                        var nprc1: f32 = f32(0i);
                        var nsagg: f32 = f32(0i);
                        var psacws: f32 = f32(0i);
                        var npsacws: f32 = f32(0i);
                        var psacwi: f32 = f32(0i);
                        var npsacwi: f32 = f32(0i);
                        var pracs: f32 = f32(0i);
                        var npracs: f32 = f32(0i);
                        var nmults: f32 = f32(0i);
                        var qmults: f32 = f32(0i);
                        var nmultr: f32 = f32(0i);
                        var qmultr: f32 = f32(0i);
                        var nmultg: f32 = f32(0i);
                        var qmultg: f32 = f32(0i);
                        var nmultrg: f32 = f32(0i);
                        var qmultrg: f32 = f32(0i);
                        var mnuccr: f32 = f32(0i);
                        var nnuccr: f32 = f32(0i);
                        var pra: f32 = f32(0i);
                        var npra: f32 = f32(0i);
                        var nragg: f32 = f32(0i);
                        var prci: f32 = f32(0i);
                        var nprci: f32 = f32(0i);
                        var prai: f32 = f32(0i);
                        var nprai: f32 = f32(0i);
                        var nnuccd: f32 = f32(0i);
                        var mnuccd: f32 = f32(0i);
                        var pcc: f32 = f32(0i);
                        var pre: f32 = f32(0i);
                        var prd: f32 = f32(0i);
                        var prds: f32 = f32(0i);
                        var eprd: f32 = f32(0i);
                        var eprds: f32 = f32(0i);
                        var nsubi: f32 = f32(0i);
                        var nsubs: f32 = f32(0i);
                        var nsubr: f32 = f32(0i);
                        var piacr: f32 = f32(0i);
                        var niacr: f32 = f32(0i);
                        var praci: f32 = f32(0i);
                        var piacrs: f32 = f32(0i);
                        var niacrs: f32 = f32(0i);
                        var pracis: f32 = f32(0i);
                        var pracg: f32 = f32(0i);
                        var psacr: f32 = f32(0i);
                        var psacwg: f32 = f32(0i);
                        var pgsacw: f32 = f32(0i);
                        var pgracs: f32 = f32(0i);
                        var prdg: f32 = f32(0i);
                        var eprdg: f32 = f32(0i);
                        var npracg: f32 = f32(0i);
                        var npsacwg: f32 = f32(0i);
                        var nscng: f32 = f32(0i);
                        var ngracs: f32 = f32(0i);
                        var nsubg: f32 = f32(0i);
                        if (((qc3 >= QSMALL) && (t3 < 269.15f))) {
                            var nacnt: f32 = opq((opq(exp(opq(fma(opq(0.262f), (opq((opq(TMELT)) - (opq(t3)))), opq((-(opq(2.8f))))))))) * (opq(1e+03f)));
                            var d: f32 = div_cr(div_cr(opq((opq(7.37f)) * (opq(t3))), (opq((opq((opq(288.0f)) * (opq(1e+01f)))) * (opq(pres))))), 1e+02f);
                            var dap: f32 = div_cr(opq((opq((opq((*&p.cons)[37i])) * (opq(t3)))) * (opq((opq(1.0f)) + (opq(div_cr(d, 1e-07f)))))), mu);
                            mnuccc = opq((opq((opq((opq((*&p.cons)[38i])) * (opq(dap)))) * (opq(nacnt)))) * (opq(exp(opq(fma(opq((-(opq(4.0f)))), opq(log(lamc)), opq((opq(log(cdist1))) + (opq(log(f_morr_gamma(opq((opq(pgam)) + (opq(5.0f))))))))))))));
                            nnuccc = div_cr(opq((opq((opq((opq((opq((opq(2.0f)) * (opq(p.pi)))) * (opq(dap)))) * (opq(nacnt)))) * (opq(cdist1)))) * (opq(f_morr_gamma(opq((opq(pgam)) + (opq(2.0f))))))), lamc);
                            mnuccc = opq(fma(opq((opq((*&p.cons)[39i])) * (opq(exp(opq(fma(opq((-(opq(6.0f)))), opq(log(lamc)), opq((opq(log(cdist1))) + (opq(log(f_morr_gamma(opq((opq(7.0f)) + (opq(pgam)))))))))))))), (opq((opq(exp(opq((opq(p.aimm)) * (opq((opq(273.15f)) - (opq(t3)))))))) - (opq(1.0f)))), opq(mnuccc)));
                            nnuccc = opq(fma(opq((opq((*&p.cons)[40i])) * (opq(exp(opq(fma(opq((-(opq(3.0f)))), opq(log(lamc)), opq((opq(log(cdist1))) + (opq(log(f_morr_gamma(opq((opq(pgam)) + (opq(4.0f)))))))))))))), (opq((opq(exp(opq((opq(p.aimm)) * (opq((opq(273.15f)) - (opq(t3)))))))) - (opq(1.0f)))), opq(nnuccc)));
                            nnuccc = opq(min(nnuccc, div_cr(nc3, DT)));
                        }
                        if ((qc3 >= (1e-06f))) {
                            prc = opq((opq((opq(1.35e+03f)) * (opq(pow(qc3, 2.47f))))) * (opq(pow(opq((opq(div_cr(nc3, 1e+06f))) * (opq(rho))), opq((-(opq(1.79f))))))));
                            nprc1 = div_cr(prc, (*&p.cons)[29i]);
                            nprc = div_cr(prc, (div_cr(qc3, nc3)));
                            nprc = opq(min(nprc, div_cr(nc3, DT)));
                            nprc1 = opq(min(nprc1, nprc));
                        }
                        if ((qni3 >= (1e-08f))) {
                            nsagg = div_cr(opq((opq((opq((opq((opq((*&p.cons)[15i])) * (opq(asn)))) * (opq(pow(rho, div_cr((opq((opq(2.0f)) + (opq(p.bs)))), 3.0f)))))) * (opq(pow(qni3, div_cr((opq((opq(2.0f)) + (opq(p.bs)))), 3.0f)))))) * (opq(pow(opq((opq(ns3)) * (opq(rho))), div_cr((opq((opq(4.0f)) - (opq(p.bs)))), 3.0f))))), rho);
                        }
                        if (((qni3 >= (1e-08f)) && (qc3 >= QSMALL))) {
                            psacws = div_cr(opq((opq((opq((opq((opq((*&p.cons)[13i])) * (opq(asn)))) * (opq(qc3)))) * (opq(rho)))) * (opq(n0s))), opq(pow(lams, opq((opq(p.bs)) + (opq(3.0f))))));
                            npsacws = div_cr(opq((opq((opq((opq((opq((*&p.cons)[13i])) * (opq(asn)))) * (opq(nc3)))) * (opq(rho)))) * (opq(n0s))), opq(pow(lams, opq((opq(p.bs)) + (opq(3.0f))))));
                        }
                        if (((qg3 >= (1e-08f)) && (qc3 >= QSMALL))) {
                            psacwg = div_cr(opq((opq((opq((opq((opq((*&p.cons)[14i])) * (opq(agn)))) * (opq(qc3)))) * (opq(rho)))) * (opq(n0g))), opq(pow(lamg, opq((opq(p.bg)) + (opq(3.0f))))));
                            npsacwg = div_cr(opq((opq((opq((opq((opq((*&p.cons)[14i])) * (opq(agn)))) * (opq(nc3)))) * (opq(rho)))) * (opq(n0g))), opq(pow(lamg, opq((opq(p.bg)) + (opq(3.0f))))));
                        }
                        if (((qi3 >= (1e-08f)) && (qc3 >= QSMALL))) {
                            if (((div_cr(1.0f, lami)) >= 0.0001f)) {
                                psacwi = div_cr(opq((opq((opq((opq((opq((*&p.cons)[16i])) * (opq(ain)))) * (opq(qc3)))) * (opq(rho)))) * (opq(n0i))), opq(pow(lami, opq((opq(p.bi)) + (opq(3.0f))))));
                                npsacwi = div_cr(opq((opq((opq((opq((opq((*&p.cons)[16i])) * (opq(ain)))) * (opq(nc3)))) * (opq(rho)))) * (opq(n0i))), opq(pow(lami, opq((opq(p.bi)) + (opq(3.0f))))));
                            }
                        }
                        if (((qr3 >= (1e-08f)) && (qni3 >= (1e-08f)))) {
                            var ums: f32 = div_cr(opq((opq(asn)) * (opq((*&p.cons)[3i]))), opq(pow(lams, p.bs)));
                            var umr: f32 = div_cr(opq((opq(arn)) * (opq((*&p.cons)[4i]))), opq(pow(lamr, p.br)));
                            var uns: f32 = div_cr(opq((opq(asn)) * (opq((*&p.cons)[5i]))), opq(pow(lams, p.bs)));
                            var unr: f32 = div_cr(opq((opq(arn)) * (opq((*&p.cons)[6i]))), opq(pow(lamr, p.br)));
                            var d: f32 = opq(pow(div_cr(p.rhosu, rho), 0.54f));
                            ums = opq(min(ums, opq((opq(1.2f)) * (opq(d)))));
                            uns = opq(min(uns, opq((opq(1.2f)) * (opq(d)))));
                            umr = opq(min(umr, opq((opq(9.1f)) * (opq(d)))));
                            unr = opq(min(unr, opq((opq(9.1f)) * (opq(d)))));
                            pracs = opq((opq((*&p.cons)[41i])) * (opq((opq(div_cr(opq((opq((opq((opq(pow(opq(fma(opq((opq(0.08f)) * (opq(ums))), opq(umr), opq(f_sq(opq(fma(opq(1.2f), opq(umr), opq((-(opq((opq(0.95f)) * (opq(ums)))))))))))), 0.5f))) * (opq(rho)))) * (opq(n0rr)))) * (opq(n0s))), f_cube(lamr)))) * (opq((opq((opq(div_cr(5.0f, (opq((opq(f_cube(lamr))) * (opq(lams))))))) + (opq(div_cr(2.0f, (opq((opq(f_sq(lamr))) * (opq(f_sq(lams)))))))))) + (opq(div_cr(0.5f, (opq((opq(lamr)) * (opq(f_cube(lams)))))))))))));
                            npracs = opq((opq((opq((opq((opq((opq((*&p.cons)[32i])) * (opq(rho)))) * (opq(pow(opq(fma(opq(1.7f), opq(f_sq(opq((opq(unr)) - (opq(uns))))), opq((opq((opq(0.3f)) * (opq(unr)))) * (opq(uns))))), 0.5f))))) * (opq(n0rr)))) * (opq(n0s)))) * (opq((opq((opq(div_cr(1.0f, (opq((opq(f_cube(lamr))) * (opq(lams))))))) + (opq(div_cr(1.0f, (opq((opq(f_sq(lamr))) * (opq(f_sq(lams)))))))))) + (opq(div_cr(1.0f, (opq((opq(lamr)) * (opq(f_cube(lams)))))))))));
                            pracs = opq(min(pracs, div_cr(qr3, DT)));
                            if (((qni3 >= 0.0001f) && (qr3 >= 0.0001f))) {
                                psacr = opq((opq((*&p.cons)[31i])) * (opq((opq(div_cr(opq((opq((opq((opq(pow(opq(fma(opq((opq(0.08f)) * (opq(ums))), opq(umr), opq(f_sq(opq(fma(opq(1.2f), opq(umr), opq((-(opq((opq(0.95f)) * (opq(ums)))))))))))), 0.5f))) * (opq(rho)))) * (opq(n0rr)))) * (opq(n0s))), f_cube(lams)))) * (opq((opq((opq(div_cr(5.0f, (opq((opq(f_cube(lams))) * (opq(lamr))))))) + (opq(div_cr(2.0f, (opq((opq(f_sq(lams))) * (opq(f_sq(lamr)))))))))) + (opq(div_cr(0.5f, (opq((opq(lams)) * (opq(f_cube(lamr)))))))))))));
                            }
                        }
                        if (((qr3 >= (1e-08f)) && (qg3 >= (1e-08f)))) {
                            var umg: f32 = div_cr(opq((opq(agn)) * (opq((*&p.cons)[7i]))), opq(pow(lamg, p.bg)));
                            var umr: f32 = div_cr(opq((opq(arn)) * (opq((*&p.cons)[4i]))), opq(pow(lamr, p.br)));
                            var ung: f32 = div_cr(opq((opq(agn)) * (opq((*&p.cons)[8i]))), opq(pow(lamg, p.bg)));
                            var unr: f32 = div_cr(opq((opq(arn)) * (opq((*&p.cons)[6i]))), opq(pow(lamr, p.br)));
                            var d: f32 = opq(pow(div_cr(p.rhosu, rho), 0.54f));
                            umg = opq(min(umg, opq((opq(2e+01f)) * (opq(d)))));
                            ung = opq(min(ung, opq((opq(2e+01f)) * (opq(d)))));
                            umr = opq(min(umr, opq((opq(9.1f)) * (opq(d)))));
                            unr = opq(min(unr, opq((opq(9.1f)) * (opq(d)))));
                            pracg = opq((opq((*&p.cons)[41i])) * (opq((opq(div_cr(opq((opq((opq((opq(pow(opq(fma(opq((opq(0.08f)) * (opq(umg))), opq(umr), opq(f_sq(opq(fma(opq(1.2f), opq(umr), opq((-(opq((opq(0.95f)) * (opq(umg)))))))))))), 0.5f))) * (opq(rho)))) * (opq(n0rr)))) * (opq(n0g))), f_cube(lamr)))) * (opq((opq((opq(div_cr(5.0f, (opq((opq(f_cube(lamr))) * (opq(lamg))))))) + (opq(div_cr(2.0f, (opq((opq(f_sq(lamr))) * (opq(f_sq(lamg)))))))))) + (opq(div_cr(0.5f, (opq((opq(lamr)) * (opq(f_cube(lamg)))))))))))));
                            npracg = opq((opq((opq((opq((opq((opq((*&p.cons)[32i])) * (opq(rho)))) * (opq(pow(opq(fma(opq(1.7f), opq(f_sq(opq((opq(unr)) - (opq(ung))))), opq((opq((opq(0.3f)) * (opq(unr)))) * (opq(ung))))), 0.5f))))) * (opq(n0rr)))) * (opq(n0g)))) * (opq((opq((opq(div_cr(1.0f, (opq((opq(f_cube(lamr))) * (opq(lamg))))))) + (opq(div_cr(1.0f, (opq((opq(f_sq(lamr))) * (opq(f_sq(lamg)))))))))) + (opq(div_cr(1.0f, (opq((opq(lamr)) * (opq(f_cube(lamg)))))))))));
                            pracg = opq(min(pracg, div_cr(qr3, DT)));
                        }
                        if ((qni3 >= 0.0001f)) {
                            if (((qc3 >= 0.0005f) || (qr3 >= 0.0001f))) {
                                if (((psacws > 0.0f) || (pracs > 0.0f))) {
                                    if (((t3 < 270.16f) && (t3 > 265.16f))) {
                                        var fmult: f32 = f32(0i);
                                        if ((t3 > 270.16f)) {
                                            fmult = 0.0f;
                                        } else {
                                            if (((t3 <= 270.16f) && (t3 > 268.16f))) {
                                                fmult = div_cr((opq((opq(270.16f)) - (opq(t3)))), 2.0f);
                                            } else {
                                                if (((t3 >= 265.16f) && (t3 <= 268.16f))) {
                                                    fmult = div_cr((opq((opq(t3)) - (opq(265.16f)))), 3.0f);
                                                } else {
                                                    if ((t3 < 265.16f)) {
                                                        fmult = 0.0f;
                                                    }
                                                }
                                            }
                                        }
                                        if ((psacws > 0.0f)) {
                                            nmults = opq((opq((opq((opq(3.5e+05f)) * (opq(psacws)))) * (opq(fmult)))) * (opq(1e+03f)));
                                            qmults = opq((opq(nmults)) * (opq(p.mmult)));
                                            qmults = opq(min(qmults, psacws));
                                            psacws = opq((opq(psacws)) - (opq(qmults)));
                                        }
                                        if ((pracs > 0.0f)) {
                                            nmultr = opq((opq((opq((opq(3.5e+05f)) * (opq(pracs)))) * (opq(fmult)))) * (opq(1e+03f)));
                                            qmultr = opq((opq(nmultr)) * (opq(p.mmult)));
                                            qmultr = opq(min(qmultr, pracs));
                                            pracs = opq((opq(pracs)) - (opq(qmultr)));
                                        }
                                    }
                                }
                            }
                        }
                        if ((qg3 >= 0.0001f)) {
                            if (((qc3 >= 0.0005f) || (qr3 >= 0.0001f))) {
                                if (((psacwg > 0.0f) || (pracg > 0.0f))) {
                                    if (((t3 < 270.16f) && (t3 > 265.16f))) {
                                        var fmult: f32 = f32(0i);
                                        if ((t3 > 270.16f)) {
                                            fmult = 0.0f;
                                        } else {
                                            if (((t3 <= 270.16f) && (t3 > 268.16f))) {
                                                fmult = div_cr((opq((opq(270.16f)) - (opq(t3)))), 2.0f);
                                            } else {
                                                if (((t3 >= 265.16f) && (t3 <= 268.16f))) {
                                                    fmult = div_cr((opq((opq(t3)) - (opq(265.16f)))), 3.0f);
                                                } else {
                                                    if ((t3 < 265.16f)) {
                                                        fmult = 0.0f;
                                                    }
                                                }
                                            }
                                        }
                                        if ((psacwg > 0.0f)) {
                                            nmultg = opq((opq((opq((opq(3.5e+05f)) * (opq(psacwg)))) * (opq(fmult)))) * (opq(1e+03f)));
                                            qmultg = opq((opq(nmultg)) * (opq(p.mmult)));
                                            qmultg = opq(min(qmultg, psacwg));
                                            psacwg = opq((opq(psacwg)) - (opq(qmultg)));
                                        }
                                        if ((pracg > 0.0f)) {
                                            nmultrg = opq((opq((opq((opq(3.5e+05f)) * (opq(pracg)))) * (opq(fmult)))) * (opq(1e+03f)));
                                            qmultrg = opq((opq(nmultrg)) * (opq(p.mmult)));
                                            qmultrg = opq(min(qmultrg, pracg));
                                            pracg = opq((opq(pracg)) - (opq(qmultrg)));
                                        }
                                    }
                                }
                            }
                        }
                        if ((psacws > 0.0f)) {
                            if (((qni3 >= 0.0001f) && (qc3 >= 0.0005f))) {
                                pgsacw = opq(min(psacws, div_cr(opq((opq((opq((opq((opq((opq((opq((*&p.cons)[17i])) * (opq(DT)))) * (opq(n0s)))) * (opq(qc3)))) * (opq(qc3)))) * (opq(asn)))) * (opq(asn))), (opq((opq(rho)) * (opq(pow(lams, opq(fma(opq(2.0f), opq(p.bs), opq(2.0f)))))))))));
                                var d: f32 = opq(max(opq((opq(div_cr(p.rhosn, (opq((opq(p.rhog)) - (opq(p.rhosn))))))) * (opq(pgsacw))), 0.0f));
                                nscng = opq((opq(div_cr(d, p.mg0))) * (opq(rho)));
                                nscng = opq(min(nscng, div_cr(ns3, DT)));
                                psacws = opq((opq(psacws)) - (opq(pgsacw)));
                            }
                        }
                        if ((pracs > 0.0f)) {
                            if (((qni3 >= 0.0001f) && (qr3 >= 0.0001f))) {
                                var d: f32 = div_cr(opq((opq((opq((*&p.cons)[18i])) * (opq(f_cube(div_cr(4.0f, lams)))))) * (opq(f_cube(div_cr(4.0f, lams))))), (opq(fma(opq((opq((*&p.cons)[18i])) * (opq(f_cube(div_cr(4.0f, lams))))), opq(f_cube(div_cr(4.0f, lams))), opq((opq((opq((*&p.cons)[19i])) * (opq(f_cube(div_cr(4.0f, lamr)))))) * (opq(f_cube(div_cr(4.0f, lamr)))))))));
                                d = opq(min(d, 1.0f));
                                d = opq(max(d, 0.0f));
                                pgracs = opq((opq((opq(1.0f)) - (opq(d)))) * (opq(pracs)));
                                ngracs = opq((opq((opq(1.0f)) - (opq(d)))) * (opq(npracs)));
                                ngracs = opq(min(ngracs, div_cr(nr3, DT)));
                                ngracs = opq(min(ngracs, div_cr(ns3, DT)));
                                pracs = opq((opq(pracs)) - (opq(pgracs)));
                                npracs = opq((opq(npracs)) - (opq(ngracs)));
                                psacr = opq((opq(psacr)) * (opq((opq(1.0f)) - (opq(d)))));
                            }
                        }
                        if (((t3 < 269.15f) && (qr3 >= QSMALL))) {
                            mnuccr = opq((opq((opq((*&p.cons)[20i])) * (opq(nr3)))) * (opq((div_cr(div_cr((opq((opq(exp(opq((opq(p.aimm)) * (opq((opq(273.15f)) - (opq(t3)))))))) - (opq(1.0f)))), f_cube(lamr)), f_cube(lamr))))));
                            nnuccr = div_cr(opq((opq((opq((opq(p.pi)) * (opq(nr3)))) * (opq(p.bimm)))) * (opq((opq(exp(opq((opq(p.aimm)) * (opq((opq(273.15f)) - (opq(t3)))))))) - (opq(1.0f))))), f_cube(lamr));
                            nnuccr = opq(min(nnuccr, div_cr(nr3, DT)));
                        }
                        if (((qr3 >= (1e-08f)) && (qc3 >= (1e-08f)))) {
                            var d: f32 = opq((opq(qc3)) * (opq(qr3)));
                            pra = opq((opq(67.0f)) * (opq(pow(d, 1.15f))));
                            npra = div_cr(pra, (div_cr(qc3, nc3)));
                        }
                        if ((qr3 >= (1e-08f))) {
                            var dum1: f32 = p.dB;
                            var d: f32 = f32(0i);
                            if (((div_cr(1.0f, lamr)) < dum1)) {
                                d = 1.0f;
                            } else {
                                if (((div_cr(1.0f, lamr)) >= dum1)) {
                                    d = opq((opq(2.0f)) - (opq(exp(2.3e+03f * (opq((opq(div_cr(1.0f, lamr))) - (opq(dum1))))))));
                                }
                            }
                            nragg = opq((opq((opq((opq((opq((-(opq(5.78f))))) * (opq(d)))) * (opq(qr3)))) * (opq(nr3)))) * (opq(rho)));
                        }
                        if (((qi3 >= (1e-08f)) && (qvqvsi >= 1.0f))) {
                            nprci = div_cr(opq((opq((opq((opq((opq((opq((*&p.cons)[21i])) * (opq((opq(qv3)) - (opq(qvi)))))) * (opq(rho)))) * (opq(n0i)))) * (opq(exp(opq((opq((-(opq(lami))))) * (opq(p.dcs)))))))) * (opq(dv))), abi);
                            prci = opq((opq((*&p.cons)[22i])) * (opq(nprci)));
                            nprci = opq(min(nprci, div_cr(ni3, DT)));
                        }
                        if (((qni3 >= (1e-08f)) && (qi3 >= QSMALL))) {
                            prai = div_cr(opq((opq((opq((opq((opq((*&p.cons)[23i])) * (opq(asn)))) * (opq(qi3)))) * (opq(rho)))) * (opq(n0s))), opq(pow(lams, opq((opq(p.bs)) + (opq(3.0f))))));
                            nprai = div_cr(opq((opq((opq((opq((opq((*&p.cons)[23i])) * (opq(asn)))) * (opq(ni3)))) * (opq(rho)))) * (opq(n0s))), opq(pow(lams, opq((opq(p.bs)) + (opq(3.0f))))));
                            nprai = opq(min(nprai, div_cr(ni3, DT)));
                        }
                        if ((((qr3 >= (1e-08f)) && (qi3 >= (1e-08f))) && (t3 <= TMELT))) {
                            if ((qr3 >= 0.0001f)) {
                                niacr = opq((opq(div_cr(opq((opq((opq((opq((*&p.cons)[24i])) * (opq(ni3)))) * (opq(n0rr)))) * (opq(arn))), opq(pow(lamr, opq((opq(p.br)) + (opq(3.0f)))))))) * (opq(rho)));
                                piacr = opq((opq(div_cr(div_cr(opq((opq((opq((opq((*&p.cons)[25i])) * (opq(ni3)))) * (opq(n0rr)))) * (opq(arn))), opq(pow(lamr, opq((opq(p.br)) + (opq(3.0f)))))), f_cube(lamr)))) * (opq(rho)));
                                praci = opq((opq(div_cr(opq((opq((opq((opq((*&p.cons)[24i])) * (opq(qi3)))) * (opq(n0rr)))) * (opq(arn))), opq(pow(lamr, opq((opq(p.br)) + (opq(3.0f)))))))) * (opq(rho)));
                                niacr = opq(min(niacr, div_cr(nr3, DT)));
                                niacr = opq(min(niacr, div_cr(ni3, DT)));
                            } else {
                                niacrs = opq((opq(div_cr(opq((opq((opq((opq((*&p.cons)[24i])) * (opq(ni3)))) * (opq(n0rr)))) * (opq(arn))), opq(pow(lamr, opq((opq(p.br)) + (opq(3.0f)))))))) * (opq(rho)));
                                piacrs = opq((opq(div_cr(div_cr(opq((opq((opq((opq((*&p.cons)[25i])) * (opq(ni3)))) * (opq(n0rr)))) * (opq(arn))), opq(pow(lamr, opq((opq(p.br)) + (opq(3.0f)))))), f_cube(lamr)))) * (opq(rho)));
                                pracis = opq((opq(div_cr(opq((opq((opq((opq((*&p.cons)[24i])) * (opq(qi3)))) * (opq(n0rr)))) * (opq(arn))), opq(pow(lamr, opq((opq(p.br)) + (opq(3.0f)))))))) * (opq(rho)));
                                niacrs = opq(min(niacrs, div_cr(nr3, DT)));
                                niacrs = opq(min(niacrs, div_cr(ni3, DT)));
                            }
                        }
                        if ((((qvqvs >= 0.999f) && (t3 <= 265.15f)) || (qvqvsi >= 1.25f))) {
                            var kc2: f32 = opq((opq((opq(0.005f)) * (opq(exp(0.304f * (opq((opq(TMELT)) - (opq(t3))))))))) * (opq(1e+03f)));
                            kc2 = opq(min(kc2, 5e+05f));
                            kc2 = opq(max(div_cr(kc2, rho), 0.0f));
                            if ((kc2 > (opq((opq((opq(ni3)) + (opq(ns3)))) + (opq(ng3)))))) {
                                nnuccd = div_cr((opq((opq((opq((opq(kc2)) - (opq(ni3)))) - (opq(ns3)))) - (opq(ng3)))), DT);
                                mnuccd = opq((opq(nnuccd)) * (opq(p.mi0)));
                            }
                        }
                        var epsi: f32;
                        var epss: f32;
                        var epsg: f32;
                        var epsr: f32;
                        if ((qi3 >= QSMALL)) {
                            epsi = div_cr(opq((opq((opq((opq((opq(2.0f)) * (opq(p.pi)))) * (opq(n0i)))) * (opq(rho)))) * (opq(dv))), (opq((opq(lami)) * (opq(lami)))));
                        } else {
                            epsi = 0.0f;
                        }
                        if ((qni3 >= QSMALL)) {
                            epss = opq((opq((opq((opq((opq((opq(2.0f)) * (opq(p.pi)))) * (opq(n0s)))) * (opq(rho)))) * (opq(dv)))) * (opq((opq(div_cr(p.f1s, (opq((opq(lams)) * (opq(lams))))))) + (opq(div_cr(opq((opq((opq((opq(p.f2s)) * (opq(pow(div_cr(opq((opq(asn)) * (opq(rho))), mu), 0.5f))))) * (opq(pow(scn, div_cr(1.0f, 3.0f)))))) * (opq((*&p.cons)[10i]))), opq(pow(lams, (*&p.cons)[35i]))))))));
                        } else {
                            epss = 0.0f;
                        }
                        if ((qg3 >= QSMALL)) {
                            epsg = opq((opq((opq((opq((opq((opq(2.0f)) * (opq(p.pi)))) * (opq(n0g)))) * (opq(rho)))) * (opq(dv)))) * (opq((opq(div_cr(p.f1s, (opq((opq(lamg)) * (opq(lamg))))))) + (opq(div_cr(opq((opq((opq((opq(p.f2s)) * (opq(pow(div_cr(opq((opq(agn)) * (opq(rho))), mu), 0.5f))))) * (opq(pow(scn, div_cr(1.0f, 3.0f)))))) * (opq((*&p.cons)[11i]))), opq(pow(lamg, (*&p.cons)[36i]))))))));
                        } else {
                            epsg = 0.0f;
                        }
                        if ((qr3 >= QSMALL)) {
                            epsr = opq((opq((opq((opq((opq((opq(2.0f)) * (opq(p.pi)))) * (opq(n0rr)))) * (opq(rho)))) * (opq(dv)))) * (opq((opq(div_cr(p.f1r, (opq((opq(lamr)) * (opq(lamr))))))) + (opq(div_cr(opq((opq((opq((opq(p.f2r)) * (opq(pow(div_cr(opq((opq(arn)) * (opq(rho))), mu), 0.5f))))) * (opq(pow(scn, div_cr(1.0f, 3.0f)))))) * (opq((*&p.cons)[9i]))), opq(pow(lamr, (*&p.cons)[34i]))))))));
                        } else {
                            epsr = 0.0f;
                        }
                        var dd: f32;
                        if ((qi3 >= QSMALL)) {
                            dd = (opq(fma(opq((-(opq(exp(opq((opq((-(opq(lami))))) * (opq(p.dcs)))))))), (opq(fma(opq(lami), opq(p.dcs), opq(1.0f)))), opq(1.0f))));
                            prd = opq((opq(div_cr(opq((opq(epsi)) * (opq((opq(qv3)) - (opq(qvi))))), abi))) * (opq(dd)));
                        } else {
                            dd = 0.0f;
                        }
                        if ((qni3 >= QSMALL)) {
                            prds = opq(fma(opq(div_cr(opq((opq(epsi)) * (opq((opq(qv3)) - (opq(qvi))))), abi)), (opq((opq(1.0f)) - (opq(dd)))), opq(div_cr(opq((opq(epss)) * (opq((opq(qv3)) - (opq(qvi))))), abi))));
                        } else {
                            prd = opq(fma(opq(div_cr(opq((opq(epsi)) * (opq((opq(qv3)) - (opq(qvi))))), abi)), (opq((opq(1.0f)) - (opq(dd)))), opq(prd)));
                        }
                        prdg = div_cr(opq((opq(epsg)) * (opq((opq(qv3)) - (opq(qvi))))), abi);
                        if ((qv3 < qvs)) {
                            pre = div_cr(opq((opq(epsr)) * (opq((opq(qv3)) - (opq(qvs))))), ab);
                            pre = opq(min(pre, 0.0f));
                            var d: f32 = opq(fma(opq((-(opq(pre)))), opq(DT), opq(qv3)));
                            if ((d > qvs)) {
                                pre = div_cr((opq((opq(qv3)) - (opq(qvs)))), DT);
                            }
                        } else {
                            pre = 0.0f;
                        }
                        {
                            var d: f32 = div_cr((opq((opq(qv3)) - (opq(qvi)))), DT);
                            var fudgef: f32 = 0.9999f;
                            var sum_dep: f32 = opq((opq((opq((opq(prd)) + (opq(prds)))) + (opq(mnuccd)))) + (opq(prdg)));
                            if ((((d > 0.0f) && (sum_dep > (opq((opq(d)) * (opq(fudgef)))))) || ((d < 0.0f) && (sum_dep < (opq((opq(d)) * (opq(fudgef)))))))) {
                                mnuccd = div_cr(opq((opq((opq(fudgef)) * (opq(mnuccd)))) * (opq(d))), sum_dep);
                                prd = div_cr(opq((opq((opq(fudgef)) * (opq(prd)))) * (opq(d))), sum_dep);
                                prds = div_cr(opq((opq((opq(fudgef)) * (opq(prds)))) * (opq(d))), sum_dep);
                                prdg = div_cr(opq((opq((opq(fudgef)) * (opq(prdg)))) * (opq(d))), sum_dep);
                            }
                        }
                        if ((prd < 0.0f)) {
                            eprd = prd;
                            prd = 0.0f;
                        }
                        if ((prds < 0.0f)) {
                            eprds = prds;
                            prds = 0.0f;
                        }
                        if ((prdg < 0.0f)) {
                            eprdg = prdg;
                            prdg = 0.0f;
                        }
                        var d: f32 = opq((opq((opq((opq((opq((opq((opq((opq((opq((opq(prc)) + (opq(pra)))) + (opq(mnuccc)))) + (opq(psacws)))) + (opq(psacwi)))) + (opq(qmults)))) + (opq(psacwg)))) + (opq(pgsacw)))) + (opq(qmultg)))) * (opq(DT)));
                        if (((d > qc3) && (qc3 >= QSMALL))) {
                            var ratio: f32 = div_cr(qc3, d);
                            prc = opq((opq(prc)) * (opq(ratio)));
                            pra = opq((opq(pra)) * (opq(ratio)));
                            mnuccc = opq((opq(mnuccc)) * (opq(ratio)));
                            psacws = opq((opq(psacws)) * (opq(ratio)));
                            psacwi = opq((opq(psacwi)) * (opq(ratio)));
                            qmults = opq((opq(qmults)) * (opq(ratio)));
                            qmultg = opq((opq(qmultg)) * (opq(ratio)));
                            psacwg = opq((opq(psacwg)) * (opq(ratio)));
                            pgsacw = opq((opq(pgsacw)) * (opq(ratio)));
                        }
                        d = opq((opq((opq((opq((opq((opq((opq((opq((opq((opq((opq((opq((opq((opq((-(opq(prd))))) - (opq(mnuccc)))) + (opq(prci)))) + (opq(prai)))) - (opq(qmults)))) - (opq(qmultg)))) - (opq(qmultr)))) - (opq(qmultrg)))) - (opq(mnuccd)))) + (opq(praci)))) + (opq(pracis)))) - (opq(eprd)))) - (opq(psacwi)))) * (opq(DT)));
                        if (((d > qi3) && (qi3 >= QSMALL))) {
                            var ratio: f32 = div_cr((opq((opq((opq((opq((opq((opq((opq((opq((opq(div_cr(qi3, DT))) + (opq(prd)))) + (opq(mnuccc)))) + (opq(qmults)))) + (opq(qmultg)))) + (opq(qmultr)))) + (opq(qmultrg)))) + (opq(mnuccd)))) + (opq(psacwi)))), (opq((opq((opq((opq((opq(prci)) + (opq(prai)))) + (opq(praci)))) + (opq(pracis)))) - (opq(eprd)))));
                            prci = opq((opq(prci)) * (opq(ratio)));
                            prai = opq((opq(prai)) * (opq(ratio)));
                            praci = opq((opq(praci)) * (opq(ratio)));
                            pracis = opq((opq(pracis)) * (opq(ratio)));
                            eprd = opq((opq(eprd)) * (opq(ratio)));
                        }
                        d = opq((opq((opq((opq((opq((opq((opq((opq((opq(pracs)) - (opq(pre)))) + (opq((opq((opq(qmultr)) + (opq(qmultrg)))) - (opq(prc)))))) + (opq((opq(mnuccr)) - (opq(pra)))))) + (opq(piacr)))) + (opq(piacrs)))) + (opq(pgracs)))) + (opq(pracg)))) * (opq(DT)));
                        if (((d > qr3) && (qr3 >= QSMALL))) {
                            var ratio: f32 = div_cr((opq((opq((opq(div_cr(qr3, DT))) + (opq(prc)))) + (opq(pra)))), (opq((opq((opq((opq((opq((opq((opq((opq((opq((-(opq(pre))))) + (opq(qmultr)))) + (opq(qmultrg)))) + (opq(pracs)))) + (opq(mnuccr)))) + (opq(piacr)))) + (opq(piacrs)))) + (opq(pgracs)))) + (opq(pracg)))));
                            pre = opq((opq(pre)) * (opq(ratio)));
                            pracs = opq((opq(pracs)) * (opq(ratio)));
                            qmultr = opq((opq(qmultr)) * (opq(ratio)));
                            qmultrg = opq((opq(qmultrg)) * (opq(ratio)));
                            mnuccr = opq((opq(mnuccr)) * (opq(ratio)));
                            piacr = opq((opq(piacr)) * (opq(ratio)));
                            piacrs = opq((opq(piacrs)) * (opq(ratio)));
                            pgracs = opq((opq(pgracs)) * (opq(ratio)));
                            pracg = opq((opq(pracg)) * (opq(ratio)));
                        }
                        d = opq((opq((opq((opq((opq((opq((opq((opq((opq((opq((-(opq(prds))))) - (opq(psacws)))) - (opq(prai)))) - (opq(prci)))) - (opq(pracs)))) - (opq(eprds)))) + (opq(psacr)))) - (opq(piacrs)))) - (opq(pracis)))) * (opq(DT)));
                        if (((d > qni3) && (qni3 >= QSMALL))) {
                            var ratio: f32 = div_cr((opq((opq((opq((opq((opq((opq((opq((opq(div_cr(qni3, DT))) + (opq(prds)))) + (opq(psacws)))) + (opq(prai)))) + (opq(prci)))) + (opq(pracs)))) + (opq(piacrs)))) + (opq(pracis)))), (opq((opq((-(opq(eprds))))) + (opq(psacr)))));
                            eprds = opq((opq(eprds)) * (opq(ratio)));
                            psacr = opq((opq(psacr)) * (opq(ratio)));
                        }
                        d = opq((opq((opq((opq((opq((opq((opq((opq((opq((opq((opq((-(opq(psacwg))))) - (opq(pracg)))) - (opq(pgsacw)))) - (opq(pgracs)))) - (opq(prdg)))) - (opq(mnuccr)))) - (opq(eprdg)))) - (opq(piacr)))) - (opq(praci)))) - (opq(psacr)))) * (opq(DT)));
                        if (((d > qg3) && (qg3 >= QSMALL))) {
                            var ratio: f32 = div_cr((opq((opq((opq((opq((opq((opq((opq((opq((opq((opq(div_cr(qg3, DT))) + (opq(psacwg)))) + (opq(pracg)))) + (opq(pgsacw)))) + (opq(pgracs)))) + (opq(prdg)))) + (opq(mnuccr)))) + (opq(psacr)))) + (opq(piacr)))) + (opq(praci)))), (opq((-(opq(eprdg))))));
                            eprdg = opq((opq(eprdg)) * (opq(ratio)));
                        }
                        mem_st(((SCRB + 0u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k))))) + (opq((opq((opq((opq((opq((opq((opq((opq((-(opq(pre))))) - (opq(prd)))) - (opq(prds)))) - (opq(mnuccd)))) - (opq(eprd)))) - (opq(eprds)))) - (opq(prdg)))) - (opq(eprdg)))))));
                        mem_st(((SCRB + 128u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 128u) + bitcast<u32>(k))))) + (opq(fma((opq((opq((opq((opq((opq((opq((opq((opq((opq((opq((opq((opq((opq((opq((opq(psacws)) + (opq(psacwi)))) + (opq(mnuccc)))) + (opq(mnuccr)))) + (opq(qmults)))) + (opq(qmultg)))) + (opq(qmultr)))) + (opq(qmultrg)))) + (opq(pracs)))) + (opq(psacwg)))) + (opq(pracg)))) + (opq(pgsacw)))) + (opq(pgracs)))) + (opq(piacr)))) + (opq(piacrs)))), opq(efrz), opq(fma(opq(pre), opq(ecnd), opq((opq((opq((opq((opq((opq((opq((opq(prd)) + (opq(prds)))) + (opq(mnuccd)))) + (opq(eprd)))) + (opq(eprds)))) + (opq(prdg)))) + (opq(eprdg)))) * (opq(edep)))))))))));
                        mem_st(((SCRB + 256u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 256u) + bitcast<u32>(k))))) + (opq((opq((opq((opq((opq((opq((opq((opq((opq((opq((-(opq(pra))))) - (opq(prc)))) - (opq(mnuccc)))) + (opq(pcc)))) - (opq(psacws)))) - (opq(psacwi)))) - (opq(qmults)))) - (opq(qmultg)))) - (opq(psacwg)))) - (opq(pgsacw)))))));
                        mem_st(((SCRB + 384u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 384u) + bitcast<u32>(k))))) + (opq((opq((opq((opq((opq((opq((opq((opq((opq((opq((opq((opq((opq(prd)) + (opq(eprd)))) + (opq(psacwi)))) + (opq(mnuccc)))) - (opq(prci)))) - (opq(prai)))) + (opq(qmults)))) + (opq(qmultg)))) + (opq(qmultr)))) + (opq(qmultrg)))) + (opq(mnuccd)))) - (opq(praci)))) - (opq(pracis)))))));
                        mem_st(((SCRB + 640u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 640u) + bitcast<u32>(k))))) + (opq((opq((opq((opq((opq((opq((opq((opq((opq((opq((opq(pre)) + (opq(pra)))) + (opq(prc)))) - (opq(pracs)))) - (opq(mnuccr)))) - (opq(qmultr)))) - (opq(qmultrg)))) - (opq(piacr)))) - (opq(piacrs)))) - (opq(pracg)))) - (opq(pgracs)))))));
                        mem_st(((SCRB + 512u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 512u) + bitcast<u32>(k))))) + (opq((opq((opq((opq((opq((opq((opq((opq((opq(prai)) + (opq(psacws)))) + (opq(prds)))) + (opq(pracs)))) + (opq(prci)))) + (opq(eprds)))) - (opq(psacr)))) + (opq(piacrs)))) + (opq(pracis)))))));
                        mem_st(((SCRB + 1024u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1024u) + bitcast<u32>(k))))) + (opq((opq((opq((opq((opq(nsagg)) + (opq(nprci)))) - (opq(nscng)))) - (opq(ngracs)))) + (opq(niacrs)))))));
                        mem_st(((SCRB + 768u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 768u) + bitcast<u32>(k))))) + (opq((opq((opq((opq((opq((opq((opq((opq((opq((opq(pracg)) + (opq(psacwg)))) + (opq(pgsacw)))) + (opq(pgracs)))) + (opq(prdg)))) + (opq(eprdg)))) + (opq(mnuccr)))) + (opq(piacr)))) + (opq(praci)))) + (opq(psacr)))))));
                        mem_st(((SCRB + 1280u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1280u) + bitcast<u32>(k))))) + (opq((opq((opq((opq(nscng)) + (opq(ngracs)))) + (opq(nnuccr)))) + (opq(niacr)))))));
                        mem_st(((SCRB + 1408u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1408u) + bitcast<u32>(k))))) + (opq((opq((opq((opq((opq((opq((-(opq(nnuccc))))) - (opq(npsacws)))) - (opq(npra)))) - (opq(nprc)))) - (opq(npsacwi)))) - (opq(npsacwg)))))));
                        mem_st(((SCRB + 896u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 896u) + bitcast<u32>(k))))) + (opq((opq((opq((opq((opq((opq((opq((opq((opq((opq(nnuccc)) - (opq(nprci)))) - (opq(nprai)))) + (opq(nmults)))) + (opq(nmultg)))) + (opq(nmultr)))) + (opq(nmultrg)))) + (opq(nnuccd)))) - (opq(niacr)))) - (opq(niacrs)))))));
                        mem_st(((SCRB + 1152u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1152u) + bitcast<u32>(k))))) + (opq((opq((opq((opq((opq((opq((opq((opq(nprc1)) - (opq(npracs)))) - (opq(nnuccr)))) + (opq(nragg)))) - (opq(niacr)))) - (opq(niacrs)))) - (opq(npracg)))) - (opq(ngracs)))))));
                        if ((eprd < 0.0f)) {
                            var q: f32 = div_cr(opq((opq(eprd)) * (opq(DT))), qi3);
                            q = opq(max(opq((-(opq(1.0f)))), q));
                            nsubi = div_cr(opq((opq(q)) * (opq(ni3))), DT);
                        }
                        if ((eprds < 0.0f)) {
                            var q: f32 = div_cr(opq((opq(eprds)) * (opq(DT))), qni3);
                            q = opq(max(opq((-(opq(1.0f)))), q));
                            nsubs = div_cr(opq((opq(q)) * (opq(ns3))), DT);
                        }
                        if ((pre < 0.0f)) {
                            var q: f32 = div_cr(opq((opq(pre)) * (opq(DT))), qr3);
                            q = opq(max(opq((-(opq(1.0f)))), q));
                            nsubr = div_cr(opq((opq(q)) * (opq(nr3))), DT);
                        }
                        if ((eprdg < 0.0f)) {
                            var q: f32 = div_cr(opq((opq(eprdg)) * (opq(DT))), qg3);
                            q = opq(max(opq((-(opq(1.0f)))), q));
                            nsubg = div_cr(opq((opq(q)) * (opq(ng3))), DT);
                        }
                        mem_st(((SCRB + 896u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 896u) + bitcast<u32>(k))))) + (opq(nsubi)))));
                        mem_st(((SCRB + 1024u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1024u) + bitcast<u32>(k))))) + (opq(nsubs)))));
                        mem_st(((SCRB + 1280u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1280u) + bitcast<u32>(k))))) + (opq(nsubg)))));
                        mem_st(((SCRB + 1152u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1152u) + bitcast<u32>(k))))) + (opq(nsubr)))));
                        {
                            var dumt: f32 = opq(fma(opq(DT), bitcast<f32>(mem_ld(((SCRB + 128u) + bitcast<u32>(k)))), opq(t3)));
                            var dumqv: f32 = opq(fma(opq(DT), bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k)))), opq(qv3)));
                            var dumqc: f32 = opq(fma(opq(DT), bitcast<f32>(mem_ld(((SCRB + 256u) + bitcast<u32>(k)))), opq(qc3)));
                            var dumqr: f32 = opq(fma(opq(DT), bitcast<f32>(mem_ld(((SCRB + 640u) + bitcast<u32>(k)))), opq(qr3)));
                            var dummqs: f32 = opq(fma(opq(DT), bitcast<f32>(mem_ld(((SCRB + 512u) + bitcast<u32>(k)))), opq(qni3)));
                            var dumqg: f32 = opq(fma(opq(DT), bitcast<f32>(mem_ld(((SCRB + 768u) + bitcast<u32>(k)))), opq(qg3)));
                            var dumqi: f32 = opq(fma(opq(DT), bitcast<f32>(mem_ld(((SCRB + 384u) + bitcast<u32>(k)))), opq(qi3)));
                            pres = opq((opq((opq(rho)) * (opq(dumt)))) * (opq(fma(opq(p.rv), opq(dumqv), opq(p.r)))));
                            var saveqc: f32 = dumqc;
                            var savet: f32 = dumt;
                            f_morr_satadj2(p, &dumt, &pres, &dumqv, &dumqc, dumqr, dumqi, dummqs, dumqg, rho);
                            if (((abs(opq((opq(dumt)) - (opq(savet))))) >= 0.0001f)) {
                                var pccv: f32 = opq((opq((opq(dumqc)) - (opq(saveqc)))) * (opq(RDT)));
                                mem_st(((SCRB + 0u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k))))) - (opq(pccv)))));
                                mem_st(((SCRB + 256u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 256u) + bitcast<u32>(k))))) + (opq(pccv)))));
                                mem_st(((SCRB + 128u) + bitcast<u32>(k)), bitcast<u32>(opq(fma((opq((opq(dumt)) - (opq(savet)))), opq(RDT), bitcast<f32>(mem_ld(((SCRB + 128u) + bitcast<u32>(k))))))));
                            }
                        }
                    }
                    LTRUE = 1i;
                }
                mem_st(((SCRB + 1920u) + bitcast<u32>(k)), bitcast<u32>(lami));
                mem_st(((SCRB + 2048u) + bitcast<u32>(k)), bitcast<u32>(nc3));
                mem_st((T3 + bitcast<u32>(c)), bitcast<u32>(t3));
                mem_st((QV + bitcast<u32>(c)), bitcast<u32>(qv3));
                mem_st((QC + bitcast<u32>(c)), bitcast<u32>(qc3));
                mem_st((QR + bitcast<u32>(c)), bitcast<u32>(qr3));
                mem_st((QI + bitcast<u32>(c)), bitcast<u32>(qi3));
                mem_st((QS + bitcast<u32>(c)), bitcast<u32>(qni3));
                mem_st((QG + bitcast<u32>(c)), bitcast<u32>(qg3));
                mem_st((NI + bitcast<u32>(c)), bitcast<u32>(ni3));
                mem_st((NS + bitcast<u32>(c)), bitcast<u32>(ns3));
                mem_st((NR + bitcast<u32>(c)), bitcast<u32>(nr3));
                mem_st((NG + bitcast<u32>(c)), bitcast<u32>(ng3));
            continuing {
                k = (k + 1i);
            }
        }
    }
    var precrt: f32 = 0.0f;
    if ((LTRUE == 0i)) {
        return;
    }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 2944u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 3072u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 3200u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 3328u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 3456u + _z, 0u); }
    for (var _z = 0u; _z < 128u; _z++) { mem_st(SCRB + 3584u + _z, 0u); }
    {
        var s: i32 = 0i;
        loop {
            if (!((s < 5i))) { break; }
                var nstep: i32 = 1i;
                {
                    var k: i32 = (nk - 1i);
                    loop {
                        if (!((k >= 0i))) { break; }
                            var c: i32 = f_mi(p, i, j, k);
                            var rho: f32 = bitcast<f32>(mem_ld((RH3 + bitcast<u32>(c))));
                            var um: f32 = f32(0i);
                            var un: f32 = f32(0i);
                            var dq: f32;
                            var dn: f32;
                            if ((s == 0i)) {
                                dq = opq(fma(bitcast<f32>(mem_ld(((SCRB + 640u) + bitcast<u32>(k)))), opq(DT), bitcast<f32>(mem_ld((QR + bitcast<u32>(c))))));
                                dn = opq(fma(bitcast<f32>(mem_ld(((SCRB + 1152u) + bitcast<u32>(k)))), opq(DT), bitcast<f32>(mem_ld((NR + bitcast<u32>(c))))));
                            } else {
                                if ((s == 1i)) {
                                    dq = opq(fma(bitcast<f32>(mem_ld(((SCRB + 384u) + bitcast<u32>(k)))), opq(DT), bitcast<f32>(mem_ld((QI + bitcast<u32>(c))))));
                                    dn = opq(fma(bitcast<f32>(mem_ld(((SCRB + 896u) + bitcast<u32>(k)))), opq(DT), bitcast<f32>(mem_ld((NI + bitcast<u32>(c))))));
                                } else {
                                    if ((s == 2i)) {
                                        dq = opq(fma(bitcast<f32>(mem_ld(((SCRB + 256u) + bitcast<u32>(k)))), opq(DT), bitcast<f32>(mem_ld((QC + bitcast<u32>(c))))));
                                        dn = bitcast<f32>(mem_ld(((SCRB + 2048u) + bitcast<u32>(k))));
                                    } else {
                                        if ((s == 3i)) {
                                            dq = opq(fma(bitcast<f32>(mem_ld(((SCRB + 512u) + bitcast<u32>(k)))), opq(DT), bitcast<f32>(mem_ld((QS + bitcast<u32>(c))))));
                                            dn = opq(fma(bitcast<f32>(mem_ld(((SCRB + 1024u) + bitcast<u32>(k)))), opq(DT), bitcast<f32>(mem_ld((NS + bitcast<u32>(c))))));
                                        } else {
                                            dq = opq(fma(bitcast<f32>(mem_ld(((SCRB + 768u) + bitcast<u32>(k)))), opq(DT), bitcast<f32>(mem_ld((QG + bitcast<u32>(c))))));
                                            dn = opq(fma(bitcast<f32>(mem_ld(((SCRB + 1280u) + bitcast<u32>(k)))), opq(DT), bitcast<f32>(mem_ld((NG + bitcast<u32>(c))))));
                                        }
                                    }
                                }
                            }
                            dn = opq(max(0.0f, dn));
                            var d: f32 = opq(pow(div_cr(p.rhosu, rho), 0.54f));
                            if ((s == 0i)) {
                                if ((dq >= QSMALL)) {
                                    var dlamr: f32 = opq(pow(div_cr(opq((opq((opq(p.pi)) * (opq(p.rhow)))) * (opq(dn))), dq), div_cr(1.0f, 3.0f)));
                                    dlamr = opq(max(dlamr, p.lamminr));
                                    dlamr = opq(min(dlamr, p.lammaxr));
                                    var arn: f32 = opq((opq(d)) * (opq(p.ar)));
                                    un = div_cr(opq((opq(arn)) * (opq((*&p.cons)[6i]))), opq(pow(dlamr, p.br)));
                                    um = div_cr(opq((opq(arn)) * (opq((*&p.cons)[4i]))), (opq(pow(dlamr, p.br))));
                                }
                                um = opq(min(um, opq((opq(9.1f)) * (opq(d)))));
                                un = opq(min(un, opq((opq(9.1f)) * (opq(d)))));
                            } else {
                                if ((s == 1i)) {
                                    if ((dq >= QSMALL)) {
                                        var dlami: f32 = opq(pow(div_cr(opq((opq((*&p.cons)[12i])) * (opq(dn))), dq), div_cr(1.0f, p.di)));
                                        dlami = opq(max(dlami, p.lammini));
                                        dlami = opq(min(dlami, p.lammaxi));
                                        var ain: f32 = opq((opq(pow(div_cr(p.rhosu, rho), 0.35f))) * (opq(p.ai)));
                                        un = div_cr(opq((opq(ain)) * (opq((*&p.cons)[27i]))), opq(pow(dlami, p.bi)));
                                        um = div_cr(opq((opq(ain)) * (opq((*&p.cons)[28i]))), (opq(pow(dlami, p.bi))));
                                    }
                                    um = opq(min(um, opq((opq(1.2f)) * (opq(pow(div_cr(p.rhosu, rho), 0.35f))))));
                                    un = opq(min(un, opq((opq(1.2f)) * (opq(pow(div_cr(p.rhosu, rho), 0.35f))))));
                                } else {
                                    if ((s == 2i)) {
                                        if ((dq >= QSMALL)) {
                                            var pgam: f32 = opq(fma(opq(0.0005714f), (opq((opq(div_cr(bitcast<f32>(mem_ld(((SCRB + 2048u) + bitcast<u32>(k)))), 1e+06f))) * (opq(rho)))), opq(0.2714f)));
                                            pgam = opq((opq(div_cr(1.0f, f_sq(pgam)))) - (opq(1.0f)));
                                            pgam = opq(max(pgam, 2.0f));
                                            pgam = opq(min(pgam, 1e+01f));
                                            var dlamc: f32 = opq(pow(div_cr(opq((opq((opq((*&p.cons)[26i])) * (opq(dn)))) * (opq(f_morr_gamma(opq((opq(pgam)) + (opq(4.0f))))))), (opq((opq(dq)) * (opq(f_morr_gamma(opq((opq(pgam)) + (opq(1.0f))))))))), div_cr(1.0f, 3.0f)));
                                            var lmin: f32 = div_cr((opq((opq(pgam)) + (opq(1.0f)))), 6e-05f);
                                            var lmax: f32 = div_cr((opq((opq(pgam)) + (opq(1.0f)))), 1e-06f);
                                            dlamc = opq(max(dlamc, lmin));
                                            dlamc = opq(min(dlamc, lmax));
                                            var acn: f32 = bitcast<f32>(mem_ld(((SCRB + 2176u) + bitcast<u32>(k))));
                                            un = div_cr(opq((opq(acn)) * (opq(f_morr_gamma(opq((opq((opq(1.0f)) + (opq(p.bc)))) + (opq(pgam))))))), (opq((opq(pow(dlamc, p.bc))) * (opq(f_morr_gamma(opq((opq(pgam)) + (opq(1.0f)))))))));
                                            um = div_cr(opq((opq(acn)) * (opq(f_morr_gamma(opq((opq((opq(4.0f)) + (opq(p.bc)))) + (opq(pgam))))))), (opq((opq(pow(dlamc, p.bc))) * (opq(f_morr_gamma(opq((opq(pgam)) + (opq(4.0f)))))))));
                                        }
                                        if ((p.drizzleVt != 0.0f)) {
                                            if ((dq >= QSMALL)) {
                                                um = opq((opq((opq((opq(1.19e+08f)) * (opq(pow(div_cr(3.0f, (opq((opq((opq((opq((opq(4.0f)) * (opq(p.pi)))) * (opq(p.rhow)))) * (opq(p.ndcnst)))) * (opq(1e+06f))))), div_cr(2.0f, 3.0f)))))) * (opq(pow(opq((opq(rho)) * (opq(dq))), div_cr(2.0f, 3.0f)))))) * (opq(exp(5.0f * (opq(f_sq(opq(log(1.5f)))))))));
                                            } else {
                                                um = 0.0f;
                                            }
                                        }
                                    } else {
                                        if ((s == 3i)) {
                                            if ((dq >= QSMALL)) {
                                                var dlams: f32 = opq(pow(div_cr(opq((opq((*&p.cons)[1i])) * (opq(dn))), dq), div_cr(1.0f, p.ds)));
                                                dlams = opq(max(dlams, p.lammins));
                                                dlams = opq(min(dlams, p.lammaxs));
                                                var asn: f32 = opq((opq(d)) * (opq(p.as_)));
                                                um = div_cr(opq((opq(asn)) * (opq((*&p.cons)[3i]))), (opq(pow(dlams, p.bs))));
                                                un = div_cr(opq((opq(asn)) * (opq((*&p.cons)[5i]))), opq(pow(dlams, p.bs)));
                                            }
                                            um = opq(min(um, opq((opq(1.2f)) * (opq(d)))));
                                            un = opq(min(un, opq((opq(1.2f)) * (opq(d)))));
                                        } else {
                                            if ((dq >= QSMALL)) {
                                                var dlamg: f32 = opq(pow(div_cr(opq((opq((*&p.cons)[2i])) * (opq(dn))), dq), div_cr(1.0f, p.dg)));
                                                dlamg = opq(max(dlamg, p.lamming));
                                                dlamg = opq(min(dlamg, p.lammaxg));
                                                var agn: f32 = opq((opq(d)) * (opq(p.ag)));
                                                um = div_cr(opq((opq(agn)) * (opq((*&p.cons)[7i]))), (opq(pow(dlamg, p.bg))));
                                                un = div_cr(opq((opq(agn)) * (opq((*&p.cons)[8i]))), opq(pow(dlamg, p.bg)));
                                            }
                                            um = opq(min(um, opq((opq(2e+01f)) * (opq(d)))));
                                            un = opq(min(un, opq((opq(2e+01f)) * (opq(d)))));
                                        }
                                    }
                                }
                            }
                            mem_st(((SCRB + 2944u) + bitcast<u32>(k)), bitcast<u32>(um));
                            mem_st(((SCRB + 3072u) + bitcast<u32>(k)), bitcast<u32>(un));
                            if ((k <= (nk - 2i))) {
                                if (((bitcast<f32>(mem_ld(((SCRB + 2944u) + bitcast<u32>(k))))) < (1e-10f))) {
                                    mem_st(((SCRB + 2944u) + bitcast<u32>(k)), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 2944u) + bitcast<u32>((k + 1i)))))));
                                }
                                if (((bitcast<f32>(mem_ld(((SCRB + 3072u) + bitcast<u32>(k))))) < (1e-10f))) {
                                    mem_st(((SCRB + 3072u) + bitcast<u32>(k)), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 3072u) + bitcast<u32>((k + 1i)))))));
                                }
                            }
                            var temz: f32 = div_cr(1.0f, bitcast<f32>(mem_ld((DZQ + bitcast<u32>(k)))));
                            var rgvm: f32 = opq(max(bitcast<f32>(mem_ld(((SCRB + 2944u) + bitcast<u32>(k)))), bitcast<f32>(mem_ld(((SCRB + 3072u) + bitcast<u32>(k))))));
                            nstep = max(i32(opq(fma(opq((opq(rgvm)) * (opq(DT))), opq(temz), opq(1.0f)))), nstep);
                            mem_st(((SCRB + 3200u) + bitcast<u32>(k)), bitcast<u32>(opq((opq(dq)) * (opq(rho)))));
                            mem_st(((SCRB + 3328u) + bitcast<u32>(k)), bitcast<u32>(opq((opq(dn)) * (opq(rho)))));
                        continuing {
                            k = (k - 1i);
                        }
                    }
                }
                var dttmp: f32 = div_cr(DT, f32(nstep));
                {
                    var n: i32 = 0i;
                    loop {
                        if (!((n < nstep))) { break; }
                            {
                                var k: i32 = 0i;
                                loop {
                                    if (!((k < nk))) { break; }
                                        mem_st(((SCRB + 3456u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 2944u) + bitcast<u32>(k))))) * (bitcast<f32>(mem_ld(((SCRB + 3200u) + bitcast<u32>(k))))))));
                                        mem_st(((SCRB + 3584u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 3072u) + bitcast<u32>(k))))) * (bitcast<f32>(mem_ld(((SCRB + 3328u) + bitcast<u32>(k))))))));
                                    continuing {
                                        k = (k + 1i);
                                    }
                                }
                            }
                            var k: i32 = (nk - 1i);
                            var c: i32 = f_mi(p, i, j, k);
                            var temr: f32 = div_cr(1.0f, (opq((opq(f32(nstep))) * (bitcast<f32>(mem_ld((RH3 + bitcast<u32>(c))))))));
                            var temz: f32 = div_cr(1.0f, bitcast<f32>(mem_ld((DZQ + bitcast<u32>(k)))));
                            var faltnd: f32 = opq((bitcast<f32>(mem_ld(((SCRB + 3456u) + bitcast<u32>(k))))) * (opq(temz)));
                            var faltndn: f32 = opq((bitcast<f32>(mem_ld(((SCRB + 3584u) + bitcast<u32>(k))))) * (opq(temz)));
                            mem_st((((SCRB + 2304u) + (bitcast<u32>(s) * 128u)) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq((-(opq(faltnd)))), opq(temr), bitcast<f32>(mem_ld((((SCRB + 2304u) + (bitcast<u32>(s) * 128u)) + bitcast<u32>(k))))))));
                            if ((s == 0i)) {
                                mem_st(((SCRB + 1152u) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq((-(opq(faltndn)))), opq(temr), bitcast<f32>(mem_ld(((SCRB + 1152u) + bitcast<u32>(k))))))));
                            } else {
                                if ((s == 1i)) {
                                    mem_st(((SCRB + 896u) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq((-(opq(faltndn)))), opq(temr), bitcast<f32>(mem_ld(((SCRB + 896u) + bitcast<u32>(k))))))));
                                } else {
                                    if ((s == 2i)) {
                                        mem_st(((SCRB + 1408u) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq((-(opq(faltndn)))), opq(temr), bitcast<f32>(mem_ld(((SCRB + 1408u) + bitcast<u32>(k))))))));
                                    } else {
                                        if ((s == 3i)) {
                                            mem_st(((SCRB + 1024u) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq((-(opq(faltndn)))), opq(temr), bitcast<f32>(mem_ld(((SCRB + 1024u) + bitcast<u32>(k))))))));
                                        } else {
                                            mem_st(((SCRB + 1280u) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq((-(opq(faltndn)))), opq(temr), bitcast<f32>(mem_ld(((SCRB + 1280u) + bitcast<u32>(k))))))));
                                        }
                                    }
                                }
                            }
                            mem_st(((SCRB + 3200u) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq((-(opq(faltnd)))), opq(dttmp), bitcast<f32>(mem_ld(((SCRB + 3200u) + bitcast<u32>(k))))))));
                            mem_st(((SCRB + 3328u) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq((-(opq(faltndn)))), opq(dttmp), bitcast<f32>(mem_ld(((SCRB + 3328u) + bitcast<u32>(k))))))));
                            {
                                k = (nk - 2i);
                                loop {
                                    if (!((k >= 0i))) { break; }
                                        c = f_mi(p, i, j, k);
                                        temr = div_cr(1.0f, (opq((opq(f32(nstep))) * (bitcast<f32>(mem_ld((RH3 + bitcast<u32>(c))))))));
                                        temz = div_cr(1.0f, bitcast<f32>(mem_ld((DZQ + bitcast<u32>(k)))));
                                        faltnd = opq((opq((bitcast<f32>(mem_ld(((SCRB + 3456u) + bitcast<u32>((k + 1i)))))) - (bitcast<f32>(mem_ld(((SCRB + 3456u) + bitcast<u32>(k))))))) * (opq(temz)));
                                        faltndn = opq((opq((bitcast<f32>(mem_ld(((SCRB + 3584u) + bitcast<u32>((k + 1i)))))) - (bitcast<f32>(mem_ld(((SCRB + 3584u) + bitcast<u32>(k))))))) * (opq(temz)));
                                        mem_st((((SCRB + 2304u) + (bitcast<u32>(s) * 128u)) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq(faltnd), opq(temr), bitcast<f32>(mem_ld((((SCRB + 2304u) + (bitcast<u32>(s) * 128u)) + bitcast<u32>(k))))))));
                                        if ((s == 0i)) {
                                            mem_st(((SCRB + 1152u) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq(faltndn), opq(temr), bitcast<f32>(mem_ld(((SCRB + 1152u) + bitcast<u32>(k))))))));
                                        } else {
                                            if ((s == 1i)) {
                                                mem_st(((SCRB + 896u) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq(faltndn), opq(temr), bitcast<f32>(mem_ld(((SCRB + 896u) + bitcast<u32>(k))))))));
                                            } else {
                                                if ((s == 2i)) {
                                                    mem_st(((SCRB + 1408u) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq(faltndn), opq(temr), bitcast<f32>(mem_ld(((SCRB + 1408u) + bitcast<u32>(k))))))));
                                                } else {
                                                    if ((s == 3i)) {
                                                        mem_st(((SCRB + 1024u) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq(faltndn), opq(temr), bitcast<f32>(mem_ld(((SCRB + 1024u) + bitcast<u32>(k))))))));
                                                    } else {
                                                        mem_st(((SCRB + 1280u) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq(faltndn), opq(temr), bitcast<f32>(mem_ld(((SCRB + 1280u) + bitcast<u32>(k))))))));
                                                    }
                                                }
                                            }
                                        }
                                        mem_st(((SCRB + 3200u) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq(faltnd), opq(dttmp), bitcast<f32>(mem_ld(((SCRB + 3200u) + bitcast<u32>(k))))))));
                                        mem_st(((SCRB + 3328u) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq(faltndn), opq(dttmp), bitcast<f32>(mem_ld(((SCRB + 3328u) + bitcast<u32>(k))))))));
                                    continuing {
                                        k = (k - 1i);
                                    }
                                }
                            }
                            precrt = opq(fma(bitcast<f32>(mem_ld((SCRB + 3456u))), opq(dttmp), opq(precrt)));
                        continuing {
                            n = (n + 1i);
                        }
                    }
                }
            continuing {
                s = (s + 1i);
            }
        }
    }
    {
        var k: i32 = 0i;
        loop {
            if (!((k < nk))) { break; }
                var c: i32 = f_mi(p, i, j, k);
                var rho: f32 = bitcast<f32>(mem_ld((RH3 + bitcast<u32>(c))));
                mem_st(((SCRB + 640u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 640u) + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld(((SCRB + 2304u) + bitcast<u32>(k))))))));
                mem_st(((SCRB + 384u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 384u) + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((((SCRB + 2304u) + (bitcast<u32>(1i) * 128u)) + bitcast<u32>(k))))))));
                mem_st(((SCRB + 256u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 256u) + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((((SCRB + 2304u) + (bitcast<u32>(2i) * 128u)) + bitcast<u32>(k))))))));
                mem_st(((SCRB + 768u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 768u) + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((((SCRB + 2304u) + (bitcast<u32>(4i) * 128u)) + bitcast<u32>(k))))))));
                mem_st(((SCRB + 512u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 512u) + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((((SCRB + 2304u) + (bitcast<u32>(3i) * 128u)) + bitcast<u32>(k))))))));
                var t3: f32 = bitcast<f32>(mem_ld((T3 + bitcast<u32>(c))));
                var qv3: f32 = bitcast<f32>(mem_ld((QV + bitcast<u32>(c))));
                var qc3: f32 = bitcast<f32>(mem_ld((QC + bitcast<u32>(c))));
                var qr3: f32 = bitcast<f32>(mem_ld((QR + bitcast<u32>(c))));
                var qi3: f32 = bitcast<f32>(mem_ld((QI + bitcast<u32>(c))));
                var qni3: f32 = bitcast<f32>(mem_ld((QS + bitcast<u32>(c))));
                var qg3: f32 = bitcast<f32>(mem_ld((QG + bitcast<u32>(c))));
                var ni3: f32 = bitcast<f32>(mem_ld((NI + bitcast<u32>(c))));
                var ns3: f32 = bitcast<f32>(mem_ld((NS + bitcast<u32>(c))));
                var nr3: f32 = bitcast<f32>(mem_ld((NR + bitcast<u32>(c))));
                var ng3: f32 = bitcast<f32>(mem_ld((NG + bitcast<u32>(c))));
                var nc3: f32 = bitcast<f32>(mem_ld(((SCRB + 2048u) + bitcast<u32>(k))));
                var lami: f32 = bitcast<f32>(mem_ld(((SCRB + 1920u) + bitcast<u32>(k))));
                if ((((qi3 >= QSMALL) && (t3 < TMELT)) && (lami >= (1e-10f)))) {
                    if (((div_cr(1.0f, lami)) >= (opq((opq(2.0f)) * (opq(p.dcs)))))) {
                        mem_st(((SCRB + 512u) + bitcast<u32>(k)), bitcast<u32>(opq((opq((bitcast<f32>(mem_ld(((SCRB + 512u) + bitcast<u32>(k))))) + (opq(div_cr(qi3, DT))))) + (bitcast<f32>(mem_ld(((SCRB + 384u) + bitcast<u32>(k))))))));
                        mem_st(((SCRB + 1024u) + bitcast<u32>(k)), bitcast<u32>(opq((opq((bitcast<f32>(mem_ld(((SCRB + 1024u) + bitcast<u32>(k))))) + (opq(div_cr(ni3, DT))))) + (bitcast<f32>(mem_ld(((SCRB + 896u) + bitcast<u32>(k))))))));
                        mem_st(((SCRB + 384u) + bitcast<u32>(k)), bitcast<u32>(div_cr(opq((-(opq(qi3)))), DT)));
                        mem_st(((SCRB + 896u) + bitcast<u32>(k)), bitcast<u32>(div_cr(opq((-(opq(ni3)))), DT)));
                    }
                }
                qc3 = opq(fma(bitcast<f32>(mem_ld(((SCRB + 256u) + bitcast<u32>(k)))), opq(DT), opq(qc3)));
                qi3 = opq(fma(bitcast<f32>(mem_ld(((SCRB + 384u) + bitcast<u32>(k)))), opq(DT), opq(qi3)));
                qni3 = opq(fma(bitcast<f32>(mem_ld(((SCRB + 512u) + bitcast<u32>(k)))), opq(DT), opq(qni3)));
                qr3 = opq(fma(bitcast<f32>(mem_ld(((SCRB + 640u) + bitcast<u32>(k)))), opq(DT), opq(qr3)));
                nc3 = opq(fma(bitcast<f32>(mem_ld(((SCRB + 1408u) + bitcast<u32>(k)))), opq(DT), opq(nc3)));
                ni3 = opq(fma(bitcast<f32>(mem_ld(((SCRB + 896u) + bitcast<u32>(k)))), opq(DT), opq(ni3)));
                ns3 = opq(fma(bitcast<f32>(mem_ld(((SCRB + 1024u) + bitcast<u32>(k)))), opq(DT), opq(ns3)));
                nr3 = opq(fma(bitcast<f32>(mem_ld(((SCRB + 1152u) + bitcast<u32>(k)))), opq(DT), opq(nr3)));
                qg3 = opq(fma(bitcast<f32>(mem_ld(((SCRB + 768u) + bitcast<u32>(k)))), opq(DT), opq(qg3)));
                ng3 = opq(fma(bitcast<f32>(mem_ld(((SCRB + 1280u) + bitcast<u32>(k)))), opq(DT), opq(ng3)));
                t3 = opq(fma(bitcast<f32>(mem_ld(((SCRB + 128u) + bitcast<u32>(k)))), opq(DT), opq(t3)));
                qv3 = opq(fma(bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k)))), opq(DT), opq(qv3)));
                var pres: f32 = opq((opq((opq(rho)) * (opq(t3)))) * (opq(fma(opq(p.rv), opq(qv3), opq(p.r)))));
                var evs: f32 = opq(min(opq((opq(pres)) * (opq(0.5f))), opq((opq(611.2f)) * (opq(exp(div_cr(opq((opq(17.67f)) * (opq((opq(t3)) - (opq(273.15f))))), (opq((opq(t3)) - (opq(29.65f)))))))))));
                var eis: f32 = opq(min(opq((opq(pres)) * (opq(0.5f))), opq((opq(611.2f)) * (opq(exp(div_cr(opq((opq(21.874557f)) * (opq((opq(t3)) - (opq(273.15f))))), (opq((opq(t3)) - (opq(7.66f)))))))))));
                if ((eis > evs)) {
                    eis = evs;
                }
                var qvs: f32 = div_cr(opq((opq(p.ep2)) * (opq(evs))), (opq((opq(pres)) - (opq(evs)))));
                var qvi: f32 = div_cr(opq((opq(p.ep2)) * (opq(eis))), (opq((opq(pres)) - (opq(eis)))));
                var qvqvs: f32 = div_cr(qv3, qvs);
                var qvqvsi: f32 = div_cr(qv3, qvi);
                var ecnd: f32 = bitcast<f32>(mem_ld(((SCRB + 1536u) + bitcast<u32>(k))));
                var edep: f32 = bitcast<f32>(mem_ld(((SCRB + 1664u) + bitcast<u32>(k))));
                var efrz: f32 = bitcast<f32>(mem_ld(((SCRB + 1792u) + bitcast<u32>(k))));
                if ((qvqvs < 0.9f)) {
                    if ((qr3 < p.qthr)) {
                        qv3 = opq((opq(qv3)) + (opq(qr3)));
                        t3 = opq(fma(opq((-(opq(qr3)))), opq(ecnd), opq(t3)));
                        qr3 = 0.0f;
                    }
                    if ((qc3 < p.qthr)) {
                        qv3 = opq((opq(qv3)) + (opq(qc3)));
                        t3 = opq(fma(opq((-(opq(qc3)))), opq(ecnd), opq(t3)));
                        qc3 = 0.0f;
                    }
                }
                if ((qvqvsi < 0.9f)) {
                    if ((qi3 < p.qthr)) {
                        qv3 = opq((opq(qv3)) + (opq(qi3)));
                        t3 = opq(fma(opq((-(opq(qi3)))), opq(edep), opq(t3)));
                        qi3 = 0.0f;
                    }
                    if ((qni3 < p.qthr)) {
                        qv3 = opq((opq(qv3)) + (opq(qni3)));
                        t3 = opq(fma(opq((-(opq(qni3)))), opq(edep), opq(t3)));
                        qni3 = 0.0f;
                    }
                    if ((qg3 < p.qthr)) {
                        qv3 = opq((opq(qv3)) + (opq(qg3)));
                        t3 = opq(fma(opq((-(opq(qg3)))), opq(edep), opq(t3)));
                        qg3 = 0.0f;
                    }
                }
                if ((qc3 < QSMALL)) {
                    qc3 = 0.0f;
                    nc3 = 0.0f;
                }
                if ((qr3 < QSMALL)) {
                    qr3 = 0.0f;
                    nr3 = 0.0f;
                }
                if ((qi3 < QSMALL)) {
                    qi3 = 0.0f;
                    ni3 = 0.0f;
                }
                if ((qni3 < QSMALL)) {
                    qni3 = 0.0f;
                    ns3 = 0.0f;
                }
                if ((qg3 < QSMALL)) {
                    qg3 = 0.0f;
                    ng3 = 0.0f;
                }
                var goto500: bool = (((((qc3 < QSMALL) && (qi3 < QSMALL)) && (qni3 < QSMALL)) && (qr3 < QSMALL)) && (qg3 < QSMALL));
                if ((!goto500)) {
                    if (((qi3 >= QSMALL) && (t3 >= TMELT))) {
                        qr3 = opq((opq(qr3)) + (opq(qi3)));
                        t3 = opq(fma(opq((-(opq(qi3)))), opq(efrz), opq(t3)));
                        qi3 = 0.0f;
                        nr3 = opq((opq(nr3)) + (opq(ni3)));
                        ni3 = 0.0f;
                    }
                    if (((t3 <= 233.15f) && (qc3 >= QSMALL))) {
                        qi3 = opq((opq(qi3)) + (opq(qc3)));
                        t3 = opq(fma(opq(qc3), opq(efrz), opq(t3)));
                        qc3 = 0.0f;
                        ni3 = opq((opq(ni3)) + (opq(nc3)));
                        nc3 = 0.0f;
                    }
                    if (((t3 <= 233.15f) && (qr3 >= QSMALL))) {
                        qg3 = opq((opq(qg3)) + (opq(qr3)));
                        t3 = opq(fma(opq(qr3), opq(efrz), opq(t3)));
                        qr3 = 0.0f;
                        ng3 = opq((opq(ng3)) + (opq(nr3)));
                        nr3 = 0.0f;
                    }
                    ni3 = opq(max(0.0f, ni3));
                    ns3 = opq(max(0.0f, ns3));
                    nc3 = opq(max(0.0f, nc3));
                    nr3 = opq(max(0.0f, nr3));
                    ng3 = opq(max(0.0f, ng3));
                    var lam: f32;
                    var n0: f32;
                    var lami: f32 = f32(0i);
                    var lams: f32 = f32(0i);
                    var lamcF: f32 = f32(0i);
                    var pgamF: f32 = f32(0i);
                    if ((qi3 >= QSMALL)) {
                        f_morr_lam3(qi3, &ni3, (*&p.cons)[12i], p.di, p.lammini, p.lammaxi, &lam, &n0);
                        lami = lam;
                    }
                    if ((qr3 >= QSMALL)) {
                        f_morr_lamr(p, qr3, &nr3, &lam, &n0);
                    }
                    if ((qc3 >= QSMALL)) {
                        var cd: f32;
                        f_morr_lamc(p, qc3, &nc3, rho, &pgamF, &lamcF, &cd);
                    }
                    if ((qni3 >= QSMALL)) {
                        f_morr_lam3(qni3, &ns3, (*&p.cons)[1i], p.ds, p.lammins, p.lammaxs, &lam, &n0);
                        lams = lam;
                    }
                    if ((qg3 >= QSMALL)) {
                        f_morr_lam3(qg3, &ng3, (*&p.cons)[2i], p.dg, p.lamming, p.lammaxg, &lam, &n0);
                    }
                    if ((dorad != 0i)) {
                        var effi: f32 = select(25.0f, opq((opq(div_cr(div_cr(3.0f, lami), 2.0f))) * (opq(1e+06f))), (qi3 >= QSMALL));
                        var effs: f32 = select(25.0f, opq((opq(div_cr(div_cr(3.0f, lams), 2.0f))) * (opq(1e+06f))), (qni3 >= QSMALL));
                        var _t1: f32;
                        if ((qc3 >= QSMALL)) {
                            _t1 = opq((opq(div_cr(div_cr(div_cr(f_morr_gamma(opq((opq(pgamF)) + (opq(4.0f)))), f_morr_gamma(opq((opq(pgamF)) + (opq(3.0f))))), lamcF), 2.0f))) * (opq(1e+06f)));
                        } else {
                            _t1 = 25.0f;
                        }
                        var effc: f32 = _t1;
                        mem_st((EFFC + bitcast<u32>(c)), bitcast<u32>(opq((opq(effc)) * (opq(1e-06f)))));
                        mem_st((EFFI + bitcast<u32>(c)), bitcast<u32>(opq((opq(min(1.4e+02f, effi))) * (opq(1e-06f)))));
                        mem_st((EFFS + bitcast<u32>(c)), bitcast<u32>(opq((opq(effs)) * (opq(1e-06f)))));
                    }
                }
                ni3 = opq(min(ni3, div_cr(3e+05f, rho)));
                nc3 = div_cr(opq((opq(p.ndcnst)) * (opq(1e+06f))), rho);
                mem_st((T3 + bitcast<u32>(c)), bitcast<u32>(t3));
                mem_st((QV + bitcast<u32>(c)), bitcast<u32>(qv3));
                mem_st((QC + bitcast<u32>(c)), bitcast<u32>(qc3));
                mem_st((QR + bitcast<u32>(c)), bitcast<u32>(qr3));
                mem_st((QI + bitcast<u32>(c)), bitcast<u32>(qi3));
                mem_st((QS + bitcast<u32>(c)), bitcast<u32>(qni3));
                mem_st((QG + bitcast<u32>(c)), bitcast<u32>(qg3));
                mem_st((NI + bitcast<u32>(c)), bitcast<u32>(ni3));
                mem_st((NS + bitcast<u32>(c)), bitcast<u32>(ns3));
                mem_st((NR + bitcast<u32>(c)), bitcast<u32>(nr3));
                mem_st((NG + bitcast<u32>(c)), bitcast<u32>(ng3));
            continuing {
                k = (k + 1i);
            }
        }
    }
    let _t2 = f_mi(p, i, j, 0i);
    mem_st((sfc + bitcast<u32>(_t2)), bitcast<u32>(opq((bitcast<f32>(mem_ld((sfc + bitcast<u32>(_t2))))) + (opq(precrt)))));
}
