// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// rrlw_columns: сгенерировано, не править руками.

@group(0) @binding(0) var<storage, read_write> M: array<atomic<u32>>;
@group(0) @binding(1) var<storage, read> ARG: array<u32>;
fn mem_ld(o: u32) -> u32 { return atomicLoad(&M[o]); }
fn mem_st(o: u32, v: u32) { atomicStore(&M[o], v); }


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


struct S_RRLWParams {
    nk: i32,
    nlayers: i32,
    ncol: i32,
    colOffset: i32,
    co2: f32,
    fluxfac: f32,
    heatfac: f32,
    bpade: f32,
    debugCol: i32,
    zero: u32,
}

struct S_RRLWColumn {
    laytrop: i32,
    nlayers: i32,
    z0: u32,
    pavel: u32,
    tavel: u32,
    coldry: u32,
    colh2o: u32,
    colco2: u32,
    colo3: u32,
    coln2o: u32,
    colco: u32,
    colch4: u32,
    colo2: u32,
    colbrd: u32,
    fac00: u32,
    fac01: u32,
    fac10: u32,
    fac11: u32,
    selffac: u32,
    selffrac: u32,
    forfac: u32,
    forfrac: u32,
    minorfrac: u32,
    scaleminor: u32,
    scaleminorn2: u32,
    rat_h2oco2: u32,
    rat_h2oco2_1: u32,
    rat_h2oo3: u32,
    rat_h2oo3_1: u32,
    rat_h2on2o: u32,
    rat_h2on2o_1: u32,
    rat_h2och4: u32,
    rat_h2och4_1: u32,
    rat_n2oco2: u32,
    rat_n2oco2_1: u32,
    rat_o3co2: u32,
    rat_o3co2_1: u32,
    wx: u32,
    jp: u32,
    jt: u32,
    jt1: u32,
    indself: u32,
    indfor: u32,
    indminor: u32,
}

const K_RR_AMDW: f32 = 1.607793f;

const K_RR_DELTAP: f32 = 4.0f;

const K_RR_AMDO: f32 = 0.603461f;

const K_RR_N2O: f32 = 3.19e-07f;

const K_RR_CH4: f32 = 1.774e-06f;

const K_RR_O2: f32 = 0.209488f;

const K_RR_AMD: f32 = 28.966f;

const K_RR_AMW: f32 = 18.016f;

const K_RR_AVOGAD: f32 = 6.022142e+23f;

const K_RR_GRAV: f32 = 9.8066f;

const K_RR_CCL4: f32 = 9.3e-11f;

const K_RR_CFC11: f32 = 2.51e-10f;

const K_RR_CFC12: f32 = 5.38e-10f;

const K_RR_CFC22: f32 = 1.69e-10f;

const K_RR_A0: array<f32, 16> = array<f32, 16>(1.66f, 1.55f, 1.58f, 1.66f, 1.54f, 1.454f, 1.89f, 1.33f, 1.668f, 1.66f, 1.66f, 1.66f, 1.66f, 1.66f, 1.66f, 1.66f);

const K_RR_A1: array<f32, 16> = array<f32, 16>(0.0f, 0.25f, 0.22f, 0.0f, 0.13f, 0.446f, (-0.1f), 0.4f, (-0.006f), 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f);

const K_RR_A2: array<f32, 16> = array<f32, 16>(0.0f, (-12.0f), (-11.7f), 0.0f, (-0.72f), (-0.243f), 0.19f, (-0.062f), 0.414f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f);

const K_RRLW_NSPA: array<i32, 16> = array<i32, 16>(1i, 1i, 9i, 9i, 9i, 1i, 9i, 1i, 9i, 1i, 1i, 9i, 9i, 1i, 9i, 9i);

const K_RRLW_NSPB: array<i32, 16> = array<i32, 16>(1i, 1i, 5i, 5i, 5i, 0i, 1i, 1i, 1i, 1i, 1i, 0i, 0i, 1i, 0i, 0i);

const K_RR_ONEMINUS: f32 = 0.999999f;

const K_RRLW_NG: array<i32, 16> = array<i32, 16>(10i, 12i, 16i, 14i, 16i, 8i, 12i, 8i, 12i, 6i, 8i, 8i, 4i, 2i, 2i, 2i);

const K_RR_REC6: f32 = 0.166667f;

const K_RR_WTDIFF: f32 = 0.5f;

fn ld_RRLWParams(o: u32) -> S_RRLWParams {
    var s: S_RRLWParams;
    s.nk = bitcast<i32>(mem_ld((o + 0u)));
    s.nlayers = bitcast<i32>(mem_ld((o + 1u)));
    s.ncol = bitcast<i32>(mem_ld((o + 2u)));
    s.colOffset = bitcast<i32>(mem_ld((o + 3u)));
    s.co2 = bitcast<f32>(mem_ld((o + 4u)));
    s.fluxfac = bitcast<f32>(mem_ld((o + 5u)));
    s.heatfac = bitcast<f32>(mem_ld((o + 6u)));
    s.bpade = bitcast<f32>(mem_ld((o + 7u)));
    s.debugCol = bitcast<i32>(mem_ld((o + 8u)));
    s.zero = mem_ld((o + 9u));
    return s;
}

fn f_rrlw_scratch_floats(nl_in: i32) -> i32 {
    var nl: i32 = nl_in;
    return (((((((60i * nl) + (9i * (nl + 1i))) + ((16i * nl) * 3i)) + (16i * (nl + 1i))) + 16i) + (4i * nl)) + (7i * nl));
}

fn f_rrlw_scratch_ints(nl_in: i32) -> i32 {
    var nl: i32 = nl_in;
    return ((7i * nl) + (f_rrlw_cloud_words(nl)));
}

fn f_rrlw_cloud_words(nl_in: i32) -> i32 {
    var nl: i32 = nl_in;
    return (((140i * nl) + 31i) / 32i);
}

fn lam_1(n_in: i32, S: u32, o: ptr<function, i32>) -> u32 {
    var n: i32 = n_in;
    var p: u32 = (S + bitcast<u32>((*o)));
    (*o) = ((*o) + n);
    return p;
}

fn lam_2(sd: ptr<function, array<u32, 4>>) -> f32 {
    (*sd)[0i] = ((69069u * ((*sd)[0i])) + 1327217885u);
    var x: u32 = (*sd)[1i];
    x = (x ^ (x << u32(13i)));
    x = (x ^ (x >> u32(17i)));
    x = (x ^ (x << u32(5i)));
    (*sd)[1i] = x;
    (*sd)[2i] = ((18000u * (((*sd)[2i]) & 65535u)) + (((*sd)[2i]) >> u32(16i)));
    (*sd)[3i] = ((30903u * (((*sd)[3i]) & 65535u)) + (((*sd)[3i]) >> u32(16i)));
    var k: i32 = i32((((((*sd)[0i]) + ((*sd)[1i])) + (((*sd)[2i]) << u32(16i))) + ((*sd)[3i])));
    return opq(fma(opq(f32(k)), opq(2.328306e-10f), opq(0.5f)));
}

fn f_rr_log_cr(x_in: f32) -> f32 {
    var x: f32 = x_in;
    if (((!(x > 0.0f)) || ((bitcast<u32>(x) & 0x7fffffffu) == 0x7f800000u))) {
        return opq(log(x));
    }
    var a: vec2<f32> = f_rr_log_ff(x);
    return opq((opq(a.x)) + (opq(a.y)));
}

fn f_rr_log_ff(x_in: f32) -> vec2<f32> {
    var x: f32 = x_in;
    var e: i32;
    let _t1 = frexp(x);
    e = _t1.exp;
    var m: f32 = _t1.fract;
    if ((m < 0.70710677f)) {
        m = opq((opq(m)) * (opq(2.0f)));
        e = (e - 1i);
    }
    var f: f32 = opq((opq(m)) - (opq(1.0f)));
    var d: vec2<f32> = f_rr_two_sum(2.0f, f);
    var sh: f32 = div_cr(f, d.x);
    var r: f32 = opq(fma(opq((-(opq(sh)))), opq(d.x), opq(f)));
    r = opq(fma(opq((-(opq(sh)))), opq(d.y), opq(r)));
    var sf: vec2<f32> = f_rr_quick_two_sum(sh, div_cr(r, d.x));
    var s2: vec2<f32> = f_rr_mul_ff(sf, sf);
    var s3: vec2<f32> = f_rr_mul_ff(s2, sf);
    var P: vec2<f32> = vec2<f32>(0.11764706f, opq((-(opq(4.3826945e-10f)))));
    P = f_rr_add_ff(f_rr_mul_ff(P, s2), vec2<f32>(0.13333334f, opq((-(opq(6.9538753e-09f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, s2), vec2<f32>(0.15384616f, opq((-(opq(5.731216e-09f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, s2), vec2<f32>(0.18181819f, opq((-(opq(5.4186042e-09f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, s2), vec2<f32>(0.22222222f, opq((-(opq(1.6556846e-09f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, s2), vec2<f32>(0.2857143f, opq((-(opq(1.2772424e-08f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, s2), vec2<f32>(0.4f, opq((-(opq(5.9604646e-09f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, s2), vec2<f32>(0.6666667f, opq((-(opq(1.9868216e-08f))))));
    var l1p: vec2<f32> = f_rr_add_ff(vec2<f32>(opq((opq(2.0f)) * (opq(sf.x))), opq((opq(2.0f)) * (opq(sf.y)))), f_rr_mul_ff(s3, P));
    var ln2h: f32 = 0.69314575f;
    var ln2m: f32 = 1.4285906e-06f;
    var ln2l: f32 = 1.6198487e-11f;
    var fe: f32 = f32(e);
    var a: vec2<f32> = f_rr_add_ff(vec2<f32>(opq((opq(fe)) * (opq(ln2h))), opq((opq(fe)) * (opq(ln2m)))), l1p);
    return f_rr_add_ff(a, vec2<f32>(opq((opq(fe)) * (opq(ln2l))), 0.0f));
}

fn f_rr_two_sum(a_in: f32, b_in: f32) -> vec2<f32> {
    var a: f32 = a_in;
    var b: f32 = b_in;
    var s: f32 = opq((opq(a)) + (opq(b)));
    var bb: f32 = opq((opq(s)) - (opq(a)));
    return vec2<f32>(s, opq((opq((opq(a)) - (opq((opq(s)) - (opq(bb)))))) + (opq((opq(b)) - (opq(bb))))));
}

fn f_rr_quick_two_sum(a_in: f32, b_in: f32) -> vec2<f32> {
    var a: f32 = a_in;
    var b: f32 = b_in;
    var s: f32 = opq((opq(a)) + (opq(b)));
    return vec2<f32>(s, opq((opq(b)) - (opq((opq(s)) - (opq(a))))));
}

fn f_rr_mul_ff(a_in: vec2<f32>, b_in: vec2<f32>) -> vec2<f32> {
    var a: vec2<f32> = a_in;
    var b: vec2<f32> = b_in;
    var p: f32 = opq((opq(a.x)) * (opq(b.x)));
    var e: f32 = opq(fma(opq(a.x), opq(b.x), opq((-(opq(p))))));
    e = opq(fma(opq(a.x), opq(b.y), opq(e)));
    e = opq(fma(opq(a.y), opq(b.x), opq(e)));
    return f_rr_quick_two_sum(p, e);
}

fn f_rr_add_ff(a_in: vec2<f32>, b_in: vec2<f32>) -> vec2<f32> {
    var a: vec2<f32> = a_in;
    var b: vec2<f32> = b_in;
    var s: vec2<f32> = f_rr_two_sum(a.x, b.x);
    var t: vec2<f32> = f_rr_two_sum(a.y, b.y);
    var u: vec2<f32> = f_rr_quick_two_sum(s.x, opq((opq(s.y)) + (opq(t.x))));
    return f_rr_quick_two_sum(u.x, opq((opq(u.y)) + (opq(t.y))));
}

fn f_rr_exp_cr(x_in: f32) -> f32 {
    var x: f32 = x_in;
    if ((!((x > (opq((-(opq(87.3f)))))) && (x < 88.7f)))) {
        return opq(exp(x));
    }
    return f_rr_exp_ff(vec2<f32>(x, 0.0f));
}

fn f_rr_exp_ff(y_in: vec2<f32>) -> f32 {
    var y: vec2<f32> = y_in;
    var ln2h: f32 = 0.69314575f;
    var ln2m: f32 = 1.4285906e-06f;
    var ln2l: f32 = 1.6198487e-11f;
    var k: f32 = round(div_cr(y.x, 0.6931472f));
    var r: vec2<f32> = f_rr_add_ff(y, vec2<f32>(opq((opq((-(opq(k))))) * (opq(ln2h))), opq((opq((-(opq(k))))) * (opq(ln2m)))));
    r = f_rr_add_ff(r, vec2<f32>(opq((opq((-(opq(k))))) * (opq(ln2l))), 0.0f));
    var P: vec2<f32> = vec2<f32>(2.5052108e-08f, 4.417623e-16f);
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(2.755732e-07f, opq((-(opq(7.575112e-15f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(2.7557319e-06f, 3.7935712e-14f));
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(2.4801588e-05f, opq((-(opq(3.406996e-13f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(0.0001984127f, opq((-(opq(2.7255969e-12f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(0.0013888889f, opq((-(opq(3.3631094e-11f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(0.008333334f, opq((-(opq(4.346172e-10f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(0.041666668f, opq((-(opq(1.2417635e-09f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(0.16666667f, opq((-(opq(4.967054e-09f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(0.5f, 0.0f));
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(1.0f, 0.0f));
    var Q: vec2<f32> = f_rr_mul_ff(P, r);
    var s: f32 = opq((opq(1.0f)) + (opq(Q.x)));
    var t: f32 = opq((opq((opq(1.0f)) - (opq(s)))) + (opq(Q.x)));
    var ur: vec2<f32> = f_rr_two_sum(t, Q.y);
    var res: f32 = opq((opq(s)) + (opq(ur.x)));
    var bb: f32 = opq((opq(res)) - (opq(s)));
    var e3: f32 = opq((opq((opq(s)) - (opq((opq(res)) - (opq(bb)))))) + (opq((opq(ur.x)) - (opq(bb)))));
    if ((((e3 != 0.0f) && (ur.y != 0.0f)) && ((i32((e3 > 0.0f))) == (i32((ur.y > 0.0f)))))) {
        var nb: f32 = bitcast<f32>(((bitcast<u32>(res)) + (select(4294967295u, 1u, (e3 > 0.0f)))));
        if (((opq((opq(e3)) + (opq(e3)))) == (opq((opq(nb)) - (opq(res)))))) {
            res = nb;
        }
    }
    return ldexp(res, i32(k));
}

fn f_rrlw_taugb1(C: ptr<function, S_RRLWColumn>, T_in: u32, taugL_in: u32, fracsL_in: u32) {
    var T: u32 = T_in;
    var taugL: u32 = taugL_in;
    var fracsL: u32 = fracsL_in;
    var corradj: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var indm: i32 = 0i;
    var inds: i32 = 0i;
    var lay: i32 = 0i;
    var pp: f32 = f32(0i);
    var scalen2: f32 = f32(0i);
    var taufor: f32 = f32(0i);
    var taun2: f32 = f32(0i);
    var tauself: f32 = f32(0i);
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((1i) - 1i)])) + 1i);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((1i) - 1i)])) + 1i);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                indm = bitcast<i32>(mem_ld(((*C).indminor + bitcast<u32>((lay - 1i)))));
                pp = bitcast<f32>(mem_ld(((*C).pavel + bitcast<u32>((lay - 1i)))));
                corradj = 1.0f;
                if (((bitcast<f32>(mem_ld(((*C).pavel + bitcast<u32>((lay - 1i)))))) < (2.5e+02f))) {
                    var r0: f32 = opq((opq(2.5e+02f)) - (opq(pp)));
                    var r1: f32 = opq((opq(0.15f)) * (opq(r0)));
                    var r2: f32 = div_cr(r1, 154.4f);
                    var r3: f32 = opq((opq(1.0f)) - (opq(r2)));
                    corradj = r3;
                }
                var r4: f32 = opq((bitcast<f32>(mem_ld(((*C).colbrd + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld(((*C).scaleminorn2 + bitcast<u32>((lay - 1i)))))));
                scalen2 = r4;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 10i))) { break; }
                            var r5: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((3813i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((3813i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r7: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r5), bitcast<f32>(mem_ld((T + bitcast<u32>(((3813i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r9: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((3913i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((3913i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r11: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r9), bitcast<f32>(mem_ld((T + bitcast<u32>(((3913i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r13: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((3433i + ((indm + 1i) - 1i)) + ((ig - 1i) * 19i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((3433i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            var r15: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r13), bitcast<f32>(mem_ld((T + bitcast<u32>(((3433i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            var r18: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((433i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 65i))))))));
                            var r19: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((433i + (ind0 - 1i)) + ((ig - 1i) * 65i)))))), opq(r18)));
                            var r21: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((433i + (ind1 - 1i)) + ((ig - 1i) * 65i)))))), opq(r19)));
                            var r23: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((433i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 65i)))))), opq(r21)));
                            var r24: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (opq(r23)));
                            var r25: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i))))), opq(r7), opq(r24)));
                            var r26: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i))))), opq(r11), opq(r25)));
                            var r27: f32 = opq(fma(opq(scalen2), opq(r15), opq(r26)));
                            var r28: f32 = opq((opq(corradj)) * (opq(r27)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + ((ig - 0i) - 1i)))), bitcast<u32>(r28));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + ((ig - 0i) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((413i + (ig - 1i))))))));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((1i) - 1i)])) + 1i);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((1i) - 1i)])) + 1i);
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                indm = bitcast<i32>(mem_ld(((*C).indminor + bitcast<u32>((lay - 1i)))));
                pp = bitcast<f32>(mem_ld(((*C).pavel + bitcast<u32>((lay - 1i)))));
                var r29: f32 = div_cr(bitcast<f32>(mem_ld(((*C).pavel + bitcast<u32>((lay - 1i))))), 95.6f);
                var r31: f32 = opq(fma(opq(f_rr_neg(0.15f, (*C).z0)), opq(r29), opq(1.0f)));
                corradj = r31;
                var r32: f32 = opq((bitcast<f32>(mem_ld(((*C).colbrd + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld(((*C).scaleminorn2 + bitcast<u32>((lay - 1i)))))));
                scalen2 = r32;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 10i))) { break; }
                            var r33: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((3913i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((3913i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r35: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r33), bitcast<f32>(mem_ld((T + bitcast<u32>(((3913i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r37: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((3623i + ((indm + 1i) - 1i)) + ((ig - 1i) * 19i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((3623i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            var r39: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r37), bitcast<f32>(mem_ld((T + bitcast<u32>(((3623i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            var r42: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((1083i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 235i))))))));
                            var r43: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((1083i + (ind0 - 1i)) + ((ig - 1i) * 235i)))))), opq(r42)));
                            var r45: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((1083i + (ind1 - 1i)) + ((ig - 1i) * 235i)))))), opq(r43)));
                            var r47: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((1083i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 235i)))))), opq(r45)));
                            var r48: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (opq(r47)));
                            var r49: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i))))), opq(r35), opq(r48)));
                            var r50: f32 = opq(fma(opq(scalen2), opq(r39), opq(r49)));
                            var r51: f32 = opq((opq(corradj)) * (opq(r50)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + ((ig - 0i) - 1i)))), bitcast<u32>(r51));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + ((ig - 0i) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((423i + (ig - 1i))))))));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rr_neg(x_in: f32, z0_in: u32) -> f32 {
    var x: f32 = x_in;
    var z0: u32 = z0_in;
    return bitcast<f32>(((bitcast<u32>(x)) ^ (2147483648u ^ z0)));
}

fn f_rrlw_taugb2(C: ptr<function, S_RRLWColumn>, T_in: u32, taugL_in: u32, fracsL_in: u32) {
    var T: u32 = T_in;
    var taugL: u32 = taugL_in;
    var fracsL: u32 = fracsL_in;
    var corradj: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var lay: i32 = 0i;
    var pp: f32 = f32(0i);
    var taufor: f32 = f32(0i);
    var tauself: f32 = f32(0i);
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((2i) - 1i)])) + 1i);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((2i) - 1i)])) + 1i);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                pp = bitcast<f32>(mem_ld(((*C).pavel + bitcast<u32>((lay - 1i)))));
                var r0: f32 = opq((bitcast<f32>(mem_ld(((*C).pavel + bitcast<u32>((lay - 1i)))))) - (opq(1e+02f)));
                var r1: f32 = opq((opq(0.05f)) * (opq(r0)));
                var r2: f32 = div_cr(r1, 9e+02f);
                var r3: f32 = opq((opq(1.0f)) - (opq(r2)));
                corradj = r3;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 12i))) { break; }
                            var r4: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((7577i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((7577i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r6: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r4), bitcast<f32>(mem_ld((T + bitcast<u32>(((7577i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r8: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((7697i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((7697i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r10: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r8), bitcast<f32>(mem_ld((T + bitcast<u32>(((7697i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r13: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((3977i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 65i))))))));
                            var r14: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((3977i + (ind0 - 1i)) + ((ig - 1i) * 65i)))))), opq(r13)));
                            var r16: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((3977i + (ind1 - 1i)) + ((ig - 1i) * 65i)))))), opq(r14)));
                            var r18: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((3977i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 65i)))))), opq(r16)));
                            var r19: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (opq(r18)));
                            var r20: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i))))), opq(r6), opq(r19)));
                            var r21: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i))))), opq(r10), opq(r20)));
                            var r22: f32 = opq((opq(corradj)) * (opq(r21)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((10i + ig) - 10i) - 1i)))), bitcast<u32>(r22));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((10i + ig) - 10i) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((3953i + (ig - 1i))))))));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((2i) - 1i)])) + 1i);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((2i) - 1i)])) + 1i);
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 12i))) { break; }
                            var r23: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((7697i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((7697i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r25: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r23), bitcast<f32>(mem_ld((T + bitcast<u32>(((7697i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r28: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((4757i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 235i))))))));
                            var r29: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((4757i + (ind0 - 1i)) + ((ig - 1i) * 235i)))))), opq(r28)));
                            var r31: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((4757i + (ind1 - 1i)) + ((ig - 1i) * 235i)))))), opq(r29)));
                            var r33: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((4757i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 235i)))))), opq(r31)));
                            var r34: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (opq(r33)));
                            var r35: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i))))), opq(r25), opq(r34)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((10i + ig) - 10i) - 1i)))), bitcast<u32>(r35));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((10i + ig) - 10i) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((3965i + (ig - 1i))))))));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrlw_taugb3(C: ptr<function, S_RRLWColumn>, T_in: u32, taugL_in: u32, fracsL_in: u32) {
    var T: u32 = T_in;
    var taugL: u32 = taugL_in;
    var fracsL: u32 = fracsL_in;
    var absn2o: f32 = f32(0i);
    var adjcoln2o: f32 = f32(0i);
    var adjfac: f32 = f32(0i);
    var chi_n2o: f32 = f32(0i);
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fac200: f32 = f32(0i);
    var fac201: f32 = f32(0i);
    var fac210: f32 = f32(0i);
    var fac211: f32 = f32(0i);
    var fk0: f32 = f32(0i);
    var fk1: f32 = f32(0i);
    var fk2: f32 = f32(0i);
    var fmn2o: f32 = f32(0i);
    var fmn2omf: f32 = f32(0i);
    var fpl: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var fs1: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var indm: i32 = 0i;
    var inds: i32 = 0i;
    var jmn2o: i32 = 0i;
    var jpl: i32 = 0i;
    var js: i32 = 0i;
    var js1: i32 = 0i;
    var lay: i32 = 0i;
    var n2om1: f32 = f32(0i);
    var n2om2: f32 = f32(0i);
    var p: f32 = f32(0i);
    var p4: f32 = f32(0i);
    var ratn2o: f32 = f32(0i);
    var refrat_m_a: f32 = f32(0i);
    var refrat_m_b: f32 = f32(0i);
    var refrat_planck_a: f32 = f32(0i);
    var refrat_planck_b: f32 = f32(0i);
    var speccomb: f32 = f32(0i);
    var speccomb1: f32 = f32(0i);
    var speccomb_mn2o: f32 = f32(0i);
    var speccomb_planck: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specmult1: f32 = f32(0i);
    var specmult_mn2o: f32 = f32(0i);
    var specmult_planck: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var specparm1: f32 = f32(0i);
    var specparm_mn2o: f32 = f32(0i);
    var specparm_planck: f32 = f32(0i);
    var tau_major: f32 = f32(0i);
    var tau_major1: f32 = f32(0i);
    var taufor: f32 = f32(0i);
    var tauself: f32 = f32(0i);
    var r0: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((9i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * ((9i) - 1i))))))));
    refrat_planck_a = r0;
    var r1: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((13i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * ((13i) - 1i))))))));
    refrat_planck_b = r1;
    var r2: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((3i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * ((3i) - 1i))))))));
    refrat_m_a = r2;
    var r3: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((13i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * ((13i) - 1i))))))));
    refrat_m_b = r3;
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                var r5: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_h2oco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb = r5;
                var r6: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r5);
                specparm = r6;
                if ((r6 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r7: f32 = opq((opq(8.0f)) * (opq(specparm)));
                specmult = r7;
                js = (1i + (i32(r7)));
                var r8: f32 = opq((r7 % 1.0f));
                fs = r8;
                var r10: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_h2oco2_1 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb1 = r10;
                var r11: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r10);
                specparm1 = r11;
                if ((r11 >= K_RR_ONEMINUS)) {
                    specparm1 = K_RR_ONEMINUS;
                }
                var r12: f32 = opq((opq(8.0f)) * (opq(specparm1)));
                specmult1 = r12;
                js1 = (1i + (i32(r12)));
                var r13: f32 = opq((r12 % 1.0f));
                fs1 = r13;
                var r15: f32 = opq(fma(opq(refrat_m_a), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb_mn2o = r15;
                var r16: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r15);
                specparm_mn2o = r16;
                if ((r16 >= K_RR_ONEMINUS)) {
                    specparm_mn2o = K_RR_ONEMINUS;
                }
                var r17: f32 = opq((opq(8.0f)) * (opq(specparm_mn2o)));
                specmult_mn2o = r17;
                jmn2o = (1i + (i32(r17)));
                var r18: f32 = opq((r17 % 1.0f));
                fmn2o = r18;
                var r19: f32 = opq((bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i)))))) * (opq(r18)));
                fmn2omf = r19;
                var r20: f32 = div_cr(bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i))))));
                chi_n2o = r20;
                var r21: f32 = opq((opq(1e+20f)) * (opq(r20)));
                var r22: f32 = div_cr(r21, bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((4i) - 1i)) + (7i * (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) + 1i) - 1i))))))));
                ratn2o = r22;
                if ((r22 > 1.5f)) {
                    var r23: f32 = opq((opq(ratn2o)) - (opq(0.5f)));
                    var r24: f32 = f_rr_pow_cr(r23, 0.65f);
                    var r25: f32 = opq((opq(0.5f)) + (opq(r24)));
                    adjfac = r25;
                    var r26: f32 = opq((opq(r25)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((4i) - 1i)) + (7i * (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) + 1i) - 1i)))))))));
                    var r27: f32 = opq((opq(r26)) * (bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i)))))));
                    var r28: f32 = opq((opq(r27)) * (opq(1e-20f)));
                    adjcoln2o = r28;
                } else {
                    adjcoln2o = bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i)))));
                }
                var r30: f32 = opq(fma(opq(refrat_planck_a), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb_planck = r30;
                var r31: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r30);
                specparm_planck = r31;
                if ((r31 >= K_RR_ONEMINUS)) {
                    specparm_planck = K_RR_ONEMINUS;
                }
                var r32: f32 = opq((opq(8.0f)) * (opq(specparm_planck)));
                specmult_planck = r32;
                jpl = (1i + (i32(r32)));
                var r33: f32 = opq((r32 % 1.0f));
                fpl = r33;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((3i) - 1i)])) + js);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((3i) - 1i)])) + js1);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                indm = bitcast<i32>(mem_ld(((*C).indminor + bitcast<u32>((lay - 1i)))));
                if ((specparm < 0.125f)) {
                    var r34: f32 = opq((opq(fs)) - (opq(f32(1i))));
                    p = r34;
                    var r35: f32 = opq((opq(r34)) * (opq(r34)));
                    var r36: f32 = opq((opq(r35)) * (opq(r35)));
                    p4 = r36;
                    fk0 = r36;
                    var r37: f32 = opq((opq(f32(1i))) - (opq(r34)));
                    var r39: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r36), opq(r37)));
                    fk1 = r39;
                    var r40: f32 = opq((opq(r34)) + (opq(r36)));
                    fk2 = r40;
                    var r41: f32 = opq((opq(r36)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac000 = r41;
                    var r42: f32 = opq((opq(r39)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac100 = r42;
                    var r43: f32 = opq((opq(r40)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac200 = r43;
                    var r44: f32 = opq((opq(r36)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac010 = r44;
                    var r45: f32 = opq((opq(r39)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac110 = r45;
                    var r46: f32 = opq((opq(r40)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac210 = r46;
                } else {
                    if ((specparm > 0.875f)) {
                        var r47: f32 = f_rr_neg(fs, (*C).z0);
                        p = r47;
                        var r48: f32 = opq((opq(r47)) * (opq(r47)));
                        var r49: f32 = opq((opq(r48)) * (opq(r48)));
                        p4 = r49;
                        fk0 = r49;
                        var r50: f32 = opq((opq(f32(1i))) - (opq(r47)));
                        var r52: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r49), opq(r50)));
                        fk1 = r52;
                        var r53: f32 = opq((opq(r47)) + (opq(r49)));
                        fk2 = r53;
                        var r54: f32 = opq((opq(r49)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac000 = r54;
                        var r55: f32 = opq((opq(r52)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac100 = r55;
                        var r56: f32 = opq((opq(r53)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac200 = r56;
                        var r57: f32 = opq((opq(r49)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac010 = r57;
                        var r58: f32 = opq((opq(r52)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac110 = r58;
                        var r59: f32 = opq((opq(r53)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac210 = r59;
                    } else {
                        var r60: f32 = opq((opq(1.0f)) - (opq(fs)));
                        var r61: f32 = opq((opq(r60)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac000 = r61;
                        var r62: f32 = opq((opq(1.0f)) - (opq(fs)));
                        var r63: f32 = opq((opq(r62)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac010 = r63;
                        var r64: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac100 = r64;
                        var r65: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac110 = r65;
                    }
                }
                if ((specparm1 < 0.125f)) {
                    var r66: f32 = opq((opq(fs1)) - (opq(f32(1i))));
                    p = r66;
                    var r67: f32 = opq((opq(r66)) * (opq(r66)));
                    var r68: f32 = opq((opq(r67)) * (opq(r67)));
                    p4 = r68;
                    fk0 = r68;
                    var r69: f32 = opq((opq(f32(1i))) - (opq(r66)));
                    var r71: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r68), opq(r69)));
                    fk1 = r71;
                    var r72: f32 = opq((opq(r66)) + (opq(r68)));
                    fk2 = r72;
                    var r73: f32 = opq((opq(r68)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac001 = r73;
                    var r74: f32 = opq((opq(r71)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac101 = r74;
                    var r75: f32 = opq((opq(r72)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac201 = r75;
                    var r76: f32 = opq((opq(r68)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac011 = r76;
                    var r77: f32 = opq((opq(r71)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac111 = r77;
                    var r78: f32 = opq((opq(r72)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac211 = r78;
                } else {
                    if ((specparm1 > 0.875f)) {
                        var r79: f32 = f_rr_neg(fs1, (*C).z0);
                        p = r79;
                        var r80: f32 = opq((opq(r79)) * (opq(r79)));
                        var r81: f32 = opq((opq(r80)) * (opq(r80)));
                        p4 = r81;
                        fk0 = r81;
                        var r82: f32 = opq((opq(f32(1i))) - (opq(r79)));
                        var r84: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r81), opq(r82)));
                        fk1 = r84;
                        var r85: f32 = opq((opq(r79)) + (opq(r81)));
                        fk2 = r85;
                        var r86: f32 = opq((opq(r81)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac001 = r86;
                        var r87: f32 = opq((opq(r84)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac101 = r87;
                        var r88: f32 = opq((opq(r85)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac201 = r88;
                        var r89: f32 = opq((opq(r81)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac011 = r89;
                        var r90: f32 = opq((opq(r84)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac111 = r90;
                        var r91: f32 = opq((opq(r85)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac211 = r91;
                    } else {
                        var r92: f32 = opq((opq(1.0f)) - (opq(fs1)));
                        var r93: f32 = opq((opq(r92)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac001 = r93;
                        var r94: f32 = opq((opq(1.0f)) - (opq(fs1)));
                        var r95: f32 = opq((opq(r94)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac011 = r95;
                        var r96: f32 = opq((opq(fs1)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac101 = r96;
                        var r97: f32 = opq((opq(fs1)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac111 = r97;
                    }
                }
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 16i))) { break; }
                            var r98: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((40385i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((40385i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r100: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r98), bitcast<f32>(mem_ld((T + bitcast<u32>(((40385i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r101: f32 = opq((bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i)))))) * (opq(r100)));
                            tauself = r101;
                            var r102: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((40545i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((40545i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r104: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r102), bitcast<f32>(mem_ld((T + bitcast<u32>(((40545i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r105: f32 = opq((bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i)))))) * (opq(r104)));
                            taufor = r105;
                            var r106: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>((((36129i + ((jmn2o + 1i) - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>((((36129i + (jmn2o - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            var r108: f32 = opq(fma(opq(fmn2o), opq(r106), bitcast<f32>(mem_ld((T + bitcast<u32>((((36129i + (jmn2o - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            n2om1 = r108;
                            var r109: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>((((36129i + ((jmn2o + 1i) - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>((((36129i + (jmn2o - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            var r111: f32 = opq(fma(opq(fmn2o), opq(r109), bitcast<f32>(mem_ld((T + bitcast<u32>((((36129i + (jmn2o - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            n2om2 = r111;
                            var r112: f32 = opq((opq(r111)) - (opq(r108)));
                            var r114: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r112), opq(r108)));
                            absn2o = r114;
                            if ((specparm < 0.125f)) {
                                var r116: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                var r117: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r116)));
                                var r119: f32 = opq(fma(opq(fac200), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind0 + 2i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r117)));
                                var r121: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r119)));
                                var r123: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r121)));
                                var r125: f32 = opq(fma(opq(fac210), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind0 + 11i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r123)));
                                var r126: f32 = opq((opq(speccomb)) * (opq(r125)));
                                tau_major = r126;
                            } else {
                                if ((specparm > 0.875f)) {
                                    var r128: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + (ind0 - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r129: f32 = opq(fma(opq(fac200), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind0 - 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r128)));
                                    var r131: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r129)));
                                    var r133: f32 = opq(fma(opq(fac210), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind0 + 8i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r131)));
                                    var r135: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r133)));
                                    var r137: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r135)));
                                    var r138: f32 = opq((opq(speccomb)) * (opq(r137)));
                                    tau_major = r138;
                                } else {
                                    var r140: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r141: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r140)));
                                    var r143: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r141)));
                                    var r145: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r143)));
                                    var r146: f32 = opq((opq(speccomb)) * (opq(r145)));
                                    tau_major = r146;
                                }
                            }
                            if ((specparm1 < 0.125f)) {
                                var r148: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                var r149: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r148)));
                                var r151: f32 = opq(fma(opq(fac201), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind1 + 2i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r149)));
                                var r153: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r151)));
                                var r155: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r153)));
                                var r157: f32 = opq(fma(opq(fac211), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind1 + 11i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r155)));
                                var r158: f32 = opq((opq(speccomb1)) * (opq(r157)));
                                tau_major1 = r158;
                            } else {
                                if ((specparm1 > 0.875f)) {
                                    var r160: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + (ind1 - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r161: f32 = opq(fma(opq(fac201), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind1 - 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r160)));
                                    var r163: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r161)));
                                    var r165: f32 = opq(fma(opq(fac211), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind1 + 8i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r163)));
                                    var r167: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r165)));
                                    var r169: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r167)));
                                    var r170: f32 = opq((opq(speccomb1)) * (opq(r169)));
                                    tau_major1 = r170;
                                } else {
                                    var r172: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r173: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r172)));
                                    var r175: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r173)));
                                    var r177: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((7969i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r175)));
                                    var r178: f32 = opq((opq(speccomb1)) * (opq(r177)));
                                    tau_major1 = r178;
                                }
                            }
                            var r179: f32 = opq((opq(tau_major)) + (opq(tau_major1)));
                            var r180: f32 = opq((opq(r179)) + (opq(tauself)));
                            var r181: f32 = opq((opq(r180)) + (opq(taufor)));
                            var r183: f32 = opq(fma(opq(adjcoln2o), opq(absn2o), opq(r181)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((22i + ig) - 22i) - 1i)))), bitcast<u32>(r183));
                            var r184: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((7745i + (ig - 1i)) + (((jpl + 1i) - 1i) * 16i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((7745i + (ig - 1i)) + ((jpl - 1i) * 16i))))))));
                            var r186: f32 = opq(fma(opq(fpl), opq(r184), bitcast<f32>(mem_ld((T + bitcast<u32>(((7745i + (ig - 1i)) + ((jpl - 1i) * 16i))))))));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((22i + ig) - 22i) - 1i)))), bitcast<u32>(r186));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                var r188: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_h2oco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb = r188;
                var r189: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r188);
                specparm = r189;
                if ((r189 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r190: f32 = opq((opq(4.0f)) * (opq(specparm)));
                specmult = r190;
                js = (1i + (i32(r190)));
                var r191: f32 = opq((r190 % 1.0f));
                fs = r191;
                var r193: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_h2oco2_1 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb1 = r193;
                var r194: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r193);
                specparm1 = r194;
                if ((r194 >= K_RR_ONEMINUS)) {
                    specparm1 = K_RR_ONEMINUS;
                }
                var r195: f32 = opq((opq(4.0f)) * (opq(specparm1)));
                specmult1 = r195;
                js1 = (1i + (i32(r195)));
                var r196: f32 = opq((r195 % 1.0f));
                fs1 = r196;
                var r197: f32 = opq((opq(1.0f)) - (opq(fs)));
                var r198: f32 = opq((opq(r197)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac000 = r198;
                var r199: f32 = opq((opq(1.0f)) - (opq(fs)));
                var r200: f32 = opq((opq(r199)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac010 = r200;
                var r201: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac100 = r201;
                var r202: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac110 = r202;
                var r203: f32 = opq((opq(1.0f)) - (opq(r196)));
                var r204: f32 = opq((opq(r203)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac001 = r204;
                var r205: f32 = opq((opq(1.0f)) - (opq(r196)));
                var r206: f32 = opq((opq(r205)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac011 = r206;
                var r207: f32 = opq((opq(r196)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac101 = r207;
                var r208: f32 = opq((opq(r196)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac111 = r208;
                var r210: f32 = opq(fma(opq(refrat_m_b), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb_mn2o = r210;
                var r211: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r210);
                specparm_mn2o = r211;
                if ((r211 >= K_RR_ONEMINUS)) {
                    specparm_mn2o = K_RR_ONEMINUS;
                }
                var r212: f32 = opq((opq(4.0f)) * (opq(specparm_mn2o)));
                specmult_mn2o = r212;
                jmn2o = (1i + (i32(r212)));
                var r213: f32 = opq((r212 % 1.0f));
                fmn2o = r213;
                var r214: f32 = opq((bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i)))))) * (opq(r213)));
                fmn2omf = r214;
                var r215: f32 = div_cr(bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i))))));
                chi_n2o = r215;
                var r216: f32 = opq((opq(1e+20f)) * (opq(r215)));
                var r217: f32 = div_cr(r216, bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((4i) - 1i)) + (7i * (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) + 1i) - 1i))))))));
                ratn2o = r217;
                if ((r217 > 1.5f)) {
                    var r218: f32 = opq((opq(ratn2o)) - (opq(0.5f)));
                    var r219: f32 = f_rr_pow_cr(r218, 0.65f);
                    var r220: f32 = opq((opq(0.5f)) + (opq(r219)));
                    adjfac = r220;
                    var r221: f32 = opq((opq(r220)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((4i) - 1i)) + (7i * (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) + 1i) - 1i)))))))));
                    var r222: f32 = opq((opq(r221)) * (bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i)))))));
                    var r223: f32 = opq((opq(r222)) * (opq(1e-20f)));
                    adjcoln2o = r223;
                } else {
                    adjcoln2o = bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i)))));
                }
                var r225: f32 = opq(fma(opq(refrat_planck_b), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb_planck = r225;
                var r226: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r225);
                specparm_planck = r226;
                if ((r226 >= K_RR_ONEMINUS)) {
                    specparm_planck = K_RR_ONEMINUS;
                }
                var r227: f32 = opq((opq(4.0f)) * (opq(specparm_planck)));
                specmult_planck = r227;
                jpl = (1i + (i32(r227)));
                var r228: f32 = opq((r227 % 1.0f));
                fpl = r228;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((3i) - 1i)])) + js);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((3i) - 1i)])) + js1);
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                indm = bitcast<i32>(mem_ld(((*C).indminor + bitcast<u32>((lay - 1i)))));
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 16i))) { break; }
                            var r229: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((40545i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((40545i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r231: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r229), bitcast<f32>(mem_ld((T + bitcast<u32>(((40545i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r233: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>((((38865i + ((jmn2o + 1i) - 1i)) + ((indm - 1i) * 5i)) + ((ig - 1i) * 95i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>((((38865i + (jmn2o - 1i)) + ((indm - 1i) * 5i)) + ((ig - 1i) * 95i))))))));
                            var r235: f32 = opq(fma(opq(fmn2o), opq(r233), bitcast<f32>(mem_ld((T + bitcast<u32>((((38865i + (jmn2o - 1i)) + ((indm - 1i) * 5i)) + ((ig - 1i) * 95i))))))));
                            n2om1 = r235;
                            var r236: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>((((38865i + ((jmn2o + 1i) - 1i)) + (((indm + 1i) - 1i) * 5i)) + ((ig - 1i) * 95i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>((((38865i + (jmn2o - 1i)) + (((indm + 1i) - 1i) * 5i)) + ((ig - 1i) * 95i))))))));
                            var r238: f32 = opq(fma(opq(fmn2o), opq(r236), bitcast<f32>(mem_ld((T + bitcast<u32>((((38865i + (jmn2o - 1i)) + (((indm + 1i) - 1i) * 5i)) + ((ig - 1i) * 95i))))))));
                            n2om2 = r238;
                            var r239: f32 = opq((opq(r238)) - (opq(r235)));
                            var r241: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r239), opq(r235)));
                            absn2o = r241;
                            var r243: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((17329i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 1175i))))))));
                            var r244: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((17329i + (ind0 - 1i)) + ((ig - 1i) * 1175i)))))), opq(r243)));
                            var r246: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((17329i + ((ind0 + 5i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r244)));
                            var r248: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((17329i + ((ind0 + 6i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r246)));
                            var r251: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((17329i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 1175i))))))));
                            var r252: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((17329i + (ind1 - 1i)) + ((ig - 1i) * 1175i)))))), opq(r251)));
                            var r254: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((17329i + ((ind1 + 5i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r252)));
                            var r256: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((17329i + ((ind1 + 6i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r254)));
                            var r257: f32 = opq((opq(speccomb1)) * (opq(r256)));
                            var r258: f32 = opq(fma(opq(speccomb), opq(r248), opq(r257)));
                            var r259: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i))))), opq(r231), opq(r258)));
                            var r261: f32 = opq(fma(opq(adjcoln2o), opq(r241), opq(r259)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((22i + ig) - 22i) - 1i)))), bitcast<u32>(r261));
                            var r262: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((7889i + (ig - 1i)) + (((jpl + 1i) - 1i) * 16i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((7889i + (ig - 1i)) + ((jpl - 1i) * 16i))))))));
                            var r264: f32 = opq(fma(opq(fpl), opq(r262), bitcast<f32>(mem_ld((T + bitcast<u32>(((7889i + (ig - 1i)) + ((jpl - 1i) * 16i))))))));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((22i + ig) - 22i) - 1i)))), bitcast<u32>(r264));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rr_pow_cr(x_in: f32, p_in: f32) -> f32 {
    var x: f32 = x_in;
    var p: f32 = p_in;
    if (((!(x > 0.0f)) || ((bitcast<u32>(x) & 0x7fffffffu) == 0x7f800000u))) {
        return opq(pow(x, p));
    }
    var L: vec2<f32> = f_rr_log_ff(x);
    var yh: f32 = opq((opq(L.x)) * (opq(p)));
    return f_rr_exp_ff(f_rr_quick_two_sum(yh, opq(fma(opq(L.y), opq(p), opq(fma(opq(L.x), opq(p), opq((-(opq(yh))))))))));
}

fn f_rrlw_taugb4(C: ptr<function, S_RRLWColumn>, T_in: u32, taugL_in: u32, fracsL_in: u32) {
    var T: u32 = T_in;
    var taugL: u32 = taugL_in;
    var fracsL: u32 = fracsL_in;
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fac200: f32 = f32(0i);
    var fac201: f32 = f32(0i);
    var fac210: f32 = f32(0i);
    var fac211: f32 = f32(0i);
    var fk0: f32 = f32(0i);
    var fk1: f32 = f32(0i);
    var fk2: f32 = f32(0i);
    var fpl: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var fs1: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var jpl: i32 = 0i;
    var js: i32 = 0i;
    var js1: i32 = 0i;
    var lay: i32 = 0i;
    var p: f32 = f32(0i);
    var p4: f32 = f32(0i);
    var refrat_planck_a: f32 = f32(0i);
    var refrat_planck_b: f32 = f32(0i);
    var speccomb: f32 = f32(0i);
    var speccomb1: f32 = f32(0i);
    var speccomb_planck: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specmult1: f32 = f32(0i);
    var specmult_planck: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var specparm1: f32 = f32(0i);
    var specparm_planck: f32 = f32(0i);
    var tau_major: f32 = f32(0i);
    var tau_major1: f32 = f32(0i);
    var taufor: f32 = f32(0i);
    var tauself: f32 = f32(0i);
    var r0: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((11i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * ((11i) - 1i))))))));
    refrat_planck_a = r0;
    var r1: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((3i) - 1i)) + (7i * ((13i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * ((13i) - 1i))))))));
    refrat_planck_b = r1;
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                var r3: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_h2oco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb = r3;
                var r4: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r3);
                specparm = r4;
                if ((r4 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r5: f32 = opq((opq(8.0f)) * (opq(specparm)));
                specmult = r5;
                js = (1i + (i32(r5)));
                var r6: f32 = opq((r5 % 1.0f));
                fs = r6;
                var r8: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_h2oco2_1 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb1 = r8;
                var r9: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r8);
                specparm1 = r9;
                if ((r9 >= K_RR_ONEMINUS)) {
                    specparm1 = K_RR_ONEMINUS;
                }
                var r10: f32 = opq((opq(8.0f)) * (opq(specparm1)));
                specmult1 = r10;
                js1 = (1i + (i32(r10)));
                var r11: f32 = opq((r10 % 1.0f));
                fs1 = r11;
                var r13: f32 = opq(fma(opq(refrat_planck_a), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb_planck = r13;
                var r14: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r13);
                specparm_planck = r14;
                if ((r14 >= K_RR_ONEMINUS)) {
                    specparm_planck = K_RR_ONEMINUS;
                }
                var r15: f32 = opq((opq(8.0f)) * (opq(specparm_planck)));
                specmult_planck = r15;
                jpl = (1i + (i32(r15)));
                var r16: f32 = opq((r15 % 1.0f));
                fpl = r16;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((4i) - 1i)])) + js);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((4i) - 1i)])) + js1);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                if ((specparm < 0.125f)) {
                    var r17: f32 = opq((opq(fs)) - (opq(f32(1i))));
                    p = r17;
                    var r18: f32 = opq((opq(r17)) * (opq(r17)));
                    var r19: f32 = opq((opq(r18)) * (opq(r18)));
                    p4 = r19;
                    fk0 = r19;
                    var r20: f32 = opq((opq(f32(1i))) - (opq(r17)));
                    var r22: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r19), opq(r20)));
                    fk1 = r22;
                    var r23: f32 = opq((opq(r17)) + (opq(r19)));
                    fk2 = r23;
                    var r24: f32 = opq((opq(r19)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac000 = r24;
                    var r25: f32 = opq((opq(r22)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac100 = r25;
                    var r26: f32 = opq((opq(r23)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac200 = r26;
                    var r27: f32 = opq((opq(r19)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac010 = r27;
                    var r28: f32 = opq((opq(r22)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac110 = r28;
                    var r29: f32 = opq((opq(r23)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac210 = r29;
                } else {
                    if ((specparm > 0.875f)) {
                        var r30: f32 = f_rr_neg(fs, (*C).z0);
                        p = r30;
                        var r31: f32 = opq((opq(r30)) * (opq(r30)));
                        var r32: f32 = opq((opq(r31)) * (opq(r31)));
                        p4 = r32;
                        fk0 = r32;
                        var r33: f32 = opq((opq(f32(1i))) - (opq(r30)));
                        var r35: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r32), opq(r33)));
                        fk1 = r35;
                        var r36: f32 = opq((opq(r30)) + (opq(r32)));
                        fk2 = r36;
                        var r37: f32 = opq((opq(r32)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac000 = r37;
                        var r38: f32 = opq((opq(r35)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac100 = r38;
                        var r39: f32 = opq((opq(r36)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac200 = r39;
                        var r40: f32 = opq((opq(r32)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac010 = r40;
                        var r41: f32 = opq((opq(r35)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac110 = r41;
                        var r42: f32 = opq((opq(r36)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac210 = r42;
                    } else {
                        var r43: f32 = opq((opq(1.0f)) - (opq(fs)));
                        var r44: f32 = opq((opq(r43)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac000 = r44;
                        var r45: f32 = opq((opq(1.0f)) - (opq(fs)));
                        var r46: f32 = opq((opq(r45)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac010 = r46;
                        var r47: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac100 = r47;
                        var r48: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac110 = r48;
                    }
                }
                if ((specparm1 < 0.125f)) {
                    var r49: f32 = opq((opq(fs1)) - (opq(f32(1i))));
                    p = r49;
                    var r50: f32 = opq((opq(r49)) * (opq(r49)));
                    var r51: f32 = opq((opq(r50)) * (opq(r50)));
                    p4 = r51;
                    fk0 = r51;
                    var r52: f32 = opq((opq(f32(1i))) - (opq(r49)));
                    var r54: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r51), opq(r52)));
                    fk1 = r54;
                    var r55: f32 = opq((opq(r49)) + (opq(r51)));
                    fk2 = r55;
                    var r56: f32 = opq((opq(r51)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac001 = r56;
                    var r57: f32 = opq((opq(r54)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac101 = r57;
                    var r58: f32 = opq((opq(r55)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac201 = r58;
                    var r59: f32 = opq((opq(r51)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac011 = r59;
                    var r60: f32 = opq((opq(r54)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac111 = r60;
                    var r61: f32 = opq((opq(r55)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac211 = r61;
                } else {
                    if ((specparm1 > 0.875f)) {
                        var r62: f32 = f_rr_neg(fs1, (*C).z0);
                        p = r62;
                        var r63: f32 = opq((opq(r62)) * (opq(r62)));
                        var r64: f32 = opq((opq(r63)) * (opq(r63)));
                        p4 = r64;
                        fk0 = r64;
                        var r65: f32 = opq((opq(f32(1i))) - (opq(r62)));
                        var r67: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r64), opq(r65)));
                        fk1 = r67;
                        var r68: f32 = opq((opq(r62)) + (opq(r64)));
                        fk2 = r68;
                        var r69: f32 = opq((opq(r64)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac001 = r69;
                        var r70: f32 = opq((opq(r67)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac101 = r70;
                        var r71: f32 = opq((opq(r68)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac201 = r71;
                        var r72: f32 = opq((opq(r64)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac011 = r72;
                        var r73: f32 = opq((opq(r67)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac111 = r73;
                        var r74: f32 = opq((opq(r68)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac211 = r74;
                    } else {
                        var r75: f32 = opq((opq(1.0f)) - (opq(fs1)));
                        var r76: f32 = opq((opq(r75)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac001 = r76;
                        var r77: f32 = opq((opq(1.0f)) - (opq(fs1)));
                        var r78: f32 = opq((opq(r77)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac011 = r78;
                        var r79: f32 = opq((opq(fs1)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac101 = r79;
                        var r80: f32 = opq((opq(fs1)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac111 = r80;
                    }
                }
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 14i))) { break; }
                            var r81: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((65445i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((65445i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r83: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r81), bitcast<f32>(mem_ld((T + bitcast<u32>(((65445i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r84: f32 = opq((bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i)))))) * (opq(r83)));
                            tauself = r84;
                            var r85: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((65585i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((65585i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r87: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r85), bitcast<f32>(mem_ld((T + bitcast<u32>(((65585i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r88: f32 = opq((bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i)))))) * (opq(r87)));
                            taufor = r88;
                            if ((specparm < 0.125f)) {
                                var r90: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                var r91: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r90)));
                                var r93: f32 = opq(fma(opq(fac200), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind0 + 2i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r91)));
                                var r95: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r93)));
                                var r97: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r95)));
                                var r99: f32 = opq(fma(opq(fac210), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind0 + 11i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r97)));
                                var r100: f32 = opq((opq(speccomb)) * (opq(r99)));
                                tau_major = r100;
                            } else {
                                if ((specparm > 0.875f)) {
                                    var r102: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + (ind0 - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r103: f32 = opq(fma(opq(fac200), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind0 - 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r102)));
                                    var r105: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r103)));
                                    var r107: f32 = opq(fma(opq(fac210), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind0 + 8i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r105)));
                                    var r109: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r107)));
                                    var r111: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r109)));
                                    var r112: f32 = opq((opq(speccomb)) * (opq(r111)));
                                    tau_major = r112;
                                } else {
                                    var r114: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r115: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r114)));
                                    var r117: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r115)));
                                    var r119: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r117)));
                                    var r120: f32 = opq((opq(speccomb)) * (opq(r119)));
                                    tau_major = r120;
                                }
                            }
                            if ((specparm1 < 0.125f)) {
                                var r122: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                var r123: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r122)));
                                var r125: f32 = opq(fma(opq(fac201), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind1 + 2i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r123)));
                                var r127: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r125)));
                                var r129: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r127)));
                                var r131: f32 = opq(fma(opq(fac211), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind1 + 11i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r129)));
                                var r132: f32 = opq((opq(speccomb1)) * (opq(r131)));
                                tau_major1 = r132;
                            } else {
                                if ((specparm1 > 0.875f)) {
                                    var r134: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + (ind1 - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r135: f32 = opq(fma(opq(fac201), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind1 - 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r134)));
                                    var r137: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r135)));
                                    var r139: f32 = opq(fma(opq(fac211), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind1 + 8i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r137)));
                                    var r141: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r139)));
                                    var r143: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r141)));
                                    var r144: f32 = opq((opq(speccomb1)) * (opq(r143)));
                                    tau_major1 = r144;
                                } else {
                                    var r146: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r147: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r146)));
                                    var r149: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r147)));
                                    var r151: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((40805i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r149)));
                                    var r152: f32 = opq((opq(speccomb1)) * (opq(r151)));
                                    tau_major1 = r152;
                                }
                            }
                            var r153: f32 = opq((opq(tau_major)) + (opq(tau_major1)));
                            var r154: f32 = opq((opq(r153)) + (opq(tauself)));
                            var r155: f32 = opq((opq(r154)) + (opq(taufor)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((38i + ig) - 38i) - 1i)))), bitcast<u32>(r155));
                            var r156: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((40609i + (ig - 1i)) + (((jpl + 1i) - 1i) * 14i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((40609i + (ig - 1i)) + ((jpl - 1i) * 14i))))))));
                            var r158: f32 = opq(fma(opq(fpl), opq(r156), bitcast<f32>(mem_ld((T + bitcast<u32>(((40609i + (ig - 1i)) + ((jpl - 1i) * 14i))))))));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((38i + ig) - 38i) - 1i)))), bitcast<u32>(r158));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                var r160: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_o3co2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i)))))));
                speccomb = r160;
                var r161: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i))))), r160);
                specparm = r161;
                if ((r161 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r162: f32 = opq((opq(4.0f)) * (opq(specparm)));
                specmult = r162;
                js = (1i + (i32(r162)));
                var r163: f32 = opq((r162 % 1.0f));
                fs = r163;
                var r165: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_o3co2_1 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i)))))));
                speccomb1 = r165;
                var r166: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i))))), r165);
                specparm1 = r166;
                if ((r166 >= K_RR_ONEMINUS)) {
                    specparm1 = K_RR_ONEMINUS;
                }
                var r167: f32 = opq((opq(4.0f)) * (opq(specparm1)));
                specmult1 = r167;
                js1 = (1i + (i32(r167)));
                var r168: f32 = opq((r167 % 1.0f));
                fs1 = r168;
                var r169: f32 = opq((opq(1.0f)) - (opq(fs)));
                var r170: f32 = opq((opq(r169)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac000 = r170;
                var r171: f32 = opq((opq(1.0f)) - (opq(fs)));
                var r172: f32 = opq((opq(r171)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac010 = r172;
                var r173: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac100 = r173;
                var r174: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac110 = r174;
                var r175: f32 = opq((opq(1.0f)) - (opq(r168)));
                var r176: f32 = opq((opq(r175)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac001 = r176;
                var r177: f32 = opq((opq(1.0f)) - (opq(r168)));
                var r178: f32 = opq((opq(r177)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac011 = r178;
                var r179: f32 = opq((opq(r168)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac101 = r179;
                var r180: f32 = opq((opq(r168)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac111 = r180;
                var r182: f32 = opq(fma(opq(refrat_planck_b), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i)))))));
                speccomb_planck = r182;
                var r183: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i))))), r182);
                specparm_planck = r183;
                if ((r183 >= K_RR_ONEMINUS)) {
                    specparm_planck = K_RR_ONEMINUS;
                }
                var r184: f32 = opq((opq(4.0f)) * (opq(specparm_planck)));
                specmult_planck = r184;
                jpl = (1i + (i32(r184)));
                var r185: f32 = opq((r184 % 1.0f));
                fpl = r185;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((4i) - 1i)])) + js);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((4i) - 1i)])) + js1);
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 14i))) { break; }
                            var r187: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((48995i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 1175i))))))));
                            var r188: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((48995i + (ind0 - 1i)) + ((ig - 1i) * 1175i)))))), opq(r187)));
                            var r190: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((48995i + ((ind0 + 5i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r188)));
                            var r192: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((48995i + ((ind0 + 6i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r190)));
                            var r195: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((48995i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 1175i))))))));
                            var r196: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((48995i + (ind1 - 1i)) + ((ig - 1i) * 1175i)))))), opq(r195)));
                            var r198: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((48995i + ((ind1 + 5i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r196)));
                            var r200: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((48995i + ((ind1 + 6i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r198)));
                            var r201: f32 = opq((opq(speccomb1)) * (opq(r200)));
                            var r202: f32 = opq(fma(opq(speccomb), opq(r192), opq(r201)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((38i + ig) - 38i) - 1i)))), bitcast<u32>(r202));
                            var r203: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((40735i + (ig - 1i)) + (((jpl + 1i) - 1i) * 14i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((40735i + (ig - 1i)) + ((jpl - 1i) * 14i))))))));
                            var r205: f32 = opq(fma(opq(fpl), opq(r203), bitcast<f32>(mem_ld((T + bitcast<u32>(((40735i + (ig - 1i)) + ((jpl - 1i) * 14i))))))));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((38i + ig) - 38i) - 1i)))), bitcast<u32>(r205));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
                var r206: f32 = opq((bitcast<f32>(mem_ld((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((38i + 8i) - 38i) - 1i))))))) * (opq(0.92f)));
                mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((38i + 8i) - 38i) - 1i)))), bitcast<u32>(r206));
                var r207: f32 = opq((bitcast<f32>(mem_ld((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((38i + 9i) - 38i) - 1i))))))) * (opq(0.88f)));
                mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((38i + 9i) - 38i) - 1i)))), bitcast<u32>(r207));
                var r208: f32 = opq((bitcast<f32>(mem_ld((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((38i + 10i) - 38i) - 1i))))))) * (opq(1.07f)));
                mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((38i + 10i) - 38i) - 1i)))), bitcast<u32>(r208));
                var r209: f32 = opq((bitcast<f32>(mem_ld((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((38i + 11i) - 38i) - 1i))))))) * (opq(1.1f)));
                mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((38i + 11i) - 38i) - 1i)))), bitcast<u32>(r209));
                var r210: f32 = opq((bitcast<f32>(mem_ld((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((38i + 12i) - 38i) - 1i))))))) * (opq(0.99f)));
                mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((38i + 12i) - 38i) - 1i)))), bitcast<u32>(r210));
                var r211: f32 = opq((bitcast<f32>(mem_ld((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((38i + 13i) - 38i) - 1i))))))) * (opq(0.88f)));
                mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((38i + 13i) - 38i) - 1i)))), bitcast<u32>(r211));
                var r212: f32 = opq((bitcast<f32>(mem_ld((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((38i + 14i) - 38i) - 1i))))))) * (opq(0.943f)));
                mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((38i + 14i) - 38i) - 1i)))), bitcast<u32>(r212));
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrlw_taugb5(C: ptr<function, S_RRLWColumn>, T_in: u32, taugL_in: u32, fracsL_in: u32) {
    var T: u32 = T_in;
    var taugL: u32 = taugL_in;
    var fracsL: u32 = fracsL_in;
    var abso3: f32 = f32(0i);
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fac200: f32 = f32(0i);
    var fac201: f32 = f32(0i);
    var fac210: f32 = f32(0i);
    var fac211: f32 = f32(0i);
    var fk0: f32 = f32(0i);
    var fk1: f32 = f32(0i);
    var fk2: f32 = f32(0i);
    var fmo3: f32 = f32(0i);
    var fpl: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var fs1: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var indm: i32 = 0i;
    var inds: i32 = 0i;
    var jmo3: i32 = 0i;
    var jpl: i32 = 0i;
    var js: i32 = 0i;
    var js1: i32 = 0i;
    var lay: i32 = 0i;
    var o3m1: f32 = f32(0i);
    var o3m2: f32 = f32(0i);
    var p: f32 = f32(0i);
    var p4: f32 = f32(0i);
    var refrat_m_a: f32 = f32(0i);
    var refrat_planck_a: f32 = f32(0i);
    var refrat_planck_b: f32 = f32(0i);
    var speccomb: f32 = f32(0i);
    var speccomb1: f32 = f32(0i);
    var speccomb_mo3: f32 = f32(0i);
    var speccomb_planck: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specmult1: f32 = f32(0i);
    var specmult_mo3: f32 = f32(0i);
    var specmult_planck: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var specparm1: f32 = f32(0i);
    var specparm_mo3: f32 = f32(0i);
    var specparm_planck: f32 = f32(0i);
    var tau_major: f32 = f32(0i);
    var tau_major1: f32 = f32(0i);
    var taufor: f32 = f32(0i);
    var tauself: f32 = f32(0i);
    var r0: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((5i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * ((5i) - 1i))))))));
    refrat_planck_a = r0;
    var r1: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((3i) - 1i)) + (7i * ((43i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * ((43i) - 1i))))))));
    refrat_planck_b = r1;
    var r2: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((7i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * ((7i) - 1i))))))));
    refrat_m_a = r2;
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                var r4: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_h2oco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb = r4;
                var r5: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r4);
                specparm = r5;
                if ((r5 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r6: f32 = opq((opq(8.0f)) * (opq(specparm)));
                specmult = r6;
                js = (1i + (i32(r6)));
                var r7: f32 = opq((r6 % 1.0f));
                fs = r7;
                var r9: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_h2oco2_1 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb1 = r9;
                var r10: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r9);
                specparm1 = r10;
                if ((r10 >= K_RR_ONEMINUS)) {
                    specparm1 = K_RR_ONEMINUS;
                }
                var r11: f32 = opq((opq(8.0f)) * (opq(specparm1)));
                specmult1 = r11;
                js1 = (1i + (i32(r11)));
                var r12: f32 = opq((r11 % 1.0f));
                fs1 = r12;
                var r14: f32 = opq(fma(opq(refrat_m_a), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb_mo3 = r14;
                var r15: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r14);
                specparm_mo3 = r15;
                if ((r15 >= K_RR_ONEMINUS)) {
                    specparm_mo3 = K_RR_ONEMINUS;
                }
                var r16: f32 = opq((opq(8.0f)) * (opq(specparm_mo3)));
                specmult_mo3 = r16;
                jmo3 = (1i + (i32(r16)));
                var r17: f32 = opq((r16 % 1.0f));
                fmo3 = r17;
                var r19: f32 = opq(fma(opq(refrat_planck_a), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb_planck = r19;
                var r20: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r19);
                specparm_planck = r20;
                if ((r20 >= K_RR_ONEMINUS)) {
                    specparm_planck = K_RR_ONEMINUS;
                }
                var r21: f32 = opq((opq(8.0f)) * (opq(specparm_planck)));
                specmult_planck = r21;
                jpl = (1i + (i32(r21)));
                var r22: f32 = opq((r21 % 1.0f));
                fpl = r22;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((5i) - 1i)])) + js);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((5i) - 1i)])) + js1);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                indm = bitcast<i32>(mem_ld(((*C).indminor + bitcast<u32>((lay - 1i)))));
                if ((specparm < 0.125f)) {
                    var r23: f32 = opq((opq(fs)) - (opq(f32(1i))));
                    p = r23;
                    var r24: f32 = opq((opq(r23)) * (opq(r23)));
                    var r25: f32 = opq((opq(r24)) * (opq(r24)));
                    p4 = r25;
                    fk0 = r25;
                    var r26: f32 = opq((opq(f32(1i))) - (opq(r23)));
                    var r28: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r25), opq(r26)));
                    fk1 = r28;
                    var r29: f32 = opq((opq(r23)) + (opq(r25)));
                    fk2 = r29;
                    var r30: f32 = opq((opq(r25)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac000 = r30;
                    var r31: f32 = opq((opq(r28)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac100 = r31;
                    var r32: f32 = opq((opq(r29)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac200 = r32;
                    var r33: f32 = opq((opq(r25)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac010 = r33;
                    var r34: f32 = opq((opq(r28)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac110 = r34;
                    var r35: f32 = opq((opq(r29)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac210 = r35;
                } else {
                    if ((specparm > 0.875f)) {
                        var r36: f32 = f_rr_neg(fs, (*C).z0);
                        p = r36;
                        var r37: f32 = opq((opq(r36)) * (opq(r36)));
                        var r38: f32 = opq((opq(r37)) * (opq(r37)));
                        p4 = r38;
                        fk0 = r38;
                        var r39: f32 = opq((opq(f32(1i))) - (opq(r36)));
                        var r41: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r38), opq(r39)));
                        fk1 = r41;
                        var r42: f32 = opq((opq(r36)) + (opq(r38)));
                        fk2 = r42;
                        var r43: f32 = opq((opq(r38)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac000 = r43;
                        var r44: f32 = opq((opq(r41)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac100 = r44;
                        var r45: f32 = opq((opq(r42)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac200 = r45;
                        var r46: f32 = opq((opq(r38)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac010 = r46;
                        var r47: f32 = opq((opq(r41)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac110 = r47;
                        var r48: f32 = opq((opq(r42)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac210 = r48;
                    } else {
                        var r49: f32 = opq((opq(1.0f)) - (opq(fs)));
                        var r50: f32 = opq((opq(r49)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac000 = r50;
                        var r51: f32 = opq((opq(1.0f)) - (opq(fs)));
                        var r52: f32 = opq((opq(r51)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac010 = r52;
                        var r53: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac100 = r53;
                        var r54: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac110 = r54;
                    }
                }
                if ((specparm1 < 0.125f)) {
                    var r55: f32 = opq((opq(fs1)) - (opq(f32(1i))));
                    p = r55;
                    var r56: f32 = opq((opq(r55)) * (opq(r55)));
                    var r57: f32 = opq((opq(r56)) * (opq(r56)));
                    p4 = r57;
                    fk0 = r57;
                    var r58: f32 = opq((opq(f32(1i))) - (opq(r55)));
                    var r60: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r57), opq(r58)));
                    fk1 = r60;
                    var r61: f32 = opq((opq(r55)) + (opq(r57)));
                    fk2 = r61;
                    var r62: f32 = opq((opq(r57)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac001 = r62;
                    var r63: f32 = opq((opq(r60)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac101 = r63;
                    var r64: f32 = opq((opq(r61)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac201 = r64;
                    var r65: f32 = opq((opq(r57)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac011 = r65;
                    var r66: f32 = opq((opq(r60)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac111 = r66;
                    var r67: f32 = opq((opq(r61)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac211 = r67;
                } else {
                    if ((specparm1 > 0.875f)) {
                        var r68: f32 = f_rr_neg(fs1, (*C).z0);
                        p = r68;
                        var r69: f32 = opq((opq(r68)) * (opq(r68)));
                        var r70: f32 = opq((opq(r69)) * (opq(r69)));
                        p4 = r70;
                        fk0 = r70;
                        var r71: f32 = opq((opq(f32(1i))) - (opq(r68)));
                        var r73: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r70), opq(r71)));
                        fk1 = r73;
                        var r74: f32 = opq((opq(r68)) + (opq(r70)));
                        fk2 = r74;
                        var r75: f32 = opq((opq(r70)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac001 = r75;
                        var r76: f32 = opq((opq(r73)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac101 = r76;
                        var r77: f32 = opq((opq(r74)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac201 = r77;
                        var r78: f32 = opq((opq(r70)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac011 = r78;
                        var r79: f32 = opq((opq(r73)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac111 = r79;
                        var r80: f32 = opq((opq(r74)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac211 = r80;
                    } else {
                        var r81: f32 = opq((opq(1.0f)) - (opq(fs1)));
                        var r82: f32 = opq((opq(r81)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac001 = r82;
                        var r83: f32 = opq((opq(1.0f)) - (opq(fs1)));
                        var r84: f32 = opq((opq(r83)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac011 = r84;
                        var r85: f32 = opq((opq(fs1)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac101 = r85;
                        var r86: f32 = opq((opq(fs1)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac111 = r86;
                    }
                }
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 16i))) { break; }
                            var r87: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((96761i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((96761i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r89: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r87), bitcast<f32>(mem_ld((T + bitcast<u32>(((96761i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r90: f32 = opq((bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i)))))) * (opq(r89)));
                            tauself = r90;
                            var r91: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((96921i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((96921i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r93: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r91), bitcast<f32>(mem_ld((T + bitcast<u32>(((96921i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r94: f32 = opq((bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i)))))) * (opq(r93)));
                            taufor = r94;
                            var r95: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>((((94025i + ((jmo3 + 1i) - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>((((94025i + (jmo3 - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            var r97: f32 = opq(fma(opq(fmo3), opq(r95), bitcast<f32>(mem_ld((T + bitcast<u32>((((94025i + (jmo3 - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            o3m1 = r97;
                            var r98: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>((((94025i + ((jmo3 + 1i) - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>((((94025i + (jmo3 - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            var r100: f32 = opq(fma(opq(fmo3), opq(r98), bitcast<f32>(mem_ld((T + bitcast<u32>((((94025i + (jmo3 - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            o3m2 = r100;
                            var r101: f32 = opq((opq(r100)) - (opq(r97)));
                            var r103: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r101), opq(r97)));
                            abso3 = r103;
                            if ((specparm < 0.125f)) {
                                var r105: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                var r106: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r105)));
                                var r108: f32 = opq(fma(opq(fac200), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind0 + 2i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r106)));
                                var r110: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r108)));
                                var r112: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r110)));
                                var r114: f32 = opq(fma(opq(fac210), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind0 + 11i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r112)));
                                var r115: f32 = opq((opq(speccomb)) * (opq(r114)));
                                tau_major = r115;
                            } else {
                                if ((specparm > 0.875f)) {
                                    var r117: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + (ind0 - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r118: f32 = opq(fma(opq(fac200), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind0 - 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r117)));
                                    var r120: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r118)));
                                    var r122: f32 = opq(fma(opq(fac210), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind0 + 8i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r120)));
                                    var r124: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r122)));
                                    var r126: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r124)));
                                    var r127: f32 = opq((opq(speccomb)) * (opq(r126)));
                                    tau_major = r127;
                                } else {
                                    var r129: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r130: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r129)));
                                    var r132: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r130)));
                                    var r134: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r132)));
                                    var r135: f32 = opq((opq(speccomb)) * (opq(r134)));
                                    tau_major = r135;
                                }
                            }
                            if ((specparm1 < 0.125f)) {
                                var r137: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                var r138: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r137)));
                                var r140: f32 = opq(fma(opq(fac201), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind1 + 2i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r138)));
                                var r142: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r140)));
                                var r144: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r142)));
                                var r146: f32 = opq(fma(opq(fac211), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind1 + 11i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r144)));
                                var r147: f32 = opq((opq(speccomb1)) * (opq(r146)));
                                tau_major1 = r147;
                            } else {
                                if ((specparm1 > 0.875f)) {
                                    var r149: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + (ind1 - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r150: f32 = opq(fma(opq(fac201), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind1 - 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r149)));
                                    var r152: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r150)));
                                    var r154: f32 = opq(fma(opq(fac211), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind1 + 8i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r152)));
                                    var r156: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r154)));
                                    var r158: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r156)));
                                    var r159: f32 = opq((opq(speccomb1)) * (opq(r158)));
                                    tau_major1 = r159;
                                } else {
                                    var r161: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r162: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r161)));
                                    var r164: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r162)));
                                    var r166: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((65865i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r164)));
                                    var r167: f32 = opq((opq(speccomb1)) * (opq(r166)));
                                    tau_major1 = r167;
                                }
                            }
                            var r168: f32 = opq((opq(tau_major)) + (opq(tau_major1)));
                            var r169: f32 = opq((opq(r168)) + (opq(tauself)));
                            var r170: f32 = opq((opq(r169)) + (opq(taufor)));
                            var r172: f32 = opq(fma(opq(abso3), bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i))))), opq(r170)));
                            var r174: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).wx + bitcast<u32>((((1i) - 1i) + (4i * (lay - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>((96985i + (ig - 1i)))))), opq(r172)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((52i + ig) - 52i) - 1i)))), bitcast<u32>(r174));
                            var r175: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((65641i + (ig - 1i)) + (((jpl + 1i) - 1i) * 16i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((65641i + (ig - 1i)) + ((jpl - 1i) * 16i))))))));
                            var r177: f32 = opq(fma(opq(fpl), opq(r175), bitcast<f32>(mem_ld((T + bitcast<u32>(((65641i + (ig - 1i)) + ((jpl - 1i) * 16i))))))));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((52i + ig) - 52i) - 1i)))), bitcast<u32>(r177));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                var r179: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_o3co2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i)))))));
                speccomb = r179;
                var r180: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i))))), r179);
                specparm = r180;
                if ((r180 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r181: f32 = opq((opq(4.0f)) * (opq(specparm)));
                specmult = r181;
                js = (1i + (i32(r181)));
                var r182: f32 = opq((r181 % 1.0f));
                fs = r182;
                var r184: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_o3co2_1 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i)))))));
                speccomb1 = r184;
                var r185: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i))))), r184);
                specparm1 = r185;
                if ((r185 >= K_RR_ONEMINUS)) {
                    specparm1 = K_RR_ONEMINUS;
                }
                var r186: f32 = opq((opq(4.0f)) * (opq(specparm1)));
                specmult1 = r186;
                js1 = (1i + (i32(r186)));
                var r187: f32 = opq((r186 % 1.0f));
                fs1 = r187;
                var r188: f32 = opq((opq(1.0f)) - (opq(fs)));
                var r189: f32 = opq((opq(r188)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac000 = r189;
                var r190: f32 = opq((opq(1.0f)) - (opq(fs)));
                var r191: f32 = opq((opq(r190)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac010 = r191;
                var r192: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac100 = r192;
                var r193: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac110 = r193;
                var r194: f32 = opq((opq(1.0f)) - (opq(r187)));
                var r195: f32 = opq((opq(r194)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac001 = r195;
                var r196: f32 = opq((opq(1.0f)) - (opq(r187)));
                var r197: f32 = opq((opq(r196)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac011 = r197;
                var r198: f32 = opq((opq(r187)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac101 = r198;
                var r199: f32 = opq((opq(r187)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac111 = r199;
                var r201: f32 = opq(fma(opq(refrat_planck_b), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i)))))));
                speccomb_planck = r201;
                var r202: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i))))), r201);
                specparm_planck = r202;
                if ((r202 >= K_RR_ONEMINUS)) {
                    specparm_planck = K_RR_ONEMINUS;
                }
                var r203: f32 = opq((opq(4.0f)) * (opq(specparm_planck)));
                specmult_planck = r203;
                jpl = (1i + (i32(r203)));
                var r204: f32 = opq((r203 % 1.0f));
                fpl = r204;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((5i) - 1i)])) + js);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((5i) - 1i)])) + js1);
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 16i))) { break; }
                            var r206: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((75225i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 1175i))))))));
                            var r207: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((75225i + (ind0 - 1i)) + ((ig - 1i) * 1175i)))))), opq(r206)));
                            var r209: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((75225i + ((ind0 + 5i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r207)));
                            var r211: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((75225i + ((ind0 + 6i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r209)));
                            var r214: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((75225i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 1175i))))))));
                            var r215: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((75225i + (ind1 - 1i)) + ((ig - 1i) * 1175i)))))), opq(r214)));
                            var r217: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((75225i + ((ind1 + 5i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r215)));
                            var r219: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((75225i + ((ind1 + 6i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r217)));
                            var r220: f32 = opq((opq(speccomb1)) * (opq(r219)));
                            var r221: f32 = opq(fma(opq(speccomb), opq(r211), opq(r220)));
                            var r223: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).wx + bitcast<u32>((((1i) - 1i) + (4i * (lay - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>((96985i + (ig - 1i)))))), opq(r221)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((52i + ig) - 52i) - 1i)))), bitcast<u32>(r223));
                            var r224: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((65785i + (ig - 1i)) + (((jpl + 1i) - 1i) * 16i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((65785i + (ig - 1i)) + ((jpl - 1i) * 16i))))))));
                            var r226: f32 = opq(fma(opq(fpl), opq(r224), bitcast<f32>(mem_ld((T + bitcast<u32>(((65785i + (ig - 1i)) + ((jpl - 1i) * 16i))))))));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((52i + ig) - 52i) - 1i)))), bitcast<u32>(r226));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrlw_taugb6(C: ptr<function, S_RRLWColumn>, T_in: u32, taugL_in: u32, fracsL_in: u32) {
    var T: u32 = T_in;
    var taugL: u32 = taugL_in;
    var fracsL: u32 = fracsL_in;
    var absco2: f32 = f32(0i);
    var adjcolco2: f32 = f32(0i);
    var adjfac: f32 = f32(0i);
    var chi_co2: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var indm: i32 = 0i;
    var inds: i32 = 0i;
    var lay: i32 = 0i;
    var ratco2: f32 = f32(0i);
    var taufor: f32 = f32(0i);
    var tauself: f32 = f32(0i);
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                var r0: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i))))));
                chi_co2 = r0;
                var r1: f32 = opq((opq(1e+20f)) * (opq(r0)));
                var r2: f32 = div_cr(r1, bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) + 1i) - 1i))))))));
                ratco2 = r2;
                if ((r2 > 3.0f)) {
                    var r3: f32 = opq((opq(ratco2)) - (opq(2.0f)));
                    var r4: f32 = f_rr_pow_cr(r3, 0.77f);
                    var r5: f32 = opq((opq(2.0f)) + (opq(r4)));
                    adjfac = r5;
                    var r6: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) + 1i) - 1i)))))))));
                    var r7: f32 = opq((opq(r6)) * (bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i)))))));
                    var r8: f32 = opq((opq(r7)) * (opq(1e-20f)));
                    adjcolco2 = r8;
                } else {
                    adjcolco2 = bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i)))));
                }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((6i) - 1i)])) + 1i);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((6i) - 1i)])) + 1i);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                indm = bitcast<i32>(mem_ld(((*C).indminor + bitcast<u32>((lay - 1i)))));
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 8i))) { break; }
                            var r9: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((97681i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((97681i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r11: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r9), bitcast<f32>(mem_ld((T + bitcast<u32>(((97681i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r13: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((97761i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((97761i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r15: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r13), bitcast<f32>(mem_ld((T + bitcast<u32>(((97761i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r17: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((97529i + ((indm + 1i) - 1i)) + ((ig - 1i) * 19i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((97529i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            var r19: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r17), bitcast<f32>(mem_ld((T + bitcast<u32>(((97529i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            absco2 = r19;
                            var r21: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((97009i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 65i))))))));
                            var r22: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((97009i + (ind0 - 1i)) + ((ig - 1i) * 65i)))))), opq(r21)));
                            var r24: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((97009i + (ind1 - 1i)) + ((ig - 1i) * 65i)))))), opq(r22)));
                            var r26: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((97009i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 65i)))))), opq(r24)));
                            var r27: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (opq(r26)));
                            var r28: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i))))), opq(r11), opq(r27)));
                            var r29: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i))))), opq(r15), opq(r28)));
                            var r31: f32 = opq(fma(opq(adjcolco2), opq(r19), opq(r29)));
                            var r33: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).wx + bitcast<u32>((((2i) - 1i) + (4i * (lay - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>((97793i + (ig - 1i)))))), opq(r31)));
                            var r35: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).wx + bitcast<u32>((((3i) - 1i) + (4i * (lay - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>((97801i + (ig - 1i)))))), opq(r33)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((68i + ig) - 68i) - 1i)))), bitcast<u32>(r35));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((68i + ig) - 68i) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((97001i + (ig - 1i))))))));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 8i))) { break; }
                            var r37: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).wx + bitcast<u32>((((2i) - 1i) + (4i * (lay - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>((97793i + (ig - 1i)))))), opq(0.0f)));
                            var r39: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).wx + bitcast<u32>((((3i) - 1i) + (4i * (lay - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>((97801i + (ig - 1i)))))), opq(r37)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((68i + ig) - 68i) - 1i)))), bitcast<u32>(r39));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((68i + ig) - 68i) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((97001i + (ig - 1i))))))));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrlw_taugb7(C: ptr<function, S_RRLWColumn>, T_in: u32, taugL_in: u32, fracsL_in: u32) {
    var T: u32 = T_in;
    var taugL: u32 = taugL_in;
    var fracsL: u32 = fracsL_in;
    var absco2: f32 = f32(0i);
    var adjcolco2: f32 = f32(0i);
    var adjfac: f32 = f32(0i);
    var chi_co2: f32 = f32(0i);
    var co2m1: f32 = f32(0i);
    var co2m2: f32 = f32(0i);
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fac200: f32 = f32(0i);
    var fac201: f32 = f32(0i);
    var fac210: f32 = f32(0i);
    var fac211: f32 = f32(0i);
    var fk0: f32 = f32(0i);
    var fk1: f32 = f32(0i);
    var fk2: f32 = f32(0i);
    var fmco2: f32 = f32(0i);
    var fpl: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var fs1: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var indm: i32 = 0i;
    var inds: i32 = 0i;
    var jmco2: i32 = 0i;
    var jpl: i32 = 0i;
    var js: i32 = 0i;
    var js1: i32 = 0i;
    var lay: i32 = 0i;
    var p: f32 = f32(0i);
    var p4: f32 = f32(0i);
    var ratco2: f32 = f32(0i);
    var refrat_m_a: f32 = f32(0i);
    var refrat_planck_a: f32 = f32(0i);
    var speccomb: f32 = f32(0i);
    var speccomb1: f32 = f32(0i);
    var speccomb_mco2: f32 = f32(0i);
    var speccomb_planck: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specmult1: f32 = f32(0i);
    var specmult_mco2: f32 = f32(0i);
    var specmult_planck: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var specparm1: f32 = f32(0i);
    var specparm_mco2: f32 = f32(0i);
    var specparm_planck: f32 = f32(0i);
    var tau_major: f32 = f32(0i);
    var tau_major1: f32 = f32(0i);
    var taufor: f32 = f32(0i);
    var tauself: f32 = f32(0i);
    var r0: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((3i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((3i) - 1i)) + (7i * ((3i) - 1i))))))));
    refrat_planck_a = r0;
    var r1: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((3i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((3i) - 1i)) + (7i * ((3i) - 1i))))))));
    refrat_m_a = r1;
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                var r3: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_h2oo3 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb = r3;
                var r4: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r3);
                specparm = r4;
                if ((r4 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r5: f32 = opq((opq(8.0f)) * (opq(specparm)));
                specmult = r5;
                js = (1i + (i32(r5)));
                var r6: f32 = opq((r5 % 1.0f));
                fs = r6;
                var r8: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_h2oo3_1 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb1 = r8;
                var r9: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r8);
                specparm1 = r9;
                if ((r9 >= K_RR_ONEMINUS)) {
                    specparm1 = K_RR_ONEMINUS;
                }
                var r10: f32 = opq((opq(8.0f)) * (opq(specparm1)));
                specmult1 = r10;
                js1 = (1i + (i32(r10)));
                var r11: f32 = opq((r10 % 1.0f));
                fs1 = r11;
                var r13: f32 = opq(fma(opq(refrat_m_a), bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb_mco2 = r13;
                var r14: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r13);
                specparm_mco2 = r14;
                if ((r14 >= K_RR_ONEMINUS)) {
                    specparm_mco2 = K_RR_ONEMINUS;
                }
                var r15: f32 = opq((opq(8.0f)) * (opq(specparm_mco2)));
                specmult_mco2 = r15;
                jmco2 = (1i + (i32(r15)));
                var r16: f32 = opq((r15 % 1.0f));
                fmco2 = r16;
                var r17: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i))))));
                chi_co2 = r17;
                var r18: f32 = opq((opq(1e+20f)) * (opq(r17)));
                var r19: f32 = div_cr(r18, bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) + 1i) - 1i))))))));
                ratco2 = r19;
                if ((r19 > 3.0f)) {
                    var r20: f32 = opq((opq(ratco2)) - (opq(3.0f)));
                    var r21: f32 = f_rr_pow_cr(r20, 0.79f);
                    var r22: f32 = opq((opq(3.0f)) + (opq(r21)));
                    adjfac = r22;
                    var r23: f32 = opq((opq(r22)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) + 1i) - 1i)))))))));
                    var r24: f32 = opq((opq(r23)) * (bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i)))))));
                    var r25: f32 = opq((opq(r24)) * (opq(1e-20f)));
                    adjcolco2 = r25;
                } else {
                    adjcolco2 = bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i)))));
                }
                var r27: f32 = opq(fma(opq(refrat_planck_a), bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb_planck = r27;
                var r28: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r27);
                specparm_planck = r28;
                if ((r28 >= K_RR_ONEMINUS)) {
                    specparm_planck = K_RR_ONEMINUS;
                }
                var r29: f32 = opq((opq(8.0f)) * (opq(specparm_planck)));
                specmult_planck = r29;
                jpl = (1i + (i32(r29)));
                var r30: f32 = opq((r29 % 1.0f));
                fpl = r30;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((7i) - 1i)])) + js);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((7i) - 1i)])) + js1);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                indm = bitcast<i32>(mem_ld(((*C).indminor + bitcast<u32>((lay - 1i)))));
                if ((specparm < 0.125f)) {
                    var r31: f32 = opq((opq(fs)) - (opq(f32(1i))));
                    p = r31;
                    var r32: f32 = opq((opq(r31)) * (opq(r31)));
                    var r33: f32 = opq((opq(r32)) * (opq(r32)));
                    p4 = r33;
                    fk0 = r33;
                    var r34: f32 = opq((opq(f32(1i))) - (opq(r31)));
                    var r36: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r33), opq(r34)));
                    fk1 = r36;
                    var r37: f32 = opq((opq(r31)) + (opq(r33)));
                    fk2 = r37;
                    var r38: f32 = opq((opq(r33)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac000 = r38;
                    var r39: f32 = opq((opq(r36)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac100 = r39;
                    var r40: f32 = opq((opq(r37)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac200 = r40;
                    var r41: f32 = opq((opq(r33)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac010 = r41;
                    var r42: f32 = opq((opq(r36)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac110 = r42;
                    var r43: f32 = opq((opq(r37)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac210 = r43;
                } else {
                    if ((specparm > 0.875f)) {
                        var r44: f32 = f_rr_neg(fs, (*C).z0);
                        p = r44;
                        var r45: f32 = opq((opq(r44)) * (opq(r44)));
                        var r46: f32 = opq((opq(r45)) * (opq(r45)));
                        p4 = r46;
                        fk0 = r46;
                        var r47: f32 = opq((opq(f32(1i))) - (opq(r44)));
                        var r49: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r46), opq(r47)));
                        fk1 = r49;
                        var r50: f32 = opq((opq(r44)) + (opq(r46)));
                        fk2 = r50;
                        var r51: f32 = opq((opq(r46)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac000 = r51;
                        var r52: f32 = opq((opq(r49)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac100 = r52;
                        var r53: f32 = opq((opq(r50)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac200 = r53;
                        var r54: f32 = opq((opq(r46)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac010 = r54;
                        var r55: f32 = opq((opq(r49)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac110 = r55;
                        var r56: f32 = opq((opq(r50)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac210 = r56;
                    } else {
                        var r57: f32 = opq((opq(1.0f)) - (opq(fs)));
                        var r58: f32 = opq((opq(r57)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac000 = r58;
                        var r59: f32 = opq((opq(1.0f)) - (opq(fs)));
                        var r60: f32 = opq((opq(r59)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac010 = r60;
                        var r61: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac100 = r61;
                        var r62: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac110 = r62;
                    }
                }
                if ((specparm1 < 0.125f)) {
                    var r63: f32 = opq((opq(fs1)) - (opq(f32(1i))));
                    p = r63;
                    var r64: f32 = opq((opq(r63)) * (opq(r63)));
                    var r65: f32 = opq((opq(r64)) * (opq(r64)));
                    p4 = r65;
                    fk0 = r65;
                    var r66: f32 = opq((opq(f32(1i))) - (opq(r63)));
                    var r68: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r65), opq(r66)));
                    fk1 = r68;
                    var r69: f32 = opq((opq(r63)) + (opq(r65)));
                    fk2 = r69;
                    var r70: f32 = opq((opq(r65)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac001 = r70;
                    var r71: f32 = opq((opq(r68)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac101 = r71;
                    var r72: f32 = opq((opq(r69)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac201 = r72;
                    var r73: f32 = opq((opq(r65)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac011 = r73;
                    var r74: f32 = opq((opq(r68)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac111 = r74;
                    var r75: f32 = opq((opq(r69)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac211 = r75;
                } else {
                    if ((specparm1 > 0.875f)) {
                        var r76: f32 = f_rr_neg(fs1, (*C).z0);
                        p = r76;
                        var r77: f32 = opq((opq(r76)) * (opq(r76)));
                        var r78: f32 = opq((opq(r77)) * (opq(r77)));
                        p4 = r78;
                        fk0 = r78;
                        var r79: f32 = opq((opq(f32(1i))) - (opq(r76)));
                        var r81: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r78), opq(r79)));
                        fk1 = r81;
                        var r82: f32 = opq((opq(r76)) + (opq(r78)));
                        fk2 = r82;
                        var r83: f32 = opq((opq(r78)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac001 = r83;
                        var r84: f32 = opq((opq(r81)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac101 = r84;
                        var r85: f32 = opq((opq(r82)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac201 = r85;
                        var r86: f32 = opq((opq(r78)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac011 = r86;
                        var r87: f32 = opq((opq(r81)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac111 = r87;
                        var r88: f32 = opq((opq(r82)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac211 = r88;
                    } else {
                        var r89: f32 = opq((opq(1.0f)) - (opq(fs1)));
                        var r90: f32 = opq((opq(r89)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac001 = r90;
                        var r91: f32 = opq((opq(1.0f)) - (opq(fs1)));
                        var r92: f32 = opq((opq(r91)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac011 = r92;
                        var r93: f32 = opq((opq(fs1)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac101 = r93;
                        var r94: f32 = opq((opq(fs1)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac111 = r94;
                    }
                }
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 12i))) { break; }
                            var r95: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((110049i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((110049i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r97: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r95), bitcast<f32>(mem_ld((T + bitcast<u32>(((110049i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r98: f32 = opq((bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i)))))) * (opq(r97)));
                            tauself = r98;
                            var r99: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((110169i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((110169i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r101: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r99), bitcast<f32>(mem_ld((T + bitcast<u32>(((110169i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r102: f32 = opq((bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i)))))) * (opq(r101)));
                            taufor = r102;
                            var r103: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>((((107769i + ((jmco2 + 1i) - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>((((107769i + (jmco2 - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            var r105: f32 = opq(fma(opq(fmco2), opq(r103), bitcast<f32>(mem_ld((T + bitcast<u32>((((107769i + (jmco2 - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            co2m1 = r105;
                            var r106: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>((((107769i + ((jmco2 + 1i) - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>((((107769i + (jmco2 - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            var r108: f32 = opq(fma(opq(fmco2), opq(r106), bitcast<f32>(mem_ld((T + bitcast<u32>((((107769i + (jmco2 - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            co2m2 = r108;
                            var r109: f32 = opq((opq(r108)) - (opq(r105)));
                            var r111: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r109), opq(r105)));
                            absco2 = r111;
                            if ((specparm < 0.125f)) {
                                var r113: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                var r114: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r113)));
                                var r116: f32 = opq(fma(opq(fac200), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind0 + 2i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r114)));
                                var r118: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r116)));
                                var r120: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r118)));
                                var r122: f32 = opq(fma(opq(fac210), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind0 + 11i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r120)));
                                var r123: f32 = opq((opq(speccomb)) * (opq(r122)));
                                tau_major = r123;
                            } else {
                                if ((specparm > 0.875f)) {
                                    var r125: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + (ind0 - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r126: f32 = opq(fma(opq(fac200), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind0 - 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r125)));
                                    var r128: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r126)));
                                    var r130: f32 = opq(fma(opq(fac210), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind0 + 8i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r128)));
                                    var r132: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r130)));
                                    var r134: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r132)));
                                    var r135: f32 = opq((opq(speccomb)) * (opq(r134)));
                                    tau_major = r135;
                                } else {
                                    var r137: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r138: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r137)));
                                    var r140: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r138)));
                                    var r142: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r140)));
                                    var r143: f32 = opq((opq(speccomb)) * (opq(r142)));
                                    tau_major = r143;
                                }
                            }
                            if ((specparm1 < 0.125f)) {
                                var r145: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                var r146: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r145)));
                                var r148: f32 = opq(fma(opq(fac201), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind1 + 2i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r146)));
                                var r150: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r148)));
                                var r152: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r150)));
                                var r154: f32 = opq(fma(opq(fac211), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind1 + 11i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r152)));
                                var r155: f32 = opq((opq(speccomb1)) * (opq(r154)));
                                tau_major1 = r155;
                            } else {
                                if ((specparm1 > 0.875f)) {
                                    var r157: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + (ind1 - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r158: f32 = opq(fma(opq(fac201), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind1 - 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r157)));
                                    var r160: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r158)));
                                    var r162: f32 = opq(fma(opq(fac211), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind1 + 8i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r160)));
                                    var r164: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r162)));
                                    var r166: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r164)));
                                    var r167: f32 = opq((opq(speccomb1)) * (opq(r166)));
                                    tau_major1 = r167;
                                } else {
                                    var r169: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r170: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r169)));
                                    var r172: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r170)));
                                    var r174: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((97929i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r172)));
                                    var r175: f32 = opq((opq(speccomb1)) * (opq(r174)));
                                    tau_major1 = r175;
                                }
                            }
                            var r176: f32 = opq((opq(tau_major)) + (opq(tau_major1)));
                            var r177: f32 = opq((opq(r176)) + (opq(tauself)));
                            var r178: f32 = opq((opq(r177)) + (opq(taufor)));
                            var r180: f32 = opq(fma(opq(adjcolco2), opq(absco2), opq(r178)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((76i + ig) - 76i) - 1i)))), bitcast<u32>(r180));
                            var r181: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((97821i + (ig - 1i)) + (((jpl + 1i) - 1i) * 12i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((97821i + (ig - 1i)) + ((jpl - 1i) * 12i))))))));
                            var r183: f32 = opq(fma(opq(fpl), opq(r181), bitcast<f32>(mem_ld((T + bitcast<u32>(((97821i + (ig - 1i)) + ((jpl - 1i) * 12i))))))));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((76i + ig) - 76i) - 1i)))), bitcast<u32>(r183));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                var r184: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i))))));
                chi_co2 = r184;
                var r185: f32 = opq((opq(1e+20f)) * (opq(r184)));
                var r186: f32 = div_cr(r185, bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) + 1i) - 1i))))))));
                ratco2 = r186;
                if ((r186 > 3.0f)) {
                    var r187: f32 = opq((opq(ratco2)) - (opq(2.0f)));
                    var r188: f32 = f_rr_pow_cr(r187, 0.79f);
                    var r189: f32 = opq((opq(2.0f)) + (opq(r188)));
                    adjfac = r189;
                    var r190: f32 = opq((opq(r189)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) + 1i) - 1i)))))))));
                    var r191: f32 = opq((opq(r190)) * (bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i)))))));
                    var r192: f32 = opq((opq(r191)) * (opq(1e-20f)));
                    adjcolco2 = r192;
                } else {
                    adjcolco2 = bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i)))));
                }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((7i) - 1i)])) + 1i);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((7i) - 1i)])) + 1i);
                indm = bitcast<i32>(mem_ld(((*C).indminor + bitcast<u32>((lay - 1i)))));
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 12i))) { break; }
                            var r193: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((109821i + ((indm + 1i) - 1i)) + ((ig - 1i) * 19i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((109821i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            var r195: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r193), bitcast<f32>(mem_ld((T + bitcast<u32>(((109821i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            absco2 = r195;
                            var r197: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((104949i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 235i))))))));
                            var r198: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((104949i + (ind0 - 1i)) + ((ig - 1i) * 235i)))))), opq(r197)));
                            var r200: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((104949i + (ind1 - 1i)) + ((ig - 1i) * 235i)))))), opq(r198)));
                            var r202: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((104949i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 235i)))))), opq(r200)));
                            var r204: f32 = opq((opq(adjcolco2)) * (opq(r195)));
                            var r205: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i))))), opq(r202), opq(r204)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((76i + ig) - 76i) - 1i)))), bitcast<u32>(r205));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((76i + ig) - 76i) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((97809i + (ig - 1i))))))));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
                var r206: f32 = opq((bitcast<f32>(mem_ld((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((76i + 6i) - 76i) - 1i))))))) * (opq(0.92f)));
                mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((76i + 6i) - 76i) - 1i)))), bitcast<u32>(r206));
                var r207: f32 = opq((bitcast<f32>(mem_ld((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((76i + 7i) - 76i) - 1i))))))) * (opq(0.88f)));
                mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((76i + 7i) - 76i) - 1i)))), bitcast<u32>(r207));
                var r208: f32 = opq((bitcast<f32>(mem_ld((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((76i + 8i) - 76i) - 1i))))))) * (opq(1.07f)));
                mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((76i + 8i) - 76i) - 1i)))), bitcast<u32>(r208));
                var r209: f32 = opq((bitcast<f32>(mem_ld((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((76i + 9i) - 76i) - 1i))))))) * (opq(1.1f)));
                mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((76i + 9i) - 76i) - 1i)))), bitcast<u32>(r209));
                var r210: f32 = opq((bitcast<f32>(mem_ld((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((76i + 10i) - 76i) - 1i))))))) * (opq(0.99f)));
                mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((76i + 10i) - 76i) - 1i)))), bitcast<u32>(r210));
                var r211: f32 = opq((bitcast<f32>(mem_ld((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((76i + 11i) - 76i) - 1i))))))) * (opq(0.855f)));
                mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((76i + 11i) - 76i) - 1i)))), bitcast<u32>(r211));
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrlw_taugb8(C: ptr<function, S_RRLWColumn>, T_in: u32, taugL_in: u32, fracsL_in: u32) {
    var T: u32 = T_in;
    var taugL: u32 = taugL_in;
    var fracsL: u32 = fracsL_in;
    var absco2: f32 = f32(0i);
    var absn2o: f32 = f32(0i);
    var abso3: f32 = f32(0i);
    var adjcolco2: f32 = f32(0i);
    var adjfac: f32 = f32(0i);
    var chi_co2: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var indm: i32 = 0i;
    var inds: i32 = 0i;
    var lay: i32 = 0i;
    var ratco2: f32 = f32(0i);
    var taufor: f32 = f32(0i);
    var tauself: f32 = f32(0i);
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                var r0: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i))))));
                chi_co2 = r0;
                var r1: f32 = opq((opq(1e+20f)) * (opq(r0)));
                var r2: f32 = div_cr(r1, bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) + 1i) - 1i))))))));
                ratco2 = r2;
                if ((r2 > 3.0f)) {
                    var r3: f32 = opq((opq(ratco2)) - (opq(2.0f)));
                    var r4: f32 = f_rr_pow_cr(r3, 0.65f);
                    var r5: f32 = opq((opq(2.0f)) + (opq(r4)));
                    adjfac = r5;
                    var r6: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) + 1i) - 1i)))))))));
                    var r7: f32 = opq((opq(r6)) * (bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i)))))));
                    var r8: f32 = opq((opq(r7)) * (opq(1e-20f)));
                    adjcolco2 = r8;
                } else {
                    adjcolco2 = bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i)))));
                }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((8i) - 1i)])) + 1i);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((8i) - 1i)])) + 1i);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                indm = bitcast<i32>(mem_ld(((*C).indminor + bitcast<u32>((lay - 1i)))));
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 8i))) { break; }
                            var r9: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((113409i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((113409i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r11: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r9), bitcast<f32>(mem_ld((T + bitcast<u32>(((113409i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r13: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((113489i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((113489i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r15: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r13), bitcast<f32>(mem_ld((T + bitcast<u32>(((113489i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r17: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((112649i + ((indm + 1i) - 1i)) + ((ig - 1i) * 19i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((112649i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            var r19: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r17), bitcast<f32>(mem_ld((T + bitcast<u32>(((112649i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            absco2 = r19;
                            var r20: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((112953i + ((indm + 1i) - 1i)) + ((ig - 1i) * 19i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((112953i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            var r22: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r20), bitcast<f32>(mem_ld((T + bitcast<u32>(((112953i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            abso3 = r22;
                            var r23: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((112801i + ((indm + 1i) - 1i)) + ((ig - 1i) * 19i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((112801i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            var r25: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r23), bitcast<f32>(mem_ld((T + bitcast<u32>(((112801i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            absn2o = r25;
                            var r27: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((110249i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 65i))))))));
                            var r28: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((110249i + (ind0 - 1i)) + ((ig - 1i) * 65i)))))), opq(r27)));
                            var r30: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((110249i + (ind1 - 1i)) + ((ig - 1i) * 65i)))))), opq(r28)));
                            var r32: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((110249i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 65i)))))), opq(r30)));
                            var r33: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (opq(r32)));
                            var r34: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i))))), opq(r11), opq(r33)));
                            var r35: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i))))), opq(r15), opq(r34)));
                            var r37: f32 = opq(fma(opq(adjcolco2), opq(r19), opq(r35)));
                            var r39: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i))))), opq(r22), opq(r37)));
                            var r41: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i))))), opq(r25), opq(r39)));
                            var r43: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).wx + bitcast<u32>((((3i) - 1i) + (4i * (lay - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>((110233i + (ig - 1i)))))), opq(r41)));
                            var r45: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).wx + bitcast<u32>((((4i) - 1i) + (4i * (lay - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>((110241i + (ig - 1i)))))), opq(r43)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((88i + ig) - 88i) - 1i)))), bitcast<u32>(r45));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((88i + ig) - 88i) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((110217i + (ig - 1i))))))));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                var r46: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i))))));
                chi_co2 = r46;
                var r47: f32 = opq((opq(1e+20f)) * (opq(r46)));
                var r48: f32 = div_cr(r47, bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) + 1i) - 1i))))))));
                ratco2 = r48;
                if ((r48 > 3.0f)) {
                    var r49: f32 = opq((opq(ratco2)) - (opq(2.0f)));
                    var r50: f32 = f_rr_pow_cr(r49, 0.65f);
                    var r51: f32 = opq((opq(2.0f)) + (opq(r50)));
                    adjfac = r51;
                    var r52: f32 = opq((opq(r51)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) + 1i) - 1i)))))))));
                    var r53: f32 = opq((opq(r52)) * (bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i)))))));
                    var r54: f32 = opq((opq(r53)) * (opq(1e-20f)));
                    adjcolco2 = r54;
                } else {
                    adjcolco2 = bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i)))));
                }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((8i) - 1i)])) + 1i);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((8i) - 1i)])) + 1i);
                indm = bitcast<i32>(mem_ld(((*C).indminor + bitcast<u32>((lay - 1i)))));
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 8i))) { break; }
                            var r55: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((113105i + ((indm + 1i) - 1i)) + ((ig - 1i) * 19i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((113105i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            var r57: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r55), bitcast<f32>(mem_ld((T + bitcast<u32>(((113105i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            absco2 = r57;
                            var r58: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((113257i + ((indm + 1i) - 1i)) + ((ig - 1i) * 19i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((113257i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            var r60: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r58), bitcast<f32>(mem_ld((T + bitcast<u32>(((113257i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            absn2o = r60;
                            var r62: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((110769i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 235i))))))));
                            var r63: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((110769i + (ind0 - 1i)) + ((ig - 1i) * 235i)))))), opq(r62)));
                            var r65: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((110769i + (ind1 - 1i)) + ((ig - 1i) * 235i)))))), opq(r63)));
                            var r67: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((110769i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 235i)))))), opq(r65)));
                            var r69: f32 = opq((opq(adjcolco2)) * (opq(r57)));
                            var r70: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i))))), opq(r67), opq(r69)));
                            var r72: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i))))), opq(r60), opq(r70)));
                            var r74: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).wx + bitcast<u32>((((3i) - 1i) + (4i * (lay - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>((110233i + (ig - 1i)))))), opq(r72)));
                            var r76: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).wx + bitcast<u32>((((4i) - 1i) + (4i * (lay - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>((110241i + (ig - 1i)))))), opq(r74)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((88i + ig) - 88i) - 1i)))), bitcast<u32>(r76));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((88i + ig) - 88i) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((110225i + (ig - 1i))))))));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrlw_taugb9(C: ptr<function, S_RRLWColumn>, T_in: u32, taugL_in: u32, fracsL_in: u32) {
    var T: u32 = T_in;
    var taugL: u32 = taugL_in;
    var fracsL: u32 = fracsL_in;
    var absn2o: f32 = f32(0i);
    var adjcoln2o: f32 = f32(0i);
    var adjfac: f32 = f32(0i);
    var chi_n2o: f32 = f32(0i);
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fac200: f32 = f32(0i);
    var fac201: f32 = f32(0i);
    var fac210: f32 = f32(0i);
    var fac211: f32 = f32(0i);
    var fk0: f32 = f32(0i);
    var fk1: f32 = f32(0i);
    var fk2: f32 = f32(0i);
    var fmn2o: f32 = f32(0i);
    var fpl: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var fs1: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var indm: i32 = 0i;
    var inds: i32 = 0i;
    var jmn2o: i32 = 0i;
    var jpl: i32 = 0i;
    var js: i32 = 0i;
    var js1: i32 = 0i;
    var lay: i32 = 0i;
    var n2om1: f32 = f32(0i);
    var n2om2: f32 = f32(0i);
    var p: f32 = f32(0i);
    var p4: f32 = f32(0i);
    var ratn2o: f32 = f32(0i);
    var refrat_m_a: f32 = f32(0i);
    var refrat_planck_a: f32 = f32(0i);
    var speccomb: f32 = f32(0i);
    var speccomb1: f32 = f32(0i);
    var speccomb_mn2o: f32 = f32(0i);
    var speccomb_planck: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specmult1: f32 = f32(0i);
    var specmult_mn2o: f32 = f32(0i);
    var specmult_planck: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var specparm1: f32 = f32(0i);
    var specparm_mn2o: f32 = f32(0i);
    var specparm_planck: f32 = f32(0i);
    var tau_major: f32 = f32(0i);
    var tau_major1: f32 = f32(0i);
    var taufor: f32 = f32(0i);
    var tauself: f32 = f32(0i);
    var r0: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((9i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((6i) - 1i)) + (7i * ((9i) - 1i))))))));
    refrat_planck_a = r0;
    var r1: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((3i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((6i) - 1i)) + (7i * ((3i) - 1i))))))));
    refrat_m_a = r1;
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                var r3: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_h2och4 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colch4 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb = r3;
                var r4: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r3);
                specparm = r4;
                if ((r4 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r5: f32 = opq((opq(8.0f)) * (opq(specparm)));
                specmult = r5;
                js = (1i + (i32(r5)));
                var r6: f32 = opq((r5 % 1.0f));
                fs = r6;
                var r8: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_h2och4_1 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colch4 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb1 = r8;
                var r9: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r8);
                specparm1 = r9;
                if ((r9 >= K_RR_ONEMINUS)) {
                    specparm1 = K_RR_ONEMINUS;
                }
                var r10: f32 = opq((opq(8.0f)) * (opq(specparm1)));
                specmult1 = r10;
                js1 = (1i + (i32(r10)));
                var r11: f32 = opq((r10 % 1.0f));
                fs1 = r11;
                var r13: f32 = opq(fma(opq(refrat_m_a), bitcast<f32>(mem_ld(((*C).colch4 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb_mn2o = r13;
                var r14: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r13);
                specparm_mn2o = r14;
                if ((r14 >= K_RR_ONEMINUS)) {
                    specparm_mn2o = K_RR_ONEMINUS;
                }
                var r15: f32 = opq((opq(8.0f)) * (opq(specparm_mn2o)));
                specmult_mn2o = r15;
                jmn2o = (1i + (i32(r15)));
                var r16: f32 = opq((r15 % 1.0f));
                fmn2o = r16;
                var r17: f32 = div_cr(bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i))))));
                chi_n2o = r17;
                var r18: f32 = opq((opq(1e+20f)) * (opq(r17)));
                var r19: f32 = div_cr(r18, bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((4i) - 1i)) + (7i * (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) + 1i) - 1i))))))));
                ratn2o = r19;
                if ((r19 > 1.5f)) {
                    var r20: f32 = opq((opq(ratn2o)) - (opq(0.5f)));
                    var r21: f32 = f_rr_pow_cr(r20, 0.65f);
                    var r22: f32 = opq((opq(0.5f)) + (opq(r21)));
                    adjfac = r22;
                    var r23: f32 = opq((opq(r22)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((4i) - 1i)) + (7i * (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) + 1i) - 1i)))))))));
                    var r24: f32 = opq((opq(r23)) * (bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i)))))));
                    var r25: f32 = opq((opq(r24)) * (opq(1e-20f)));
                    adjcoln2o = r25;
                } else {
                    adjcoln2o = bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i)))));
                }
                var r27: f32 = opq(fma(opq(refrat_planck_a), bitcast<f32>(mem_ld(((*C).colch4 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb_planck = r27;
                var r28: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r27);
                specparm_planck = r28;
                if ((r28 >= K_RR_ONEMINUS)) {
                    specparm_planck = K_RR_ONEMINUS;
                }
                var r29: f32 = opq((opq(8.0f)) * (opq(specparm_planck)));
                specmult_planck = r29;
                jpl = (1i + (i32(r29)));
                var r30: f32 = opq((r29 % 1.0f));
                fpl = r30;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((9i) - 1i)])) + js);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((9i) - 1i)])) + js1);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                indm = bitcast<i32>(mem_ld(((*C).indminor + bitcast<u32>((lay - 1i)))));
                if ((specparm < 0.125f)) {
                    var r31: f32 = opq((opq(fs)) - (opq(f32(1i))));
                    p = r31;
                    var r32: f32 = opq((opq(r31)) * (opq(r31)));
                    var r33: f32 = opq((opq(r32)) * (opq(r32)));
                    p4 = r33;
                    fk0 = r33;
                    var r34: f32 = opq((opq(f32(1i))) - (opq(r31)));
                    var r36: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r33), opq(r34)));
                    fk1 = r36;
                    var r37: f32 = opq((opq(r31)) + (opq(r33)));
                    fk2 = r37;
                    var r38: f32 = opq((opq(r33)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac000 = r38;
                    var r39: f32 = opq((opq(r36)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac100 = r39;
                    var r40: f32 = opq((opq(r37)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac200 = r40;
                    var r41: f32 = opq((opq(r33)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac010 = r41;
                    var r42: f32 = opq((opq(r36)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac110 = r42;
                    var r43: f32 = opq((opq(r37)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac210 = r43;
                } else {
                    if ((specparm > 0.875f)) {
                        var r44: f32 = f_rr_neg(fs, (*C).z0);
                        p = r44;
                        var r45: f32 = opq((opq(r44)) * (opq(r44)));
                        var r46: f32 = opq((opq(r45)) * (opq(r45)));
                        p4 = r46;
                        fk0 = r46;
                        var r47: f32 = opq((opq(f32(1i))) - (opq(r44)));
                        var r49: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r46), opq(r47)));
                        fk1 = r49;
                        var r50: f32 = opq((opq(r44)) + (opq(r46)));
                        fk2 = r50;
                        var r51: f32 = opq((opq(r46)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac000 = r51;
                        var r52: f32 = opq((opq(r49)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac100 = r52;
                        var r53: f32 = opq((opq(r50)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac200 = r53;
                        var r54: f32 = opq((opq(r46)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac010 = r54;
                        var r55: f32 = opq((opq(r49)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac110 = r55;
                        var r56: f32 = opq((opq(r50)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac210 = r56;
                    } else {
                        var r57: f32 = opq((opq(1.0f)) - (opq(fs)));
                        var r58: f32 = opq((opq(r57)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac000 = r58;
                        var r59: f32 = opq((opq(1.0f)) - (opq(fs)));
                        var r60: f32 = opq((opq(r59)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac010 = r60;
                        var r61: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac100 = r61;
                        var r62: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac110 = r62;
                    }
                }
                if ((specparm1 < 0.125f)) {
                    var r63: f32 = opq((opq(fs1)) - (opq(f32(1i))));
                    p = r63;
                    var r64: f32 = opq((opq(r63)) * (opq(r63)));
                    var r65: f32 = opq((opq(r64)) * (opq(r64)));
                    p4 = r65;
                    fk0 = r65;
                    var r66: f32 = opq((opq(f32(1i))) - (opq(r63)));
                    var r68: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r65), opq(r66)));
                    fk1 = r68;
                    var r69: f32 = opq((opq(r63)) + (opq(r65)));
                    fk2 = r69;
                    var r70: f32 = opq((opq(r65)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac001 = r70;
                    var r71: f32 = opq((opq(r68)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac101 = r71;
                    var r72: f32 = opq((opq(r69)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac201 = r72;
                    var r73: f32 = opq((opq(r65)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac011 = r73;
                    var r74: f32 = opq((opq(r68)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac111 = r74;
                    var r75: f32 = opq((opq(r69)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac211 = r75;
                } else {
                    if ((specparm1 > 0.875f)) {
                        var r76: f32 = f_rr_neg(fs1, (*C).z0);
                        p = r76;
                        var r77: f32 = opq((opq(r76)) * (opq(r76)));
                        var r78: f32 = opq((opq(r77)) * (opq(r77)));
                        p4 = r78;
                        fk0 = r78;
                        var r79: f32 = opq((opq(f32(1i))) - (opq(r76)));
                        var r81: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r78), opq(r79)));
                        fk1 = r81;
                        var r82: f32 = opq((opq(r76)) + (opq(r78)));
                        fk2 = r82;
                        var r83: f32 = opq((opq(r78)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac001 = r83;
                        var r84: f32 = opq((opq(r81)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac101 = r84;
                        var r85: f32 = opq((opq(r82)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac201 = r85;
                        var r86: f32 = opq((opq(r78)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac011 = r86;
                        var r87: f32 = opq((opq(r81)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac111 = r87;
                        var r88: f32 = opq((opq(r82)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac211 = r88;
                    } else {
                        var r89: f32 = opq((opq(1.0f)) - (opq(fs1)));
                        var r90: f32 = opq((opq(r89)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac001 = r90;
                        var r91: f32 = opq((opq(1.0f)) - (opq(fs1)));
                        var r92: f32 = opq((opq(r91)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac011 = r92;
                        var r93: f32 = opq((opq(fs1)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac101 = r93;
                        var r94: f32 = opq((opq(fs1)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac111 = r94;
                    }
                }
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 12i))) { break; }
                            var r95: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((125761i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((125761i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r97: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r95), bitcast<f32>(mem_ld((T + bitcast<u32>(((125761i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r98: f32 = opq((bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i)))))) * (opq(r97)));
                            tauself = r98;
                            var r99: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((125881i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((125881i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r101: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r99), bitcast<f32>(mem_ld((T + bitcast<u32>(((125881i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r102: f32 = opq((bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i)))))) * (opq(r101)));
                            taufor = r102;
                            var r103: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>((((123481i + ((jmn2o + 1i) - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>((((123481i + (jmn2o - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            var r105: f32 = opq(fma(opq(fmn2o), opq(r103), bitcast<f32>(mem_ld((T + bitcast<u32>((((123481i + (jmn2o - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            n2om1 = r105;
                            var r106: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>((((123481i + ((jmn2o + 1i) - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>((((123481i + (jmn2o - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            var r108: f32 = opq(fma(opq(fmn2o), opq(r106), bitcast<f32>(mem_ld((T + bitcast<u32>((((123481i + (jmn2o - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            n2om2 = r108;
                            var r109: f32 = opq((opq(r108)) - (opq(r105)));
                            var r111: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r109), opq(r105)));
                            absn2o = r111;
                            if ((specparm < 0.125f)) {
                                var r113: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                var r114: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r113)));
                                var r116: f32 = opq(fma(opq(fac200), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind0 + 2i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r114)));
                                var r118: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r116)));
                                var r120: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r118)));
                                var r122: f32 = opq(fma(opq(fac210), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind0 + 11i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r120)));
                                var r123: f32 = opq((opq(speccomb)) * (opq(r122)));
                                tau_major = r123;
                            } else {
                                if ((specparm > 0.875f)) {
                                    var r125: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + (ind0 - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r126: f32 = opq(fma(opq(fac200), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind0 - 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r125)));
                                    var r128: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r126)));
                                    var r130: f32 = opq(fma(opq(fac210), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind0 + 8i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r128)));
                                    var r132: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r130)));
                                    var r134: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r132)));
                                    var r135: f32 = opq((opq(speccomb)) * (opq(r134)));
                                    tau_major = r135;
                                } else {
                                    var r137: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r138: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r137)));
                                    var r140: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r138)));
                                    var r142: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r140)));
                                    var r143: f32 = opq((opq(speccomb)) * (opq(r142)));
                                    tau_major = r143;
                                }
                            }
                            if ((specparm1 < 0.125f)) {
                                var r145: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                var r146: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r145)));
                                var r148: f32 = opq(fma(opq(fac201), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind1 + 2i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r146)));
                                var r150: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r148)));
                                var r152: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r150)));
                                var r154: f32 = opq(fma(opq(fac211), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind1 + 11i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r152)));
                                var r155: f32 = opq((opq(speccomb1)) * (opq(r154)));
                                tau_major1 = r155;
                            } else {
                                if ((specparm1 > 0.875f)) {
                                    var r157: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + (ind1 - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r158: f32 = opq(fma(opq(fac201), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind1 - 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r157)));
                                    var r160: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r158)));
                                    var r162: f32 = opq(fma(opq(fac211), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind1 + 8i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r160)));
                                    var r164: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r162)));
                                    var r166: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r164)));
                                    var r167: f32 = opq((opq(speccomb1)) * (opq(r166)));
                                    tau_major1 = r167;
                                } else {
                                    var r169: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r170: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r169)));
                                    var r172: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r170)));
                                    var r174: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((113641i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r172)));
                                    var r175: f32 = opq((opq(speccomb1)) * (opq(r174)));
                                    tau_major1 = r175;
                                }
                            }
                            var r176: f32 = opq((opq(tau_major)) + (opq(tau_major1)));
                            var r177: f32 = opq((opq(r176)) + (opq(tauself)));
                            var r178: f32 = opq((opq(r177)) + (opq(taufor)));
                            var r180: f32 = opq(fma(opq(adjcoln2o), opq(absn2o), opq(r178)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((96i + ig) - 96i) - 1i)))), bitcast<u32>(r180));
                            var r181: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((113533i + (ig - 1i)) + (((jpl + 1i) - 1i) * 12i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((113533i + (ig - 1i)) + ((jpl - 1i) * 12i))))))));
                            var r183: f32 = opq(fma(opq(fpl), opq(r181), bitcast<f32>(mem_ld((T + bitcast<u32>(((113533i + (ig - 1i)) + ((jpl - 1i) * 12i))))))));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((96i + ig) - 96i) - 1i)))), bitcast<u32>(r183));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                var r184: f32 = div_cr(bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i))))));
                chi_n2o = r184;
                var r185: f32 = opq((opq(1e+20f)) * (opq(r184)));
                var r186: f32 = div_cr(r185, bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((4i) - 1i)) + (7i * (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) + 1i) - 1i))))))));
                ratn2o = r186;
                if ((r186 > 1.5f)) {
                    var r187: f32 = opq((opq(ratn2o)) - (opq(0.5f)));
                    var r188: f32 = f_rr_pow_cr(r187, 0.65f);
                    var r189: f32 = opq((opq(0.5f)) + (opq(r188)));
                    adjfac = r189;
                    var r190: f32 = opq((opq(r189)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((4i) - 1i)) + (7i * (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) + 1i) - 1i)))))))));
                    var r191: f32 = opq((opq(r190)) * (bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i)))))));
                    var r192: f32 = opq((opq(r191)) * (opq(1e-20f)));
                    adjcoln2o = r192;
                } else {
                    adjcoln2o = bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i)))));
                }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((9i) - 1i)])) + 1i);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((9i) - 1i)])) + 1i);
                indm = bitcast<i32>(mem_ld(((*C).indminor + bitcast<u32>((lay - 1i)))));
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 12i))) { break; }
                            var r193: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((125533i + ((indm + 1i) - 1i)) + ((ig - 1i) * 19i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((125533i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            var r195: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r193), bitcast<f32>(mem_ld((T + bitcast<u32>(((125533i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            absn2o = r195;
                            var r197: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((120661i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 235i))))))));
                            var r198: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((120661i + (ind0 - 1i)) + ((ig - 1i) * 235i)))))), opq(r197)));
                            var r200: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((120661i + (ind1 - 1i)) + ((ig - 1i) * 235i)))))), opq(r198)));
                            var r202: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((120661i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 235i)))))), opq(r200)));
                            var r204: f32 = opq((opq(adjcoln2o)) * (opq(r195)));
                            var r205: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).colch4 + bitcast<u32>((lay - 1i))))), opq(r202), opq(r204)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((96i + ig) - 96i) - 1i)))), bitcast<u32>(r205));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((96i + ig) - 96i) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((113521i + (ig - 1i))))))));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrlw_taugb10(C: ptr<function, S_RRLWColumn>, T_in: u32, taugL_in: u32, fracsL_in: u32) {
    var T: u32 = T_in;
    var taugL: u32 = taugL_in;
    var fracsL: u32 = fracsL_in;
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var lay: i32 = 0i;
    var taufor: f32 = f32(0i);
    var tauself: f32 = f32(0i);
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((10i) - 1i)])) + 1i);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((10i) - 1i)])) + 1i);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 6i))) { break; }
                            var r0: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((127741i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((127741i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r2: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r0), bitcast<f32>(mem_ld((T + bitcast<u32>(((127741i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r4: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((127801i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((127801i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r6: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r4), bitcast<f32>(mem_ld((T + bitcast<u32>(((127801i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r9: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((125941i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 65i))))))));
                            var r10: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((125941i + (ind0 - 1i)) + ((ig - 1i) * 65i)))))), opq(r9)));
                            var r12: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((125941i + (ind1 - 1i)) + ((ig - 1i) * 65i)))))), opq(r10)));
                            var r14: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((125941i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 65i)))))), opq(r12)));
                            var r15: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (opq(r14)));
                            var r16: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i))))), opq(r2), opq(r15)));
                            var r17: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i))))), opq(r6), opq(r16)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((108i + ig) - 108i) - 1i)))), bitcast<u32>(r17));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((108i + ig) - 108i) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((125929i + (ig - 1i))))))));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((10i) - 1i)])) + 1i);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((10i) - 1i)])) + 1i);
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 6i))) { break; }
                            var r18: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((127801i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((127801i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r20: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r18), bitcast<f32>(mem_ld((T + bitcast<u32>(((127801i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r23: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((126331i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 235i))))))));
                            var r24: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((126331i + (ind0 - 1i)) + ((ig - 1i) * 235i)))))), opq(r23)));
                            var r26: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((126331i + (ind1 - 1i)) + ((ig - 1i) * 235i)))))), opq(r24)));
                            var r28: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((126331i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 235i)))))), opq(r26)));
                            var r29: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (opq(r28)));
                            var r30: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i))))), opq(r20), opq(r29)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((108i + ig) - 108i) - 1i)))), bitcast<u32>(r30));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((108i + ig) - 108i) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((125935i + (ig - 1i))))))));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrlw_taugb11(C: ptr<function, S_RRLWColumn>, T_in: u32, taugL_in: u32, fracsL_in: u32) {
    var T: u32 = T_in;
    var taugL: u32 = taugL_in;
    var fracsL: u32 = fracsL_in;
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var indm: i32 = 0i;
    var inds: i32 = 0i;
    var lay: i32 = 0i;
    var scaleo2: f32 = f32(0i);
    var taufor: f32 = f32(0i);
    var tauo2: f32 = f32(0i);
    var tauself: f32 = f32(0i);
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((11i) - 1i)])) + 1i);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((11i) - 1i)])) + 1i);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                indm = bitcast<i32>(mem_ld(((*C).indminor + bitcast<u32>((lay - 1i)))));
                var r0: f32 = opq((bitcast<f32>(mem_ld(((*C).colo2 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld(((*C).scaleminor + bitcast<u32>((lay - 1i)))))));
                scaleo2 = r0;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 8i))) { break; }
                            var r1: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((130545i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((130545i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r3: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r1), bitcast<f32>(mem_ld((T + bitcast<u32>(((130545i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r5: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((130625i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((130625i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r7: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r5), bitcast<f32>(mem_ld((T + bitcast<u32>(((130625i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r9: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((130241i + ((indm + 1i) - 1i)) + ((ig - 1i) * 19i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((130241i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            var r11: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r9), bitcast<f32>(mem_ld((T + bitcast<u32>(((130241i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            var r14: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((127841i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 65i))))))));
                            var r15: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((127841i + (ind0 - 1i)) + ((ig - 1i) * 65i)))))), opq(r14)));
                            var r17: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((127841i + (ind1 - 1i)) + ((ig - 1i) * 65i)))))), opq(r15)));
                            var r19: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((127841i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 65i)))))), opq(r17)));
                            var r20: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (opq(r19)));
                            var r21: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i))))), opq(r3), opq(r20)));
                            var r22: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i))))), opq(r7), opq(r21)));
                            var r23: f32 = opq(fma(opq(scaleo2), opq(r11), opq(r22)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((114i + ig) - 114i) - 1i)))), bitcast<u32>(r23));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((114i + ig) - 114i) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((127825i + (ig - 1i))))))));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((11i) - 1i)])) + 1i);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((11i) - 1i)])) + 1i);
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                indm = bitcast<i32>(mem_ld(((*C).indminor + bitcast<u32>((lay - 1i)))));
                var r24: f32 = opq((bitcast<f32>(mem_ld(((*C).colo2 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld(((*C).scaleminor + bitcast<u32>((lay - 1i)))))));
                scaleo2 = r24;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 8i))) { break; }
                            var r25: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((130625i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((130625i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r27: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r25), bitcast<f32>(mem_ld((T + bitcast<u32>(((130625i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r29: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((130393i + ((indm + 1i) - 1i)) + ((ig - 1i) * 19i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((130393i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            var r31: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r29), bitcast<f32>(mem_ld((T + bitcast<u32>(((130393i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            var r34: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((128361i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 235i))))))));
                            var r35: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((128361i + (ind0 - 1i)) + ((ig - 1i) * 235i)))))), opq(r34)));
                            var r37: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((128361i + (ind1 - 1i)) + ((ig - 1i) * 235i)))))), opq(r35)));
                            var r39: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((128361i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 235i)))))), opq(r37)));
                            var r40: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (opq(r39)));
                            var r41: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i))))), opq(r27), opq(r40)));
                            var r42: f32 = opq(fma(opq(scaleo2), opq(r31), opq(r41)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((114i + ig) - 114i) - 1i)))), bitcast<u32>(r42));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((114i + ig) - 114i) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((127833i + (ig - 1i))))))));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrlw_taugb12(C: ptr<function, S_RRLWColumn>, T_in: u32, taugL_in: u32, fracsL_in: u32) {
    var T: u32 = T_in;
    var taugL: u32 = taugL_in;
    var fracsL: u32 = fracsL_in;
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fac200: f32 = f32(0i);
    var fac201: f32 = f32(0i);
    var fac210: f32 = f32(0i);
    var fac211: f32 = f32(0i);
    var fk0: f32 = f32(0i);
    var fk1: f32 = f32(0i);
    var fk2: f32 = f32(0i);
    var fpl: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var fs1: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var jpl: i32 = 0i;
    var js: i32 = 0i;
    var js1: i32 = 0i;
    var lay: i32 = 0i;
    var p: f32 = f32(0i);
    var p4: f32 = f32(0i);
    var refrat_planck_a: f32 = f32(0i);
    var speccomb: f32 = f32(0i);
    var speccomb1: f32 = f32(0i);
    var speccomb_planck: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specmult1: f32 = f32(0i);
    var specmult_planck: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var specparm1: f32 = f32(0i);
    var specparm_planck: f32 = f32(0i);
    var tau_major: f32 = f32(0i);
    var tau_major1: f32 = f32(0i);
    var taufor: f32 = f32(0i);
    var tauself: f32 = f32(0i);
    var r0: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((10i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * ((10i) - 1i))))))));
    refrat_planck_a = r0;
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                var r2: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_h2oco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb = r2;
                var r3: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r2);
                specparm = r3;
                if ((r3 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r4: f32 = opq((opq(8.0f)) * (opq(specparm)));
                specmult = r4;
                js = (1i + (i32(r4)));
                var r5: f32 = opq((r4 % 1.0f));
                fs = r5;
                var r7: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_h2oco2_1 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb1 = r7;
                var r8: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r7);
                specparm1 = r8;
                if ((r8 >= K_RR_ONEMINUS)) {
                    specparm1 = K_RR_ONEMINUS;
                }
                var r9: f32 = opq((opq(8.0f)) * (opq(specparm1)));
                specmult1 = r9;
                js1 = (1i + (i32(r9)));
                var r10: f32 = opq((r9 % 1.0f));
                fs1 = r10;
                var r12: f32 = opq(fma(opq(refrat_planck_a), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb_planck = r12;
                var r13: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r12);
                specparm_planck = r13;
                if ((r13 >= K_RR_ONEMINUS)) {
                    specparm_planck = K_RR_ONEMINUS;
                }
                var r14: f32 = opq((opq(8.0f)) * (opq(specparm_planck)));
                specmult_planck = r14;
                jpl = (1i + (i32(r14)));
                var r15: f32 = opq((r14 % 1.0f));
                fpl = r15;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((12i) - 1i)])) + js);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((12i) - 1i)])) + js1);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                if ((specparm < 0.125f)) {
                    var r16: f32 = opq((opq(fs)) - (opq(f32(1i))));
                    p = r16;
                    var r17: f32 = opq((opq(r16)) * (opq(r16)));
                    var r18: f32 = opq((opq(r17)) * (opq(r17)));
                    p4 = r18;
                    fk0 = r18;
                    var r19: f32 = opq((opq(f32(1i))) - (opq(r16)));
                    var r21: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r18), opq(r19)));
                    fk1 = r21;
                    var r22: f32 = opq((opq(r16)) + (opq(r18)));
                    fk2 = r22;
                    var r23: f32 = opq((opq(r18)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac000 = r23;
                    var r24: f32 = opq((opq(r21)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac100 = r24;
                    var r25: f32 = opq((opq(r22)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac200 = r25;
                    var r26: f32 = opq((opq(r18)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac010 = r26;
                    var r27: f32 = opq((opq(r21)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac110 = r27;
                    var r28: f32 = opq((opq(r22)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac210 = r28;
                } else {
                    if ((specparm > 0.875f)) {
                        var r29: f32 = f_rr_neg(fs, (*C).z0);
                        p = r29;
                        var r30: f32 = opq((opq(r29)) * (opq(r29)));
                        var r31: f32 = opq((opq(r30)) * (opq(r30)));
                        p4 = r31;
                        fk0 = r31;
                        var r32: f32 = opq((opq(f32(1i))) - (opq(r29)));
                        var r34: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r31), opq(r32)));
                        fk1 = r34;
                        var r35: f32 = opq((opq(r29)) + (opq(r31)));
                        fk2 = r35;
                        var r36: f32 = opq((opq(r31)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac000 = r36;
                        var r37: f32 = opq((opq(r34)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac100 = r37;
                        var r38: f32 = opq((opq(r35)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac200 = r38;
                        var r39: f32 = opq((opq(r31)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac010 = r39;
                        var r40: f32 = opq((opq(r34)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac110 = r40;
                        var r41: f32 = opq((opq(r35)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac210 = r41;
                    } else {
                        var r42: f32 = opq((opq(1.0f)) - (opq(fs)));
                        var r43: f32 = opq((opq(r42)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac000 = r43;
                        var r44: f32 = opq((opq(1.0f)) - (opq(fs)));
                        var r45: f32 = opq((opq(r44)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac010 = r45;
                        var r46: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac100 = r46;
                        var r47: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac110 = r47;
                    }
                }
                if ((specparm1 < 0.125f)) {
                    var r48: f32 = opq((opq(fs1)) - (opq(f32(1i))));
                    p = r48;
                    var r49: f32 = opq((opq(r48)) * (opq(r48)));
                    var r50: f32 = opq((opq(r49)) * (opq(r49)));
                    p4 = r50;
                    fk0 = r50;
                    var r51: f32 = opq((opq(f32(1i))) - (opq(r48)));
                    var r53: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r50), opq(r51)));
                    fk1 = r53;
                    var r54: f32 = opq((opq(r48)) + (opq(r50)));
                    fk2 = r54;
                    var r55: f32 = opq((opq(r50)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac001 = r55;
                    var r56: f32 = opq((opq(r53)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac101 = r56;
                    var r57: f32 = opq((opq(r54)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac201 = r57;
                    var r58: f32 = opq((opq(r50)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac011 = r58;
                    var r59: f32 = opq((opq(r53)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac111 = r59;
                    var r60: f32 = opq((opq(r54)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac211 = r60;
                } else {
                    if ((specparm1 > 0.875f)) {
                        var r61: f32 = f_rr_neg(fs1, (*C).z0);
                        p = r61;
                        var r62: f32 = opq((opq(r61)) * (opq(r61)));
                        var r63: f32 = opq((opq(r62)) * (opq(r62)));
                        p4 = r63;
                        fk0 = r63;
                        var r64: f32 = opq((opq(f32(1i))) - (opq(r61)));
                        var r66: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r63), opq(r64)));
                        fk1 = r66;
                        var r67: f32 = opq((opq(r61)) + (opq(r63)));
                        fk2 = r67;
                        var r68: f32 = opq((opq(r63)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac001 = r68;
                        var r69: f32 = opq((opq(r66)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac101 = r69;
                        var r70: f32 = opq((opq(r67)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac201 = r70;
                        var r71: f32 = opq((opq(r63)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac011 = r71;
                        var r72: f32 = opq((opq(r66)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac111 = r72;
                        var r73: f32 = opq((opq(r67)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac211 = r73;
                    } else {
                        var r74: f32 = opq((opq(1.0f)) - (opq(fs1)));
                        var r75: f32 = opq((opq(r74)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac001 = r75;
                        var r76: f32 = opq((opq(1.0f)) - (opq(fs1)));
                        var r77: f32 = opq((opq(r76)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac011 = r77;
                        var r78: f32 = opq((opq(fs1)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac101 = r78;
                        var r79: f32 = opq((opq(fs1)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac111 = r79;
                    }
                }
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 8i))) { break; }
                            var r80: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((135409i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((135409i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r82: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r80), bitcast<f32>(mem_ld((T + bitcast<u32>(((135409i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r83: f32 = opq((bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i)))))) * (opq(r82)));
                            tauself = r83;
                            var r84: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((135489i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((135489i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r86: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r84), bitcast<f32>(mem_ld((T + bitcast<u32>(((135489i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r87: f32 = opq((bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i)))))) * (opq(r86)));
                            taufor = r87;
                            if ((specparm < 0.125f)) {
                                var r89: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                var r90: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r89)));
                                var r92: f32 = opq(fma(opq(fac200), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind0 + 2i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r90)));
                                var r94: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r92)));
                                var r96: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r94)));
                                var r98: f32 = opq(fma(opq(fac210), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind0 + 11i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r96)));
                                var r99: f32 = opq((opq(speccomb)) * (opq(r98)));
                                tau_major = r99;
                            } else {
                                if ((specparm > 0.875f)) {
                                    var r101: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + (ind0 - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r102: f32 = opq(fma(opq(fac200), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind0 - 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r101)));
                                    var r104: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r102)));
                                    var r106: f32 = opq(fma(opq(fac210), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind0 + 8i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r104)));
                                    var r108: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r106)));
                                    var r110: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r108)));
                                    var r111: f32 = opq((opq(speccomb)) * (opq(r110)));
                                    tau_major = r111;
                                } else {
                                    var r113: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r114: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r113)));
                                    var r116: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r114)));
                                    var r118: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r116)));
                                    var r119: f32 = opq((opq(speccomb)) * (opq(r118)));
                                    tau_major = r119;
                                }
                            }
                            if ((specparm1 < 0.125f)) {
                                var r121: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                var r122: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r121)));
                                var r124: f32 = opq(fma(opq(fac201), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind1 + 2i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r122)));
                                var r126: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r124)));
                                var r128: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r126)));
                                var r130: f32 = opq(fma(opq(fac211), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind1 + 11i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r128)));
                                var r131: f32 = opq((opq(speccomb1)) * (opq(r130)));
                                tau_major1 = r131;
                            } else {
                                if ((specparm1 > 0.875f)) {
                                    var r133: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + (ind1 - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r134: f32 = opq(fma(opq(fac201), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind1 - 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r133)));
                                    var r136: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r134)));
                                    var r138: f32 = opq(fma(opq(fac211), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind1 + 8i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r136)));
                                    var r140: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r138)));
                                    var r142: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r140)));
                                    var r143: f32 = opq((opq(speccomb1)) * (opq(r142)));
                                    tau_major1 = r143;
                                } else {
                                    var r145: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r146: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r145)));
                                    var r148: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r146)));
                                    var r150: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((130729i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r148)));
                                    var r151: f32 = opq((opq(speccomb1)) * (opq(r150)));
                                    tau_major1 = r151;
                                }
                            }
                            var r152: f32 = opq((opq(tau_major)) + (opq(tau_major1)));
                            var r153: f32 = opq((opq(r152)) + (opq(tauself)));
                            var r154: f32 = opq((opq(r153)) + (opq(taufor)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((122i + ig) - 122i) - 1i)))), bitcast<u32>(r154));
                            var r155: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((130657i + (ig - 1i)) + (((jpl + 1i) - 1i) * 8i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((130657i + (ig - 1i)) + ((jpl - 1i) * 8i))))))));
                            var r157: f32 = opq(fma(opq(fpl), opq(r155), bitcast<f32>(mem_ld((T + bitcast<u32>(((130657i + (ig - 1i)) + ((jpl - 1i) * 8i))))))));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((122i + ig) - 122i) - 1i)))), bitcast<u32>(r157));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 8i))) { break; }
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((122i + ig) - 122i) - 1i)))), bitcast<u32>(0.0f));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((122i + ig) - 122i) - 1i)))), bitcast<u32>(0.0f));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrlw_taugb13(C: ptr<function, S_RRLWColumn>, T_in: u32, taugL_in: u32, fracsL_in: u32) {
    var T: u32 = T_in;
    var taugL: u32 = taugL_in;
    var fracsL: u32 = fracsL_in;
    var absco: f32 = f32(0i);
    var absco2: f32 = f32(0i);
    var abso3: f32 = f32(0i);
    var adjcolco2: f32 = f32(0i);
    var adjfac: f32 = f32(0i);
    var chi_co2: f32 = f32(0i);
    var co2m1: f32 = f32(0i);
    var co2m2: f32 = f32(0i);
    var com1: f32 = f32(0i);
    var com2: f32 = f32(0i);
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fac200: f32 = f32(0i);
    var fac201: f32 = f32(0i);
    var fac210: f32 = f32(0i);
    var fac211: f32 = f32(0i);
    var fk0: f32 = f32(0i);
    var fk1: f32 = f32(0i);
    var fk2: f32 = f32(0i);
    var fmco: f32 = f32(0i);
    var fmco2: f32 = f32(0i);
    var fpl: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var fs1: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var indm: i32 = 0i;
    var inds: i32 = 0i;
    var jmco: i32 = 0i;
    var jmco2: i32 = 0i;
    var jpl: i32 = 0i;
    var js: i32 = 0i;
    var js1: i32 = 0i;
    var lay: i32 = 0i;
    var p: f32 = f32(0i);
    var p4: f32 = f32(0i);
    var ratco2: f32 = f32(0i);
    var refrat_m_a: f32 = f32(0i);
    var refrat_m_a3: f32 = f32(0i);
    var refrat_planck_a: f32 = f32(0i);
    var speccomb: f32 = f32(0i);
    var speccomb1: f32 = f32(0i);
    var speccomb_mco: f32 = f32(0i);
    var speccomb_mco2: f32 = f32(0i);
    var speccomb_planck: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specmult1: f32 = f32(0i);
    var specmult_mco: f32 = f32(0i);
    var specmult_mco2: f32 = f32(0i);
    var specmult_planck: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var specparm1: f32 = f32(0i);
    var specparm_mco: f32 = f32(0i);
    var specparm_mco2: f32 = f32(0i);
    var specparm_planck: f32 = f32(0i);
    var tau_major: f32 = f32(0i);
    var tau_major1: f32 = f32(0i);
    var taufor: f32 = f32(0i);
    var tauself: f32 = f32(0i);
    var r0: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((5i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((4i) - 1i)) + (7i * ((5i) - 1i))))))));
    refrat_planck_a = r0;
    var r1: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((1i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((4i) - 1i)) + (7i * ((1i) - 1i))))))));
    refrat_m_a = r1;
    var r2: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((3i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((4i) - 1i)) + (7i * ((3i) - 1i))))))));
    refrat_m_a3 = r2;
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                var r4: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_h2on2o + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb = r4;
                var r5: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r4);
                specparm = r5;
                if ((r5 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r6: f32 = opq((opq(8.0f)) * (opq(specparm)));
                specmult = r6;
                js = (1i + (i32(r6)));
                var r7: f32 = opq((r6 % 1.0f));
                fs = r7;
                var r9: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_h2on2o_1 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb1 = r9;
                var r10: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r9);
                specparm1 = r10;
                if ((r10 >= K_RR_ONEMINUS)) {
                    specparm1 = K_RR_ONEMINUS;
                }
                var r11: f32 = opq((opq(8.0f)) * (opq(specparm1)));
                specmult1 = r11;
                js1 = (1i + (i32(r11)));
                var r12: f32 = opq((r11 % 1.0f));
                fs1 = r12;
                var r14: f32 = opq(fma(opq(refrat_m_a), bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb_mco2 = r14;
                var r15: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r14);
                specparm_mco2 = r15;
                if ((r15 >= K_RR_ONEMINUS)) {
                    specparm_mco2 = K_RR_ONEMINUS;
                }
                var r16: f32 = opq((opq(8.0f)) * (opq(specparm_mco2)));
                specmult_mco2 = r16;
                jmco2 = (1i + (i32(r16)));
                var r17: f32 = opq((r16 % 1.0f));
                fmco2 = r17;
                var r18: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i))))));
                chi_co2 = r18;
                var r19: f32 = opq((opq(1e+20f)) * (opq(r18)));
                var r20: f32 = div_cr(r19, 0.000355f);
                ratco2 = r20;
                if ((r20 > 3.0f)) {
                    var r21: f32 = opq((opq(ratco2)) - (opq(2.0f)));
                    var r22: f32 = f_rr_pow_cr(r21, 0.68f);
                    var r23: f32 = opq((opq(2.0f)) + (opq(r22)));
                    adjfac = r23;
                    var r24: f32 = opq((opq(r23)) * (opq(0.000355f)));
                    var r25: f32 = opq((opq(r24)) * (bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i)))))));
                    var r26: f32 = opq((opq(r25)) * (opq(1e-20f)));
                    adjcolco2 = r26;
                } else {
                    adjcolco2 = bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i)))));
                }
                var r28: f32 = opq(fma(opq(refrat_m_a3), bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb_mco = r28;
                var r29: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r28);
                specparm_mco = r29;
                if ((r29 >= K_RR_ONEMINUS)) {
                    specparm_mco = K_RR_ONEMINUS;
                }
                var r30: f32 = opq((opq(8.0f)) * (opq(specparm_mco)));
                specmult_mco = r30;
                jmco = (1i + (i32(r30)));
                var r31: f32 = opq((r30 % 1.0f));
                fmco = r31;
                var r33: f32 = opq(fma(opq(refrat_planck_a), bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb_planck = r33;
                var r34: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r33);
                specparm_planck = r34;
                if ((r34 >= K_RR_ONEMINUS)) {
                    specparm_planck = K_RR_ONEMINUS;
                }
                var r35: f32 = opq((opq(8.0f)) * (opq(specparm_planck)));
                specmult_planck = r35;
                jpl = (1i + (i32(r35)));
                var r36: f32 = opq((r35 % 1.0f));
                fpl = r36;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((13i) - 1i)])) + js);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((13i) - 1i)])) + js1);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                indm = bitcast<i32>(mem_ld(((*C).indminor + bitcast<u32>((lay - 1i)))));
                if ((specparm < 0.125f)) {
                    var r37: f32 = opq((opq(fs)) - (opq(f32(1i))));
                    p = r37;
                    var r38: f32 = opq((opq(r37)) * (opq(r37)));
                    var r39: f32 = opq((opq(r38)) * (opq(r38)));
                    p4 = r39;
                    fk0 = r39;
                    var r40: f32 = opq((opq(f32(1i))) - (opq(r37)));
                    var r42: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r39), opq(r40)));
                    fk1 = r42;
                    var r43: f32 = opq((opq(r37)) + (opq(r39)));
                    fk2 = r43;
                    var r44: f32 = opq((opq(r39)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac000 = r44;
                    var r45: f32 = opq((opq(r42)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac100 = r45;
                    var r46: f32 = opq((opq(r43)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac200 = r46;
                    var r47: f32 = opq((opq(r39)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac010 = r47;
                    var r48: f32 = opq((opq(r42)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac110 = r48;
                    var r49: f32 = opq((opq(r43)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac210 = r49;
                } else {
                    if ((specparm > 0.875f)) {
                        var r50: f32 = f_rr_neg(fs, (*C).z0);
                        p = r50;
                        var r51: f32 = opq((opq(r50)) * (opq(r50)));
                        var r52: f32 = opq((opq(r51)) * (opq(r51)));
                        p4 = r52;
                        fk0 = r52;
                        var r53: f32 = opq((opq(f32(1i))) - (opq(r50)));
                        var r55: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r52), opq(r53)));
                        fk1 = r55;
                        var r56: f32 = opq((opq(r50)) + (opq(r52)));
                        fk2 = r56;
                        var r57: f32 = opq((opq(r52)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac000 = r57;
                        var r58: f32 = opq((opq(r55)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac100 = r58;
                        var r59: f32 = opq((opq(r56)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac200 = r59;
                        var r60: f32 = opq((opq(r52)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac010 = r60;
                        var r61: f32 = opq((opq(r55)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac110 = r61;
                        var r62: f32 = opq((opq(r56)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac210 = r62;
                    } else {
                        var r63: f32 = opq((opq(1.0f)) - (opq(fs)));
                        var r64: f32 = opq((opq(r63)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac000 = r64;
                        var r65: f32 = opq((opq(1.0f)) - (opq(fs)));
                        var r66: f32 = opq((opq(r65)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac010 = r66;
                        var r67: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac100 = r67;
                        var r68: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac110 = r68;
                    }
                }
                if ((specparm1 < 0.125f)) {
                    var r69: f32 = opq((opq(fs1)) - (opq(f32(1i))));
                    p = r69;
                    var r70: f32 = opq((opq(r69)) * (opq(r69)));
                    var r71: f32 = opq((opq(r70)) * (opq(r70)));
                    p4 = r71;
                    fk0 = r71;
                    var r72: f32 = opq((opq(f32(1i))) - (opq(r69)));
                    var r74: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r71), opq(r72)));
                    fk1 = r74;
                    var r75: f32 = opq((opq(r69)) + (opq(r71)));
                    fk2 = r75;
                    var r76: f32 = opq((opq(r71)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac001 = r76;
                    var r77: f32 = opq((opq(r74)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac101 = r77;
                    var r78: f32 = opq((opq(r75)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac201 = r78;
                    var r79: f32 = opq((opq(r71)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac011 = r79;
                    var r80: f32 = opq((opq(r74)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac111 = r80;
                    var r81: f32 = opq((opq(r75)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac211 = r81;
                } else {
                    if ((specparm1 > 0.875f)) {
                        var r82: f32 = f_rr_neg(fs1, (*C).z0);
                        p = r82;
                        var r83: f32 = opq((opq(r82)) * (opq(r82)));
                        var r84: f32 = opq((opq(r83)) * (opq(r83)));
                        p4 = r84;
                        fk0 = r84;
                        var r85: f32 = opq((opq(f32(1i))) - (opq(r82)));
                        var r87: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r84), opq(r85)));
                        fk1 = r87;
                        var r88: f32 = opq((opq(r82)) + (opq(r84)));
                        fk2 = r88;
                        var r89: f32 = opq((opq(r84)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac001 = r89;
                        var r90: f32 = opq((opq(r87)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac101 = r90;
                        var r91: f32 = opq((opq(r88)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac201 = r91;
                        var r92: f32 = opq((opq(r84)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac011 = r92;
                        var r93: f32 = opq((opq(r87)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac111 = r93;
                        var r94: f32 = opq((opq(r88)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac211 = r94;
                    } else {
                        var r95: f32 = opq((opq(1.0f)) - (opq(fs1)));
                        var r96: f32 = opq((opq(r95)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac001 = r96;
                        var r97: f32 = opq((opq(1.0f)) - (opq(fs1)));
                        var r98: f32 = opq((opq(r97)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac011 = r98;
                        var r99: f32 = opq((opq(fs1)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac101 = r99;
                        var r100: f32 = opq((opq(fs1)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac111 = r100;
                    }
                }
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 4i))) { break; }
                            var r101: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((139345i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((139345i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r103: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r101), bitcast<f32>(mem_ld((T + bitcast<u32>(((139345i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r104: f32 = opq((bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i)))))) * (opq(r103)));
                            tauself = r104;
                            var r105: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((139385i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((139385i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r107: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r105), bitcast<f32>(mem_ld((T + bitcast<u32>(((139385i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r108: f32 = opq((bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i)))))) * (opq(r107)));
                            taufor = r108;
                            var r109: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>((((137901i + ((jmco2 + 1i) - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>((((137901i + (jmco2 - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            var r111: f32 = opq(fma(opq(fmco2), opq(r109), bitcast<f32>(mem_ld((T + bitcast<u32>((((137901i + (jmco2 - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            co2m1 = r111;
                            var r112: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>((((137901i + ((jmco2 + 1i) - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>((((137901i + (jmco2 - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            var r114: f32 = opq(fma(opq(fmco2), opq(r112), bitcast<f32>(mem_ld((T + bitcast<u32>((((137901i + (jmco2 - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            co2m2 = r114;
                            var r115: f32 = opq((opq(r114)) - (opq(r111)));
                            var r117: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r115), opq(r111)));
                            absco2 = r117;
                            var r118: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>((((138585i + ((jmco + 1i) - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>((((138585i + (jmco - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            var r120: f32 = opq(fma(opq(fmco), opq(r118), bitcast<f32>(mem_ld((T + bitcast<u32>((((138585i + (jmco - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            com1 = r120;
                            var r121: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>((((138585i + ((jmco + 1i) - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>((((138585i + (jmco - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            var r123: f32 = opq(fma(opq(fmco), opq(r121), bitcast<f32>(mem_ld((T + bitcast<u32>((((138585i + (jmco - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            com2 = r123;
                            var r124: f32 = opq((opq(r123)) - (opq(r120)));
                            var r126: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r124), opq(r120)));
                            absco = r126;
                            if ((specparm < 0.125f)) {
                                var r128: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                var r129: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r128)));
                                var r131: f32 = opq(fma(opq(fac200), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind0 + 2i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r129)));
                                var r133: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r131)));
                                var r135: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r133)));
                                var r137: f32 = opq(fma(opq(fac210), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind0 + 11i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r135)));
                                var r138: f32 = opq((opq(speccomb)) * (opq(r137)));
                                tau_major = r138;
                            } else {
                                if ((specparm > 0.875f)) {
                                    var r140: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + (ind0 - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r141: f32 = opq(fma(opq(fac200), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind0 - 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r140)));
                                    var r143: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r141)));
                                    var r145: f32 = opq(fma(opq(fac210), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind0 + 8i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r143)));
                                    var r147: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r145)));
                                    var r149: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r147)));
                                    var r150: f32 = opq((opq(speccomb)) * (opq(r149)));
                                    tau_major = r150;
                                } else {
                                    var r152: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r153: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r152)));
                                    var r155: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r153)));
                                    var r157: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r155)));
                                    var r158: f32 = opq((opq(speccomb)) * (opq(r157)));
                                    tau_major = r158;
                                }
                            }
                            if ((specparm1 < 0.125f)) {
                                var r160: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                var r161: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r160)));
                                var r163: f32 = opq(fma(opq(fac201), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind1 + 2i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r161)));
                                var r165: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r163)));
                                var r167: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r165)));
                                var r169: f32 = opq(fma(opq(fac211), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind1 + 11i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r167)));
                                var r170: f32 = opq((opq(speccomb1)) * (opq(r169)));
                                tau_major1 = r170;
                            } else {
                                if ((specparm1 > 0.875f)) {
                                    var r172: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + (ind1 - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r173: f32 = opq(fma(opq(fac201), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind1 - 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r172)));
                                    var r175: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r173)));
                                    var r177: f32 = opq(fma(opq(fac211), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind1 + 8i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r175)));
                                    var r179: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r177)));
                                    var r181: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r179)));
                                    var r182: f32 = opq((opq(speccomb1)) * (opq(r181)));
                                    tau_major1 = r182;
                                } else {
                                    var r184: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r185: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r184)));
                                    var r187: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r185)));
                                    var r189: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((135561i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r187)));
                                    var r190: f32 = opq((opq(speccomb1)) * (opq(r189)));
                                    tau_major1 = r190;
                                }
                            }
                            var r191: f32 = opq((opq(tau_major)) + (opq(tau_major1)));
                            var r192: f32 = opq((opq(r191)) + (opq(tauself)));
                            var r193: f32 = opq((opq(r192)) + (opq(taufor)));
                            var r195: f32 = opq(fma(opq(adjcolco2), opq(absco2), opq(r193)));
                            var r197: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).colco + bitcast<u32>((lay - 1i))))), opq(absco), opq(r195)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((130i + ig) - 130i) - 1i)))), bitcast<u32>(r197));
                            var r198: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((135525i + (ig - 1i)) + (((jpl + 1i) - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((135525i + (ig - 1i)) + ((jpl - 1i) * 4i))))))));
                            var r200: f32 = opq(fma(opq(fpl), opq(r198), bitcast<f32>(mem_ld((T + bitcast<u32>(((135525i + (ig - 1i)) + ((jpl - 1i) * 4i))))))));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((130i + ig) - 130i) - 1i)))), bitcast<u32>(r200));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                indm = bitcast<i32>(mem_ld(((*C).indminor + bitcast<u32>((lay - 1i)))));
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 4i))) { break; }
                            var r201: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((139269i + ((indm + 1i) - 1i)) + ((ig - 1i) * 19i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((139269i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            var r203: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r201), bitcast<f32>(mem_ld((T + bitcast<u32>(((139269i + (indm - 1i)) + ((ig - 1i) * 19i))))))));
                            abso3 = r203;
                            var r204: f32 = opq((bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i)))))) * (opq(r203)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((130i + ig) - 130i) - 1i)))), bitcast<u32>(r204));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((130i + ig) - 130i) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((135521i + (ig - 1i))))))));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrlw_taugb14(C: ptr<function, S_RRLWColumn>, T_in: u32, taugL_in: u32, fracsL_in: u32) {
    var T: u32 = T_in;
    var taugL: u32 = taugL_in;
    var fracsL: u32 = fracsL_in;
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var lay: i32 = 0i;
    var taufor: f32 = f32(0i);
    var tauself: f32 = f32(0i);
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((14i) - 1i)])) + 1i);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((14i) - 1i)])) + 1i);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 2i))) { break; }
                            var r0: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((140005i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((140005i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r2: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r0), bitcast<f32>(mem_ld((T + bitcast<u32>(((140005i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r4: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((140025i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((140025i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r6: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r4), bitcast<f32>(mem_ld((T + bitcast<u32>(((140025i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r9: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((139405i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 65i))))))));
                            var r10: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((139405i + (ind0 - 1i)) + ((ig - 1i) * 65i)))))), opq(r9)));
                            var r12: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((139405i + (ind1 - 1i)) + ((ig - 1i) * 65i)))))), opq(r10)));
                            var r14: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((139405i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 65i)))))), opq(r12)));
                            var r15: f32 = opq((bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i)))))) * (opq(r14)));
                            var r16: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i))))), opq(r2), opq(r15)));
                            var r17: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i))))), opq(r6), opq(r16)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((134i + ig) - 134i) - 1i)))), bitcast<u32>(r17));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((134i + ig) - 134i) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((139401i + (ig - 1i))))))));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((14i) - 1i)])) + 1i);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((14i) - 1i)])) + 1i);
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 2i))) { break; }
                            var r19: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((139535i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 235i))))))));
                            var r20: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((139535i + (ind0 - 1i)) + ((ig - 1i) * 235i)))))), opq(r19)));
                            var r22: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((139535i + (ind1 - 1i)) + ((ig - 1i) * 235i)))))), opq(r20)));
                            var r24: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((139535i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 235i)))))), opq(r22)));
                            var r25: f32 = opq((bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i)))))) * (opq(r24)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((134i + ig) - 134i) - 1i)))), bitcast<u32>(r25));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((134i + ig) - 134i) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((139403i + (ig - 1i))))))));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrlw_taugb15(C: ptr<function, S_RRLWColumn>, T_in: u32, taugL_in: u32, fracsL_in: u32) {
    var T: u32 = T_in;
    var taugL: u32 = taugL_in;
    var fracsL: u32 = fracsL_in;
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fac200: f32 = f32(0i);
    var fac201: f32 = f32(0i);
    var fac210: f32 = f32(0i);
    var fac211: f32 = f32(0i);
    var fk0: f32 = f32(0i);
    var fk1: f32 = f32(0i);
    var fk2: f32 = f32(0i);
    var fmn2: f32 = f32(0i);
    var fpl: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var fs1: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var indm: i32 = 0i;
    var inds: i32 = 0i;
    var jmn2: i32 = 0i;
    var jpl: i32 = 0i;
    var js: i32 = 0i;
    var js1: i32 = 0i;
    var lay: i32 = 0i;
    var n2m1: f32 = f32(0i);
    var n2m2: f32 = f32(0i);
    var p: f32 = f32(0i);
    var p4: f32 = f32(0i);
    var refrat_m_a: f32 = f32(0i);
    var refrat_planck_a: f32 = f32(0i);
    var scalen2: f32 = f32(0i);
    var speccomb: f32 = f32(0i);
    var speccomb1: f32 = f32(0i);
    var speccomb_mn2: f32 = f32(0i);
    var speccomb_planck: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specmult1: f32 = f32(0i);
    var specmult_mn2: f32 = f32(0i);
    var specmult_planck: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var specparm1: f32 = f32(0i);
    var specparm_mn2: f32 = f32(0i);
    var specparm_planck: f32 = f32(0i);
    var tau_major: f32 = f32(0i);
    var tau_major1: f32 = f32(0i);
    var taufor: f32 = f32(0i);
    var taun2: f32 = f32(0i);
    var tauself: f32 = f32(0i);
    var r0: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((4i) - 1i)) + (7i * ((1i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * ((1i) - 1i))))))));
    refrat_planck_a = r0;
    var r1: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((4i) - 1i)) + (7i * ((1i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * ((1i) - 1i))))))));
    refrat_m_a = r1;
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                var r3: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_n2oco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i)))))));
                speccomb = r3;
                var r4: f32 = div_cr(bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i))))), r3);
                specparm = r4;
                if ((r4 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r5: f32 = opq((opq(8.0f)) * (opq(specparm)));
                specmult = r5;
                js = (1i + (i32(r5)));
                var r6: f32 = opq((r5 % 1.0f));
                fs = r6;
                var r8: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_n2oco2_1 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i)))))));
                speccomb1 = r8;
                var r9: f32 = div_cr(bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i))))), r8);
                specparm1 = r9;
                if ((r9 >= K_RR_ONEMINUS)) {
                    specparm1 = K_RR_ONEMINUS;
                }
                var r10: f32 = opq((opq(8.0f)) * (opq(specparm1)));
                specmult1 = r10;
                js1 = (1i + (i32(r10)));
                var r11: f32 = opq((r10 % 1.0f));
                fs1 = r11;
                var r13: f32 = opq(fma(opq(refrat_m_a), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i)))))));
                speccomb_mn2 = r13;
                var r14: f32 = div_cr(bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i))))), r13);
                specparm_mn2 = r14;
                if ((r14 >= K_RR_ONEMINUS)) {
                    specparm_mn2 = K_RR_ONEMINUS;
                }
                var r15: f32 = opq((opq(8.0f)) * (opq(specparm_mn2)));
                specmult_mn2 = r15;
                jmn2 = (1i + (i32(r15)));
                var r16: f32 = opq((r15 % 1.0f));
                fmn2 = r16;
                var r18: f32 = opq(fma(opq(refrat_planck_a), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i)))))));
                speccomb_planck = r18;
                var r19: f32 = div_cr(bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i))))), r18);
                specparm_planck = r19;
                if ((r19 >= K_RR_ONEMINUS)) {
                    specparm_planck = K_RR_ONEMINUS;
                }
                var r20: f32 = opq((opq(8.0f)) * (opq(specparm_planck)));
                specmult_planck = r20;
                jpl = (1i + (i32(r20)));
                var r21: f32 = opq((r20 % 1.0f));
                fpl = r21;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((15i) - 1i)])) + js);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((15i) - 1i)])) + js1);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                indm = bitcast<i32>(mem_ld(((*C).indminor + bitcast<u32>((lay - 1i)))));
                var r22: f32 = opq((bitcast<f32>(mem_ld(((*C).colbrd + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld(((*C).scaleminor + bitcast<u32>((lay - 1i)))))));
                scalen2 = r22;
                if ((specparm < 0.125f)) {
                    var r23: f32 = opq((opq(fs)) - (opq(f32(1i))));
                    p = r23;
                    var r24: f32 = opq((opq(r23)) * (opq(r23)));
                    var r25: f32 = opq((opq(r24)) * (opq(r24)));
                    p4 = r25;
                    fk0 = r25;
                    var r26: f32 = opq((opq(f32(1i))) - (opq(r23)));
                    var r28: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r25), opq(r26)));
                    fk1 = r28;
                    var r29: f32 = opq((opq(r23)) + (opq(r25)));
                    fk2 = r29;
                    var r30: f32 = opq((opq(r25)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac000 = r30;
                    var r31: f32 = opq((opq(r28)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac100 = r31;
                    var r32: f32 = opq((opq(r29)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac200 = r32;
                    var r33: f32 = opq((opq(r25)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac010 = r33;
                    var r34: f32 = opq((opq(r28)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac110 = r34;
                    var r35: f32 = opq((opq(r29)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac210 = r35;
                } else {
                    if ((specparm > 0.875f)) {
                        var r36: f32 = f_rr_neg(fs, (*C).z0);
                        p = r36;
                        var r37: f32 = opq((opq(r36)) * (opq(r36)));
                        var r38: f32 = opq((opq(r37)) * (opq(r37)));
                        p4 = r38;
                        fk0 = r38;
                        var r39: f32 = opq((opq(f32(1i))) - (opq(r36)));
                        var r41: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r38), opq(r39)));
                        fk1 = r41;
                        var r42: f32 = opq((opq(r36)) + (opq(r38)));
                        fk2 = r42;
                        var r43: f32 = opq((opq(r38)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac000 = r43;
                        var r44: f32 = opq((opq(r41)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac100 = r44;
                        var r45: f32 = opq((opq(r42)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac200 = r45;
                        var r46: f32 = opq((opq(r38)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac010 = r46;
                        var r47: f32 = opq((opq(r41)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac110 = r47;
                        var r48: f32 = opq((opq(r42)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac210 = r48;
                    } else {
                        var r49: f32 = opq((opq(1.0f)) - (opq(fs)));
                        var r50: f32 = opq((opq(r49)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac000 = r50;
                        var r51: f32 = opq((opq(1.0f)) - (opq(fs)));
                        var r52: f32 = opq((opq(r51)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac010 = r52;
                        var r53: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac100 = r53;
                        var r54: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac110 = r54;
                    }
                }
                if ((specparm1 < 0.125f)) {
                    var r55: f32 = opq((opq(fs1)) - (opq(f32(1i))));
                    p = r55;
                    var r56: f32 = opq((opq(r55)) * (opq(r55)));
                    var r57: f32 = opq((opq(r56)) * (opq(r56)));
                    p4 = r57;
                    fk0 = r57;
                    var r58: f32 = opq((opq(f32(1i))) - (opq(r55)));
                    var r60: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r57), opq(r58)));
                    fk1 = r60;
                    var r61: f32 = opq((opq(r55)) + (opq(r57)));
                    fk2 = r61;
                    var r62: f32 = opq((opq(r57)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac001 = r62;
                    var r63: f32 = opq((opq(r60)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac101 = r63;
                    var r64: f32 = opq((opq(r61)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac201 = r64;
                    var r65: f32 = opq((opq(r57)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac011 = r65;
                    var r66: f32 = opq((opq(r60)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac111 = r66;
                    var r67: f32 = opq((opq(r61)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac211 = r67;
                } else {
                    if ((specparm1 > 0.875f)) {
                        var r68: f32 = f_rr_neg(fs1, (*C).z0);
                        p = r68;
                        var r69: f32 = opq((opq(r68)) * (opq(r68)));
                        var r70: f32 = opq((opq(r69)) * (opq(r69)));
                        p4 = r70;
                        fk0 = r70;
                        var r71: f32 = opq((opq(f32(1i))) - (opq(r68)));
                        var r73: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r70), opq(r71)));
                        fk1 = r73;
                        var r74: f32 = opq((opq(r68)) + (opq(r70)));
                        fk2 = r74;
                        var r75: f32 = opq((opq(r70)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac001 = r75;
                        var r76: f32 = opq((opq(r73)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac101 = r76;
                        var r77: f32 = opq((opq(r74)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac201 = r77;
                        var r78: f32 = opq((opq(r70)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac011 = r78;
                        var r79: f32 = opq((opq(r73)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac111 = r79;
                        var r80: f32 = opq((opq(r74)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac211 = r80;
                    } else {
                        var r81: f32 = opq((opq(1.0f)) - (opq(fs1)));
                        var r82: f32 = opq((opq(r81)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac001 = r82;
                        var r83: f32 = opq((opq(1.0f)) - (opq(fs1)));
                        var r84: f32 = opq((opq(r83)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac011 = r84;
                        var r85: f32 = opq((opq(fs1)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac101 = r85;
                        var r86: f32 = opq((opq(fs1)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac111 = r86;
                    }
                }
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 2i))) { break; }
                            var r87: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((141563i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((141563i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r89: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r87), bitcast<f32>(mem_ld((T + bitcast<u32>(((141563i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r90: f32 = opq((bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i)))))) * (opq(r89)));
                            tauself = r90;
                            var r91: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((141583i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((141583i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r93: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r91), bitcast<f32>(mem_ld((T + bitcast<u32>(((141583i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r94: f32 = opq((bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i)))))) * (opq(r93)));
                            taufor = r94;
                            var r95: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>((((141221i + ((jmn2 + 1i) - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>((((141221i + (jmn2 - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            var r97: f32 = opq(fma(opq(fmn2), opq(r95), bitcast<f32>(mem_ld((T + bitcast<u32>((((141221i + (jmn2 - 1i)) + ((indm - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            n2m1 = r97;
                            var r98: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>((((141221i + ((jmn2 + 1i) - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>((((141221i + (jmn2 - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            var r100: f32 = opq(fma(opq(fmn2), opq(r98), bitcast<f32>(mem_ld((T + bitcast<u32>((((141221i + (jmn2 - 1i)) + (((indm + 1i) - 1i) * 9i)) + ((ig - 1i) * 171i))))))));
                            n2m2 = r100;
                            var r101: f32 = opq((opq(r100)) - (opq(r97)));
                            var r103: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).minorfrac + bitcast<u32>((lay - 1i))))), opq(r101), opq(r97)));
                            var r104: f32 = opq((opq(scalen2)) * (opq(r103)));
                            taun2 = r104;
                            if ((specparm < 0.125f)) {
                                var r106: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                var r107: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r106)));
                                var r109: f32 = opq(fma(opq(fac200), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind0 + 2i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r107)));
                                var r111: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r109)));
                                var r113: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r111)));
                                var r115: f32 = opq(fma(opq(fac210), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind0 + 11i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r113)));
                                var r116: f32 = opq((opq(speccomb)) * (opq(r115)));
                                tau_major = r116;
                            } else {
                                if ((specparm > 0.875f)) {
                                    var r118: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + (ind0 - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r119: f32 = opq(fma(opq(fac200), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind0 - 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r118)));
                                    var r121: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r119)));
                                    var r123: f32 = opq(fma(opq(fac210), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind0 + 8i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r121)));
                                    var r125: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r123)));
                                    var r127: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r125)));
                                    var r128: f32 = opq((opq(speccomb)) * (opq(r127)));
                                    tau_major = r128;
                                } else {
                                    var r130: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r131: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r130)));
                                    var r133: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r131)));
                                    var r135: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r133)));
                                    var r136: f32 = opq((opq(speccomb)) * (opq(r135)));
                                    tau_major = r136;
                                }
                            }
                            if ((specparm1 < 0.125f)) {
                                var r138: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                var r139: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r138)));
                                var r141: f32 = opq(fma(opq(fac201), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind1 + 2i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r139)));
                                var r143: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r141)));
                                var r145: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r143)));
                                var r147: f32 = opq(fma(opq(fac211), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind1 + 11i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r145)));
                                var r148: f32 = opq((opq(speccomb1)) * (opq(r147)));
                                tau_major1 = r148;
                            } else {
                                if ((specparm1 > 0.875f)) {
                                    var r150: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + (ind1 - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r151: f32 = opq(fma(opq(fac201), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind1 - 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r150)));
                                    var r153: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r151)));
                                    var r155: f32 = opq(fma(opq(fac211), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind1 + 8i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r153)));
                                    var r157: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r155)));
                                    var r159: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r157)));
                                    var r160: f32 = opq((opq(speccomb1)) * (opq(r159)));
                                    tau_major1 = r160;
                                } else {
                                    var r162: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r163: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r162)));
                                    var r165: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r163)));
                                    var r167: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((140051i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r165)));
                                    var r168: f32 = opq((opq(speccomb1)) * (opq(r167)));
                                    tau_major1 = r168;
                                }
                            }
                            var r169: f32 = opq((opq(tau_major)) + (opq(tau_major1)));
                            var r170: f32 = opq((opq(r169)) + (opq(tauself)));
                            var r171: f32 = opq((opq(r170)) + (opq(taufor)));
                            var r172: f32 = opq((opq(r171)) + (opq(taun2)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((136i + ig) - 136i) - 1i)))), bitcast<u32>(r172));
                            var r173: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((140033i + (ig - 1i)) + (((jpl + 1i) - 1i) * 2i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((140033i + (ig - 1i)) + ((jpl - 1i) * 2i))))))));
                            var r175: f32 = opq(fma(opq(fpl), opq(r173), bitcast<f32>(mem_ld((T + bitcast<u32>(((140033i + (ig - 1i)) + ((jpl - 1i) * 2i))))))));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((136i + ig) - 136i) - 1i)))), bitcast<u32>(r175));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 2i))) { break; }
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((136i + ig) - 136i) - 1i)))), bitcast<u32>(0.0f));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((136i + ig) - 136i) - 1i)))), bitcast<u32>(0.0f));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrlw_taugb16(C: ptr<function, S_RRLWColumn>, T_in: u32, taugL_in: u32, fracsL_in: u32) {
    var T: u32 = T_in;
    var taugL: u32 = taugL_in;
    var fracsL: u32 = fracsL_in;
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fac200: f32 = f32(0i);
    var fac201: f32 = f32(0i);
    var fac210: f32 = f32(0i);
    var fac211: f32 = f32(0i);
    var fk0: f32 = f32(0i);
    var fk1: f32 = f32(0i);
    var fk2: f32 = f32(0i);
    var fpl: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var fs1: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var jpl: i32 = 0i;
    var js: i32 = 0i;
    var js1: i32 = 0i;
    var lay: i32 = 0i;
    var p: f32 = f32(0i);
    var p4: f32 = f32(0i);
    var refrat_planck_a: f32 = f32(0i);
    var speccomb: f32 = f32(0i);
    var speccomb1: f32 = f32(0i);
    var speccomb_planck: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specmult1: f32 = f32(0i);
    var specmult_planck: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var specparm1: f32 = f32(0i);
    var specparm_planck: f32 = f32(0i);
    var tau_major: f32 = f32(0i);
    var tau_major1: f32 = f32(0i);
    var taufor: f32 = f32(0i);
    var tauself: f32 = f32(0i);
    var r0: f32 = div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((6i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((6i) - 1i)) + (7i * ((6i) - 1i))))))));
    refrat_planck_a = r0;
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                var r2: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_h2och4 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colch4 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb = r2;
                var r3: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r2);
                specparm = r3;
                if ((r3 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r4: f32 = opq((opq(8.0f)) * (opq(specparm)));
                specmult = r4;
                js = (1i + (i32(r4)));
                var r5: f32 = opq((r4 % 1.0f));
                fs = r5;
                var r7: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).rat_h2och4_1 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colch4 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb1 = r7;
                var r8: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r7);
                specparm1 = r8;
                if ((r8 >= K_RR_ONEMINUS)) {
                    specparm1 = K_RR_ONEMINUS;
                }
                var r9: f32 = opq((opq(8.0f)) * (opq(specparm1)));
                specmult1 = r9;
                js1 = (1i + (i32(r9)));
                var r10: f32 = opq((r9 % 1.0f));
                fs1 = r10;
                var r12: f32 = opq(fma(opq(refrat_planck_a), bitcast<f32>(mem_ld(((*C).colch4 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb_planck = r12;
                var r13: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r12);
                specparm_planck = r13;
                if ((r13 >= K_RR_ONEMINUS)) {
                    specparm_planck = K_RR_ONEMINUS;
                }
                var r14: f32 = opq((opq(8.0f)) * (opq(specparm_planck)));
                specmult_planck = r14;
                jpl = (1i + (i32(r14)));
                var r15: f32 = opq((r14 % 1.0f));
                fpl = r15;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((16i) - 1i)])) + js);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPA[((16i) - 1i)])) + js1);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                if ((specparm < 0.125f)) {
                    var r16: f32 = opq((opq(fs)) - (opq(f32(1i))));
                    p = r16;
                    var r17: f32 = opq((opq(r16)) * (opq(r16)));
                    var r18: f32 = opq((opq(r17)) * (opq(r17)));
                    p4 = r18;
                    fk0 = r18;
                    var r19: f32 = opq((opq(f32(1i))) - (opq(r16)));
                    var r21: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r18), opq(r19)));
                    fk1 = r21;
                    var r22: f32 = opq((opq(r16)) + (opq(r18)));
                    fk2 = r22;
                    var r23: f32 = opq((opq(r18)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac000 = r23;
                    var r24: f32 = opq((opq(r21)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac100 = r24;
                    var r25: f32 = opq((opq(r22)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                    fac200 = r25;
                    var r26: f32 = opq((opq(r18)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac010 = r26;
                    var r27: f32 = opq((opq(r21)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac110 = r27;
                    var r28: f32 = opq((opq(r22)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                    fac210 = r28;
                } else {
                    if ((specparm > 0.875f)) {
                        var r29: f32 = f_rr_neg(fs, (*C).z0);
                        p = r29;
                        var r30: f32 = opq((opq(r29)) * (opq(r29)));
                        var r31: f32 = opq((opq(r30)) * (opq(r30)));
                        p4 = r31;
                        fk0 = r31;
                        var r32: f32 = opq((opq(f32(1i))) - (opq(r29)));
                        var r34: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r31), opq(r32)));
                        fk1 = r34;
                        var r35: f32 = opq((opq(r29)) + (opq(r31)));
                        fk2 = r35;
                        var r36: f32 = opq((opq(r31)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac000 = r36;
                        var r37: f32 = opq((opq(r34)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac100 = r37;
                        var r38: f32 = opq((opq(r35)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac200 = r38;
                        var r39: f32 = opq((opq(r31)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac010 = r39;
                        var r40: f32 = opq((opq(r34)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac110 = r40;
                        var r41: f32 = opq((opq(r35)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac210 = r41;
                    } else {
                        var r42: f32 = opq((opq(1.0f)) - (opq(fs)));
                        var r43: f32 = opq((opq(r42)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac000 = r43;
                        var r44: f32 = opq((opq(1.0f)) - (opq(fs)));
                        var r45: f32 = opq((opq(r44)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac010 = r45;
                        var r46: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                        fac100 = r46;
                        var r47: f32 = opq((opq(fs)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                        fac110 = r47;
                    }
                }
                if ((specparm1 < 0.125f)) {
                    var r48: f32 = opq((opq(fs1)) - (opq(f32(1i))));
                    p = r48;
                    var r49: f32 = opq((opq(r48)) * (opq(r48)));
                    var r50: f32 = opq((opq(r49)) * (opq(r49)));
                    p4 = r50;
                    fk0 = r50;
                    var r51: f32 = opq((opq(f32(1i))) - (opq(r48)));
                    var r53: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r50), opq(r51)));
                    fk1 = r53;
                    var r54: f32 = opq((opq(r48)) + (opq(r50)));
                    fk2 = r54;
                    var r55: f32 = opq((opq(r50)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac001 = r55;
                    var r56: f32 = opq((opq(r53)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac101 = r56;
                    var r57: f32 = opq((opq(r54)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                    fac201 = r57;
                    var r58: f32 = opq((opq(r50)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac011 = r58;
                    var r59: f32 = opq((opq(r53)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac111 = r59;
                    var r60: f32 = opq((opq(r54)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                    fac211 = r60;
                } else {
                    if ((specparm1 > 0.875f)) {
                        var r61: f32 = f_rr_neg(fs1, (*C).z0);
                        p = r61;
                        var r62: f32 = opq((opq(r61)) * (opq(r61)));
                        var r63: f32 = opq((opq(r62)) * (opq(r62)));
                        p4 = r63;
                        fk0 = r63;
                        var r64: f32 = opq((opq(f32(1i))) - (opq(r61)));
                        var r66: f32 = opq(fma(opq(f_rr_neg(2.0f, (*C).z0)), opq(r63), opq(r64)));
                        fk1 = r66;
                        var r67: f32 = opq((opq(r61)) + (opq(r63)));
                        fk2 = r67;
                        var r68: f32 = opq((opq(r63)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac001 = r68;
                        var r69: f32 = opq((opq(r66)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac101 = r69;
                        var r70: f32 = opq((opq(r67)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac201 = r70;
                        var r71: f32 = opq((opq(r63)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac011 = r71;
                        var r72: f32 = opq((opq(r66)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac111 = r72;
                        var r73: f32 = opq((opq(r67)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac211 = r73;
                    } else {
                        var r74: f32 = opq((opq(1.0f)) - (opq(fs1)));
                        var r75: f32 = opq((opq(r74)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac001 = r75;
                        var r76: f32 = opq((opq(1.0f)) - (opq(fs1)));
                        var r77: f32 = opq((opq(r76)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac011 = r77;
                        var r78: f32 = opq((opq(fs1)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                        fac101 = r78;
                        var r79: f32 = opq((opq(fs1)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                        fac111 = r79;
                    }
                }
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 2i))) { break; }
                            var r80: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((143251i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((143251i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r82: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r80), bitcast<f32>(mem_ld((T + bitcast<u32>(((143251i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r83: f32 = opq((bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i)))))) * (opq(r82)));
                            tauself = r83;
                            var r84: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((143271i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((143271i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r86: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r84), bitcast<f32>(mem_ld((T + bitcast<u32>(((143271i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r87: f32 = opq((bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i)))))) * (opq(r86)));
                            taufor = r87;
                            if ((specparm < 0.125f)) {
                                var r89: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                var r90: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r89)));
                                var r92: f32 = opq(fma(opq(fac200), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind0 + 2i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r90)));
                                var r94: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r92)));
                                var r96: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r94)));
                                var r98: f32 = opq(fma(opq(fac210), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind0 + 11i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r96)));
                                var r99: f32 = opq((opq(speccomb)) * (opq(r98)));
                                tau_major = r99;
                            } else {
                                if ((specparm > 0.875f)) {
                                    var r101: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + (ind0 - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r102: f32 = opq(fma(opq(fac200), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind0 - 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r101)));
                                    var r104: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r102)));
                                    var r106: f32 = opq(fma(opq(fac210), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind0 + 8i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r104)));
                                    var r108: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r106)));
                                    var r110: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r108)));
                                    var r111: f32 = opq((opq(speccomb)) * (opq(r110)));
                                    tau_major = r111;
                                } else {
                                    var r113: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r114: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r113)));
                                    var r116: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r114)));
                                    var r118: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r116)));
                                    var r119: f32 = opq((opq(speccomb)) * (opq(r118)));
                                    tau_major = r119;
                                }
                            }
                            if ((specparm1 < 0.125f)) {
                                var r121: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                var r122: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r121)));
                                var r124: f32 = opq(fma(opq(fac201), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind1 + 2i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r122)));
                                var r126: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r124)));
                                var r128: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r126)));
                                var r130: f32 = opq(fma(opq(fac211), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind1 + 11i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r128)));
                                var r131: f32 = opq((opq(speccomb1)) * (opq(r130)));
                                tau_major1 = r131;
                            } else {
                                if ((specparm1 > 0.875f)) {
                                    var r133: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + (ind1 - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r134: f32 = opq(fma(opq(fac201), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind1 - 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r133)));
                                    var r136: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r134)));
                                    var r138: f32 = opq(fma(opq(fac211), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind1 + 8i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r136)));
                                    var r140: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r138)));
                                    var r142: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r140)));
                                    var r143: f32 = opq((opq(speccomb1)) * (opq(r142)));
                                    tau_major1 = r143;
                                } else {
                                    var r145: f32 = opq((opq(fac101)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                                    var r146: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r145)));
                                    var r148: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r146)));
                                    var r150: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((141611i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r148)));
                                    var r151: f32 = opq((opq(speccomb1)) * (opq(r150)));
                                    tau_major1 = r151;
                                }
                            }
                            var r152: f32 = opq((opq(tau_major)) + (opq(tau_major1)));
                            var r153: f32 = opq((opq(r152)) + (opq(tauself)));
                            var r154: f32 = opq((opq(r153)) + (opq(taufor)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((138i + ig) - 138i) - 1i)))), bitcast<u32>(r154));
                            var r155: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((141593i + (ig - 1i)) + (((jpl + 1i) - 1i) * 2i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((141593i + (ig - 1i)) + ((jpl - 1i) * 2i))))))));
                            var r157: f32 = opq(fma(opq(fpl), opq(r155), bitcast<f32>(mem_ld((T + bitcast<u32>(((141593i + (ig - 1i)) + ((jpl - 1i) * 2i))))))));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((138i + ig) - 138i) - 1i)))), bitcast<u32>(r157));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((16i) - 1i)])) + 1i);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRLW_NSPB[((16i) - 1i)])) + 1i);
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 2i))) { break; }
                            var r159: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((142781i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 235i))))))));
                            var r160: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((142781i + (ind0 - 1i)) + ((ig - 1i) * 235i)))))), opq(r159)));
                            var r162: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((142781i + (ind1 - 1i)) + ((ig - 1i) * 235i)))))), opq(r160)));
                            var r164: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((142781i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 235i)))))), opq(r162)));
                            var r165: f32 = opq((bitcast<f32>(mem_ld(((*C).colch4 + bitcast<u32>((lay - 1i)))))) * (opq(r164)));
                            mem_st((taugL + bitcast<u32>((((lay - 1i) * 16i) + (((138i + ig) - 138i) - 1i)))), bitcast<u32>(r165));
                            mem_st((fracsL + bitcast<u32>((((lay - 1i) * 16i) + (((138i + ig) - 138i) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((141591i + (ig - 1i))))))));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn lam_3(gGlobal_in: i32, band_in: i32, lay_in: i32, cloudy: u32, nl: ptr<function, i32>, ciwp: u32, clwp: u32, cswp: u32, rei: u32, fail: u32, G: u32, res: u32, rel: u32) -> f32 {
    var gGlobal: i32 = gGlobal_in;
    var band: i32 = band_in;
    var lay: i32 = lay_in;
    if ((!((((mem_ld((cloudy + bitcast<u32>(((((gGlobal - 1i) * (*nl)) + (lay - 1i)) >> u32(5i)))))) >> u32(((((gGlobal - 1i) * (*nl)) + (lay - 1i)) & 31i))) & 1u) != 0u))) {
        return 0.0f;
    }
    var cw: f32 = bitcast<f32>(mem_ld((ciwp + bitcast<u32>((lay - 1i)))));
    var cl: f32 = bitcast<f32>(mem_ld((clwp + bitcast<u32>((lay - 1i)))));
    var cs: f32 = bitcast<f32>(mem_ld((cswp + bitcast<u32>((lay - 1i)))));
    var cwp: f32 = opq((opq((opq(cw)) + (opq(cl)))) + (opq(cs)));
    if ((!(cwp >= (1e-20f)))) {
        return 0.0f;
    }
    var abscoice: f32 = 0.0f;
    var abscosno: f32 = 0.0f;
    var abscoliq: f32 = 0.0f;
    if (((opq((opq(cw)) + (opq(cs)))) == 0.0f)) {
        abscoice = 0.0f;
        abscosno = 0.0f;
    } else {
        var radice: f32 = bitcast<f32>(mem_ld((rei + bitcast<u32>((lay - 1i)))));
        if (((radice < 5.0f) || (radice > (1.4e+02f)))) {
            _ = atomicAdd(&M[fail], 1u);
        }
        var factor: f32 = div_cr((opq((opq(radice)) - (opq(2.0f)))), 3.0f);
        var index: i32 = i32(factor);
        if ((index == 46i)) {
            index = 45i;
        }
        var fint: f32 = opq((opq(factor)) - (opq(f32(index))));
        abscoice = opq(fma(opq(fint), opq((bitcast<f32>(mem_ld((G + bitcast<u32>(((34298i + ((index + 1i) - 1i)) + (46i * (band - 1i)))))))) - (bitcast<f32>(mem_ld((G + bitcast<u32>(((34298i + (index - 1i)) + (46i * (band - 1i))))))))), bitcast<f32>(mem_ld((G + bitcast<u32>(((34298i + (index - 1i)) + (46i * (band - 1i)))))))));
        abscosno = 0.0f;
    }
    if ((cs > 0.0f)) {
        var radsno: f32 = bitcast<f32>(mem_ld((res + bitcast<u32>((lay - 1i)))));
        if (((radsno < 5.0f) || (radsno > (1.4e+02f)))) {
            _ = atomicAdd(&M[fail], 1u);
        }
        var factor: f32 = div_cr((opq((opq(radsno)) - (opq(2.0f)))), 3.0f);
        var index: i32 = i32(factor);
        if ((index == 46i)) {
            index = 45i;
        }
        var fint: f32 = opq((opq(factor)) - (opq(f32(index))));
        abscosno = opq(fma(opq(fint), opq((bitcast<f32>(mem_ld((G + bitcast<u32>(((34298i + ((index + 1i) - 1i)) + (46i * (band - 1i)))))))) - (bitcast<f32>(mem_ld((G + bitcast<u32>(((34298i + (index - 1i)) + (46i * (band - 1i))))))))), bitcast<f32>(mem_ld((G + bitcast<u32>(((34298i + (index - 1i)) + (46i * (band - 1i)))))))));
    }
    if ((cl == 0.0f)) {
        abscoliq = 0.0f;
    } else {
        var radliq: f32 = bitcast<f32>(mem_ld((rel + bitcast<u32>((lay - 1i)))));
        if (((radliq < 2.5f) || (radliq > (6e+01f)))) {
            _ = atomicAdd(&M[fail], 1u);
        }
        var index: i32 = i32(opq((opq(radliq)) - (opq(1.5f))));
        if ((index == 0i)) {
            index = 1i;
        }
        if ((index == 58i)) {
            index = 57i;
        }
        var fint: f32 = opq((opq((opq(radliq)) - (opq(1.5f)))) - (opq(f32(index))));
        abscoliq = opq(fma(opq(fint), opq((bitcast<f32>(mem_ld((G + bitcast<u32>(((33370i + ((index + 1i) - 1i)) + (58i * (band - 1i)))))))) - (bitcast<f32>(mem_ld((G + bitcast<u32>(((33370i + (index - 1i)) + (58i * (band - 1i))))))))), bitcast<f32>(mem_ld((G + bitcast<u32>(((33370i + (index - 1i)) + (58i * (band - 1i)))))))));
    }
    return opq(fma(opq(cs), opq(abscosno), opq(fma(opq(cw), opq(abscoice), opq((opq(cl)) * (opq(abscoliq)))))));
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    var P: S_RRLWParams = ld_RRLWParams(ARG[4]);
    var T: u32 = ARG[5];
    var G: u32 = ARG[6];
    var p8w: u32 = ARG[7];
    var p3d: u32 = ARG[8];
    var t3d: u32 = ARG[9];
    var t8w: u32 = ARG[10];
    var qv3d: u32 = ARG[11];
    var tsk: u32 = ARG[12];
    var emis: u32 = ARG[13];
    var scr: u32 = ARG[14];
    var iscr: u32 = ARG[15];
    var rthraten: u32 = ARG[16];
    var sfc: u32 = ARG[17];
    var stride: i32 = bitcast<i32>(mem_ld(ARG[18]));
    var qc3d: u32 = ARG[19];
    var qi3d: u32 = ARG[20];
    var qs3d: u32 = ARG[21];
    var cldfra3d: u32 = ARG[22];
    var effc: u32 = ARG[23];
    var effi: u32 = ARG[24];
    var effs: u32 = ARG[25];
    var xland: u32 = ARG[26];
    var fail: u32 = ARG[27];
    var dbg: u32 = ARG[28];
    var tid: u32 = gid.x;
    if (((i32(tid)) >= P.ncol)) {
        return;
    }
    var c: i32 = (P.colOffset + (i32(tid)));
    var nk: i32 = P.nk;
    var nl: i32 = P.nlayers;
    var S: u32 = (scr + bitcast<u32>(i32((tid * (u32(f_rrlw_scratch_floats(nl)))))));
    var IS: u32 = (iscr + bitcast<u32>(i32((tid * (u32(f_rrlw_scratch_ints(nl)))))));
    var o: i32 = 0i;
    var C: S_RRLWColumn = S_RRLWColumn();
    C.nlayers = nl;
    C.z0 = P.zero;
    let _t1 = lam_1(nl, S, &o);
    C.pavel = _t1;
    let _t2 = lam_1(nl, S, &o);
    C.tavel = _t2;
    let _t3 = lam_1(nl, S, &o);
    C.coldry = _t3;
    let _t4 = lam_1(nl, S, &o);
    C.colh2o = _t4;
    let _t5 = lam_1(nl, S, &o);
    C.colco2 = _t5;
    let _t6 = lam_1(nl, S, &o);
    C.colo3 = _t6;
    let _t7 = lam_1(nl, S, &o);
    C.coln2o = _t7;
    let _t8 = lam_1(nl, S, &o);
    C.colco = _t8;
    let _t9 = lam_1(nl, S, &o);
    C.colch4 = _t9;
    let _t10 = lam_1(nl, S, &o);
    C.colo2 = _t10;
    let _t11 = lam_1(nl, S, &o);
    C.colbrd = _t11;
    let _t12 = lam_1(nl, S, &o);
    C.fac00 = _t12;
    let _t13 = lam_1(nl, S, &o);
    C.fac01 = _t13;
    let _t14 = lam_1(nl, S, &o);
    C.fac10 = _t14;
    let _t15 = lam_1(nl, S, &o);
    C.fac11 = _t15;
    let _t16 = lam_1(nl, S, &o);
    C.selffac = _t16;
    let _t17 = lam_1(nl, S, &o);
    C.selffrac = _t17;
    let _t18 = lam_1(nl, S, &o);
    C.forfac = _t18;
    let _t19 = lam_1(nl, S, &o);
    C.forfrac = _t19;
    let _t20 = lam_1(nl, S, &o);
    C.minorfrac = _t20;
    let _t21 = lam_1(nl, S, &o);
    C.scaleminor = _t21;
    let _t22 = lam_1(nl, S, &o);
    C.scaleminorn2 = _t22;
    let _t23 = lam_1(nl, S, &o);
    C.rat_h2oco2 = _t23;
    let _t24 = lam_1(nl, S, &o);
    C.rat_h2oco2_1 = _t24;
    let _t25 = lam_1(nl, S, &o);
    C.rat_h2oo3 = _t25;
    let _t26 = lam_1(nl, S, &o);
    C.rat_h2oo3_1 = _t26;
    let _t27 = lam_1(nl, S, &o);
    C.rat_h2on2o = _t27;
    let _t28 = lam_1(nl, S, &o);
    C.rat_h2on2o_1 = _t28;
    let _t29 = lam_1(nl, S, &o);
    C.rat_h2och4 = _t29;
    let _t30 = lam_1(nl, S, &o);
    C.rat_h2och4_1 = _t30;
    let _t31 = lam_1(nl, S, &o);
    C.rat_n2oco2 = _t31;
    let _t32 = lam_1(nl, S, &o);
    C.rat_n2oco2_1 = _t32;
    let _t33 = lam_1(nl, S, &o);
    C.rat_o3co2 = _t33;
    let _t34 = lam_1(nl, S, &o);
    C.rat_o3co2_1 = _t34;
    let _t35 = lam_1(nl, S, &o);
    var wbrodl: u32 = _t35;
    let _t36 = lam_1(nl, S, &o);
    var h2ovmr: u32 = _t36;
    let _t37 = lam_1(nl, S, &o);
    var o3vmr: u32 = _t37;
    let _t38 = lam_1(nl, S, &o);
    var play: u32 = _t38;
    let _t39 = lam_1(nl, S, &o);
    var tlay: u32 = _t39;
    let _t40 = lam_1(nl, S, &o);
    var atrans: u32 = _t40;
    let _t41 = lam_1(nl, S, &o);
    var bbugas: u32 = _t41;
    let _t42 = lam_1(nl, S, &o);
    var htr: u32 = _t42;
    let _t43 = lam_1(nl, S, &o);
    var o3prof: u32 = _t43;
    let _t44 = lam_1(nl, S, &o);
    var qv1d: u32 = _t44;
    let _t45 = lam_1(nl, S, &o);
    var p1d: u32 = _t45;
    let _t46 = lam_1(nl, S, &o);
    var t1d: u32 = _t46;
    let _t47 = lam_1(nl, S, &o);
    var pdel: u32 = _t47;
    let _t48 = lam_1(nl, S, &o);
    var cldfrac: u32 = _t48;
    let _t49 = lam_1(nl, S, &o);
    var clwp: u32 = _t49;
    let _t50 = lam_1(nl, S, &o);
    var ciwp: u32 = _t50;
    let _t51 = lam_1(nl, S, &o);
    var cswp: u32 = _t51;
    let _t52 = lam_1(nl, S, &o);
    var rel: u32 = _t52;
    let _t53 = lam_1(nl, S, &o);
    var rei: u32 = _t53;
    let _t54 = lam_1(nl, S, &o);
    var res: u32 = _t54;
    let _t55 = lam_1(nl, S, &o);
    var atot: u32 = _t55;
    let _t56 = lam_1(nl, S, &o);
    var bbutot: u32 = _t56;
    let _t57 = lam_1((nl + 1i), S, &o);
    var plev: u32 = _t57;
    let _t58 = lam_1((nl + 1i), S, &o);
    var tlev: u32 = _t58;
    let _t59 = lam_1((nl + 1i), S, &o);
    var varint: u32 = _t59;
    let _t60 = lam_1((nl + 1i), S, &o);
    var pz: u32 = _t60;
    let _t61 = lam_1((nl + 1i), S, &o);
    var tz: u32 = _t61;
    let _t62 = lam_1((nl + 1i), S, &o);
    var totuflux: u32 = _t62;
    let _t63 = lam_1((nl + 1i), S, &o);
    var totdflux: u32 = _t63;
    let _t64 = lam_1((nl + 1i), S, &o);
    var urad: u32 = _t64;
    let _t65 = lam_1((nl + 1i), S, &o);
    var drad: u32 = _t65;
    let _t66 = lam_1((16i * nl), S, &o);
    var planklay: u32 = _t66;
    let _t67 = lam_1((16i * nl), S, &o);
    var taugL: u32 = _t67;
    let _t68 = lam_1((16i * nl), S, &o);
    var fracsL: u32 = _t68;
    let _t69 = lam_1((16i * (nl + 1i)), S, &o);
    var planklev: u32 = _t69;
    let _t70 = lam_1(16i, S, &o);
    var plankbnd: u32 = _t70;
    let _t71 = lam_1((4i * nl), S, &o);
    C.wx = _t71;
    let _t72 = lam_1((7i * nl), S, &o);
    var wkl: u32 = _t72;
    C.jp = IS;
    C.jt = (IS + bitcast<u32>(nl));
    C.jt1 = (IS + bitcast<u32>((2i * nl)));
    C.indself = (IS + bitcast<u32>((3i * nl)));
    C.indfor = (IS + bitcast<u32>((4i * nl)));
    C.indminor = (IS + bitcast<u32>((5i * nl)));
    var icldlyr: u32 = (IS + bitcast<u32>((6i * nl)));
    var cloudy: u32 = (IS + bitcast<u32>((7i * nl)));
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= nk))) { break; }
                var q: f32 = bitcast<f32>(mem_ld((qv3d + bitcast<u32>((c + (stride * (k - 1i)))))));
                q = opq(max(0.0f, q));
                mem_st((qv1d + bitcast<u32>((k - 1i))), bitcast<u32>(opq(max(q, 1e-12f))));
                mem_st((p1d + bitcast<u32>((k - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((p3d + bitcast<u32>((c + (stride * (k - 1i)))))))) * (opq(0.01f)))));
                mem_st((t1d + bitcast<u32>((k - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((t3d + bitcast<u32>((c + (stride * (k - 1i)))))))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    mem_st((plev + bitcast<u32>(((1i) - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((p8w + bitcast<u32>((c + (stride * ((1i) - 1i)))))))) * (opq(0.01f)))));
    mem_st((tlev + bitcast<u32>(((1i) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((t8w + bitcast<u32>((c + (stride * ((1i) - 1i)))))))));
    var tsfc: f32 = bitcast<f32>(mem_ld((tsk + bitcast<u32>(c))));
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= nk))) { break; }
                mem_st((play + bitcast<u32>((k - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((p1d + bitcast<u32>((k - 1i)))))));
                mem_st((plev + bitcast<u32>(((k + 1i) - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((p8w + bitcast<u32>((c + (stride * ((k + 1i) - 1i)))))))) * (opq(0.01f)))));
                mem_st((pdel + bitcast<u32>((k - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((plev + bitcast<u32>((k - 1i)))))) - (bitcast<f32>(mem_ld((plev + bitcast<u32>(((k + 1i) - 1i)))))))));
                mem_st((tlay + bitcast<u32>((k - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((t1d + bitcast<u32>((k - 1i)))))));
                mem_st((tlev + bitcast<u32>(((k + 1i) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((t8w + bitcast<u32>((c + (stride * ((k + 1i) - 1i)))))))));
                mem_st((h2ovmr + bitcast<u32>((k - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((qv1d + bitcast<u32>((k - 1i)))))) * (opq(K_RR_AMDW)))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    {
        var L: i32 = (nk + 1i);
        loop {
            if (!((L <= nl))) { break; }
                mem_st((plev + bitcast<u32>(((L + 1i) - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((plev + bitcast<u32>((L - 1i)))))) - (opq(K_RR_DELTAP)))));
                mem_st((play + bitcast<u32>((L - 1i))), bitcast<u32>(opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((plev + bitcast<u32>((L - 1i)))))) + (bitcast<f32>(mem_ld((plev + bitcast<u32>(((L + 1i) - 1i)))))))))));
            continuing {
                L = (L + 1i);
            }
        }
    }
    mem_st((plev + bitcast<u32>(((nl + 1i) - 1i))), bitcast<u32>(0.0f));
    mem_st((play + bitcast<u32>((nl - 1i))), bitcast<u32>(opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((plev + bitcast<u32>((nl - 1i)))))) + (bitcast<f32>(mem_ld((plev + bitcast<u32>(((nl + 1i) - 1i)))))))))));
    var nproflevs: i32 = 60i;
    {
        var L: i32 = 1i;
        loop {
            if (!((L <= (nl + 1i)))) { break; }
                var klev: i32 = nproflevs;
                if (((bitcast<f32>(mem_ld((G + bitcast<u32>(((33155i + nproflevs) - 1i)))))) < (bitcast<f32>(mem_ld((plev + bitcast<u32>((L - 1i)))))))) {
                    {
                        var LL: i32 = 2i;
                        loop {
                            if (!((LL <= nproflevs))) { break; }
                                if (((bitcast<f32>(mem_ld((G + bitcast<u32>(((33155i + LL) - 1i)))))) < (bitcast<f32>(mem_ld((plev + bitcast<u32>((L - 1i)))))))) {
                                    klev = (LL - 1i);
                                    break;
                                }
                            continuing {
                                LL = (LL + 1i);
                            }
                        }
                    }
                } else {
                    klev = nproflevs;
                }
                var vark: f32;
                var vark1: f32;
                var wght: f32;
                if ((klev != nproflevs)) {
                    vark = bitcast<f32>(mem_ld((G + bitcast<u32>(((33215i + klev) - 1i)))));
                    vark1 = bitcast<f32>(mem_ld((G + bitcast<u32>((33215i + klev)))));
                    wght = div_cr((opq((bitcast<f32>(mem_ld((plev + bitcast<u32>((L - 1i)))))) - (bitcast<f32>(mem_ld((G + bitcast<u32>(((33155i + klev) - 1i)))))))), (opq((bitcast<f32>(mem_ld((G + bitcast<u32>((33155i + klev)))))) - (bitcast<f32>(mem_ld((G + bitcast<u32>(((33155i + klev) - 1i)))))))));
                } else {
                    vark = bitcast<f32>(mem_ld((G + bitcast<u32>(((33215i + klev) - 1i)))));
                    vark1 = bitcast<f32>(mem_ld((G + bitcast<u32>(((33215i + klev) - 1i)))));
                    wght = 0.0f;
                }
                mem_st((varint + bitcast<u32>((L - 1i))), bitcast<u32>(opq(fma(opq(wght), (opq((opq(vark1)) - (opq(vark)))), opq(vark)))));
            continuing {
                L = (L + 1i);
            }
        }
    }
    {
        var L: i32 = (nk + 1i);
        loop {
            if (!((L <= (nl + 1i)))) { break; }
                mem_st((tlev + bitcast<u32>((L - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((varint + bitcast<u32>((L - 1i)))))) + (opq((bitcast<f32>(mem_ld((tlev + bitcast<u32>((nk - 1i)))))) - (bitcast<f32>(mem_ld((varint + bitcast<u32>((nk - 1i)))))))))));
                mem_st((tlay + bitcast<u32>(((L - 1i) - 1i))), bitcast<u32>(opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((tlev + bitcast<u32>((L - 1i)))))) + (bitcast<f32>(mem_ld((tlev + bitcast<u32>(((L - 1i) - 1i)))))))))));
            continuing {
                L = (L + 1i);
            }
        }
    }
    {
        var L: i32 = (nk + 1i);
        loop {
            if (!((L <= nl))) { break; }
                mem_st((h2ovmr + bitcast<u32>((L - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((h2ovmr + bitcast<u32>((nk - 1i)))))));
            continuing {
                L = (L + 1i);
            }
        }
    }
    {
        var K: i32 = 1i;
        loop {
            if (!((K <= nl))) { break; }
                var acc: f32 = 0.0f;
                {
                    var JJ: i32 = 1i;
                    loop {
                        if (!((JJ <= 31i))) { break; }
                            var h1: f32 = bitcast<f32>(mem_ld((G + bitcast<u32>(((33123i + JJ) - 1i)))));
                            var h2: f32 = bitcast<f32>(mem_ld((G + bitcast<u32>((33123i + JJ)))));
                            var pb1: f32 = select(opq((bitcast<f32>(mem_ld((plev + bitcast<u32>((K - 1i)))))) - (opq(h1))), 0.0f, ((opq((-(opq((bitcast<f32>(mem_ld((plev + bitcast<u32>((K - 1i)))))) - (opq(h1))))))) >= 0.0f));
                            var pb2: f32 = select(opq((bitcast<f32>(mem_ld((plev + bitcast<u32>((K - 1i)))))) - (opq(h2))), 0.0f, ((opq((-(opq((bitcast<f32>(mem_ld((plev + bitcast<u32>((K - 1i)))))) - (opq(h2))))))) >= 0.0f));
                            var pt1: f32 = select(opq((bitcast<f32>(mem_ld((plev + bitcast<u32>(((K + 1i) - 1i)))))) - (opq(h1))), 0.0f, ((opq((-(opq((bitcast<f32>(mem_ld((plev + bitcast<u32>(((K + 1i) - 1i)))))) - (opq(h1))))))) >= 0.0f));
                            var pt2: f32 = select(opq((bitcast<f32>(mem_ld((plev + bitcast<u32>(((K + 1i) - 1i)))))) - (opq(h2))), 0.0f, ((opq((-(opq((bitcast<f32>(mem_ld((plev + bitcast<u32>(((K + 1i) - 1i)))))) - (opq(h2))))))) >= 0.0f));
                            acc = opq(fma((opq((opq((opq((opq(pb2)) - (opq(pb1)))) - (opq(pt2)))) + (opq(pt1)))), bitcast<f32>(mem_ld((G + bitcast<u32>(((33092i + JJ) - 1i))))), opq(acc)));
                        continuing {
                            JJ = (JJ + 1i);
                        }
                    }
                }
                mem_st((o3prof + bitcast<u32>((K - 1i))), bitcast<u32>(div_cr(acc, (opq((bitcast<f32>(mem_ld((plev + bitcast<u32>((K - 1i)))))) - (bitcast<f32>(mem_ld((plev + bitcast<u32>(((K + 1i) - 1i)))))))))));
                mem_st((o3vmr + bitcast<u32>((K - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((o3prof + bitcast<u32>((K - 1i)))))) * (opq(K_RR_AMDO)))));
            continuing {
                K = (K + 1i);
            }
        }
    }
    var xl: f32 = bitcast<f32>(mem_ld((xland + bitcast<u32>(c))));
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= nk))) { break; }
                var cf: f32 = bitcast<f32>(mem_ld((cldfra3d + bitcast<u32>((c + (stride * (k - 1i)))))));
                var qc: f32 = opq(max(0.0f, bitcast<f32>(mem_ld((qc3d + bitcast<u32>((c + (stride * (k - 1i)))))))));
                var qi: f32 = opq(max(0.0f, bitcast<f32>(mem_ld((qi3d + bitcast<u32>((c + (stride * (k - 1i)))))))));
                var qs: f32 = opq(max(0.0f, bitcast<f32>(mem_ld((qs3d + bitcast<u32>((c + (stride * (k - 1i)))))))));
                var rc: f32 = opq(max(2.5f, opq((bitcast<f32>(mem_ld((effc + bitcast<u32>((c + (stride * (k - 1i)))))))) * (opq(1e+06f)))));
                if ((((rc <= 2.5f) && (cf > 0.0f)) && ((opq((opq(xl)) - (opq(1.5f)))) > 0.0f))) {
                    rc = 10.5f;
                } else {
                    if ((((rc <= 2.5f) && (cf > 0.0f)) && ((opq((opq(xl)) - (opq(1.5f)))) < 0.0f))) {
                        rc = 7.5f;
                    }
                }
                var ri: f32 = opq(max(5.0f, opq((bitcast<f32>(mem_ld((effi + bitcast<u32>((c + (stride * (k - 1i)))))))) * (opq(1e+06f)))));
                if (((ri <= 5.0f) && (cf > 0.0f))) {
                    var tk: f32 = bitcast<f32>(mem_ld((t3d + bitcast<u32>((c + (stride * (k - 1i)))))));
                    var idx: i32 = i32(opq((opq(tk)) - (opq(179.0f))));
                    idx = min(max(idx, 1i), 75i);
                    var corr: f32 = opq((opq(tk)) - (opq(f32(i32(tk)))));
                    ri = opq(fma(bitcast<f32>(mem_ld((G + bitcast<u32>(((33275i + idx) - 1i))))), opq((opq(1.0f)) - (opq(corr))), opq((bitcast<f32>(mem_ld((G + bitcast<u32>((33275i + idx)))))) * (opq(corr)))));
                    ri = opq(max(ri, 5.0f));
                }
                var rs: f32 = opq(max(1e+01f, opq((bitcast<f32>(mem_ld((effs + bitcast<u32>((c + (stride * (k - 1i)))))))) * (opq(1e+06f)))));
                mem_st((cldfrac + bitcast<u32>((k - 1i))), bitcast<u32>(cf));
                var gravmks: f32 = 9.81f;
                var denom: f32 = opq(max(0.01f, cf));
                var gliqwp: f32 = opq((opq(div_cr(opq((opq((opq(qc)) * (bitcast<f32>(mem_ld((pdel + bitcast<u32>((k - 1i)))))))) * (opq(1e+02f))), gravmks))) * (opq(1e+03f)));
                var gicewp: f32 = opq((opq(div_cr(opq((opq((opq(qi)) * (bitcast<f32>(mem_ld((pdel + bitcast<u32>((k - 1i)))))))) * (opq(1e+02f))), gravmks))) * (opq(1e+03f)));
                mem_st((clwp + bitcast<u32>((k - 1i))), bitcast<u32>(div_cr(gliqwp, denom)));
                mem_st((ciwp + bitcast<u32>((k - 1i))), bitcast<u32>(div_cr(gicewp, denom)));
                var smf: f32 = 1.0f;
                if ((rs > (1.3e+02f))) {
                    smf = opq((opq((div_cr(1.3e+02f, rs)))) * (opq((div_cr(1.3e+02f, rs)))));
                    rs = 1.3e+02f;
                }
                var gsnowp: f32 = opq((opq(div_cr(opq((opq((opq((opq(qs)) * (opq(smf)))) * (bitcast<f32>(mem_ld((pdel + bitcast<u32>((k - 1i)))))))) * (opq(1e+02f))), gravmks))) * (opq(1e+03f)));
                mem_st((cswp + bitcast<u32>((k - 1i))), bitcast<u32>(div_cr(gsnowp, denom)));
                mem_st((rel + bitcast<u32>((k - 1i))), bitcast<u32>(rc));
                mem_st((rei + bitcast<u32>((k - 1i))), bitcast<u32>(ri));
                mem_st((res + bitcast<u32>((k - 1i))), bitcast<u32>(rs));
            continuing {
                k = (k + 1i);
            }
        }
    }
    {
        var k: i32 = (nk + 1i);
        loop {
            if (!((k <= nl))) { break; }
                mem_st((clwp + bitcast<u32>((k - 1i))), bitcast<u32>(0.0f));
                mem_st((ciwp + bitcast<u32>((k - 1i))), bitcast<u32>(0.0f));
                mem_st((cswp + bitcast<u32>((k - 1i))), bitcast<u32>(0.0f));
                mem_st((rel + bitcast<u32>((k - 1i))), bitcast<u32>(1e+01f));
                mem_st((rei + bitcast<u32>((k - 1i))), bitcast<u32>(1e+01f));
                mem_st((res + bitcast<u32>((k - 1i))), bitcast<u32>(1e+01f));
                mem_st((cldfrac + bitcast<u32>((k - 1i))), bitcast<u32>(0.0f));
            continuing {
                k = (k + 1i);
            }
        }
    }
    {
        var sd: array<u32, 4>;
        {
            var q: i32 = 0i;
            loop {
                if (!((q < 4i))) { break; }
                    var pm: f32 = opq((bitcast<f32>(mem_ld((play + bitcast<u32>(((q + 1i) - 1i)))))) * (opq(1e+02f)));
                    (*&sd)[q] = u32(i32(opq((opq((opq(pm)) - (opq(f32(i32(pm)))))) * (opq(1e+09f)))));
                continuing {
                    q = (q + 1i);
                }
            }
        }
        {
            var i: i32 = 0i;
            loop {
                if (!((i < 150i))) { break; }
                    _ = lam_2(&sd);
                continuing {
                    i = (i + 1i);
                }
            }
        }
        {
            var w: i32 = 0i;
            loop {
                if (!((w < (f_rrlw_cloud_words(nl))))) { break; }
                    mem_st((cloudy + bitcast<u32>(w)), 0u);
                continuing {
                    w = (w + 1i);
                }
            }
        }
        {
            var sub: i32 = 1i;
            loop {
                if (!((sub <= 140i))) { break; }
                    var prev: f32 = 0.0f;
                    {
                        var lev: i32 = 1i;
                        loop {
                            if (!((lev <= nl))) { break; }
                                var cdf: f32 = lam_2(&sd);
                                var cfl: f32 = select(bitcast<f32>(mem_ld((cldfrac + bitcast<u32>((lev - 1i))))), 0.0f, ((bitcast<f32>(mem_ld((cldfrac + bitcast<u32>((lev - 1i)))))) < (1e-20f)));
                                if ((lev > 1i)) {
                                    var cfp: f32 = select(bitcast<f32>(mem_ld((cldfrac + bitcast<u32>(((lev - 1i) - 1i))))), 0.0f, ((bitcast<f32>(mem_ld((cldfrac + bitcast<u32>(((lev - 1i) - 1i)))))) < (1e-20f)));
                                    if ((prev > (opq((opq(1.0f)) - (opq(cfp)))))) {
                                        cdf = prev;
                                    } else {
                                        cdf = opq((opq(cdf)) * (opq((opq(1.0f)) - (opq(cfp)))));
                                    }
                                }
                                if ((cdf >= (opq((opq(1.0f)) - (opq(cfl)))))) {
                                    var bit: i32 = (((sub - 1i) * nl) + (lev - 1i));
                                    mem_st((cloudy + bitcast<u32>((bit >> u32(5i)))), ((mem_ld((cloudy + bitcast<u32>((bit >> u32(5i)))))) | (1u << u32((bit & 31i)))));
                                }
                                prev = cdf;
                            continuing {
                                lev = (lev + 1i);
                            }
                        }
                    }
                continuing {
                    sub = (sub + 1i);
                }
            }
        }
    }
    mem_st((pz + bitcast<u32>((0i))), bitcast<u32>(bitcast<f32>(mem_ld((plev + bitcast<u32>(((1i) - 1i)))))));
    mem_st((tz + bitcast<u32>((0i))), bitcast<u32>(bitcast<f32>(mem_ld((tlev + bitcast<u32>(((1i) - 1i)))))));
    var amttl: f32 = 0.0f;
    var wvttl: f32 = 0.0f;
    {
        var l: i32 = 1i;
        loop {
            if (!((l <= nl))) { break; }
                mem_st((C.pavel + bitcast<u32>((l - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((play + bitcast<u32>((l - 1i)))))));
                mem_st((C.tavel + bitcast<u32>((l - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((tlay + bitcast<u32>((l - 1i)))))));
                mem_st((pz + bitcast<u32>(l)), bitcast<u32>(bitcast<f32>(mem_ld((plev + bitcast<u32>(((l + 1i) - 1i)))))));
                mem_st((tz + bitcast<u32>(l)), bitcast<u32>(bitcast<f32>(mem_ld((tlev + bitcast<u32>(((l + 1i) - 1i)))))));
                mem_st((wkl + bitcast<u32>((((1i) - 1i) + (7i * (l - 1i))))), bitcast<u32>(bitcast<f32>(mem_ld((h2ovmr + bitcast<u32>((l - 1i)))))));
                mem_st((wkl + bitcast<u32>((((2i) - 1i) + (7i * (l - 1i))))), bitcast<u32>(P.co2));
                mem_st((wkl + bitcast<u32>((((3i) - 1i) + (7i * (l - 1i))))), bitcast<u32>(bitcast<f32>(mem_ld((o3vmr + bitcast<u32>((l - 1i)))))));
                mem_st((wkl + bitcast<u32>((((4i) - 1i) + (7i * (l - 1i))))), bitcast<u32>(K_RR_N2O));
                mem_st((wkl + bitcast<u32>((((5i) - 1i) + (7i * (l - 1i))))), bitcast<u32>(0.0f));
                mem_st((wkl + bitcast<u32>((((6i) - 1i) + (7i * (l - 1i))))), bitcast<u32>(K_RR_CH4));
                mem_st((wkl + bitcast<u32>((((7i) - 1i) + (7i * (l - 1i))))), bitcast<u32>(K_RR_O2));
                var amm: f32 = opq(fma((opq((opq(1.0f)) - (bitcast<f32>(mem_ld((wkl + bitcast<u32>((((1i) - 1i) + (7i * (l - 1i)))))))))), opq(K_RR_AMD), opq((bitcast<f32>(mem_ld((wkl + bitcast<u32>((((1i) - 1i) + (7i * (l - 1i)))))))) * (opq(K_RR_AMW)))));
                mem_st((C.coldry + bitcast<u32>((l - 1i))), bitcast<u32>(div_cr(opq((opq((opq((bitcast<f32>(mem_ld((pz + bitcast<u32>((l - 1i)))))) - (bitcast<f32>(mem_ld((pz + bitcast<u32>(l))))))) * (opq(1e+03f)))) * (opq(K_RR_AVOGAD))), (opq((opq((opq((opq(1e+02f)) * (opq(K_RR_GRAV)))) * (opq(amm)))) * (opq((opq(1.0f)) + (bitcast<f32>(mem_ld((wkl + bitcast<u32>((((1i) - 1i) + (7i * (l - 1i)))))))))))))));
                mem_st((C.wx + bitcast<u32>((0i + (4i * (l - 1i))))), bitcast<u32>(K_RR_CCL4));
                mem_st((C.wx + bitcast<u32>((1i + (4i * (l - 1i))))), bitcast<u32>(K_RR_CFC11));
                mem_st((C.wx + bitcast<u32>((2i + (4i * (l - 1i))))), bitcast<u32>(K_RR_CFC12));
                mem_st((C.wx + bitcast<u32>((3i + (4i * (l - 1i))))), bitcast<u32>(K_RR_CFC22));
            continuing {
                l = (l + 1i);
            }
        }
    }
    {
        var l: i32 = 1i;
        loop {
            if (!((l <= nl))) { break; }
                var summol: f32 = 0.0f;
                {
                    var imol: i32 = 2i;
                    loop {
                        if (!((imol <= 7i))) { break; }
                            summol = opq((opq(summol)) + (bitcast<f32>(mem_ld((wkl + bitcast<u32>(((imol - 1i) + (7i * (l - 1i)))))))));
                        continuing {
                            imol = (imol + 1i);
                        }
                    }
                }
                mem_st((wbrodl + bitcast<u32>((l - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((C.coldry + bitcast<u32>((l - 1i)))))) * (opq((opq(1.0f)) - (opq(summol)))))));
                {
                    var imol: i32 = 1i;
                    loop {
                        if (!((imol <= 7i))) { break; }
                            mem_st((wkl + bitcast<u32>(((imol - 1i) + (7i * (l - 1i))))), bitcast<u32>(opq((bitcast<f32>(mem_ld((C.coldry + bitcast<u32>((l - 1i)))))) * (bitcast<f32>(mem_ld((wkl + bitcast<u32>(((imol - 1i) + (7i * (l - 1i)))))))))));
                        continuing {
                            imol = (imol + 1i);
                        }
                    }
                }
                amttl = opq((opq((opq(amttl)) + (bitcast<f32>(mem_ld((C.coldry + bitcast<u32>((l - 1i)))))))) + (bitcast<f32>(mem_ld((wkl + bitcast<u32>((((1i) - 1i) + (7i * (l - 1i)))))))));
                wvttl = opq((opq(wvttl)) + (bitcast<f32>(mem_ld((wkl + bitcast<u32>((((1i) - 1i) + (7i * (l - 1i)))))))));
                {
                    var ix: i32 = 1i;
                    loop {
                        if (!((ix <= 4i))) { break; }
                            mem_st((C.wx + bitcast<u32>(((ix - 1i) + (4i * (l - 1i))))), bitcast<u32>(opq((opq((bitcast<f32>(mem_ld((C.coldry + bitcast<u32>((l - 1i)))))) * (bitcast<f32>(mem_ld((C.wx + bitcast<u32>(((ix - 1i) + (4i * (l - 1i)))))))))) * (opq(1e-20f)))));
                        continuing {
                            ix = (ix + 1i);
                        }
                    }
                }
            continuing {
                l = (l + 1i);
            }
        }
    }
    var wvsh: f32 = div_cr((opq((opq(K_RR_AMW)) * (opq(wvttl)))), (opq((opq(K_RR_AMD)) * (opq(amttl)))));
    var pwvcm: f32 = div_cr(opq((opq(wvsh)) * (opq((opq(1e+03f)) * (bitcast<f32>(mem_ld((pz + bitcast<u32>((0i))))))))), (opq((opq(1e+02f)) * (opq(K_RR_GRAV)))));
    var semiss: f32 = bitcast<f32>(mem_ld((emis + bitcast<u32>(c))));
    var tbound: f32 = tsfc;
    var stpfac: f32 = div_cr(296.0f, 1013.0f);
    var indbound: i32 = i32(opq((opq(tbound)) - (opq(159.0f))));
    if ((indbound < 1i)) {
        indbound = 1i;
    } else {
        if ((indbound > 180i)) {
            indbound = 180i;
        }
    }
    var tbndfrac: f32 = opq((opq((opq(tbound)) - (opq(159.0f)))) - (opq(f32(indbound))));
    var indlev0: i32 = i32(opq((bitcast<f32>(mem_ld((tz + bitcast<u32>((0i)))))) - (opq(159.0f))));
    if ((indlev0 < 1i)) {
        indlev0 = 1i;
    } else {
        if ((indlev0 > 180i)) {
            indlev0 = 180i;
        }
    }
    var t0frac: f32 = opq((opq((bitcast<f32>(mem_ld((tz + bitcast<u32>((0i)))))) - (opq(159.0f)))) - (opq(f32(indlev0))));
    var laytrop: i32 = 0i;
    {
        var lay: i32 = 1i;
        loop {
            if (!((lay <= nl))) { break; }
                var indlay: i32 = i32(opq((bitcast<f32>(mem_ld((C.tavel + bitcast<u32>((lay - 1i)))))) - (opq(159.0f))));
                if ((indlay < 1i)) {
                    indlay = 1i;
                } else {
                    if ((indlay > 180i)) {
                        indlay = 180i;
                    }
                }
                var tlayfrac: f32 = opq((opq((bitcast<f32>(mem_ld((C.tavel + bitcast<u32>((lay - 1i)))))) - (opq(159.0f)))) - (opq(f32(indlay))));
                var indlev: i32 = i32(opq((bitcast<f32>(mem_ld((tz + bitcast<u32>(lay))))) - (opq(159.0f))));
                if ((indlev < 1i)) {
                    indlev = 1i;
                } else {
                    if ((indlev > 180i)) {
                        indlev = 180i;
                    }
                }
                var tlevfrac: f32 = opq((opq((bitcast<f32>(mem_ld((tz + bitcast<u32>(lay))))) - (opq(159.0f)))) - (opq(f32(indlev))));
                {
                    var iband: i32 = 1i;
                    loop {
                        if (!((iband <= 16i))) { break; }
                            if ((lay == 1i)) {
                                var dbdtlev: f32 = opq((bitcast<f32>(mem_ld((G + bitcast<u32>(((177i + ((indbound + 1i) - 1i)) + (181i * (iband - 1i)))))))) - (bitcast<f32>(mem_ld((G + bitcast<u32>(((177i + (indbound - 1i)) + (181i * (iband - 1i)))))))));
                                mem_st((plankbnd + bitcast<u32>((iband - 1i))), bitcast<u32>(opq((opq(semiss)) * (opq(fma(opq(tbndfrac), opq(dbdtlev), bitcast<f32>(mem_ld((G + bitcast<u32>(((177i + (indbound - 1i)) + (181i * (iband - 1i)))))))))))));
                                dbdtlev = opq((bitcast<f32>(mem_ld((G + bitcast<u32>(((177i + ((indlev0 + 1i) - 1i)) + (181i * (iband - 1i)))))))) - (bitcast<f32>(mem_ld((G + bitcast<u32>(((177i + (indlev0 - 1i)) + (181i * (iband - 1i)))))))));
                                mem_st((planklev + bitcast<u32>((((0i) * 16i) + (iband - 1i)))), bitcast<u32>(opq(fma(opq(t0frac), opq(dbdtlev), bitcast<f32>(mem_ld((G + bitcast<u32>(((177i + (indlev0 - 1i)) + (181i * (iband - 1i)))))))))));
                            }
                            var dbdtlev: f32 = opq((bitcast<f32>(mem_ld((G + bitcast<u32>(((177i + ((indlev + 1i) - 1i)) + (181i * (iband - 1i)))))))) - (bitcast<f32>(mem_ld((G + bitcast<u32>(((177i + (indlev - 1i)) + (181i * (iband - 1i)))))))));
                            var dbdtlay: f32 = opq((bitcast<f32>(mem_ld((G + bitcast<u32>(((177i + ((indlay + 1i) - 1i)) + (181i * (iband - 1i)))))))) - (bitcast<f32>(mem_ld((G + bitcast<u32>(((177i + (indlay - 1i)) + (181i * (iband - 1i)))))))));
                            mem_st((planklay + bitcast<u32>((((lay - 1i) * 16i) + (iband - 1i)))), bitcast<u32>(opq(fma(opq(tlayfrac), opq(dbdtlay), bitcast<f32>(mem_ld((G + bitcast<u32>(((177i + (indlay - 1i)) + (181i * (iband - 1i)))))))))));
                            mem_st((planklev + bitcast<u32>(((lay * 16i) + (iband - 1i)))), bitcast<u32>(opq(fma(opq(tlevfrac), opq(dbdtlev), bitcast<f32>(mem_ld((G + bitcast<u32>(((177i + (indlev - 1i)) + (181i * (iband - 1i)))))))))));
                        continuing {
                            iband = (iband + 1i);
                        }
                    }
                }
                var plog: f32 = f_rr_log_cr(bitcast<f32>(mem_ld((C.pavel + bitcast<u32>((lay - 1i))))));
                var jp: i32 = i32(opq(fma(opq((-(opq(5.0f)))), (opq((opq(plog)) + (opq(0.04f)))), opq(36.0f))));
                if ((jp < 1i)) {
                    jp = 1i;
                } else {
                    if ((jp > 58i)) {
                        jp = 58i;
                    }
                }
                mem_st((C.jp + bitcast<u32>((lay - 1i))), bitcast<u32>(jp));
                var jp1: i32 = (jp + 1i);
                var fp: f32 = opq((opq(5.0f)) * (opq((bitcast<f32>(mem_ld((G + bitcast<u32>(((59i + jp) - 1i)))))) - (opq(plog)))));
                var jt: i32 = i32(opq((opq(3.0f)) + (opq(div_cr((opq((bitcast<f32>(mem_ld((C.tavel + bitcast<u32>((lay - 1i)))))) - (bitcast<f32>(mem_ld((G + bitcast<u32>(((118i + jp) - 1i)))))))), 15.0f)))));
                if ((jt < 1i)) {
                    jt = 1i;
                } else {
                    if ((jt > 4i)) {
                        jt = 4i;
                    }
                }
                mem_st((C.jt + bitcast<u32>((lay - 1i))), bitcast<u32>(jt));
                var ft: f32 = opq((opq((div_cr((opq((bitcast<f32>(mem_ld((C.tavel + bitcast<u32>((lay - 1i)))))) - (bitcast<f32>(mem_ld((G + bitcast<u32>(((118i + jp) - 1i)))))))), 15.0f)))) - (opq(f32((jt - 3i)))));
                var jt1: i32 = i32(opq((opq(3.0f)) + (opq(div_cr((opq((bitcast<f32>(mem_ld((C.tavel + bitcast<u32>((lay - 1i)))))) - (bitcast<f32>(mem_ld((G + bitcast<u32>(((118i + jp1) - 1i)))))))), 15.0f)))));
                if ((jt1 < 1i)) {
                    jt1 = 1i;
                } else {
                    if ((jt1 > 4i)) {
                        jt1 = 4i;
                    }
                }
                mem_st((C.jt1 + bitcast<u32>((lay - 1i))), bitcast<u32>(jt1));
                var ft1: f32 = opq((opq((div_cr((opq((bitcast<f32>(mem_ld((C.tavel + bitcast<u32>((lay - 1i)))))) - (bitcast<f32>(mem_ld((G + bitcast<u32>(((118i + jp1) - 1i)))))))), 15.0f)))) - (opq(f32((jt1 - 3i)))));
                var water: f32 = div_cr(bitcast<f32>(mem_ld((wkl + bitcast<u32>((((1i) - 1i) + (7i * (lay - 1i))))))), bitcast<f32>(mem_ld((C.coldry + bitcast<u32>((lay - 1i))))));
                var scalefac: f32 = div_cr(opq((bitcast<f32>(mem_ld((C.pavel + bitcast<u32>((lay - 1i)))))) * (opq(stpfac))), bitcast<f32>(mem_ld((C.tavel + bitcast<u32>((lay - 1i))))));
                if ((plog > 4.56f)) {
                    laytrop = (laytrop + 1i);
                    mem_st((C.forfac + bitcast<u32>((lay - 1i))), bitcast<u32>(div_cr(scalefac, (opq((opq(1.0f)) + (opq(water)))))));
                    var factor: f32 = div_cr((opq((opq(332.0f)) - (bitcast<f32>(mem_ld((C.tavel + bitcast<u32>((lay - 1i)))))))), 36.0f);
                    mem_st((C.indfor + bitcast<u32>((lay - 1i))), bitcast<u32>(min(2i, max(1i, i32(factor)))));
                    mem_st((C.forfrac + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(factor)) - (opq(f32(bitcast<i32>(mem_ld((C.indfor + bitcast<u32>((lay - 1i)))))))))));
                    mem_st((C.selffac + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(water)) * (bitcast<f32>(mem_ld((C.forfac + bitcast<u32>((lay - 1i)))))))));
                    factor = div_cr((opq((bitcast<f32>(mem_ld((C.tavel + bitcast<u32>((lay - 1i)))))) - (opq(188.0f)))), 7.2f);
                    mem_st((C.indself + bitcast<u32>((lay - 1i))), bitcast<u32>(min(9i, max(1i, ((i32(factor)) - 7i)))));
                    mem_st((C.selffrac + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(factor)) - (opq(f32(((bitcast<i32>(mem_ld((C.indself + bitcast<u32>((lay - 1i)))))) + 7i)))))));
                    mem_st((C.scaleminor + bitcast<u32>((lay - 1i))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((C.pavel + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((C.tavel + bitcast<u32>((lay - 1i))))))));
                    mem_st((C.scaleminorn2 + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq((div_cr(bitcast<f32>(mem_ld((C.pavel + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((C.tavel + bitcast<u32>((lay - 1i))))))))) * (opq((div_cr(bitcast<f32>(mem_ld((wbrodl + bitcast<u32>((lay - 1i))))), (opq((bitcast<f32>(mem_ld((C.coldry + bitcast<u32>((lay - 1i)))))) + (bitcast<f32>(mem_ld((wkl + bitcast<u32>((((1i) - 1i) + (7i * (lay - 1i)))))))))))))))));
                    factor = div_cr((opq((bitcast<f32>(mem_ld((C.tavel + bitcast<u32>((lay - 1i)))))) - (opq(180.8f)))), 7.2f);
                    mem_st((C.indminor + bitcast<u32>((lay - 1i))), bitcast<u32>(min(18i, max(1i, i32(factor)))));
                    mem_st((C.minorfrac + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(factor)) - (opq(f32(bitcast<i32>(mem_ld((C.indminor + bitcast<u32>((lay - 1i)))))))))));
                    mem_st((C.rat_h2oco2 + bitcast<u32>((lay - 1i))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * (jp - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * (jp - 1i))))))))));
                    mem_st((C.rat_h2oco2_1 + bitcast<u32>((lay - 1i))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((jp + 1i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * ((jp + 1i) - 1i))))))))));
                    mem_st((C.rat_h2oo3 + bitcast<u32>((lay - 1i))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * (jp - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((3i) - 1i)) + (7i * (jp - 1i))))))))));
                    mem_st((C.rat_h2oo3_1 + bitcast<u32>((lay - 1i))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((jp + 1i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((3i) - 1i)) + (7i * ((jp + 1i) - 1i))))))))));
                    mem_st((C.rat_h2on2o + bitcast<u32>((lay - 1i))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * (jp - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((4i) - 1i)) + (7i * (jp - 1i))))))))));
                    mem_st((C.rat_h2on2o_1 + bitcast<u32>((lay - 1i))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((jp + 1i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((4i) - 1i)) + (7i * ((jp + 1i) - 1i))))))))));
                    mem_st((C.rat_h2och4 + bitcast<u32>((lay - 1i))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * (jp - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((6i) - 1i)) + (7i * (jp - 1i))))))))));
                    mem_st((C.rat_h2och4_1 + bitcast<u32>((lay - 1i))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((jp + 1i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((6i) - 1i)) + (7i * ((jp + 1i) - 1i))))))))));
                    mem_st((C.rat_n2oco2 + bitcast<u32>((lay - 1i))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((4i) - 1i)) + (7i * (jp - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * (jp - 1i))))))))));
                    mem_st((C.rat_n2oco2_1 + bitcast<u32>((lay - 1i))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((4i) - 1i)) + (7i * ((jp + 1i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * ((jp + 1i) - 1i))))))))));
                } else {
                    mem_st((C.forfac + bitcast<u32>((lay - 1i))), bitcast<u32>(div_cr(scalefac, (opq((opq(1.0f)) + (opq(water)))))));
                    var factor: f32 = div_cr((opq((bitcast<f32>(mem_ld((C.tavel + bitcast<u32>((lay - 1i)))))) - (opq(188.0f)))), 36.0f);
                    mem_st((C.indfor + bitcast<u32>((lay - 1i))), bitcast<u32>(3i));
                    mem_st((C.forfrac + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(factor)) - (opq(1.0f)))));
                    mem_st((C.selffac + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(water)) * (bitcast<f32>(mem_ld((C.forfac + bitcast<u32>((lay - 1i)))))))));
                    mem_st((C.scaleminor + bitcast<u32>((lay - 1i))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((C.pavel + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((C.tavel + bitcast<u32>((lay - 1i))))))));
                    mem_st((C.scaleminorn2 + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq((div_cr(bitcast<f32>(mem_ld((C.pavel + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((C.tavel + bitcast<u32>((lay - 1i))))))))) * (opq((div_cr(bitcast<f32>(mem_ld((wbrodl + bitcast<u32>((lay - 1i))))), (opq((bitcast<f32>(mem_ld((C.coldry + bitcast<u32>((lay - 1i)))))) + (bitcast<f32>(mem_ld((wkl + bitcast<u32>((((1i) - 1i) + (7i * (lay - 1i)))))))))))))))));
                    factor = div_cr((opq((bitcast<f32>(mem_ld((C.tavel + bitcast<u32>((lay - 1i)))))) - (opq(180.8f)))), 7.2f);
                    mem_st((C.indminor + bitcast<u32>((lay - 1i))), bitcast<u32>(min(18i, max(1i, i32(factor)))));
                    mem_st((C.minorfrac + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(factor)) - (opq(f32(bitcast<i32>(mem_ld((C.indminor + bitcast<u32>((lay - 1i)))))))))));
                    mem_st((C.rat_h2oco2 + bitcast<u32>((lay - 1i))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * (jp - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * (jp - 1i))))))))));
                    mem_st((C.rat_h2oco2_1 + bitcast<u32>((lay - 1i))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((1i) - 1i)) + (7i * ((jp + 1i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * ((jp + 1i) - 1i))))))))));
                    mem_st((C.rat_o3co2 + bitcast<u32>((lay - 1i))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((3i) - 1i)) + (7i * (jp - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * (jp - 1i))))))))));
                    mem_st((C.rat_o3co2_1 + bitcast<u32>((lay - 1i))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((3i) - 1i)) + (7i * ((jp + 1i) - 1i))))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((0i + ((2i) - 1i)) + (7i * ((jp + 1i) - 1i))))))))));
                }
                mem_st((C.colh2o + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(1e-20f)) * (bitcast<f32>(mem_ld((wkl + bitcast<u32>((((1i) - 1i) + (7i * (lay - 1i)))))))))));
                mem_st((C.colco2 + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(1e-20f)) * (bitcast<f32>(mem_ld((wkl + bitcast<u32>((((2i) - 1i) + (7i * (lay - 1i)))))))))));
                mem_st((C.colo3 + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(1e-20f)) * (bitcast<f32>(mem_ld((wkl + bitcast<u32>((((3i) - 1i) + (7i * (lay - 1i)))))))))));
                mem_st((C.coln2o + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(1e-20f)) * (bitcast<f32>(mem_ld((wkl + bitcast<u32>((((4i) - 1i) + (7i * (lay - 1i)))))))))));
                mem_st((C.colco + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(1e-20f)) * (bitcast<f32>(mem_ld((wkl + bitcast<u32>((((5i) - 1i) + (7i * (lay - 1i)))))))))));
                mem_st((C.colch4 + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(1e-20f)) * (bitcast<f32>(mem_ld((wkl + bitcast<u32>((((6i) - 1i) + (7i * (lay - 1i)))))))))));
                mem_st((C.colo2 + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(1e-20f)) * (bitcast<f32>(mem_ld((wkl + bitcast<u32>((((7i) - 1i) + (7i * (lay - 1i)))))))))));
                if (((bitcast<f32>(mem_ld((C.colco2 + bitcast<u32>((lay - 1i)))))) == 0.0f)) {
                    mem_st((C.colco2 + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(1e-32f)) * (bitcast<f32>(mem_ld((C.coldry + bitcast<u32>((lay - 1i)))))))));
                }
                if (((bitcast<f32>(mem_ld((C.colo3 + bitcast<u32>((lay - 1i)))))) == 0.0f)) {
                    mem_st((C.colo3 + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(1e-32f)) * (bitcast<f32>(mem_ld((C.coldry + bitcast<u32>((lay - 1i)))))))));
                }
                if (((bitcast<f32>(mem_ld((C.coln2o + bitcast<u32>((lay - 1i)))))) == 0.0f)) {
                    mem_st((C.coln2o + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(1e-32f)) * (bitcast<f32>(mem_ld((C.coldry + bitcast<u32>((lay - 1i)))))))));
                }
                if (((bitcast<f32>(mem_ld((C.colco + bitcast<u32>((lay - 1i)))))) == 0.0f)) {
                    mem_st((C.colco + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(1e-32f)) * (bitcast<f32>(mem_ld((C.coldry + bitcast<u32>((lay - 1i)))))))));
                }
                if (((bitcast<f32>(mem_ld((C.colch4 + bitcast<u32>((lay - 1i)))))) == 0.0f)) {
                    mem_st((C.colch4 + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(1e-32f)) * (bitcast<f32>(mem_ld((C.coldry + bitcast<u32>((lay - 1i)))))))));
                }
                mem_st((C.colbrd + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(1e-20f)) * (bitcast<f32>(mem_ld((wbrodl + bitcast<u32>((lay - 1i)))))))));
                var compfp: f32 = opq((opq(1.0f)) - (opq(fp)));
                mem_st((C.fac10 + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(compfp)) * (opq(ft)))));
                mem_st((C.fac00 + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(compfp)) * (opq((opq(1.0f)) - (opq(ft)))))));
                mem_st((C.fac11 + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(fp)) * (opq(ft1)))));
                mem_st((C.fac01 + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((opq(fp)) * (opq((opq(1.0f)) - (opq(ft1)))))));
                mem_st((C.selffac + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((C.colh2o + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((C.selffac + bitcast<u32>((lay - 1i)))))))));
                mem_st((C.forfac + bitcast<u32>((lay - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((C.colh2o + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((C.forfac + bitcast<u32>((lay - 1i)))))))));
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    C.laytrop = laytrop;
    var D: bool = (c == P.debugCol);
    var dTau: i32 = (((((2i + (14i * nl)) + (2i * (nl + 1i))) + (16i * nl)) + (16i * (nl + 1i))) + 16i);
    if (D) {
        var q: i32 = 0i;
        let _t73 = q;
        q = (q + 1i);
        let _t74 = _t73;
        mem_st((dbg + bitcast<u32>(_t74)), bitcast<u32>(f32(laytrop)));
        let _t75 = q;
        q = (q + 1i);
        let _t76 = _t75;
        mem_st((dbg + bitcast<u32>(_t76)), bitcast<u32>(pwvcm));
        {
            var l: i32 = 1i;
            loop {
                if (!((l <= nl))) { break; }
                    let _t77 = q;
                    q = (q + 1i);
                    let _t78 = _t77;
                    mem_st((dbg + bitcast<u32>(_t78)), bitcast<u32>(bitcast<f32>(mem_ld((C.pavel + bitcast<u32>((l - 1i)))))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 1i;
            loop {
                if (!((l <= nl))) { break; }
                    let _t79 = q;
                    q = (q + 1i);
                    let _t80 = _t79;
                    mem_st((dbg + bitcast<u32>(_t80)), bitcast<u32>(bitcast<f32>(mem_ld((C.tavel + bitcast<u32>((l - 1i)))))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 0i;
            loop {
                if (!((l <= nl))) { break; }
                    let _t81 = q;
                    q = (q + 1i);
                    let _t82 = _t81;
                    mem_st((dbg + bitcast<u32>(_t82)), bitcast<u32>(bitcast<f32>(mem_ld((pz + bitcast<u32>(l))))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 0i;
            loop {
                if (!((l <= nl))) { break; }
                    let _t83 = q;
                    q = (q + 1i);
                    let _t84 = _t83;
                    mem_st((dbg + bitcast<u32>(_t84)), bitcast<u32>(bitcast<f32>(mem_ld((tz + bitcast<u32>(l))))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 1i;
            loop {
                if (!((l <= nl))) { break; }
                    let _t85 = q;
                    q = (q + 1i);
                    let _t86 = _t85;
                    mem_st((dbg + bitcast<u32>(_t86)), bitcast<u32>(bitcast<f32>(mem_ld((C.coldry + bitcast<u32>((l - 1i)))))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 1i;
            loop {
                if (!((l <= nl))) { break; }
                    let _t87 = q;
                    q = (q + 1i);
                    let _t88 = _t87;
                    mem_st((dbg + bitcast<u32>(_t88)), bitcast<u32>(f32(bitcast<i32>(mem_ld((C.jp + bitcast<u32>((l - 1i))))))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 1i;
            loop {
                if (!((l <= nl))) { break; }
                    let _t89 = q;
                    q = (q + 1i);
                    let _t90 = _t89;
                    mem_st((dbg + bitcast<u32>(_t90)), bitcast<u32>(f32(bitcast<i32>(mem_ld((C.jt + bitcast<u32>((l - 1i))))))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 1i;
            loop {
                if (!((l <= nl))) { break; }
                    let _t91 = q;
                    q = (q + 1i);
                    let _t92 = _t91;
                    mem_st((dbg + bitcast<u32>(_t92)), bitcast<u32>(f32(bitcast<i32>(mem_ld((C.jt1 + bitcast<u32>((l - 1i))))))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 1i;
            loop {
                if (!((l <= nl))) { break; }
                    let _t93 = q;
                    q = (q + 1i);
                    let _t94 = _t93;
                    mem_st((dbg + bitcast<u32>(_t94)), bitcast<u32>(bitcast<f32>(mem_ld((C.fac00 + bitcast<u32>((l - 1i)))))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 1i;
            loop {
                if (!((l <= nl))) { break; }
                    let _t95 = q;
                    q = (q + 1i);
                    let _t96 = _t95;
                    mem_st((dbg + bitcast<u32>(_t96)), bitcast<u32>(bitcast<f32>(mem_ld((C.fac01 + bitcast<u32>((l - 1i)))))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 1i;
            loop {
                if (!((l <= nl))) { break; }
                    let _t97 = q;
                    q = (q + 1i);
                    let _t98 = _t97;
                    mem_st((dbg + bitcast<u32>(_t98)), bitcast<u32>(bitcast<f32>(mem_ld((C.fac10 + bitcast<u32>((l - 1i)))))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 1i;
            loop {
                if (!((l <= nl))) { break; }
                    let _t99 = q;
                    q = (q + 1i);
                    let _t100 = _t99;
                    mem_st((dbg + bitcast<u32>(_t100)), bitcast<u32>(bitcast<f32>(mem_ld((C.fac11 + bitcast<u32>((l - 1i)))))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 1i;
            loop {
                if (!((l <= nl))) { break; }
                    let _t101 = q;
                    q = (q + 1i);
                    let _t102 = _t101;
                    mem_st((dbg + bitcast<u32>(_t102)), bitcast<u32>(bitcast<f32>(mem_ld((C.colh2o + bitcast<u32>((l - 1i)))))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 1i;
            loop {
                if (!((l <= nl))) { break; }
                    let _t103 = q;
                    q = (q + 1i);
                    let _t104 = _t103;
                    mem_st((dbg + bitcast<u32>(_t104)), bitcast<u32>(bitcast<f32>(mem_ld((C.colo3 + bitcast<u32>((l - 1i)))))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 1i;
            loop {
                if (!((l <= nl))) { break; }
                    let _t105 = q;
                    q = (q + 1i);
                    let _t106 = _t105;
                    mem_st((dbg + bitcast<u32>(_t106)), bitcast<u32>(bitcast<f32>(mem_ld((C.selffac + bitcast<u32>((l - 1i)))))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 1i;
            loop {
                if (!((l <= nl))) { break; }
                    let _t107 = q;
                    q = (q + 1i);
                    let _t108 = _t107;
                    mem_st((dbg + bitcast<u32>(_t108)), bitcast<u32>(bitcast<f32>(mem_ld((C.forfac + bitcast<u32>((l - 1i)))))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 1i;
            loop {
                if (!((l <= nl))) { break; }
                    {
                        var b: i32 = 1i;
                        loop {
                            if (!((b <= 16i))) { break; }
                                let _t109 = q;
                                q = (q + 1i);
                                let _t110 = _t109;
                                mem_st((dbg + bitcast<u32>(_t110)), bitcast<u32>(bitcast<f32>(mem_ld((planklay + bitcast<u32>((((l - 1i) * 16i) + (b - 1i))))))));
                            continuing {
                                b = (b + 1i);
                            }
                        }
                    }
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 0i;
            loop {
                if (!((l <= nl))) { break; }
                    {
                        var b: i32 = 1i;
                        loop {
                            if (!((b <= 16i))) { break; }
                                let _t111 = q;
                                q = (q + 1i);
                                let _t112 = _t111;
                                mem_st((dbg + bitcast<u32>(_t112)), bitcast<u32>(bitcast<f32>(mem_ld((planklev + bitcast<u32>(((l * 16i) + (b - 1i))))))));
                            continuing {
                                b = (b + 1i);
                            }
                        }
                    }
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var b: i32 = 1i;
            loop {
                if (!((b <= 16i))) { break; }
                    let _t113 = q;
                    q = (q + 1i);
                    let _t114 = _t113;
                    mem_st((dbg + bitcast<u32>(_t114)), bitcast<u32>(bitcast<f32>(mem_ld((plankbnd + bitcast<u32>((b - 1i)))))));
                continuing {
                    b = (b + 1i);
                }
            }
        }
    }
    var secdiffB: array<f32, 16>;
    {
        var ib: i32 = 1i;
        loop {
            if (!((ib <= 16i))) { break; }
                if ((((ib == 1i) || (ib == 4i)) || (ib >= 10i))) {
                    (*&secdiffB)[(ib - 1i)] = 1.66f;
                } else {
                    var sd: f32 = opq(fma(opq(K_RR_A1[(ib - 1i)]), opq(f_rr_exp_cr(opq((opq(K_RR_A2[(ib - 1i)])) * (opq(pwvcm))))), opq(K_RR_A0[(ib - 1i)])));
                    if ((sd > 1.8f)) {
                        sd = 1.8f;
                    }
                    if ((sd < 1.5f)) {
                        sd = 1.5f;
                    }
                    (*&secdiffB)[(ib - 1i)] = sd;
                }
            continuing {
                ib = (ib + 1i);
            }
        }
    }
    {
        var lay: i32 = 1i;
        loop {
            if (!((lay <= nl))) { break; }
                var any_v: i32 = 0i;
                {
                    var g: i32 = 1i;
                    loop {
                        if (!(((g <= 140i) && (any_v == 0i)))) { break; }
                            if (((((mem_ld((cloudy + bitcast<u32>(((((g - 1i) * nl) + (lay - 1i)) >> u32(5i)))))) >> u32(((((g - 1i) * nl) + (lay - 1i)) & 31i))) & 1u) != 0u)) {
                                any_v = 1i;
                            }
                        continuing {
                            g = (g + 1i);
                        }
                    }
                }
                mem_st((icldlyr + bitcast<u32>((lay - 1i))), bitcast<u32>(any_v));
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        var lev: i32 = 0i;
        loop {
            if (!((lev <= nl))) { break; }
                mem_st((totuflux + bitcast<u32>(lev)), bitcast<u32>(0.0f));
                mem_st((totdflux + bitcast<u32>(lev)), bitcast<u32>(0.0f));
                mem_st((urad + bitcast<u32>(lev)), bitcast<u32>(0.0f));
                mem_st((drad + bitcast<u32>(lev)), bitcast<u32>(0.0f));
            continuing {
                lev = (lev + 1i);
            }
        }
    }
    var bpade: f32 = P.bpade;
    var tblint: f32 = 1e+04f;
    var gBase: i32 = 0i;
    {
        var iband: i32 = 1i;
        loop {
            if (!((iband <= 16i))) { break; }
                switch (iband) {
                    case 1i: {
                        f_rrlw_taugb1(&C, T, taugL, fracsL);
                    }
                    case 2i: {
                        f_rrlw_taugb2(&C, T, taugL, fracsL);
                    }
                    case 3i: {
                        f_rrlw_taugb3(&C, T, taugL, fracsL);
                    }
                    case 4i: {
                        f_rrlw_taugb4(&C, T, taugL, fracsL);
                    }
                    case 5i: {
                        f_rrlw_taugb5(&C, T, taugL, fracsL);
                    }
                    case 6i: {
                        f_rrlw_taugb6(&C, T, taugL, fracsL);
                    }
                    case 7i: {
                        f_rrlw_taugb7(&C, T, taugL, fracsL);
                    }
                    case 8i: {
                        f_rrlw_taugb8(&C, T, taugL, fracsL);
                    }
                    case 9i: {
                        f_rrlw_taugb9(&C, T, taugL, fracsL);
                    }
                    case 10i: {
                        f_rrlw_taugb10(&C, T, taugL, fracsL);
                    }
                    case 11i: {
                        f_rrlw_taugb11(&C, T, taugL, fracsL);
                    }
                    case 12i: {
                        f_rrlw_taugb12(&C, T, taugL, fracsL);
                    }
                    case 13i: {
                        f_rrlw_taugb13(&C, T, taugL, fracsL);
                    }
                    case 14i: {
                        f_rrlw_taugb14(&C, T, taugL, fracsL);
                    }
                    case 15i: {
                        f_rrlw_taugb15(&C, T, taugL, fracsL);
                    }
                    case default: {
                        f_rrlw_taugb16(&C, T, taugL, fracsL);
                    }
                }
                var secdiff: f32 = (*&secdiffB)[(iband - 1i)];
                var ngb: i32 = K_RRLW_NG[(iband - 1i)];
                if (D) {
                    {
                        var l: i32 = 1i;
                        loop {
                            if (!((l <= nl))) { break; }
                                {
                                    var g: i32 = 1i;
                                    loop {
                                        if (!((g <= ngb))) { break; }
                                            mem_st((dbg + bitcast<u32>(((dTau + ((l - 1i) * 140i)) + ((gBase + g) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((taugL + bitcast<u32>((((l - 1i) * 16i) + (g - 1i))))))));
                                            mem_st((dbg + bitcast<u32>((((dTau + (140i * nl)) + ((l - 1i) * 140i)) + ((gBase + g) - 1i)))), bitcast<u32>(bitcast<f32>(mem_ld((fracsL + bitcast<u32>((((l - 1i) * 16i) + (g - 1i))))))));
                                        continuing {
                                            g = (g + 1i);
                                        }
                                    }
                                }
                            continuing {
                                l = (l + 1i);
                            }
                        }
                    }
                }
                {
                    var g: i32 = 1i;
                    loop {
                        if (!((g <= ngb))) { break; }
                            var gg: i32 = (gBase + g);
                            var radld: f32 = 0.0f;
                            {
                                var lev: i32 = nl;
                                loop {
                                    if (!((lev >= 1i))) { break; }
                                        var plfrac: f32 = bitcast<f32>(mem_ld((fracsL + bitcast<u32>((((lev - 1i) * 16i) + (g - 1i))))));
                                        var blay: f32 = bitcast<f32>(mem_ld((planklay + bitcast<u32>((((lev - 1i) * 16i) + (iband - 1i))))));
                                        var dplankup: f32 = opq((bitcast<f32>(mem_ld((planklev + bitcast<u32>(((lev * 16i) + (iband - 1i))))))) - (opq(blay)));
                                        var dplankdn: f32 = opq((bitcast<f32>(mem_ld((planklev + bitcast<u32>((((lev - 1i) * 16i) + (iband - 1i))))))) - (opq(blay)));
                                        var odepth: f32 = opq((opq(secdiff)) * (bitcast<f32>(mem_ld((taugL + bitcast<u32>((((lev - 1i) * 16i) + (g - 1i))))))));
                                        if ((odepth < 0.0f)) {
                                            odepth = 0.0f;
                                        }
                                        if (((bitcast<i32>(mem_ld((icldlyr + bitcast<u32>((lev - 1i)))))) == 1i)) {
                                            var cld: f32 = select(0.0f, 1.0f, ((((mem_ld((cloudy + bitcast<u32>(((((gg - 1i) * nl) + (lev - 1i)) >> u32(5i)))))) >> u32(((((gg - 1i) * nl) + (lev - 1i)) & 31i))) & 1u) != 0u));
                                            var odcld: f32 = 0.0f;
                                            var efclfrac: f32 = 0.0f;
                                            if ((cld == 1.0f)) {
                                                odcld = opq((opq(secdiff)) * (opq(lam_3(gg, iband, lev, cloudy, &nl, ciwp, clwp, cswp, rei, fail, G, res, rel))));
                                                var transcld: f32 = f_rr_exp_cr(opq((-(opq(odcld)))));
                                                var abscld: f32 = opq((opq(1.0f)) - (opq(transcld)));
                                                efclfrac = opq((opq(abscld)) * (opq(cld)));
                                            }
                                            var odtot: f32 = opq((opq(odepth)) + (opq(odcld)));
                                            var bbdtot: f32;
                                            var gasF1: f32 = 0.0f;
                                            var gasF2: f32 = 0.0f;
                                            if ((odtot < 0.06f)) {
                                                mem_st((atrans + bitcast<u32>((lev - 1i))), bitcast<u32>(opq(fma(opq((-(opq((opq(0.5f)) * (opq(odepth)))))), opq(odepth), opq(odepth)))));
                                                var odepth_rec: f32 = opq((opq(K_RR_REC6)) * (opq(odepth)));
                                                gasF1 = opq((opq(plfrac)) * (opq(fma(opq(dplankdn), opq(odepth_rec), opq(blay)))));
                                                gasF2 = bitcast<f32>(mem_ld((atrans + bitcast<u32>((lev - 1i)))));
                                                mem_st((atot + bitcast<u32>((lev - 1i))), bitcast<u32>(opq(fma(opq((-(opq((opq(0.5f)) * (opq(odtot)))))), opq(odtot), opq(odtot)))));
                                                var odtot_rec: f32 = opq((opq(K_RR_REC6)) * (opq(odtot)));
                                                bbdtot = opq((opq(plfrac)) * (opq(fma(opq(dplankdn), opq(odtot_rec), opq(blay)))));
                                                mem_st((bbugas + bitcast<u32>((lev - 1i))), bitcast<u32>(opq((opq(plfrac)) * (opq(fma(opq(dplankup), opq(odepth_rec), opq(blay)))))));
                                                mem_st((bbutot + bitcast<u32>((lev - 1i))), bitcast<u32>(opq((opq(plfrac)) * (opq(fma(opq(dplankup), opq(odtot_rec), opq(blay)))))));
                                            } else {
                                                if ((odepth <= 0.06f)) {
                                                    mem_st((atrans + bitcast<u32>((lev - 1i))), bitcast<u32>(opq(fma(opq((-(opq((opq(0.5f)) * (opq(odepth)))))), opq(odepth), opq(odepth)))));
                                                    var odepth_rec: f32 = opq((opq(K_RR_REC6)) * (opq(odepth)));
                                                    gasF1 = opq((opq(plfrac)) * (opq(fma(opq(dplankdn), opq(odepth_rec), opq(blay)))));
                                                    gasF2 = bitcast<f32>(mem_ld((atrans + bitcast<u32>((lev - 1i)))));
                                                    var tblind: f32 = div_cr(odtot, (opq((opq(bpade)) + (opq(odtot)))));
                                                    var ittot: i32 = i32(opq(fma(opq(tblint), opq(tblind), opq(0.5f))));
                                                    var tfactot: f32 = bitcast<f32>(mem_ld((G + bitcast<u32>((23091i + ittot)))));
                                                    bbdtot = opq((opq(plfrac)) * (opq(fma(opq(tfactot), opq(dplankdn), opq(blay)))));
                                                    mem_st((atot + bitcast<u32>((lev - 1i))), bitcast<u32>(opq((opq(1.0f)) - (bitcast<f32>(mem_ld((G + bitcast<u32>((13090i + ittot)))))))));
                                                    mem_st((bbugas + bitcast<u32>((lev - 1i))), bitcast<u32>(opq((opq(plfrac)) * (opq(fma(opq(dplankup), opq(odepth_rec), opq(blay)))))));
                                                    mem_st((bbutot + bitcast<u32>((lev - 1i))), bitcast<u32>(opq((opq(plfrac)) * (opq(fma(opq(tfactot), opq(dplankup), opq(blay)))))));
                                                } else {
                                                    var tblind: f32 = div_cr(odepth, (opq((opq(bpade)) + (opq(odepth)))));
                                                    var itgas: i32 = i32(opq(fma(opq(tblint), opq(tblind), opq(0.5f))));
                                                    odepth = bitcast<f32>(mem_ld((G + bitcast<u32>((3089i + itgas)))));
                                                    mem_st((atrans + bitcast<u32>((lev - 1i))), bitcast<u32>(opq((opq(1.0f)) - (bitcast<f32>(mem_ld((G + bitcast<u32>((13090i + itgas)))))))));
                                                    var tfacgas: f32 = bitcast<f32>(mem_ld((G + bitcast<u32>((23091i + itgas)))));
                                                    gasF1 = opq((bitcast<f32>(mem_ld((atrans + bitcast<u32>((lev - 1i)))))) * (opq(plfrac)));
                                                    gasF2 = opq(fma(opq(tfacgas), opq(dplankdn), opq(blay)));
                                                    odtot = opq((opq(odepth)) + (opq(odcld)));
                                                    tblind = div_cr(odtot, (opq((opq(bpade)) + (opq(odtot)))));
                                                    var ittot: i32 = i32(opq(fma(opq(tblint), opq(tblind), opq(0.5f))));
                                                    var tfactot: f32 = bitcast<f32>(mem_ld((G + bitcast<u32>((23091i + ittot)))));
                                                    bbdtot = opq((opq(plfrac)) * (opq(fma(opq(tfactot), opq(dplankdn), opq(blay)))));
                                                    mem_st((atot + bitcast<u32>((lev - 1i))), bitcast<u32>(opq((opq(1.0f)) - (bitcast<f32>(mem_ld((G + bitcast<u32>((13090i + ittot)))))))));
                                                    mem_st((bbugas + bitcast<u32>((lev - 1i))), bitcast<u32>(opq((opq(plfrac)) * (opq(fma(opq(tfacgas), opq(dplankup), opq(blay)))))));
                                                    mem_st((bbutot + bitcast<u32>((lev - 1i))), bitcast<u32>(opq((opq(plfrac)) * (opq(fma(opq(tfactot), opq(dplankup), opq(blay)))))));
                                                }
                                            }
                                            {
                                                var X: f32 = opq(fma(opq(efclfrac), opq((opq(1.0f)) - (bitcast<f32>(mem_ld((atrans + bitcast<u32>((lev - 1i))))))), bitcast<f32>(mem_ld((atrans + bitcast<u32>((lev - 1i)))))));
                                                var s5: f32 = opq(fma(opq(f_rr_neg(radld, C.z0)), opq(X), opq(radld)));
                                                var s6: f32 = opq(fma(opq(gasF1), opq(gasF2), opq(s5)));
                                                var bt: f32 = opq((opq(bbdtot)) * (bitcast<f32>(mem_ld((atot + bitcast<u32>((lev - 1i)))))));
                                                var s8: f32 = opq(fma(opq(f_rr_neg(gasF1, C.z0)), opq(gasF2), opq(bt)));
                                                radld = opq(fma(opq(cld), opq(s8), opq(s6)));
                                            }
                                            mem_st((drad + bitcast<u32>((lev - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((drad + bitcast<u32>((lev - 1i)))))) + (opq(radld)))));
                                        } else {
                                            var bbd: f32;
                                            if ((odepth <= 0.06f)) {
                                                mem_st((atrans + bitcast<u32>((lev - 1i))), bitcast<u32>(opq(fma(opq((-(opq((opq(0.5f)) * (opq(odepth)))))), opq(odepth), opq(odepth)))));
                                                odepth = opq((opq(K_RR_REC6)) * (opq(odepth)));
                                                bbd = opq((opq(plfrac)) * (opq(fma(opq(dplankdn), opq(odepth), opq(blay)))));
                                                mem_st((bbugas + bitcast<u32>((lev - 1i))), bitcast<u32>(opq((opq(plfrac)) * (opq(fma(opq(dplankup), opq(odepth), opq(blay)))))));
                                            } else {
                                                var tblind: f32 = div_cr(odepth, (opq((opq(bpade)) + (opq(odepth)))));
                                                var itr: i32 = i32(opq(fma(opq(tblint), opq(tblind), opq(0.5f))));
                                                var transc: f32 = bitcast<f32>(mem_ld((G + bitcast<u32>((13090i + itr)))));
                                                mem_st((atrans + bitcast<u32>((lev - 1i))), bitcast<u32>(opq((opq(1.0f)) - (opq(transc)))));
                                                var tausfac: f32 = bitcast<f32>(mem_ld((G + bitcast<u32>((23091i + itr)))));
                                                bbd = opq((opq(plfrac)) * (opq(fma(opq(tausfac), opq(dplankdn), opq(blay)))));
                                                mem_st((bbugas + bitcast<u32>((lev - 1i))), bitcast<u32>(opq((opq(plfrac)) * (opq(fma(opq(tausfac), opq(dplankup), opq(blay)))))));
                                            }
                                            radld = opq(fma(opq((opq(bbd)) - (opq(radld))), bitcast<f32>(mem_ld((atrans + bitcast<u32>((lev - 1i))))), opq(radld)));
                                            mem_st((drad + bitcast<u32>((lev - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((drad + bitcast<u32>((lev - 1i)))))) + (opq(radld)))));
                                        }
                                    continuing {
                                        lev = (lev - 1i);
                                    }
                                }
                            }
                            var reflect_v: f32 = opq((opq(1.0f)) - (opq(semiss)));
                            var rr: f32 = opq((opq(reflect_v)) * (opq(radld)));
                            var radlu: f32 = opq(fma(bitcast<f32>(mem_ld((fracsL + bitcast<u32>(((((1i) - 1i) * 16i) + (g - 1i)))))), bitcast<f32>(mem_ld((plankbnd + bitcast<u32>((iband - 1i))))), opq(rr)));
                            mem_st((urad + bitcast<u32>((0i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((urad + bitcast<u32>((0i)))))) + (opq(radlu)))));
                            {
                                var lev: i32 = 1i;
                                loop {
                                    if (!((lev <= nl))) { break; }
                                        if (((bitcast<i32>(mem_ld((icldlyr + bitcast<u32>((lev - 1i)))))) == 1i)) {
                                            var cld: f32 = select(0.0f, 1.0f, ((((mem_ld((cloudy + bitcast<u32>(((((gg - 1i) * nl) + (lev - 1i)) >> u32(5i)))))) >> u32(((((gg - 1i) * nl) + (lev - 1i)) & 31i))) & 1u) != 0u));
                                            var efclfrac: f32 = 0.0f;
                                            if ((cld == 1.0f)) {
                                                var odcld: f32 = opq((opq(secdiff)) * (opq(lam_3(gg, iband, lev, cloudy, &nl, ciwp, clwp, cswp, rei, fail, G, res, rel))));
                                                efclfrac = opq((opq((opq(1.0f)) - (opq(f_rr_exp_cr(opq((-(opq(odcld))))))))) * (opq(cld)));
                                            }
                                            {
                                                var X: f32 = opq(fma(opq(efclfrac), opq((opq(1.0f)) - (bitcast<f32>(mem_ld((atrans + bitcast<u32>((lev - 1i))))))), bitcast<f32>(mem_ld((atrans + bitcast<u32>((lev - 1i)))))));
                                                var s5: f32 = opq(fma(opq(f_rr_neg(radlu, C.z0)), opq(X), opq(radlu)));
                                                var s6: f32 = opq(fma(bitcast<f32>(mem_ld((bbugas + bitcast<u32>((lev - 1i))))), bitcast<f32>(mem_ld((atrans + bitcast<u32>((lev - 1i))))), opq(s5)));
                                                var bt: f32 = opq((bitcast<f32>(mem_ld((bbutot + bitcast<u32>((lev - 1i)))))) * (bitcast<f32>(mem_ld((atot + bitcast<u32>((lev - 1i)))))));
                                                var s8: f32 = opq(fma(opq(f_rr_neg(bitcast<f32>(mem_ld((bbugas + bitcast<u32>((lev - 1i))))), C.z0)), bitcast<f32>(mem_ld((atrans + bitcast<u32>((lev - 1i))))), opq(bt)));
                                                radlu = opq(fma(opq(cld), opq(s8), opq(s6)));
                                            }
                                            mem_st((urad + bitcast<u32>(lev)), bitcast<u32>(opq((bitcast<f32>(mem_ld((urad + bitcast<u32>(lev))))) + (opq(radlu)))));
                                        } else {
                                            radlu = opq(fma(opq((bitcast<f32>(mem_ld((bbugas + bitcast<u32>((lev - 1i)))))) - (opq(radlu))), bitcast<f32>(mem_ld((atrans + bitcast<u32>((lev - 1i))))), opq(radlu)));
                                            mem_st((urad + bitcast<u32>(lev)), bitcast<u32>(opq((bitcast<f32>(mem_ld((urad + bitcast<u32>(lev))))) + (opq(radlu)))));
                                        }
                                    continuing {
                                        lev = (lev + 1i);
                                    }
                                }
                            }
                        continuing {
                            g = (g + 1i);
                        }
                    }
                }
                var dw: f32 = bitcast<f32>(mem_ld((G + bitcast<u32>(((3073i + iband) - 1i)))));
                {
                    var lev: i32 = nl;
                    loop {
                        if (!((lev >= 0i))) { break; }
                            var uflux: f32 = opq((bitcast<f32>(mem_ld((urad + bitcast<u32>(lev))))) * (opq(K_RR_WTDIFF)));
                            var dflux: f32 = opq((bitcast<f32>(mem_ld((drad + bitcast<u32>(lev))))) * (opq(K_RR_WTDIFF)));
                            mem_st((urad + bitcast<u32>(lev)), bitcast<u32>(0.0f));
                            mem_st((drad + bitcast<u32>(lev)), bitcast<u32>(0.0f));
                            mem_st((totuflux + bitcast<u32>(lev)), bitcast<u32>(opq(fma(opq(uflux), opq(dw), bitcast<f32>(mem_ld((totuflux + bitcast<u32>(lev))))))));
                            mem_st((totdflux + bitcast<u32>(lev)), bitcast<u32>(opq(fma(opq(dflux), opq(dw), bitcast<f32>(mem_ld((totdflux + bitcast<u32>(lev))))))));
                        continuing {
                            lev = (lev - 1i);
                        }
                    }
                }
                gBase = (gBase + ngb);
            continuing {
                iband = (iband + 1i);
            }
        }
    }
    {
        var lev: i32 = 0i;
        loop {
            if (!((lev <= nl))) { break; }
                mem_st((totuflux + bitcast<u32>(lev)), bitcast<u32>(opq((bitcast<f32>(mem_ld((totuflux + bitcast<u32>(lev))))) * (opq(P.fluxfac)))));
                mem_st((totdflux + bitcast<u32>(lev)), bitcast<u32>(opq((bitcast<f32>(mem_ld((totdflux + bitcast<u32>(lev))))) * (opq(P.fluxfac)))));
            continuing {
                lev = (lev + 1i);
            }
        }
    }
    {
        var lev: i32 = 1i;
        loop {
            if (!((lev <= nl))) { break; }
                var l: i32 = (lev - 1i);
                var fnetl: f32 = opq((bitcast<f32>(mem_ld((totuflux + bitcast<u32>(l))))) - (bitcast<f32>(mem_ld((totdflux + bitcast<u32>(l))))));
                var fnetv: f32 = opq((bitcast<f32>(mem_ld((totuflux + bitcast<u32>(lev))))) - (bitcast<f32>(mem_ld((totdflux + bitcast<u32>(lev))))));
                mem_st((htr + bitcast<u32>(l)), bitcast<u32>(div_cr(opq((opq(P.heatfac)) * (opq((opq(fnetl)) - (opq(fnetv))))), (opq((bitcast<f32>(mem_ld((pz + bitcast<u32>(l))))) - (bitcast<f32>(mem_ld((pz + bitcast<u32>(lev))))))))));
            continuing {
                lev = (lev + 1i);
            }
        }
    }
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= nk))) { break; }
                mem_st((rthraten + bitcast<u32>((c + (stride * (k - 1i))))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((htr + bitcast<u32>((k - 1i))))), 8.64e+04f)));
            continuing {
                k = (k + 1i);
            }
        }
    }
    if (D) {
        var q: i32 = (dTau + (280i * nl));
        {
            var l: i32 = 0i;
            loop {
                if (!((l <= nl))) { break; }
                    let _t115 = q;
                    q = (q + 1i);
                    let _t116 = _t115;
                    mem_st((dbg + bitcast<u32>(_t116)), bitcast<u32>(bitcast<f32>(mem_ld((totuflux + bitcast<u32>(l))))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 0i;
            loop {
                if (!((l <= nl))) { break; }
                    let _t117 = q;
                    q = (q + 1i);
                    let _t118 = _t117;
                    mem_st((dbg + bitcast<u32>(_t118)), bitcast<u32>(bitcast<f32>(mem_ld((totdflux + bitcast<u32>(l))))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 0i;
            loop {
                if (!((l < nl))) { break; }
                    let _t119 = q;
                    q = (q + 1i);
                    let _t120 = _t119;
                    mem_st((dbg + bitcast<u32>(_t120)), bitcast<u32>(bitcast<f32>(mem_ld((htr + bitcast<u32>(l))))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
    }
    var s8: u32 = (sfc + bitcast<u32>((8i * c)));
    mem_st(s8, bitcast<u32>(bitcast<f32>(mem_ld((totdflux + bitcast<u32>((0i)))))));
    mem_st((s8 + bitcast<u32>(1i)), bitcast<u32>(bitcast<f32>(mem_ld((totuflux + bitcast<u32>(nl))))));
    mem_st((s8 + bitcast<u32>(2i)), bitcast<u32>(bitcast<f32>(mem_ld((totuflux + bitcast<u32>(nl))))));
    mem_st((s8 + bitcast<u32>(3i)), bitcast<u32>(bitcast<f32>(mem_ld((totdflux + bitcast<u32>(nl))))));
    mem_st((s8 + bitcast<u32>(4i)), bitcast<u32>(bitcast<f32>(mem_ld((totuflux + bitcast<u32>((0i)))))));
    mem_st((s8 + bitcast<u32>(5i)), bitcast<u32>(bitcast<f32>(mem_ld((totdflux + bitcast<u32>((0i)))))));
    mem_st((s8 + bitcast<u32>(6i)), bitcast<u32>(f32(laytrop)));
    mem_st((s8 + bitcast<u32>(7i)), bitcast<u32>(pwvcm));
}
