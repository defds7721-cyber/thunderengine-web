// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// turb_sfcstress: сгенерировано, не править руками.

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

fn lam_1(ii_in: i32, jj_in: i32, comp_in: i32, g: ptr<function, S_GridDims>, sfc: u32, plane: ptr<function, i32>, au: ptr<function, f32>, av: ptr<function, f32>, as_v: ptr<function, f32>, den: ptr<function, f32>) -> f32 {
    var ii: i32 = ii_in;
    var jj: i32 = jj_in;
    var comp: i32 = comp_in;
    var q: i32 = f_gidx((*g), ii, jj, 0i);
    var us: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>(((3i * (*plane)) + q)))));
    var s1: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>(((2i * (*plane)) + q)))));
    var w1: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>(((comp * (*plane)) + q)))));
    var am: f32 = select((*av), (*au), (comp == 0i));
    return div_cr(opq((opq((opq(us)) * (opq(us)))) * (opq(fma(opq(s1), opq(am), opq((opq((*as_v))) * (opq((opq(w1)) - (opq(am))))))))), (*den));
}

fn f_hm_arf1(g_in: S_GridDims, hm_in: u32, i_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var hm: u32 = hm_in;
    var i: i32 = i_in;
    let _t1 = (((f_hm_axi_offset(g.strideJ, g.strideK)) + (2i * g.strideJ)) + i);
    return bitcast<f32>(mem_ld((hm + bitcast<u32>(_t1))));
}

fn f_hm_axi_offset(sJ_in: i32, sK_in: i32) -> i32 {
    var sJ: i32 = sJ_in;
    var sK: i32 = sK_in;
    return (((3i * sJ) + (3i * sK)) + 3i);
}

fn f_hm_arf2(g_in: S_GridDims, hm_in: u32, i_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var hm: u32 = hm_in;
    var i: i32 = i_in;
    let _t1 = (((f_hm_axi_offset(g.strideJ, g.strideK)) + (3i * g.strideJ)) + i);
    return bitcast<f32>(mem_ld((hm + bitcast<u32>(_t1))));
}

fn lam_2(ii_in: i32, jj_in: i32, comp_in: i32, g: ptr<function, S_GridDims>, sfc: u32, plane: ptr<function, i32>) -> f32 {
    var ii: i32 = ii_in;
    var jj: i32 = jj_in;
    var comp: i32 = comp_in;
    var q: i32 = f_gidx((*g), ii, jj, 0i);
    var us: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>(((3i * (*plane)) + q)))));
    return div_cr(opq((opq((opq(us)) * (opq(us)))) * (bitcast<f32>(mem_ld((sfc + bitcast<u32>(((comp * (*plane)) + q))))))), opq(max(bitcast<f32>(mem_ld((sfc + bitcast<u32>(((2i * (*plane)) + q))))), 0.01f)));
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    var g: S_GridDims = ld_GridDims(ARG[4]);
    var sfc: u32 = ARG[5];
    var rf: u32 = ARG[6];
    var t13: u32 = ARG[7];
    var t23: u32 = ARG[8];
    var mode: i32 = bitcast<i32>(mem_ld(ARG[9]));
    var u: u32 = ARG[10];
    var v: u32 = ARG[11];
    var move_v: vec2<f32> = vec2<f32>(bitcast<f32>(mem_ld((ARG[12] + 0u))), bitcast<f32>(mem_ld((ARG[12] + 1u))));
    var kmv: u32 = ARG[13];
    var topNoSlip: i32 = bitcast<i32>(mem_ld(ARG[14]));
    var mf: u32 = ARG[15];
    var hm: u32 = ARG[34];
    var tid: vec2<u32> = gid.xy;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    if (((i > g.nx) || (j > g.ny))) {
        return;
    }
    var plane: i32 = (g.strideJ * g.strideK);
    var sjj: i32 = g.strideJ;
    {
        var ct: i32 = f_gidx(g, i, j, g.nz);
        if ((topNoSlip != 0i)) {
            var cu: i32 = (ct - plane);
            var mftu: f32 = opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((mf + bitcast<u32>(g.nz))))) + (bitcast<f32>(mem_ld((mf + bitcast<u32>(g.nz))))))));
            var mftv: f32 = opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((mf + bitcast<u32>(g.nz))))) + (bitcast<f32>(mem_ld((mf + bitcast<u32>(g.nz))))))));
            mem_st((t13 + bitcast<u32>(ct)), bitcast<u32>(opq((opq((opq((opq((opq((opq((opq((opq((-(opq(2.0f))))) * (opq((bitcast<f32>(mem_ld((u + bitcast<u32>(cu))))) + (opq(move_v.x)))))) * (opq(g.rdz)))) * (opq(mftu)))) * (opq(0.5f)))) * (opq((bitcast<f32>(mem_ld((rf + bitcast<u32>((ct - 1i)))))) + (bitcast<f32>(mem_ld((rf + bitcast<u32>(ct))))))))) * (opq(0.5f)))) * (opq((bitcast<f32>(mem_ld((kmv + bitcast<u32>((cu - 1i)))))) + (bitcast<f32>(mem_ld((kmv + bitcast<u32>(cu))))))))));
            mem_st((t23 + bitcast<u32>(ct)), bitcast<u32>(opq((opq((opq((opq((opq((opq((opq((opq((-(opq(2.0f))))) * (opq((bitcast<f32>(mem_ld((v + bitcast<u32>(cu))))) + (opq(move_v.y)))))) * (opq(g.rdz)))) * (opq(mftv)))) * (opq(0.5f)))) * (opq((bitcast<f32>(mem_ld((rf + bitcast<u32>((ct - sjj)))))) + (bitcast<f32>(mem_ld((rf + bitcast<u32>(ct))))))))) * (opq(0.5f)))) * (opq((bitcast<f32>(mem_ld((kmv + bitcast<u32>((cu - sjj)))))) + (bitcast<f32>(mem_ld((kmv + bitcast<u32>(cu))))))))));
        } else {
            mem_st((t13 + bitcast<u32>(ct)), bitcast<u32>(bitcast<f32>(mem_ld((t13 + bitcast<u32>((ct - plane)))))));
            mem_st((t23 + bitcast<u32>(ct)), bitcast<u32>(bitcast<f32>(mem_ld((t23 + bitcast<u32>((ct - plane)))))));
        }
    }
    if ((mode == 0i)) {
        var c0: i32 = f_gidx(g, i, j, 0i);
        mem_st((t13 + bitcast<u32>(c0)), bitcast<u32>(bitcast<f32>(mem_ld((t13 + bitcast<u32>((c0 + plane)))))));
        mem_st((t23 + bitcast<u32>(c0)), bitcast<u32>(bitcast<f32>(mem_ld((t23 + bitcast<u32>((c0 + plane)))))));
        return;
    }
    var c: i32 = f_gidx(g, i, j, 0i);
    if ((mode == 4i)) {
        var sj: i32 = g.strideJ;
        var mfbu: f32 = opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((mf + bitcast<u32>((0i)))))) + (bitcast<f32>(mem_ld((mf + bitcast<u32>((0i)))))))));
        var mfbv: f32 = opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((mf + bitcast<u32>((0i)))))) + (bitcast<f32>(mem_ld((mf + bitcast<u32>((0i)))))))));
        mem_st((t13 + bitcast<u32>(c)), bitcast<u32>(opq((opq((opq((opq((opq((opq((opq((opq(2.0f)) * (opq((bitcast<f32>(mem_ld((u + bitcast<u32>(c))))) + (opq(move_v.x)))))) * (opq(g.rdz)))) * (opq(mfbu)))) * (opq(0.5f)))) * (opq((bitcast<f32>(mem_ld((rf + bitcast<u32>((c - 1i)))))) + (bitcast<f32>(mem_ld((rf + bitcast<u32>(c))))))))) * (opq(0.5f)))) * (opq((bitcast<f32>(mem_ld((kmv + bitcast<u32>(((c - 1i) + plane)))))) + (bitcast<f32>(mem_ld((kmv + bitcast<u32>((c + plane)))))))))));
        mem_st((t23 + bitcast<u32>(c)), bitcast<u32>(opq((opq((opq((opq((opq((opq((opq((opq(2.0f)) * (opq((bitcast<f32>(mem_ld((v + bitcast<u32>(c))))) + (opq(move_v.y)))))) * (opq(g.rdz)))) * (opq(mfbv)))) * (opq(0.5f)))) * (opq((bitcast<f32>(mem_ld((rf + bitcast<u32>((c - sj)))))) + (bitcast<f32>(mem_ld((rf + bitcast<u32>(c))))))))) * (opq(0.5f)))) * (opq((bitcast<f32>(mem_ld((kmv + bitcast<u32>(((c - sj) + plane)))))) + (bitcast<f32>(mem_ld((kmv + bitcast<u32>((c + plane)))))))))));
        return;
    }
    if ((mode == 2i)) {
        var sj: i32 = g.strideJ;
        let _t1 = ((2i * plane) + (f_gidx(g, (i - 1i), j, 0i)));
        var s1w: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>(_t1))));
        var s1c: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>(((2i * plane) + c)))));
        let _t2 = ((2i * plane) + (f_gidx(g, i, (j - 1i), 0i)));
        var s1s: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>(_t2))));
        mem_st((t13 + bitcast<u32>(c)), bitcast<u32>(opq((opq((opq((opq((opq((opq(0.001229f)) * (opq(0.5f)))) * (opq((opq(s1w)) + (opq(s1c)))))) * (opq((bitcast<f32>(mem_ld((u + bitcast<u32>(c))))) + (opq(move_v.x)))))) * (opq(0.5f)))) * (opq((bitcast<f32>(mem_ld((rf + bitcast<u32>((c - 1i)))))) + (bitcast<f32>(mem_ld((rf + bitcast<u32>(c))))))))));
        mem_st((t23 + bitcast<u32>(c)), bitcast<u32>(opq((opq((opq((opq((opq((opq(0.001229f)) * (opq(0.5f)))) * (opq((opq(s1s)) + (opq(s1c)))))) * (opq((bitcast<f32>(mem_ld((v + bitcast<u32>(c))))) + (opq(move_v.y)))))) * (opq(0.5f)))) * (opq((bitcast<f32>(mem_ld((rf + bitcast<u32>((c - sj)))))) + (bitcast<f32>(mem_ld((rf + bitcast<u32>(c))))))))));
        return;
    }
    if ((mode == 3i)) {
        var o0: i32 = f_gidx(g, 0i, 0i, 0i);
        var au: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>(((14i * plane) + o0)))));
        var av: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>(((15i * plane) + o0)))));
        var as_v: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>(((16i * plane) + o0)))));
        var den: f32 = opq(max(0.0001f, opq((opq(as_v)) * (opq(sqrt_cr(opq(fma(opq(au), opq(au), opq((opq(av)) * (opq(av)))))))))));
        mem_st((t13 + bitcast<u32>(c)), bitcast<u32>(opq((opq((opq(0.25f)) * (opq((opq(lam_1((i - 1i), j, 0i, &g, sfc, &plane, &au, &av, &as_v, &den))) + (opq(lam_1(i, j, 0i, &g, sfc, &plane, &au, &av, &as_v, &den))))))) * (opq((bitcast<f32>(mem_ld((rf + bitcast<u32>((c - 1i)))))) + (bitcast<f32>(mem_ld((rf + bitcast<u32>(c))))))))));
        mem_st((t23 + bitcast<u32>(c)), bitcast<u32>(opq((opq((opq(0.25f)) * (opq((opq(lam_1(i, (j - 1i), 1i, &g, sfc, &plane, &au, &av, &as_v, &den))) + (opq(lam_1(i, j, 1i, &g, sfc, &plane, &au, &av, &as_v, &den))))))) * (opq((bitcast<f32>(mem_ld((rf + bitcast<u32>((c - g.strideJ)))))) + (bitcast<f32>(mem_ld((rf + bitcast<u32>(c))))))))));
        return;
    }
    {
        var a1: f32 = f_hm_arf1(g, hm, i);
        var a2: f32 = f_hm_arf2(g, hm, i);
        mem_st((t13 + bitcast<u32>(c)), bitcast<u32>(opq((opq((opq(0.25f)) * (opq(fma(opq(a1), opq(lam_2((i - 1i), j, 0i, &g, sfc, &plane)), opq((opq(a2)) * (opq(lam_2(i, j, 0i, &g, sfc, &plane))))))))) * (opq(fma(opq(a1), bitcast<f32>(mem_ld((rf + bitcast<u32>((c - 1i))))), opq((opq(a2)) * (bitcast<f32>(mem_ld((rf + bitcast<u32>(c))))))))))));
        mem_st((t23 + bitcast<u32>(c)), bitcast<u32>(opq((bitcast<f32>(mem_ld((rf + bitcast<u32>(c))))) * (opq(lam_2(i, j, 1i, &g, sfc, &plane))))));
        return;
    }
    mem_st((t13 + bitcast<u32>(c)), bitcast<u32>(opq((opq((opq(0.25f)) * (opq((opq(lam_2((i - 1i), j, 0i, &g, sfc, &plane))) + (opq(lam_2(i, j, 0i, &g, sfc, &plane))))))) * (opq((bitcast<f32>(mem_ld((rf + bitcast<u32>((c - 1i)))))) + (bitcast<f32>(mem_ld((rf + bitcast<u32>(c))))))))));
    mem_st((t23 + bitcast<u32>(c)), bitcast<u32>(opq((opq((opq(0.25f)) * (opq((opq(lam_2(i, (j - 1i), 1i, &g, sfc, &plane))) + (opq(lam_2(i, j, 1i, &g, sfc, &plane))))))) * (opq((bitcast<f32>(mem_ld((rf + bitcast<u32>((c - g.strideJ)))))) + (bitcast<f32>(mem_ld((rf + bitcast<u32>(c))))))))));
}
