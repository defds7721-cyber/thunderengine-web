// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// sfc_most_avg: сгенерировано, не править руками.

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

struct S_MostParams {
    za: f32,
    th0first: f32,
    rtime: f32,
    testcase: i32,
    useAvg: i32,
    cnstQstar: f32,
}

struct S_MostPoint {
    ust: f32,
    tst: f32,
    tsk: f32,
    psim: f32,
    psih: f32,
    lnzadz0: f32,
    rmol: f32,
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

fn ld_MostParams(o: u32) -> S_MostParams {
    var s: S_MostParams;
    s.za = bitcast<f32>(mem_ld((o + 0u)));
    s.th0first = bitcast<f32>(mem_ld((o + 1u)));
    s.rtime = bitcast<f32>(mem_ld((o + 2u)));
    s.testcase = bitcast<i32>(mem_ld((o + 3u)));
    s.useAvg = bitcast<i32>(mem_ld((o + 4u)));
    s.cnstQstar = bitcast<f32>(mem_ld((o + 5u)));
    return s;
}

fn f_gidx(g_in: S_GridDims, i_in: i32, j_in: i32, k_in: i32) -> i32 {
    var g: S_GridDims = g_in;
    var i: i32 = i_in;
    var j: i32 = j_in;
    var k: i32 = k_in;
    return ((i + 3i) + (g.strideJ * ((j + 3i) + (g.strideK * k))));
}

fn f_most_iterate(s1_in: f32, t1_in: f32, tskIn_in: f32, znt_in: f32, p_in: S_MostParams) -> S_MostPoint {
    var s1: f32 = s1_in;
    var t1: f32 = t1_in;
    var tskIn: f32 = tskIn_in;
    var znt: f32 = znt_in;
    var p: S_MostParams = p_in;
    var karman: f32 = K_SFC_KARMAN;
    var gAcc: f32 = 9.81f;
    var kgt: f32 = div_cr(opq((opq(karman)) * (opq(gAcc))), p.th0first);
    var gt: f32 = div_cr(gAcc, p.th0first);
    var lnzadz0: f32 = opq(log(opq((opq(p.za)) * (opq((div_cr(1.0f, znt)))))));
    var ust: f32 = 0.0f;
    var ustlast: f32 = opq((-(opq(1e+03f))));
    var zeta: f32 = 0.0f;
    var zetalast: f32 = opq((-(opq(1e+03f))));
    var qstar: f32 = 0.0f;
    var tst: f32 = 0.0f;
    var tsk: f32 = tskIn;
    var rmol: f32 = 0.0f;
    var phim: f32;
    var phih: f32;
    var psim: f32 = 0.0f;
    var psih: f32 = 0.0f;
    var n: i32 = 0i;
    loop {
        if (!(((((abs(opq((opq(ust)) - (opq(ustlast))))) > 0.0001f) || (n < 6i)) && (n <= 100i)))) { break; }
            n = (n + 1i);
            ustlast = ust;
            zetalast = zeta;
            f_most_stabil(zeta, &phim, &phih, &psim, &psih);
            var vconv: f32 = opq((opq(0.07f)) * (opq(pow(abs(opq((opq((opq((opq(gt)) * (opq(qstar)))) * (opq(2.0f)))) * (opq(p.za)))), 0.33333334f))));
            var wspd: f32 = opq((opq(s1)) + (opq(vconv)));
            ust = opq(max(div_cr(opq((opq(wspd)) * (opq(karman))), (opq((opq(lnzadz0)) - (opq(psim))))), 1e-08f));
            if ((p.testcase == 1i)) {
                qstar = p.cnstQstar;
                tst = div_cr(opq((-(opq(qstar)))), ust);
                tsk = opq(fma(opq((-(opq((opq(tst)) * (opq((div_cr(1.0f, karman)))))))), (opq((opq(lnzadz0)) - (opq(psih)))), opq(t1)));
            } else {
                tst = opq(max(div_cr(opq((opq((opq(t1)) - (opq(tsk)))) * (opq(karman))), (opq((opq(lnzadz0)) - (opq(psih))))), 1e-30f));
                qstar = opq((opq((-(opq(ust))))) * (opq(tst)));
            }
            rmol = div_cr((opq((opq(kgt)) * (opq(tst)))), (opq((opq(ust)) * (opq(ust)))));
            var zol: f32 = opq((opq(p.za)) * (opq(rmol)));
            zeta = opq(fma(opq(0.5f), (opq((opq(zol)) - (opq(zetalast)))), opq(zetalast)));
    }
    var r: S_MostPoint = S_MostPoint();
    r.ust = ust;
    r.tst = tst;
    r.tsk = tsk;
    r.psim = psim;
    r.psih = psih;
    r.lnzadz0 = lnzadz0;
    r.rmol = rmol;
    return r;
}

fn f_most_stabil(zeta_in: f32, phim: ptr<function, f32>, phih: ptr<function, f32>, psim: ptr<function, f32>, psih: ptr<function, f32>) {
    var zeta: f32 = zeta_in;
    if ((zeta < (opq((-(opq(1e-06f))))))) {
        var x: f32 = sqrt_cr(sqrt_cr(opq(fma(opq((-(opq(19.3f)))), opq(zeta), opq(1.0f)))));
        (*phim) = div_cr(1.0f, x);
        (*psim) = opq((opq(fma(opq((-(opq(2.0f)))), opq(atan(x)), opq(fma(opq(2.0f), opq(log(opq((opq(0.5f)) * (opq((opq(1.0f)) + (opq(x))))))), opq(log(opq((opq(0.5f)) * (opq(fma(opq(x), opq(x), opq(1.0f)))))))))))) + (opq(1.5707964f)));
        var y: f32 = sqrt_cr(opq(fma(opq((-(opq(12.0f)))), opq(zeta), opq(1.0f))));
        (*phih) = div_cr(1.0f, y);
        (*psih) = opq((opq(2.0f)) * (opq(log(opq((opq(0.5f)) * (opq((opq(1.0f)) + (opq(y)))))))));
    } else {
        if ((zeta > (1e-06f))) {
            (*phim) = opq(fma(opq(4.8f), opq(zeta), opq(1.0f)));
            (*phih) = opq(fma(opq(7.8f), opq(zeta), opq(1.0f)));
            (*psim) = opq((opq((-(opq(4.8f))))) * (opq(zeta)));
            (*psih) = opq((opq((-(opq(7.8f))))) * (opq(zeta)));
        } else {
            (*phim) = 1.0f;
            (*phih) = 1.0f;
            (*psim) = 0.0f;
            (*psih) = 0.0f;
        }
    }
}

fn f_most_diag(r_in: S_MostPoint, znt_in: f32, s1_in: f32, s10: ptr<function, f32>, cd: ptr<function, f32>, ch: ptr<function, f32>) {
    var r: S_MostPoint = r_in;
    var znt: f32 = znt_in;
    var s1: f32 = s1_in;
    var phim10: f32;
    var phih10: f32;
    var psim10: f32;
    var psih10: f32;
    f_most_stabil(opq((opq(1e+01f)) * (opq(r.rmol))), &phim10, &phih10, &psim10, &psih10);
    var ln10dz0: f32 = opq(log(opq((opq(1e+01f)) * (opq((div_cr(1.0f, znt)))))));
    var var_v: f32 = div_cr((opq((opq(ln10dz0)) - (opq(psim10)))), (opq((opq(r.lnzadz0)) - (opq(r.psim)))));
    (*s10) = opq((opq(s1)) * (opq(var_v)));
    var varm: f32 = opq((opq(ln10dz0)) - (opq(psim10)));
    var varh: f32 = opq((opq(ln10dz0)) - (opq(psih10)));
    (*cd) = opq((opq((div_cr(K_SFC_KARMAN, varm)))) * (opq((div_cr(K_SFC_KARMAN, varm)))));
    (*ch) = div_cr(opq((opq(K_SFC_KARMAN)) * (opq(K_SFC_KARMAN))), (opq((opq(varm)) * (opq(varh)))));
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    var g: S_GridDims = ld_GridDims(ARG[4]);
    var p: S_MostParams = ld_MostParams(ARG[5]);
    var th: u32 = ARG[6];
    var partial: u32 = ARG[7];
    var sfc: u32 = ARG[8];
    var tid: vec2<u32> = gid.xy;
    var i: i32 = i32(tid.x);
    var j: i32 = i32(tid.y);
    if (((i >= g.nx) || (j >= g.ny))) {
        return;
    }
    var su: f32 = 0.0f;
    var sv: f32 = 0.0f;
    var ss: f32 = 0.0f;
    var st: f32 = 0.0f;
    {
        var jj: i32 = 0i;
        loop {
            if (!((jj < g.ny))) { break; }
                su = opq((opq(su)) + (bitcast<f32>(mem_ld((partial + bitcast<u32>((4i * jj)))))));
                sv = opq((opq(sv)) + (bitcast<f32>(mem_ld((partial + bitcast<u32>(((4i * jj) + 1i)))))));
                ss = opq((opq(ss)) + (bitcast<f32>(mem_ld((partial + bitcast<u32>(((4i * jj) + 2i)))))));
                st = opq((opq(st)) + (bitcast<f32>(mem_ld((partial + bitcast<u32>(((4i * jj) + 3i)))))));
            continuing {
                jj = (jj + 1i);
            }
        }
    }
    var inv: f32 = div_cr(1.0f, f32((g.nx * g.ny)));
    var avgu: f32 = opq((opq(su)) * (opq(inv)));
    var avgv: f32 = opq((opq(sv)) * (opq(inv)));
    var avgs: f32 = opq((opq(ss)) * (opq(inv)));
    var avgt: f32 = opq((opq(st)) * (opq(inv)));
    var plane: i32 = (g.strideJ * g.strideK);
    var o: i32 = f_gidx(g, i, j, 0i);
    var o0: i32 = f_gidx(g, 0i, 0i, 0i);
    var znt: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>(((4i * plane) + o0)))));
    var tsk0: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>(((13i * plane) + o0)))));
    if ((p.testcase == 9i)) {
        tsk0 = opq(fma(opq((-(opq(0.25f)))), opq((div_cr(p.rtime, 3.6e+03f))), opq(265.0f)));
    }
    var r: S_MostPoint = f_most_iterate(avgs, avgt, tsk0, znt, p);
    var s10: f32;
    var cd: f32;
    var ch: f32;
    f_most_diag(r, znt, avgs, &s10, &cd, &ch);
    var thflux0: f32 = opq((opq((-(opq(r.ust))))) * (opq(r.tst)));
    var dt: f32 = opq((opq(avgt)) - (opq(r.tsk)));
    var thflux: f32 = thflux0;
    var tem: f32 = opq((opq(avgs)) * (opq(dt)));
    if (((abs(tem)) > (1e-10f))) {
        tem = div_cr(thflux0, tem);
        var s1: f32 = bitcast<f32>(mem_ld((sfc + bitcast<u32>(((2i * plane) + o)))));
        var t1: f32 = opq((opq(p.th0first)) + (bitcast<f32>(mem_ld((th + bitcast<u32>(o))))));
        thflux = opq((opq(tem)) * (opq(fma(opq(s1), opq(dt), opq((opq(avgs)) * (opq((opq(t1)) - (opq(avgt)))))))));
    }
    mem_st((sfc + bitcast<u32>(((3i * plane) + o))), bitcast<u32>(r.ust));
    mem_st((sfc + bitcast<u32>(((5i * plane) + o))), bitcast<u32>(cd));
    mem_st((sfc + bitcast<u32>(((6i * plane) + o))), bitcast<u32>(ch));
    mem_st((sfc + bitcast<u32>(((8i * plane) + o))), bitcast<u32>(s10));
    mem_st((sfc + bitcast<u32>(((9i * plane) + o))), bitcast<u32>(thflux));
    mem_st((sfc + bitcast<u32>(((13i * plane) + o))), bitcast<u32>(r.tsk));
    mem_st((sfc + bitcast<u32>(((14i * plane) + o))), bitcast<u32>(avgu));
    mem_st((sfc + bitcast<u32>(((15i * plane) + o))), bitcast<u32>(avgv));
    mem_st((sfc + bitcast<u32>(((16i * plane) + o))), bitcast<u32>(avgs));
}
