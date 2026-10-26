// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// turb_u_tendency: сгенерировано, не править руками.

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

fn f_hm_uf(g_in: S_GridDims, hm_in: u32, i_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var hm: u32 = hm_in;
    var i: i32 = i_in;
    return bitcast<f32>(mem_ld((hm + bitcast<u32>(((g.strideJ + i) + 3i)))));
}

fn lam_1(k_in: i32, base: ptr<function, i32>, sk: ptr<function, i32>, a1: ptr<function, f32>, rho: u32, a2: ptr<function, f32>) -> f32 {
    var k: i32 = k_in;
    var c: i32 = ((*base) + (k * (*sk)));
    return div_cr(1.0f, (opq((opq(0.5f)) * (opq(fma(opq((*a1)), bitcast<f32>(mem_ld((rho + bitcast<u32>((c - 1i))))), opq((opq((*a2))) * (bitcast<f32>(mem_ld((rho + bitcast<u32>(c))))))))))));
}

fn lam_2(k_in: i32, lev_in: i32, base: ptr<function, i32>, sk: ptr<function, i32>, mh: u32, a1: ptr<function, f32>, rho: u32, a2: ptr<function, f32>, kmv: u32, mf: u32, rf: u32) -> f32 {
    var k: i32 = k_in;
    var lev: i32 = lev_in;
    var c: i32 = ((*base) + (k * (*sk)));
    var cl: i32 = ((*base) + (lev * (*sk)));
    var tem: f32 = opq((bitcast<f32>(mem_ld((mh + bitcast<u32>(k))))) * (opq(lam_3(k, base, sk, a1, rho, a2))));
    return opq((opq((opq((opq((bitcast<f32>(mem_ld((kmv + bitcast<u32>((cl - 1i)))))) + (bitcast<f32>(mem_ld((kmv + bitcast<u32>(cl))))))) * (bitcast<f32>(mem_ld((mf + bitcast<u32>(lev))))))) * (opq(fma(opq((*a1)), bitcast<f32>(mem_ld((rf + bitcast<u32>((cl - 1i))))), opq((opq((*a2))) * (bitcast<f32>(mem_ld((rf + bitcast<u32>(cl))))))))))) * (opq(tem)));
}

fn lam_3(k_in: i32, base: ptr<function, i32>, sk: ptr<function, i32>, a1: ptr<function, f32>, rho: u32, a2: ptr<function, f32>) -> f32 {
    var k: i32 = k_in;
    var c: i32 = ((*base) + (k * (*sk)));
    return div_cr(1.0f, (opq((opq(0.5f)) * (opq(fma(opq((*a1)), bitcast<f32>(mem_ld((rho + bitcast<u32>((c - 1i))))), opq((opq((*a2))) * (bitcast<f32>(mem_ld((rho + bitcast<u32>(c))))))))))));
}

fn f_hm_vh(g_in: S_GridDims, hm_in: u32, j_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var hm: u32 = hm_in;
    var j: i32 = j_in;
    return bitcast<f32>(mem_ld((hm + bitcast<u32>((((2i * g.strideJ) + j) + 3i)))));
}

fn lam_4(k_in: i32, lev_in: i32, base: ptr<function, i32>, sk: ptr<function, i32>, mh: u32, rho: u32, kmv: u32, mf: u32, rf: u32) -> f32 {
    var k: i32 = k_in;
    var lev: i32 = lev_in;
    var c: i32 = ((*base) + (k * (*sk)));
    var cl: i32 = ((*base) + (lev * (*sk)));
    var tem: f32 = opq((opq((bitcast<f32>(mem_ld((mh + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((mh + bitcast<u32>(k))))))) * (opq(lam_5(k, base, sk, rho))));
    return opq((opq((opq((opq((bitcast<f32>(mem_ld((kmv + bitcast<u32>((cl - 1i)))))) + (bitcast<f32>(mem_ld((kmv + bitcast<u32>(cl))))))) * (opq((bitcast<f32>(mem_ld((mf + bitcast<u32>(lev))))) + (bitcast<f32>(mem_ld((mf + bitcast<u32>(lev))))))))) * (opq((bitcast<f32>(mem_ld((rf + bitcast<u32>((cl - 1i)))))) + (bitcast<f32>(mem_ld((rf + bitcast<u32>(cl))))))))) * (opq(tem)));
}

fn lam_5(k_in: i32, base: ptr<function, i32>, sk: ptr<function, i32>, rho: u32) -> f32 {
    var k: i32 = k_in;
    var c: i32 = ((*base) + (k * (*sk)));
    return div_cr(1.0f, (opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((rho + bitcast<u32>((c - 1i)))))) + (bitcast<f32>(mem_ld((rho + bitcast<u32>(c))))))))));
}

fn lam_6(k_in: i32, base: ptr<function, i32>, sk: ptr<function, i32>, rho: u32) -> f32 {
    var k: i32 = k_in;
    var c: i32 = ((*base) + (k * (*sk)));
    return div_cr(1.0f, (opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((rho + bitcast<u32>((c - 1i)))))) + (bitcast<f32>(mem_ld((rho + bitcast<u32>(c))))))))));
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    var g: S_GridDims = ld_GridDims(ARG[4]);
    var u: u32 = ARG[5];
    var w: u32 = ARG[6];
    var rho: u32 = ARG[7];
    var rf: u32 = ARG[8];
    var kmv: u32 = ARG[9];
    var t11: u32 = ARG[10];
    var t12: u32 = ARG[11];
    var t13: u32 = ARG[12];
    var mh: u32 = ARG[13];
    var mf: u32 = ARG[14];
    var dt: f32 = bitcast<f32>(mem_ld(ARG[15]));
    var cA: u32 = ARG[16];
    var cB: u32 = ARG[17];
    var dwdx: u32 = ARG[18];
    var uten: u32 = ARG[19];
    var open: vec2<i32> = vec2<i32>(bitcast<i32>(mem_ld((ARG[20] + 0u))), bitcast<i32>(mem_ld((ARG[20] + 1u))));
    var explicitZ: i32 = bitcast<i32>(mem_ld(ARG[21]));
    var hm: u32 = ARG[34];
    var tid: vec2<u32> = gid.xy;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    if (((i > g.nx) || (j >= g.ny))) {
        return;
    }
    var zeroX: bool = ((open.x != 0i) && ((i == 0i) || (i == g.nx)));
    var zeroY: bool = ((open.y != 0i) && ((j == 0i) || (j == (g.ny - 1i))));
    var sj: i32 = g.strideJ;
    var sk: i32 = (g.strideJ * g.strideK);
    var base: i32 = f_gidx(g, i, j, 0i);
    {
        if (((i == 0i) || (i == g.nx))) {
            return;
        }
        var a1: f32 = f_hm_arf1(g, hm, i);
        var a2: f32 = f_hm_arf2(g, hm, i);
        if ((explicitZ != 0i)) {
            {
                var k: i32 = 0i;
                loop {
                    if (!((k < g.nz))) { break; }
                        var c: i32 = (base + (k * sk));
                        var turbx: f32 = opq((opq((opq(fma(opq((opq(a2)) * (opq(a2))), bitcast<f32>(mem_ld((t11 + bitcast<u32>(c)))), opq((-(opq((opq((opq(a1)) * (opq(a1)))) * (bitcast<f32>(mem_ld((t11 + bitcast<u32>((c - 1i))))))))))))) * (opq(g.rdx)))) * (opq(f_hm_uf(g, hm, i))));
                        var turbz: f32 = opq((opq((opq((opq((bitcast<f32>(mem_ld((t13 + bitcast<u32>((c + sk)))))) - (bitcast<f32>(mem_ld((t13 + bitcast<u32>(c))))))) * (opq(g.rdz)))) * (opq(0.5f)))) * (opq((bitcast<f32>(mem_ld((mh + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((mh + bitcast<u32>(k))))))));
                        mem_st((uten + bitcast<u32>(c)), bitcast<u32>(opq(fma((opq((opq(turbx)) + (opq(turbz)))), opq(lam_1(k, &base, &sk, &a1, rho, &a2)), bitcast<f32>(mem_ld((uten + bitcast<u32>(c))))))));
                    continuing {
                        k = (k + 1i);
                    }
                }
            }
            return;
        }
        var temaA: f32 = opq((opq((opq((opq((-(opq(0.25f))))) * (opq(dt)))) * (opq(g.rdz)))) * (opq(g.rdz)));
        var temcA: f32 = opq((opq(dt)) * (opq(g.rdz)));
        var rdtA: f32 = div_cr(0.5f, dt);
        {
            var k: i32 = 0i;
            loop {
                if (!((k <= g.nz))) { break; }
                    var c: i32 = (base + (k * sk));
                    mem_st((dwdx + bitcast<u32>(c)), bitcast<u32>(opq((opq((opq((opq((opq((opq((bitcast<f32>(mem_ld((w + bitcast<u32>(c))))) - (bitcast<f32>(mem_ld((w + bitcast<u32>((c - 1i)))))))) * (opq(g.rdx)))) * (opq(f_hm_uf(g, hm, i))))) * (opq(0.25f)))) * (opq(fma(opq(a1), bitcast<f32>(mem_ld((kmv + bitcast<u32>((c - 1i))))), opq((opq(a2)) * (bitcast<f32>(mem_ld((kmv + bitcast<u32>(c))))))))))) * (opq(fma(opq(a1), bitcast<f32>(mem_ld((rf + bitcast<u32>((c - 1i))))), opq((opq(a2)) * (bitcast<f32>(mem_ld((rf + bitcast<u32>(c))))))))))));
                continuing {
                    k = (k + 1i);
                }
            }
        }
        {
            var cfc: f32 = opq((opq(temaA)) * (opq(lam_2(0i, 1i, &base, &sk, mh, &a1, rho, &a2, kmv, mf, rf))));
            var cfb: f32 = opq((opq(1.0f)) - (opq(cfc)));
            var cfd: f32 = opq(fma(opq((-(opq((opq((opq(temcA)) * (bitcast<f32>(mem_ld((t13 + bitcast<u32>(base))))))) * (bitcast<f32>(mem_ld((mh + bitcast<u32>((0i)))))))))), opq(lam_1(0i, &base, &sk, &a1, rho, &a2)), bitcast<f32>(mem_ld((u + bitcast<u32>(base))))));
            var t: f32 = div_cr(1.0f, cfb);
            mem_st((cA + bitcast<u32>(base)), bitcast<u32>(opq((opq((-(opq(cfc))))) * (opq(t)))));
            mem_st((cB + bitcast<u32>(base)), bitcast<u32>(opq((opq(cfd)) * (opq(t)))));
        }
        {
            var k: i32 = 1i;
            loop {
                if (!((k < (g.nz - 1i)))) { break; }
                    var c: i32 = (base + (k * sk));
                    var cfa: f32 = opq((opq(temaA)) * (opq(lam_2(k, k, &base, &sk, mh, &a1, rho, &a2, kmv, mf, rf))));
                    var cfc: f32 = opq((opq(temaA)) * (opq(lam_2(k, (k + 1i), &base, &sk, mh, &a1, rho, &a2, kmv, mf, rf))));
                    var cfb: f32 = opq((opq((opq(1.0f)) - (opq(cfa)))) - (opq(cfc)));
                    var t: f32 = div_cr(1.0f, (opq(fma(opq(cfa), bitcast<f32>(mem_ld((cA + bitcast<u32>((c - sk))))), opq(cfb)))));
                    mem_st((cA + bitcast<u32>(c)), bitcast<u32>(opq((opq((-(opq(cfc))))) * (opq(t)))));
                    mem_st((cB + bitcast<u32>(c)), bitcast<u32>(opq((opq(fma(opq((-(opq(cfa)))), bitcast<f32>(mem_ld((cB + bitcast<u32>((c - sk))))), bitcast<f32>(mem_ld((u + bitcast<u32>(c))))))) * (opq(t)))));
                continuing {
                    k = (k + 1i);
                }
            }
        }
        var ktA: i32 = (g.nz - 1i);
        var ctA: i32 = (base + (ktA * sk));
        {
            var cfa: f32 = opq((opq(temaA)) * (opq(lam_2(ktA, ktA, &base, &sk, mh, &a1, rho, &a2, kmv, mf, rf))));
            var cfb: f32 = opq((opq(1.0f)) - (opq(cfa)));
            var cfd: f32 = opq(fma(opq((opq((opq(temcA)) * (bitcast<f32>(mem_ld((t13 + bitcast<u32>((base + (g.nz * sk))))))))) * (bitcast<f32>(mem_ld((mh + bitcast<u32>(ktA)))))), opq(lam_1(ktA, &base, &sk, &a1, rho, &a2)), bitcast<f32>(mem_ld((u + bitcast<u32>(ctA))))));
            var t: f32 = div_cr(1.0f, (opq(fma(opq(cfa), bitcast<f32>(mem_ld((cA + bitcast<u32>((ctA - sk))))), opq(cfb)))));
            mem_st((cB + bitcast<u32>(ctA)), bitcast<u32>(opq((opq(fma(opq((-(opq(cfa)))), bitcast<f32>(mem_ld((cB + bitcast<u32>((ctA - sk))))), opq(cfd)))) * (opq(t)))));
        }
        {
            var k: i32 = (g.nz - 2i);
            loop {
                if (!((k >= 0i))) { break; }
                    var c: i32 = (base + (k * sk));
                    mem_st((cB + bitcast<u32>(c)), bitcast<u32>(opq(fma(bitcast<f32>(mem_ld((cA + bitcast<u32>(c)))), bitcast<f32>(mem_ld((cB + bitcast<u32>((c + sk))))), bitcast<f32>(mem_ld((cB + bitcast<u32>(c))))))));
                continuing {
                    k = (k - 1i);
                }
            }
        }
        {
            var k: i32 = 0i;
            loop {
                if (!((k < g.nz))) { break; }
                    var c: i32 = (base + (k * sk));
                    var turbx: f32 = opq((opq((opq(fma(opq((opq(a2)) * (opq(a2))), bitcast<f32>(mem_ld((t11 + bitcast<u32>(c)))), opq((-(opq((opq((opq(a1)) * (opq(a1)))) * (bitcast<f32>(mem_ld((t11 + bitcast<u32>((c - 1i))))))))))))) * (opq(g.rdx)))) * (opq(f_hm_uf(g, hm, i))));
                    var turbz: f32 = opq((opq((opq(fma(opq(a1), bitcast<f32>(mem_ld((rho + bitcast<u32>((c - 1i))))), opq((opq(a2)) * (bitcast<f32>(mem_ld((rho + bitcast<u32>(c))))))))) * (opq((bitcast<f32>(mem_ld((cB + bitcast<u32>(c))))) - (bitcast<f32>(mem_ld((u + bitcast<u32>(c))))))))) * (opq(rdtA)));
                    turbz = opq(fma(opq((opq((opq((bitcast<f32>(mem_ld((dwdx + bitcast<u32>((c + sk)))))) - (bitcast<f32>(mem_ld((dwdx + bitcast<u32>(c))))))) * (opq(g.rdz)))) * (opq(0.5f))), (opq((bitcast<f32>(mem_ld((mh + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((mh + bitcast<u32>(k))))))), opq(turbz)));
                    mem_st((uten + bitcast<u32>(c)), bitcast<u32>(opq(fma((opq((opq(turbx)) + (opq(turbz)))), opq(lam_1(k, &base, &sk, &a1, rho, &a2)), bitcast<f32>(mem_ld((uten + bitcast<u32>(c))))))));
                continuing {
                    k = (k + 1i);
                }
            }
        }
        return;
    }
    if ((explicitZ != 0i)) {
        {
            var k: i32 = 0i;
            loop {
                if (!((k < g.nz))) { break; }
                    var c: i32 = (base + (k * sk));
                    var _t1: f32;
                    if (zeroX) {
                        _t1 = 0.0f;
                    } else {
                        _t1 = opq((opq((opq((bitcast<f32>(mem_ld((t11 + bitcast<u32>(c))))) - (bitcast<f32>(mem_ld((t11 + bitcast<u32>((c - 1i)))))))) * (opq(g.rdx)))) * (opq(f_hm_uf(g, hm, i))));
                    }
                    var turbx: f32 = _t1;
                    var _t2: f32;
                    if (zeroY) {
                        _t2 = 0.0f;
                    } else {
                        _t2 = opq((opq((opq((bitcast<f32>(mem_ld((t12 + bitcast<u32>((c + sj)))))) - (bitcast<f32>(mem_ld((t12 + bitcast<u32>(c))))))) * (opq(g.rdy)))) * (opq(f_hm_vh(g, hm, j))));
                    }
                    var turby: f32 = _t2;
                    var turbz: f32 = opq((opq((opq((opq((bitcast<f32>(mem_ld((t13 + bitcast<u32>((c + sk)))))) - (bitcast<f32>(mem_ld((t13 + bitcast<u32>(c))))))) * (opq(g.rdz)))) * (opq(0.5f)))) * (opq((bitcast<f32>(mem_ld((mh + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((mh + bitcast<u32>(k))))))));
                    mem_st((uten + bitcast<u32>(c)), bitcast<u32>(opq((bitcast<f32>(mem_ld((uten + bitcast<u32>(c))))) + (opq(div_cr((opq((opq((opq(turbx)) + (opq(turby)))) + (opq(turbz)))), (opq((opq(0.5f)) * (opq((bitcast<f32>(mem_ld((rho + bitcast<u32>((c - 1i)))))) + (bitcast<f32>(mem_ld((rho + bitcast<u32>(c)))))))))))))));
                continuing {
                    k = (k + 1i);
                }
            }
        }
        return;
    }
    var tema: f32 = opq((opq((opq((opq((-(opq(0.0625f))))) * (opq(dt)))) * (opq(g.rdz)))) * (opq(g.rdz)));
    var temc: f32 = opq((opq((opq(0.5f)) * (opq(dt)))) * (opq(g.rdz)));
    var rdt: f32 = div_cr(0.5f, dt);
    {
        var k: i32 = 0i;
        loop {
            if (!((k <= g.nz))) { break; }
                var c: i32 = (base + (k * sk));
                mem_st((dwdx + bitcast<u32>(c)), bitcast<u32>(opq((opq((opq((opq((opq((opq((bitcast<f32>(mem_ld((w + bitcast<u32>(c))))) - (bitcast<f32>(mem_ld((w + bitcast<u32>((c - 1i)))))))) * (opq(g.rdx)))) * (opq(f_hm_uf(g, hm, i))))) * (opq(0.25f)))) * (opq((bitcast<f32>(mem_ld((kmv + bitcast<u32>((c - 1i)))))) + (bitcast<f32>(mem_ld((kmv + bitcast<u32>(c))))))))) * (opq((bitcast<f32>(mem_ld((rf + bitcast<u32>((c - 1i)))))) + (bitcast<f32>(mem_ld((rf + bitcast<u32>(c))))))))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    {
        var r2: f32 = lam_4(0i, 1i, &base, &sk, mh, rho, kmv, mf, rf);
        var cfc: f32 = opq((opq(tema)) * (opq(r2)));
        var cfb: f32 = opq((opq(1.0f)) - (opq(cfc)));
        var cfd: f32 = opq(fma(opq((-(opq((opq((opq(temc)) * (bitcast<f32>(mem_ld((t13 + bitcast<u32>(base))))))) * (opq((bitcast<f32>(mem_ld((mh + bitcast<u32>((0i)))))) + (bitcast<f32>(mem_ld((mh + bitcast<u32>((0i)))))))))))), opq(lam_6(0i, &base, &sk, rho)), bitcast<f32>(mem_ld((u + bitcast<u32>(base))))));
        var t: f32 = div_cr(1.0f, cfb);
        mem_st((cA + bitcast<u32>(base)), bitcast<u32>(opq((opq((-(opq(cfc))))) * (opq(t)))));
        mem_st((cB + bitcast<u32>(base)), bitcast<u32>(opq((opq(cfd)) * (opq(t)))));
    }
    {
        var k: i32 = 1i;
        loop {
            if (!((k < (g.nz - 1i)))) { break; }
                var c: i32 = (base + (k * sk));
                var cfa: f32 = opq((opq(tema)) * (opq(lam_4(k, k, &base, &sk, mh, rho, kmv, mf, rf))));
                var cfc: f32 = opq((opq(tema)) * (opq(lam_4(k, (k + 1i), &base, &sk, mh, rho, kmv, mf, rf))));
                var cfb: f32 = opq((opq((opq(1.0f)) - (opq(cfa)))) - (opq(cfc)));
                var t: f32 = div_cr(1.0f, (opq(fma(opq(cfa), bitcast<f32>(mem_ld((cA + bitcast<u32>((c - sk))))), opq(cfb)))));
                mem_st((cA + bitcast<u32>(c)), bitcast<u32>(opq((opq((-(opq(cfc))))) * (opq(t)))));
                mem_st((cB + bitcast<u32>(c)), bitcast<u32>(opq((opq(fma(opq((-(opq(cfa)))), bitcast<f32>(mem_ld((cB + bitcast<u32>((c - sk))))), bitcast<f32>(mem_ld((u + bitcast<u32>(c))))))) * (opq(t)))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    var kt: i32 = (g.nz - 1i);
    var ct: i32 = (base + (kt * sk));
    {
        var cfa: f32 = opq((opq(tema)) * (opq(lam_4(kt, kt, &base, &sk, mh, rho, kmv, mf, rf))));
        var cfb: f32 = opq((opq(1.0f)) - (opq(cfa)));
        var cfd: f32 = opq(fma(opq((opq((opq(temc)) * (bitcast<f32>(mem_ld((t13 + bitcast<u32>((base + (g.nz * sk))))))))) * (opq((bitcast<f32>(mem_ld((mh + bitcast<u32>(kt))))) + (bitcast<f32>(mem_ld((mh + bitcast<u32>(kt)))))))), opq(lam_6(kt, &base, &sk, rho)), bitcast<f32>(mem_ld((u + bitcast<u32>(ct))))));
        var t: f32 = div_cr(1.0f, (opq(fma(opq(cfa), bitcast<f32>(mem_ld((cA + bitcast<u32>((ct - sk))))), opq(cfb)))));
        mem_st((cB + bitcast<u32>(ct)), bitcast<u32>(opq((opq(fma(opq((-(opq(cfa)))), bitcast<f32>(mem_ld((cB + bitcast<u32>((ct - sk))))), opq(cfd)))) * (opq(t)))));
    }
    {
        var k: i32 = (g.nz - 2i);
        loop {
            if (!((k >= 0i))) { break; }
                var c: i32 = (base + (k * sk));
                mem_st((cB + bitcast<u32>(c)), bitcast<u32>(opq(fma(bitcast<f32>(mem_ld((cA + bitcast<u32>(c)))), bitcast<f32>(mem_ld((cB + bitcast<u32>((c + sk))))), bitcast<f32>(mem_ld((cB + bitcast<u32>(c))))))));
            continuing {
                k = (k - 1i);
            }
        }
    }
    {
        var k: i32 = 0i;
        loop {
            if (!((k < g.nz))) { break; }
                var c: i32 = (base + (k * sk));
                var _t3: f32;
                if (zeroX) {
                    _t3 = 0.0f;
                } else {
                    _t3 = opq((opq((opq((bitcast<f32>(mem_ld((t11 + bitcast<u32>(c))))) - (bitcast<f32>(mem_ld((t11 + bitcast<u32>((c - 1i)))))))) * (opq(g.rdx)))) * (opq(f_hm_uf(g, hm, i))));
                }
                var turbx: f32 = _t3;
                var _t4: f32;
                if (zeroY) {
                    _t4 = 0.0f;
                } else {
                    _t4 = opq((opq((opq((bitcast<f32>(mem_ld((t12 + bitcast<u32>((c + sj)))))) - (bitcast<f32>(mem_ld((t12 + bitcast<u32>(c))))))) * (opq(g.rdy)))) * (opq(f_hm_vh(g, hm, j))));
                }
                var turby: f32 = _t4;
                var turbz: f32 = opq((opq((opq((bitcast<f32>(mem_ld((rho + bitcast<u32>((c - 1i)))))) + (bitcast<f32>(mem_ld((rho + bitcast<u32>(c))))))) * (opq((bitcast<f32>(mem_ld((cB + bitcast<u32>(c))))) - (bitcast<f32>(mem_ld((u + bitcast<u32>(c))))))))) * (opq(rdt)));
                turbz = opq(fma(opq((opq((opq((bitcast<f32>(mem_ld((dwdx + bitcast<u32>((c + sk)))))) - (bitcast<f32>(mem_ld((dwdx + bitcast<u32>(c))))))) * (opq(g.rdz)))) * (opq(0.5f))), (opq((bitcast<f32>(mem_ld((mh + bitcast<u32>(k))))) + (bitcast<f32>(mem_ld((mh + bitcast<u32>(k))))))), opq(turbz)));
                mem_st((uten + bitcast<u32>(c)), bitcast<u32>(opq(fma((opq((opq((opq(turbx)) + (opq(turby)))) + (opq(turbz)))), opq(lam_6(k, &base, &sk, rho)), bitcast<f32>(mem_ld((uten + bitcast<u32>(c))))))));
            continuing {
                k = (k + 1i);
            }
        }
    }
}
