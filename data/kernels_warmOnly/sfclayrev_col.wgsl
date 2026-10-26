// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// sfclayrev_col: сгенерировано, не править руками.

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

fn f_rr_exp_cr(x_in: f32) -> f32 {
    var x: f32 = x_in;
    if ((!((x > (opq((-(opq(87.3f)))))) && (x < 88.7f)))) {
        return opq(exp(x));
    }
    return f_rr_exp_ff(vec2<f32>(x, 0.0f));
}

fn f_rr_log_cr(x_in: f32) -> f32 {
    var x: f32 = x_in;
    if (((!(x > 0.0f)) || ((bitcast<u32>(x) & 0x7fffffffu) == 0x7f800000u))) {
        return opq(log(x));
    }
    var a: vec2<f32> = f_rr_log_ff(x);
    return opq((opq(a.x)) + (opq(a.y)));
}

fn f_zolri(ri_in: f32, z_in: f32, z0_in: f32, T_in: u32, zero_in: u32) -> f32 {
    var ri: f32 = ri_in;
    var z: f32 = z_in;
    var z0: f32 = z0_in;
    var T: u32 = T_in;
    var zero: u32 = zero_in;
    var x1: f32;
    var x2: f32;
    if ((ri < 0.0f)) {
        x1 = opq((-(opq(5.0f))));
        x2 = 0.0f;
    } else {
        x1 = 0.0f;
        x2 = 5.0f;
    }
    var fx1: f32 = f_zolri2(&x1, ri, z, z0, T);
    var fx2: f32 = f_zolri2(&x2, ri, z, z0, T);
    var res: f32 = bitcast<f32>(0x7fc00000u);
    loop {
        if (!(((abs(opq((opq(x1)) - (opq(x2))))) > 0.01f))) { break; }
            if ((fx1 == fx2)) {
                return res;
            }
            if (((abs(fx2)) < (abs(fx1)))) {
                x1 = opq(fma(opq(f_rr_neg(div_cr(fx1, (opq((opq(fx2)) - (opq(fx1))))), zero)), opq((opq(x2)) - (opq(x1))), opq(x1)));
                fx1 = f_zolri2(&x1, ri, z, z0, T);
                res = x1;
            } else {
                x2 = opq(fma(opq(f_rr_neg(div_cr(fx2, (opq((opq(fx2)) - (opq(fx1))))), zero)), opq((opq(x2)) - (opq(x1))), opq(x2)));
                fx2 = f_zolri2(&x2, ri, z, z0, T);
                res = x2;
            }
    }
    return res;
}

fn f_zolri2(zol2: ptr<function, f32>, ri2_in: f32, z_in: f32, z0_in: f32, T_in: u32) -> f32 {
    var ri2: f32 = ri2_in;
    var z: f32 = z_in;
    var z0: f32 = z0_in;
    var T: u32 = T_in;
    if (((opq((opq((*zol2))) * (opq(ri2)))) < 0.0f)) {
        (*zol2) = 0.0f;
    }
    var zol20: f32 = div_cr(opq((opq((*zol2))) * (opq(z0))), z);
    var zol3: f32 = opq((opq((*zol2))) + (opq(zol20)));
    var lg: f32 = f_rr_log_cr(div_cr((opq((opq(z)) + (opq(z0)))), z0));
    var psix2: f32;
    var psih2: f32;
    if ((ri2 < 0.0f)) {
        psix2 = opq((opq(lg)) - (opq((opq(f_psim_unstable(zol3, T))) - (opq(f_psim_unstable(zol20, T))))));
        psih2 = opq((opq(lg)) - (opq((opq(f_psih_unstable(zol3, T))) - (opq(f_psih_unstable(zol20, T))))));
    } else {
        psix2 = opq((opq(lg)) - (opq((opq(f_psim_stable(zol3, T))) - (opq(f_psim_stable(zol20, T))))));
        psih2 = opq((opq(lg)) - (opq((opq(f_psih_stable(zol3, T))) - (opq(f_psih_stable(zol20, T))))));
    }
    return opq((opq(div_cr(opq((opq((*zol2))) * (opq(psih2))), (opq((opq(psix2)) * (opq(psix2))))))) - (opq(ri2)));
}

fn f_psim_unstable(z_in: f32, T_in: u32) -> f32 {
    var z: f32 = z_in;
    var T: u32 = T_in;
    var t: f32 = opq((opq((-(opq(z))))) * (opq(1e+02f)));
    var _t1: f32;
    if ((((i32(t)) + 1i) <= 1000i)) {
        _t1 = f_sfc_lookup((T + bitcast<u32>(1001i)), t);
    } else {
        _t1 = f_psim_unstable_full(z);
    }
    return _t1;
}

fn f_sfc_lookup(t_in: u32, zolf100_in: f32) -> f32 {
    var t: u32 = t_in;
    var zolf100: f32 = zolf100_in;
    var n: i32 = i32(zolf100);
    var r: f32 = opq((opq(zolf100)) - (opq(f32(n))));
    return opq(fma(opq(r), opq((bitcast<f32>(mem_ld((t + bitcast<u32>((n + 1i)))))) - (bitcast<f32>(mem_ld((t + bitcast<u32>(n)))))), bitcast<f32>(mem_ld((t + bitcast<u32>(n))))));
}

fn f_psim_unstable_full(zolf_in: f32) -> f32 {
    var zolf: f32 = zolf_in;
    var x: f32 = f_rr_pow_cr(opq(fma(opq((-(opq(zolf)))), opq(16.0f), opq(1.0f))), 0.25f);
    var a: f32 = f_rr_log_cr(opq((opq((opq(x)) + (opq(1.0f)))) * (opq(0.5f))));
    var b: f32 = f_rr_log_cr(opq((opq(fma(opq(x), opq(x), opq(1.0f)))) * (opq(0.5f))));
    var psimk: f32 = opq((opq(fma(opq((-(opq(atan(x))))), opq(2.0f), opq(fma(opq(a), opq(2.0f), opq(b)))))) + (opq(1.5707964f)));
    var ym: f32 = f_rr_pow_cr(opq(fma(opq((-(opq(zolf)))), opq(1e+01f), opq(1.0f))), 0.33f);
    var d: f32 = f_rr_log_cr(div_cr((opq((opq(fma(opq(ym), opq(ym), opq(ym)))) + (opq(1.0f)))), 3.0f));
    var e: f32 = opq((opq(atan(div_cr(opq(fma(opq(ym), opq(2.0f), opq(1.0f))), 1.7320508f)))) * (opq(1.7320508f)));
    var psimc: f32 = opq((opq(fma(opq(d), opq(1.5f), opq((-(opq(e))))))) + (opq(1.8137994f)));
    var z2: f32 = opq((opq(zolf)) * (opq(zolf)));
    return div_cr(opq(fma(opq(psimc), opq(z2), opq(psimk))), (opq((opq(z2)) + (opq(1.0f)))));
}

fn f_psih_unstable(z_in: f32, T_in: u32) -> f32 {
    var z: f32 = z_in;
    var T: u32 = T_in;
    var t: f32 = opq((opq((-(opq(z))))) * (opq(1e+02f)));
    var _t1: f32;
    if ((((i32(t)) + 1i) <= 1000i)) {
        _t1 = f_sfc_lookup((T + bitcast<u32>(3003i)), t);
    } else {
        _t1 = f_psih_unstable_full(z);
    }
    return _t1;
}

fn f_psih_unstable_full(zolf_in: f32) -> f32 {
    var zolf: f32 = zolf_in;
    var y: f32 = f_rr_pow_cr(opq(fma(opq((-(opq(zolf)))), opq(16.0f), opq(1.0f))), 0.5f);
    var a: f32 = f_rr_log_cr(opq((opq((opq(y)) + (opq(1.0f)))) * (opq(0.5f))));
    var yh: f32 = f_rr_pow_cr(opq(fma(opq((-(opq(zolf)))), opq(34.0f), opq(1.0f))), 0.33f);
    var d: f32 = f_rr_log_cr(div_cr((opq((opq(fma(opq(yh), opq(yh), opq(yh)))) + (opq(1.0f)))), 3.0f));
    var e: f32 = opq((opq(atan(div_cr(opq(fma(opq(yh), opq(2.0f), opq(1.0f))), 1.7320508f)))) * (opq(1.7320508f)));
    var psihc: f32 = opq((opq(fma(opq(d), opq(1.5f), opq((-(opq(e))))))) + (opq(1.8137994f)));
    var z2: f32 = opq((opq(zolf)) * (opq(zolf)));
    return div_cr(opq(fma(opq(a), opq(2.0f), opq((opq(psihc)) * (opq(z2))))), (opq((opq(z2)) + (opq(1.0f)))));
}

fn f_psim_stable(z_in: f32, T_in: u32) -> f32 {
    var z: f32 = z_in;
    var T: u32 = T_in;
    var t: f32 = opq((opq(z)) * (opq(1e+02f)));
    var _t1: f32;
    if ((((i32(t)) + 1i) <= 1000i)) {
        _t1 = f_sfc_lookup(T, t);
    } else {
        _t1 = f_psim_stable_full(z);
    }
    return _t1;
}

fn f_psim_stable_full(zolf_in: f32) -> f32 {
    var zolf: f32 = zolf_in;
    return opq((opq((-(opq(6.1f))))) * (opq(f_rr_log_cr(opq((opq(zolf)) + (opq(f_rr_pow_cr(opq((opq(f_rr_pow_cr(zolf, 2.5f))) + (opq(1.0f))), 0.4f))))))));
}

fn f_psih_stable(z_in: f32, T_in: u32) -> f32 {
    var z: f32 = z_in;
    var T: u32 = T_in;
    var t: f32 = opq((opq(z)) * (opq(1e+02f)));
    var _t1: f32;
    if ((((i32(t)) + 1i) <= 1000i)) {
        _t1 = f_sfc_lookup((T + bitcast<u32>(2002i)), t);
    } else {
        _t1 = f_psih_stable_full(z);
    }
    return _t1;
}

fn f_psih_stable_full(zolf_in: f32) -> f32 {
    var zolf: f32 = zolf_in;
    return opq((opq((-(opq(5.3f))))) * (opq(f_rr_log_cr(opq((opq(zolf)) + (opq(f_rr_pow_cr(opq((opq(f_rr_pow_cr(zolf, 1.1f))) + (opq(1.0f))), bitcast<f32>(1063828014u)))))))));
}

fn f_rr_neg(x_in: f32, z0_in: u32) -> f32 {
    var x: f32 = x_in;
    var z0: u32 = z0_in;
    return bitcast<f32>(((bitcast<u32>(x)) ^ (2147483648u ^ z0)));
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
    var T: u32 = ARG[7];
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
    var karman: f32 = pc.karman;
    var ux: f32 = bitcast<f32>(mem_ld((pin + bitcast<u32>((((((0i) * (g.nz + 1i)) + (0i)) * pc.nc) + c)))));
    var vx: f32 = bitcast<f32>(mem_ld((pin + bitcast<u32>((((((1i) * (g.nz + 1i)) + (0i)) * pc.nc) + c)))));
    var t1d: f32 = bitcast<f32>(mem_ld((pin + bitcast<u32>((((((3i) * (g.nz + 1i)) + (0i)) * pc.nc) + c)))));
    var qv1d: f32 = bitcast<f32>(mem_ld((pin + bitcast<u32>((((((4i) * (g.nz + 1i)) + (0i)) * pc.nc) + c)))));
    var p1d: f32 = bitcast<f32>(mem_ld((pin + bitcast<u32>((((((7i) * (g.nz + 1i)) + (0i)) * pc.nc) + c)))));
    var dz8w: f32 = bitcast<f32>(mem_ld((pin + bitcast<u32>((((((10i) * (g.nz + 1i)) + (0i)) * pc.nc) + c)))));
    var rhox: f32 = bitcast<f32>(mem_ld((pin + bitcast<u32>((((((12i) * (g.nz + 1i)) + (0i)) * pc.nc) + c)))));
    var psfcpa: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((11i) * plane) + o)))));
    var tsk: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((13i) * plane) + o)))));
    var xland: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((17i) * plane) + o)))));
    var water: bool = ((opq((opq(xland)) - (opq(1.5f)))) >= 0.0f);
    var znt: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((4i) * plane) + o)))));
    var ust: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((3i) * plane) + o)))));
    var mol: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((25i) * plane) + o)))));
    var qsfc: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((12i) * plane) + o)))));
    var zol: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((24i) * plane) + o)))));
    var psfc: f32 = div_cr(psfcpa, 1e+03f);
    var thgb: f32 = opq((opq(tsk)) * (opq(f_rr_pow_cr(div_cr(pc.p1000mb, psfcpa), pc.rovcp))));
    var pl: f32 = div_cr(p1d, 1e+03f);
    var thcon: f32 = f_rr_pow_cr(div_cr(opq((opq(pc.p1000mb)) * (opq(0.001f))), pl), pc.rovcp);
    var thx: f32 = opq((opq(t1d)) * (opq(thcon)));
    var qx: f32 = qv1d;
    var thvx: f32 = opq((opq(thx)) * (opq(fma(opq(pc.ep1), opq(qx), opq(1.0f)))));
    var e1: f32 = opq((opq(pc.svp1)) * (opq(f_rr_exp_cr(div_cr(opq((opq(pc.svp2)) * (opq((opq(tsk)) - (opq(pc.svpt0))))), (opq((opq(tsk)) - (opq(pc.svp3)))))))));
    if (((xland > 1.5f) || (qsfc <= (2e-10f)))) {
        qsfc = div_cr(opq((opq(pc.ep2)) * (opq(e1))), (opq((opq(psfc)) - (opq(e1)))));
    }
    e1 = opq((opq(pc.svp1)) * (opq(f_rr_exp_cr(div_cr(opq((opq(pc.svp2)) * (opq((opq(t1d)) - (opq(pc.svpt0))))), (opq((opq(t1d)) - (opq(pc.svp3)))))))));
    var qgh: f32 = div_cr(opq((opq(pc.ep2)) * (opq(e1))), (opq((opq(pl)) - (opq(e1)))));
    var cpm: f32 = opq((opq(pc.cp)) * (opq(fma(opq(0.8f), opq(qx), opq(1.0f)))));
    var za: f32 = opq((opq(0.5f)) * (opq((opq(dz8w)) + (opq(0.0f)))));
    var govrth: f32 = div_cr(pc.g, thx);
    var gz1oz0: f32 = f_rr_log_cr(div_cr((opq((opq(za)) + (opq(znt)))), znt));
    var gz2oz0: f32 = f_rr_log_cr(div_cr((opq((opq(2.0f)) + (opq(znt)))), znt));
    var gz10oz0: f32 = f_rr_log_cr(div_cr((opq((opq(1e+01f)) + (opq(znt)))), znt));
    var wspd: f32 = sqrt_cr(opq(fma(opq(ux), opq(ux), opq((opq(vx)) * (opq(vx))))));
    var tskv: f32 = opq((opq(thgb)) * (opq(fma(opq(pc.ep1), opq(qsfc), opq(1.0f)))));
    var dthvdz: f32 = opq((opq(thvx)) - (opq(tskv)));
    var vconv: f32;
    if ((xland < 1.5f)) {
        var hfx: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((31i) * plane) + o)))));
        var qfx: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((32i) * plane) + o)))));
        var pblh: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((23i) * plane) + o)))));
        var fluxc: f32 = opq(max(opq((opq(div_cr(div_cr(hfx, rhox), pc.cp))) + (opq(div_cr(opq((opq((opq(pc.ep1)) * (opq(tskv)))) * (opq(qfx))), rhox)))), 0.0f));
        vconv = f_rr_pow_cr(opq((opq((opq(div_cr(pc.g, tsk))) * (opq(pblh)))) * (opq(fluxc))), 0.33f);
    } else {
        var dthvm: f32 = select(0.0f, opq((-(opq(dthvdz)))), ((opq((-(opq(dthvdz))))) >= 0.0f));
        vconv = sqrt_cr(dthvm);
    }
    var vsgd: f32 = opq((opq(0.32f)) * (opq(f_rr_pow_cr(opq(max(opq((opq(div_cr(pc.dx, 5e+03f))) - (opq(1.0f))), 0.0f)), 0.33f))));
    wspd = sqrt_cr(opq(fma(opq(vsgd), opq(vsgd), opq(fma(opq(wspd), opq(wspd), opq((opq(vconv)) * (opq(vconv))))))));
    wspd = opq(max(wspd, 0.1f));
    var br: f32 = div_cr(opq((opq((opq(govrth)) * (opq(za)))) * (opq(dthvdz))), (opq((opq(wspd)) * (opq(wspd)))));
    if ((mol < 0.0f)) {
        br = opq(min(br, 0.0f));
    }
    if ((br > 0.0f)) {
        zol = f_zolri(select(br, 2.5e+02f, (br > (2.5e+02f))), za, znt, T, pc.zero);
    }
    if ((br < 0.0f)) {
        if ((ust < 0.001f)) {
            zol = opq((opq(br)) * (opq(gz1oz0)));
        } else {
            zol = f_zolri(select(br, opq((-(opq(2.5e+02f)))), (br < (opq((-(opq(2.5e+02f))))))), za, znt, T, pc.zero);
        }
    }
    var zolzz: f32 = div_cr(opq((opq(zol)) * (opq((opq(za)) + (opq(znt))))), za);
    var zol10: f32 = div_cr(opq((opq(zol)) * (opq((opq(1e+01f)) + (opq(znt))))), za);
    var zol2: f32 = div_cr(opq((opq(zol)) * (opq((opq(2.0f)) + (opq(znt))))), za);
    var zol0: f32 = div_cr(opq((opq(zol)) * (opq(znt))), za);
    var zl2: f32 = opq((opq(div_cr(2.0f, za))) * (opq(zol)));
    var zl10: f32 = opq((opq(div_cr(1e+01f, za))) * (opq(zol)));
    var zlq: f32 = select(opq((opq(div_cr(0.01f, za))) * (opq(zol))), zol0, water);
    var regime: f32;
    var psim: f32;
    var psih: f32;
    var psim10: f32;
    var psih10: f32;
    var psim2: f32;
    var psih2: f32;
    var pq: f32;
    var pq2: f32;
    var pq10: f32;
    var rmol: f32;
    if ((br > 0.0f)) {
        regime = 1.0f;
        psim = opq((opq(f_psim_stable(zolzz, T))) - (opq(f_psim_stable(zol0, T))));
        psih = opq((opq(f_psih_stable(zolzz, T))) - (opq(f_psih_stable(zol0, T))));
        psim10 = opq((opq(f_psim_stable(zol10, T))) - (opq(f_psim_stable(zol0, T))));
        psih10 = opq((opq(f_psih_stable(zol10, T))) - (opq(f_psih_stable(zol0, T))));
        psim2 = opq((opq(f_psim_stable(zol2, T))) - (opq(f_psim_stable(zol0, T))));
        psih2 = opq((opq(f_psih_stable(zol2, T))) - (opq(f_psih_stable(zol0, T))));
        pq = opq((opq(f_psih_stable(zol, T))) - (opq(f_psih_stable(zlq, T))));
        pq2 = opq((opq(f_psih_stable(zl2, T))) - (opq(f_psih_stable(zlq, T))));
        pq10 = opq((opq(f_psih_stable(zl10, T))) - (opq(f_psih_stable(zlq, T))));
        rmol = div_cr(zol, za);
    } else {
        if ((br == 0.0f)) {
            regime = 3.0f;
            psim = 0.0f;
            psih = 0.0f;
            psim10 = 0.0f;
            psih10 = 0.0f;
            psim2 = 0.0f;
            psih2 = 0.0f;
            pq = 0.0f;
            pq2 = 0.0f;
            pq10 = 0.0f;
            zol = 0.0f;
            rmol = div_cr(zol, za);
        } else {
            regime = 4.0f;
            psim = opq((opq(f_psim_unstable(zolzz, T))) - (opq(f_psim_unstable(zol0, T))));
            psih = opq((opq(f_psih_unstable(zolzz, T))) - (opq(f_psih_unstable(zol0, T))));
            psim10 = opq((opq(f_psim_unstable(zol10, T))) - (opq(f_psim_unstable(zol0, T))));
            psih10 = opq((opq(f_psih_unstable(zol10, T))) - (opq(f_psih_unstable(zol0, T))));
            psim2 = opq((opq(f_psim_unstable(zol2, T))) - (opq(f_psim_unstable(zol0, T))));
            psih2 = opq((opq(f_psih_unstable(zol2, T))) - (opq(f_psih_unstable(zol0, T))));
            pq = opq((opq(f_psih_unstable(zol, T))) - (opq(f_psih_unstable(zlq, T))));
            pq2 = opq((opq(f_psih_unstable(zl2, T))) - (opq(f_psih_unstable(zlq, T))));
            pq10 = opq((opq(f_psih_unstable(zl10, T))) - (opq(f_psih_unstable(zlq, T))));
            psih = opq(min(psih, opq((opq(0.9f)) * (opq(gz1oz0)))));
            psim = opq(min(psim, opq((opq(0.9f)) * (opq(gz1oz0)))));
            psih2 = opq(min(psih2, opq((opq(0.9f)) * (opq(gz2oz0)))));
            psim10 = opq(min(psim10, opq((opq(0.9f)) * (opq(gz10oz0)))));
            psih10 = opq(min(psih10, opq((opq(0.9f)) * (opq(gz10oz0)))));
            rmol = div_cr(zol, za);
        }
    }
    var dtg: f32 = opq((opq(thx)) - (opq(thgb)));
    var psix: f32 = opq((opq(gz1oz0)) - (opq(psim)));
    var psix10: f32 = opq((opq(gz10oz0)) - (opq(psim10)));
    var psit: f32 = opq((opq(gz1oz0)) - (opq(psih)));
    var psit2: f32 = opq((opq(gz2oz0)) - (opq(psih2)));
    var zl: f32 = select(0.01f, znt, water);
    var xka: f32 = 2.4e-05f;
    var psiq: f32 = opq((opq(f_rr_log_cr(opq((opq(div_cr(opq((opq((opq(karman)) * (opq(ust)))) * (opq(za))), xka))) + (opq(div_cr(za, zl))))))) - (opq(pq)));
    var psiq2: f32 = opq((opq(f_rr_log_cr(opq((opq(div_cr(opq((opq((opq(karman)) * (opq(ust)))) * (opq(2.0f))), xka))) + (opq(div_cr(2.0f, zl))))))) - (opq(pq2)));
    var psiq10: f32 = opq((opq(f_rr_log_cr(opq((opq(div_cr(opq((opq((opq(karman)) * (opq(ust)))) * (opq(1e+01f))), xka))) + (opq(div_cr(1e+01f, zl))))))) - (opq(pq10)));
    var z0t: f32 = znt;
    var z0q: f32 = znt;
    if (water) {
        var visc: f32 = opq((opq(fma(opq(0.009f), opq((opq(t1d)) - (opq(273.15f))), opq(1.32f)))) * (opq(1e-05f)));
        var restar: f32 = div_cr(opq((opq(ust)) * (opq(znt))), visc);
        z0t = opq((opq(5.5e-05f)) * (opq(f_rr_pow_cr(restar, opq((-(opq(0.6f))))))));
        z0t = opq(min(z0t, 0.0001f));
        z0t = opq(max(z0t, 2e-09f));
        z0q = z0t;
        zolzz = div_cr(opq((opq(zol)) * (opq((opq(za)) + (opq(z0t))))), za);
        zol10 = div_cr(opq((opq(zol)) * (opq((opq(1e+01f)) + (opq(z0t))))), za);
        zol2 = div_cr(opq((opq(zol)) * (opq((opq(2.0f)) + (opq(z0t))))), za);
        zol0 = div_cr(opq((opq(zol)) * (opq(z0t))), za);
        if ((zol > 0.0f)) {
            psih = opq((opq(f_psih_stable(zolzz, T))) - (opq(f_psih_stable(zol0, T))));
            psih10 = opq((opq(f_psih_stable(zol10, T))) - (opq(f_psih_stable(zol0, T))));
            psih2 = opq((opq(f_psih_stable(zol2, T))) - (opq(f_psih_stable(zol0, T))));
        } else {
            if ((zol == 0.0f)) {
                psih = 0.0f;
                psih10 = 0.0f;
                psih2 = 0.0f;
            } else {
                psih = opq((opq(f_psih_unstable(zolzz, T))) - (opq(f_psih_unstable(zol0, T))));
                psih10 = opq((opq(f_psih_unstable(zol10, T))) - (opq(f_psih_unstable(zol0, T))));
                psih2 = opq((opq(f_psih_unstable(zol2, T))) - (opq(f_psih_unstable(zol0, T))));
            }
        }
        psit = opq((opq(f_rr_log_cr(div_cr((opq((opq(za)) + (opq(z0t)))), z0t)))) - (opq(psih)));
        psit2 = opq((opq(f_rr_log_cr(div_cr((opq((opq(2.0f)) + (opq(z0t)))), z0t)))) - (opq(psih2)));
        psiq = opq((opq(f_rr_log_cr(div_cr((opq((opq(za)) + (opq(z0q)))), z0q)))) - (opq(psih)));
        psiq2 = opq((opq(f_rr_log_cr(div_cr((opq((opq(2.0f)) + (opq(z0q)))), z0q)))) - (opq(psih2)));
        psiq10 = opq((opq(f_rr_log_cr(div_cr((opq((opq(1e+01f)) + (opq(z0q)))), z0q)))) - (opq(psih10)));
    }
    mem_st((sfc + bitcast<u32>((((47i) * plane) + o))), bitcast<u32>(opq((opq((div_cr(karman, psix10)))) * (opq((div_cr(karman, psiq10)))))));
    mem_st((sfc + bitcast<u32>((((5i) * plane) + o))), bitcast<u32>(opq((opq((div_cr(karman, psix10)))) * (opq((div_cr(karman, psix10)))))));
    mem_st((sfc + bitcast<u32>((((48i) * plane) + o))), bitcast<u32>(opq((opq((div_cr(karman, psix)))) * (opq((div_cr(karman, psiq)))))));
    mem_st((sfc + bitcast<u32>((((49i) * plane) + o))), bitcast<u32>(opq((opq((div_cr(karman, psix)))) * (opq((div_cr(karman, psix)))))));
    mem_st((sfc + bitcast<u32>((((53i) * plane) + o))), bitcast<u32>(z0t));
    mem_st((sfc + bitcast<u32>((((54i) * plane) + o))), bitcast<u32>(z0q));
    ust = opq(fma(opq(0.5f), opq(ust), opq(div_cr(opq((opq((opq(0.5f)) * (opq(karman)))) * (opq(wspd))), psix))));
    var wspdi: f32 = sqrt_cr(opq(fma(opq(ux), opq(ux), opq((opq(vx)) * (opq(vx))))));
    mem_st((sfc + bitcast<u32>((((46i) * plane) + o))), bitcast<u32>(opq(fma(opq(0.5f), bitcast<f32>(mem_ld((sfc + bitcast<u32>((((46i) * plane) + o))))), opq(div_cr(opq((opq((opq(0.5f)) * (opq(karman)))) * (opq(wspdi))), psix))))));
    mem_st((sfc + bitcast<u32>((((38i) * plane) + o))), bitcast<u32>(div_cr(opq((opq(ux)) * (opq(psix10))), psix)));
    mem_st((sfc + bitcast<u32>((((39i) * plane) + o))), bitcast<u32>(div_cr(opq((opq(vx)) * (opq(psix10))), psix)));
    var th2: f32 = opq((opq(thgb)) + (opq(div_cr(opq((opq(dtg)) * (opq(psit2))), psit))));
    mem_st((sfc + bitcast<u32>((((40i) * plane) + o))), bitcast<u32>(th2));
    mem_st((sfc + bitcast<u32>((((42i) * plane) + o))), bitcast<u32>(opq((opq(qsfc)) + (opq(div_cr(opq((opq((opq(qx)) - (opq(qsfc)))) * (opq(psiq2))), psiq))))));
    mem_st((sfc + bitcast<u32>((((41i) * plane) + o))), bitcast<u32>(opq((opq(th2)) * (opq(f_rr_pow_cr(div_cr(psfcpa, pc.p1000mb), pc.rovcp))))));
    if ((!water)) {
        ust = opq(max(ust, 0.001f));
    }
    mol = div_cr(opq((opq(karman)) * (opq(dtg))), psit);
    if (water) {
        znt = opq((opq(div_cr(opq((opq((opq(0.0185f)) * (opq(ust)))) * (opq(ust))), pc.g))) + (opq(div_cr((opq((opq(0.11f)) * (opq(1.5e-05f)))), ust))));
        znt = opq(min(znt, 0.00285f));
    }
    var flqc: f32 = div_cr(opq((opq((opq((opq(rhox)) * (bitcast<f32>(mem_ld((sfc + bitcast<u32>((((18i) * plane) + o)))))))) * (opq(ust)))) * (opq(karman))), psiq);
    var dtthx: f32 = abs(opq((opq(thx)) - (opq(thgb))));
    var flhc: f32 = select(0.0f, div_cr(opq((opq((opq((opq(cpm)) * (opq(rhox)))) * (opq(ust)))) * (opq(mol))), (opq((opq(thx)) - (opq(thgb))))), (dtthx > (1e-05f)));
    var qvflux: f32 = div_cr(0.00015f, (opq((opq(1.0f)) - (opq(0.00015f)))));
    var qfx: f32 = opq(max(opq((opq(qvflux)) * (opq(rhox))), 0.0f));
    mem_st((sfc + bitcast<u32>((((33i) * plane) + o))), bitcast<u32>(opq((opq(fma(opq((-(opq(pc.lv2)))), opq(tsk), opq(pc.lv1)))) * (opq(qfx)))));
    mem_st((sfc + bitcast<u32>((((51i) * plane) + o))), bitcast<u32>(div_cr(opq((-(opq(qfx)))), (opq((opq(rhox)) * (opq(ust)))))));
    var hfx: f32 = 0.0f;
    if (((opq((opq(xland)) - (opq(1.5f)))) > 0.0f)) {
        hfx = opq((opq(flhc)) * (opq((opq(thgb)) - (opq(thx)))));
    } else {
        if (((opq((opq(xland)) - (opq(1.5f)))) < 0.0f)) {
            hfx = opq(max(opq((opq((opq(0.1f)) * (opq(rhox)))) * (opq(cpm))), opq((-(opq(2.5e+02f))))));
        }
    }
    mem_st((sfc + bitcast<u32>((((31i) * plane) + o))), bitcast<u32>(hfx));
    mem_st((sfc + bitcast<u32>((((32i) * plane) + o))), bitcast<u32>(qfx));
    mem_st((sfc + bitcast<u32>((((55i) * plane) + o))), bitcast<u32>(div_cr(opq((opq(ust)) * (opq(karman))), psiq)));
    mem_st((sfc + bitcast<u32>((((57i) * plane) + o))), bitcast<u32>(div_cr(opq((opq(ust)) * (opq(karman))), psiq2)));
    mem_st((sfc + bitcast<u32>((((56i) * plane) + o))), bitcast<u32>(div_cr(opq((opq(ust)) * (opq(karman))), psit2)));
    mem_st((sfc + bitcast<u32>((((4i) * plane) + o))), bitcast<u32>(znt));
    mem_st((sfc + bitcast<u32>((((3i) * plane) + o))), bitcast<u32>(ust));
    mem_st((sfc + bitcast<u32>((((25i) * plane) + o))), bitcast<u32>(mol));
    mem_st((sfc + bitcast<u32>((((12i) * plane) + o))), bitcast<u32>(qsfc));
    mem_st((sfc + bitcast<u32>((((24i) * plane) + o))), bitcast<u32>(zol));
    mem_st((sfc + bitcast<u32>((((37i) * plane) + o))), bitcast<u32>(rmol));
    mem_st((sfc + bitcast<u32>((((26i) * plane) + o))), bitcast<u32>(regime));
    mem_st((sfc + bitcast<u32>((((27i) * plane) + o))), bitcast<u32>(psim));
    mem_st((sfc + bitcast<u32>((((28i) * plane) + o))), bitcast<u32>(psih));
    mem_st((sfc + bitcast<u32>((((29i) * plane) + o))), bitcast<u32>(psix));
    mem_st((sfc + bitcast<u32>((((30i) * plane) + o))), bitcast<u32>(psit));
    mem_st((sfc + bitcast<u32>((((52i) * plane) + o))), bitcast<u32>(psiq));
    mem_st((sfc + bitcast<u32>((((43i) * plane) + o))), bitcast<u32>(gz1oz0));
    mem_st((sfc + bitcast<u32>((((44i) * plane) + o))), bitcast<u32>(wspd));
    mem_st((sfc + bitcast<u32>((((45i) * plane) + o))), bitcast<u32>(br));
    mem_st((sfc + bitcast<u32>((((36i) * plane) + o))), bitcast<u32>(qgh));
    mem_st((sfc + bitcast<u32>((((58i) * plane) + o))), bitcast<u32>(cpm));
    mem_st((sfc + bitcast<u32>((((34i) * plane) + o))), bitcast<u32>(flhc));
    mem_st((sfc + bitcast<u32>((((35i) * plane) + o))), bitcast<u32>(flqc));
    mem_st((sfc + bitcast<u32>((((50i) * plane) + o))), bitcast<u32>(mol));
}
