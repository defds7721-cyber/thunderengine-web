// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// adv_flux_y_weno_w: сгенерировано, не править руками.

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

fn f_weno5(s1_in: f32, s2_in: f32, s3_in: f32, s4_in: f32, s5_in: f32, weps_in: f32) -> f32 {
    var s1: f32 = s1_in;
    var s2: f32 = s2_in;
    var s3: f32 = s3_in;
    var s4: f32 = s4_in;
    var s5: f32 = s5_in;
    var weps: f32 = weps_in;
    var b1: f32 = opq(fma(opq((opq((div_cr(13.0f, 12.0f)))) * (opq((opq(fma(opq((-(opq(2.0f)))), opq(s2), opq(s1)))) + (opq(s3))))), (opq((opq(fma(opq((-(opq(2.0f)))), opq(s2), opq(s1)))) + (opq(s3)))), opq((opq((opq(0.25f)) * (opq(fma(opq(3.0f), opq(s3), opq(fma(opq((-(opq(4.0f)))), opq(s2), opq(s1)))))))) * (opq(fma(opq(3.0f), opq(s3), opq(fma(opq((-(opq(4.0f)))), opq(s2), opq(s1)))))))));
    var b2: f32 = opq(fma(opq((opq((div_cr(13.0f, 12.0f)))) * (opq((opq(fma(opq((-(opq(2.0f)))), opq(s3), opq(s2)))) + (opq(s4))))), (opq((opq(fma(opq((-(opq(2.0f)))), opq(s3), opq(s2)))) + (opq(s4)))), opq((opq((opq(0.25f)) * (opq((opq(s2)) - (opq(s4)))))) * (opq((opq(s2)) - (opq(s4)))))));
    var b3: f32 = opq(fma(opq((opq((div_cr(13.0f, 12.0f)))) * (opq((opq(fma(opq((-(opq(2.0f)))), opq(s4), opq(s3)))) + (opq(s5))))), (opq((opq(fma(opq((-(opq(2.0f)))), opq(s4), opq(s3)))) + (opq(s5)))), opq((opq((opq(0.25f)) * (opq((opq(fma(opq(3.0f), opq(s3), opq((-(opq((opq(4.0f)) * (opq(s4))))))))) + (opq(s5)))))) * (opq((opq(fma(opq(3.0f), opq(s3), opq((-(opq((opq(4.0f)) * (opq(s4))))))))) + (opq(s5)))))));
    var tau: f32 = abs(opq((opq(b1)) - (opq(b3))));
    var r1: f32 = opq(min(1e+30f, div_cr(tau, (opq((opq(b1)) + (opq(weps)))))));
    var r2: f32 = opq(min(1e+30f, div_cr(tau, (opq((opq(b2)) + (opq(weps)))))));
    var r3: f32 = opq(min(1e+30f, div_cr(tau, (opq((opq(b3)) + (opq(weps)))))));
    var m: f32 = opq(max(r1, opq(max(r2, r3))));
    var one: f32 = 1.0f;
    if ((m > (1e+15f))) {
        var im: f32 = div_cr(1.0f, m);
        r1 = opq((opq(r1)) * (opq(im)));
        r2 = opq((opq(r2)) * (opq(im)));
        r3 = opq((opq(r3)) * (opq(im)));
        one = opq((opq(im)) * (opq(im)));
    }
    var w1: f32 = opq((opq(0.1f)) * (opq(fma(opq(r1), opq(r1), opq(one)))));
    var w2: f32 = opq((opq(0.6f)) * (opq(fma(opq(r2), opq(r2), opq(one)))));
    var w3: f32 = opq((opq(0.3f)) * (opq(fma(opq(r3), opq(r3), opq(one)))));
    var p1: f32 = opq(fma(opq((div_cr(11.0f, 6.0f))), opq(s3), opq(fma(opq((div_cr(2.0f, 6.0f))), opq(s1), opq((opq((div_cr(opq((-(opq(7.0f)))), 6.0f)))) * (opq(s2)))))));
    var p2: f32 = opq(fma(opq((div_cr(2.0f, 6.0f))), opq(s4), opq(fma(opq((div_cr(opq((-(opq(1.0f)))), 6.0f))), opq(s2), opq((opq((div_cr(5.0f, 6.0f)))) * (opq(s3)))))));
    var p3: f32 = opq(fma(opq((div_cr(opq((-(opq(1.0f)))), 6.0f))), opq(s5), opq(fma(opq((div_cr(2.0f, 6.0f))), opq(s3), opq((opq((div_cr(5.0f, 6.0f)))) * (opq(s4)))))));
    return div_cr((opq(fma(opq(w3), opq(p3), opq(fma(opq(w1), opq(p1), opq((opq(w2)) * (opq(p2)))))))), (opq((opq((opq(w1)) + (opq(w2)))) + (opq(w3)))));
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    var g: S_GridDims = ld_GridDims(ARG[4]);
    var a: u32 = ARG[5];
    var rrv: u32 = ARG[6];
    var c2: u32 = ARG[7];
    var weps: f32 = bitcast<f32>(mem_ld(ARG[8]));
    var fy: u32 = ARG[9];
    var tid: vec3<u32> = gid;
    var i: i32 = ((i32(tid.x)) - 1i);
    var j: i32 = ((i32(tid.y)) - 1i);
    var k: i32 = i32(tid.z);
    if ((((((i < 0i) || (j < 0i)) || (i > g.nx)) || (j > g.ny)) || (k >= g.nz))) {
        return;
    }
    var c: i32 = f_gidx(g, i, j, k);
    var sj: i32 = g.strideJ;
    var sk: i32 = (g.strideJ * g.strideK);
    if ((k == 0i)) {
        mem_st((fy + bitcast<u32>(c)), bitcast<u32>(0.0f));
        return;
    }
    var cc2: f32 = bitcast<f32>(mem_ld((c2 + bitcast<u32>(c))));
    var cc1: f32 = opq((opq(1.0f)) - (opq(cc2)));
    var vbar: f32 = opq(fma(opq(cc2), bitcast<f32>(mem_ld((rrv + bitcast<u32>(c)))), opq((opq(cc1)) * (bitcast<f32>(mem_ld((rrv + bitcast<u32>((c - sk)))))))));
    var _t1: f32;
    if ((vbar >= 0.0f)) {
        _t1 = opq((opq(vbar)) * (opq(f_weno5(bitcast<f32>(mem_ld((a + bitcast<u32>((c - (3i * sj)))))), bitcast<f32>(mem_ld((a + bitcast<u32>((c - (2i * sj)))))), bitcast<f32>(mem_ld((a + bitcast<u32>((c - sj))))), bitcast<f32>(mem_ld((a + bitcast<u32>(c)))), bitcast<f32>(mem_ld((a + bitcast<u32>((c + sj))))), weps))));
    } else {
        _t1 = opq((opq(vbar)) * (opq(f_weno5(bitcast<f32>(mem_ld((a + bitcast<u32>((c + (2i * sj)))))), bitcast<f32>(mem_ld((a + bitcast<u32>((c + sj))))), bitcast<f32>(mem_ld((a + bitcast<u32>(c)))), bitcast<f32>(mem_ld((a + bitcast<u32>((c - sj))))), bitcast<f32>(mem_ld((a + bitcast<u32>((c - (2i * sj)))))), weps))));
    }
    mem_st((fy + bitcast<u32>(c)), bitcast<u32>(_t1));
}
