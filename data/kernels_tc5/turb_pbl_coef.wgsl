// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// turb_pbl_coef: сгенерировано, не править руками.

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

struct S_PblParams {
    linf: f32,
    lh: f32,
    lhref1: f32,
    lhref2: f32,
    xland: f32,
    zntField: i32,
    znt: f32,
    diss: i32,
    useVert: i32,
    useHoriz: i32,
}

const K_SFC_KARMAN: f32 = 0.4f;

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

fn ld_PblParams(o: u32) -> S_PblParams {
    var s: S_PblParams;
    s.linf = bitcast<f32>(mem_ld((o + 0u)));
    s.lh = bitcast<f32>(mem_ld((o + 1u)));
    s.lhref1 = bitcast<f32>(mem_ld((o + 2u)));
    s.lhref2 = bitcast<f32>(mem_ld((o + 3u)));
    s.xland = bitcast<f32>(mem_ld((o + 4u)));
    s.zntField = bitcast<i32>(mem_ld((o + 5u)));
    s.znt = bitcast<f32>(mem_ld((o + 6u)));
    s.diss = bitcast<i32>(mem_ld((o + 7u)));
    s.useVert = bitcast<i32>(mem_ld((o + 8u)));
    s.useHoriz = bitcast<i32>(mem_ld((o + 9u)));
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
    var p: S_PblParams = ld_PblParams(ARG[5]);
    var nm: u32 = ARG[6];
    var defv: u32 = ARG[7];
    var defh: u32 = ARG[8];
    var zf: u32 = ARG[9];
    var sfc: u32 = ARG[10];
    var kmh: u32 = ARG[11];
    var kmv: u32 = ARG[12];
    var khh: u32 = ARG[13];
    var khv: u32 = ARG[14];
    var dissten: u32 = ARG[15];
    var tid: vec3<u32> = gid;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    var k: i32 = ((i32(tid.z)) + 1i);
    if ((((i >= g.nx) || (j >= g.ny)) || (k > (g.nz - 1i)))) {
        return;
    }
    var c: i32 = f_gidx(g, i, j, k);
    var plane: i32 = (g.strideJ * g.strideK);
    var o: i32 = f_gidx(g, i, j, 0i);
    var karman: f32 = K_SFC_KARMAN;
    var prinv: f32 = 1.0f;
    var dmin: f32 = 1e-10f;
    var lvz: f32 = 0.0f;
    var tlh: f32 = p.lh;
    if (((p.useVert != 0i) && (p.linf > (1e-12f)))) {
        var a: f32 = opq((opq(1e-06f)) + (opq(p.linf)));
        var rlinf: f32 = div_cr(1.0f, (opq((opq(a)) * (opq(a)))));
        var z0: f32 = select(p.znt, bitcast<f32>(mem_ld((sfc + bitcast<u32>(((4i * plane) + o))))), (p.zntField != 0i));
        var b: f32 = opq((opq(karman)) * (opq((opq((bitcast<f32>(mem_ld((zf + bitcast<u32>(k))))) - (bitcast<f32>(mem_ld((zf + bitcast<u32>((0i)))))))) + (opq(z0)))));
        lvz = sqrt_cr(div_cr(1.0f, (opq((opq(rlinf)) + (opq(div_cr(1.0f, (opq((opq(b)) * (opq(b)))))))))));
        var km: f32 = opq((opq((opq(lvz)) * (opq(lvz)))) * (opq(sqrt_cr(opq(max(opq(fma(opq((-(bitcast<f32>(mem_ld((nm + bitcast<u32>(c))))))), opq(prinv), bitcast<f32>(mem_ld((defv + bitcast<u32>(c)))))), dmin))))));
        mem_st((kmv + bitcast<u32>(c)), bitcast<u32>(km));
        mem_st((khv + bitcast<u32>(c)), bitcast<u32>(opq((opq(km)) * (opq(prinv)))));
    }
    if ((p.useHoriz != 0i)) {
        if ((p.xland > 1.5f)) {
            var psfc: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>(((11i * plane) + o)))));
            tlh = opq((opq(p.lhref2)) + (opq(div_cr(opq((opq((opq(p.lhref1)) - (opq(p.lhref2)))) * (opq((opq(psfc)) - (opq(9e+04f))))), (opq((opq(1.015e+05f)) - (opq(9e+04f))))))));
        }
        var km: f32 = opq((opq((opq(tlh)) * (opq(tlh)))) * (opq(sqrt_cr(opq(max(bitcast<f32>(mem_ld((defh + bitcast<u32>(c)))), dmin))))));
        mem_st((kmh + bitcast<u32>(c)), bitcast<u32>(km));
        mem_st((khh + bitcast<u32>(c)), bitcast<u32>(opq((opq(km)) * (opq(prinv)))));
    }
    if ((p.diss != 0i)) {
        var d: f32 = bitcast<f32>(mem_ld((dissten + bitcast<u32>(c))));
        if (((p.useVert != 0i) && (p.linf > (1e-12f)))) {
            var km: f32 = bitcast<f32>(mem_ld((kmv + bitcast<u32>(c))));
            var l2: f32 = opq((opq(lvz)) * (opq(lvz)));
            d = opq((opq(d)) + (opq(div_cr((opq((opq((opq(km)) * (opq(km)))) * (opq(km)))), (opq((opq(l2)) * (opq(l2))))))));
        }
        if ((p.useHoriz != 0i)) {
            var km: f32 = bitcast<f32>(mem_ld((kmh + bitcast<u32>(c))));
            var t2: f32 = opq((opq(tlh)) * (opq(tlh)));
            d = opq((opq(d)) + (opq(div_cr((opq((opq((opq(km)) * (opq(km)))) * (opq(km)))), (opq((opq(t2)) * (opq(t2))))))));
        }
        mem_st((dissten + bitcast<u32>(c)), bitcast<u32>(d));
    }
}
