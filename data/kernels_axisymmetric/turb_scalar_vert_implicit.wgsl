// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// turb_scalar_vert_implicit: сгенерировано, не править руками.

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

fn lam_1(kf_in: i32, base: ptr<function, i32>, sk: ptr<function, i32>, khv: u32, s: u32, g: ptr<function, S_GridDims>, mf: u32, rf: u32, wall: ptr<function, vec4<f32>>, useFlux: ptr<function, i32>, sflux: u32, bcturbs: ptr<function, i32>) -> f32 {
    var kf: i32 = kf_in;
    var c: i32 = ((*base) + (kf * (*sk)));
    if ((kf == 0i)) {
        if ((((*wall).w) == 0.0f)) {
            var _t2: f32;
            if (((*useFlux) != 0i)) {
                _t2 = opq((bitcast<f32>(mem_ld((sflux + bitcast<u32>((*base)))))) * (bitcast<f32>(mem_ld((rf + bitcast<u32>(c))))));
            } else {
                var _t1: f32;
                if (((*bcturbs) == 2i)) {
                    _t1 = lam_2(1i, base, sk, khv, s, g, mf, rf);
                } else {
                    _t1 = 0.0f;
                }
                _t2 = (_t1);
            }
            return _t2;
        }
        if ((((*wall).w) == 2.0f)) {
            return opq((opq((opq((*wall).x)) * (opq((*wall).y)))) * (bitcast<f32>(mem_ld((rf + bitcast<u32>(c))))));
        }
        return opq((opq((opq((opq((opq((opq((-(opq((*wall).x))))) * (opq(2.0f)))) * (opq((bitcast<f32>(mem_ld((s + bitcast<u32>(c))))) - (opq((*wall).y)))))) * (opq((*g).rdz)))) * (bitcast<f32>(mem_ld((mf + bitcast<u32>((0i)))))))) * (bitcast<f32>(mem_ld((rf + bitcast<u32>(c))))));
    }
    if ((kf == ((*g).nz))) {
        if ((((*wall).w) == 0.0f)) {
            var _t3: f32;
            if (((*bcturbs) == 2i)) {
                _t3 = lam_2((((*g).nz) - 1i), base, sk, khv, s, g, mf, rf);
            } else {
                _t3 = 0.0f;
            }
            return _t3;
        }
        var cb: i32 = ((*base) + ((((*g).nz) - 1i) * (*sk)));
        if ((((*wall).w) == 2.0f)) {
            return opq((opq((opq((*wall).x)) * (opq((*wall).z)))) * (bitcast<f32>(mem_ld((rf + bitcast<u32>(c))))));
        }
        return opq((opq((opq((opq((opq((opq((-(opq((*wall).x))))) * (opq(2.0f)))) * (opq((opq((*wall).z)) - (bitcast<f32>(mem_ld((s + bitcast<u32>(cb))))))))) * (opq((*g).rdz)))) * (bitcast<f32>(mem_ld((mf + bitcast<u32>((*g).nz))))))) * (bitcast<f32>(mem_ld((rf + bitcast<u32>(c))))));
    }
    return opq((opq((opq((opq((opq((-(bitcast<f32>(mem_ld((khv + bitcast<u32>(c)))))))) * (opq((bitcast<f32>(mem_ld((s + bitcast<u32>(c))))) - (bitcast<f32>(mem_ld((s + bitcast<u32>((c - (*sk))))))))))) * (opq((*g).rdz)))) * (bitcast<f32>(mem_ld((mf + bitcast<u32>(kf))))))) * (bitcast<f32>(mem_ld((rf + bitcast<u32>(c))))));
}

fn lam_2(kk_in: i32, base: ptr<function, i32>, sk: ptr<function, i32>, khv: u32, s: u32, g: ptr<function, S_GridDims>, mf: u32, rf: u32) -> f32 {
    var kk: i32 = kk_in;
    var cc: i32 = ((*base) + (kk * (*sk)));
    return opq((opq((opq((opq((opq((-(bitcast<f32>(mem_ld((khv + bitcast<u32>(cc)))))))) * (opq((bitcast<f32>(mem_ld((s + bitcast<u32>(cc))))) - (bitcast<f32>(mem_ld((s + bitcast<u32>((cc - (*sk))))))))))) * (opq((*g).rdz)))) * (bitcast<f32>(mem_ld((mf + bitcast<u32>(kk))))))) * (bitcast<f32>(mem_ld((rf + bitcast<u32>(cc))))));
}

fn f_hm_arh2(g_in: S_GridDims, hm_in: u32, i_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var hm: u32 = hm_in;
    var i: i32 = i_in;
    let _t1 = (((f_hm_axi_offset(g.strideJ, g.strideK)) + g.strideJ) + i);
    return bitcast<f32>(mem_ld((hm + bitcast<u32>(_t1))));
}

fn f_hm_axi_offset(sJ_in: i32, sK_in: i32) -> i32 {
    var sJ: i32 = sJ_in;
    var sK: i32 = sK_in;
    return (((3i * sJ) + (3i * sK)) + 3i);
}

fn f_hm_arh1(g_in: S_GridDims, hm_in: u32, i_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var hm: u32 = hm_in;
    var i: i32 = i_in;
    let _t1 = ((f_hm_axi_offset(g.strideJ, g.strideK)) + i);
    return bitcast<f32>(mem_ld((hm + bitcast<u32>(_t1))));
}

fn f_hm_uh(g_in: S_GridDims, hm_in: u32, i_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var hm: u32 = hm_in;
    var i: i32 = i_in;
    return bitcast<f32>(mem_ld((hm + bitcast<u32>((i + 3i)))));
}

fn lam_3(k_in: i32, base: ptr<function, i32>, sk: ptr<function, i32>, khv: u32, mf: u32, rf: u32, mh: u32, rr: u32) -> f32 {
    var k: i32 = k_in;
    var c: i32 = ((*base) + (k * (*sk)));
    return opq((opq((opq((opq((bitcast<f32>(mem_ld((khv + bitcast<u32>((c + (*sk))))))) * (bitcast<f32>(mem_ld((mf + bitcast<u32>((k + 1i)))))))) * (bitcast<f32>(mem_ld((rf + bitcast<u32>((c + (*sk))))))))) * (bitcast<f32>(mem_ld((mh + bitcast<u32>(k))))))) * (bitcast<f32>(mem_ld((rr + bitcast<u32>(c))))));
}

fn lam_4(k_in: i32, base: ptr<function, i32>, sk: ptr<function, i32>, khv: u32, mf: u32, rf: u32, mh: u32, rr: u32) -> f32 {
    var k: i32 = k_in;
    var c: i32 = ((*base) + (k * (*sk)));
    return opq((opq((opq((opq((bitcast<f32>(mem_ld((khv + bitcast<u32>(c))))) * (bitcast<f32>(mem_ld((mf + bitcast<u32>(k))))))) * (bitcast<f32>(mem_ld((rf + bitcast<u32>(c))))))) * (bitcast<f32>(mem_ld((mh + bitcast<u32>(k))))))) * (bitcast<f32>(mem_ld((rr + bitcast<u32>(c))))));
}

fn lam_5(c_in: i32, turbz_in: f32, g: ptr<function, S_GridDims>, hm: u32, i: ptr<function, i32>, fx: u32, fy: u32, sj: ptr<function, i32>, j: ptr<function, i32>, sten: u32, rr: u32) {
    var c: i32 = c_in;
    var turbz: f32 = turbz_in;
    var h: f32 = opq((opq((opq((-(opq((opq((opq(f_hm_arh2((*g), hm, (*i)))) * (bitcast<f32>(mem_ld((fx + bitcast<u32>((c + 1i)))))))) - (opq((opq(f_hm_arh1((*g), hm, (*i)))) * (bitcast<f32>(mem_ld((fx + bitcast<u32>(c)))))))))))) * (opq((*g).rdx)))) * (opq(f_hm_uh((*g), hm, (*i)))));
    mem_st((sten + bitcast<u32>(c)), bitcast<u32>(opq(fma(opq((opq(h)) + (opq(turbz))), bitcast<f32>(mem_ld((rr + bitcast<u32>(c)))), bitcast<f32>(mem_ld((sten + bitcast<u32>(c))))))));
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    var g: S_GridDims = ld_GridDims(ARG[4]);
    var s: u32 = ARG[5];
    var rho: u32 = ARG[6];
    var rr: u32 = ARG[7];
    var rf: u32 = ARG[8];
    var khv: u32 = ARG[9];
    var mh: u32 = ARG[10];
    var mf: u32 = ARG[11];
    var fx: u32 = ARG[12];
    var fy: u32 = ARG[13];
    var dt: f32 = bitcast<f32>(mem_ld(ARG[14]));
    var cA: u32 = ARG[15];
    var cB: u32 = ARG[16];
    var sten: u32 = ARG[17];
    var sflux: u32 = ARG[18];
    var useFlux: i32 = bitcast<i32>(mem_ld(ARG[19]));
    var explicitZ: i32 = bitcast<i32>(mem_ld(ARG[20]));
    var wall: vec4<f32> = vec4<f32>(bitcast<f32>(mem_ld((ARG[21] + 0u))), bitcast<f32>(mem_ld((ARG[21] + 1u))), bitcast<f32>(mem_ld((ARG[21] + 2u))), bitcast<f32>(mem_ld((ARG[21] + 3u))));
    var bcturbs: i32 = bitcast<i32>(mem_ld(ARG[22]));
    var hm: u32 = ARG[34];
    var tid: vec2<u32> = gid.xy;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    if (((i >= g.nx) || (j >= g.ny))) {
        return;
    }
    var sj: i32 = g.strideJ;
    var sk: i32 = (g.strideJ * g.strideK);
    var base: i32 = f_gidx(g, i, j, 0i);
    if ((explicitZ != 0i)) {
        var below: f32 = lam_1(0i, &base, &sk, khv, s, &g, mf, rf, &wall, &useFlux, sflux, &bcturbs);
        {
            var k: i32 = 0i;
            loop {
                if (!((k < g.nz))) { break; }
                    var c: i32 = (base + (k * sk));
                    var above: f32 = lam_1((k + 1i), &base, &sk, khv, s, &g, mf, rf, &wall, &useFlux, sflux, &bcturbs);
                    var turbz: f32 = opq((opq((opq((-(opq((opq(above)) - (opq(below))))))) * (opq(g.rdz)))) * (bitcast<f32>(mem_ld((mh + bitcast<u32>(k))))));
                    mem_st((sten + bitcast<u32>(c)), bitcast<u32>(opq(fma((opq(fma(opq((opq((-(opq(fma(opq(f_hm_arh2(g, hm, i)), bitcast<f32>(mem_ld((fx + bitcast<u32>((c + 1i))))), opq((-(opq((opq(f_hm_arh1(g, hm, i))) * (bitcast<f32>(mem_ld((fx + bitcast<u32>(c))))))))))))))) * (opq(g.rdx))), opq(f_hm_uh(g, hm, i)), opq(turbz)))), bitcast<f32>(mem_ld((rr + bitcast<u32>(c)))), bitcast<f32>(mem_ld((sten + bitcast<u32>(c))))))));
                    below = above;
                continuing {
                    k = (k + 1i);
                }
            }
        }
        return;
    }
    {
        var tema: f32 = opq((opq((opq((-(opq(dt))))) * (opq(g.rdz)))) * (opq(g.rdz)));
        var rdt: f32 = div_cr(1.0f, dt);
        var temc: f32 = opq((opq(dt)) * (opq(g.rdz)));
        {
            var cfc: f32 = opq((opq(tema)) * (opq(lam_3(0i, &base, &sk, khv, mf, rf, mh, rr))));
            var cfb: f32 = opq((opq(1.0f)) - (opq(cfc)));
            var t: f32 = div_cr(1.0f, cfb);
            mem_st((cA + bitcast<u32>(base)), bitcast<u32>(opq((opq((-(opq(cfc))))) * (opq(t)))));
            var cfd: f32 = bitcast<f32>(mem_ld((s + bitcast<u32>(base))));
            if (((useFlux != 0i) || (bcturbs == 2i))) {
                var dumz: f32;
                if ((useFlux != 0i)) {
                    dumz = opq((bitcast<f32>(mem_ld((sflux + bitcast<u32>(base))))) * (bitcast<f32>(mem_ld((rf + bitcast<u32>(base))))));
                } else {
                    var c1: i32 = (base + sk);
                    dumz = opq((opq((opq((opq((opq((-(bitcast<f32>(mem_ld((khv + bitcast<u32>(c1)))))))) * (opq((bitcast<f32>(mem_ld((s + bitcast<u32>(c1))))) - (bitcast<f32>(mem_ld((s + bitcast<u32>(base))))))))) * (opq(g.rdz)))) * (bitcast<f32>(mem_ld((mf + bitcast<u32>((1i)))))))) * (bitcast<f32>(mem_ld((rf + bitcast<u32>(c1))))));
                }
                cfd = opq(fma(opq((opq((opq(temc)) * (opq(dumz)))) * (bitcast<f32>(mem_ld((mh + bitcast<u32>((0i))))))), bitcast<f32>(mem_ld((rr + bitcast<u32>(base)))), bitcast<f32>(mem_ld((s + bitcast<u32>(base))))));
            }
            mem_st((cB + bitcast<u32>(base)), bitcast<u32>(opq((opq(cfd)) * (opq(t)))));
        }
        {
            var k: i32 = 1i;
            loop {
                if (!((k < (g.nz - 1i)))) { break; }
                    var c: i32 = (base + (k * sk));
                    var cfa: f32 = opq((opq(tema)) * (opq(lam_4(k, &base, &sk, khv, mf, rf, mh, rr))));
                    var cfc: f32 = opq((opq(tema)) * (opq(lam_3(k, &base, &sk, khv, mf, rf, mh, rr))));
                    var cfb: f32 = opq((opq((opq(1.0f)) - (opq(cfa)))) - (opq(cfc)));
                    var t: f32 = div_cr(1.0f, opq(fma(opq(cfa), bitcast<f32>(mem_ld((cA + bitcast<u32>((c - sk))))), opq(cfb))));
                    mem_st((cA + bitcast<u32>(c)), bitcast<u32>(opq((opq((-(opq(cfc))))) * (opq(t)))));
                    mem_st((cB + bitcast<u32>(c)), bitcast<u32>(opq((opq(fma(opq((-(opq(cfa)))), bitcast<f32>(mem_ld((cB + bitcast<u32>((c - sk))))), bitcast<f32>(mem_ld((s + bitcast<u32>(c))))))) * (opq(t)))));
                continuing {
                    k = (k + 1i);
                }
            }
        }
        var kt: i32 = (g.nz - 1i);
        var ct: i32 = (base + (kt * sk));
        {
            var cfa: f32 = opq((opq(tema)) * (opq(lam_4(kt, &base, &sk, khv, mf, rf, mh, rr))));
            var cfb: f32 = opq((opq(1.0f)) - (opq(cfa)));
            var t: f32 = div_cr(1.0f, opq(fma(opq(cfa), bitcast<f32>(mem_ld((cA + bitcast<u32>((ct - sk))))), opq(cfb))));
            var cfd: f32 = bitcast<f32>(mem_ld((s + bitcast<u32>(ct))));
            if ((bcturbs == 2i)) {
                var dumz: f32 = opq((opq((opq((opq((opq((-(bitcast<f32>(mem_ld((khv + bitcast<u32>(ct)))))))) * (opq((bitcast<f32>(mem_ld((s + bitcast<u32>(ct))))) - (bitcast<f32>(mem_ld((s + bitcast<u32>((ct - sk)))))))))) * (opq(g.rdz)))) * (bitcast<f32>(mem_ld((mf + bitcast<u32>(kt))))))) * (bitcast<f32>(mem_ld((rf + bitcast<u32>(ct))))));
                cfd = opq(fma(opq((-(opq((opq((opq(temc)) * (opq(dumz)))) * (bitcast<f32>(mem_ld((mh + bitcast<u32>(kt))))))))), bitcast<f32>(mem_ld((rr + bitcast<u32>(ct)))), bitcast<f32>(mem_ld((s + bitcast<u32>(ct))))));
            }
            var snew: f32 = opq((opq(fma(opq((-(opq(cfa)))), bitcast<f32>(mem_ld((cB + bitcast<u32>((ct - sk))))), opq(cfd)))) * (opq(t)));
            mem_st((cB + bitcast<u32>(ct)), bitcast<u32>(snew));
            lam_5(ct, opq((opq((bitcast<f32>(mem_ld((rho + bitcast<u32>(ct))))) * (opq((opq(snew)) - (bitcast<f32>(mem_ld((s + bitcast<u32>(ct))))))))) * (opq(rdt))), &g, hm, &i, fx, fy, &sj, &j, sten, rr);
        }
        {
            var k: i32 = (g.nz - 2i);
            loop {
                if (!((k >= 0i))) { break; }
                    var c: i32 = (base + (k * sk));
                    var snew: f32 = opq(fma(bitcast<f32>(mem_ld((cA + bitcast<u32>(c)))), bitcast<f32>(mem_ld((cB + bitcast<u32>((c + sk))))), bitcast<f32>(mem_ld((cB + bitcast<u32>(c))))));
                    mem_st((cB + bitcast<u32>(c)), bitcast<u32>(snew));
                    lam_5(c, opq((opq((bitcast<f32>(mem_ld((rho + bitcast<u32>(c))))) * (opq((opq(snew)) - (bitcast<f32>(mem_ld((s + bitcast<u32>(c))))))))) * (opq(rdt))), &g, hm, &i, fx, fy, &sj, &j, sten, rr);
                continuing {
                    k = (k - 1i);
                }
            }
        }
    }
}
