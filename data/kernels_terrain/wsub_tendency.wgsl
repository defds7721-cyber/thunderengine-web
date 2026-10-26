// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// wsub_tendency: сгенерировано, не править руками.

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

fn lam_1(kf_in: i32, g: ptr<function, S_GridDims>, wprof: u32, rf0: u32, c: ptr<function, i32>, k: ptr<function, i32>, sk: ptr<function, i32>, c1: u32, a: u32, c2: u32, weps: ptr<function, f32>) -> f32 {
    var kf: i32 = kf_in;
    if (((kf <= 0i) || (kf >= ((*g).nz)))) {
        return 0.0f;
    }
    var wp: f32 = bitcast<f32>(mem_ld((wprof + bitcast<u32>(kf))));
    var m: f32 = opq((bitcast<f32>(mem_ld((rf0 + bitcast<u32>(((*c) + ((kf - (*k)) * (*sk)))))))) * (opq(wp)));
    if ((kf == (((*g).nz) - 1i))) {
        return opq((opq(m)) * (opq(fma(bitcast<f32>(mem_ld((c1 + bitcast<u32>(((*c) + ((kf - (*k)) * (*sk))))))), opq(lam_2((kf - 1i), a, c, k, sk)), opq((bitcast<f32>(mem_ld((c2 + bitcast<u32>(((*c) + ((kf - (*k)) * (*sk)))))))) * (opq(lam_2(kf, a, c, k, sk))))))));
    }
    if ((wp <= 0.0f)) {
        return opq((opq(m)) * (opq(f_upstrpd(lam_2((kf + 1i), a, c, k, sk), lam_2(kf, a, c, k, sk), lam_2((kf - 1i), a, c, k, sk), (*weps)))));
    }
    if ((kf == 1i)) {
        return opq((opq(m)) * (opq(fma(bitcast<f32>(mem_ld((c1 + bitcast<u32>(((*c) + ((kf - (*k)) * (*sk))))))), opq(lam_2((kf - 1i), a, c, k, sk)), opq((bitcast<f32>(mem_ld((c2 + bitcast<u32>(((*c) + ((kf - (*k)) * (*sk)))))))) * (opq(lam_2(kf, a, c, k, sk))))))));
    }
    return opq((opq(m)) * (opq(f_upstrpd(lam_2((kf - 2i), a, c, k, sk), lam_2((kf - 1i), a, c, k, sk), lam_2(kf, a, c, k, sk), (*weps)))));
}

fn lam_2(kk_in: i32, a: u32, c: ptr<function, i32>, k: ptr<function, i32>, sk: ptr<function, i32>) -> f32 {
    var kk: i32 = kk_in;
    return bitcast<f32>(mem_ld((a + bitcast<u32>(((*c) + ((kk - (*k)) * (*sk)))))));
}

fn f_upstrpd(s1_in: f32, s2_in: f32, s3_in: f32, weps_in: f32) -> f32 {
    var s1: f32 = s1_in;
    var s2: f32 = s2_in;
    var s3: f32 = s3_in;
    var weps: f32 = weps_in;
    var dd: f32 = opq((opq(s2)) - (opq(s1)));
    var rr: f32 = div_cr((opq((opq(s3)) - (opq(s2)))), (opq((opq(bitcast<f32>((bitcast<u32>(weps) & 0x7fffffffu) | (bitcast<u32>(dd) & 0x80000000u)))) + (opq(dd)))));
    var phi: f32 = opq(max(0.0f, opq(min(rr, opq(min(opq(fma(opq((div_cr(2.0f, 6.0f))), opq(rr), opq((div_cr(1.0f, 6.0f))))), 1.0f))))));
    return opq(fma(opq(phi), (opq((opq(s2)) - (opq(s1)))), opq(s2)));
}

fn lam_3(kk_in: i32, a: u32, c: ptr<function, i32>, k: ptr<function, i32>, sk: ptr<function, i32>) -> f32 {
    var kk: i32 = kk_in;
    return bitcast<f32>(mem_ld((a + bitcast<u32>(((*c) + ((kk - (*k)) * (*sk)))))));
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    var g: S_GridDims = ld_GridDims(ARG[4]);
    var stag: i32 = bitcast<i32>(mem_ld(ARG[5]));
    var a: u32 = ARG[6];
    var wprof: u32 = ARG[7];
    var c1: u32 = ARG[8];
    var c2: u32 = ARG[9];
    var mh: u32 = ARG[10];
    var rr0: u32 = ARG[11];
    var rf0: u32 = ARG[12];
    var weps: f32 = bitcast<f32>(mem_ld(ARG[13]));
    var tend: u32 = ARG[14];
    var tid: vec3<u32> = gid;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    var k: i32 = i32(tid.z);
    var iMax: i32 = select((g.nx - 1i), g.nx, (stag == 2i));
    var jMax: i32 = select((g.ny - 1i), g.ny, (stag == 3i));
    if ((((i > iMax) || (j > jMax)) || (k >= g.nz))) {
        return;
    }
    var c: i32 = f_gidx(g, i, j, k);
    var sk: i32 = (g.strideJ * g.strideK);
    var div: f32 = opq((opq((opq(fma(bitcast<f32>(mem_ld((rf0 + bitcast<u32>((c + sk))))), bitcast<f32>(mem_ld((wprof + bitcast<u32>((k + 1i))))), opq((-(opq((bitcast<f32>(mem_ld((rf0 + bitcast<u32>(c))))) * (bitcast<f32>(mem_ld((wprof + bitcast<u32>(k)))))))))))) * (opq(g.rdz)))) * (bitcast<f32>(mem_ld((mh + bitcast<u32>(c))))));
    var subs: f32 = opq((opq(fma(opq((opq((-(opq((opq(lam_1((k + 1i), &g, wprof, rf0, &c, &k, &sk, c1, a, c2, &weps))) - (opq(lam_1(k, &g, wprof, rf0, &c, &k, &sk, c1, a, c2, &weps)))))))) * (opq(g.rdz))), bitcast<f32>(mem_ld((mh + bitcast<u32>(c)))), opq((opq(lam_3(k, a, &c, &k, &sk))) * (opq(div)))))) * (bitcast<f32>(mem_ld((rr0 + bitcast<u32>(c))))));
    mem_st((tend + bitcast<u32>(c)), bitcast<u32>(opq((bitcast<f32>(mem_ld((tend + bitcast<u32>(c))))) + (opq(subs)))));
}
