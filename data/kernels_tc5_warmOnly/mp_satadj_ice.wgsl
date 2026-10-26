// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// mp_satadj_ice: сгенерировано, не править руками.

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

const K_MP_T00K: f32 = 233.15f;

const K_MP_RT0: f32 = 0.025f;

const K_MP_RD: f32 = 287.0f;

const K_MP_RV: f32 = 461.5f;

const K_MP_T0K: f32 = 273.15f;

const K_MP_CP: f32 = 1004.0f;

const K_MP_CPV: f32 = 1.87e+03f;

const K_MP_CPL: f32 = 4.19e+03f;

const K_MP_CPI: f32 = 2106.0f;

const K_MP_XLV: f32 = 2.5e+06f;

const K_MP_TO: f32 = 273.15f;

const K_MP_XLS: f32 = 2.834e+06f;

const K_MP_C409: f32 = 4302.645f;

const K_MP_C358: f32 = 29.65f;

const K_MP_C580: f32 = 5807.476f;

const K_MP_C76: f32 = 7.66f;

const K_MP_CONVERGE: f32 = 0.0002f;

const K_MP_MAXITER: i32 = 100i;

const K_MP_P00: f32 = 1e+05f;

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

fn f_mp_rslf(p_in: f32, t_in: f32) -> f32 {
    var p: f32 = p_in;
    var t: f32 = t_in;
    var esl: f32 = opq((opq(611.2f)) * (opq(exp(div_cr(opq((opq(17.67f)) * (opq((opq(t)) - (opq(273.15f))))), (opq((opq(t)) - (opq(29.65f)))))))));
    esl = opq(min(esl, opq((opq(p)) * (opq(0.5f)))));
    var eps: f32 = div_cr(K_MP_RD, K_MP_RV);
    return div_cr(opq((opq(eps)) * (opq(esl))), (opq((opq(p)) - (opq(esl)))));
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
    var th0: u32 = ARG[5];
    var pi0: u32 = ARG[6];
    var rho: u32 = ARG[7];
    var prs: u32 = ARG[8];
    var ppPert: u32 = ARG[9];
    var thPert: u32 = ARG[10];
    var qv: u32 = ARG[11];
    var qc: u32 = ARG[12];
    var qr: u32 = ARG[13];
    var qi: u32 = ARG[14];
    var qs: u32 = ARG[15];
    var qg: u32 = ARG[16];
    var tid: vec3<u32> = gid;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    var k: i32 = i32(tid.z);
    if ((((i >= g.nx) || (j >= g.ny)) || (k >= g.nz))) {
        return;
    }
    var c: i32 = f_gidx(g, i, j, k);
    var p: f32 = bitcast<f32>(mem_ld((prs + bitcast<u32>(c))));
    var tnew: f32 = opq((opq((bitcast<f32>(mem_ld((th0 + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((thPert + bitcast<u32>(c))))))) * (opq((bitcast<f32>(mem_ld((pi0 + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((ppPert + bitcast<u32>(c))))))));
    var fliq: f32 = opq(clamp(opq((opq((opq(tnew)) - (opq(K_MP_T00K)))) * (opq(K_MP_RT0))), 0.0f, 1.0f));
    var fice: f32 = opq((opq(1.0f)) - (opq(fliq)));
    var _t1: f32;
    if ((tnew > K_MP_T00K)) {
        _t1 = opq((opq(fliq)) * (opq(f_mp_rslf(p, tnew))));
    } else {
        _t1 = 0.0f;
    }
    var qsw: f32 = _t1;
    var _t2: f32;
    if ((tnew < K_MP_T0K)) {
        _t2 = opq((opq(fice)) * (opq(f_mp_rsif(p, tnew))));
    } else {
        _t2 = 0.0f;
    }
    var qsi: f32 = _t2;
    var qvs: f32 = opq((opq(qsw)) + (opq(qsi)));
    if ((!((((bitcast<f32>(mem_ld((qc + bitcast<u32>(c))))) > (1e-12f)) || ((bitcast<f32>(mem_ld((qi + bitcast<u32>(c))))) > (1e-12f))) || ((bitcast<f32>(mem_ld((qv + bitcast<u32>(c))))) > qvs)))) {
        return;
    }
    var qvnew: f32 = bitcast<f32>(mem_ld((qv + bitcast<u32>(c))));
    var qcnew: f32 = bitcast<f32>(mem_ld((qc + bitcast<u32>(c))));
    var qinew: f32 = bitcast<f32>(mem_ld((qi + bitcast<u32>(c))));
    var cv: f32 = opq((opq(K_MP_CP)) - (opq(K_MP_RD)));
    var cvv: f32 = opq((opq(K_MP_CPV)) - (opq(K_MP_RV)));
    var tem: f32 = opq(fma(opq(K_MP_CPL), (opq((bitcast<f32>(mem_ld((qc + bitcast<u32>(c))))) + (bitcast<f32>(mem_ld((qr + bitcast<u32>(c))))))), opq((opq(K_MP_CPI)) * (opq((opq((bitcast<f32>(mem_ld((qi + bitcast<u32>(c))))) + (bitcast<f32>(mem_ld((qs + bitcast<u32>(c))))))) + (bitcast<f32>(mem_ld((qg + bitcast<u32>(c))))))))));
    var cvml: f32 = opq((opq(fma(opq(cvv), bitcast<f32>(mem_ld((qv + bitcast<u32>(c)))), opq(cv)))) + (opq(tem)));
    var lv1: f32 = opq(fma((opq((opq(K_MP_CPL)) - (opq(K_MP_CPV)))), opq(K_MP_TO), opq(K_MP_XLV)));
    var lv2: f32 = opq((opq(K_MP_CPL)) - (opq(K_MP_CPV)));
    var ls1: f32 = opq(fma((opq((opq(K_MP_CPI)) - (opq(K_MP_CPV)))), opq(K_MP_TO), opq(K_MP_XLS)));
    var ls2: f32 = opq((opq(K_MP_CPI)) - (opq(K_MP_CPV)));
    var lhv: f32 = opq(fma(opq((-(opq(lv2)))), opq(tnew), opq(lv1)));
    var lhs: f32 = opq(fma(opq((-(opq(ls2)))), opq(tnew), opq(ls1)));
    var t1: f32 = div_cr(1.0f, cvml);
    var t2: f32 = div_cr(opq((opq(K_MP_RV)) * (opq(tnew))), cvml);
    var tlast: f32 = tnew;
    var pnew: f32 = p;
    var n: i32 = 0i;
    var doit: bool = true;
    loop {
        if (!(doit)) { break; }
            n = (n + 1i);
            var term1: f32 = select(0.0f, opq((opq(qsw)) * (opq((div_cr(opq((opq(fliq)) * (opq(K_MP_C409))), (opq((opq((opq(tnew)) - (opq(K_MP_C358)))) * (opq((opq(tnew)) - (opq(K_MP_C358))))))))))), (tnew > K_MP_T00K));
            var term2: f32 = select(0.0f, opq((opq(qsi)) * (opq((div_cr(opq((opq(fice)) * (opq(K_MP_C580))), (opq((opq((opq(tnew)) - (opq(K_MP_C76)))) * (opq((opq(tnew)) - (opq(K_MP_C76))))))))))), (tnew < K_MP_T0K));
            var dqv: f32 = div_cr((opq((opq(qvs)) - (opq(qvnew)))), (opq(fma((opq(fma((opq(fma(opq(lhv), opq(fliq), opq((opq(lhs)) * (opq(fice)))))), opq(t1), opq((-(opq(t2))))))), (opq((opq(term1)) + (opq(term2)))), opq(1.0f)))));
            dqv = opq(min(dqv, opq((opq(qcnew)) + (opq(qinew)))));
            if (((((opq((opq(dqv)) * (opq(qcnew)))) > 0.0f) && (qinew == 0.0f)) || (((opq((opq(dqv)) * (opq(qinew)))) > 0.0f) && (qcnew == 0.0f)))) {
                fliq = div_cr(qcnew, (opq((opq(qcnew)) + (opq(qinew)))));
                fice = opq((opq(1.0f)) - (opq(fliq)));
            }
            if (((opq((opq(qvnew)) + (opq(dqv)))) < (1e-20f))) {
                dqv = opq((opq(1e-20f)) - (opq(qvnew)));
            }
            var cnd: f32 = opq(min(opq((opq(fliq)) * (opq(dqv))), qcnew));
            var dep: f32 = opq(min(opq((opq(fice)) * (opq(dqv))), qinew));
            dqv = opq((opq(cnd)) + (opq(dep)));
            qvnew = opq((opq(qvnew)) + (opq(dqv)));
            qcnew = opq(max(opq((opq(qcnew)) - (opq(cnd))), 0.0f));
            qinew = opq(max(opq((opq(qinew)) - (opq(dep))), 0.0f));
            tnew = opq((opq(tnew)) - (opq(fma((opq(fma(opq(lhv), opq(cnd), opq((opq(lhs)) * (opq(dep)))))), opq(t1), opq((-(opq((opq(dqv)) * (opq(t2))))))))));
            pnew = opq((opq((bitcast<f32>(mem_ld((rho + bitcast<u32>(c))))) * (opq(fma(opq(K_MP_RV), opq(qvnew), opq(K_MP_RD)))))) * (opq(tnew)));
            doit = false;
            if (((abs(opq((opq(tnew)) - (opq(tlast))))) > K_MP_CONVERGE)) {
                tlast = tnew;
                fliq = opq(clamp(opq((opq((opq(tnew)) - (opq(K_MP_T00K)))) * (opq(K_MP_RT0))), 0.0f, 1.0f));
                fice = opq((opq(1.0f)) - (opq(fliq)));
                var _t3: f32;
                if ((tnew > K_MP_T00K)) {
                    _t3 = opq((opq(fliq)) * (opq(f_mp_rslf(p, tnew))));
                } else {
                    _t3 = 0.0f;
                }
                qsw = _t3;
                var _t4: f32;
                if ((tnew < K_MP_T0K)) {
                    _t4 = opq((opq(fice)) * (opq(f_mp_rsif(p, tnew))));
                } else {
                    _t4 = 0.0f;
                }
                qsi = _t4;
                qvs = opq((opq(qsw)) + (opq(qsi)));
                doit = true;
            }
            if ((n >= K_MP_MAXITER)) {
                doit = false;
            }
    }
    mem_st((prs + bitcast<u32>(c)), bitcast<u32>(pnew));
    mem_st((ppPert + bitcast<u32>(c)), bitcast<u32>(opq((opq(pow(div_cr(pnew, K_MP_P00), div_cr(K_MP_RD, K_MP_CP)))) - (bitcast<f32>(mem_ld((pi0 + bitcast<u32>(k))))))));
    mem_st((thPert + bitcast<u32>(c)), bitcast<u32>(opq((opq(div_cr(tnew, (opq((bitcast<f32>(mem_ld((pi0 + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((ppPert + bitcast<u32>(c)))))))))) - (bitcast<f32>(mem_ld((th0 + bitcast<u32>(k))))))));
    mem_st((qv + bitcast<u32>(c)), bitcast<u32>(qvnew));
    mem_st((qc + bitcast<u32>(c)), bitcast<u32>(qcnew));
    mem_st((qi + bitcast<u32>(c)), bitcast<u32>(qinew));
}
