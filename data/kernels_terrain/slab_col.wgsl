// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// slab_col: сгенерировано, не править руками.

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

const K_SLAB_SOILFAC: f32 = 1.25f;

const K_SLAB_DIFSL: f32 = 5e-07f;

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
    var t1d: f32 = bitcast<f32>(mem_ld((pin + bitcast<u32>((((((3i) * (g.nz + 1i)) + (0i)) * pc.nc) + c)))));
    var qx: f32 = bitcast<f32>(mem_ld((pin + bitcast<u32>((((((4i) * (g.nz + 1i)) + (0i)) * pc.nc) + c)))));
    var p1d: f32 = bitcast<f32>(mem_ld((pin + bitcast<u32>((((((7i) * (g.nz + 1i)) + (0i)) * pc.nc) + c)))));
    var psfcpa: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((11i) * plane) + o)))));
    var xland: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((17i) * plane) + o)))));
    var psfc: f32 = div_cr(psfcpa, 1e+03f);
    var pl: f32 = div_cr(p1d, 1e+03f);
    var thx: f32 = opq((opq(t1d)) * (opq(f_rr_pow_cr(div_cr(opq((opq(pc.p1000mb)) * (opq(0.001f))), pl), pc.rovcp))));
    var dzs: array<f32, 5>;
    var zs: array<f32, 5>;
    (*&dzs)[0i] = 0.01f;
    (*&zs)[0i] = opq((opq(0.5f)) * (opq((*&dzs)[0i])));
    {
        var l: i32 = 1i;
        loop {
            if (!((l < 5i))) { break; }
                (*&dzs)[l] = opq((opq(2.0f)) * (opq((*&dzs)[(l - 1i)])));
                (*&zs)[l] = opq(fma(opq(0.5f), opq((*&dzs)[l]), opq(fma(opq(0.5f), opq((*&dzs)[(l - 1i)]), opq((*&zs)[(l - 1i)])))));
            continuing {
                l = (l + 1i);
            }
        }
    }
    var capg: f32 = opq((opq(5.9114e+07f)) * (bitcast<f32>(mem_ld((sfc + bitcast<u32>((((21i) * plane) + o)))))));
    mem_st((sfc + bitcast<u32>((((61i) * plane) + o))), bitcast<u32>(capg));
    var hfx: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((31i) * plane) + o)))));
    var qfx: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((32i) * plane) + o)))));
    var flhc: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((34i) * plane) + o)))));
    var flqc: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((35i) * plane) + o)))));
    if (((opq((opq(xland)) - (opq(1.5f)))) < 0.0f)) {
        var tsk: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((13i) * plane) + o)))));
        var tg0: f32 = tsk;
        var upflux: f32 = opq((opq(5.67051e-08f)) * (opq((opq((opq(tg0)) * (opq(tg0)))) * (opq((opq(tg0)) * (opq(tg0)))))));
        var xinet: f32 = opq((bitcast<f32>(mem_ld((sfc + bitcast<u32>((((20i) * plane) + o)))))) * (opq((bitcast<f32>(mem_ld((sfc + bitcast<u32>((((60i) * plane) + o)))))) - (opq(upflux)))));
        var rnet: f32 = opq((bitcast<f32>(mem_ld((sfc + bitcast<u32>((((59i) * plane) + o)))))) + (opq(xinet)));
        var esg: f32 = opq((opq(pc.svp1)) * (opq(f_rr_exp_cr(div_cr(opq((opq(pc.svp2)) * (opq((opq(tg0)) - (opq(pc.svpt0))))), (opq((opq(tg0)) - (opq(pc.svp3)))))))));
        var qsg: f32 = div_cr(opq((opq(pc.ep2)) * (opq(esg))), (opq((opq(psfc)) - (opq(esg)))));
        hfx = opq((opq(flhc)) * (opq(fma(opq(tsk), opq(f_rr_pow_cr(div_cr(1e+02f, psfc), pc.rovcp)), opq((-(opq(thx))))))));
        qfx = opq((opq(flqc)) * (opq((opq(qsg)) - (opq(qx)))));
        var lfac: f32 = opq(fma(opq((-(opq(pc.lv2)))), opq(tsk), opq(pc.lv1)));
        var qs: f32 = opq(fma(opq(qfx), opq(lfac), opq(hfx)));
        var dthgdt: f32 = 0.0f;
        var nsoil: i32 = (1i + (i32(div_cr(opq((opq(div_cr(opq((opq((opq(K_SLAB_SOILFAC)) * (opq(4.0f)))) * (opq(K_SLAB_DIFSL))), (*&dzs)[0i]))) * (opq(pc.dt))), (*&dzs)[0i]))));
        var rnsoil: f32 = div_cr(1.0f, f32(nsoil));
        var tslb: array<f32, 5>;
        {
            var l: i32 = 0i;
            loop {
                if (!((l < 5i))) { break; }
                    (*&tslb)[l] = bitcast<f32>(mem_ld((sfc + bitcast<u32>((((68i + l) * plane) + o)))));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        var flux: array<f32, 5>;
        {
            var it: i32 = 1i;
            loop {
                if (!((it <= nsoil))) { break; }
                    {
                        var l: i32 = 0i;
                        loop {
                            if (!((l < 4i))) { break; }
                                var qsl: f32 = qs;
                                if (((l == 0i) && (it > 1i))) {
                                    var ps1: f32 = f_rr_pow_cr(div_cr(psfcpa, pc.p1000mb), pc.rovcp);
                                    var thgl: f32 = div_cr((*&tslb)[0i], ps1);
                                    var esgl: f32 = opq((opq(pc.svp1)) * (opq(f_rr_exp_cr(div_cr(opq((opq(pc.svp2)) * (opq((opq((*&tslb)[0i])) - (opq(pc.svpt0))))), (opq((opq((*&tslb)[0i])) - (opq(pc.svp3)))))))));
                                    var qsgl: f32 = div_cr(opq((opq(pc.ep2)) * (opq(esgl))), (opq((opq(psfc)) - (opq(esgl)))));
                                    var hfxt: f32 = opq((opq(flhc)) * (opq((opq(thgl)) - (opq(thx)))));
                                    var qfxt: f32 = opq((opq(flqc)) * (opq((opq(qsgl)) - (opq(qx)))));
                                    qsl = opq(fma(opq(qfxt), opq(lfac), opq(hfxt)));
                                    hfx = opq((opq(hfx)) + (opq(hfxt)));
                                    qfx = opq((opq(qfx)) + (opq(qfxt)));
                                }
                                (*&flux)[0i] = opq((opq(rnet)) - (opq(qsl)));
                                (*&flux)[(l + 1i)] = div_cr(opq((opq((opq((-(opq(K_SLAB_DIFSL))))) * (opq(capg)))) * (opq((opq((*&tslb)[(l + 1i)])) - (opq((*&tslb)[l]))))), (opq((opq((*&zs)[(l + 1i)])) - (opq((*&zs)[l])))));
                                var dtsdt: f32 = div_cr(opq((-(opq((opq((*&flux)[(l + 1i)])) - (opq((*&flux)[l])))))), (opq((opq((*&dzs)[l])) * (opq(capg)))));
                                (*&tslb)[l] = opq(fma(opq((opq(dtsdt)) * (opq(pc.dt))), opq(rnsoil), opq((*&tslb)[l])));
                                if ((l == 0i)) {
                                    dthgdt = opq(fma(opq(rnsoil), opq(dtsdt), opq(dthgdt)));
                                }
                                if (((it == nsoil) && (l == 0i))) {
                                    hfx = opq((opq(hfx)) * (opq(rnsoil)));
                                    qfx = opq((opq(qfx)) * (opq(rnsoil)));
                                    mem_st((sfc + bitcast<u32>((((33i) * plane) + o))), bitcast<u32>(opq((opq(qfx)) * (opq(lfac)))));
                                }
                            continuing {
                                l = (l + 1i);
                            }
                        }
                    }
                continuing {
                    it = (it + 1i);
                }
            }
        }
        {
            var l: i32 = 0i;
            loop {
                if (!((l < 4i))) { break; }
                    mem_st((sfc + bitcast<u32>((((68i + l) * plane) + o))), bitcast<u32>((*&tslb)[l]));
                continuing {
                    l = (l + 1i);
                }
            }
        }
        tsk = opq(fma(opq(pc.dt), opq(dthgdt), opq(tg0)));
        mem_st((sfc + bitcast<u32>((((13i) * plane) + o))), bitcast<u32>(tsk));
        mem_st((sfc + bitcast<u32>((((31i) * plane) + o))), bitcast<u32>(hfx));
        mem_st((sfc + bitcast<u32>((((32i) * plane) + o))), bitcast<u32>(qfx));
    }
    mem_st((sfc + bitcast<u32>((((12i) * plane) + o))), bitcast<u32>(select(qx, opq((opq(qx)) + (opq(div_cr(qfx, flqc)))), (flqc != 0.0f))));
    mem_st((sfc + bitcast<u32>((((62i) * plane) + o))), bitcast<u32>(bitcast<f32>(mem_ld((sfc + bitcast<u32>((((18i) * plane) + o)))))));
}
