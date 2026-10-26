// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// turb_nm: сгенерировано, не править руками.

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

const K_MP_RD: f32 = 287.0f;

const K_MP_RV: f32 = 461.5f;

const K_MP_CP: f32 = 1004.0f;

const K_MP_CPV: f32 = 1.87e+03f;

const K_MP_CPL: f32 = 4.19e+03f;

const K_MP_LV1: f32 = 2.5e+06f;

const K_MP_LV2: f32 = 0.0f;

const K_MP_CPI: f32 = 2106.0f;

const K_MP_LS1: f32 = 2898463.5f;

const K_MP_LS2: f32 = 236.0f;

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

fn f_mp_rslf(p_in: f32, t_in: f32) -> f32 {
    var p: f32 = p_in;
    var t: f32 = t_in;
    var esl: f32 = opq((opq(611.2f)) * (opq(exp(div_cr(opq((opq(17.67f)) * (opq((opq(t)) - (opq(273.15f))))), (opq((opq(t)) - (opq(29.65f)))))))));
    esl = opq(min(esl, opq((opq(p)) * (opq(0.5f)))));
    var eps: f32 = div_cr(K_MP_RD, K_MP_RV);
    return div_cr(opq((opq(eps)) * (opq(esl))), (opq((opq(p)) - (opq(esl)))));
}

fn lam_1(qvs_in: f32, lh_in: f32, drdt_in: f32, cpml_in: f32, gAcc: ptr<function, f32>, qtavg: ptr<function, f32>, rd: ptr<function, f32>, tavg: ptr<function, f32>, dlnT: ptr<function, f32>, eps: ptr<function, f32>, dlnQt: ptr<function, f32>) -> f32 {
    var qvs: f32 = qvs_in;
    var lh: f32 = lh_in;
    var drdt: f32 = drdt_in;
    var cpml: f32 = cpml_in;
    var gamma: f32 = div_cr(opq((opq((opq((*gAcc))) * (opq((opq(1.0f)) + (opq((*qtavg))))))) * (opq((opq(1.0f)) + (opq(div_cr(opq((opq(lh)) * (opq(qvs))), (opq((opq((*rd))) * (opq((*tavg))))))))))), (opq(fma(opq(lh), opq(drdt), opq(cpml)))));
    return opq((opq((*gAcc))) * (opq(fma((opq((opq((*dlnT))) + (opq(div_cr(gamma, (*tavg)))))), (opq((opq(1.0f)) + (opq(div_cr(opq((opq((*tavg))) * (opq(drdt))), (opq((opq((*eps))) + (opq(qvs))))))))), opq((-(opq((*dlnQt)))))))));
}

fn f_mp_rsif(p_in: f32, t_in: f32) -> f32 {
    var p: f32 = p_in;
    var t: f32 = t_in;
    var esi: f32 = opq((opq(611.2f)) * (opq(exp(div_cr(opq((opq(21.874557f)) * (opq((opq(t)) - (opq(273.15f))))), (opq((opq(t)) - (opq(7.66f)))))))));
    esi = opq(min(esi, opq((opq(p)) * (opq(0.5f)))));
    var eps: f32 = div_cr(K_MP_RD, K_MP_RV);
    return div_cr(opq((opq(eps)) * (opq(esi))), (opq((opq(p)) - (opq(esi)))));
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    var g: S_GridDims = ld_GridDims(ARG[4]);
    var thPert: u32 = ARG[5];
    var ppPert: u32 = ARG[6];
    var th0: u32 = ARG[7];
    var pi0: u32 = ARG[8];
    var prs: u32 = ARG[9];
    var qv: u32 = ARG[10];
    var qc: u32 = ARG[11];
    var qr: u32 = ARG[12];
    var qi: u32 = ARG[13];
    var qs: u32 = ARG[14];
    var qg: u32 = ARG[15];
    var c1: u32 = ARG[16];
    var c2: u32 = ARG[17];
    var mf: u32 = ARG[18];
    var nm: u32 = ARG[19];
    var moist: i32 = bitcast<i32>(mem_ld(ARG[20]));
    var sat: u32 = ARG[21];
    var wantSat: i32 = bitcast<i32>(mem_ld(ARG[22]));
    var tid: vec3<u32> = gid;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    var k: i32 = ((i32(tid.z)) + 1i);
    if ((((i >= g.nx) || (j >= g.ny)) || (k > (g.nz - 1i)))) {
        return;
    }
    var c: i32 = f_gidx(g, i, j, k);
    var sk: i32 = (g.strideJ * g.strideK);
    if ((wantSat != 0i)) {
        mem_st((sat + bitcast<u32>(c)), bitcast<u32>(0.0f));
    }
    var nmsat: f32 = 1e-10f;
    var rd: f32 = K_MP_RD;
    var rv: f32 = K_MP_RV;
    var cp: f32 = K_MP_CP;
    var cpv: f32 = K_MP_CPV;
    var eps: f32 = div_cr(rd, rv);
    var reps: f32 = div_cr(rv, rd);
    var gAcc: f32 = 9.81f;
    var thA: f32 = opq((bitcast<f32>(mem_ld((th0 + bitcast<u32>((k - 1i)))))) + (bitcast<f32>(mem_ld((thPert + bitcast<u32>((c - sk)))))));
    var thB: f32 = opq((bitcast<f32>(mem_ld((th0 + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((thPert + bitcast<u32>(c))))));
    if ((moist == 0i)) {
        mem_st((nm + bitcast<u32>(c)), bitcast<u32>(opq((opq((opq((opq(f_rr_log_cr(div_cr(thB, thA)))) * (opq(gAcc)))) * (opq(g.rdz)))) * (bitcast<f32>(mem_ld((mf + bitcast<u32>(k))))))));
        return;
    }
    var piA: f32 = opq((bitcast<f32>(mem_ld((pi0 + bitcast<u32>((k - 1i)))))) + (bitcast<f32>(mem_ld((ppPert + bitcast<u32>((c - sk)))))));
    var piB: f32 = opq((bitcast<f32>(mem_ld((pi0 + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((ppPert + bitcast<u32>(c))))));
    var tA: f32 = opq((opq(thA)) * (opq(piA)));
    var tB: f32 = opq((opq(thB)) * (opq(piB)));
    var qtA: f32 = opq((opq((opq((opq((opq((bitcast<f32>(mem_ld((qv + bitcast<u32>((c - sk)))))) + (bitcast<f32>(mem_ld((qc + bitcast<u32>((c - sk)))))))) + (bitcast<f32>(mem_ld((qr + bitcast<u32>((c - sk)))))))) + (bitcast<f32>(mem_ld((qi + bitcast<u32>((c - sk)))))))) + (bitcast<f32>(mem_ld((qs + bitcast<u32>((c - sk)))))))) + (bitcast<f32>(mem_ld((qg + bitcast<u32>((c - sk)))))));
    var qtB: f32 = opq((opq((opq((opq((opq((bitcast<f32>(mem_ld((qv + bitcast<u32>(c))))) + (bitcast<f32>(mem_ld((qc + bitcast<u32>(c))))))) + (bitcast<f32>(mem_ld((qr + bitcast<u32>(c))))))) + (bitcast<f32>(mem_ld((qi + bitcast<u32>(c))))))) + (bitcast<f32>(mem_ld((qs + bitcast<u32>(c))))))) + (bitcast<f32>(mem_ld((qg + bitcast<u32>(c))))));
    var qciA: f32 = opq((opq((bitcast<f32>(mem_ld((qv + bitcast<u32>((c - sk)))))) + (bitcast<f32>(mem_ld((qc + bitcast<u32>((c - sk)))))))) + (bitcast<f32>(mem_ld((qi + bitcast<u32>((c - sk)))))));
    var qciB: f32 = opq((opq((bitcast<f32>(mem_ld((qv + bitcast<u32>(c))))) + (bitcast<f32>(mem_ld((qc + bitcast<u32>(c))))))) + (bitcast<f32>(mem_ld((qi + bitcast<u32>(c))))));
    var thvA: f32 = div_cr(opq((opq(thA)) * (opq(fma(opq(reps), bitcast<f32>(mem_ld((qv + bitcast<u32>((c - sk))))), opq(1.0f))))), (opq((opq(1.0f)) + (opq(qtA)))));
    var thvB: f32 = div_cr(opq((opq(thB)) * (opq(fma(opq(reps), bitcast<f32>(mem_ld((qv + bitcast<u32>(c)))), opq(1.0f))))), (opq((opq(1.0f)) + (opq(qtB)))));
    var rmf: f32 = opq((opq(g.rdz)) * (bitcast<f32>(mem_ld((mf + bitcast<u32>(k))))));
    var dlnT: f32 = opq((opq(f_rr_log_cr(div_cr(tB, tA)))) * (opq(rmf)));
    var dlnQt: f32 = opq((opq(f_rr_log_cr(div_cr((opq((opq(1.0f)) + (opq(qtB)))), (opq((opq(1.0f)) + (opq(qtA)))))))) * (opq(rmf)));
    var out: f32 = opq((opq((opq(gAcc)) * (opq(f_rr_log_cr(div_cr(thvB, thvA)))))) * (opq(rmf)));
    var a: f32 = bitcast<f32>(mem_ld((c1 + bitcast<u32>(k))));
    var b: f32 = bitcast<f32>(mem_ld((c2 + bitcast<u32>(k))));
    var pavg: f32 = opq(fma(opq(a), bitcast<f32>(mem_ld((prs + bitcast<u32>((c - sk))))), opq((opq(b)) * (bitcast<f32>(mem_ld((prs + bitcast<u32>(c))))))));
    var tavg: f32 = opq(fma(opq(a), opq(tA), opq((opq(b)) * (opq(tB)))));
    var qtavg: f32 = opq(fma(opq(a), opq(qtA), opq((opq(b)) * (opq(qtB)))));
    var qciavg: f32 = opq(fma(opq(a), opq(qciA), opq((opq(b)) * (opq(qciB)))));
    {
        var qvs: f32 = f_mp_rslf(pavg, tavg);
        var ql: f32 = opq(max(opq((opq(qciavg)) - (opq(qvs))), 0.0f));
        if ((ql > nmsat)) {
            if ((wantSat != 0i)) {
                mem_st((sat + bitcast<u32>(c)), bitcast<u32>(1.0f));
            }
            var qvl: f32 = opq(max(opq((opq(qciavg)) - (opq(ql))), 0.0f));
            var cpml: f32 = opq(fma(opq(K_MP_CPL), opq(ql), opq(fma(opq(cpv), opq(qvl), opq(cp)))));
            var lh: f32 = opq(fma(opq((-(opq(K_MP_LV2)))), opq(tavg), opq(K_MP_LV1)));
            var drdt: f32 = div_cr(opq((opq((opq(17.67f)) * (opq((opq(273.15f)) - (opq(29.65f)))))) * (opq(qvs))), (opq((opq((opq(tavg)) - (opq(29.65f)))) * (opq((opq(tavg)) - (opq(29.65f)))))));
            out = lam_1(qvs, lh, drdt, cpml, &gAcc, &qtavg, &rd, &tavg, &dlnT, &eps, &dlnQt);
        }
        mem_st((nm + bitcast<u32>(c)), bitcast<u32>(out));
        return;
    }
    if ((tavg >= 273.15f)) {
        var qvs: f32 = f_mp_rslf(pavg, tavg);
        var ql: f32 = opq(max(opq((opq(qciavg)) - (opq(qvs))), 0.0f));
        if ((ql > nmsat)) {
            if ((wantSat != 0i)) {
                mem_st((sat + bitcast<u32>(c)), bitcast<u32>(1.0f));
            }
            var qvl: f32 = opq(max(opq((opq(qciavg)) - (opq(ql))), 0.0f));
            var cpml: f32 = opq(fma(opq(K_MP_CPL), opq(ql), opq(fma(opq(cpv), opq(qvl), opq(cp)))));
            var lh: f32 = opq(fma(opq((-(opq(K_MP_LV2)))), opq(tavg), opq(K_MP_LV1)));
            var drdt: f32 = div_cr(opq((opq((opq(17.67f)) * (opq((opq(273.15f)) - (opq(29.65f)))))) * (opq(qvs))), (opq((opq((opq(tavg)) - (opq(29.65f)))) * (opq((opq(tavg)) - (opq(29.65f)))))));
            out = lam_1(qvs, lh, drdt, cpml, &gAcc, &qtavg, &rd, &tavg, &dlnT, &eps, &dlnQt);
        }
    } else {
        if ((tavg <= 233.15f)) {
            var qvs: f32 = f_mp_rsif(pavg, tavg);
            var qice: f32 = opq(max(opq((opq(qciavg)) - (opq(qvs))), 0.0f));
            if ((qice > nmsat)) {
                if ((wantSat != 0i)) {
                    mem_st((sat + bitcast<u32>(c)), bitcast<u32>(1.0f));
                }
                var qvl: f32 = opq(max(opq((opq(qciavg)) - (opq(qice))), 0.0f));
                var cpml: f32 = opq(fma(opq(K_MP_CPI), opq(qice), opq(fma(opq(cpv), opq(qvl), opq(cp)))));
                var lh: f32 = opq(fma(opq((-(opq(K_MP_LS2)))), opq(tavg), opq(K_MP_LS1)));
                var drdt: f32 = div_cr(opq((opq((opq(21.874557f)) * (opq((opq(273.15f)) - (opq(7.66f)))))) * (opq(qvs))), (opq((opq((opq(tavg)) - (opq(7.66f)))) * (opq((opq(tavg)) - (opq(7.66f)))))));
                out = lam_1(qvs, lh, drdt, cpml, &gAcc, &qtavg, &rd, &tavg, &dlnT, &eps, &dlnQt);
            }
        } else {
            var ff: f32 = div_cr((opq((opq(tavg)) - (opq(233.15f)))), (opq((opq(273.15f)) - (opq(233.15f)))));
            var qvsl: f32 = f_mp_rslf(pavg, tavg);
            var qvsi: f32 = f_mp_rsif(pavg, tavg);
            var qvs: f32 = opq(fma(opq(ff), opq(qvsl), opq((opq((opq(1.0f)) - (opq(ff)))) * (opq(qvsi)))));
            var qice: f32 = opq(max(0.0f, opq((opq((opq(1.0f)) - (opq(ff)))) * (opq((opq(qciavg)) - (opq(qvs)))))));
            var ql: f32 = opq(max(0.0f, opq((opq(ff)) * (opq((opq(qciavg)) - (opq(qvs)))))));
            if (((opq((opq(ql)) + (opq(qice)))) > nmsat)) {
                if ((wantSat != 0i)) {
                    mem_st((sat + bitcast<u32>(c)), bitcast<u32>(1.0f));
                }
                var qvl: f32 = opq(max(0.0f, opq((opq((opq(qciavg)) - (opq(ql)))) - (opq(qice)))));
                var cpml: f32 = opq(fma(opq(K_MP_CPI), opq(qice), opq(fma(opq(K_MP_CPL), opq(ql), opq(fma(opq(cpv), opq(qvl), opq(cp)))))));
                var lhl: f32 = opq(fma(opq((-(opq(K_MP_LV2)))), opq(tavg), opq(K_MP_LV1)));
                var drdtl: f32 = div_cr(opq((opq((opq(17.67f)) * (opq((opq(273.15f)) - (opq(29.65f)))))) * (opq(qvsl))), (opq((opq((opq(tavg)) - (opq(29.65f)))) * (opq((opq(tavg)) - (opq(29.65f)))))));
                var nml: f32 = lam_1(qvsl, lhl, drdtl, cpml, &gAcc, &qtavg, &rd, &tavg, &dlnT, &eps, &dlnQt);
                var lhi: f32 = opq(fma(opq((-(opq(K_MP_LS2)))), opq(tavg), opq(K_MP_LS1)));
                var drdti: f32 = div_cr(opq((opq((opq(21.874557f)) * (opq((opq(273.15f)) - (opq(7.66f)))))) * (opq(qvsi))), (opq((opq((opq(tavg)) - (opq(7.66f)))) * (opq((opq(tavg)) - (opq(7.66f)))))));
                var nmi: f32 = lam_1(qvsi, lhi, drdti, cpml, &gAcc, &qtavg, &rd, &tavg, &dlnT, &eps, &dlnQt);
                out = opq(fma(opq(ff), opq(nml), opq((opq((opq(1.0f)) - (opq(ff)))) * (opq(nmi)))));
            }
        }
    }
    mem_st((nm + bitcast<u32>(c)), bitcast<u32>(out));
}
