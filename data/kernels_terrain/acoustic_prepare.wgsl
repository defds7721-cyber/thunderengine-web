// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// acoustic_prepare: сгенерировано, не править руками.

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

struct S_AcousticParams {
    dts: f32,
    alph: f32,
    beta: f32,
    kdiv: f32,
    smeps: f32,
}

const K_MP_CP: f32 = 1005.7f;

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

fn ld_AcousticParams(o: u32) -> S_AcousticParams {
    var s: S_AcousticParams;
    s.dts = bitcast<f32>(mem_ld((o + 0u)));
    s.alph = bitcast<f32>(mem_ld((o + 1u)));
    s.beta = bitcast<f32>(mem_ld((o + 2u)));
    s.kdiv = bitcast<f32>(mem_ld((o + 3u)));
    s.smeps = bitcast<f32>(mem_ld((o + 4u)));
    return s;
}

fn f_gidx(g_in: S_GridDims, i_in: i32, j_in: i32, k_in: i32) -> i32 {
    var g: S_GridDims = g_in;
    var i: i32 = i_in;
    var j: i32 = j_in;
    var k: i32 = k_in;
    return ((i + 3i) + (g.strideJ * ((j + 3i) + (g.strideK * k))));
}

fn f_tplane(g_in: S_GridDims, tpl_in: u32, n_in: i32, i_in: i32, j_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var tpl: u32 = tpl_in;
    var n: i32 = n_in;
    var i: i32 = i_in;
    var j: i32 = j_in;
    let _t1 = (((n * g.strideJ) * g.strideK) + (f_gidx(g, i, j, 0i)));
    return bitcast<f32>(mem_ld((tpl + bitcast<u32>(_t1))));
}

fn f_tsig(g_in: S_GridDims, tz_in: u32, which_in: i32, k_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var tz: u32 = tz_in;
    var which: i32 = which_in;
    var k: i32 = k_in;
    return bitcast<f32>(mem_ld((tz + bitcast<u32>(((which * (g.nz + 1i)) + k)))));
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    var g: S_GridDims = ld_GridDims(ARG[4]);
    var a: S_AcousticParams = ld_AcousticParams(ARG[5]);
    var ppterm: u32 = ARG[6];
    var piadv: u32 = ARG[7];
    var thv: u32 = ARG[8];
    var rr0: u32 = ARG[9];
    var rf0: u32 = ARG[10];
    var mh: u32 = ARG[11];
    var mf: u32 = ARG[12];
    var c1: u32 = ARG[13];
    var c2: u32 = ARG[14];
    var qk: u32 = ARG[15];
    var pk1: u32 = ARG[16];
    var pk2: u32 = ARG[17];
    var mm: u32 = ARG[18];
    var tpl: u32 = ARG[28];
    var tz: u32 = ARG[29];
    var tid: vec3<u32> = gid;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    var k: i32 = i32(tid.z);
    if ((((i >= g.nx) || (j >= g.ny)) || (k >= g.nz))) {
        return;
    }
    var cp: f32 = K_MP_CP;
    var c: i32 = f_gidx(g, i, j, k);
    var sk: i32 = (g.strideJ * g.strideK);
    {
        var gz: f32 = f_tplane(g, tpl, 0i, i, j);
        var tem: f32 = opq((opq(a.dts)) * (opq(f_tsig(g, tz, 1i, k))));
        mem_st((qk + bitcast<u32>(c)), bitcast<u32>(opq((opq((opq(tem)) * (bitcast<f32>(mem_ld((ppterm + bitcast<u32>(c))))))) * (opq(gz)))));
        var tem2: f32 = opq((opq((opq((opq(a.dts)) * (opq(gz)))) * (opq(f_tsig(g, tz, 1i, k))))) * (bitcast<f32>(mem_ld((rr0 + bitcast<u32>(c))))));
        var _t1: f32;
        if ((k == (g.nz - 1i))) {
            _t1 = 0.0f;
        } else {
            _t1 = opq((opq((opq(tem2)) * (bitcast<f32>(mem_ld((rf0 + bitcast<u32>((c + sk)))))))) * (opq(fma(opq((-(bitcast<f32>(mem_ld((c2 + bitcast<u32>((c + sk)))))))), bitcast<f32>(mem_ld((piadv + bitcast<u32>((c + sk))))), opq((opq((opq(1.0f)) - (bitcast<f32>(mem_ld((c1 + bitcast<u32>((c + sk)))))))) * (bitcast<f32>(mem_ld((piadv + bitcast<u32>(c))))))))));
        }
        mem_st((pk2 + bitcast<u32>(c)), bitcast<u32>(_t1));
        var _t2: f32;
        if ((k == 0i)) {
            _t2 = 0.0f;
        } else {
            _t2 = opq((opq((opq(tem2)) * (bitcast<f32>(mem_ld((rf0 + bitcast<u32>(c))))))) * (opq(fma(bitcast<f32>(mem_ld((c1 + bitcast<u32>(c)))), bitcast<f32>(mem_ld((piadv + bitcast<u32>((c - sk))))), opq((opq((bitcast<f32>(mem_ld((c2 + bitcast<u32>(c))))) - (opq(1.0f)))) * (bitcast<f32>(mem_ld((piadv + bitcast<u32>(c))))))))));
        }
        mem_st((pk1 + bitcast<u32>(c)), bitcast<u32>(_t2));
        var _t3: f32;
        if ((k == 0i)) {
            _t3 = 0.0f;
        } else {
            _t3 = opq((opq((opq((opq((opq(a.dts)) * (opq(f_tsig(g, tz, 0i, k))))) * (opq(cp)))) * (opq(fma(bitcast<f32>(mem_ld((c2 + bitcast<u32>(c)))), bitcast<f32>(mem_ld((thv + bitcast<u32>(c)))), opq((bitcast<f32>(mem_ld((c1 + bitcast<u32>(c))))) * (bitcast<f32>(mem_ld((thv + bitcast<u32>((c - sk)))))))))))) * (opq(gz)));
        }
        mem_st((mm + bitcast<u32>(c)), bitcast<u32>(_t3));
        return;
    }
    {
        var tem: f32 = opq((opq((opq(a.dts)) * (opq(g.rdz)))) * (bitcast<f32>(mem_ld((mh + bitcast<u32>(c))))));
        var r2: f32 = opq((opq((opq(tem)) * (bitcast<f32>(mem_ld((rr0 + bitcast<u32>(c))))))) * (bitcast<f32>(mem_ld((rf0 + bitcast<u32>((c + sk)))))));
        var r1: f32 = opq((opq((opq(tem)) * (bitcast<f32>(mem_ld((rr0 + bitcast<u32>(c))))))) * (bitcast<f32>(mem_ld((rf0 + bitcast<u32>(c))))));
        var tem1: f32 = opq((opq((opq((opq(a.dts)) * (opq(g.rdz)))) * (opq(cp)))) * (bitcast<f32>(mem_ld((mf + bitcast<u32>(c))))));
        var c1a: f32 = bitcast<f32>(mem_ld((c1 + bitcast<u32>(c))));
        var c1b: f32 = bitcast<f32>(mem_ld((c1 + bitcast<u32>((c + sk)))));
        var c2a: f32 = bitcast<f32>(mem_ld((c2 + bitcast<u32>(c))));
        var c2b: f32 = bitcast<f32>(mem_ld((c2 + bitcast<u32>((c + sk)))));
        var vec_v: bool = ((g.nx > 3i) && (i < ((g.nx / 4i) * 4i)));
        mem_st((qk + bitcast<u32>(c)), bitcast<u32>(opq((opq(tem)) * (bitcast<f32>(mem_ld((ppterm + bitcast<u32>(c))))))));
        var p2: f32 = 0.0f;
        var p1: f32 = 0.0f;
        if ((k != (g.nz - 1i))) {
            p2 = select(opq(fma(opq((opq(1.0f)) - (opq(c1b))), bitcast<f32>(mem_ld((piadv + bitcast<u32>(c)))), opq((-(opq((opq(c2b)) * (bitcast<f32>(mem_ld((piadv + bitcast<u32>((c + sk)))))))))))), opq(fma(opq((-(opq(c2b)))), bitcast<f32>(mem_ld((piadv + bitcast<u32>((c + sk))))), opq((opq((opq(1.0f)) - (opq(c1b)))) * (bitcast<f32>(mem_ld((piadv + bitcast<u32>(c)))))))), vec_v);
        }
        if ((k != 0i)) {
            p1 = select(opq(fma(opq(c1a), bitcast<f32>(mem_ld((piadv + bitcast<u32>((c - sk))))), opq((opq((opq(c2a)) - (opq(1.0f)))) * (bitcast<f32>(mem_ld((piadv + bitcast<u32>(c)))))))), opq(fma(opq((opq(c2a)) - (opq(1.0f))), bitcast<f32>(mem_ld((piadv + bitcast<u32>(c)))), opq((opq(c1a)) * (bitcast<f32>(mem_ld((piadv + bitcast<u32>((c - sk))))))))), vec_v);
        }
        mem_st((pk2 + bitcast<u32>(c)), bitcast<u32>(select(opq((opq(r2)) * (opq(p2))), 0.0f, (k == (g.nz - 1i)))));
        mem_st((pk1 + bitcast<u32>(c)), bitcast<u32>(select(opq((opq(r1)) * (opq(p1))), 0.0f, (k == 0i))));
        mem_st((mm + bitcast<u32>(c)), bitcast<u32>(opq((opq(tem1)) * (opq(fma(opq(c2a), bitcast<f32>(mem_ld((thv + bitcast<u32>(c)))), opq((opq(c1a)) * (opq(select(bitcast<f32>(mem_ld((thv + bitcast<u32>((c - sk))))), bitcast<f32>(mem_ld((thv + bitcast<u32>(c)))), (k == 0i)))))))))));
    }
}
