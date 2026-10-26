// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// ysu_col: сгенерировано, не править руками.

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

fn f_rr_neg(x_in: f32, z0_in: u32) -> f32 {
    var x: f32 = x_in;
    var z0: u32 = z0_in;
    return bitcast<f32>(((bitcast<u32>(x)) ^ (2147483648u ^ z0)));
}

fn f_ysu_tridiag_10(al_in: u32, cm_in: u32, cu_in: u32, f_in: u32, n_in: i32) {
    var al: u32 = al_in;
    var cm: u32 = cm_in;
    var cu: u32 = cu_in;
    var f: u32 = f_in;
    var n: i32 = n_in;
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 1914u + _z, 0u); }
    var fk: f32 = div_cr(1.0f, bitcast<f32>(mem_ld((cm + bitcast<u32>(1i)))));
    mem_st(((SCRB + 1914u) + bitcast<u32>(1i)), bitcast<u32>(opq((opq(fk)) * (bitcast<f32>(mem_ld((cu + bitcast<u32>(1i))))))));
    mem_st((f + bitcast<u32>(1i)), bitcast<u32>(opq((opq(fk)) * (bitcast<f32>(mem_ld((f + bitcast<u32>(1i))))))));
    {
        var k: i32 = 2i;
        loop {
            if (!((k <= (n - 1i)))) { break; }
                fk = div_cr(1.0f, opq(fma(opq((-(bitcast<f32>(mem_ld((al + bitcast<u32>((k - 1i)))))))), bitcast<f32>(mem_ld(((SCRB + 1914u) + bitcast<u32>((k - 1i))))), bitcast<f32>(mem_ld((cm + bitcast<u32>(k)))))));
                mem_st(((SCRB + 1914u) + bitcast<u32>(k)), bitcast<u32>(opq((opq(fk)) * (bitcast<f32>(mem_ld((cu + bitcast<u32>(k))))))));
                mem_st((f + bitcast<u32>(k)), bitcast<u32>(opq((opq(fk)) * (opq(fma(opq((-(bitcast<f32>(mem_ld((al + bitcast<u32>((k - 1i)))))))), bitcast<f32>(mem_ld((f + bitcast<u32>((k - 1i))))), bitcast<f32>(mem_ld((f + bitcast<u32>(k))))))))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    fk = div_cr(1.0f, opq(fma(opq((-(bitcast<f32>(mem_ld((al + bitcast<u32>((n - 1i)))))))), bitcast<f32>(mem_ld(((SCRB + 1914u) + bitcast<u32>((n - 1i))))), bitcast<f32>(mem_ld((cm + bitcast<u32>(n)))))));
    mem_st((f + bitcast<u32>(n)), bitcast<u32>(opq((opq(fk)) * (opq(fma(opq((-(bitcast<f32>(mem_ld((al + bitcast<u32>((n - 1i)))))))), bitcast<f32>(mem_ld((f + bitcast<u32>((n - 1i))))), bitcast<f32>(mem_ld((f + bitcast<u32>(n))))))))));
    {
        var k: i32 = (n - 1i);
        loop {
            if (!((k >= 1i))) { break; }
                mem_st((f + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq((-(bitcast<f32>(mem_ld(((SCRB + 1914u) + bitcast<u32>(k))))))), bitcast<f32>(mem_ld((f + bitcast<u32>((k + 1i))))), bitcast<f32>(mem_ld((f + bitcast<u32>(k))))))));
            continuing {
                k = (k - 1i);
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
    SCRB = ARG[36] + (gid.x + ARG[0] * (gid.y + ARG[1] * gid.z)) * 1980u;
    var g: S_GridDims = ld_GridDims(ARG[4]);
    var pc: S_PblConsts = ld_PblConsts(ARG[5]);
    var pin: u32 = ARG[6];
    var pout: u32 = ARG[7];
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
    var kte: i32 = g.nz;
    var klpbl: i32 = kte;
    var zero: u32 = pc.zero;
    var xkzminm: f32 = 0.1f;
    var xkzminh: f32 = 0.01f;
    var xkzmax: f32 = 1e+03f;
    var rimin: f32 = opq((-(opq(1e+02f))));
    var rlam: f32 = 3e+01f;
    var prmin: f32 = 0.25f;
    var prmax: f32 = 4.0f;
    var brcr_ub: f32 = 0.0f;
    var brcr_sb: f32 = 0.25f;
    var cori: f32 = 0.0001f;
    var afac: f32 = 6.8f;
    var bfac: f32 = 6.8f;
    var phifac: f32 = 8.0f;
    var sfcfrac: f32 = 0.1f;
    var d1: f32 = 0.02f;
    var d2: f32 = 0.05f;
    var d3: f32 = 0.001f;
    var h1: f32 = 0.33333334f;
    var h2: f32 = 0.6666667f;
    var zfmin: f32 = 1e-08f;
    var aphi5: f32 = 5.0f;
    var aphi16: f32 = 16.0f;
    var tmin: f32 = 0.01f;
    var gamcrt: f32 = 3.0f;
    var gamcrq: f32 = 0.002f;
    var g0: f32 = pc.g;
    var cp: f32 = pc.cp;
    var karman: f32 = pc.karman;
    var ep1: f32 = pc.ep1;
    var dt2: f32 = opq((opq(2.0f)) * (opq(pc.dt)));
    var rdt: f32 = div_cr(1.0f, dt2);
    var cont: f32 = div_cr(cp, g0);
    var conq: f32 = div_cr(1.0f, g0);
    var conpr: f32 = opq((opq((opq(bfac)) * (opq(karman)))) * (opq(sfcfrac)));
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 0u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 66u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 132u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 198u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 264u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 330u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 396u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 462u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 528u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 594u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 660u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 726u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 792u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 858u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 924u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 990u + _z, 0u); }
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= kte))) { break; }
                mem_st(((SCRB + 0u) + bitcast<u32>(k)), bitcast<u32>(bitcast<f32>(mem_ld((pin + bitcast<u32>((((((0i) * (g.nz + 1i)) + (k - 1i)) * pc.nc) + c)))))));
                mem_st(((SCRB + 66u) + bitcast<u32>(k)), bitcast<u32>(bitcast<f32>(mem_ld((pin + bitcast<u32>((((((1i) * (g.nz + 1i)) + (k - 1i)) * pc.nc) + c)))))));
                mem_st(((SCRB + 132u) + bitcast<u32>(k)), bitcast<u32>(bitcast<f32>(mem_ld((pin + bitcast<u32>((((((3i) * (g.nz + 1i)) + (k - 1i)) * pc.nc) + c)))))));
                mem_st(((SCRB + 198u) + bitcast<u32>(k)), bitcast<u32>(bitcast<f32>(mem_ld((pin + bitcast<u32>((((((4i) * (g.nz + 1i)) + (k - 1i)) * pc.nc) + c)))))));
                mem_st(((SCRB + 264u) + bitcast<u32>(k)), bitcast<u32>(bitcast<f32>(mem_ld((pin + bitcast<u32>((((((5i) * (g.nz + 1i)) + (k - 1i)) * pc.nc) + c)))))));
                mem_st(((SCRB + 330u) + bitcast<u32>(k)), bitcast<u32>(bitcast<f32>(mem_ld((pin + bitcast<u32>((((((6i) * (g.nz + 1i)) + (k - 1i)) * pc.nc) + c)))))));
                mem_st(((SCRB + 396u) + bitcast<u32>(k)), bitcast<u32>(bitcast<f32>(mem_ld((pin + bitcast<u32>((((((7i) * (g.nz + 1i)) + (k - 1i)) * pc.nc) + c)))))));
                mem_st(((SCRB + 528u) + bitcast<u32>(k)), bitcast<u32>(bitcast<f32>(mem_ld((pin + bitcast<u32>((((((9i) * (g.nz + 1i)) + (k - 1i)) * pc.nc) + c)))))));
                mem_st(((SCRB + 594u) + bitcast<u32>(k)), bitcast<u32>(bitcast<f32>(mem_ld((pin + bitcast<u32>((((((11i) * (g.nz + 1i)) + (k - 1i)) * pc.nc) + c)))))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= (kte + 1i)))) { break; }
                mem_st(((SCRB + 462u) + bitcast<u32>(k)), bitcast<u32>(bitcast<f32>(mem_ld((pin + bitcast<u32>((((((8i) * (g.nz + 1i)) + (k - 1i)) * pc.nc) + c)))))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    var psfcpa: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((11i) * plane) + o)))));
    var znt: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((4i) * plane) + o)))));
    var ust: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((3i) * plane) + o)))));
    var psim: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((29i) * plane) + o)))));
    var psih: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((30i) * plane) + o)))));
    var xland: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((17i) * plane) + o)))));
    var hfx: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((31i) * plane) + o)))));
    var qfx: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((32i) * plane) + o)))));
    var wspd: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((44i) * plane) + o)))));
    var br: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((45i) * plane) + o)))));
    var u10: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((38i) * plane) + o)))));
    var v10: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((39i) * plane) + o)))));
    var water: bool = ((opq((opq(xland)) - (opq(1.5f)))) >= 0.0f);
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= kte))) { break; }
                mem_st(((SCRB + 660u) + bitcast<u32>(k)), bitcast<u32>(div_cr(bitcast<f32>(mem_ld(((SCRB + 132u) + bitcast<u32>(k)))), bitcast<f32>(mem_ld(((SCRB + 528u) + bitcast<u32>(k)))))));
                mem_st(((SCRB + 726u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 660u) + bitcast<u32>(k))))) * (opq(fma(opq(ep1), bitcast<f32>(mem_ld(((SCRB + 198u) + bitcast<u32>(k)))), opq(1.0f)))))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    var rhox: f32 = div_cr(psfcpa, (opq((opq((opq(pc.rd)) * (bitcast<f32>(mem_ld(((SCRB + 132u) + bitcast<u32>(1i))))))) * (opq(fma(opq(ep1), bitcast<f32>(mem_ld(((SCRB + 198u) + bitcast<u32>(1i)))), opq(1.0f)))))));
    var govrth: f32 = div_cr(g0, bitcast<f32>(mem_ld(((SCRB + 660u) + bitcast<u32>(1i)))));
    mem_st(((SCRB + 792u) + bitcast<u32>(1i)), bitcast<u32>(0.0f));
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= kte))) { break; }
                mem_st(((SCRB + 792u) + bitcast<u32>((k + 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((pin + bitcast<u32>((((((10i) * (g.nz + 1i)) + (k - 1i)) * pc.nc) + c)))))) + (bitcast<f32>(mem_ld(((SCRB + 792u) + bitcast<u32>(k))))))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= kte))) { break; }
                mem_st(((SCRB + 858u) + bitcast<u32>(k)), bitcast<u32>(opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld(((SCRB + 792u) + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld(((SCRB + 792u) + bitcast<u32>((k + 1i)))))))))));
                mem_st(((SCRB + 990u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 462u) + bitcast<u32>(k))))) - (bitcast<f32>(mem_ld(((SCRB + 462u) + bitcast<u32>((k + 1i)))))))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    mem_st(((SCRB + 924u) + bitcast<u32>(1i)), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 858u) + bitcast<u32>(1i))))));
    {
        var k: i32 = 2i;
        loop {
            if (!((k <= kte))) { break; }
                mem_st(((SCRB + 924u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 858u) + bitcast<u32>(k))))) - (bitcast<f32>(mem_ld(((SCRB + 858u) + bitcast<u32>((k - 1i)))))))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    var wspd1: f32 = opq((opq(sqrt_cr(opq(fma(bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(1i)))), bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(1i)))), opq((bitcast<f32>(mem_ld(((SCRB + 66u) + bitcast<u32>(1i))))) * (bitcast<f32>(mem_ld(((SCRB + 66u) + bitcast<u32>(1i))))))))))) + (opq(1e-09f)));
    var hgamu: f32 = 0.0f;
    var hgamv: f32 = 0.0f;
    var delta: f32 = 0.0f;
    var wstar3_2: f32 = 0.0f;
    var hgamt: f32 = 0.0f;
    var hgamq: f32 = 0.0f;
    var wscale: f32 = 0.0f;
    var kpbl: i32 = 1i;
    var hpbl: f32 = bitcast<f32>(mem_ld(((SCRB + 792u) + bitcast<u32>(1i))));
    var zl1: f32 = bitcast<f32>(mem_ld(((SCRB + 858u) + bitcast<u32>(1i))));
    var thermal: f32 = bitcast<f32>(mem_ld(((SCRB + 726u) + bitcast<u32>(1i))));
    var pblflg: bool = true;
    var sfcflg: bool = true;
    var sflux: f32 = opq(fma(opq((opq(div_cr(qfx, rhox))) * (opq(ep1))), bitcast<f32>(mem_ld(((SCRB + 660u) + bitcast<u32>(1i)))), opq(div_cr(div_cr(hfx, rhox), cp))));
    if ((br > 0.0f)) {
        sfcflg = false;
    }
    var stable: bool = false;
    var brup: f32 = br;
    var brdn: f32 = 0.0f;
    var brcr: f32 = brcr_ub;
    {
        var k: i32 = 2i;
        loop {
            if (!((k <= klpbl))) { break; }
                if ((!stable)) {
                    brdn = brup;
                    var spdk2: f32 = opq(max(opq(fma(bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k)))), bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k)))), opq((bitcast<f32>(mem_ld(((SCRB + 66u) + bitcast<u32>(k))))) * (bitcast<f32>(mem_ld(((SCRB + 66u) + bitcast<u32>(k)))))))), 1.0f));
                    brup = div_cr(opq((opq((bitcast<f32>(mem_ld(((SCRB + 726u) + bitcast<u32>(k))))) - (opq(thermal)))) * (opq((div_cr(opq((opq(g0)) * (bitcast<f32>(mem_ld(((SCRB + 858u) + bitcast<u32>(k)))))), bitcast<f32>(mem_ld(((SCRB + 726u) + bitcast<u32>(1i))))))))), spdk2);
                    kpbl = k;
                    stable = (brup > brcr);
                }
            continuing {
                k = (k + 1i);
            }
        }
    }
    {
        var k: i32 = kpbl;
        var brint: f32;
        if ((brdn >= brcr)) {
            brint = 0.0f;
        } else {
            if ((brup <= brcr)) {
                brint = 1.0f;
            } else {
                brint = div_cr((opq((opq(brcr)) - (opq(brdn)))), (opq((opq(brup)) - (opq(brdn)))));
            }
        }
        hpbl = opq(fma(opq(brint), opq((bitcast<f32>(mem_ld(((SCRB + 858u) + bitcast<u32>(k))))) - (bitcast<f32>(mem_ld(((SCRB + 858u) + bitcast<u32>((k - 1i))))))), bitcast<f32>(mem_ld(((SCRB + 858u) + bitcast<u32>((k - 1i)))))));
        if ((hpbl < (bitcast<f32>(mem_ld(((SCRB + 792u) + bitcast<u32>(2i))))))) {
            kpbl = 1i;
        }
        if ((kpbl <= 1i)) {
            pblflg = false;
        }
    }
    var zol1: f32 = opq(max(div_cr(opq((opq((opq(br)) * (opq(psim)))) * (opq(psim))), (opq((opq(1e-12f)) + (opq(psih))))), rimin));
    zol1 = select(opq(max(zol1, zfmin)), opq(min(zol1, opq((-(opq(zfmin)))))), sfcflg);
    var hol1: f32 = opq((opq(div_cr(opq((opq(zol1)) * (opq(hpbl))), zl1))) * (opq(sfcfrac)));
    var phim: f32;
    var phih: f32;
    var wstar: f32;
    var wstar3: f32;
    if (sfcflg) {
        var b: f32 = opq(fma(opq((-(opq(aphi16)))), opq(hol1), opq(1.0f)));
        phim = f_rr_pow_cr(b, opq((-(opq(0.25f)))));
        phih = f_rr_pow_cr(b, opq((-(opq(0.5f)))));
        var bfx0: f32 = opq(max(sflux, 0.0f));
        wstar3 = opq((opq((opq(govrth)) * (opq(bfx0)))) * (opq(hpbl)));
        wstar = f_rr_pow_cr(wstar3, h1);
    } else {
        phim = opq(fma(opq(aphi5), opq(hol1), opq(1.0f)));
        phih = phim;
        wstar = 0.0f;
        wstar3 = 0.0f;
    }
    var ust3: f32 = f_rr_pow_cr(ust, 3.0f);
    wscale = f_rr_pow_cr(opq(fma(opq((opq((opq(phifac)) * (opq(karman)))) * (opq(wstar3))), opq(0.5f), opq(ust3))), h1);
    wscale = opq(min(wscale, opq((opq(ust)) * (opq(aphi16)))));
    wscale = opq(max(wscale, div_cr(ust, aphi5)));
    if ((sfcflg && (sflux > 0.0f))) {
        var gamfac: f32 = div_cr(div_cr(bfac, rhox), wscale);
        hgamt = opq(min(div_cr(opq((opq(gamfac)) * (opq(hfx))), cp), gamcrt));
        hgamq = opq(min(opq((opq(gamfac)) * (opq(qfx))), gamcrq));
        var vpert: f32 = opq((opq(div_cr(opq(fma(opq((opq(ep1)) * (bitcast<f32>(mem_ld(((SCRB + 660u) + bitcast<u32>(1i)))))), opq(hgamq), opq(hgamt))), bfac))) * (opq(afac)));
        thermal = opq(fma(opq(max(vpert, 0.0f)), opq(min(div_cr(bitcast<f32>(mem_ld(((SCRB + 858u) + bitcast<u32>(1i)))), (opq((opq(sfcfrac)) * (opq(hpbl))))), 1.0f)), opq(thermal)));
        hgamt = opq(max(hgamt, 0.0f));
        hgamq = opq(max(hgamq, 0.0f));
        var brint: f32 = div_cr(opq((opq(div_cr(opq((opq((opq((-(opq(15.9f))))) * (opq(ust)))) * (opq(ust))), wspd))) * (opq(wstar3))), f_rr_pow_cr(wscale, 4.0f));
        hgamu = opq((opq(brint)) * (bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(1i))))));
        hgamv = opq((opq(brint)) * (bitcast<f32>(mem_ld(((SCRB + 66u) + bitcast<u32>(1i))))));
    } else {
        pblflg = false;
    }
    if (pblflg) {
        kpbl = 1i;
        hpbl = bitcast<f32>(mem_ld(((SCRB + 792u) + bitcast<u32>(1i))));
        stable = false;
        brup = br;
        brcr = brcr_ub;
    }
    {
        var k: i32 = 2i;
        loop {
            if (!((k <= klpbl))) { break; }
                if (((!stable) && pblflg)) {
                    brdn = brup;
                    var spdk2: f32 = opq(max(opq(fma(bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k)))), bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k)))), opq((bitcast<f32>(mem_ld(((SCRB + 66u) + bitcast<u32>(k))))) * (bitcast<f32>(mem_ld(((SCRB + 66u) + bitcast<u32>(k)))))))), 1.0f));
                    brup = div_cr(opq((opq((bitcast<f32>(mem_ld(((SCRB + 726u) + bitcast<u32>(k))))) - (opq(thermal)))) * (opq((div_cr(opq((opq(g0)) * (bitcast<f32>(mem_ld(((SCRB + 858u) + bitcast<u32>(k)))))), bitcast<f32>(mem_ld(((SCRB + 726u) + bitcast<u32>(1i))))))))), spdk2);
                    kpbl = k;
                    stable = (brup > brcr);
                }
            continuing {
                k = (k + 1i);
            }
        }
    }
    if (pblflg) {
        var k: i32 = kpbl;
        var brint: f32;
        if ((brdn >= brcr)) {
            brint = 0.0f;
        } else {
            if ((brup <= brcr)) {
                brint = 1.0f;
            } else {
                brint = div_cr((opq((opq(brcr)) - (opq(brdn)))), (opq((opq(brup)) - (opq(brdn)))));
            }
        }
        hpbl = opq(fma(opq(brint), opq((bitcast<f32>(mem_ld(((SCRB + 858u) + bitcast<u32>(k))))) - (bitcast<f32>(mem_ld(((SCRB + 858u) + bitcast<u32>((k - 1i))))))), bitcast<f32>(mem_ld(((SCRB + 858u) + bitcast<u32>((k - 1i)))))));
        if ((hpbl < (bitcast<f32>(mem_ld(((SCRB + 792u) + bitcast<u32>(2i))))))) {
            kpbl = 1i;
        }
        if ((kpbl <= 1i)) {
            pblflg = false;
        }
    }
    if (((!sfcflg) && (hpbl < (bitcast<f32>(mem_ld(((SCRB + 792u) + bitcast<u32>(2i)))))))) {
        brup = br;
        stable = false;
    } else {
        stable = true;
    }
    if ((!stable)) {
        if (water) {
            var wspd10: f32 = sqrt_cr(opq(fma(opq(u10), opq(u10), opq((opq(v10)) * (opq(v10))))));
            var ross: f32 = div_cr((opq((opq(1e-10f)) + (opq(wspd10)))), (opq((opq(cori)) * (opq(znt)))));
            brcr = opq(min(opq((opq(0.16f)) * (opq(f_rr_pow_cr(opq((opq(1e-07f)) * (opq(ross))), opq((-(opq(0.18f)))))))), 0.3f));
        } else {
            brcr = brcr_sb;
        }
    }
    {
        var k: i32 = 2i;
        loop {
            if (!((k <= klpbl))) { break; }
                if ((!stable)) {
                    brdn = brup;
                    var spdk2: f32 = opq(max(opq(fma(bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k)))), bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k)))), opq((bitcast<f32>(mem_ld(((SCRB + 66u) + bitcast<u32>(k))))) * (bitcast<f32>(mem_ld(((SCRB + 66u) + bitcast<u32>(k)))))))), 1.0f));
                    brup = div_cr(opq((opq((bitcast<f32>(mem_ld(((SCRB + 726u) + bitcast<u32>(k))))) - (opq(thermal)))) * (opq((div_cr(opq((opq(g0)) * (bitcast<f32>(mem_ld(((SCRB + 858u) + bitcast<u32>(k)))))), bitcast<f32>(mem_ld(((SCRB + 726u) + bitcast<u32>(1i))))))))), spdk2);
                    kpbl = k;
                    stable = (brup > brcr);
                }
            continuing {
                k = (k + 1i);
            }
        }
    }
    if (((!sfcflg) && (hpbl < (bitcast<f32>(mem_ld(((SCRB + 792u) + bitcast<u32>(2i)))))))) {
        var k: i32 = kpbl;
        var brint: f32;
        if ((brdn >= brcr)) {
            brint = 0.0f;
        } else {
            if ((brup <= brcr)) {
                brint = 1.0f;
            } else {
                brint = div_cr((opq((opq(brcr)) - (opq(brdn)))), (opq((opq(brup)) - (opq(brdn)))));
            }
        }
        hpbl = opq(fma(opq(brint), opq((bitcast<f32>(mem_ld(((SCRB + 858u) + bitcast<u32>(k))))) - (bitcast<f32>(mem_ld(((SCRB + 858u) + bitcast<u32>((k - 1i))))))), bitcast<f32>(mem_ld(((SCRB + 858u) + bitcast<u32>((k - 1i)))))));
        if ((hpbl < (bitcast<f32>(mem_ld(((SCRB + 792u) + bitcast<u32>(2i))))))) {
            kpbl = 1i;
        }
        if ((kpbl <= 1i)) {
            pblflg = false;
        }
    }
    var we: f32 = 0.0f;
    var hfxpbl: f32 = 0.0f;
    var qfxpbl: f32 = 0.0f;
    var ufxpbl: f32 = 0.0f;
    var vfxpbl: f32 = 0.0f;
    if (pblflg) {
        var k: i32 = (kpbl - 1i);
        var wm3: f32 = opq(fma(opq(5.0f), opq(ust3), opq(wstar3)));
        var wm2: f32 = f_rr_pow_cr(wm3, h2);
        var bfxpbl: f32 = div_cr(opq((opq(div_cr(opq((opq((-(opq(0.15f))))) * (bitcast<f32>(mem_ld(((SCRB + 726u) + bitcast<u32>(1i)))))), g0))) * (opq(wm3))), hpbl);
        var dthvx: f32 = opq(max(opq((bitcast<f32>(mem_ld(((SCRB + 726u) + bitcast<u32>((k + 1i)))))) - (bitcast<f32>(mem_ld(((SCRB + 726u) + bitcast<u32>(k)))))), tmin));
        we = opq(max(div_cr(bfxpbl, dthvx), opq((-(opq(sqrt_cr(wm2)))))));
        var dthx: f32 = opq(max(opq((bitcast<f32>(mem_ld(((SCRB + 660u) + bitcast<u32>((k + 1i)))))) - (bitcast<f32>(mem_ld(((SCRB + 660u) + bitcast<u32>(k)))))), tmin));
        var dqx: f32 = opq(min(opq((bitcast<f32>(mem_ld(((SCRB + 198u) + bitcast<u32>((k + 1i)))))) - (bitcast<f32>(mem_ld(((SCRB + 198u) + bitcast<u32>(k)))))), 0.0f));
        hfxpbl = opq((opq(we)) * (opq(dthx)));
        qfxpbl = opq((opq(we)) * (opq(dqx)));
        var dux: f32 = opq((bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>((k + 1i)))))) - (bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k))))));
        var dvx: f32 = opq((bitcast<f32>(mem_ld(((SCRB + 66u) + bitcast<u32>((k + 1i)))))) - (bitcast<f32>(mem_ld(((SCRB + 66u) + bitcast<u32>(k))))));
        if ((dux > tmin)) {
            ufxpbl = opq(max(opq((opq(we)) * (opq(dux))), opq((opq((-(opq(ust))))) * (opq(ust)))));
        } else {
            if ((dux < (opq((-(opq(tmin))))))) {
                ufxpbl = opq(min(opq((opq(we)) * (opq(dux))), opq((opq(ust)) * (opq(ust)))));
            } else {
                ufxpbl = 0.0f;
            }
        }
        if ((dvx > tmin)) {
            vfxpbl = opq(max(opq((opq(we)) * (opq(dvx))), opq((opq((-(opq(ust))))) * (opq(ust)))));
        } else {
            if ((dvx < (opq((-(opq(tmin))))))) {
                vfxpbl = opq(min(opq((opq(we)) * (opq(dvx))), opq((opq(ust)) * (opq(ust)))));
            } else {
                vfxpbl = 0.0f;
            }
        }
        var delb: f32 = opq((opq((opq(govrth)) * (opq(d3)))) * (opq(hpbl)));
        delta = opq(min(opq(fma(opq(d1), opq(hpbl), opq(div_cr(opq((opq(d2)) * (opq(wm2))), delb)))), 1e+02f));
    }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 1056u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 1122u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 1188u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 1254u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 1320u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 1386u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 1452u + _z, 0u); }
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= kte))) { break; }
                mem_st(((SCRB + 1188u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
                mem_st(((SCRB + 1254u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
                mem_st(((SCRB + 1320u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
                mem_st(((SCRB + 1122u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
                mem_st(((SCRB + 1386u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
                mem_st(((SCRB + 1452u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
            continuing {
                k = (k + 1i);
            }
        }
    }
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= klpbl))) { break; }
                if ((pblflg && (k >= kpbl))) {
                    var e: f32 = div_cr((opq((bitcast<f32>(mem_ld(((SCRB + 792u) + bitcast<u32>((k + 1i)))))) - (opq(hpbl)))), delta);
                    mem_st(((SCRB + 1056u) + bitcast<u32>(k)), bitcast<u32>(opq((opq(e)) * (opq(e)))));
                } else {
                    mem_st(((SCRB + 1056u) + bitcast<u32>(k)), bitcast<u32>(1e+30f));
                }
            continuing {
                k = (k + 1i);
            }
        }
    }
    var prkpp: f32 = 0.0f;
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= klpbl))) { break; }
                if ((k < kpbl)) {
                    var zfac: f32 = opq(min(opq(max(opq((opq(1.0f)) - (opq(div_cr((opq((bitcast<f32>(mem_ld(((SCRB + 792u) + bitcast<u32>((k + 1i)))))) - (opq(zl1)))), (opq((opq(hpbl)) - (opq(zl1)))))))), zfmin)), 1.0f));
                    mem_st(((SCRB + 1122u) + bitcast<u32>(k)), bitcast<u32>(f_rr_pow_cr(opq((opq(1.0f)) - (opq(zfac))), 3.0f)));
                    var wscalek: f32 = f_rr_pow_cr(opq(fma(opq((opq((opq(phifac)) * (opq(karman)))) * (opq(wstar3))), opq((opq(1.0f)) - (opq(zfac))), opq(ust3))), h1);
                    var wscalek2: f32 = f_rr_pow_cr(opq((opq((opq((opq(phifac)) * (opq(karman)))) * (opq(wstar3_2)))) * (opq(zfac))), h1);
                    var prfac: f32;
                    var prfac2: f32;
                    var prnumfac: f32;
                    if (sfcflg) {
                        prfac = conpr;
                        prfac2 = div_cr(div_cr(opq((opq(15.9f)) * (opq((opq(wstar3)) + (opq(wstar3_2))))), ust3), (opq((opq(1.0f)) + (opq(div_cr(opq((opq((opq(4.0f)) * (opq(karman)))) * (opq((opq(wstar3)) + (opq(wstar3_2))))), ust3))))));
                        var m: f32 = opq(max(opq(fma(opq((-(opq(sfcfrac)))), opq(hpbl), bitcast<f32>(mem_ld(((SCRB + 792u) + bitcast<u32>((k + 1i))))))), 0.0f));
                        prnumfac = div_cr(opq((opq((-(opq(3.0f))))) * (opq((opq(m)) * (opq(m))))), (opq((opq(hpbl)) * (opq(hpbl)))));
                    } else {
                        prfac = 0.0f;
                        prfac2 = 0.0f;
                        prnumfac = 0.0f;
                        var phim8z: f32 = opq((opq(1.0f)) + (opq(div_cr(opq((opq((opq(aphi5)) * (opq(zol1)))) * (bitcast<f32>(mem_ld(((SCRB + 792u) + bitcast<u32>((k + 1i))))))), zl1))));
                        wscalek = div_cr(ust, phim8z);
                        wscalek = opq(max(wscalek, 0.001f));
                    }
                    var prnum0: f32 = opq((opq(div_cr(phih, phim))) + (opq(prfac)));
                    prnum0 = opq(max(opq(min(prnum0, prmax)), prmin));
                    var omz: f32 = opq((opq(1.0f)) - (opq(zfac)));
                    mem_st(((SCRB + 1188u) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq((opq((opq(wscalek)) * (opq(karman)))) * (bitcast<f32>(mem_ld(((SCRB + 792u) + bitcast<u32>((k + 1i))))))), opq((opq(zfac)) * (opq(zfac))), opq((opq((opq((opq(wscalek2)) * (opq(karman)))) * (opq((opq(hpbl)) - (bitcast<f32>(mem_ld(((SCRB + 792u) + bitcast<u32>((k + 1i)))))))))) * (opq((opq(omz)) * (opq(omz)))))))));
                    var ex: f32 = f_rr_exp_cr(prnumfac);
                    var prnum: f32 = opq(fma(opq((opq(prnum0)) - (opq(1.0f))), opq(ex), opq(1.0f)));
                    mem_st(((SCRB + 1320u) + bitcast<u32>(k)), bitcast<u32>(div_cr(bitcast<f32>(mem_ld(((SCRB + 1188u) + bitcast<u32>(k)))), prnum)));
                    prnum0 = div_cr(prnum0, opq(fma(opq((opq(prfac2)) * (opq(karman))), opq(sfcfrac), opq(1.0f))));
                    prnum = opq(fma(opq((opq(prnum0)) - (opq(1.0f))), opq(ex), opq(1.0f)));
                    mem_st(((SCRB + 1254u) + bitcast<u32>(k)), bitcast<u32>(div_cr(bitcast<f32>(mem_ld(((SCRB + 1188u) + bitcast<u32>(k)))), prnum)));
                    mem_st(((SCRB + 1188u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1188u) + bitcast<u32>(k))))) + (opq(xkzminm)))));
                    mem_st(((SCRB + 1254u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1254u) + bitcast<u32>(k))))) + (opq(xkzminh)))));
                    mem_st(((SCRB + 1320u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1320u) + bitcast<u32>(k))))) + (opq(xkzminh)))));
                    mem_st(((SCRB + 1188u) + bitcast<u32>(k)), bitcast<u32>(opq(min(bitcast<f32>(mem_ld(((SCRB + 1188u) + bitcast<u32>(k)))), xkzmax))));
                    mem_st(((SCRB + 1254u) + bitcast<u32>(k)), bitcast<u32>(opq(min(bitcast<f32>(mem_ld(((SCRB + 1254u) + bitcast<u32>(k)))), xkzmax))));
                    mem_st(((SCRB + 1320u) + bitcast<u32>(k)), bitcast<u32>(opq(min(bitcast<f32>(mem_ld(((SCRB + 1320u) + bitcast<u32>(k)))), xkzmax))));
                    if ((k == 1i)) {
                        prkpp = prnum;
                    }
                }
            continuing {
                k = (k + 1i);
            }
        }
    }
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= (kte - 1i)))) { break; }
                if ((k >= kpbl)) {
                    var du: f32 = opq((bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>((k + 1i)))))) - (bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k))))));
                    var dv: f32 = opq((bitcast<f32>(mem_ld(((SCRB + 66u) + bitcast<u32>((k + 1i)))))) - (bitcast<f32>(mem_ld(((SCRB + 66u) + bitcast<u32>(k))))));
                    var ss: f32 = opq((opq(div_cr(opq(fma(opq(du), opq(du), opq((opq(dv)) * (opq(dv))))), (opq((bitcast<f32>(mem_ld(((SCRB + 924u) + bitcast<u32>((k + 1i)))))) * (bitcast<f32>(mem_ld(((SCRB + 924u) + bitcast<u32>((k + 1i))))))))))) + (opq(1e-09f)));
                    var govrthv: f32 = div_cr(g0, (opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld(((SCRB + 726u) + bitcast<u32>((k + 1i)))))) + (bitcast<f32>(mem_ld(((SCRB + 726u) + bitcast<u32>(k))))))))));
                    var ri: f32 = div_cr(opq((opq(govrthv)) * (opq((bitcast<f32>(mem_ld(((SCRB + 726u) + bitcast<u32>((k + 1i)))))) - (bitcast<f32>(mem_ld(((SCRB + 726u) + bitcast<u32>(k)))))))), (opq((opq(ss)) * (bitcast<f32>(mem_ld(((SCRB + 924u) + bitcast<u32>((k + 1i)))))))));
                    if (((bitcast<f32>(mem_ld(((SCRB + 594u) + bitcast<u32>((k + 1i)))))) != 0.0f)) {
                        var qmean: f32 = opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld(((SCRB + 198u) + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld(((SCRB + 198u) + bitcast<u32>((k + 1i)))))))));
                        var tmean: f32 = opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld(((SCRB + 132u) + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld(((SCRB + 132u) + bitcast<u32>((k + 1i)))))))));
                        var lt: f32 = opq(fma(opq((-(opq(pc.lv2)))), opq(tmean), opq(pc.lv1)));
                        var alph: f32 = div_cr(div_cr(opq((opq(lt)) * (opq(qmean))), pc.rd), tmean);
                        var chi: f32 = div_cr(div_cr(div_cr(div_cr(opq((opq((opq(lt)) * (opq(lt)))) * (opq(qmean))), cp), pc.rv), tmean), tmean);
                        var pg: f32 = div_cr(div_cr(div_cr(opq((opq(g0)) * (opq(g0))), ss), tmean), cp);
                        ri = opq((opq((opq(1.0f)) + (opq(alph)))) * (opq(fma(opq(f_rr_neg(pg, zero)), opq(div_cr((opq((opq(chi)) - (opq(alph)))), (opq((opq(1.0f)) + (opq(chi)))))), opq(ri)))));
                    }
                    var zk: f32 = opq((opq(karman)) * (bitcast<f32>(mem_ld(((SCRB + 792u) + bitcast<u32>((k + 1i)))))));
                    var rlamdz: f32 = opq(min(opq(max(opq((opq(0.1f)) * (bitcast<f32>(mem_ld(((SCRB + 924u) + bitcast<u32>((k + 1i))))))), rlam)), 3e+02f));
                    rlamdz = opq(min(bitcast<f32>(mem_ld(((SCRB + 924u) + bitcast<u32>((k + 1i))))), rlamdz));
                    var rl: f32 = div_cr(opq((opq(zk)) * (opq(rlamdz))), (opq((opq(rlamdz)) + (opq(zk)))));
                    var dk: f32 = opq((opq((opq(rl)) * (opq(rl)))) * (opq(sqrt_cr(ss))));
                    if ((ri < 0.0f)) {
                        ri = opq(max(ri, rimin));
                        var sri: f32 = sqrt_cr(opq((-(opq(ri)))));
                        mem_st(((SCRB + 1188u) + bitcast<u32>(k)), bitcast<u32>(opq((opq(dk)) * (opq((opq(1.0f)) + (opq(div_cr(opq((opq(8.0f)) * (opq((-(opq(ri)))))), opq(fma(opq(1.746f), opq(sri), opq(1.0f)))))))))));
                        mem_st(((SCRB + 1254u) + bitcast<u32>(k)), bitcast<u32>(opq((opq(dk)) * (opq((opq(1.0f)) + (opq(div_cr(opq((opq(8.0f)) * (opq((-(opq(ri)))))), opq(fma(opq(1.286f), opq(sri), opq(1.0f)))))))))));
                    } else {
                        var d: f32 = opq(fma(opq(5.0f), opq(ri), opq(1.0f)));
                        mem_st(((SCRB + 1254u) + bitcast<u32>(k)), bitcast<u32>(div_cr(dk, (opq((opq(d)) * (opq(d)))))));
                        var prnum: f32 = opq(fma(opq(2.1f), opq(ri), opq(1.0f)));
                        prnum = opq(min(prnum, prmax));
                        mem_st(((SCRB + 1188u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1254u) + bitcast<u32>(k))))) * (opq(prnum)))));
                    }
                    mem_st(((SCRB + 1188u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1188u) + bitcast<u32>(k))))) + (opq(xkzminm)))));
                    mem_st(((SCRB + 1254u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1254u) + bitcast<u32>(k))))) + (opq(xkzminh)))));
                    mem_st(((SCRB + 1188u) + bitcast<u32>(k)), bitcast<u32>(opq(min(bitcast<f32>(mem_ld(((SCRB + 1188u) + bitcast<u32>(k)))), xkzmax))));
                    mem_st(((SCRB + 1254u) + bitcast<u32>(k)), bitcast<u32>(opq(min(bitcast<f32>(mem_ld(((SCRB + 1254u) + bitcast<u32>(k)))), xkzmax))));
                    mem_st(((SCRB + 1386u) + bitcast<u32>(k)), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 1188u) + bitcast<u32>(k))))));
                    mem_st(((SCRB + 1452u) + bitcast<u32>(k)), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 1254u) + bitcast<u32>(k))))));
                }
            continuing {
                k = (k + 1i);
            }
        }
    }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 1518u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 1584u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 1650u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 1716u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 1782u + _z, 0u); }
    for (var _z = 0u; _z < 66u; _z++) { mem_st(SCRB + 1848u + _z, 0u); }
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= kte))) { break; }
                mem_st(((SCRB + 1650u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
                mem_st(((SCRB + 1518u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
                mem_st(((SCRB + 1584u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
                mem_st(((SCRB + 1716u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
            continuing {
                k = (k + 1i);
            }
        }
    }
    mem_st(((SCRB + 1584u) + bitcast<u32>(1i)), bitcast<u32>(1.0f));
    mem_st(((SCRB + 1716u) + bitcast<u32>(1i)), bitcast<u32>(opq(fma(opq(div_cr(div_cr(hfx, cont), bitcast<f32>(mem_ld(((SCRB + 990u) + bitcast<u32>(1i)))))), opq(dt2), opq((bitcast<f32>(mem_ld(((SCRB + 660u) + bitcast<u32>(1i))))) - (opq(3e+02f)))))));
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= (kte - 1i)))) { break; }
                var dtodsd: f32 = div_cr(dt2, bitcast<f32>(mem_ld(((SCRB + 990u) + bitcast<u32>(k)))));
                var dtodsu: f32 = div_cr(dt2, bitcast<f32>(mem_ld(((SCRB + 990u) + bitcast<u32>((k + 1i))))));
                var dsig: f32 = opq((bitcast<f32>(mem_ld(((SCRB + 396u) + bitcast<u32>(k))))) - (bitcast<f32>(mem_ld(((SCRB + 396u) + bitcast<u32>((k + 1i)))))));
                var rdz: f32 = div_cr(1.0f, bitcast<f32>(mem_ld(((SCRB + 924u) + bitcast<u32>((k + 1i))))));
                var tem1: f32 = opq((opq((opq(dsig)) * (bitcast<f32>(mem_ld(((SCRB + 1254u) + bitcast<u32>(k))))))) * (opq(rdz)));
                if ((pblflg && (k < kpbl))) {
                    var dsdzt: f32 = opq((opq(tem1)) * (opq((opq((-(opq((div_cr(hgamt, hpbl))))))) - (opq(div_cr(opq((opq(hfxpbl)) * (bitcast<f32>(mem_ld(((SCRB + 1122u) + bitcast<u32>(k)))))), bitcast<f32>(mem_ld(((SCRB + 1254u) + bitcast<u32>(k))))))))));
                    mem_st(((SCRB + 1716u) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq(dtodsd), opq(dsdzt), bitcast<f32>(mem_ld(((SCRB + 1716u) + bitcast<u32>(k))))))));
                    mem_st(((SCRB + 1716u) + bitcast<u32>((k + 1i))), bitcast<u32>(opq(fma(opq(f_rr_neg(dtodsu, zero)), opq(dsdzt), opq((bitcast<f32>(mem_ld(((SCRB + 660u) + bitcast<u32>((k + 1i)))))) - (opq(3e+02f)))))));
                } else {
                    if (((pblflg && (k >= kpbl)) && ((bitcast<f32>(mem_ld(((SCRB + 1056u) + bitcast<u32>(k))))) < 4.6f))) {
                        var x: f32 = opq((opq((opq((-(opq(we))))) * (bitcast<f32>(mem_ld(((SCRB + 924u) + bitcast<u32>(kpbl))))))) * (opq(f_rr_exp_cr(opq((-(bitcast<f32>(mem_ld(((SCRB + 1056u) + bitcast<u32>(k)))))))))));
                        x = sqrt_cr(opq((opq(x)) * (bitcast<f32>(mem_ld(((SCRB + 1452u) + bitcast<u32>(k)))))));
                        x = opq(max(x, xkzminh));
                        mem_st(((SCRB + 1254u) + bitcast<u32>(k)), bitcast<u32>(opq(min(x, xkzmax))));
                        mem_st(((SCRB + 1716u) + bitcast<u32>((k + 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 660u) + bitcast<u32>((k + 1i)))))) - (opq(3e+02f)))));
                    } else {
                        mem_st(((SCRB + 1716u) + bitcast<u32>((k + 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 660u) + bitcast<u32>((k + 1i)))))) - (opq(3e+02f)))));
                    }
                }
                tem1 = opq((opq((opq(dsig)) * (bitcast<f32>(mem_ld(((SCRB + 1254u) + bitcast<u32>(k))))))) * (opq(rdz)));
                var dsdz2: f32 = opq((opq(tem1)) * (opq(rdz)));
                mem_st(((SCRB + 1650u) + bitcast<u32>(k)), bitcast<u32>(opq((opq(f_rr_neg(dtodsd, zero))) * (opq(dsdz2)))));
                mem_st(((SCRB + 1518u) + bitcast<u32>(k)), bitcast<u32>(opq((opq(f_rr_neg(dtodsu, zero))) * (opq(dsdz2)))));
                mem_st(((SCRB + 1584u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1584u) + bitcast<u32>(k))))) - (bitcast<f32>(mem_ld(((SCRB + 1650u) + bitcast<u32>(k))))))));
                mem_st(((SCRB + 1584u) + bitcast<u32>((k + 1i))), bitcast<u32>(opq((opq(1.0f)) - (bitcast<f32>(mem_ld(((SCRB + 1518u) + bitcast<u32>(k))))))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    f_ysu_tridiag_10((SCRB + 1518u), (SCRB + 1584u), (SCRB + 1650u), (SCRB + 1716u), kte);
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= kte))) { break; }
                var ttend: f32 = opq((opq((opq((opq((bitcast<f32>(mem_ld(((SCRB + 1716u) + bitcast<u32>(k))))) - (bitcast<f32>(mem_ld(((SCRB + 660u) + bitcast<u32>(k))))))) + (opq(3e+02f)))) * (opq(rdt)))) * (bitcast<f32>(mem_ld(((SCRB + 528u) + bitcast<u32>(k))))));
                mem_st((pout + bitcast<u32>((((((2i) * (g.nz + 1i)) + (k - 1i)) * pc.nc) + c))), bitcast<u32>(div_cr(ttend, bitcast<f32>(mem_ld(((SCRB + 528u) + bitcast<u32>(k)))))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= kte))) { break; }
                mem_st(((SCRB + 1650u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
                mem_st(((SCRB + 1518u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
                mem_st(((SCRB + 1584u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
                mem_st(((SCRB + 1716u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
                mem_st(((SCRB + 1782u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
                mem_st(((SCRB + 1848u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
            continuing {
                k = (k + 1i);
            }
        }
    }
    mem_st(((SCRB + 1584u) + bitcast<u32>(1i)), bitcast<u32>(1.0f));
    mem_st(((SCRB + 1716u) + bitcast<u32>(1i)), bitcast<u32>(opq(fma(opq(div_cr(opq((opq(qfx)) * (opq(g0))), bitcast<f32>(mem_ld(((SCRB + 990u) + bitcast<u32>(1i)))))), opq(dt2), bitcast<f32>(mem_ld(((SCRB + 198u) + bitcast<u32>(1i))))))));
    mem_st(((SCRB + 1782u) + bitcast<u32>(1i)), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 264u) + bitcast<u32>(1i))))));
    mem_st(((SCRB + 1848u) + bitcast<u32>(1i)), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 330u) + bitcast<u32>(1i))))));
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= (kte - 1i)))) { break; }
                if ((k >= kpbl)) {
                    mem_st(((SCRB + 1320u) + bitcast<u32>(k)), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 1254u) + bitcast<u32>(k))))));
                }
            continuing {
                k = (k + 1i);
            }
        }
    }
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= (kte - 1i)))) { break; }
                var dtodsd: f32 = div_cr(dt2, bitcast<f32>(mem_ld(((SCRB + 990u) + bitcast<u32>(k)))));
                var dtodsu: f32 = div_cr(dt2, bitcast<f32>(mem_ld(((SCRB + 990u) + bitcast<u32>((k + 1i))))));
                var dsig: f32 = opq((bitcast<f32>(mem_ld(((SCRB + 396u) + bitcast<u32>(k))))) - (bitcast<f32>(mem_ld(((SCRB + 396u) + bitcast<u32>((k + 1i)))))));
                var rdz: f32 = div_cr(1.0f, bitcast<f32>(mem_ld(((SCRB + 924u) + bitcast<u32>((k + 1i))))));
                var tem1: f32 = opq((opq((opq(dsig)) * (bitcast<f32>(mem_ld(((SCRB + 1320u) + bitcast<u32>(k))))))) * (opq(rdz)));
                if ((pblflg && (k < kpbl))) {
                    var dsdzq: f32 = opq((opq(tem1)) * (opq((-(opq((div_cr(opq((opq(qfxpbl)) * (bitcast<f32>(mem_ld(((SCRB + 1122u) + bitcast<u32>(k)))))), bitcast<f32>(mem_ld(((SCRB + 1320u) + bitcast<u32>(k))))))))))));
                    mem_st(((SCRB + 1716u) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq(dtodsd), opq(dsdzq), bitcast<f32>(mem_ld(((SCRB + 1716u) + bitcast<u32>(k))))))));
                    mem_st(((SCRB + 1716u) + bitcast<u32>((k + 1i))), bitcast<u32>(opq(fma(opq(f_rr_neg(dtodsu, zero)), opq(dsdzq), bitcast<f32>(mem_ld(((SCRB + 198u) + bitcast<u32>((k + 1i)))))))));
                } else {
                    if (((pblflg && (k >= kpbl)) && ((bitcast<f32>(mem_ld(((SCRB + 1056u) + bitcast<u32>(k))))) < 4.6f))) {
                        var x: f32 = opq((opq((opq((-(opq(we))))) * (bitcast<f32>(mem_ld(((SCRB + 924u) + bitcast<u32>(kpbl))))))) * (opq(f_rr_exp_cr(opq((-(bitcast<f32>(mem_ld(((SCRB + 1056u) + bitcast<u32>(k)))))))))));
                        x = sqrt_cr(opq((opq(x)) * (bitcast<f32>(mem_ld(((SCRB + 1452u) + bitcast<u32>(k)))))));
                        x = opq(max(x, xkzminh));
                        mem_st(((SCRB + 1320u) + bitcast<u32>(k)), bitcast<u32>(opq(min(x, xkzmax))));
                        mem_st(((SCRB + 1716u) + bitcast<u32>((k + 1i))), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 198u) + bitcast<u32>((k + 1i)))))));
                    } else {
                        mem_st(((SCRB + 1716u) + bitcast<u32>((k + 1i))), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 198u) + bitcast<u32>((k + 1i)))))));
                    }
                }
                tem1 = opq((opq((opq(dsig)) * (bitcast<f32>(mem_ld(((SCRB + 1320u) + bitcast<u32>(k))))))) * (opq(rdz)));
                var dsdz2: f32 = opq((opq(tem1)) * (opq(rdz)));
                mem_st(((SCRB + 1650u) + bitcast<u32>(k)), bitcast<u32>(opq((opq(f_rr_neg(dtodsd, zero))) * (opq(dsdz2)))));
                mem_st(((SCRB + 1518u) + bitcast<u32>(k)), bitcast<u32>(opq((opq(f_rr_neg(dtodsu, zero))) * (opq(dsdz2)))));
                mem_st(((SCRB + 1584u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1584u) + bitcast<u32>(k))))) - (bitcast<f32>(mem_ld(((SCRB + 1650u) + bitcast<u32>(k))))))));
                mem_st(((SCRB + 1584u) + bitcast<u32>((k + 1i))), bitcast<u32>(opq((opq(1.0f)) - (bitcast<f32>(mem_ld(((SCRB + 1518u) + bitcast<u32>(k))))))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= (kte - 1i)))) { break; }
                mem_st(((SCRB + 1782u) + bitcast<u32>((k + 1i))), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 264u) + bitcast<u32>((k + 1i)))))));
                mem_st(((SCRB + 1848u) + bitcast<u32>((k + 1i))), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 330u) + bitcast<u32>((k + 1i)))))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    f_ysu_tridiag_10((SCRB + 1518u), (SCRB + 1584u), (SCRB + 1650u), (SCRB + 1716u), kte);
    f_ysu_tridiag_10((SCRB + 1518u), (SCRB + 1584u), (SCRB + 1650u), (SCRB + 1782u), kte);
    f_ysu_tridiag_10((SCRB + 1518u), (SCRB + 1584u), (SCRB + 1650u), (SCRB + 1848u), kte);
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= kte))) { break; }
                mem_st((pout + bitcast<u32>((((((3i) * (g.nz + 1i)) + (k - 1i)) * pc.nc) + c))), bitcast<u32>(opq((opq((bitcast<f32>(mem_ld(((SCRB + 1716u) + bitcast<u32>(k))))) - (bitcast<f32>(mem_ld(((SCRB + 198u) + bitcast<u32>(k))))))) * (opq(rdt)))));
                mem_st((pout + bitcast<u32>((((((4i) * (g.nz + 1i)) + (k - 1i)) * pc.nc) + c))), bitcast<u32>(opq((opq((bitcast<f32>(mem_ld(((SCRB + 1782u) + bitcast<u32>(k))))) - (bitcast<f32>(mem_ld(((SCRB + 264u) + bitcast<u32>(k))))))) * (opq(rdt)))));
                mem_st((pout + bitcast<u32>((((((5i) * (g.nz + 1i)) + (k - 1i)) * pc.nc) + c))), bitcast<u32>(opq((opq((bitcast<f32>(mem_ld(((SCRB + 1848u) + bitcast<u32>(k))))) - (bitcast<f32>(mem_ld(((SCRB + 330u) + bitcast<u32>(k))))))) * (opq(rdt)))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= kte))) { break; }
                mem_st(((SCRB + 1650u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
                mem_st(((SCRB + 1518u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
                mem_st(((SCRB + 1584u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
                mem_st(((SCRB + 1716u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
                mem_st(((SCRB + 1782u) + bitcast<u32>(k)), bitcast<u32>(0.0f));
            continuing {
                k = (k + 1i);
            }
        }
    }
    {
        var r: f32 = div_cr(wspd1, wspd);
        var fric: f32 = opq((opq((opq(div_cr(opq((opq((opq(div_cr(opq((opq(ust)) * (opq(ust))), wspd1))) * (opq(rhox)))) * (opq(g0))), bitcast<f32>(mem_ld(((SCRB + 990u) + bitcast<u32>(1i))))))) * (opq(dt2)))) * (opq((opq(r)) * (opq(r)))));
        mem_st(((SCRB + 1584u) + bitcast<u32>(1i)), bitcast<u32>(opq((opq(1.0f)) + (opq(fric)))));
        mem_st(((SCRB + 1716u) + bitcast<u32>(1i)), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(1i))))));
        mem_st(((SCRB + 1782u) + bitcast<u32>(1i)), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 66u) + bitcast<u32>(1i))))));
    }
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= (kte - 1i)))) { break; }
                var dtodsd: f32 = div_cr(dt2, bitcast<f32>(mem_ld(((SCRB + 990u) + bitcast<u32>(k)))));
                var dtodsu: f32 = div_cr(dt2, bitcast<f32>(mem_ld(((SCRB + 990u) + bitcast<u32>((k + 1i))))));
                var dsig: f32 = opq((bitcast<f32>(mem_ld(((SCRB + 396u) + bitcast<u32>(k))))) - (bitcast<f32>(mem_ld(((SCRB + 396u) + bitcast<u32>((k + 1i)))))));
                var rdz: f32 = div_cr(1.0f, bitcast<f32>(mem_ld(((SCRB + 924u) + bitcast<u32>((k + 1i))))));
                var tem1: f32 = opq((opq((opq(dsig)) * (bitcast<f32>(mem_ld(((SCRB + 1188u) + bitcast<u32>(k))))))) * (opq(rdz)));
                if ((pblflg && (k < kpbl))) {
                    var dsdzu: f32 = opq((opq(tem1)) * (opq((opq((-(opq((div_cr(hgamu, hpbl))))))) - (opq(div_cr(opq((opq(ufxpbl)) * (bitcast<f32>(mem_ld(((SCRB + 1122u) + bitcast<u32>(k)))))), bitcast<f32>(mem_ld(((SCRB + 1188u) + bitcast<u32>(k))))))))));
                    var dsdzv: f32 = opq((opq(tem1)) * (opq((opq((-(opq((div_cr(hgamv, hpbl))))))) - (opq(div_cr(opq((opq(vfxpbl)) * (bitcast<f32>(mem_ld(((SCRB + 1122u) + bitcast<u32>(k)))))), bitcast<f32>(mem_ld(((SCRB + 1188u) + bitcast<u32>(k))))))))));
                    mem_st(((SCRB + 1716u) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq(dtodsd), opq(dsdzu), bitcast<f32>(mem_ld(((SCRB + 1716u) + bitcast<u32>(k))))))));
                    mem_st(((SCRB + 1716u) + bitcast<u32>((k + 1i))), bitcast<u32>(opq(fma(opq(f_rr_neg(dtodsu, zero)), opq(dsdzu), bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>((k + 1i)))))))));
                    mem_st(((SCRB + 1782u) + bitcast<u32>(k)), bitcast<u32>(opq(fma(opq(dtodsd), opq(dsdzv), bitcast<f32>(mem_ld(((SCRB + 1782u) + bitcast<u32>(k))))))));
                    mem_st(((SCRB + 1782u) + bitcast<u32>((k + 1i))), bitcast<u32>(opq(fma(opq(f_rr_neg(dtodsu, zero)), opq(dsdzv), bitcast<f32>(mem_ld(((SCRB + 66u) + bitcast<u32>((k + 1i)))))))));
                } else {
                    if (((pblflg && (k >= kpbl)) && ((bitcast<f32>(mem_ld(((SCRB + 1056u) + bitcast<u32>(k))))) < 4.6f))) {
                        var x: f32 = bitcast<f32>(mem_ld(((SCRB + 1254u) + bitcast<u32>(k))));
                        x = sqrt_cr(opq((opq(x)) * (bitcast<f32>(mem_ld(((SCRB + 1386u) + bitcast<u32>(k)))))));
                        x = opq(max(x, xkzminm));
                        mem_st(((SCRB + 1188u) + bitcast<u32>(k)), bitcast<u32>(opq(min(x, xkzmax))));
                        mem_st(((SCRB + 1716u) + bitcast<u32>((k + 1i))), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>((k + 1i)))))));
                        mem_st(((SCRB + 1782u) + bitcast<u32>((k + 1i))), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 66u) + bitcast<u32>((k + 1i)))))));
                    } else {
                        mem_st(((SCRB + 1716u) + bitcast<u32>((k + 1i))), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>((k + 1i)))))));
                        mem_st(((SCRB + 1782u) + bitcast<u32>((k + 1i))), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 66u) + bitcast<u32>((k + 1i)))))));
                    }
                }
                tem1 = opq((opq((opq(dsig)) * (bitcast<f32>(mem_ld(((SCRB + 1188u) + bitcast<u32>(k))))))) * (opq(rdz)));
                var dsdz2: f32 = opq((opq(tem1)) * (opq(rdz)));
                mem_st(((SCRB + 1650u) + bitcast<u32>(k)), bitcast<u32>(opq((opq(f_rr_neg(dtodsd, zero))) * (opq(dsdz2)))));
                mem_st(((SCRB + 1518u) + bitcast<u32>(k)), bitcast<u32>(opq((opq(f_rr_neg(dtodsu, zero))) * (opq(dsdz2)))));
                mem_st(((SCRB + 1584u) + bitcast<u32>(k)), bitcast<u32>(opq((bitcast<f32>(mem_ld(((SCRB + 1584u) + bitcast<u32>(k))))) - (bitcast<f32>(mem_ld(((SCRB + 1650u) + bitcast<u32>(k))))))));
                mem_st(((SCRB + 1584u) + bitcast<u32>((k + 1i))), bitcast<u32>(opq((opq(1.0f)) - (bitcast<f32>(mem_ld(((SCRB + 1518u) + bitcast<u32>(k))))))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    f_ysu_tridiag_10((SCRB + 1518u), (SCRB + 1584u), (SCRB + 1650u), (SCRB + 1716u), kte);
    f_ysu_tridiag_10((SCRB + 1518u), (SCRB + 1584u), (SCRB + 1650u), (SCRB + 1782u), kte);
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= kte))) { break; }
                mem_st((pout + bitcast<u32>((((((0i) * (g.nz + 1i)) + (k - 1i)) * pc.nc) + c))), bitcast<u32>(opq((opq((bitcast<f32>(mem_ld(((SCRB + 1716u) + bitcast<u32>(k))))) - (bitcast<f32>(mem_ld(((SCRB + 0u) + bitcast<u32>(k))))))) * (opq(rdt)))));
                mem_st((pout + bitcast<u32>((((((1i) * (g.nz + 1i)) + (k - 1i)) * pc.nc) + c))), bitcast<u32>(opq((opq((bitcast<f32>(mem_ld(((SCRB + 1782u) + bitcast<u32>(k))))) - (bitcast<f32>(mem_ld(((SCRB + 66u) + bitcast<u32>(k))))))) * (opq(rdt)))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= (kte - 1i)))) { break; }
                mem_st((pout + bitcast<u32>((((((6i) * (g.nz + 1i)) + k) * pc.nc) + c))), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 1254u) + bitcast<u32>(k))))));
                mem_st((pout + bitcast<u32>((((((7i) * (g.nz + 1i)) + k) * pc.nc) + c))), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 1320u) + bitcast<u32>(k))))));
                mem_st((pout + bitcast<u32>((((((8i) * (g.nz + 1i)) + k) * pc.nc) + c))), bitcast<u32>(bitcast<f32>(mem_ld(((SCRB + 1188u) + bitcast<u32>(k))))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    mem_st((sfc + bitcast<u32>((((23i) * plane) + o))), bitcast<u32>(hpbl));
    mem_st((sfc + bitcast<u32>((((64i) * plane) + o))), bitcast<u32>(f32(kpbl)));
    mem_st((sfc + bitcast<u32>((((63i) * plane) + o))), bitcast<u32>(brcr));
    mem_st((sfc + bitcast<u32>((((65i) * plane) + o))), bitcast<u32>(wstar));
    mem_st((sfc + bitcast<u32>((((66i) * plane) + o))), bitcast<u32>(delta));
    mem_st((sfc + bitcast<u32>((((67i) * plane) + o))), bitcast<u32>(prkpp));
}
