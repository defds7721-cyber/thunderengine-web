// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// pdef_apply: сгенерировано, не править руками.

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

struct S_PdefCell {
    neg: bool,
    f1: f32,
    f2: f32,
    foo3: f32,
}

const K_PDEF_SMEPS: f32 = 1e-30f;

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

fn f_pdef_mass(dm2_in: f32, dm1_in: f32, d0_in: f32, dp1_in: f32, dp2_in: f32, flag: ptr<function, bool>) -> f32 {
    var dm2: f32 = dm2_in;
    var dm1: f32 = dm1_in;
    var d0: f32 = d0_in;
    var dp1: f32 = dp1_in;
    var dp2: f32 = dp2_in;
    var l: S_PdefCell = f_pdef_cell(dm1, dm2, d0);
    var c: S_PdefCell = f_pdef_cell(d0, dm1, dp1);
    var r: S_PdefCell = f_pdef_cell(dp1, d0, dp2);
    var mass: f32 = 0.0f;
    if (l.neg) {
        mass = opq(fma(opq(l.f2), opq(l.foo3), opq(mass)));
    }
    if (c.neg) {
        mass = opq(fma(opq((-(opq((opq(c.f1)) + (opq(c.f2)))))), opq(c.foo3), opq(mass)));
    }
    if (r.neg) {
        mass = opq(fma(opq(r.f1), opq(r.foo3), opq(mass)));
    }
    (*flag) = ((c.neg || (l.neg && (d0 > K_PDEF_SMEPS))) || (r.neg && (d0 > K_PDEF_SMEPS)));
    return mass;
}

fn f_pdef_cell(d_in: f32, dm_in: f32, dp_in: f32) -> S_PdefCell {
    var d: f32 = d_in;
    var dm: f32 = dm_in;
    var dp: f32 = dp_in;
    var r: S_PdefCell = S_PdefCell();
    r.neg = false;
    r.f1 = 0.0f;
    r.f2 = 0.0f;
    r.foo3 = 0.0f;
    if ((d < 0.0f)) {
        var f1: f32 = opq(max(0.0f, dm));
        var f2: f32 = opq(max(0.0f, dp));
        if (((opq((opq(f1)) + (opq(f2)))) > K_PDEF_SMEPS)) {
            r.neg = true;
            r.f1 = f1;
            r.f2 = f2;
            r.foo3 = div_cr(opq(max(d, opq((-(opq((opq(f1)) + (opq(f2)))))))), (opq((opq(f1)) + (opq(f2)))));
        }
    }
    return r;
}

fn f_hm_uh(g_in: S_GridDims, hm_in: u32, i_in: i32) -> f32 {
    var g: S_GridDims = g_in;
    var hm: u32 = hm_in;
    var i: i32 = i_in;
    return bitcast<f32>(mem_ld((hm + bitcast<u32>((i + 3i)))));
}

fn f_pdef_inflow(g_in: S_GridDims, dir_in: i32, i_in: i32, j_in: i32, c_in: i32, step_v_in: i32, rr_in: u32, open_in: vec2<i32>) -> bool {
    var g: S_GridDims = g_in;
    var dir: i32 = dir_in;
    var i: i32 = i_in;
    var j: i32 = j_in;
    var c: i32 = c_in;
    var step_v: i32 = step_v_in;
    var rr: u32 = rr_in;
    var open: vec2<i32> = open_in;
    if (((dir == 0i) && (open.x != 0i))) {
        if (((i == 0i) && ((bitcast<f32>(mem_ld((rr + bitcast<u32>(c))))) >= 0.0f))) {
            return true;
        }
        if (((i == (g.nx - 1i)) && ((bitcast<f32>(mem_ld((rr + bitcast<u32>((c + step_v)))))) <= 0.0f))) {
            return true;
        }
    }
    if (((dir == 1i) && (open.y != 0i))) {
        if (((j == 0i) && ((bitcast<f32>(mem_ld((rr + bitcast<u32>(c))))) >= 0.0f))) {
            return true;
        }
        if (((j == (g.ny - 1i)) && ((bitcast<f32>(mem_ld((rr + bitcast<u32>((c + step_v)))))) <= 0.0f))) {
            return true;
        }
    }
    return false;
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
    var s: u32 = ARG[5];
    var s0: u32 = ARG[6];
    var fx: u32 = ARG[7];
    var fy: u32 = ARG[8];
    var fz: u32 = ARG[9];
    var rru: u32 = ARG[10];
    var rrv: u32 = ARG[11];
    var rrw: u32 = ARG[12];
    var dumx: u32 = ARG[13];
    var dumy: u32 = ARG[14];
    var dumz: u32 = ARG[15];
    var rho0: u32 = ARG[16];
    var mh: u32 = ARG[17];
    var dt: f32 = bitcast<f32>(mem_ld(ARG[18]));
    var open: vec2<i32> = vec2<i32>(bitcast<i32>(mem_ld((ARG[19] + 0u))), bitcast<i32>(mem_ld((ARG[19] + 1u))));
    var tend: u32 = ARG[20];
    var hm: u32 = ARG[34];
    var tid: vec3<u32> = gid;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    var k: i32 = i32(tid.z);
    if ((((i >= g.nx) || (j >= g.ny)) || (k >= g.nz))) {
        return;
    }
    var c: i32 = f_gidx(g, i, j, k);
    var sj: i32 = g.strideJ;
    var sk: i32 = (g.strideJ * g.strideK);
    var rdt: f32 = div_cr(1.0f, dt);
    var base: f32 = opq((bitcast<f32>(mem_ld((rho0 + bitcast<u32>(k))))) * (bitcast<f32>(mem_ld((s0 + bitcast<u32>(c))))));
    var delta: f32 = 0.0f;
    var flag: bool;
    {
        var mx: f32 = f_pdef_mass(bitcast<f32>(mem_ld((dumx + bitcast<u32>((c - 2i))))), bitcast<f32>(mem_ld((dumx + bitcast<u32>((c - 1i))))), bitcast<f32>(mem_ld((dumx + bitcast<u32>(c)))), bitcast<f32>(mem_ld((dumx + bitcast<u32>((c + 1i))))), bitcast<f32>(mem_ld((dumx + bitcast<u32>((c + 2i))))), &flag);
        if (flag) {
            var sdiv: f32 = opq((opq((opq((bitcast<f32>(mem_ld((s + bitcast<u32>(c))))) * (opq((bitcast<f32>(mem_ld((rru + bitcast<u32>((c + 1i)))))) - (bitcast<f32>(mem_ld((rru + bitcast<u32>(c))))))))) * (opq(g.rdx)))) * (opq(f_hm_uh(g, hm, i))));
            var _t1: f32;
            if (f_pdef_inflow(g, 0i, i, j, c, 1i, rru, open)) {
                _t1 = opq((-(opq(sdiv))));
            } else {
                _t1 = opq((opq((opq((-(opq((bitcast<f32>(mem_ld((fx + bitcast<u32>((c + 1i)))))) - (bitcast<f32>(mem_ld((fx + bitcast<u32>(c)))))))))) * (opq(g.rdx)))) * (opq(f_hm_uh(g, hm, i))));
            }
            var advOld: f32 = _t1;
            var advNew: f32 = opq(fma((opq((opq((bitcast<f32>(mem_ld((dumx + bitcast<u32>(c))))) + (opq(mx)))) - (opq(base)))), opq(rdt), opq((-(opq(sdiv))))));
            delta = opq((opq(delta)) + (opq((opq(advNew)) - (opq(advOld)))));
        }
    }
    var my: f32 = f_pdef_mass(bitcast<f32>(mem_ld((dumy + bitcast<u32>((c - (2i * sj)))))), bitcast<f32>(mem_ld((dumy + bitcast<u32>((c - sj))))), bitcast<f32>(mem_ld((dumy + bitcast<u32>(c)))), bitcast<f32>(mem_ld((dumy + bitcast<u32>((c + sj))))), bitcast<f32>(mem_ld((dumy + bitcast<u32>((c + (2i * sj)))))), &flag);
    if (flag) {
        var sdiv: f32 = opq((opq((opq((bitcast<f32>(mem_ld((s + bitcast<u32>(c))))) * (opq((bitcast<f32>(mem_ld((rrv + bitcast<u32>((c + sj)))))) - (bitcast<f32>(mem_ld((rrv + bitcast<u32>(c))))))))) * (opq(g.rdy)))) * (opq(f_hm_vh(g, hm, j))));
        var _t2: f32;
        if (f_pdef_inflow(g, 1i, i, j, c, sj, rrv, open)) {
            _t2 = opq((-(opq(sdiv))));
        } else {
            _t2 = opq((opq((opq((-(opq((bitcast<f32>(mem_ld((fy + bitcast<u32>((c + sj)))))) - (bitcast<f32>(mem_ld((fy + bitcast<u32>(c)))))))))) * (opq(g.rdy)))) * (opq(f_hm_vh(g, hm, j))));
        }
        var advOld: f32 = _t2;
        var advNew: f32 = opq(fma((opq((opq((bitcast<f32>(mem_ld((dumy + bitcast<u32>(c))))) + (opq(my)))) - (opq(base)))), opq(rdt), opq((-(opq(sdiv))))));
        delta = opq((opq(delta)) + (opq((opq(advNew)) - (opq(advOld)))));
    }
    var zm2: f32 = select(0.0f, bitcast<f32>(mem_ld((dumz + bitcast<u32>((c - (2i * sk)))))), (k >= 2i));
    var zm1: f32 = select(0.0f, bitcast<f32>(mem_ld((dumz + bitcast<u32>((c - sk))))), (k >= 1i));
    var zp1: f32 = select(0.0f, bitcast<f32>(mem_ld((dumz + bitcast<u32>((c + sk))))), ((k + 1i) < g.nz));
    var zp2: f32 = select(0.0f, bitcast<f32>(mem_ld((dumz + bitcast<u32>((c + (2i * sk)))))), ((k + 2i) < g.nz));
    var mz: f32 = f_pdef_mass(zm2, zm1, bitcast<f32>(mem_ld((dumz + bitcast<u32>(c)))), zp1, zp2, &flag);
    if (flag) {
        var sdiv: f32 = opq((opq((opq((bitcast<f32>(mem_ld((s + bitcast<u32>(c))))) * (opq((bitcast<f32>(mem_ld((rrw + bitcast<u32>((c + sk)))))) - (bitcast<f32>(mem_ld((rrw + bitcast<u32>(c))))))))) * (opq(g.rdz)))) * (bitcast<f32>(mem_ld((mh + bitcast<u32>(k))))));
        var advOld: f32 = opq((opq((opq((-(opq((bitcast<f32>(mem_ld((fz + bitcast<u32>((c + sk)))))) - (bitcast<f32>(mem_ld((fz + bitcast<u32>(c)))))))))) * (opq(g.rdz)))) * (bitcast<f32>(mem_ld((mh + bitcast<u32>(k))))));
        var advNew: f32 = opq(fma((opq((opq((bitcast<f32>(mem_ld((dumz + bitcast<u32>(c))))) + (opq(mz)))) - (opq(base)))), opq(rdt), opq((-(opq(sdiv))))));
        delta = opq((opq(delta)) + (opq((opq(advNew)) - (opq(advOld)))));
    }
    mem_st((tend + bitcast<u32>(c)), bitcast<u32>(opq((bitcast<f32>(mem_ld((tend + bitcast<u32>(c))))) + (opq(div_cr(delta, bitcast<f32>(mem_ld((rho0 + bitcast<u32>(k))))))))));
}
