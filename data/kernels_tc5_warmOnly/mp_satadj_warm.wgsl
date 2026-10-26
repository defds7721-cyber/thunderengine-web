// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// mp_satadj_warm: сгенерировано, не править руками.

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

const K_MP_CV: f32 = 717.0f;

const K_MP_CVV: f32 = 1408.5f;

const K_MP_CPL: f32 = 4.19e+03f;

const K_MP_LV1: f32 = 2.5e+06f;

const K_MP_LV2: f32 = 0.0f;

const K_MP_CONVERGE: f32 = 0.0002f;

const K_MP_MAXITER: i32 = 100i;

const K_MP_RP00: f32 = 1e-05f;

const K_MP_ROVCP: f32 = 0.28585657f;

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
    var ql: u32 = ARG[12];
    var fail: u32 = ARG[13];
    var tid: vec3<u32> = gid;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    var k: i32 = i32(tid.z);
    if ((((i >= g.nx) || (j >= g.ny)) || (k >= g.nz))) {
        return;
    }
    var c: i32 = f_gidx(g, i, j, k);
    var eps: f32 = div_cr(K_MP_RD, K_MP_RV);
    var p: f32 = bitcast<f32>(mem_ld((prs + bitcast<u32>(c))));
    var tnew: f32 = opq((opq((bitcast<f32>(mem_ld((th0 + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((thPert + bitcast<u32>(c))))))) * (opq((bitcast<f32>(mem_ld((pi0 + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((ppPert + bitcast<u32>(c))))))));
    var esl: f32 = opq((opq(611.2f)) * (opq(exp(div_cr(opq((opq(17.67f)) * (opq((opq(tnew)) - (opq(273.15f))))), (opq((opq(tnew)) - (opq(29.65f)))))))));
    esl = opq(min(esl, opq((opq(p)) * (opq(0.5f)))));
    var qvs: f32 = div_cr(opq((opq(eps)) * (opq(esl))), (opq((opq(p)) - (opq(esl)))));
    if ((!(((bitcast<f32>(mem_ld((ql + bitcast<u32>(c))))) > (1e-12f)) || ((bitcast<f32>(mem_ld((qv + bitcast<u32>(c))))) > qvs)))) {
        return;
    }
    var qvnew: f32 = bitcast<f32>(mem_ld((qv + bitcast<u32>(c))));
    var qcnew: f32 = bitcast<f32>(mem_ld((ql + bitcast<u32>(c))));
    var qlsum: f32 = opq(max(0.0f, bitcast<f32>(mem_ld((ql + bitcast<u32>(c))))));
    var cvml: f32 = opq(fma(opq(K_MP_CPL), opq(qlsum), opq(fma(opq(K_MP_CVV), opq(qvnew), opq(K_MP_CV)))));
    var lhv: f32 = opq(fma(opq((-(opq(K_MP_LV2)))), opq(tnew), opq(K_MP_LV1)));
    var t1: f32 = div_cr((opq(fma(opq((-(opq(K_MP_RV)))), opq(tnew), opq(lhv)))), cvml);
    var d1: f32 = opq((opq((opq(t1)) * (opq(17.67f)))) * (opq(243.5f)));
    var n: i32 = 0i;
    var tlast: f32 = tnew;
    var pnew: f32 = p;
    var doit: bool = true;
    loop {
        if (!(doit)) { break; }
            n = (n + 1i);
            var dqv: f32 = div_cr((opq((opq(qvs)) - (opq(qvnew)))), (opq((opq(1.0f)) + (opq(div_cr(opq((opq(d1)) * (opq(qvs))), (opq((opq((opq(tnew)) - (opq(29.65f)))) * (opq((opq(tnew)) - (opq(29.65f))))))))))));
            dqv = opq(min(dqv, qcnew));
            if (((opq((opq(qvnew)) + (opq(dqv)))) < (1e-20f))) {
                dqv = opq((opq(1e-20f)) - (opq(qvnew)));
            }
            qvnew = opq((opq(qvnew)) + (opq(dqv)));
            qcnew = opq((opq(qcnew)) - (opq(dqv)));
            tnew = opq(fma(opq((-(opq(dqv)))), opq(t1), opq(tnew)));
            pnew = opq((opq((bitcast<f32>(mem_ld((rho + bitcast<u32>(c))))) * (opq(fma(opq(K_MP_RV), opq(qvnew), opq(K_MP_RD)))))) * (opq(tnew)));
            doit = false;
            if (((abs(opq((opq(tnew)) - (opq(tlast))))) > K_MP_CONVERGE)) {
                tlast = tnew;
                esl = opq((opq(611.2f)) * (opq(exp(div_cr(opq((opq(17.67f)) * (opq((opq(tnew)) - (opq(273.15f))))), (opq((opq(tnew)) - (opq(29.65f)))))))));
                esl = opq(min(esl, opq((opq(p)) * (opq(0.5f)))));
                qvs = div_cr(opq((opq(eps)) * (opq(esl))), (opq((opq(pnew)) - (opq(esl)))));
                doit = true;
            }
            if ((n == K_MP_MAXITER)) {
                _ = atomicAdd(&M[fail], 1u);
                doit = false;
            }
    }
    mem_st((prs + bitcast<u32>(c)), bitcast<u32>(pnew));
    mem_st((ppPert + bitcast<u32>(c)), bitcast<u32>(opq((opq(pow(opq((opq(pnew)) * (opq(K_MP_RP00))), K_MP_ROVCP))) - (bitcast<f32>(mem_ld((pi0 + bitcast<u32>(k))))))));
    mem_st((thPert + bitcast<u32>(c)), bitcast<u32>(opq((opq(div_cr(tnew, (opq((bitcast<f32>(mem_ld((pi0 + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((ppPert + bitcast<u32>(c)))))))))) - (bitcast<f32>(mem_ld((th0 + bitcast<u32>(k))))))));
    mem_st((ql + bitcast<u32>(c)), bitcast<u32>(qcnew));
    mem_st((qv + bitcast<u32>(c)), bitcast<u32>(qvnew));
}
