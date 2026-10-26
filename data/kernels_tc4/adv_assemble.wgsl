// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// adv_assemble: сгенерировано, не править руками.

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

fn f_hm_uf(g_in: S_GridDims, hm_in: u32, i_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var hm: u32 = hm_in;
    var i: i32 = i_in;
    return bitcast<f32>(mem_ld((hm + bitcast<u32>(((g.strideJ + i) + 3i)))));
}

fn f_hm_vf(g_in: S_GridDims, hm_in: u32, j_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var hm: u32 = hm_in;
    var j: i32 = j_in;
    return bitcast<f32>(mem_ld((hm + bitcast<u32>(((((2i * g.strideJ) + g.strideK) + j) + 3i)))));
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
    var s: u32 = ARG[6];
    var fx: u32 = ARG[7];
    var fy: u32 = ARG[8];
    var fz: u32 = ARG[9];
    var divx: u32 = ARG[10];
    var rho0: u32 = ARG[11];
    var rf0: u32 = ARG[12];
    var mh: u32 = ARG[13];
    var mf: u32 = ARG[14];
    var tend: u32 = ARG[15];
    var accumulate: i32 = bitcast<i32>(mem_ld(ARG[16]));
    var rru: u32 = ARG[17];
    var rrv: u32 = ARG[18];
    var c1: u32 = ARG[19];
    var c2: u32 = ARG[20];
    var open: vec2<i32> = vec2<i32>(bitcast<i32>(mem_ld((ARG[21] + 0u))), bitcast<i32>(mem_ld((ARG[21] + 1u))));
    var hm: u32 = ARG[34];
    var rr0: u32 = ARG[22];
    var advz6: u32 = ARG[23];
    var fcor: f32 = bitcast<f32>(mem_ld(ARG[31]));
    var tpl: u32 = ARG[28];
    var tz: u32 = ARG[29];
    var tid: vec3<u32> = gid;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    var k: i32 = i32(tid.z);
    var st: i32 = select(stag, (-stag), (stag < 0i));
    var iMax: i32 = select((g.nx - 1i), g.nx, (st == 2i));
    var jMax: i32 = select((g.ny - 1i), g.ny, (st == 3i));
    var kLo: i32 = select(0i, 1i, (st == 4i));
    var kMax: i32 = (g.nz - 1i);
    if (((((i > iMax) || (j > jMax)) || (k < kLo)) || (k > kMax))) {
        return;
    }
    if ((((open.x != 0i) && (st == 2i)) && ((i == 0i) || (i == g.nx)))) {
        return;
    }
    if ((((open.y != 0i) && (st == 3i)) && ((j == 0i) || (j == g.ny)))) {
        return;
    }
    var c: i32 = f_gidx(g, i, j, k);
    var sj: i32 = g.strideJ;
    var sk: i32 = (g.strideJ * g.strideK);
    var dFx: f32 = select((opq((bitcast<f32>(mem_ld((fx + bitcast<u32>((c + 1i)))))) - (bitcast<f32>(mem_ld((fx + bitcast<u32>(c))))))), (opq((bitcast<f32>(mem_ld((fx + bitcast<u32>(c))))) - (bitcast<f32>(mem_ld((fx + bitcast<u32>((c - 1i)))))))), (st == 2i));
    var dFy: f32 = select((opq((bitcast<f32>(mem_ld((fy + bitcast<u32>((c + sj)))))) - (bitcast<f32>(mem_ld((fy + bitcast<u32>(c))))))), (opq((bitcast<f32>(mem_ld((fy + bitcast<u32>(c))))) - (bitcast<f32>(mem_ld((fy + bitcast<u32>((c - sj)))))))), (st == 3i));
    var dFz: f32 = select((opq((bitcast<f32>(mem_ld((fz + bitcast<u32>((c + sk)))))) - (bitcast<f32>(mem_ld((fz + bitcast<u32>(c))))))), (opq((bitcast<f32>(mem_ld((fz + bitcast<u32>(c))))) - (bitcast<f32>(mem_ld((fz + bitcast<u32>((c - sk)))))))), (st == 4i));
    var mz: f32 = select(select((bitcast<f32>(mem_ld((mh + bitcast<u32>(k))))), (bitcast<f32>(mem_ld((mf + bitcast<u32>(k))))), (stag == 4i)), 1.0f, (stag < 0i));
    var dv: f32;
    if ((st == 2i)) {
        dv = opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((divx + bitcast<u32>(c))))) + (bitcast<f32>(mem_ld((divx + bitcast<u32>((c - 1i)))))))));
    } else {
        if ((st == 3i)) {
            dv = opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((divx + bitcast<u32>(c))))) + (bitcast<f32>(mem_ld((divx + bitcast<u32>((c - sj)))))))));
        } else {
            if ((st == 4i)) {
                dv = opq(fma(bitcast<f32>(mem_ld((c2 + bitcast<u32>(k)))), bitcast<f32>(mem_ld((divx + bitcast<u32>(c)))), opq((bitcast<f32>(mem_ld((c1 + bitcast<u32>(k))))) * (bitcast<f32>(mem_ld((divx + bitcast<u32>((c - sk)))))))));
            } else {
                dv = bitcast<f32>(mem_ld((divx + bitcast<u32>(c))));
            }
        }
    }
    if (((open.x != 0i) && (st != 2i))) {
        var west: bool = (i == 0i);
        var east: bool = (i == (g.nx - 1i));
        if ((west || east)) {
            var cf: i32 = select((c + 1i), c, west);
            var un: f32;
            var piece: f32;
            if ((st == 3i)) {
                un = opq((bitcast<f32>(mem_ld((rru + bitcast<u32>(cf))))) + (bitcast<f32>(mem_ld((rru + bitcast<u32>((cf - sj)))))));
                piece = opq((opq((opq((opq(0.5f)) * (opq((opq((bitcast<f32>(mem_ld((rru + bitcast<u32>(((c + 1i) - sj)))))) - (bitcast<f32>(mem_ld((rru + bitcast<u32>((c - sj)))))))) + (opq((bitcast<f32>(mem_ld((rru + bitcast<u32>((c + 1i)))))) - (bitcast<f32>(mem_ld((rru + bitcast<u32>(c))))))))))) * (opq(g.rdx)))) * (opq(f_hm_uh(g, hm, i))));
            } else {
                if ((st == 4i)) {
                    var cc2: f32 = opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((c2 + bitcast<u32>((k - 1i)))))) + (bitcast<f32>(mem_ld((c2 + bitcast<u32>(k))))))));
                    var cc1: f32 = opq((opq(1.0f)) - (opq(cc2)));
                    un = opq(fma(opq(cc2), bitcast<f32>(mem_ld((rru + bitcast<u32>(cf)))), opq((opq(cc1)) * (bitcast<f32>(mem_ld((rru + bitcast<u32>((cf - sk)))))))));
                    piece = opq((opq((opq(fma(bitcast<f32>(mem_ld((c1 + bitcast<u32>(k)))), (opq((bitcast<f32>(mem_ld((rru + bitcast<u32>(((c + 1i) - sk)))))) - (bitcast<f32>(mem_ld((rru + bitcast<u32>((c - sk)))))))), opq((bitcast<f32>(mem_ld((c2 + bitcast<u32>(k))))) * (opq((bitcast<f32>(mem_ld((rru + bitcast<u32>((c + 1i)))))) - (bitcast<f32>(mem_ld((rru + bitcast<u32>(c))))))))))) * (opq(g.rdx)))) * (opq(f_hm_uh(g, hm, i))));
                } else {
                    un = bitcast<f32>(mem_ld((rru + bitcast<u32>(cf))));
                    piece = opq((opq((opq((bitcast<f32>(mem_ld((rru + bitcast<u32>((c + 1i)))))) - (bitcast<f32>(mem_ld((rru + bitcast<u32>(c))))))) * (opq(g.rdx)))) * (opq(f_hm_uh(g, hm, i))));
                }
            }
            var inflow: bool = select((un <= 0.0f), (un >= 0.0f), west);
            if (inflow) {
                dFx = 0.0f;
                dv = opq((opq(dv)) - (opq(piece)));
            }
        }
    }
    if (((open.y != 0i) && (st != 3i))) {
        var south: bool = (j == 0i);
        var north: bool = (j == (g.ny - 1i));
        if ((south || north)) {
            var cf: i32 = select((c + sj), c, south);
            var vn: f32;
            var piece: f32;
            if ((st == 2i)) {
                vn = opq((bitcast<f32>(mem_ld((rrv + bitcast<u32>(cf))))) + (bitcast<f32>(mem_ld((rrv + bitcast<u32>((cf - 1i)))))));
                piece = opq((opq((opq((opq(0.5f)) * (opq((opq((bitcast<f32>(mem_ld((rrv + bitcast<u32>(((c + sj) - 1i)))))) - (bitcast<f32>(mem_ld((rrv + bitcast<u32>((c - 1i)))))))) + (opq((bitcast<f32>(mem_ld((rrv + bitcast<u32>((c + sj)))))) - (bitcast<f32>(mem_ld((rrv + bitcast<u32>(c))))))))))) * (opq(g.rdy)))) * (opq(f_hm_vh(g, hm, j))));
            } else {
                if ((st == 4i)) {
                    var cc2: f32 = opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((c2 + bitcast<u32>((k - 1i)))))) + (bitcast<f32>(mem_ld((c2 + bitcast<u32>(k))))))));
                    var cc1: f32 = opq((opq(1.0f)) - (opq(cc2)));
                    vn = opq(fma(opq(cc2), bitcast<f32>(mem_ld((rrv + bitcast<u32>(cf)))), opq((opq(cc1)) * (bitcast<f32>(mem_ld((rrv + bitcast<u32>((cf - sk)))))))));
                    piece = opq((opq((opq(fma(bitcast<f32>(mem_ld((c1 + bitcast<u32>(k)))), (opq((bitcast<f32>(mem_ld((rrv + bitcast<u32>(((c + sj) - sk)))))) - (bitcast<f32>(mem_ld((rrv + bitcast<u32>((c - sk)))))))), opq((bitcast<f32>(mem_ld((c2 + bitcast<u32>(k))))) * (opq((bitcast<f32>(mem_ld((rrv + bitcast<u32>((c + sj)))))) - (bitcast<f32>(mem_ld((rrv + bitcast<u32>(c))))))))))) * (opq(g.rdy)))) * (opq(f_hm_vh(g, hm, j))));
                } else {
                    vn = bitcast<f32>(mem_ld((rrv + bitcast<u32>(cf))));
                    piece = opq((opq((opq((bitcast<f32>(mem_ld((rrv + bitcast<u32>((c + sj)))))) - (bitcast<f32>(mem_ld((rrv + bitcast<u32>(c))))))) * (opq(g.rdy)))) * (opq(f_hm_vh(g, hm, j))));
                }
            }
            var inflow: bool = select((vn <= 0.0f), (vn >= 0.0f), south);
            if (inflow) {
                dFy = 0.0f;
                dv = opq((opq(dv)) - (opq(piece)));
            }
        }
    }
    var _t1: f32;
    if ((st == 2i)) {
        _t1 = f_hm_uf(g, hm, i);
    } else {
        _t1 = f_hm_uh(g, hm, i);
    }
    var mx: f32 = _t1;
    var _t2: f32;
    if ((st == 3i)) {
        _t2 = f_hm_vf(g, hm, j);
    } else {
        _t2 = f_hm_vh(g, hm, j);
    }
    var my: f32 = _t2;
    var divF: f32 = opq(fma(opq((opq(dFz)) * (opq(g.rdz))), opq(mz), opq(fma(opq((opq(dFx)) * (opq(g.rdx))), opq(mx), opq((opq((opq(dFy)) * (opq(g.rdy)))) * (opq(my)))))));
    var rho: f32 = select((bitcast<f32>(mem_ld((rho0 + bitcast<u32>(k))))), (bitcast<f32>(mem_ld((rf0 + bitcast<u32>(k))))), (st == 4i));
    var t: f32 = div_cr((opq(fma(bitcast<f32>(mem_ld((s + bitcast<u32>(c)))), opq(dv), opq((-(opq(divF))))))), rho);
    mem_st((tend + bitcast<u32>(c)), bitcast<u32>(select(t, (opq((bitcast<f32>(mem_ld((tend + bitcast<u32>(c))))) + (opq(t)))), (accumulate != 0i))));
}
