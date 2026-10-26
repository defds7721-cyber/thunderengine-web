// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// sfc_cecd: сгенерировано, не править руками.

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

struct S_SfcFluxParams {
    za: f32,
    cnstcd: f32,
    cnstce: f32,
    xland: f32,
    mavail: f32,
    cgs1: f32,
    cgs2: f32,
    cgs3: f32,
    setZnt: i32,
    cecd: i32,
    isfcflx: i32,
    moist: i32,
    setUst: i32,
    setFlx: i32,
    cnstUst: f32,
    cnstShflx: f32,
    cnstLhflx: f32,
    cutoff: f32,
    rtime: f32,
    testcase: i32,
}

const K_SFC_KARMAN: f32 = 0.4f;

const K_SFC_DCD1: f32 = 0.001f;

const K_SFC_DWSP1: f32 = 5.0f;

const K_SFC_DFAC: f32 = 7e-05f;

const K_SFC_DCD2: f32 = 0.0024f;

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

fn ld_SfcFluxParams(o: u32) -> S_SfcFluxParams {
    var s: S_SfcFluxParams;
    s.za = bitcast<f32>(mem_ld((o + 0u)));
    s.cnstcd = bitcast<f32>(mem_ld((o + 1u)));
    s.cnstce = bitcast<f32>(mem_ld((o + 2u)));
    s.xland = bitcast<f32>(mem_ld((o + 3u)));
    s.mavail = bitcast<f32>(mem_ld((o + 4u)));
    s.cgs1 = bitcast<f32>(mem_ld((o + 5u)));
    s.cgs2 = bitcast<f32>(mem_ld((o + 6u)));
    s.cgs3 = bitcast<f32>(mem_ld((o + 7u)));
    s.setZnt = bitcast<i32>(mem_ld((o + 8u)));
    s.cecd = bitcast<i32>(mem_ld((o + 9u)));
    s.isfcflx = bitcast<i32>(mem_ld((o + 10u)));
    s.moist = bitcast<i32>(mem_ld((o + 11u)));
    s.setUst = bitcast<i32>(mem_ld((o + 12u)));
    s.setFlx = bitcast<i32>(mem_ld((o + 13u)));
    s.cnstUst = bitcast<f32>(mem_ld((o + 14u)));
    s.cnstShflx = bitcast<f32>(mem_ld((o + 15u)));
    s.cnstLhflx = bitcast<f32>(mem_ld((o + 16u)));
    s.cutoff = bitcast<f32>(mem_ld((o + 17u)));
    s.rtime = bitcast<f32>(mem_ld((o + 18u)));
    s.testcase = bitcast<i32>(mem_ld((o + 19u)));
    return s;
}

fn f_gidx(g_in: S_GridDims, i_in: i32, j_in: i32, k_in: i32) -> i32 {
    var g: S_GridDims = g_in;
    var i: i32 = i_in;
    var j: i32 = j_in;
    var k: i32 = k_in;
    return ((i + 3i) + (g.strideJ * ((j + 3i) + (g.strideK * k))));
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

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    var g: S_GridDims = ld_GridDims(ARG[4]);
    var p: S_SfcFluxParams = ld_SfcFluxParams(ARG[5]);
    var sfc: u32 = ARG[6];
    var tid: vec2<u32> = gid.xy;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    if (((i >= g.nx) || (j >= g.ny))) {
        return;
    }
    var plane: i32 = (g.strideJ * g.strideK);
    var o: i32 = f_gidx(g, i, j, 0i);
    var karman: f32 = K_SFC_KARMAN;
    var za: f32 = p.za;
    var s1: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>(((2i * plane) + o)))));
    var znt: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>(((4i * plane) + o)))));
    var cd: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>(((5i * plane) + o)))));
    var s10: f32;
    var rznt: f32;
    var var_v: f32;
    var ust: f32;
    if ((p.setZnt != 0i)) {
        rznt = div_cr(1.0f, znt);
        var l10: f32 = f_rr_log_cr(opq((opq(1e+01f)) * (opq(rznt))));
        cd = opq((opq((div_cr(karman, l10)))) * (opq((div_cr(karman, l10)))));
        var_v = div_cr(l10, f_rr_log_cr(opq((opq(za)) * (opq(rznt)))));
        s10 = opq((opq(s1)) * (opq(var_v)));
        ust = opq(max(div_cr(opq((opq(s1)) * (opq(karman))), f_rr_log_cr(opq((opq(za)) * (opq(rznt))))), 1e-06f));
    } else {
        if ((p.setUst != 0i)) {
            ust = p.cnstUst;
            znt = div_cr(za, (opq((opq(f_rr_exp_cr(div_cr(opq((opq(max(1e-10f, s1))) * (opq(karman))), opq(max(1e-10f, ust)))))) - (opq(1.0f)))));
            rznt = div_cr(1.0f, znt);
            var l: f32 = f_rr_log_cr(opq((opq((opq(1e+01f)) + (opq(znt)))) * (opq(rznt))));
            cd = opq((opq((div_cr(karman, l)))) * (opq((div_cr(karman, l)))));
            var_v = div_cr(l, f_rr_log_cr(opq((opq((opq(za)) + (opq(znt)))) * (opq(rznt)))));
            s10 = opq((opq(s1)) * (opq(var_v)));
        } else {
            if ((p.cecd == 1i)) {
                cd = opq(max(1e-10f, p.cnstcd));
                znt = div_cr(1e+01f, (opq((opq(f_rr_exp_cr(div_cr(karman, sqrt_cr(cd))))) - (opq(1.0f)))));
                rznt = div_cr(1.0f, znt);
                var_v = div_cr(f_rr_log_cr(opq((opq((opq(1e+01f)) + (opq(znt)))) * (opq(rznt)))), f_rr_log_cr(opq((opq((opq(za)) + (opq(znt)))) * (opq(rznt)))));
                s10 = opq((opq(s1)) * (opq(var_v)));
                ust = opq(max(div_cr(opq((opq(s1)) * (opq(karman))), f_rr_log_cr(opq((opq((opq(za)) + (opq(znt)))) * (opq(rznt))))), 1e-06f));
            } else {
                if ((p.xland > 1.5f)) {
                    rznt = div_cr(1.0f, znt);
                    var_v = div_cr(f_rr_log_cr(opq((opq((opq(1e+01f)) + (opq(znt)))) * (opq(rznt)))), f_rr_log_cr(opq((opq((opq(za)) + (opq(znt)))) * (opq(rznt)))));
                    s10 = opq((opq(s1)) * (opq(var_v)));
                    var wlast: f32 = opq((-(opq(1e+03f))));
                    var n: i32 = 0i;
                    loop {
                        if (!(((abs(opq((opq(s10)) - (opq(wlast))))) > 0.001f))) { break; }
                            n = (n + 1i);
                            wlast = s10;
                            if ((p.cecd == 2i)) {
                                cd = opq(fma(opq(4e-05f), opq(s10), opq(0.0011f)));
                            } else {
                                if ((p.cecd == 3i)) {
                                    cd = opq(fma((opq((opq(s10)) - (opq(K_SFC_DWSP1)))), opq(K_SFC_DFAC), opq(K_SFC_DCD1)));
                                    cd = opq(min(cd, K_SFC_DCD2));
                                    cd = opq(max(cd, K_SFC_DCD1));
                                }
                            }
                            znt = opq(max(1e-20f, div_cr(1e+01f, (opq((opq(f_rr_exp_cr(div_cr(karman, sqrt_cr(cd))))) - (opq(1.0f)))))));
                            rznt = div_cr(1.0f, znt);
                            var_v = div_cr(f_rr_log_cr(opq((opq((opq(1e+01f)) + (opq(znt)))) * (opq(rznt)))), f_rr_log_cr(opq((opq((opq(za)) + (opq(znt)))) * (opq(rznt)))));
                            s10 = opq((opq(s1)) * (opq(var_v)));
                            if ((n > 20i)) {
                                break;
                            }
                    }
                } else {
                    rznt = div_cr(1.0f, znt);
                    var l: f32 = f_rr_log_cr(opq((opq((opq(1e+01f)) + (opq(znt)))) * (opq(rznt))));
                    cd = opq((opq((div_cr(karman, l)))) * (opq((div_cr(karman, l)))));
                    var_v = div_cr(l, f_rr_log_cr(opq((opq((opq(za)) + (opq(znt)))) * (opq(rznt)))));
                    s10 = opq((opq(s1)) * (opq(var_v)));
                }
                ust = opq(max(div_cr(opq((opq(s1)) * (opq(karman))), f_rr_log_cr(opq((opq((opq(za)) + (opq(znt)))) * (opq(rznt))))), 1e-06f));
            }
        }
    }
    var ch: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>(((6i * plane) + o)))));
    var cq: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>(((7i * plane) + o)))));
    if ((p.isfcflx != 0i)) {
        if ((p.xland > 1.5f)) {
            if ((p.cecd == 1i)) {
                ch = p.cnstce;
                cq = p.cnstce;
            } else {
                if ((p.cecd == 2i)) {
                    ch = opq(fma(opq(4e-05f), opq(s10), opq(0.0011f)));
                    cq = opq(fma(opq(4e-05f), opq(s10), opq(0.0011f)));
                } else {
                    if ((p.cecd == 3i)) {
                        ch = 0.0012f;
                        cq = 0.0012f;
                    }
                }
            }
        } else {
            ch = cd;
            cq = cd;
        }
    }
    mem_st((sfc + bitcast<u32>(((3i * plane) + o))), bitcast<u32>(ust));
    mem_st((sfc + bitcast<u32>(((4i * plane) + o))), bitcast<u32>(znt));
    mem_st((sfc + bitcast<u32>(((5i * plane) + o))), bitcast<u32>(cd));
    mem_st((sfc + bitcast<u32>(((6i * plane) + o))), bitcast<u32>(ch));
    mem_st((sfc + bitcast<u32>(((7i * plane) + o))), bitcast<u32>(cq));
    mem_st((sfc + bitcast<u32>(((8i * plane) + o))), bitcast<u32>(s10));
}
