// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// stability_max: сгенерировано, не править руками.

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

struct S_StabilityParams {
    dtdx: f32,
    dtdy: f32,
    dtdz: f32,
    ksdx: f32,
    ksdy: f32,
    twoD: i32,
    withKs: i32,
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

fn ld_StabilityParams(o: u32) -> S_StabilityParams {
    var s: S_StabilityParams;
    s.dtdx = bitcast<f32>(mem_ld((o + 0u)));
    s.dtdy = bitcast<f32>(mem_ld((o + 1u)));
    s.dtdz = bitcast<f32>(mem_ld((o + 2u)));
    s.ksdx = bitcast<f32>(mem_ld((o + 3u)));
    s.ksdy = bitcast<f32>(mem_ld((o + 4u)));
    s.twoD = bitcast<i32>(mem_ld((o + 5u)));
    s.withKs = bitcast<i32>(mem_ld((o + 6u)));
    return s;
}

fn f_gidx(g_in: S_GridDims, i_in: i32, j_in: i32, k_in: i32) -> i32 {
    var g: S_GridDims = g_in;
    var i: i32 = i_in;
    var j: i32 = j_in;
    var k: i32 = k_in;
    return ((i + 3i) + (g.strideJ * ((j + 3i) + (g.strideK * k))));
}

fn f_hm_uh(g_in: S_GridDims, hm_in: u32, i_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var hm: u32 = hm_in;
    var i: i32 = i_in;
    return bitcast<f32>(mem_ld((hm + bitcast<u32>((i + 3i)))));
}

fn f_hm_vh(g_in: S_GridDims, hm_in: u32, j_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var hm: u32 = hm_in;
    var j: i32 = j_in;
    return bitcast<f32>(mem_ld((hm + bitcast<u32>((((2i * g.strideJ) + j) + 3i)))));
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    var g: S_GridDims = ld_GridDims(ARG[4]);
    var p: S_StabilityParams = ld_StabilityParams(ARG[5]);
    var u: u32 = ARG[6];
    var v: u32 = ARG[7];
    var w: u32 = ARG[8];
    var mh: u32 = ARG[9];
    var kmh: u32 = ARG[10];
    var kmv: u32 = ARG[11];
    var khh: u32 = ARG[12];
    var out: u32 = ARG[13];
    var hm: u32 = ARG[34];
    var tid: vec3<u32> = gid;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    var k: i32 = i32(tid.z);
    var inside: bool = (((i < g.nx) && (j < g.ny)) && (k < g.nz));
    var c2: f32 = 0.0f;
    var m: f32 = 0.0f;
    if (inside) {
        var c: i32 = f_gidx(g, i, j, k);
        var uh: f32 = f_hm_uh(g, hm, i);
        var vh: f32 = f_hm_vh(g, hm, j);
        let _t1 = f_gidx(g, (i + 1i), j, k);
        var x: f32 = opq((opq((opq((bitcast<f32>(mem_ld((u + bitcast<u32>(c))))) + (bitcast<f32>(mem_ld((u + bitcast<u32>(_t1))))))) * (opq(p.dtdx)))) * (opq(uh)));
        let _t2 = f_gidx(g, i, j, (k + 1i));
        var z: f32 = opq((opq((opq((bitcast<f32>(mem_ld((w + bitcast<u32>(c))))) + (bitcast<f32>(mem_ld((w + bitcast<u32>(_t2))))))) * (opq(p.dtdz)))) * (bitcast<f32>(mem_ld((mh + bitcast<u32>(c))))));
        if ((p.twoD != 0i)) {
            c2 = opq(fma(opq(x), opq(x), opq((opq(z)) * (opq(z)))));
        } else {
            let _t3 = f_gidx(g, i, (j + 1i), k);
            var y: f32 = opq((opq((opq((bitcast<f32>(mem_ld((v + bitcast<u32>(c))))) + (bitcast<f32>(mem_ld((v + bitcast<u32>(_t3))))))) * (opq(p.dtdy)))) * (opq(vh)));
            c2 = opq(fma(opq(z), opq(z), (opq(fma(opq(x), opq(x), opq((opq(y)) * (opq(y))))))));
        }
        if (((p.withKs != 0i) && (k >= 1i))) {
            var K: array<f32, 3>;
            K[0] = bitcast<f32>(mem_ld((kmh + bitcast<u32>(c))));
            K[1] = bitcast<f32>(mem_ld((khh + bitcast<u32>(c))));
            K[2] = bitcast<f32>(mem_ld((kmv + bitcast<u32>(c))));
            {
                var n: i32 = 0i;
                loop {
                    if (!((n < 3i))) { break; }
                        var a: f32 = opq((opq((opq((opq((*&K)[n])) * (opq(p.ksdx)))) * (opq(uh)))) * (opq(uh)));
                        var t: f32;
                        if ((p.twoD != 0i)) {
                            t = a;
                        } else {
                            var b: f32 = opq((opq((opq((opq((*&K)[n])) * (opq(p.ksdy)))) * (opq(vh)))) * (opq(vh)));
                            t = opq(fma(opq(a), opq(a), opq((opq(b)) * (opq(b)))));
                        }
                        m = opq(max(m, t));
                    continuing {
                        n = (n + 1i);
                    }
                }
            }
        }
    }
    var cb: u32 = bitcast<u32>(c2);
    var kb: u32 = bitcast<u32>(m);
    if (true) {
        _ = atomicMax(&M[out], cb);
        _ = atomicMax(&M[(out + bitcast<u32>(1i))], kb);
    }
}
