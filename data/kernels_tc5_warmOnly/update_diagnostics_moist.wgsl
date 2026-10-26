// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// update_diagnostics_moist: сгенерировано, не править руками.

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

const K_MP_CV: f32 = 717.0f;

const K_MP_CPV: f32 = 1.87e+03f;

const K_MP_CVV: f32 = 1408.5f;

const K_MP_ROVCP: f32 = 0.28585657f;

const K_MP_CPL: f32 = 4.19e+03f;

const K_MP_CPI: f32 = 2106.0f;

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
    var thPert: u32 = ARG[5];
    var ppPert: u32 = ARG[6];
    var th0: u32 = ARG[7];
    var pi0: u32 = ARG[8];
    var qv0: u32 = ARG[9];
    var qc0: u32 = ARG[10];
    var qi0: u32 = ARG[11];
    var rth0: u32 = ARG[12];
    var qv: u32 = ARG[13];
    var qc: u32 = ARG[14];
    var qr: u32 = ARG[15];
    var qi: u32 = ARG[16];
    var qs: u32 = ARG[17];
    var qg: u32 = ARG[18];
    var thv: u32 = ARG[19];
    var ppterm: u32 = ARG[20];
    var piadv: u32 = ARG[21];
    var thterm: u32 = ARG[22];
    var buoy: u32 = ARG[23];
    var tid: vec3<u32> = gid;
    var i: i32 = ((i32(tid.x)) - 3i);
    var j: i32 = ((i32(tid.y)) - 3i);
    var k: i32 = i32(tid.z);
    if ((((i > (g.nx + 3i)) || (j > (g.ny + 3i))) || (k >= g.nz))) {
        return;
    }
    var c: i32 = f_gidx(g, i, j, k);
    var rd: f32 = K_MP_RD;
    var rv: f32 = K_MP_RV;
    var cp: f32 = K_MP_CP;
    var cv: f32 = K_MP_CV;
    var cpv: f32 = K_MP_CPV;
    var cvv: f32 = K_MP_CVV;
    var rovcp: f32 = K_MP_ROVCP;
    var reps: f32 = div_cr(rv, rd);
    var repsm1: f32 = opq((opq(reps)) - (opq(1.0f)));
    var gAcc: f32 = 9.81f;
    var qvv: f32 = opq(max(bitcast<f32>(mem_ld((qv + bitcast<u32>(c)))), 0.0f));
    var liq: f32 = opq((bitcast<f32>(mem_ld((qc + bitcast<u32>(c))))) + (bitcast<f32>(mem_ld((qr + bitcast<u32>(c))))));
    var ice: f32 = opq((opq((bitcast<f32>(mem_ld((qi + bitcast<u32>(c))))) + (bitcast<f32>(mem_ld((qs + bitcast<u32>(c))))))) + (bitcast<f32>(mem_ld((qg + bitcast<u32>(c))))));
    var qli: f32 = opq(max(0.0f, opq((opq(liq)) + (opq(ice)))));
    var cpli: f32 = opq(fma(opq(K_MP_CPL), opq(max(0.0f, liq)), opq((opq(K_MP_CPI)) * (opq(max(0.0f, ice))))));
    var th: f32 = opq((bitcast<f32>(mem_ld((th0 + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((thPert + bitcast<u32>(c))))));
    var pi: f32 = opq((bitcast<f32>(mem_ld((pi0 + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((ppPert + bitcast<u32>(c))))));
    var cpm: f32 = opq((opq(fma(opq(cpv), opq(qvv), opq(cp)))) + (opq(cpli)));
    var cvm: f32 = div_cr(1.0f, (opq((opq(fma(opq(cvv), opq(qvv), opq(cv)))) + (opq(cpli)))));
    mem_st((thv + bitcast<u32>(c)), bitcast<u32>(div_cr(opq((opq(th)) * (opq(fma(opq(reps), opq(qvv), opq(1.0f))))), (opq((opq((opq(1.0f)) + (opq(qvv)))) + (opq(qli)))))));
    mem_st((piadv + bitcast<u32>(c)), bitcast<u32>(pi));
    mem_st((ppterm + bitcast<u32>(c)), bitcast<u32>(opq((opq((opq((opq(pi)) * (opq(rovcp)))) * (opq(cpm)))) * (opq(cvm)))));
    mem_st((thterm + bitcast<u32>(c)), bitcast<u32>(opq((opq((opq(th)) * (opq(fma(opq((-(opq(rovcp)))), opq(cpm), opq(fma(opq(rv), opq(qvv), opq(rd)))))))) * (opq(cvm)))));
    mem_st((buoy + bitcast<u32>(c)), bitcast<u32>(opq((opq(gAcc)) * (opq((opq(fma(bitcast<f32>(mem_ld((thPert + bitcast<u32>(c)))), bitcast<f32>(mem_ld((rth0 + bitcast<u32>(k)))), opq((opq(repsm1)) * (opq((opq(qvv)) - (bitcast<f32>(mem_ld((qv0 + bitcast<u32>(k))))))))))) - (opq((opq((opq(qli)) - (bitcast<f32>(mem_ld((qc0 + bitcast<u32>(k))))))) - (bitcast<f32>(mem_ld((qi0 + bitcast<u32>(k))))))))))));
}
