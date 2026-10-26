// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// rrsw_columns: сгенерировано, не править руками.

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


struct S_RRSWParams {
    nk: i32,
    ncol: i32,
    colOffset: i32,
    co2: f32,
    scon: f32,
    heatfac: f32,
    debugCol: i32,
    zero: u32,
}

struct S_RRSWColumn {
    nlayers: i32,
    laytrop: i32,
    layswtch: i32,
    laylow: i32,
    fail: i32,
    z0: u32,
    tbound: f32,
    cossza: f32,
    pavel: u32,
    tavel: u32,
    pz: u32,
    tz: u32,
    coldry: u32,
    wkl: u32,
    colh2o: u32,
    colco2: u32,
    colo3: u32,
    coln2o: u32,
    colch4: u32,
    colo2: u32,
    colmol: u32,
    co2mult: u32,
    fac00: u32,
    fac01: u32,
    fac10: u32,
    fac11: u32,
    selffac: u32,
    selffrac: u32,
    forfac: u32,
    forfrac: u32,
    jp: u32,
    jt: u32,
    jt1: u32,
    indself: u32,
    indfor: u32,
    cldfmc: u32,
    ciwpmc: u32,
    clwpmc: u32,
    cswpmc: u32,
    taucmc: u32,
    ssacmc: u32,
    asmcmc: u32,
    fsfcmc: u32,
    taormc: u32,
    reicmc: u32,
    relqmc: u32,
    resnmc: u32,
    taug: u32,
    taur: u32,
    sfluxzen: u32,
    albdif: u32,
    albdir: u32,
    adjflux: u32,
    pbbfd: u32,
    pbbfu: u32,
    pbbcd: u32,
    pbbcu: u32,
    pbbfddir: u32,
    pbbcddir: u32,
    puvfd: u32,
    puvcd: u32,
    puvfddir: u32,
    puvcddir: u32,
    pnifd: u32,
    pnicd: u32,
    pnifddir: u32,
    pnicddir: u32,
}

const K_RS_AMDW: f32 = 1.607793f;

const K_RS_AMDO: f32 = 0.603461f;

const K_RS_SCON: f32 = 1368.22f;

const K_RS_N2O: f32 = 3.19e-07f;

const K_RS_CH4: f32 = 1.774e-06f;

const K_RS_O2: f32 = 0.209488f;

const K_RS_AMD: f32 = 28.966f;

const K_RS_AMW: f32 = 18.016f;

const K_RS_AVOGAD: f32 = 6.022142e+23f;

const K_RS_GRAV: f32 = 9.8066f;

const K_RRSW_NGB: array<i32, 112> = array<i32, 112>(16i, 16i, 16i, 16i, 16i, 16i, 17i, 17i, 17i, 17i, 17i, 17i, 17i, 17i, 17i, 17i, 17i, 17i, 18i, 18i, 18i, 18i, 18i, 18i, 18i, 18i, 19i, 19i, 19i, 19i, 19i, 19i, 19i, 19i, 20i, 20i, 20i, 20i, 20i, 20i, 20i, 20i, 20i, 20i, 21i, 21i, 21i, 21i, 21i, 21i, 21i, 21i, 21i, 21i, 22i, 22i, 23i, 23i, 23i, 23i, 23i, 23i, 23i, 23i, 23i, 23i, 24i, 24i, 24i, 24i, 24i, 24i, 24i, 24i, 25i, 25i, 25i, 25i, 25i, 25i, 26i, 26i, 26i, 26i, 26i, 26i, 27i, 27i, 27i, 27i, 27i, 27i, 27i, 27i, 28i, 28i, 28i, 28i, 28i, 28i, 29i, 29i, 29i, 29i, 29i, 29i, 29i, 29i, 29i, 29i, 29i, 29i);

const K_RR_ONEMINUS: f32 = 0.999999f;

const K_RRSW_NSPA: array<i32, 14> = array<i32, 14>(9i, 9i, 9i, 9i, 1i, 9i, 9i, 1i, 9i, 1i, 0i, 1i, 9i, 1i);

const K_RRSW_NSPB: array<i32, 14> = array<i32, 14>(1i, 5i, 1i, 1i, 1i, 5i, 1i, 0i, 1i, 0i, 0i, 1i, 5i, 1i);

const K_RRSW_NGC: array<i32, 14> = array<i32, 14>(6i, 12i, 8i, 8i, 10i, 10i, 2i, 10i, 8i, 6i, 6i, 8i, 6i, 12i);

fn ld_RRSWParams(o: u32) -> S_RRSWParams {
    var s: S_RRSWParams;
    s.nk = bitcast<i32>(mem_ld((o + 0u)));
    s.ncol = bitcast<i32>(mem_ld((o + 1u)));
    s.colOffset = bitcast<i32>(mem_ld((o + 2u)));
    s.co2 = bitcast<f32>(mem_ld((o + 3u)));
    s.scon = bitcast<f32>(mem_ld((o + 4u)));
    s.heatfac = bitcast<f32>(mem_ld((o + 5u)));
    s.debugCol = bitcast<i32>(mem_ld((o + 6u)));
    s.zero = mem_ld((o + 7u));
    return s;
}

fn f_rrsw_ws_floats(nl_in: i32) -> i32 {
    var nl: i32 = nl_in;
    return (((((((((((((((22i * nl) + (2i * (nl + 1i))) + (7i * nl)) + ((9i * 112i) * nl)) + ((2i * 112i) * nl)) + 112i) + 14i) + 14i) + 29i) + (14i * (nl + 1i))) + (20i * nl)) + (2i * (nl + 1i))) + (13i * 112i)) + (45i * (nl + 1i))) + 112i);
}

fn f_rrsw_ws_ints(nl_in: i32) -> i32 {
    var nl: i32 = nl_in;
    return (((5i * nl) + (2i * nl)) + (f_rrsw_cloud_words(nl)));
}

fn f_rrsw_cloud_words(nl_in: i32) -> i32 {
    var nl: i32 = nl_in;
    return (((112i * nl) + 31i) / 32i);
}

fn lam_1(n_in: i32, S: u32, o: ptr<function, i32>) -> u32 {
    var n: i32 = n_in;
    var p: u32 = (S + bitcast<u32>((*o)));
    (*o) = ((*o) + n);
    return p;
}

fn lam_2(n_in: i32, IS: u32, oi: ptr<function, i32>) -> u32 {
    var n: i32 = n_in;
    var p: u32 = (IS + bitcast<u32>((*oi)));
    (*oi) = ((*oi) + n);
    return p;
}

fn lam_3(sd: ptr<function, array<u32, 4>>) -> f32 {
    (*sd)[0i] = ((69069u * ((*sd)[0i])) + 1327217885u);
    var x: u32 = (*sd)[1i];
    x = (x ^ (x << u32(13i)));
    x = (x ^ (x >> u32(17i)));
    x = (x ^ (x << u32(5i)));
    (*sd)[1i] = x;
    (*sd)[2i] = ((18000u * (((*sd)[2i]) & 65535u)) + (((*sd)[2i]) >> u32(16i)));
    (*sd)[3i] = ((30903u * (((*sd)[3i]) & 65535u)) + (((*sd)[3i]) >> u32(16i)));
    var k: i32 = i32((((((*sd)[0i]) + ((*sd)[1i])) + (((*sd)[2i]) << u32(16i))) + ((*sd)[3i])));
    return opq(fma(opq(f32(k)), opq(2.328306e-10f), opq(0.5f)));
}

fn f_rrsw_cldprmc_sw(C: ptr<function, S_RRSWColumn>, T_in: u32, W_in: u32, WI_in: u32) {
    var T: u32 = T_in;
    var W: u32 = W_in;
    var WI: u32 = WI_in;
    var cwp: f32 = f32(0i);
    var factor: f32 = f32(0i);
    var ffp: f32 = f32(0i);
    var ffp1: f32 = f32(0i);
    var ffpssa: f32 = f32(0i);
    var fint: f32 = f32(0i);
    var ib: i32 = 0i;
    var icx: i32 = 0i;
    var ig: i32 = 0i;
    var index: i32 = 0i;
    var lay: i32 = 0i;
    var radice: f32 = f32(0i);
    var radliq: f32 = f32(0i);
    var radsno: f32 = f32(0i);
    var scatice: f32 = f32(0i);
    var scatliq: f32 = f32(0i);
    var scatsno: f32 = f32(0i);
    var ssacloud_a: f32 = f32(0i);
    var ssaice: f32 = f32(0i);
    var ssaliq: f32 = f32(0i);
    var ssasno: f32 = f32(0i);
    var taucldorig_a: f32 = f32(0i);
    var taucloud_a: f32 = f32(0i);
    var tauice: f32 = f32(0i);
    var tauiceorig: f32 = f32(0i);
    var tauliq: f32 = f32(0i);
    var tauliqorig: f32 = f32(0i);
    var tausno: f32 = f32(0i);
    var tausnoorig: f32 = f32(0i);
    var fdelta: u32 = (W + bitcast<u32>((0i)));
    var extcoice: u32 = (W + bitcast<u32>(((112i - 1i) + 1i)));
    var gice: u32 = (W + bitcast<u32>((((112i - 1i) + 1i) + ((112i - 1i) + 1i))));
    var ssacoice: u32 = (W + bitcast<u32>(((((112i - 1i) + 1i) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i))));
    var forwice: u32 = (W + bitcast<u32>((((((112i - 1i) + 1i) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i))));
    var extcoliq: u32 = (W + bitcast<u32>(((((((112i - 1i) + 1i) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i))));
    var gliq: u32 = (W + bitcast<u32>((((((((112i - 1i) + 1i) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i))));
    var ssacoliq: u32 = (W + bitcast<u32>(((((((((112i - 1i) + 1i) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i))));
    var forwliq: u32 = (W + bitcast<u32>((((((((((112i - 1i) + 1i) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i))));
    var extcosno: u32 = (W + bitcast<u32>(((((((((((112i - 1i) + 1i) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i))));
    var gsno: u32 = (W + bitcast<u32>((((((((((((112i - 1i) + 1i) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i))));
    var ssacosno: u32 = (W + bitcast<u32>(((((((((((((112i - 1i) + 1i) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i))));
    var forwsno: u32 = (W + bitcast<u32>((((((((((((((112i - 1i) + 1i) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i)) + ((112i - 1i) + 1i))));
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 112i))) { break; }
                            mem_st(((*C).taormc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i))))), bitcast<u32>(bitcast<f32>(mem_ld(((*C).taucmc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i)))))))));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 112i))) { break; }
                            var r0: f32 = opq((bitcast<f32>(mem_ld(((*C).ciwpmc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i)))))))) + (bitcast<f32>(mem_ld(((*C).clwpmc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i)))))))));
                            var r1: f32 = opq((opq(r0)) + (bitcast<f32>(mem_ld(((*C).cswpmc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i)))))))));
                            cwp = r1;
                            if ((((bitcast<f32>(mem_ld(((*C).cldfmc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i)))))))) >= (1e-20f)) && ((r1 >= (1e-20f)) || ((bitcast<f32>(mem_ld(((*C).taucmc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i)))))))) >= (1e-20f))))) {
                                radice = bitcast<f32>(mem_ld(((*C).reicmc + bitcast<u32>((lay - 1i)))));
                                if (((opq((bitcast<f32>(mem_ld(((*C).ciwpmc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i)))))))) + (bitcast<f32>(mem_ld(((*C).cswpmc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i)))))))))) == 0.0f)) {
                                    mem_st((extcoice + bitcast<u32>((ig - 1i))), bitcast<u32>(0.0f));
                                    mem_st((ssacoice + bitcast<u32>((ig - 1i))), bitcast<u32>(0.0f));
                                    mem_st((gice + bitcast<u32>((ig - 1i))), bitcast<u32>(0.0f));
                                    mem_st((forwice + bitcast<u32>((ig - 1i))), bitcast<u32>(0.0f));
                                    mem_st((extcosno + bitcast<u32>((ig - 1i))), bitcast<u32>(0.0f));
                                    mem_st((ssacosno + bitcast<u32>((ig - 1i))), bitcast<u32>(0.0f));
                                    mem_st((gsno + bitcast<u32>((ig - 1i))), bitcast<u32>(0.0f));
                                    mem_st((forwsno + bitcast<u32>((ig - 1i))), bitcast<u32>(0.0f));
                                } else {
                                    if (((radice < 5.0f) || (radice > (1.4e+02f)))) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                    var r2: f32 = opq((opq(radice)) - (opq(2.0f)));
                                    var r3: f32 = div_cr(r2, 3.0f);
                                    factor = r3;
                                    var r4: i32 = i32(r3);
                                    index = r4;
                                    if ((index == 46i)) {
                                        index = 45i;
                                    }
                                    var r5: f32 = f32(index);
                                    var r6: f32 = opq((opq(factor)) - (opq(r5)));
                                    fint = r6;
                                    ib = K_RRSW_NGB[(ig - 1i)];
                                    var r7: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((12555i + ((index + 1i) - 1i)) + ((ib - 16i) * 46i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((12555i + (index - 1i)) + ((ib - 16i) * 46i))))))));
                                    var r9: f32 = opq(fma(opq(r6), opq(r7), bitcast<f32>(mem_ld((T + bitcast<u32>(((12555i + (index - 1i)) + ((ib - 16i) * 46i))))))));
                                    mem_st((extcoice + bitcast<u32>((ig - 1i))), bitcast<u32>(r9));
                                    var r10: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((13199i + ((index + 1i) - 1i)) + ((ib - 16i) * 46i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((13199i + (index - 1i)) + ((ib - 16i) * 46i))))))));
                                    var r12: f32 = opq(fma(opq(r6), opq(r10), bitcast<f32>(mem_ld((T + bitcast<u32>(((13199i + (index - 1i)) + ((ib - 16i) * 46i))))))));
                                    mem_st((ssacoice + bitcast<u32>((ig - 1i))), bitcast<u32>(r12));
                                    var r13: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((13843i + ((index + 1i) - 1i)) + ((ib - 16i) * 46i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((13843i + (index - 1i)) + ((ib - 16i) * 46i))))))));
                                    var r15: f32 = opq(fma(opq(r6), opq(r13), bitcast<f32>(mem_ld((T + bitcast<u32>(((13843i + (index - 1i)) + ((ib - 16i) * 46i))))))));
                                    mem_st((gice + bitcast<u32>((ig - 1i))), bitcast<u32>(r15));
                                    var r16: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((14487i + ((index + 1i) - 1i)) + ((ib - 16i) * 46i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((14487i + (index - 1i)) + ((ib - 16i) * 46i))))))));
                                    var r18: f32 = opq(fma(opq(r6), opq(r16), bitcast<f32>(mem_ld((T + bitcast<u32>(((14487i + (index - 1i)) + ((ib - 16i) * 46i))))))));
                                    mem_st((fdelta + bitcast<u32>((ig - 1i))), bitcast<u32>(r18));
                                    if (((bitcast<f32>(mem_ld((fdelta + bitcast<u32>((ig - 1i)))))) < 0.0f)) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                    if (((bitcast<f32>(mem_ld((fdelta + bitcast<u32>((ig - 1i)))))) > 1.0f)) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                    var r19: f32 = div_cr(0.5f, bitcast<f32>(mem_ld((ssacoice + bitcast<u32>((ig - 1i))))));
                                    var r20: f32 = opq((bitcast<f32>(mem_ld((fdelta + bitcast<u32>((ig - 1i)))))) + (opq(r19)));
                                    mem_st((forwice + bitcast<u32>((ig - 1i))), bitcast<u32>(r20));
                                    if (((bitcast<f32>(mem_ld((forwice + bitcast<u32>((ig - 1i)))))) > (bitcast<f32>(mem_ld((gice + bitcast<u32>((ig - 1i)))))))) {
                                        mem_st((forwice + bitcast<u32>((ig - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((gice + bitcast<u32>((ig - 1i)))))));
                                    }
                                    if (((bitcast<f32>(mem_ld((extcoice + bitcast<u32>((ig - 1i)))))) < 0.0f)) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                    if (((bitcast<f32>(mem_ld((ssacoice + bitcast<u32>((ig - 1i)))))) > 1.0f)) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                    if (((bitcast<f32>(mem_ld((ssacoice + bitcast<u32>((ig - 1i)))))) < 0.0f)) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                    if (((bitcast<f32>(mem_ld((gice + bitcast<u32>((ig - 1i)))))) > 1.0f)) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                    if (((bitcast<f32>(mem_ld((gice + bitcast<u32>((ig - 1i)))))) < 0.0f)) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                }
                                if ((((bitcast<f32>(mem_ld(((*C).cswpmc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i)))))))) > 0.0f) && (5i == 5i))) {
                                    radsno = bitcast<f32>(mem_ld(((*C).resnmc + bitcast<u32>((lay - 1i)))));
                                    if ((((bitcast<f32>(mem_ld(((*C).resnmc + bitcast<u32>((lay - 1i)))))) < 5.0f) || ((bitcast<f32>(mem_ld(((*C).resnmc + bitcast<u32>((lay - 1i)))))) > (1.4e+02f)))) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                    var r21: f32 = opq((opq(radsno)) - (opq(2.0f)));
                                    var r22: f32 = div_cr(r21, 3.0f);
                                    factor = r22;
                                    var r23: i32 = i32(r22);
                                    index = r23;
                                    if ((index == 46i)) {
                                        index = 45i;
                                    }
                                    var r24: f32 = f32(index);
                                    var r25: f32 = opq((opq(factor)) - (opq(r24)));
                                    fint = r25;
                                    ib = K_RRSW_NGB[(ig - 1i)];
                                    var r26: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((12555i + ((index + 1i) - 1i)) + ((ib - 16i) * 46i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((12555i + (index - 1i)) + ((ib - 16i) * 46i))))))));
                                    var r28: f32 = opq(fma(opq(r25), opq(r26), bitcast<f32>(mem_ld((T + bitcast<u32>(((12555i + (index - 1i)) + ((ib - 16i) * 46i))))))));
                                    mem_st((extcosno + bitcast<u32>((ig - 1i))), bitcast<u32>(r28));
                                    var r29: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((13199i + ((index + 1i) - 1i)) + ((ib - 16i) * 46i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((13199i + (index - 1i)) + ((ib - 16i) * 46i))))))));
                                    var r31: f32 = opq(fma(opq(r25), opq(r29), bitcast<f32>(mem_ld((T + bitcast<u32>(((13199i + (index - 1i)) + ((ib - 16i) * 46i))))))));
                                    mem_st((ssacosno + bitcast<u32>((ig - 1i))), bitcast<u32>(r31));
                                    var r32: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((13843i + ((index + 1i) - 1i)) + ((ib - 16i) * 46i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((13843i + (index - 1i)) + ((ib - 16i) * 46i))))))));
                                    var r34: f32 = opq(fma(opq(r25), opq(r32), bitcast<f32>(mem_ld((T + bitcast<u32>(((13843i + (index - 1i)) + ((ib - 16i) * 46i))))))));
                                    mem_st((gsno + bitcast<u32>((ig - 1i))), bitcast<u32>(r34));
                                    var r35: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((14487i + ((index + 1i) - 1i)) + ((ib - 16i) * 46i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((14487i + (index - 1i)) + ((ib - 16i) * 46i))))))));
                                    var r37: f32 = opq(fma(opq(r25), opq(r35), bitcast<f32>(mem_ld((T + bitcast<u32>(((14487i + (index - 1i)) + ((ib - 16i) * 46i))))))));
                                    mem_st((fdelta + bitcast<u32>((ig - 1i))), bitcast<u32>(r37));
                                    if (((bitcast<f32>(mem_ld((fdelta + bitcast<u32>((ig - 1i)))))) < 0.0f)) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                    if (((bitcast<f32>(mem_ld((fdelta + bitcast<u32>((ig - 1i)))))) > 1.0f)) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                    var r38: f32 = div_cr(0.5f, bitcast<f32>(mem_ld((ssacosno + bitcast<u32>((ig - 1i))))));
                                    var r39: f32 = opq((bitcast<f32>(mem_ld((fdelta + bitcast<u32>((ig - 1i)))))) + (opq(r38)));
                                    mem_st((forwsno + bitcast<u32>((ig - 1i))), bitcast<u32>(r39));
                                    if (((bitcast<f32>(mem_ld((forwsno + bitcast<u32>((ig - 1i)))))) > (bitcast<f32>(mem_ld((gsno + bitcast<u32>((ig - 1i)))))))) {
                                        mem_st((forwsno + bitcast<u32>((ig - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((gsno + bitcast<u32>((ig - 1i)))))));
                                    }
                                    if (((bitcast<f32>(mem_ld((extcosno + bitcast<u32>((ig - 1i)))))) < 0.0f)) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                    if (((bitcast<f32>(mem_ld((ssacosno + bitcast<u32>((ig - 1i)))))) > 1.0f)) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                    if (((bitcast<f32>(mem_ld((ssacosno + bitcast<u32>((ig - 1i)))))) < 0.0f)) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                    if (((bitcast<f32>(mem_ld((gsno + bitcast<u32>((ig - 1i)))))) > 1.0f)) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                    if (((bitcast<f32>(mem_ld((gsno + bitcast<u32>((ig - 1i)))))) < 0.0f)) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                } else {
                                    mem_st((extcosno + bitcast<u32>((ig - 1i))), bitcast<u32>(0.0f));
                                    mem_st((ssacosno + bitcast<u32>((ig - 1i))), bitcast<u32>(0.0f));
                                    mem_st((gsno + bitcast<u32>((ig - 1i))), bitcast<u32>(0.0f));
                                    mem_st((forwsno + bitcast<u32>((ig - 1i))), bitcast<u32>(0.0f));
                                }
                                if (((bitcast<f32>(mem_ld(((*C).clwpmc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i)))))))) == 0.0f)) {
                                    mem_st((extcoliq + bitcast<u32>((ig - 1i))), bitcast<u32>(0.0f));
                                    mem_st((ssacoliq + bitcast<u32>((ig - 1i))), bitcast<u32>(0.0f));
                                    mem_st((gliq + bitcast<u32>((ig - 1i))), bitcast<u32>(0.0f));
                                    mem_st((forwliq + bitcast<u32>((ig - 1i))), bitcast<u32>(0.0f));
                                } else {
                                    radliq = bitcast<f32>(mem_ld(((*C).relqmc + bitcast<u32>((lay - 1i)))));
                                    if ((((bitcast<f32>(mem_ld(((*C).relqmc + bitcast<u32>((lay - 1i)))))) < 1.5f) || ((bitcast<f32>(mem_ld(((*C).relqmc + bitcast<u32>((lay - 1i)))))) > (6e+01f)))) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                    var r40: f32 = opq((opq(radliq)) - (opq(1.5f)));
                                    var r41: i32 = i32(r40);
                                    index = r41;
                                    if ((index == 0i)) {
                                        index = 1i;
                                    }
                                    if ((index == 58i)) {
                                        index = 57i;
                                    }
                                    var r42: f32 = f32(index);
                                    var r43: f32 = opq((opq(r40)) - (opq(r42)));
                                    fint = r43;
                                    ib = K_RRSW_NGB[(ig - 1i)];
                                    var r44: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((10119i + ((index + 1i) - 1i)) + ((ib - 16i) * 58i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((10119i + (index - 1i)) + ((ib - 16i) * 58i))))))));
                                    var r46: f32 = opq(fma(opq(r43), opq(r44), bitcast<f32>(mem_ld((T + bitcast<u32>(((10119i + (index - 1i)) + ((ib - 16i) * 58i))))))));
                                    mem_st((extcoliq + bitcast<u32>((ig - 1i))), bitcast<u32>(r46));
                                    var r47: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((10931i + ((index + 1i) - 1i)) + ((ib - 16i) * 58i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((10931i + (index - 1i)) + ((ib - 16i) * 58i))))))));
                                    var r49: f32 = opq(fma(opq(r43), opq(r47), bitcast<f32>(mem_ld((T + bitcast<u32>(((10931i + (index - 1i)) + ((ib - 16i) * 58i))))))));
                                    mem_st((ssacoliq + bitcast<u32>((ig - 1i))), bitcast<u32>(r49));
                                    if (((r43 < 0.0f) && ((bitcast<f32>(mem_ld((ssacoliq + bitcast<u32>((ig - 1i)))))) > 1.0f))) {
                                        mem_st((ssacoliq + bitcast<u32>((ig - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>(((10931i + (index - 1i)) + ((ib - 16i) * 58i))))))));
                                    }
                                    var r50: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((11743i + ((index + 1i) - 1i)) + ((ib - 16i) * 58i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((11743i + (index - 1i)) + ((ib - 16i) * 58i))))))));
                                    var r52: f32 = opq(fma(opq(fint), opq(r50), bitcast<f32>(mem_ld((T + bitcast<u32>(((11743i + (index - 1i)) + ((ib - 16i) * 58i))))))));
                                    mem_st((gliq + bitcast<u32>((ig - 1i))), bitcast<u32>(r52));
                                    var r53: f32 = opq((bitcast<f32>(mem_ld((gliq + bitcast<u32>((ig - 1i)))))) * (bitcast<f32>(mem_ld((gliq + bitcast<u32>((ig - 1i)))))));
                                    mem_st((forwliq + bitcast<u32>((ig - 1i))), bitcast<u32>(r53));
                                    if (((bitcast<f32>(mem_ld((extcoliq + bitcast<u32>((ig - 1i)))))) < 0.0f)) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                    if (((bitcast<f32>(mem_ld((ssacoliq + bitcast<u32>((ig - 1i)))))) > 1.0f)) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                    if (((bitcast<f32>(mem_ld((ssacoliq + bitcast<u32>((ig - 1i)))))) < 0.0f)) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                    if (((bitcast<f32>(mem_ld((gliq + bitcast<u32>((ig - 1i)))))) > 1.0f)) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                    if (((bitcast<f32>(mem_ld((gliq + bitcast<u32>((ig - 1i)))))) < 0.0f)) {
                                        (*C).fail = 1i;
                                        return;
                                    }
                                }
                                var r54: f32 = opq((bitcast<f32>(mem_ld(((*C).clwpmc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i)))))))) * (bitcast<f32>(mem_ld((extcoliq + bitcast<u32>((ig - 1i)))))));
                                tauliqorig = r54;
                                var r55: f32 = opq((bitcast<f32>(mem_ld(((*C).ciwpmc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i)))))))) * (bitcast<f32>(mem_ld((extcoice + bitcast<u32>((ig - 1i)))))));
                                tauiceorig = r55;
                                var r56: f32 = opq((bitcast<f32>(mem_ld(((*C).cswpmc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i)))))))) * (bitcast<f32>(mem_ld((extcosno + bitcast<u32>((ig - 1i)))))));
                                tausnoorig = r56;
                                var r57: f32 = opq((opq(r54)) + (opq(r55)));
                                var r58: f32 = opq((opq(r57)) + (opq(r56)));
                                mem_st(((*C).taormc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i))))), bitcast<u32>(r58));
                                var r59: f32 = opq((opq(1.0f)) - (bitcast<f32>(mem_ld((forwliq + bitcast<u32>((ig - 1i)))))));
                                var r60: f32 = opq((bitcast<f32>(mem_ld((ssacoliq + bitcast<u32>((ig - 1i)))))) * (opq(r59)));
                                var r62: f32 = opq(fma(opq(f_rr_neg(bitcast<f32>(mem_ld((forwliq + bitcast<u32>((ig - 1i))))), (*C).z0)), bitcast<f32>(mem_ld((ssacoliq + bitcast<u32>((ig - 1i))))), opq(1.0f)));
                                var r63: f32 = div_cr(r60, r62);
                                ssaliq = r63;
                                var r64: f32 = opq((opq(r62)) * (opq(r54)));
                                tauliq = r64;
                                var r65: f32 = opq((opq(1.0f)) - (bitcast<f32>(mem_ld((forwice + bitcast<u32>((ig - 1i)))))));
                                var r66: f32 = opq((bitcast<f32>(mem_ld((ssacoice + bitcast<u32>((ig - 1i)))))) * (opq(r65)));
                                var r68: f32 = opq(fma(opq(f_rr_neg(bitcast<f32>(mem_ld((forwice + bitcast<u32>((ig - 1i))))), (*C).z0)), bitcast<f32>(mem_ld((ssacoice + bitcast<u32>((ig - 1i))))), opq(1.0f)));
                                var r69: f32 = div_cr(r66, r68);
                                ssaice = r69;
                                var r70: f32 = opq((opq(r68)) * (opq(r55)));
                                tauice = r70;
                                var r71: f32 = opq((opq(1.0f)) - (bitcast<f32>(mem_ld((forwsno + bitcast<u32>((ig - 1i)))))));
                                var r72: f32 = opq((bitcast<f32>(mem_ld((ssacosno + bitcast<u32>((ig - 1i)))))) * (opq(r71)));
                                var r74: f32 = opq(fma(opq(f_rr_neg(bitcast<f32>(mem_ld((forwsno + bitcast<u32>((ig - 1i))))), (*C).z0)), bitcast<f32>(mem_ld((ssacosno + bitcast<u32>((ig - 1i))))), opq(1.0f)));
                                var r75: f32 = div_cr(r72, r74);
                                ssasno = r75;
                                var r76: f32 = opq((opq(r74)) * (opq(r56)));
                                tausno = r76;
                                var r77: f32 = opq((opq(r63)) * (opq(r64)));
                                scatliq = r77;
                                var r78: f32 = opq((opq(r69)) * (opq(r70)));
                                scatice = r78;
                                var r79: f32 = opq((opq(r75)) * (opq(r76)));
                                scatsno = r79;
                                var r80: f32 = opq((opq(r64)) + (opq(r70)));
                                var r81: f32 = opq((opq(r80)) + (opq(r76)));
                                mem_st(((*C).taucmc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i))))), bitcast<u32>(r81));
                                if (((bitcast<f32>(mem_ld(((*C).taucmc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i)))))))) == 0.0f)) {
                                    mem_st(((*C).taucmc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i))))), bitcast<u32>(1e-20f));
                                }
                                if ((scatice == 0.0f)) {
                                    scatice = 1e-20f;
                                }
                                if ((scatsno == 0.0f)) {
                                    scatsno = 1e-20f;
                                }
                                var r82: f32 = opq((opq(scatliq)) + (opq(scatice)));
                                var r83: f32 = opq((opq(r82)) + (opq(scatsno)));
                                var r84: f32 = div_cr(r83, bitcast<f32>(mem_ld(((*C).taucmc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i))))))));
                                mem_st(((*C).ssacmc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i))))), bitcast<u32>(r84));
                                var r85: f32 = div_cr(1.0f, r83);
                                var r86: f32 = opq((bitcast<f32>(mem_ld((gliq + bitcast<u32>((ig - 1i)))))) - (bitcast<f32>(mem_ld((forwliq + bitcast<u32>((ig - 1i)))))));
                                var r87: f32 = opq((opq(scatliq)) * (opq(r86)));
                                var r88: f32 = div_cr(r87, r59);
                                var r89: f32 = opq((bitcast<f32>(mem_ld((gice + bitcast<u32>((ig - 1i)))))) - (bitcast<f32>(mem_ld((forwice + bitcast<u32>((ig - 1i)))))));
                                var r90: f32 = div_cr(r89, r65);
                                var r92: f32 = opq(fma(opq(scatice), opq(r90), opq(r88)));
                                var r93: f32 = opq((bitcast<f32>(mem_ld((gsno + bitcast<u32>((ig - 1i)))))) - (bitcast<f32>(mem_ld((forwsno + bitcast<u32>((ig - 1i)))))));
                                var r94: f32 = div_cr(r93, r71);
                                var r96: f32 = opq(fma(opq(scatsno), opq(r94), opq(r92)));
                                var r97: f32 = opq((opq(r85)) * (opq(r96)));
                                mem_st(((*C).asmcmc + bitcast<u32>(((ig - 1i) + ((112i) * (lay - 1i))))), bitcast<u32>(r97));
                            }
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rr_neg(x_in: f32, z0_in: u32) -> f32 {
    var x: f32 = x_in;
    var z0: u32 = z0_in;
    return bitcast<f32>(((bitcast<u32>(x)) ^ (2147483648u ^ z0)));
}

fn f_rrsw_setcoef_sw(C: ptr<function, S_RRSWColumn>, T_in: u32, W_in: u32, WI_in: u32) {
    var T: u32 = T_in;
    var W: u32 = W_in;
    var WI: u32 = WI_in;
    var co2reg: f32 = f32(0i);
    var compfp: f32 = f32(0i);
    var factor: f32 = f32(0i);
    var fp: f32 = f32(0i);
    var ft: f32 = f32(0i);
    var ft1: f32 = f32(0i);
    var indbound: i32 = 0i;
    var indlev0: i32 = 0i;
    var jp1: i32 = 0i;
    var lay: i32 = 0i;
    var plog: f32 = f32(0i);
    var scalefac: f32 = f32(0i);
    var stpfac: f32 = f32(0i);
    var t0frac: f32 = f32(0i);
    var tbndfrac: f32 = f32(0i);
    var water: f32 = f32(0i);
    var r0: f32 = div_cr(296.0f, 1013.0f);
    stpfac = r0;
    var r1: f32 = opq((opq((*C).tbound)) - (opq(159.0f)));
    var r2: i32 = i32(r1);
    indbound = r2;
    var r3: f32 = f32(i32((*C).tbound));
    var r4: f32 = opq((opq((*C).tbound)) - (opq(r3)));
    tbndfrac = r4;
    var r5: f32 = opq((bitcast<f32>(mem_ld(((*C).tz + bitcast<u32>(((0i) - 0i)))))) - (opq(159.0f)));
    var r6: i32 = i32(r5);
    indlev0 = r6;
    var r7: f32 = f32(i32(bitcast<f32>(mem_ld(((*C).tz + bitcast<u32>(((0i) - 0i)))))));
    var r8: f32 = opq((bitcast<f32>(mem_ld(((*C).tz + bitcast<u32>(((0i) - 0i)))))) - (opq(r7)));
    t0frac = r8;
    (*C).laytrop = 0i;
    (*C).layswtch = 0i;
    (*C).laylow = 0i;
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                var r9: f32 = f_rr_log_cr(bitcast<f32>(mem_ld(((*C).pavel + bitcast<u32>((lay - 1i))))));
                plog = r9;
                var r10: f32 = opq((opq(r9)) + (opq(0.04f)));
                var r12: f32 = opq(fma(opq(f_rr_neg(5.0f, (*C).z0)), opq(r10), opq(36.0f)));
                var r13: i32 = i32(r12);
                mem_st(((*C).jp + bitcast<u32>((lay - 1i))), bitcast<u32>(r13));
                if (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) < 1i)) {
                    mem_st(((*C).jp + bitcast<u32>((lay - 1i))), bitcast<u32>(1i));
                } else {
                    if (((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) > 58i)) {
                        mem_st(((*C).jp + bitcast<u32>((lay - 1i))), bitcast<u32>(58i));
                    }
                }
                jp1 = ((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) + 1i);
                var r14: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>((10001i + ((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i))))))) - (opq(plog)));
                var r15: f32 = opq((opq(5.0f)) * (opq(r14)));
                fp = r15;
                var r16: f32 = opq((bitcast<f32>(mem_ld(((*C).tavel + bitcast<u32>((lay - 1i)))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>((10060i + ((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i))))))));
                var r17: f32 = div_cr(r16, 15.0f);
                var r18: f32 = opq((opq(3.0f)) + (opq(r17)));
                var r19: i32 = i32(r18);
                mem_st(((*C).jt + bitcast<u32>((lay - 1i))), bitcast<u32>(r19));
                if (((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) < 1i)) {
                    mem_st(((*C).jt + bitcast<u32>((lay - 1i))), bitcast<u32>(1i));
                } else {
                    if (((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) > 4i)) {
                        mem_st(((*C).jt + bitcast<u32>((lay - 1i))), bitcast<u32>(4i));
                    }
                }
                var r20: f32 = f32(((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 3i));
                var r21: f32 = opq((opq(r17)) - (opq(r20)));
                ft = r21;
                var r22: f32 = opq((bitcast<f32>(mem_ld(((*C).tavel + bitcast<u32>((lay - 1i)))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>((10060i + (jp1 - 1i))))))));
                var r23: f32 = div_cr(r22, 15.0f);
                var r24: f32 = opq((opq(3.0f)) + (opq(r23)));
                var r25: i32 = i32(r24);
                mem_st(((*C).jt1 + bitcast<u32>((lay - 1i))), bitcast<u32>(r25));
                if (((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) < 1i)) {
                    mem_st(((*C).jt1 + bitcast<u32>((lay - 1i))), bitcast<u32>(1i));
                } else {
                    if (((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) > 4i)) {
                        mem_st(((*C).jt1 + bitcast<u32>((lay - 1i))), bitcast<u32>(4i));
                    }
                }
                var r26: f32 = f32(((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 3i));
                var r27: f32 = opq((opq(r23)) - (opq(r26)));
                ft1 = r27;
                var r28: f32 = div_cr(bitcast<f32>(mem_ld(((*C).wkl + bitcast<u32>((((1i) - 1i) + ((7i) * (lay - 1i))))))), bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i))))));
                water = r28;
                var r29: f32 = opq((bitcast<f32>(mem_ld(((*C).pavel + bitcast<u32>((lay - 1i)))))) * (opq(stpfac)));
                var r30: f32 = div_cr(r29, bitcast<f32>(mem_ld(((*C).tavel + bitcast<u32>((lay - 1i))))));
                scalefac = r30;
                if ((plog <= 4.56f)) {
                    var r31: f32 = opq((opq(1.0f)) + (opq(water)));
                    var r32: f32 = div_cr(scalefac, r31);
                    mem_st(((*C).forfac + bitcast<u32>((lay - 1i))), bitcast<u32>(r32));
                    var r33: f32 = opq((bitcast<f32>(mem_ld(((*C).tavel + bitcast<u32>((lay - 1i)))))) - (opq(188.0f)));
                    var r34: f32 = div_cr(r33, 36.0f);
                    factor = r34;
                    mem_st(((*C).indfor + bitcast<u32>((lay - 1i))), bitcast<u32>(3i));
                    var r35: f32 = opq((opq(r34)) - (opq(1.0f)));
                    mem_st(((*C).forfrac + bitcast<u32>((lay - 1i))), bitcast<u32>(r35));
                    var r36: f32 = opq((opq(1e-20f)) * (bitcast<f32>(mem_ld(((*C).wkl + bitcast<u32>((((1i) - 1i) + ((7i) * (lay - 1i)))))))));
                    mem_st(((*C).colh2o + bitcast<u32>((lay - 1i))), bitcast<u32>(r36));
                    var r37: f32 = opq((opq(1e-20f)) * (bitcast<f32>(mem_ld(((*C).wkl + bitcast<u32>((((2i) - 1i) + ((7i) * (lay - 1i)))))))));
                    mem_st(((*C).colco2 + bitcast<u32>((lay - 1i))), bitcast<u32>(r37));
                    var r38: f32 = opq((opq(1e-20f)) * (bitcast<f32>(mem_ld(((*C).wkl + bitcast<u32>((((3i) - 1i) + ((7i) * (lay - 1i)))))))));
                    mem_st(((*C).colo3 + bitcast<u32>((lay - 1i))), bitcast<u32>(r38));
                    var r39: f32 = opq((opq(1e-20f)) * (bitcast<f32>(mem_ld(((*C).wkl + bitcast<u32>((((4i) - 1i) + ((7i) * (lay - 1i)))))))));
                    mem_st(((*C).coln2o + bitcast<u32>((lay - 1i))), bitcast<u32>(r39));
                    var r40: f32 = opq((opq(1e-20f)) * (bitcast<f32>(mem_ld(((*C).wkl + bitcast<u32>((((6i) - 1i) + ((7i) * (lay - 1i)))))))));
                    mem_st(((*C).colch4 + bitcast<u32>((lay - 1i))), bitcast<u32>(r40));
                    var r41: f32 = opq((opq(1e-20f)) * (bitcast<f32>(mem_ld(((*C).wkl + bitcast<u32>((((7i) - 1i) + ((7i) * (lay - 1i)))))))));
                    mem_st(((*C).colo2 + bitcast<u32>((lay - 1i))), bitcast<u32>(r41));
                    var r43: f32 = opq(fma(opq(1e-20f), bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                    mem_st(((*C).colmol + bitcast<u32>((lay - 1i))), bitcast<u32>(r43));
                    if (((bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i)))))) == 0.0f)) {
                        var r44: f32 = opq((opq(1e-32f)) * (bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i)))))));
                        mem_st(((*C).colco2 + bitcast<u32>((lay - 1i))), bitcast<u32>(r44));
                    }
                    if (((bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i)))))) == 0.0f)) {
                        var r45: f32 = opq((opq(1e-32f)) * (bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i)))))));
                        mem_st(((*C).coln2o + bitcast<u32>((lay - 1i))), bitcast<u32>(r45));
                    }
                    if (((bitcast<f32>(mem_ld(((*C).colch4 + bitcast<u32>((lay - 1i)))))) == 0.0f)) {
                        var r46: f32 = opq((opq(1e-32f)) * (bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i)))))));
                        mem_st(((*C).colch4 + bitcast<u32>((lay - 1i))), bitcast<u32>(r46));
                    }
                    if (((bitcast<f32>(mem_ld(((*C).colo2 + bitcast<u32>((lay - 1i)))))) == 0.0f)) {
                        var r47: f32 = opq((opq(1e-32f)) * (bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i)))))));
                        mem_st(((*C).colo2 + bitcast<u32>((lay - 1i))), bitcast<u32>(r47));
                    }
                    var r49: f32 = opq(fma(opq(f_rr_neg(3.55e-24f, (*C).z0)), bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i)))))));
                    var r50: f32 = opq((opq(r49)) * (opq(272.63f)));
                    var r51: f32 = div_cr(1919.4f, bitcast<f32>(mem_ld(((*C).tavel + bitcast<u32>((lay - 1i))))));
                    var r52: f32 = f_rr_neg(r51, (*C).z0);
                    var r53: f32 = f_rr_exp_cr(r52);
                    var r54: f32 = opq((opq(r50)) * (opq(r53)));
                    var r55: f32 = opq((opq(0.00087604f)) * (bitcast<f32>(mem_ld(((*C).tavel + bitcast<u32>((lay - 1i)))))));
                    var r56: f32 = div_cr(r54, r55);
                    mem_st(((*C).co2mult + bitcast<u32>((lay - 1i))), bitcast<u32>(r56));
                    mem_st(((*C).selffac + bitcast<u32>((lay - 1i))), bitcast<u32>(0.0f));
                    mem_st(((*C).selffrac + bitcast<u32>((lay - 1i))), bitcast<u32>(0.0f));
                    mem_st(((*C).indself + bitcast<u32>((lay - 1i))), bitcast<u32>(0i));
                } else {
                    (*C).laytrop = (((*C).laytrop) + 1i);
                    if ((plog >= 6.62f)) {
                        (*C).laylow = (((*C).laylow) + 1i);
                    }
                    var r57: f32 = opq((opq(1.0f)) + (opq(water)));
                    var r58: f32 = div_cr(scalefac, r57);
                    mem_st(((*C).forfac + bitcast<u32>((lay - 1i))), bitcast<u32>(r58));
                    var r59: f32 = opq((opq(332.0f)) - (bitcast<f32>(mem_ld(((*C).tavel + bitcast<u32>((lay - 1i)))))));
                    var r60: f32 = div_cr(r59, 36.0f);
                    factor = r60;
                    var r61: i32 = min(2i, max(1i, i32(r60)));
                    mem_st(((*C).indfor + bitcast<u32>((lay - 1i))), bitcast<u32>(r61));
                    var r62: f32 = f32(bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i))))));
                    var r63: f32 = opq((opq(r60)) - (opq(r62)));
                    mem_st(((*C).forfrac + bitcast<u32>((lay - 1i))), bitcast<u32>(r63));
                    var r64: f32 = opq((opq(water)) * (bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i)))))));
                    mem_st(((*C).selffac + bitcast<u32>((lay - 1i))), bitcast<u32>(r64));
                    var r65: f32 = opq((bitcast<f32>(mem_ld(((*C).tavel + bitcast<u32>((lay - 1i)))))) - (opq(188.0f)));
                    var r66: f32 = div_cr(r65, 7.2f);
                    factor = r66;
                    var r67: i32 = min(9i, max(1i, ((i32(r66)) - 7i)));
                    mem_st(((*C).indself + bitcast<u32>((lay - 1i))), bitcast<u32>(r67));
                    var r68: f32 = f32(((bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))))) + 7i));
                    var r69: f32 = opq((opq(r66)) - (opq(r68)));
                    mem_st(((*C).selffrac + bitcast<u32>((lay - 1i))), bitcast<u32>(r69));
                    var r70: f32 = opq((opq(1e-20f)) * (bitcast<f32>(mem_ld(((*C).wkl + bitcast<u32>((((1i) - 1i) + ((7i) * (lay - 1i)))))))));
                    mem_st(((*C).colh2o + bitcast<u32>((lay - 1i))), bitcast<u32>(r70));
                    var r71: f32 = opq((opq(1e-20f)) * (bitcast<f32>(mem_ld(((*C).wkl + bitcast<u32>((((2i) - 1i) + ((7i) * (lay - 1i)))))))));
                    mem_st(((*C).colco2 + bitcast<u32>((lay - 1i))), bitcast<u32>(r71));
                    var r72: f32 = opq((opq(1e-20f)) * (bitcast<f32>(mem_ld(((*C).wkl + bitcast<u32>((((3i) - 1i) + ((7i) * (lay - 1i)))))))));
                    mem_st(((*C).colo3 + bitcast<u32>((lay - 1i))), bitcast<u32>(r72));
                    var r73: f32 = opq((opq(1e-20f)) * (bitcast<f32>(mem_ld(((*C).wkl + bitcast<u32>((((4i) - 1i) + ((7i) * (lay - 1i)))))))));
                    mem_st(((*C).coln2o + bitcast<u32>((lay - 1i))), bitcast<u32>(r73));
                    var r74: f32 = opq((opq(1e-20f)) * (bitcast<f32>(mem_ld(((*C).wkl + bitcast<u32>((((6i) - 1i) + ((7i) * (lay - 1i)))))))));
                    mem_st(((*C).colch4 + bitcast<u32>((lay - 1i))), bitcast<u32>(r74));
                    var r75: f32 = opq((opq(1e-20f)) * (bitcast<f32>(mem_ld(((*C).wkl + bitcast<u32>((((7i) - 1i) + ((7i) * (lay - 1i)))))))));
                    mem_st(((*C).colo2 + bitcast<u32>((lay - 1i))), bitcast<u32>(r75));
                    var r77: f32 = opq(fma(opq(1e-20f), bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                    mem_st(((*C).colmol + bitcast<u32>((lay - 1i))), bitcast<u32>(r77));
                    if (((bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i)))))) == 0.0f)) {
                        var r78: f32 = opq((opq(1e-32f)) * (bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i)))))));
                        mem_st(((*C).colco2 + bitcast<u32>((lay - 1i))), bitcast<u32>(r78));
                    }
                    if (((bitcast<f32>(mem_ld(((*C).coln2o + bitcast<u32>((lay - 1i)))))) == 0.0f)) {
                        var r79: f32 = opq((opq(1e-32f)) * (bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i)))))));
                        mem_st(((*C).coln2o + bitcast<u32>((lay - 1i))), bitcast<u32>(r79));
                    }
                    if (((bitcast<f32>(mem_ld(((*C).colch4 + bitcast<u32>((lay - 1i)))))) == 0.0f)) {
                        var r80: f32 = opq((opq(1e-32f)) * (bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i)))))));
                        mem_st(((*C).colch4 + bitcast<u32>((lay - 1i))), bitcast<u32>(r80));
                    }
                    if (((bitcast<f32>(mem_ld(((*C).colo2 + bitcast<u32>((lay - 1i)))))) == 0.0f)) {
                        var r81: f32 = opq((opq(1e-32f)) * (bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i)))))));
                        mem_st(((*C).colo2 + bitcast<u32>((lay - 1i))), bitcast<u32>(r81));
                    }
                    var r83: f32 = opq(fma(opq(f_rr_neg(3.55e-24f, (*C).z0)), bitcast<f32>(mem_ld(((*C).coldry + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i)))))));
                    var r84: f32 = opq((opq(r83)) * (opq(272.63f)));
                    var r85: f32 = div_cr(1919.4f, bitcast<f32>(mem_ld(((*C).tavel + bitcast<u32>((lay - 1i))))));
                    var r86: f32 = f_rr_neg(r85, (*C).z0);
                    var r87: f32 = f_rr_exp_cr(r86);
                    var r88: f32 = opq((opq(r84)) * (opq(r87)));
                    var r89: f32 = opq((opq(0.00087604f)) * (bitcast<f32>(mem_ld(((*C).tavel + bitcast<u32>((lay - 1i)))))));
                    var r90: f32 = div_cr(r88, r89);
                    mem_st(((*C).co2mult + bitcast<u32>((lay - 1i))), bitcast<u32>(r90));
                }
                var r91: f32 = opq((opq(1.0f)) - (opq(fp)));
                compfp = r91;
                var r92: f32 = opq((opq(r91)) * (opq(ft)));
                mem_st(((*C).fac10 + bitcast<u32>((lay - 1i))), bitcast<u32>(r92));
                var r93: f32 = opq((opq(1.0f)) - (opq(ft)));
                var r94: f32 = opq((opq(r91)) * (opq(r93)));
                mem_st(((*C).fac00 + bitcast<u32>((lay - 1i))), bitcast<u32>(r94));
                var r95: f32 = opq((opq(fp)) * (opq(ft1)));
                mem_st(((*C).fac11 + bitcast<u32>((lay - 1i))), bitcast<u32>(r95));
                var r96: f32 = opq((opq(1.0f)) - (opq(ft1)));
                var r97: f32 = opq((opq(fp)) * (opq(r96)));
                mem_st(((*C).fac01 + bitcast<u32>((lay - 1i))), bitcast<u32>(r97));
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rr_log_cr(x_in: f32) -> f32 {
    var x: f32 = x_in;
    if (((!(x > 0.0f)) || ((bitcast<u32>(x) & 0x7fffffffu) == 0x7f800000u))) {
        return opq(log(x));
    }
    var a: vec2<f32> = f_rr_log_ff(x);
    return opq((opq(a.x)) + (opq(a.y)));
}

fn f_rr_log_ff(x_in: f32) -> vec2<f32> {
    var x: f32 = x_in;
    var e: i32;
    let _t1 = frexp(x);
    e = _t1.exp;
    var m: f32 = _t1.fract;
    if ((m < 0.70710677f)) {
        m = opq((opq(m)) * (opq(2.0f)));
        e = (e - 1i);
    }
    var f: f32 = opq((opq(m)) - (opq(1.0f)));
    var d: vec2<f32> = f_rr_two_sum(2.0f, f);
    var sh: f32 = div_cr(f, d.x);
    var r: f32 = opq(fma(opq((-(opq(sh)))), opq(d.x), opq(f)));
    r = opq(fma(opq((-(opq(sh)))), opq(d.y), opq(r)));
    var sf: vec2<f32> = f_rr_quick_two_sum(sh, div_cr(r, d.x));
    var s2: vec2<f32> = f_rr_mul_ff(sf, sf);
    var s3: vec2<f32> = f_rr_mul_ff(s2, sf);
    var P: vec2<f32> = vec2<f32>(0.11764706f, opq((-(opq(4.3826945e-10f)))));
    P = f_rr_add_ff(f_rr_mul_ff(P, s2), vec2<f32>(0.13333334f, opq((-(opq(6.9538753e-09f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, s2), vec2<f32>(0.15384616f, opq((-(opq(5.731216e-09f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, s2), vec2<f32>(0.18181819f, opq((-(opq(5.4186042e-09f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, s2), vec2<f32>(0.22222222f, opq((-(opq(1.6556846e-09f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, s2), vec2<f32>(0.2857143f, opq((-(opq(1.2772424e-08f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, s2), vec2<f32>(0.4f, opq((-(opq(5.9604646e-09f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, s2), vec2<f32>(0.6666667f, opq((-(opq(1.9868216e-08f))))));
    var l1p: vec2<f32> = f_rr_add_ff(vec2<f32>(opq((opq(2.0f)) * (opq(sf.x))), opq((opq(2.0f)) * (opq(sf.y)))), f_rr_mul_ff(s3, P));
    var ln2h: f32 = 0.69314575f;
    var ln2m: f32 = 1.4285906e-06f;
    var ln2l: f32 = 1.6198487e-11f;
    var fe: f32 = f32(e);
    var a: vec2<f32> = f_rr_add_ff(vec2<f32>(opq((opq(fe)) * (opq(ln2h))), opq((opq(fe)) * (opq(ln2m)))), l1p);
    return f_rr_add_ff(a, vec2<f32>(opq((opq(fe)) * (opq(ln2l))), 0.0f));
}

fn f_rr_two_sum(a_in: f32, b_in: f32) -> vec2<f32> {
    var a: f32 = a_in;
    var b: f32 = b_in;
    var s: f32 = opq((opq(a)) + (opq(b)));
    var bb: f32 = opq((opq(s)) - (opq(a)));
    return vec2<f32>(s, opq((opq((opq(a)) - (opq((opq(s)) - (opq(bb)))))) + (opq((opq(b)) - (opq(bb))))));
}

fn f_rr_quick_two_sum(a_in: f32, b_in: f32) -> vec2<f32> {
    var a: f32 = a_in;
    var b: f32 = b_in;
    var s: f32 = opq((opq(a)) + (opq(b)));
    return vec2<f32>(s, opq((opq(b)) - (opq((opq(s)) - (opq(a))))));
}

fn f_rr_mul_ff(a_in: vec2<f32>, b_in: vec2<f32>) -> vec2<f32> {
    var a: vec2<f32> = a_in;
    var b: vec2<f32> = b_in;
    var p: f32 = opq((opq(a.x)) * (opq(b.x)));
    var e: f32 = opq(fma(opq(a.x), opq(b.x), opq((-(opq(p))))));
    e = opq(fma(opq(a.x), opq(b.y), opq(e)));
    e = opq(fma(opq(a.y), opq(b.x), opq(e)));
    return f_rr_quick_two_sum(p, e);
}

fn f_rr_add_ff(a_in: vec2<f32>, b_in: vec2<f32>) -> vec2<f32> {
    var a: vec2<f32> = a_in;
    var b: vec2<f32> = b_in;
    var s: vec2<f32> = f_rr_two_sum(a.x, b.x);
    var t: vec2<f32> = f_rr_two_sum(a.y, b.y);
    var u: vec2<f32> = f_rr_quick_two_sum(s.x, opq((opq(s.y)) + (opq(t.x))));
    return f_rr_quick_two_sum(u.x, opq((opq(u.y)) + (opq(t.y))));
}

fn f_rr_exp_cr(x_in: f32) -> f32 {
    var x: f32 = x_in;
    if ((!((x > (opq((-(opq(87.3f)))))) && (x < 88.7f)))) {
        return opq(exp(x));
    }
    return f_rr_exp_ff(vec2<f32>(x, 0.0f));
}

fn f_rr_exp_ff(y_in: vec2<f32>) -> f32 {
    var y: vec2<f32> = y_in;
    var ln2h: f32 = 0.69314575f;
    var ln2m: f32 = 1.4285906e-06f;
    var ln2l: f32 = 1.6198487e-11f;
    var k: f32 = round(div_cr(y.x, 0.6931472f));
    var r: vec2<f32> = f_rr_add_ff(y, vec2<f32>(opq((opq((-(opq(k))))) * (opq(ln2h))), opq((opq((-(opq(k))))) * (opq(ln2m)))));
    r = f_rr_add_ff(r, vec2<f32>(opq((opq((-(opq(k))))) * (opq(ln2l))), 0.0f));
    var P: vec2<f32> = vec2<f32>(2.5052108e-08f, 4.417623e-16f);
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(2.755732e-07f, opq((-(opq(7.575112e-15f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(2.7557319e-06f, 3.7935712e-14f));
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(2.4801588e-05f, opq((-(opq(3.406996e-13f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(0.0001984127f, opq((-(opq(2.7255969e-12f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(0.0013888889f, opq((-(opq(3.3631094e-11f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(0.008333334f, opq((-(opq(4.346172e-10f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(0.041666668f, opq((-(opq(1.2417635e-09f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(0.16666667f, opq((-(opq(4.967054e-09f))))));
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(0.5f, 0.0f));
    P = f_rr_add_ff(f_rr_mul_ff(P, r), vec2<f32>(1.0f, 0.0f));
    var Q: vec2<f32> = f_rr_mul_ff(P, r);
    var s: f32 = opq((opq(1.0f)) + (opq(Q.x)));
    var t: f32 = opq((opq((opq(1.0f)) - (opq(s)))) + (opq(Q.x)));
    var ur: vec2<f32> = f_rr_two_sum(t, Q.y);
    var res: f32 = opq((opq(s)) + (opq(ur.x)));
    var bb: f32 = opq((opq(res)) - (opq(s)));
    var e3: f32 = opq((opq((opq(s)) - (opq((opq(res)) - (opq(bb)))))) + (opq((opq(ur.x)) - (opq(bb)))));
    if ((((e3 != 0.0f) && (ur.y != 0.0f)) && ((i32((e3 > 0.0f))) == (i32((ur.y > 0.0f)))))) {
        var nb: f32 = bitcast<f32>(((bitcast<u32>(res)) + (select(4294967295u, 1u, (e3 > 0.0f)))));
        if (((opq((opq(e3)) + (opq(e3)))) == (opq((opq(nb)) - (opq(res)))))) {
            res = nb;
        }
    }
    return ldexp(res, i32(k));
}

fn f_rrsw_spcvmc_sw(C: ptr<function, S_RRSWColumn>, T_in: u32, W_in: u32, WI_in: u32) {
    var T: u32 = T_in;
    var W: u32 = W_in;
    var WI: u32 = WI_in;
    var ib1: i32 = 0i;
    var ib2: i32 = 0i;
    var ibm: i32 = 0i;
    var igt: i32 = 0i;
    var ikl: i32 = 0i;
    var ikp: i32 = 0i;
    var ikx: i32 = 0i;
    var itind: i32 = 0i;
    var iw: i32 = 0i;
    var jb: i32 = 0i;
    var jg: i32 = 0i;
    var jk: i32 = 0i;
    var jl: i32 = 0i;
    var klev: i32 = 0i;
    var repclc: f32 = f32(0i);
    var tauorig: f32 = f32(0i);
    var tblind: f32 = f32(0i);
    var zclear: f32 = f32(0i);
    var zcloud: f32 = f32(0i);
    var zdbtmc: f32 = f32(0i);
    var zdbtmo: f32 = f32(0i);
    var ze1: f32 = f32(0i);
    var zf: f32 = f32(0i);
    var zgw: f32 = f32(0i);
    var zreflect: f32 = f32(0i);
    var zwf: f32 = f32(0i);
    var lrtchkclr: u32 = (WI + bitcast<u32>((0i)));
    var lrtchkcld: u32 = (WI + bitcast<u32>(((((*C).nlayers) - 1i) + 1i)));
    var zdbt: u32 = (W + bitcast<u32>((0i)));
    var zdbt_nodel: u32 = (W + bitcast<u32>((((((*C).nlayers) + 1i) - 1i) + 1i)));
    var zgc: u32 = (W + bitcast<u32>(((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var zgcc: u32 = (W + bitcast<u32>((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i))));
    var zgco: u32 = (W + bitcast<u32>(((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i))));
    var zomc: u32 = (W + bitcast<u32>((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i))));
    var zomcc: u32 = (W + bitcast<u32>(((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i))));
    var zomco: u32 = (W + bitcast<u32>((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i))));
    var zrdnd: u32 = (W + bitcast<u32>(((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i))));
    var zrdndc: u32 = (W + bitcast<u32>((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var zref: u32 = (W + bitcast<u32>(((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var zrefc: u32 = (W + bitcast<u32>((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var zrefo: u32 = (W + bitcast<u32>(((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var zrefd: u32 = (W + bitcast<u32>((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var zrefdc: u32 = (W + bitcast<u32>(((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var zrefdo: u32 = (W + bitcast<u32>((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var zrup: u32 = (W + bitcast<u32>(((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var zrupd: u32 = (W + bitcast<u32>((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var zrupc: u32 = (W + bitcast<u32>(((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var zrupdc: u32 = (W + bitcast<u32>((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var zs1: u32 = (W + bitcast<u32>(((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var ztauc: u32 = (W + bitcast<u32>((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var ztauo: u32 = (W + bitcast<u32>(((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i))));
    var ztdn: u32 = (W + bitcast<u32>((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i))));
    var ztdnd: u32 = (W + bitcast<u32>(((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var ztdbt: u32 = (W + bitcast<u32>((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var ztoc: u32 = (W + bitcast<u32>(((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var ztor: u32 = (W + bitcast<u32>((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i))));
    var ztra: u32 = (W + bitcast<u32>(((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i))));
    var ztrac: u32 = (W + bitcast<u32>((((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var ztrao: u32 = (W + bitcast<u32>(((((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var ztrad: u32 = (W + bitcast<u32>((((((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var ztradc: u32 = (W + bitcast<u32>(((((((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var ztrado: u32 = (W + bitcast<u32>((((((((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var zdbtc: u32 = (W + bitcast<u32>(((((((((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var ztdbtc: u32 = (W + bitcast<u32>((((((((((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var zincflx: u32 = (W + bitcast<u32>(((((((((((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var zdbtc_nodel: u32 = (W + bitcast<u32>((((((((((((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((112i - 1i) + 1i))));
    var ztdbt_nodel: u32 = (W + bitcast<u32>(((((((((((((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((112i - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var ztdbtc_nodel: u32 = (W + bitcast<u32>((((((((((((((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((112i - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var zcd: u32 = (W + bitcast<u32>(((((((((((((((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((112i - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var zcu: u32 = (W + bitcast<u32>((((((((((((((((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((112i - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var zfd: u32 = (W + bitcast<u32>(((((((((((((((((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((112i - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    var zfu: u32 = (W + bitcast<u32>((((((((((((((((((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((112i - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i))));
    ib1 = 16i;
    ib2 = 29i;
    klev = (*C).nlayers;
    iw = 0i;
    repclc = 1e-12f;
    {
        jk = 1i;
        loop {
            if (!((jk <= (klev + 1i)))) { break; }
                mem_st(((*C).pbbcd + bitcast<u32>((jk - 1i))), bitcast<u32>(0.0f));
                mem_st(((*C).pbbcu + bitcast<u32>((jk - 1i))), bitcast<u32>(0.0f));
                mem_st(((*C).pbbfd + bitcast<u32>((jk - 1i))), bitcast<u32>(0.0f));
                mem_st(((*C).pbbfu + bitcast<u32>((jk - 1i))), bitcast<u32>(0.0f));
                mem_st(((*C).pbbcddir + bitcast<u32>((jk - 1i))), bitcast<u32>(0.0f));
                mem_st(((*C).pbbfddir + bitcast<u32>((jk - 1i))), bitcast<u32>(0.0f));
                mem_st(((*C).puvcd + bitcast<u32>((jk - 1i))), bitcast<u32>(0.0f));
                mem_st(((*C).puvfd + bitcast<u32>((jk - 1i))), bitcast<u32>(0.0f));
                mem_st(((*C).puvcddir + bitcast<u32>((jk - 1i))), bitcast<u32>(0.0f));
                mem_st(((*C).puvfddir + bitcast<u32>((jk - 1i))), bitcast<u32>(0.0f));
                mem_st(((*C).pnicd + bitcast<u32>((jk - 1i))), bitcast<u32>(0.0f));
                mem_st(((*C).pnifd + bitcast<u32>((jk - 1i))), bitcast<u32>(0.0f));
                mem_st(((*C).pnicddir + bitcast<u32>((jk - 1i))), bitcast<u32>(0.0f));
                mem_st(((*C).pnifddir + bitcast<u32>((jk - 1i))), bitcast<u32>(0.0f));
            continuing {
                jk = (jk + 1i);
            }
        }
    }
    f_rrsw_taumol(C, T);
    {
        jb = ib1;
        loop {
            if (!((jb <= ib2))) { break; }
                ibm = (jb - 15i);
                igt = K_RRSW_NGC[(ibm - 1i)];
                {
                    jg = 1i;
                    loop {
                        if (!((jg <= igt))) { break; }
                            iw = (iw + 1i);
                            var r0: f32 = opq((bitcast<f32>(mem_ld(((*C).adjflux + bitcast<u32>((jb - 1i)))))) * (bitcast<f32>(mem_ld(((*C).sfluxzen + bitcast<u32>((iw - 1i)))))));
                            var r1: f32 = opq((opq(r0)) * (opq((*C).cossza)));
                            mem_st((zincflx + bitcast<u32>((iw - 1i))), bitcast<u32>(r1));
                            mem_st((ztdbtc + bitcast<u32>(((1i) - 1i))), bitcast<u32>(1.0f));
                            mem_st((ztdbtc_nodel + bitcast<u32>(((1i) - 1i))), bitcast<u32>(1.0f));
                            mem_st((zdbtc + bitcast<u32>(((klev + 1i) - 1i))), bitcast<u32>(0.0f));
                            mem_st((ztrac + bitcast<u32>(((klev + 1i) - 1i))), bitcast<u32>(0.0f));
                            mem_st((ztradc + bitcast<u32>(((klev + 1i) - 1i))), bitcast<u32>(0.0f));
                            mem_st((zrefc + bitcast<u32>(((klev + 1i) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld(((*C).albdir + bitcast<u32>((ibm - 1i)))))));
                            mem_st((zrefdc + bitcast<u32>(((klev + 1i) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld(((*C).albdif + bitcast<u32>((ibm - 1i)))))));
                            mem_st((zrupc + bitcast<u32>(((klev + 1i) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld(((*C).albdir + bitcast<u32>((ibm - 1i)))))));
                            mem_st((zrupdc + bitcast<u32>(((klev + 1i) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld(((*C).albdif + bitcast<u32>((ibm - 1i)))))));
                            mem_st((ztdbt + bitcast<u32>(((1i) - 1i))), bitcast<u32>(1.0f));
                            mem_st((ztdbt_nodel + bitcast<u32>(((1i) - 1i))), bitcast<u32>(1.0f));
                            mem_st((zdbt + bitcast<u32>(((klev + 1i) - 1i))), bitcast<u32>(0.0f));
                            mem_st((ztra + bitcast<u32>(((klev + 1i) - 1i))), bitcast<u32>(0.0f));
                            mem_st((ztrad + bitcast<u32>(((klev + 1i) - 1i))), bitcast<u32>(0.0f));
                            mem_st((zref + bitcast<u32>(((klev + 1i) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld(((*C).albdir + bitcast<u32>((ibm - 1i)))))));
                            mem_st((zrefd + bitcast<u32>(((klev + 1i) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld(((*C).albdif + bitcast<u32>((ibm - 1i)))))));
                            mem_st((zrup + bitcast<u32>(((klev + 1i) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld(((*C).albdir + bitcast<u32>((ibm - 1i)))))));
                            mem_st((zrupd + bitcast<u32>(((klev + 1i) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld(((*C).albdif + bitcast<u32>((ibm - 1i)))))));
                            {
                                jk = 1i;
                                loop {
                                    if (!((jk <= klev))) { break; }
                                        ikl = ((klev + 1i) - jk);
                                        mem_st((lrtchkclr + bitcast<u32>((jk - 1i))), bitcast<u32>(1i));
                                        mem_st((lrtchkcld + bitcast<u32>((jk - 1i))), bitcast<u32>(0i));
                                        mem_st((lrtchkcld + bitcast<u32>((jk - 1i))), bitcast<u32>(i32(((bitcast<f32>(mem_ld(((*C).cldfmc + bitcast<u32>(((iw - 1i) + ((112i) * (ikl - 1i)))))))) > repclc))));
                                        var r2: f32 = opq((bitcast<f32>(mem_ld(((*C).taur + bitcast<u32>(((ikl - 1i) + (((*C).nlayers) * (iw - 1i)))))))) + (bitcast<f32>(mem_ld(((*C).taug + bitcast<u32>(((ikl - 1i) + (((*C).nlayers) * (iw - 1i)))))))));
                                        var r3: f32 = opq((opq(r2)) + (opq(0.0f)));
                                        mem_st((ztauc + bitcast<u32>((jk - 1i))), bitcast<u32>(r3));
                                        var r4: f32 = opq((bitcast<f32>(mem_ld(((*C).taur + bitcast<u32>(((ikl - 1i) + (((*C).nlayers) * (iw - 1i)))))))) + (opq(0.0f)));
                                        mem_st((zomcc + bitcast<u32>((jk - 1i))), bitcast<u32>(r4));
                                        var r5: f32 = opq((opq(0.0f)) * (opq(0.0f)));
                                        var r6: f32 = div_cr(r5, bitcast<f32>(mem_ld((zomcc + bitcast<u32>((jk - 1i))))));
                                        mem_st((zgcc + bitcast<u32>((jk - 1i))), bitcast<u32>(r6));
                                        var r7: f32 = div_cr(bitcast<f32>(mem_ld((zomcc + bitcast<u32>((jk - 1i))))), bitcast<f32>(mem_ld((ztauc + bitcast<u32>((jk - 1i))))));
                                        mem_st((zomcc + bitcast<u32>((jk - 1i))), bitcast<u32>(r7));
                                        var r8: f32 = opq((opq(1.0f)) - (bitcast<f32>(mem_ld(((*C).cldfmc + bitcast<u32>(((iw - 1i) + ((112i) * (ikl - 1i)))))))));
                                        zclear = r8;
                                        zcloud = bitcast<f32>(mem_ld(((*C).cldfmc + bitcast<u32>(((iw - 1i) + ((112i) * (ikl - 1i)))))));
                                        var r9: f32 = div_cr(bitcast<f32>(mem_ld((ztauc + bitcast<u32>((jk - 1i))))), (*C).cossza);
                                        ze1 = r9;
                                        if ((r9 <= 0.06f)) {
                                            var r10: f32 = opq((opq(1.0f)) - (opq(ze1)));
                                            var r11: f32 = opq((opq(0.5f)) * (opq(ze1)));
                                            var r13: f32 = opq(fma(opq(r11), opq(ze1), opq(r10)));
                                            zdbtmc = r13;
                                        } else {
                                            var r14: f32 = opq((opq(3.5971224f)) + (opq(ze1)));
                                            var r15: f32 = div_cr(ze1, r14);
                                            tblind = r15;
                                            var r17: f32 = opq(fma(opq(1e+04f), opq(r15), opq(0.5f)));
                                            var r18: i32 = i32(r17);
                                            itind = r18;
                                            zdbtmc = bitcast<f32>(mem_ld((T + bitcast<u32>((0i + (itind - 0i))))));
                                        }
                                        mem_st((zdbtc_nodel + bitcast<u32>((jk - 1i))), bitcast<u32>(zdbtmc));
                                        var r19: f32 = opq((bitcast<f32>(mem_ld((zdbtc_nodel + bitcast<u32>((jk - 1i)))))) * (bitcast<f32>(mem_ld((ztdbtc_nodel + bitcast<u32>((jk - 1i)))))));
                                        mem_st((ztdbtc_nodel + bitcast<u32>(((jk + 1i) - 1i))), bitcast<u32>(r19));
                                        var r20: f32 = opq((bitcast<f32>(mem_ld((ztauc + bitcast<u32>((jk - 1i)))))) + (bitcast<f32>(mem_ld(((*C).taormc + bitcast<u32>(((iw - 1i) + ((112i) * (ikl - 1i)))))))));
                                        tauorig = r20;
                                        var r21: f32 = div_cr(r20, (*C).cossza);
                                        ze1 = r21;
                                        if ((r21 <= 0.06f)) {
                                            var r22: f32 = opq((opq(1.0f)) - (opq(ze1)));
                                            var r23: f32 = opq((opq(0.5f)) * (opq(ze1)));
                                            var r25: f32 = opq(fma(opq(r23), opq(ze1), opq(r22)));
                                            zdbtmo = r25;
                                        } else {
                                            var r26: f32 = opq((opq(3.5971224f)) + (opq(ze1)));
                                            var r27: f32 = div_cr(ze1, r26);
                                            tblind = r27;
                                            var r29: f32 = opq(fma(opq(1e+04f), opq(r27), opq(0.5f)));
                                            var r30: i32 = i32(r29);
                                            itind = r30;
                                            zdbtmo = bitcast<f32>(mem_ld((T + bitcast<u32>((0i + (itind - 0i))))));
                                        }
                                        var r32: f32 = opq((opq(zcloud)) * (opq(zdbtmo)));
                                        var r33: f32 = opq(fma(opq(zclear), opq(zdbtmc), opq(r32)));
                                        mem_st((zdbt_nodel + bitcast<u32>((jk - 1i))), bitcast<u32>(r33));
                                        var r34: f32 = opq((bitcast<f32>(mem_ld((zdbt_nodel + bitcast<u32>((jk - 1i)))))) * (bitcast<f32>(mem_ld((ztdbt_nodel + bitcast<u32>((jk - 1i)))))));
                                        mem_st((ztdbt_nodel + bitcast<u32>(((jk + 1i) - 1i))), bitcast<u32>(r34));
                                        var r35: f32 = opq((bitcast<f32>(mem_ld((zgcc + bitcast<u32>((jk - 1i)))))) * (bitcast<f32>(mem_ld((zgcc + bitcast<u32>((jk - 1i)))))));
                                        zf = r35;
                                        var r37: f32 = opq(fma(opq(f_rr_neg(bitcast<f32>(mem_ld((zomcc + bitcast<u32>((jk - 1i))))), (*C).z0)), opq(r35), opq(1.0f)));
                                        var r38: f32 = opq((opq(r37)) * (bitcast<f32>(mem_ld((ztauc + bitcast<u32>((jk - 1i)))))));
                                        mem_st((ztauc + bitcast<u32>((jk - 1i))), bitcast<u32>(r38));
                                        var r39: f32 = opq(fma(opq(f_rr_neg(bitcast<f32>(mem_ld((zomcc + bitcast<u32>((jk - 1i))))), (*C).z0)), opq(r35), bitcast<f32>(mem_ld((zomcc + bitcast<u32>((jk - 1i)))))));
                                        var r40: f32 = div_cr(r39, r37);
                                        mem_st((zomcc + bitcast<u32>((jk - 1i))), bitcast<u32>(r40));
                                        var r41: f32 = opq((bitcast<f32>(mem_ld((zgcc + bitcast<u32>((jk - 1i)))))) - (opq(r35)));
                                        var r42: f32 = opq((opq(1.0f)) - (opq(r35)));
                                        var r43: f32 = div_cr(r41, r42);
                                        mem_st((zgcc + bitcast<u32>((jk - 1i))), bitcast<u32>(r43));
                                        var r44: f32 = opq((bitcast<f32>(mem_ld((ztauc + bitcast<u32>((jk - 1i)))))) + (bitcast<f32>(mem_ld(((*C).taucmc + bitcast<u32>(((iw - 1i) + ((112i) * (ikl - 1i)))))))));
                                        mem_st((ztauo + bitcast<u32>((jk - 1i))), bitcast<u32>(r44));
                                        var r45: f32 = opq((bitcast<f32>(mem_ld((ztauc + bitcast<u32>((jk - 1i)))))) * (bitcast<f32>(mem_ld((zomcc + bitcast<u32>((jk - 1i)))))));
                                        var r46: f32 = opq((bitcast<f32>(mem_ld(((*C).taucmc + bitcast<u32>(((iw - 1i) + ((112i) * (ikl - 1i)))))))) * (bitcast<f32>(mem_ld(((*C).ssacmc + bitcast<u32>(((iw - 1i) + ((112i) * (ikl - 1i)))))))));
                                        var r47: f32 = opq((opq(r45)) + (opq(r46)));
                                        mem_st((zomco + bitcast<u32>((jk - 1i))), bitcast<u32>(r47));
                                        var r49: f32 = opq((opq(r45)) * (bitcast<f32>(mem_ld((zgcc + bitcast<u32>((jk - 1i)))))));
                                        var r50: f32 = opq(fma(opq(r46), bitcast<f32>(mem_ld(((*C).asmcmc + bitcast<u32>(((iw - 1i) + ((112i) * (ikl - 1i))))))), opq(r49)));
                                        var r51: f32 = div_cr(r50, bitcast<f32>(mem_ld((zomco + bitcast<u32>((jk - 1i))))));
                                        mem_st((zgco + bitcast<u32>((jk - 1i))), bitcast<u32>(r51));
                                        var r52: f32 = div_cr(bitcast<f32>(mem_ld((zomco + bitcast<u32>((jk - 1i))))), bitcast<f32>(mem_ld((ztauo + bitcast<u32>((jk - 1i))))));
                                        mem_st((zomco + bitcast<u32>((jk - 1i))), bitcast<u32>(r52));
                                    continuing {
                                        jk = (jk + 1i);
                                    }
                                }
                            }
                            f_rrsw_reftra_sw(C, T, (W + bitcast<u32>(((((((((((((((((((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((112i - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)))), (WI + bitcast<u32>((((((*C).nlayers) - 1i) + 1i) + ((((*C).nlayers) - 1i) + 1i)))), lrtchkclr, zgcc, (*C).cossza, ztauc, zomcc, zrefc, zrefdc, ztrac, ztradc);
                            if (((*C).fail != 0i)) {
                                return;
                            }
                            f_rrsw_reftra_sw(C, T, (W + bitcast<u32>(((((((((((((((((((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((112i - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)))), (WI + bitcast<u32>((((((*C).nlayers) - 1i) + 1i) + ((((*C).nlayers) - 1i) + 1i)))), lrtchkcld, zgco, (*C).cossza, ztauo, zomco, zrefo, zrefdo, ztrao, ztrado);
                            if (((*C).fail != 0i)) {
                                return;
                            }
                            {
                                jk = 1i;
                                loop {
                                    if (!((jk <= klev))) { break; }
                                        ikl = ((klev + 1i) - jk);
                                        var r53: f32 = opq((opq(1.0f)) - (bitcast<f32>(mem_ld(((*C).cldfmc + bitcast<u32>(((iw - 1i) + ((112i) * (ikl - 1i)))))))));
                                        zclear = r53;
                                        zcloud = bitcast<f32>(mem_ld(((*C).cldfmc + bitcast<u32>(((iw - 1i) + ((112i) * (ikl - 1i)))))));
                                        var r55: f32 = opq((bitcast<f32>(mem_ld(((*C).cldfmc + bitcast<u32>(((iw - 1i) + ((112i) * (ikl - 1i)))))))) * (bitcast<f32>(mem_ld((zrefo + bitcast<u32>((jk - 1i)))))));
                                        var r56: f32 = opq(fma(opq(r53), bitcast<f32>(mem_ld((zrefc + bitcast<u32>((jk - 1i))))), opq(r55)));
                                        mem_st((zref + bitcast<u32>((jk - 1i))), bitcast<u32>(r56));
                                        var r58: f32 = opq((bitcast<f32>(mem_ld(((*C).cldfmc + bitcast<u32>(((iw - 1i) + ((112i) * (ikl - 1i)))))))) * (bitcast<f32>(mem_ld((zrefdo + bitcast<u32>((jk - 1i)))))));
                                        var r59: f32 = opq(fma(opq(r53), bitcast<f32>(mem_ld((zrefdc + bitcast<u32>((jk - 1i))))), opq(r58)));
                                        mem_st((zrefd + bitcast<u32>((jk - 1i))), bitcast<u32>(r59));
                                        var r61: f32 = opq((bitcast<f32>(mem_ld(((*C).cldfmc + bitcast<u32>(((iw - 1i) + ((112i) * (ikl - 1i)))))))) * (bitcast<f32>(mem_ld((ztrao + bitcast<u32>((jk - 1i)))))));
                                        var r62: f32 = opq(fma(opq(r53), bitcast<f32>(mem_ld((ztrac + bitcast<u32>((jk - 1i))))), opq(r61)));
                                        mem_st((ztra + bitcast<u32>((jk - 1i))), bitcast<u32>(r62));
                                        var r64: f32 = opq((bitcast<f32>(mem_ld(((*C).cldfmc + bitcast<u32>(((iw - 1i) + ((112i) * (ikl - 1i)))))))) * (bitcast<f32>(mem_ld((ztrado + bitcast<u32>((jk - 1i)))))));
                                        var r65: f32 = opq(fma(opq(r53), bitcast<f32>(mem_ld((ztradc + bitcast<u32>((jk - 1i))))), opq(r64)));
                                        mem_st((ztrad + bitcast<u32>((jk - 1i))), bitcast<u32>(r65));
                                        var r66: f32 = div_cr(bitcast<f32>(mem_ld((ztauc + bitcast<u32>((jk - 1i))))), (*C).cossza);
                                        ze1 = r66;
                                        if ((r66 <= 0.06f)) {
                                            var r67: f32 = opq((opq(1.0f)) - (opq(ze1)));
                                            var r68: f32 = opq((opq(0.5f)) * (opq(ze1)));
                                            var r70: f32 = opq(fma(opq(r68), opq(ze1), opq(r67)));
                                            zdbtmc = r70;
                                        } else {
                                            var r71: f32 = opq((opq(3.5971224f)) + (opq(ze1)));
                                            var r72: f32 = div_cr(ze1, r71);
                                            tblind = r72;
                                            var r74: f32 = opq(fma(opq(1e+04f), opq(r72), opq(0.5f)));
                                            var r75: i32 = i32(r74);
                                            itind = r75;
                                            zdbtmc = bitcast<f32>(mem_ld((T + bitcast<u32>((0i + (itind - 0i))))));
                                        }
                                        mem_st((zdbtc + bitcast<u32>((jk - 1i))), bitcast<u32>(zdbtmc));
                                        var r76: f32 = opq((bitcast<f32>(mem_ld((zdbtc + bitcast<u32>((jk - 1i)))))) * (bitcast<f32>(mem_ld((ztdbtc + bitcast<u32>((jk - 1i)))))));
                                        mem_st((ztdbtc + bitcast<u32>(((jk + 1i) - 1i))), bitcast<u32>(r76));
                                        var r77: f32 = div_cr(bitcast<f32>(mem_ld((ztauo + bitcast<u32>((jk - 1i))))), (*C).cossza);
                                        ze1 = r77;
                                        if ((r77 <= 0.06f)) {
                                            var r78: f32 = opq((opq(1.0f)) - (opq(ze1)));
                                            var r79: f32 = opq((opq(0.5f)) * (opq(ze1)));
                                            var r81: f32 = opq(fma(opq(r79), opq(ze1), opq(r78)));
                                            zdbtmo = r81;
                                        } else {
                                            var r82: f32 = opq((opq(3.5971224f)) + (opq(ze1)));
                                            var r83: f32 = div_cr(ze1, r82);
                                            tblind = r83;
                                            var r85: f32 = opq(fma(opq(1e+04f), opq(r83), opq(0.5f)));
                                            var r86: i32 = i32(r85);
                                            itind = r86;
                                            zdbtmo = bitcast<f32>(mem_ld((T + bitcast<u32>((0i + (itind - 0i))))));
                                        }
                                        var r88: f32 = opq((opq(zcloud)) * (opq(zdbtmo)));
                                        var r89: f32 = opq(fma(opq(zclear), opq(zdbtmc), opq(r88)));
                                        mem_st((zdbt + bitcast<u32>((jk - 1i))), bitcast<u32>(r89));
                                        var r90: f32 = opq((bitcast<f32>(mem_ld((zdbt + bitcast<u32>((jk - 1i)))))) * (bitcast<f32>(mem_ld((ztdbt + bitcast<u32>((jk - 1i)))))));
                                        mem_st((ztdbt + bitcast<u32>(((jk + 1i) - 1i))), bitcast<u32>(r90));
                                    continuing {
                                        jk = (jk + 1i);
                                    }
                                }
                            }
                            f_rrsw_vrtqdr_sw(C, T, (W + bitcast<u32>(((((((((((((((((((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((112i - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)))), (WI + bitcast<u32>((((((*C).nlayers) - 1i) + 1i) + ((((*C).nlayers) - 1i) + 1i)))), klev, iw, zrefc, zrefdc, ztrac, ztradc, zdbtc, zrdndc, zrupc, zrupdc, ztdbtc, zcd, zcu);
                            if (((*C).fail != 0i)) {
                                return;
                            }
                            f_rrsw_vrtqdr_sw(C, T, (W + bitcast<u32>(((((((((((((((((((((((((((((((((((((((((((((((((*C).nlayers) + 1i) - 1i) + 1i) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + ((((*C).nlayers) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + ((112i - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)) + (((((*C).nlayers) + 1i) - 1i) + 1i)))), (WI + bitcast<u32>((((((*C).nlayers) - 1i) + 1i) + ((((*C).nlayers) - 1i) + 1i)))), klev, iw, zref, zrefd, ztra, ztrad, zdbt, zrdnd, zrup, zrupd, ztdbt, zfd, zfu);
                            if (((*C).fail != 0i)) {
                                return;
                            }
                            {
                                jk = 1i;
                                loop {
                                    if (!((jk <= (klev + 1i)))) { break; }
                                        ikl = ((klev + 2i) - jk);
                                        var r92: f32 = opq(fma(bitcast<f32>(mem_ld((zincflx + bitcast<u32>((iw - 1i))))), bitcast<f32>(mem_ld((zfu + bitcast<u32>((jk - 1i))))), bitcast<f32>(mem_ld(((*C).pbbfu + bitcast<u32>((ikl - 1i)))))));
                                        mem_st(((*C).pbbfu + bitcast<u32>((ikl - 1i))), bitcast<u32>(r92));
                                        var r93: f32 = opq((bitcast<f32>(mem_ld((zincflx + bitcast<u32>((iw - 1i)))))) * (bitcast<f32>(mem_ld((zfd + bitcast<u32>((jk - 1i)))))));
                                        var r94: f32 = opq((bitcast<f32>(mem_ld(((*C).pbbfd + bitcast<u32>((ikl - 1i)))))) + (opq(r93)));
                                        mem_st(((*C).pbbfd + bitcast<u32>((ikl - 1i))), bitcast<u32>(r94));
                                        var r96: f32 = opq(fma(bitcast<f32>(mem_ld((zincflx + bitcast<u32>((iw - 1i))))), bitcast<f32>(mem_ld((zcu + bitcast<u32>((jk - 1i))))), bitcast<f32>(mem_ld(((*C).pbbcu + bitcast<u32>((ikl - 1i)))))));
                                        mem_st(((*C).pbbcu + bitcast<u32>((ikl - 1i))), bitcast<u32>(r96));
                                        var r97: f32 = opq((bitcast<f32>(mem_ld((zincflx + bitcast<u32>((iw - 1i)))))) * (bitcast<f32>(mem_ld((zcd + bitcast<u32>((jk - 1i)))))));
                                        var r98: f32 = opq((bitcast<f32>(mem_ld(((*C).pbbcd + bitcast<u32>((ikl - 1i)))))) + (opq(r97)));
                                        mem_st(((*C).pbbcd + bitcast<u32>((ikl - 1i))), bitcast<u32>(r98));
                                        var r99: f32 = opq((bitcast<f32>(mem_ld((zincflx + bitcast<u32>((iw - 1i)))))) * (bitcast<f32>(mem_ld((ztdbt_nodel + bitcast<u32>((jk - 1i)))))));
                                        var r100: f32 = opq((bitcast<f32>(mem_ld(((*C).pbbfddir + bitcast<u32>((ikl - 1i)))))) + (opq(r99)));
                                        mem_st(((*C).pbbfddir + bitcast<u32>((ikl - 1i))), bitcast<u32>(r100));
                                        var r101: f32 = opq((bitcast<f32>(mem_ld((zincflx + bitcast<u32>((iw - 1i)))))) * (bitcast<f32>(mem_ld((ztdbtc_nodel + bitcast<u32>((jk - 1i)))))));
                                        var r102: f32 = opq((bitcast<f32>(mem_ld(((*C).pbbcddir + bitcast<u32>((ikl - 1i)))))) + (opq(r101)));
                                        mem_st(((*C).pbbcddir + bitcast<u32>((ikl - 1i))), bitcast<u32>(r102));
                                        if (((ibm >= 10i) && (ibm <= 13i))) {
                                            var r103: f32 = opq((bitcast<f32>(mem_ld(((*C).puvcd + bitcast<u32>((ikl - 1i)))))) + (opq(r97)));
                                            mem_st(((*C).puvcd + bitcast<u32>((ikl - 1i))), bitcast<u32>(r103));
                                            var r104: f32 = opq((bitcast<f32>(mem_ld(((*C).puvfd + bitcast<u32>((ikl - 1i)))))) + (opq(r93)));
                                            mem_st(((*C).puvfd + bitcast<u32>((ikl - 1i))), bitcast<u32>(r104));
                                            var r105: f32 = opq((bitcast<f32>(mem_ld(((*C).puvcddir + bitcast<u32>((ikl - 1i)))))) + (opq(r101)));
                                            mem_st(((*C).puvcddir + bitcast<u32>((ikl - 1i))), bitcast<u32>(r105));
                                            var r106: f32 = opq((bitcast<f32>(mem_ld(((*C).puvfddir + bitcast<u32>((ikl - 1i)))))) + (opq(r99)));
                                            mem_st(((*C).puvfddir + bitcast<u32>((ikl - 1i))), bitcast<u32>(r106));
                                        } else {
                                            if (((ibm == 14i) || (ibm <= 9i))) {
                                                var r107: f32 = opq((bitcast<f32>(mem_ld(((*C).pnicd + bitcast<u32>((ikl - 1i)))))) + (opq(r97)));
                                                mem_st(((*C).pnicd + bitcast<u32>((ikl - 1i))), bitcast<u32>(r107));
                                                var r108: f32 = opq((bitcast<f32>(mem_ld(((*C).pnifd + bitcast<u32>((ikl - 1i)))))) + (opq(r93)));
                                                mem_st(((*C).pnifd + bitcast<u32>((ikl - 1i))), bitcast<u32>(r108));
                                                var r109: f32 = opq((bitcast<f32>(mem_ld(((*C).pnicddir + bitcast<u32>((ikl - 1i)))))) + (opq(r101)));
                                                mem_st(((*C).pnicddir + bitcast<u32>((ikl - 1i))), bitcast<u32>(r109));
                                                var r110: f32 = opq((bitcast<f32>(mem_ld(((*C).pnifddir + bitcast<u32>((ikl - 1i)))))) + (opq(r99)));
                                                mem_st(((*C).pnifddir + bitcast<u32>((ikl - 1i))), bitcast<u32>(r110));
                                            }
                                        }
                                    continuing {
                                        jk = (jk + 1i);
                                    }
                                }
                            }
                        continuing {
                            jg = (jg + 1i);
                        }
                    }
                }
            continuing {
                jb = (jb + 1i);
            }
        }
    }
}

fn f_rrsw_taumol(C: ptr<function, S_RRSWColumn>, T_in: u32) {
    var T: u32 = T_in;
    f_rrsw_taumol16(C, T);
    f_rrsw_taumol17(C, T);
    f_rrsw_taumol18(C, T);
    f_rrsw_taumol19(C, T);
    f_rrsw_taumol20(C, T);
    f_rrsw_taumol21(C, T);
    f_rrsw_taumol22(C, T);
    f_rrsw_taumol23(C, T);
    f_rrsw_taumol24(C, T);
    f_rrsw_taumol25(C, T);
    f_rrsw_taumol26(C, T);
    f_rrsw_taumol27(C, T);
    f_rrsw_taumol28(C, T);
    f_rrsw_taumol29(C, T);
}

fn f_rrsw_taumol16(C: ptr<function, S_RRSWColumn>, T_in: u32) {
    var T: u32 = T_in;
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var js: i32 = 0i;
    var lay: i32 = 0i;
    var laysolfr: i32 = 0i;
    var speccomb: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var tauray: f32 = f32(0i);
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                var r1: f32 = opq(fma(bitcast<f32>(mem_ld((T + bitcast<u32>(20137i)))), bitcast<f32>(mem_ld(((*C).colch4 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb = r1;
                var r2: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r1);
                specparm = r2;
                if ((r2 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r3: f32 = opq((opq(8.0f)) * (opq(specparm)));
                specmult = r3;
                js = (1i + (i32(r3)));
                var r4: f32 = opq((r3 % 1.0f));
                fs = r4;
                var r5: f32 = opq((opq(1.0f)) - (opq(r4)));
                var r6: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac000 = r6;
                var r7: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac010 = r7;
                var r8: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac100 = r8;
                var r9: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac110 = r9;
                var r10: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac001 = r10;
                var r11: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac011 = r11;
                var r12: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac101 = r12;
                var r13: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac111 = r13;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((16i) - 16i)])) + js);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((16i) - 16i)])) + js);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                var r14: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(20136i))))));
                tauray = r14;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 6i))) { break; }
                            var r16: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((15131i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                            var r17: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((15131i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r16)));
                            var r19: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((15131i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r17)));
                            var r21: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((15131i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r19)));
                            var r23: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((15131i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r21)));
                            var r25: f32 = opq(fma(opq(fac101), bitcast<f32>(mem_ld((T + bitcast<u32>(((15131i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r23)));
                            var r27: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((15131i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r25)));
                            var r29: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((15131i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r27)));
                            var r31: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((20051i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((20051i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r33: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r31), bitcast<f32>(mem_ld((T + bitcast<u32>(((20051i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r35: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((20111i + ((indf + 1i) - 1i)) + ((ig - 1i) * 3i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((20111i + (indf - 1i)) + ((ig - 1i) * 3i))))))));
                            var r37: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r35), bitcast<f32>(mem_ld((T + bitcast<u32>(((20111i + (indf - 1i)) + ((ig - 1i) * 3i))))))));
                            var r38: f32 = opq((bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i)))))) * (opq(r37)));
                            var r39: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i))))), opq(r33), opq(r38)));
                            var r40: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (opq(r39)));
                            var r41: f32 = opq(fma(opq(speccomb), opq(r29), opq(r40)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * (ig - 1i))))), bitcast<u32>(r41));
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * (ig - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    laysolfr = (*C).nlayers;
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                if ((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>(((lay - 1i) - 1i)))))) < (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(20135i))))))) && ((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) >= (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(20135i))))))))) {
                    laysolfr = lay;
                }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((16i) - 16i)])) + 1i);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((16i) - 16i)])) + 1i);
                var r42: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(20136i))))));
                tauray = r42;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 6i))) { break; }
                            var r44: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((18641i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 235i))))))));
                            var r45: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((18641i + (ind0 - 1i)) + ((ig - 1i) * 235i)))))), opq(r44)));
                            var r47: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((18641i + (ind1 - 1i)) + ((ig - 1i) * 235i)))))), opq(r45)));
                            var r49: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((18641i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 235i)))))), opq(r47)));
                            var r50: f32 = opq((bitcast<f32>(mem_ld(((*C).colch4 + bitcast<u32>((lay - 1i)))))) * (opq(r49)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * (ig - 1i))))), bitcast<u32>(r50));
                            if ((lay == laysolfr)) {
                                mem_st(((*C).sfluxzen + bitcast<u32>((ig - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((20129i + (ig - 1i))))))));
                            }
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * (ig - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrsw_taumol17(C: ptr<function, S_RRSWColumn>, T_in: u32) {
    var T: u32 = T_in;
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var js: i32 = 0i;
    var lay: i32 = 0i;
    var laysolfr: i32 = 0i;
    var speccomb: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var tauray: f32 = f32(0i);
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                var r1: f32 = opq(fma(bitcast<f32>(mem_ld((T + bitcast<u32>(41488i)))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb = r1;
                var r2: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r1);
                specparm = r2;
                if ((r2 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r3: f32 = opq((opq(8.0f)) * (opq(specparm)));
                specmult = r3;
                js = (1i + (i32(r3)));
                var r4: f32 = opq((r3 % 1.0f));
                fs = r4;
                var r5: f32 = opq((opq(1.0f)) - (opq(r4)));
                var r6: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac000 = r6;
                var r7: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac010 = r7;
                var r8: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac100 = r8;
                var r9: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac110 = r9;
                var r10: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac001 = r10;
                var r11: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac011 = r11;
                var r12: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac101 = r12;
                var r13: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac111 = r13;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((17i) - 16i)])) + js);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((17i) - 16i)])) + js);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                var r14: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(41487i))))));
                tauray = r14;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 12i))) { break; }
                            var r16: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((20138i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                            var r17: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((20138i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r16)));
                            var r19: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((20138i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r17)));
                            var r21: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((20138i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r19)));
                            var r23: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((20138i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r21)));
                            var r25: f32 = opq(fma(opq(fac101), bitcast<f32>(mem_ld((T + bitcast<u32>(((20138i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r23)));
                            var r27: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((20138i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r25)));
                            var r29: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((20138i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r27)));
                            var r31: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((41258i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((41258i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r33: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r31), bitcast<f32>(mem_ld((T + bitcast<u32>(((41258i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r35: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((41378i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((41378i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r37: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r35), bitcast<f32>(mem_ld((T + bitcast<u32>(((41378i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r38: f32 = opq((bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i)))))) * (opq(r37)));
                            var r39: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i))))), opq(r33), opq(r38)));
                            var r40: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (opq(r39)));
                            var r41: f32 = opq(fma(opq(speccomb), opq(r29), opq(r40)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((6i + ig) - 1i))))), bitcast<u32>(r41));
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((6i + ig) - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    laysolfr = (*C).nlayers;
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                if ((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>(((lay - 1i) - 1i)))))) < (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(41486i))))))) && ((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) >= (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(41486i))))))))) {
                    laysolfr = lay;
                }
                var r43: f32 = opq(fma(bitcast<f32>(mem_ld((T + bitcast<u32>(41488i)))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb = r43;
                var r44: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r43);
                specparm = r44;
                if ((r44 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r45: f32 = opq((opq(4.0f)) * (opq(specparm)));
                specmult = r45;
                js = (1i + (i32(r45)));
                var r46: f32 = opq((r45 % 1.0f));
                fs = r46;
                var r47: f32 = opq((opq(1.0f)) - (opq(r46)));
                var r48: f32 = opq((opq(r47)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac000 = r48;
                var r49: f32 = opq((opq(r47)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac010 = r49;
                var r50: f32 = opq((opq(r46)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac100 = r50;
                var r51: f32 = opq((opq(r46)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac110 = r51;
                var r52: f32 = opq((opq(r47)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac001 = r52;
                var r53: f32 = opq((opq(r47)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac011 = r53;
                var r54: f32 = opq((opq(r46)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac101 = r54;
                var r55: f32 = opq((opq(r46)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac111 = r55;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((17i) - 16i)])) + js);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((17i) - 16i)])) + js);
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                var r56: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(41487i))))));
                tauray = r56;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 12i))) { break; }
                            var r58: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((27158i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 1175i))))))));
                            var r59: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((27158i + (ind0 - 1i)) + ((ig - 1i) * 1175i)))))), opq(r58)));
                            var r61: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((27158i + ((ind0 + 5i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r59)));
                            var r63: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((27158i + ((ind0 + 6i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r61)));
                            var r65: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((27158i + (ind1 - 1i)) + ((ig - 1i) * 1175i)))))), opq(r63)));
                            var r67: f32 = opq(fma(opq(fac101), bitcast<f32>(mem_ld((T + bitcast<u32>(((27158i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r65)));
                            var r69: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((27158i + ((ind1 + 5i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r67)));
                            var r71: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((27158i + ((ind1 + 6i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r69)));
                            var r73: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i)))))));
                            var r74: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((41378i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((41378i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r76: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r74), bitcast<f32>(mem_ld((T + bitcast<u32>(((41378i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r77: f32 = opq((opq(r73)) * (opq(r76)));
                            var r78: f32 = opq(fma(opq(speccomb), opq(r71), opq(r77)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((6i + ig) - 1i))))), bitcast<u32>(r78));
                            if ((lay == laysolfr)) {
                                var r79: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((41426i + (ig - 1i)) + (((js + 1i) - 1i) * 12i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((41426i + (ig - 1i)) + ((js - 1i) * 12i))))))));
                                var r81: f32 = opq(fma(opq(fs), opq(r79), bitcast<f32>(mem_ld((T + bitcast<u32>(((41426i + (ig - 1i)) + ((js - 1i) * 12i))))))));
                                mem_st(((*C).sfluxzen + bitcast<u32>(((6i + ig) - 1i))), bitcast<u32>(r81));
                            }
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((6i + ig) - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrsw_taumol18(C: ptr<function, S_RRSWColumn>, T_in: u32) {
    var T: u32 = T_in;
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var js: i32 = 0i;
    var lay: i32 = 0i;
    var laysolfr: i32 = 0i;
    var speccomb: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var tauray: f32 = f32(0i);
    laysolfr = (*C).laytrop;
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                if ((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) < (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(48225i))))))) && ((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>(((lay + 1i) - 1i)))))) >= (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(48225i))))))))) {
                    laysolfr = min((lay + 1i), (*C).laytrop);
                }
                var r1: f32 = opq(fma(bitcast<f32>(mem_ld((T + bitcast<u32>(48227i)))), bitcast<f32>(mem_ld(((*C).colch4 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb = r1;
                var r2: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r1);
                specparm = r2;
                if ((r2 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r3: f32 = opq((opq(8.0f)) * (opq(specparm)));
                specmult = r3;
                js = (1i + (i32(r3)));
                var r4: f32 = opq((r3 % 1.0f));
                fs = r4;
                var r5: f32 = opq((opq(1.0f)) - (opq(r4)));
                var r6: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac000 = r6;
                var r7: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac010 = r7;
                var r8: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac100 = r8;
                var r9: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac110 = r9;
                var r10: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac001 = r10;
                var r11: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac011 = r11;
                var r12: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac101 = r12;
                var r13: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac111 = r13;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((18i) - 16i)])) + js);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((18i) - 16i)])) + js);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                var r14: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(48226i))))));
                tauray = r14;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 8i))) { break; }
                            var r16: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((41489i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                            var r17: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((41489i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r16)));
                            var r19: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((41489i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r17)));
                            var r21: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((41489i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r19)));
                            var r23: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((41489i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r21)));
                            var r25: f32 = opq(fma(opq(fac101), bitcast<f32>(mem_ld((T + bitcast<u32>(((41489i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r23)));
                            var r27: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((41489i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r25)));
                            var r29: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((41489i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r27)));
                            var r31: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((48049i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((48049i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r33: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r31), bitcast<f32>(mem_ld((T + bitcast<u32>(((48049i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r35: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((48129i + ((indf + 1i) - 1i)) + ((ig - 1i) * 3i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((48129i + (indf - 1i)) + ((ig - 1i) * 3i))))))));
                            var r37: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r35), bitcast<f32>(mem_ld((T + bitcast<u32>(((48129i + (indf - 1i)) + ((ig - 1i) * 3i))))))));
                            var r38: f32 = opq((bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i)))))) * (opq(r37)));
                            var r39: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i))))), opq(r33), opq(r38)));
                            var r40: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (opq(r39)));
                            var r41: f32 = opq(fma(opq(speccomb), opq(r29), opq(r40)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((18i + ig) - 1i))))), bitcast<u32>(r41));
                            if ((lay == laysolfr)) {
                                var r42: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((48153i + (ig - 1i)) + (((js + 1i) - 1i) * 8i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((48153i + (ig - 1i)) + ((js - 1i) * 8i))))))));
                                var r44: f32 = opq(fma(opq(fs), opq(r42), bitcast<f32>(mem_ld((T + bitcast<u32>(((48153i + (ig - 1i)) + ((js - 1i) * 8i))))))));
                                mem_st(((*C).sfluxzen + bitcast<u32>(((18i + ig) - 1i))), bitcast<u32>(r44));
                            }
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((18i + ig) - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((18i) - 16i)])) + 1i);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((18i) - 16i)])) + 1i);
                var r45: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(48226i))))));
                tauray = r45;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 8i))) { break; }
                            var r47: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((46169i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 235i))))))));
                            var r48: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((46169i + (ind0 - 1i)) + ((ig - 1i) * 235i)))))), opq(r47)));
                            var r50: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((46169i + (ind1 - 1i)) + ((ig - 1i) * 235i)))))), opq(r48)));
                            var r52: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((46169i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 235i)))))), opq(r50)));
                            var r53: f32 = opq((bitcast<f32>(mem_ld(((*C).colch4 + bitcast<u32>((lay - 1i)))))) * (opq(r52)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((18i + ig) - 1i))))), bitcast<u32>(r53));
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((18i + ig) - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrsw_taumol19(C: ptr<function, S_RRSWColumn>, T_in: u32) {
    var T: u32 = T_in;
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var js: i32 = 0i;
    var lay: i32 = 0i;
    var laysolfr: i32 = 0i;
    var speccomb: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var tauray: f32 = f32(0i);
    laysolfr = (*C).laytrop;
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                if ((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) < (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(54964i))))))) && ((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>(((lay + 1i) - 1i)))))) >= (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(54964i))))))))) {
                    laysolfr = min((lay + 1i), (*C).laytrop);
                }
                var r1: f32 = opq(fma(bitcast<f32>(mem_ld((T + bitcast<u32>(54966i)))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb = r1;
                var r2: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r1);
                specparm = r2;
                if ((r2 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r3: f32 = opq((opq(8.0f)) * (opq(specparm)));
                specmult = r3;
                js = (1i + (i32(r3)));
                var r4: f32 = opq((r3 % 1.0f));
                fs = r4;
                var r5: f32 = opq((opq(1.0f)) - (opq(r4)));
                var r6: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac000 = r6;
                var r7: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac010 = r7;
                var r8: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac100 = r8;
                var r9: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac110 = r9;
                var r10: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac001 = r10;
                var r11: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac011 = r11;
                var r12: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac101 = r12;
                var r13: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac111 = r13;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((19i) - 16i)])) + js);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((19i) - 16i)])) + js);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                var r14: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(54965i))))));
                tauray = r14;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 8i))) { break; }
                            var r16: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((48228i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                            var r17: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((48228i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r16)));
                            var r19: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((48228i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r17)));
                            var r21: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((48228i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r19)));
                            var r23: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((48228i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r21)));
                            var r25: f32 = opq(fma(opq(fac101), bitcast<f32>(mem_ld((T + bitcast<u32>(((48228i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r23)));
                            var r27: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((48228i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r25)));
                            var r29: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((48228i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r27)));
                            var r31: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((54788i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((54788i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r33: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r31), bitcast<f32>(mem_ld((T + bitcast<u32>(((54788i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r35: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((54868i + ((indf + 1i) - 1i)) + ((ig - 1i) * 3i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((54868i + (indf - 1i)) + ((ig - 1i) * 3i))))))));
                            var r37: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r35), bitcast<f32>(mem_ld((T + bitcast<u32>(((54868i + (indf - 1i)) + ((ig - 1i) * 3i))))))));
                            var r38: f32 = opq((bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i)))))) * (opq(r37)));
                            var r39: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i))))), opq(r33), opq(r38)));
                            var r40: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (opq(r39)));
                            var r41: f32 = opq(fma(opq(speccomb), opq(r29), opq(r40)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((26i + ig) - 1i))))), bitcast<u32>(r41));
                            if ((lay == laysolfr)) {
                                var r42: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((54892i + (ig - 1i)) + (((js + 1i) - 1i) * 8i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((54892i + (ig - 1i)) + ((js - 1i) * 8i))))))));
                                var r44: f32 = opq(fma(opq(fs), opq(r42), bitcast<f32>(mem_ld((T + bitcast<u32>(((54892i + (ig - 1i)) + ((js - 1i) * 8i))))))));
                                mem_st(((*C).sfluxzen + bitcast<u32>(((26i + ig) - 1i))), bitcast<u32>(r44));
                            }
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((26i + ig) - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((19i) - 16i)])) + 1i);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((19i) - 16i)])) + 1i);
                var r45: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(54965i))))));
                tauray = r45;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 8i))) { break; }
                            var r47: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((52908i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 235i))))))));
                            var r48: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((52908i + (ind0 - 1i)) + ((ig - 1i) * 235i)))))), opq(r47)));
                            var r50: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((52908i + (ind1 - 1i)) + ((ig - 1i) * 235i)))))), opq(r48)));
                            var r52: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((52908i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 235i)))))), opq(r50)));
                            var r53: f32 = opq((bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i)))))) * (opq(r52)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((26i + ig) - 1i))))), bitcast<u32>(r53));
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((26i + ig) - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrsw_taumol20(C: ptr<function, S_RRSWColumn>, T_in: u32) {
    var T: u32 = T_in;
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var js: i32 = 0i;
    var lay: i32 = 0i;
    var laysolfr: i32 = 0i;
    var speccomb: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var tauray: f32 = f32(0i);
    laysolfr = (*C).laytrop;
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                if ((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) < (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(58127i))))))) && ((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>(((lay + 1i) - 1i)))))) >= (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(58127i))))))))) {
                    laysolfr = min((lay + 1i), (*C).laytrop);
                }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((20i) - 16i)])) + 1i);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((20i) - 16i)])) + 1i);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                var r0: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(58128i))))));
                tauray = r0;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 10i))) { break; }
                            var r2: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((54967i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 65i))))))));
                            var r3: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((54967i + (ind0 - 1i)) + ((ig - 1i) * 65i)))))), opq(r2)));
                            var r5: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((54967i + (ind1 - 1i)) + ((ig - 1i) * 65i)))))), opq(r3)));
                            var r7: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((54967i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 65i)))))), opq(r5)));
                            var r8: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((57967i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((57967i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r10: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r8), bitcast<f32>(mem_ld((T + bitcast<u32>(((57967i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r12: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i))))), opq(r10), opq(r7)));
                            var r13: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((58067i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((58067i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r15: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r13), bitcast<f32>(mem_ld((T + bitcast<u32>(((58067i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r17: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i))))), opq(r15), opq(r12)));
                            var r19: f32 = opq((bitcast<f32>(mem_ld(((*C).colch4 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>((58117i + (ig - 1i))))))));
                            var r20: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), opq(r17), opq(r19)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((34i + ig) - 1i))))), bitcast<u32>(r20));
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((34i + ig) - 1i))))), bitcast<u32>(tauray));
                            if ((lay == laysolfr)) {
                                mem_st(((*C).sfluxzen + bitcast<u32>(((34i + ig) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((58107i + (ig - 1i))))))));
                            }
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((20i) - 16i)])) + 1i);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((20i) - 16i)])) + 1i);
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                var r21: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(58128i))))));
                tauray = r21;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 10i))) { break; }
                            var r23: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((55617i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 235i))))))));
                            var r24: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((55617i + (ind0 - 1i)) + ((ig - 1i) * 235i)))))), opq(r23)));
                            var r26: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((55617i + (ind1 - 1i)) + ((ig - 1i) * 235i)))))), opq(r24)));
                            var r28: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((55617i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 235i)))))), opq(r26)));
                            var r29: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((58067i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((58067i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r31: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r29), bitcast<f32>(mem_ld((T + bitcast<u32>(((58067i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r33: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i))))), opq(r31), opq(r28)));
                            var r35: f32 = opq((bitcast<f32>(mem_ld(((*C).colch4 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>((58117i + (ig - 1i))))))));
                            var r36: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), opq(r33), opq(r35)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((34i + ig) - 1i))))), bitcast<u32>(r36));
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((34i + ig) - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrsw_taumol21(C: ptr<function, S_RRSWColumn>, T_in: u32) {
    var T: u32 = T_in;
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var js: i32 = 0i;
    var lay: i32 = 0i;
    var laysolfr: i32 = 0i;
    var speccomb: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var tauray: f32 = f32(0i);
    laysolfr = (*C).laytrop;
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                if ((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) < (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(75959i))))))) && ((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>(((lay + 1i) - 1i)))))) >= (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(75959i))))))))) {
                    laysolfr = min((lay + 1i), (*C).laytrop);
                }
                var r1: f32 = opq(fma(bitcast<f32>(mem_ld((T + bitcast<u32>(75961i)))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb = r1;
                var r2: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r1);
                specparm = r2;
                if ((r2 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r3: f32 = opq((opq(8.0f)) * (opq(specparm)));
                specmult = r3;
                js = (1i + (i32(r3)));
                var r4: f32 = opq((r3 % 1.0f));
                fs = r4;
                var r5: f32 = opq((opq(1.0f)) - (opq(r4)));
                var r6: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac000 = r6;
                var r7: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac010 = r7;
                var r8: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac100 = r8;
                var r9: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac110 = r9;
                var r10: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac001 = r10;
                var r11: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac011 = r11;
                var r12: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac101 = r12;
                var r13: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac111 = r13;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((21i) - 16i)])) + js);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((21i) - 16i)])) + js);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                var r14: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(75960i))))));
                tauray = r14;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 10i))) { break; }
                            var r16: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((58129i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                            var r17: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((58129i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r16)));
                            var r19: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((58129i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r17)));
                            var r21: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((58129i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r19)));
                            var r23: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((58129i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r21)));
                            var r25: f32 = opq(fma(opq(fac101), bitcast<f32>(mem_ld((T + bitcast<u32>(((58129i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r23)));
                            var r27: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((58129i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r25)));
                            var r29: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((58129i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r27)));
                            var r31: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((75729i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((75729i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r33: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r31), bitcast<f32>(mem_ld((T + bitcast<u32>(((75729i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r35: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((75829i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((75829i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r37: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r35), bitcast<f32>(mem_ld((T + bitcast<u32>(((75829i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r38: f32 = opq((bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i)))))) * (opq(r37)));
                            var r39: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i))))), opq(r33), opq(r38)));
                            var r40: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (opq(r39)));
                            var r41: f32 = opq(fma(opq(speccomb), opq(r29), opq(r40)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((44i + ig) - 1i))))), bitcast<u32>(r41));
                            if ((lay == laysolfr)) {
                                var r42: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((75869i + (ig - 1i)) + (((js + 1i) - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((75869i + (ig - 1i)) + ((js - 1i) * 10i))))))));
                                var r44: f32 = opq(fma(opq(fs), opq(r42), bitcast<f32>(mem_ld((T + bitcast<u32>(((75869i + (ig - 1i)) + ((js - 1i) * 10i))))))));
                                mem_st(((*C).sfluxzen + bitcast<u32>(((44i + ig) - 1i))), bitcast<u32>(r44));
                            }
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((44i + ig) - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                var r46: f32 = opq(fma(bitcast<f32>(mem_ld((T + bitcast<u32>(75961i)))), bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb = r46;
                var r47: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r46);
                specparm = r47;
                if ((r47 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r48: f32 = opq((opq(4.0f)) * (opq(specparm)));
                specmult = r48;
                js = (1i + (i32(r48)));
                var r49: f32 = opq((r48 % 1.0f));
                fs = r49;
                var r50: f32 = opq((opq(1.0f)) - (opq(r49)));
                var r51: f32 = opq((opq(r50)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac000 = r51;
                var r52: f32 = opq((opq(r50)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac010 = r52;
                var r53: f32 = opq((opq(r49)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac100 = r53;
                var r54: f32 = opq((opq(r49)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac110 = r54;
                var r55: f32 = opq((opq(r50)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac001 = r55;
                var r56: f32 = opq((opq(r50)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac011 = r56;
                var r57: f32 = opq((opq(r49)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac101 = r57;
                var r58: f32 = opq((opq(r49)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac111 = r58;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((21i) - 16i)])) + js);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((21i) - 16i)])) + js);
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                var r59: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(75960i))))));
                tauray = r59;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 10i))) { break; }
                            var r61: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((63979i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 1175i))))))));
                            var r62: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((63979i + (ind0 - 1i)) + ((ig - 1i) * 1175i)))))), opq(r61)));
                            var r64: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((63979i + ((ind0 + 5i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r62)));
                            var r66: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((63979i + ((ind0 + 6i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r64)));
                            var r68: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((63979i + (ind1 - 1i)) + ((ig - 1i) * 1175i)))))), opq(r66)));
                            var r70: f32 = opq(fma(opq(fac101), bitcast<f32>(mem_ld((T + bitcast<u32>(((63979i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r68)));
                            var r72: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((63979i + ((ind1 + 5i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r70)));
                            var r74: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((63979i + ((ind1 + 6i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r72)));
                            var r76: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i)))))));
                            var r77: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((75829i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((75829i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r79: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r77), bitcast<f32>(mem_ld((T + bitcast<u32>(((75829i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r80: f32 = opq((opq(r76)) * (opq(r79)));
                            var r81: f32 = opq(fma(opq(speccomb), opq(r74), opq(r80)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((44i + ig) - 1i))))), bitcast<u32>(r81));
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((44i + ig) - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrsw_taumol22(C: ptr<function, S_RRSWColumn>, T_in: u32) {
    var T: u32 = T_in;
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var js: i32 = 0i;
    var lay: i32 = 0i;
    var laysolfr: i32 = 0i;
    var o2adj: f32 = f32(0i);
    var o2cont: f32 = f32(0i);
    var speccomb: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var tauray: f32 = f32(0i);
    o2adj = 1.6f;
    laysolfr = (*C).laytrop;
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                if ((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) < (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(77646i))))))) && ((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>(((lay + 1i) - 1i)))))) >= (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(77646i))))))))) {
                    laysolfr = min((lay + 1i), (*C).laytrop);
                }
                var r0: f32 = opq((opq(0.000435f)) * (bitcast<f32>(mem_ld(((*C).colo2 + bitcast<u32>((lay - 1i)))))));
                var r1: f32 = opq((opq(3.5e+02f)) * (opq(2.0f)));
                var r2: f32 = div_cr(r0, r1);
                o2cont = r2;
                var r3: f32 = opq((opq(o2adj)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(77648i))))));
                var r5: f32 = opq(fma(opq(r3), bitcast<f32>(mem_ld(((*C).colo2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb = r5;
                var r6: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r5);
                specparm = r6;
                if ((r6 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r7: f32 = opq((opq(8.0f)) * (opq(specparm)));
                specmult = r7;
                js = (1i + (i32(r7)));
                var r8: f32 = opq((r7 % 1.0f));
                fs = r8;
                var r9: f32 = opq((opq(1.0f)) - (opq(r8)));
                var r10: f32 = opq((opq(r9)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac000 = r10;
                var r11: f32 = opq((opq(r9)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac010 = r11;
                var r12: f32 = opq((opq(r8)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac100 = r12;
                var r13: f32 = opq((opq(r8)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac110 = r13;
                var r14: f32 = opq((opq(r9)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac001 = r14;
                var r15: f32 = opq((opq(r9)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac011 = r15;
                var r16: f32 = opq((opq(r8)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac101 = r16;
                var r17: f32 = opq((opq(r8)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac111 = r17;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((22i) - 16i)])) + js);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((22i) - 16i)])) + js);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                var r18: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(77647i))))));
                tauray = r18;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 2i))) { break; }
                            var r20: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((75962i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                            var r21: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((75962i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r20)));
                            var r23: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((75962i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r21)));
                            var r25: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((75962i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r23)));
                            var r27: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((75962i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r25)));
                            var r29: f32 = opq(fma(opq(fac101), bitcast<f32>(mem_ld((T + bitcast<u32>(((75962i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r27)));
                            var r31: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((75962i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r29)));
                            var r33: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((75962i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r31)));
                            var r35: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((77602i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((77602i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r37: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r35), bitcast<f32>(mem_ld((T + bitcast<u32>(((77602i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r39: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((77622i + ((indf + 1i) - 1i)) + ((ig - 1i) * 3i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((77622i + (indf - 1i)) + ((ig - 1i) * 3i))))))));
                            var r41: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r39), bitcast<f32>(mem_ld((T + bitcast<u32>(((77622i + (indf - 1i)) + ((ig - 1i) * 3i))))))));
                            var r42: f32 = opq((bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i)))))) * (opq(r41)));
                            var r43: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i))))), opq(r37), opq(r42)));
                            var r44: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (opq(r43)));
                            var r45: f32 = opq(fma(opq(speccomb), opq(r33), opq(r44)));
                            var r46: f32 = opq((opq(r45)) + (opq(o2cont)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((54i + ig) - 1i))))), bitcast<u32>(r46));
                            if ((lay == laysolfr)) {
                                var r47: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((77628i + (ig - 1i)) + (((js + 1i) - 1i) * 2i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((77628i + (ig - 1i)) + ((js - 1i) * 2i))))))));
                                var r49: f32 = opq(fma(opq(fs), opq(r47), bitcast<f32>(mem_ld((T + bitcast<u32>(((77628i + (ig - 1i)) + ((js - 1i) * 2i))))))));
                                mem_st(((*C).sfluxzen + bitcast<u32>(((54i + ig) - 1i))), bitcast<u32>(r49));
                            }
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((54i + ig) - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                var r50: f32 = opq((opq(0.000435f)) * (bitcast<f32>(mem_ld(((*C).colo2 + bitcast<u32>((lay - 1i)))))));
                var r51: f32 = opq((opq(3.5e+02f)) * (opq(2.0f)));
                var r52: f32 = div_cr(r50, r51);
                o2cont = r52;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((22i) - 16i)])) + 1i);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((22i) - 16i)])) + 1i);
                var r53: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(77647i))))));
                tauray = r53;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 2i))) { break; }
                            var r54: f32 = opq((bitcast<f32>(mem_ld(((*C).colo2 + bitcast<u32>((lay - 1i)))))) * (opq(o2adj)));
                            var r56: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((77132i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 235i))))))));
                            var r57: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((77132i + (ind0 - 1i)) + ((ig - 1i) * 235i)))))), opq(r56)));
                            var r59: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((77132i + (ind1 - 1i)) + ((ig - 1i) * 235i)))))), opq(r57)));
                            var r61: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((77132i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 235i)))))), opq(r59)));
                            var r63: f32 = opq(fma(opq(r54), opq(r61), opq(o2cont)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((54i + ig) - 1i))))), bitcast<u32>(r63));
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((54i + ig) - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrsw_taumol23(C: ptr<function, S_RRSWColumn>, T_in: u32) {
    var T: u32 = T_in;
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var js: i32 = 0i;
    var lay: i32 = 0i;
    var laysolfr: i32 = 0i;
    var speccomb: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var tauray: f32 = f32(0i);
    laysolfr = (*C).laytrop;
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                if ((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) < (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(78449i))))))) && ((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>(((lay + 1i) - 1i)))))) >= (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(78449i))))))))) {
                    laysolfr = min((lay + 1i), (*C).laytrop);
                }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((23i) - 16i)])) + 1i);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((23i) - 16i)])) + 1i);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 10i))) { break; }
                            var r0: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>((78439i + (ig - 1i))))))));
                            tauray = r0;
                            var r2: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((77649i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 65i))))))));
                            var r3: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((77649i + (ind0 - 1i)) + ((ig - 1i) * 65i)))))), opq(r2)));
                            var r5: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((77649i + (ind1 - 1i)) + ((ig - 1i) * 65i)))))), opq(r3)));
                            var r7: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((77649i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 65i)))))), opq(r5)));
                            var r9: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((78299i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((78299i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r11: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r9), bitcast<f32>(mem_ld((T + bitcast<u32>(((78299i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r12: f32 = opq((bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i)))))) * (opq(r11)));
                            var r13: f32 = opq(fma(bitcast<f32>(mem_ld((T + bitcast<u32>(78450i)))), opq(r7), opq(r12)));
                            var r14: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((78399i + ((indf + 1i) - 1i)) + ((ig - 1i) * 3i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((78399i + (indf - 1i)) + ((ig - 1i) * 3i))))))));
                            var r16: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r14), bitcast<f32>(mem_ld((T + bitcast<u32>(((78399i + (indf - 1i)) + ((ig - 1i) * 3i))))))));
                            var r18: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i))))), opq(r16), opq(r13)));
                            var r19: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (opq(r18)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((56i + ig) - 1i))))), bitcast<u32>(r19));
                            if ((lay == laysolfr)) {
                                mem_st(((*C).sfluxzen + bitcast<u32>(((56i + ig) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((78429i + (ig - 1i))))))));
                            }
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((56i + ig) - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 10i))) { break; }
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((56i + ig) - 1i))))), bitcast<u32>(0.0f));
                            var r20: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>((78439i + (ig - 1i))))))));
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((56i + ig) - 1i))))), bitcast<u32>(r20));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrsw_taumol24(C: ptr<function, S_RRSWColumn>, T_in: u32) {
    var T: u32 = T_in;
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var js: i32 = 0i;
    var lay: i32 = 0i;
    var laysolfr: i32 = 0i;
    var speccomb: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var tauray: f32 = f32(0i);
    laysolfr = (*C).laytrop;
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                if ((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) < (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(85283i))))))) && ((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>(((lay + 1i) - 1i)))))) >= (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(85283i))))))))) {
                    laysolfr = min((lay + 1i), (*C).laytrop);
                }
                var r1: f32 = opq(fma(bitcast<f32>(mem_ld((T + bitcast<u32>(85284i)))), bitcast<f32>(mem_ld(((*C).colo2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))));
                speccomb = r1;
                var r2: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), r1);
                specparm = r2;
                if ((r2 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r3: f32 = opq((opq(8.0f)) * (opq(specparm)));
                specmult = r3;
                js = (1i + (i32(r3)));
                var r4: f32 = opq((r3 % 1.0f));
                fs = r4;
                var r5: f32 = opq((opq(1.0f)) - (opq(r4)));
                var r6: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac000 = r6;
                var r7: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac010 = r7;
                var r8: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac100 = r8;
                var r9: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac110 = r9;
                var r10: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac001 = r10;
                var r11: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac011 = r11;
                var r12: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac101 = r12;
                var r13: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac111 = r13;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((24i) - 16i)])) + js);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((24i) - 16i)])) + js);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 8i))) { break; }
                            var r14: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((85203i + (ig - 1i)) + (((js + 1i) - 1i) * 8i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((85203i + (ig - 1i)) + ((js - 1i) * 8i))))))));
                            var r16: f32 = opq(fma(opq(fs), opq(r14), bitcast<f32>(mem_ld((T + bitcast<u32>(((85203i + (ig - 1i)) + ((js - 1i) * 8i))))))));
                            var r17: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (opq(r16)));
                            tauray = r17;
                            var r19: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((78451i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                            var r20: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((78451i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r19)));
                            var r22: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((78451i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r20)));
                            var r24: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((78451i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r22)));
                            var r26: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((78451i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r24)));
                            var r28: f32 = opq(fma(opq(fac101), bitcast<f32>(mem_ld((T + bitcast<u32>(((78451i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r26)));
                            var r30: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((78451i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r28)));
                            var r32: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((78451i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r30)));
                            var r34: f32 = opq((bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>((85187i + (ig - 1i))))))));
                            var r35: f32 = opq(fma(opq(speccomb), opq(r32), opq(r34)));
                            var r36: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((85011i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((85011i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r38: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r36), bitcast<f32>(mem_ld((T + bitcast<u32>(((85011i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r40: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((85091i + ((indf + 1i) - 1i)) + ((ig - 1i) * 3i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((85091i + (indf - 1i)) + ((ig - 1i) * 3i))))))));
                            var r42: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r40), bitcast<f32>(mem_ld((T + bitcast<u32>(((85091i + (indf - 1i)) + ((ig - 1i) * 3i))))))));
                            var r43: f32 = opq((bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i)))))) * (opq(r42)));
                            var r44: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i))))), opq(r38), opq(r43)));
                            var r46: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), opq(r44), opq(r35)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((66i + ig) - 1i))))), bitcast<u32>(r46));
                            if ((lay == laysolfr)) {
                                var r47: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((85115i + (ig - 1i)) + (((js + 1i) - 1i) * 8i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((85115i + (ig - 1i)) + ((js - 1i) * 8i))))))));
                                var r49: f32 = opq(fma(opq(fs), opq(r47), bitcast<f32>(mem_ld((T + bitcast<u32>(((85115i + (ig - 1i)) + ((js - 1i) * 8i))))))));
                                mem_st(((*C).sfluxzen + bitcast<u32>(((66i + ig) - 1i))), bitcast<u32>(r49));
                            }
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((66i + ig) - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((24i) - 16i)])) + 1i);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((24i) - 16i)])) + 1i);
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 8i))) { break; }
                            var r50: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>((85275i + (ig - 1i))))))));
                            tauray = r50;
                            var r52: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((83131i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 235i))))))));
                            var r53: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((83131i + (ind0 - 1i)) + ((ig - 1i) * 235i)))))), opq(r52)));
                            var r55: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((83131i + (ind1 - 1i)) + ((ig - 1i) * 235i)))))), opq(r53)));
                            var r57: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((83131i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 235i)))))), opq(r55)));
                            var r59: f32 = opq((bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>((85195i + (ig - 1i))))))));
                            var r60: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).colo2 + bitcast<u32>((lay - 1i))))), opq(r57), opq(r59)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((66i + ig) - 1i))))), bitcast<u32>(r60));
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((66i + ig) - 1i))))), bitcast<u32>(r50));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrsw_taumol25(C: ptr<function, S_RRSWColumn>, T_in: u32) {
    var T: u32 = T_in;
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var js: i32 = 0i;
    var lay: i32 = 0i;
    var laysolfr: i32 = 0i;
    var speccomb: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var tauray: f32 = f32(0i);
    laysolfr = (*C).laytrop;
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                if ((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) < (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(85699i))))))) && ((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>(((lay + 1i) - 1i)))))) >= (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(85699i))))))))) {
                    laysolfr = min((lay + 1i), (*C).laytrop);
                }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((25i) - 16i)])) + 1i);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((25i) - 16i)])) + 1i);
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 6i))) { break; }
                            var r0: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>((85693i + (ig - 1i))))))));
                            tauray = r0;
                            var r2: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((85285i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 65i))))))));
                            var r3: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((85285i + (ind0 - 1i)) + ((ig - 1i) * 65i)))))), opq(r2)));
                            var r5: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((85285i + (ind1 - 1i)) + ((ig - 1i) * 65i)))))), opq(r3)));
                            var r7: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((85285i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 65i)))))), opq(r5)));
                            var r9: f32 = opq((bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>((85681i + (ig - 1i))))))));
                            var r10: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), opq(r7), opq(r9)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((74i + ig) - 1i))))), bitcast<u32>(r10));
                            if ((lay == laysolfr)) {
                                mem_st(((*C).sfluxzen + bitcast<u32>(((74i + ig) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((85675i + (ig - 1i))))))));
                            }
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((74i + ig) - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 6i))) { break; }
                            var r11: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>((85693i + (ig - 1i))))))));
                            tauray = r11;
                            var r12: f32 = opq((bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>((85687i + (ig - 1i))))))));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((74i + ig) - 1i))))), bitcast<u32>(r12));
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((74i + ig) - 1i))))), bitcast<u32>(r11));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrsw_taumol26(C: ptr<function, S_RRSWColumn>, T_in: u32) {
    var T: u32 = T_in;
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var js: i32 = 0i;
    var lay: i32 = 0i;
    var laysolfr: i32 = 0i;
    var speccomb: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var tauray: f32 = f32(0i);
    laysolfr = (*C).laytrop;
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 6i))) { break; }
                            if ((lay == laysolfr)) {
                                mem_st(((*C).sfluxzen + bitcast<u32>(((80i + ig) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((85700i + (ig - 1i))))))));
                            }
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((80i + ig) - 1i))))), bitcast<u32>(0.0f));
                            var r0: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>((85706i + (ig - 1i))))))));
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((80i + ig) - 1i))))), bitcast<u32>(r0));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 6i))) { break; }
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((80i + ig) - 1i))))), bitcast<u32>(0.0f));
                            var r1: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>((85706i + (ig - 1i))))))));
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((80i + ig) - 1i))))), bitcast<u32>(r1));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrsw_taumol27(C: ptr<function, S_RRSWColumn>, T_in: u32) {
    var T: u32 = T_in;
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var js: i32 = 0i;
    var lay: i32 = 0i;
    var laysolfr: i32 = 0i;
    var speccomb: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var tauray: f32 = f32(0i);
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((27i) - 16i)])) + 1i);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((27i) - 16i)])) + 1i);
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 8i))) { break; }
                            var r0: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>((88120i + (ig - 1i))))))));
                            tauray = r0;
                            var r2: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((85712i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 65i))))))));
                            var r3: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((85712i + (ind0 - 1i)) + ((ig - 1i) * 65i)))))), opq(r2)));
                            var r5: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((85712i + (ind1 - 1i)) + ((ig - 1i) * 65i)))))), opq(r3)));
                            var r7: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((85712i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 65i)))))), opq(r5)));
                            var r8: f32 = opq((bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i)))))) * (opq(r7)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((86i + ig) - 1i))))), bitcast<u32>(r8));
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((86i + ig) - 1i))))), bitcast<u32>(r0));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    laysolfr = (*C).nlayers;
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                if ((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>(((lay - 1i) - 1i)))))) < (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(88128i))))))) && ((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) >= (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(88128i))))))))) {
                    laysolfr = lay;
                }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((27i) - 16i)])) + 1i);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((27i) - 16i)])) + 1i);
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 8i))) { break; }
                            var r9: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>((88120i + (ig - 1i))))))));
                            tauray = r9;
                            var r11: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((86232i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 235i))))))));
                            var r12: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((86232i + (ind0 - 1i)) + ((ig - 1i) * 235i)))))), opq(r11)));
                            var r14: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((86232i + (ind1 - 1i)) + ((ig - 1i) * 235i)))))), opq(r12)));
                            var r16: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((86232i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 235i)))))), opq(r14)));
                            var r17: f32 = opq((bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i)))))) * (opq(r16)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((86i + ig) - 1i))))), bitcast<u32>(r17));
                            if ((lay == laysolfr)) {
                                var r18: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(88129i))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>((88112i + (ig - 1i))))))));
                                mem_st(((*C).sfluxzen + bitcast<u32>(((86i + ig) - 1i))), bitcast<u32>(r18));
                            }
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((86i + ig) - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrsw_taumol28(C: ptr<function, S_RRSWColumn>, T_in: u32) {
    var T: u32 = T_in;
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var js: i32 = 0i;
    var lay: i32 = 0i;
    var laysolfr: i32 = 0i;
    var speccomb: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var tauray: f32 = f32(0i);
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                var r1: f32 = opq(fma(bitcast<f32>(mem_ld((T + bitcast<u32>(98722i)))), bitcast<f32>(mem_ld(((*C).colo2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i)))))));
                speccomb = r1;
                var r2: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i))))), r1);
                specparm = r2;
                if ((r2 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r3: f32 = opq((opq(8.0f)) * (opq(specparm)));
                specmult = r3;
                js = (1i + (i32(r3)));
                var r4: f32 = opq((r3 % 1.0f));
                fs = r4;
                var r5: f32 = opq((opq(1.0f)) - (opq(r4)));
                var r6: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac000 = r6;
                var r7: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac010 = r7;
                var r8: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac100 = r8;
                var r9: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac110 = r9;
                var r10: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac001 = r10;
                var r11: f32 = opq((opq(r5)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac011 = r11;
                var r12: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac101 = r12;
                var r13: f32 = opq((opq(r4)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac111 = r13;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((28i) - 16i)])) + js);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((28i) - 16i)])) + js);
                var r14: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(98721i))))));
                tauray = r14;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 6i))) { break; }
                            var r16: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((88130i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 585i))))))));
                            var r17: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((88130i + (ind0 - 1i)) + ((ig - 1i) * 585i)))))), opq(r16)));
                            var r19: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((88130i + ((ind0 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r17)));
                            var r21: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((88130i + ((ind0 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r19)));
                            var r23: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((88130i + (ind1 - 1i)) + ((ig - 1i) * 585i)))))), opq(r21)));
                            var r25: f32 = opq(fma(opq(fac101), bitcast<f32>(mem_ld((T + bitcast<u32>(((88130i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r23)));
                            var r27: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((88130i + ((ind1 + 9i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r25)));
                            var r29: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((88130i + ((ind1 + 10i) - 1i)) + ((ig - 1i) * 585i)))))), opq(r27)));
                            var r30: f32 = opq((opq(speccomb)) * (opq(r29)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((94i + ig) - 1i))))), bitcast<u32>(r30));
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((94i + ig) - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    laysolfr = (*C).nlayers;
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                if ((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>(((lay - 1i) - 1i)))))) < (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(98720i))))))) && ((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) >= (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(98720i))))))))) {
                    laysolfr = lay;
                }
                var r32: f32 = opq(fma(bitcast<f32>(mem_ld((T + bitcast<u32>(98722i)))), bitcast<f32>(mem_ld(((*C).colo2 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i)))))));
                speccomb = r32;
                var r33: f32 = div_cr(bitcast<f32>(mem_ld(((*C).colo3 + bitcast<u32>((lay - 1i))))), r32);
                specparm = r33;
                if ((r33 >= K_RR_ONEMINUS)) {
                    specparm = K_RR_ONEMINUS;
                }
                var r34: f32 = opq((opq(4.0f)) * (opq(specparm)));
                specmult = r34;
                js = (1i + (i32(r34)));
                var r35: f32 = opq((r34 % 1.0f));
                fs = r35;
                var r36: f32 = opq((opq(1.0f)) - (opq(r35)));
                var r37: f32 = opq((opq(r36)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac000 = r37;
                var r38: f32 = opq((opq(r36)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac010 = r38;
                var r39: f32 = opq((opq(r35)) * (bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i)))))));
                fac100 = r39;
                var r40: f32 = opq((opq(r35)) * (bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))));
                fac110 = r40;
                var r41: f32 = opq((opq(r36)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac001 = r41;
                var r42: f32 = opq((opq(r36)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac011 = r42;
                var r43: f32 = opq((opq(r35)) * (bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i)))))));
                fac101 = r43;
                var r44: f32 = opq((opq(r35)) * (bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i)))))));
                fac111 = r44;
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((28i) - 16i)])) + js);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((28i) - 16i)])) + js);
                var r45: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(98721i))))));
                tauray = r45;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 6i))) { break; }
                            var r47: f32 = opq((opq(fac100)) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((91640i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 1175i))))))));
                            var r48: f32 = opq(fma(opq(fac000), bitcast<f32>(mem_ld((T + bitcast<u32>(((91640i + (ind0 - 1i)) + ((ig - 1i) * 1175i)))))), opq(r47)));
                            var r50: f32 = opq(fma(opq(fac010), bitcast<f32>(mem_ld((T + bitcast<u32>(((91640i + ((ind0 + 5i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r48)));
                            var r52: f32 = opq(fma(opq(fac110), bitcast<f32>(mem_ld((T + bitcast<u32>(((91640i + ((ind0 + 6i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r50)));
                            var r54: f32 = opq(fma(opq(fac001), bitcast<f32>(mem_ld((T + bitcast<u32>(((91640i + (ind1 - 1i)) + ((ig - 1i) * 1175i)))))), opq(r52)));
                            var r56: f32 = opq(fma(opq(fac101), bitcast<f32>(mem_ld((T + bitcast<u32>(((91640i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r54)));
                            var r58: f32 = opq(fma(opq(fac011), bitcast<f32>(mem_ld((T + bitcast<u32>(((91640i + ((ind1 + 5i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r56)));
                            var r60: f32 = opq(fma(opq(fac111), bitcast<f32>(mem_ld((T + bitcast<u32>(((91640i + ((ind1 + 6i) - 1i)) + ((ig - 1i) * 1175i)))))), opq(r58)));
                            var r61: f32 = opq((opq(speccomb)) * (opq(r60)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((94i + ig) - 1i))))), bitcast<u32>(r61));
                            if ((lay == laysolfr)) {
                                var r62: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((98690i + (ig - 1i)) + (((js + 1i) - 1i) * 6i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((98690i + (ig - 1i)) + ((js - 1i) * 6i))))))));
                                var r64: f32 = opq(fma(opq(fs), opq(r62), bitcast<f32>(mem_ld((T + bitcast<u32>(((98690i + (ig - 1i)) + ((js - 1i) * 6i))))))));
                                mem_st(((*C).sfluxzen + bitcast<u32>(((94i + ig) - 1i))), bitcast<u32>(r64));
                            }
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((94i + ig) - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrsw_taumol29(C: ptr<function, S_RRSWColumn>, T_in: u32) {
    var T: u32 = T_in;
    var fac000: f32 = f32(0i);
    var fac001: f32 = f32(0i);
    var fac010: f32 = f32(0i);
    var fac011: f32 = f32(0i);
    var fac100: f32 = f32(0i);
    var fac101: f32 = f32(0i);
    var fac110: f32 = f32(0i);
    var fac111: f32 = f32(0i);
    var fs: f32 = f32(0i);
    var ig: i32 = 0i;
    var ind0: i32 = 0i;
    var ind1: i32 = 0i;
    var indf: i32 = 0i;
    var inds: i32 = 0i;
    var js: i32 = 0i;
    var lay: i32 = 0i;
    var laysolfr: i32 = 0i;
    var speccomb: f32 = f32(0i);
    var specmult: f32 = f32(0i);
    var specparm: f32 = f32(0i);
    var tauray: f32 = f32(0i);
    {
        lay = 1i;
        loop {
            if (!((lay <= ((*C).laytrop)))) { break; }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 1i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((29i) - 16i)])) + 1i);
                ind1 = (((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPA[((29i) - 16i)])) + 1i);
                inds = bitcast<i32>(mem_ld(((*C).indself + bitcast<u32>((lay - 1i)))));
                indf = bitcast<i32>(mem_ld(((*C).indfor + bitcast<u32>((lay - 1i)))));
                var r0: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(102528i))))));
                tauray = r0;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 12i))) { break; }
                            var r2: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((98723i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 65i))))))));
                            var r3: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((98723i + (ind0 - 1i)) + ((ig - 1i) * 65i)))))), opq(r2)));
                            var r5: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((98723i + (ind1 - 1i)) + ((ig - 1i) * 65i)))))), opq(r3)));
                            var r7: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((98723i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 65i)))))), opq(r5)));
                            var r8: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((102323i + ((inds + 1i) - 1i)) + ((ig - 1i) * 10i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((102323i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r10: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffrac + bitcast<u32>((lay - 1i))))), opq(r8), bitcast<f32>(mem_ld((T + bitcast<u32>(((102323i + (inds - 1i)) + ((ig - 1i) * 10i))))))));
                            var r12: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).selffac + bitcast<u32>((lay - 1i))))), opq(r10), opq(r7)));
                            var r13: f32 = opq((bitcast<f32>(mem_ld((T + bitcast<u32>(((102443i + ((indf + 1i) - 1i)) + ((ig - 1i) * 4i))))))) - (bitcast<f32>(mem_ld((T + bitcast<u32>(((102443i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r15: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfrac + bitcast<u32>((lay - 1i))))), opq(r13), bitcast<f32>(mem_ld((T + bitcast<u32>(((102443i + (indf - 1i)) + ((ig - 1i) * 4i))))))));
                            var r17: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).forfac + bitcast<u32>((lay - 1i))))), opq(r15), opq(r12)));
                            var r19: f32 = opq((bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>((102515i + (ig - 1i))))))));
                            var r20: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i))))), opq(r17), opq(r19)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((100i + ig) - 1i))))), bitcast<u32>(r20));
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((100i + ig) - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
    laysolfr = (*C).nlayers;
    {
        lay = (((*C).laytrop) + 1i);
        loop {
            if (!((lay <= ((*C).nlayers)))) { break; }
                if ((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>(((lay - 1i) - 1i)))))) < (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(102527i))))))) && ((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) >= (i32(bitcast<f32>(mem_ld((T + bitcast<u32>(102527i))))))))) {
                    laysolfr = lay;
                }
                ind0 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 13i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((29i) - 16i)])) + 1i);
                ind1 = ((((((bitcast<i32>(mem_ld(((*C).jp + bitcast<u32>((lay - 1i)))))) - 12i) * 5i) + ((bitcast<i32>(mem_ld(((*C).jt1 + bitcast<u32>((lay - 1i)))))) - 1i)) * (K_RRSW_NSPB[((29i) - 16i)])) + 1i);
                var r21: f32 = opq((bitcast<f32>(mem_ld(((*C).colmol + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(102528i))))));
                tauray = r21;
                {
                    ig = 1i;
                    loop {
                        if (!((ig <= 12i))) { break; }
                            var r23: f32 = opq((bitcast<f32>(mem_ld(((*C).fac10 + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>(((99503i + ((ind0 + 1i) - 1i)) + ((ig - 1i) * 235i))))))));
                            var r24: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac00 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((99503i + (ind0 - 1i)) + ((ig - 1i) * 235i)))))), opq(r23)));
                            var r26: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac01 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((99503i + (ind1 - 1i)) + ((ig - 1i) * 235i)))))), opq(r24)));
                            var r28: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).fac11 + bitcast<u32>((lay - 1i))))), bitcast<f32>(mem_ld((T + bitcast<u32>(((99503i + ((ind1 + 1i) - 1i)) + ((ig - 1i) * 235i)))))), opq(r26)));
                            var r30: f32 = opq((bitcast<f32>(mem_ld(((*C).colh2o + bitcast<u32>((lay - 1i)))))) * (bitcast<f32>(mem_ld((T + bitcast<u32>((102503i + (ig - 1i))))))));
                            var r31: f32 = opq(fma(bitcast<f32>(mem_ld(((*C).colco2 + bitcast<u32>((lay - 1i))))), opq(r28), opq(r30)));
                            mem_st(((*C).taug + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((100i + ig) - 1i))))), bitcast<u32>(r31));
                            if ((lay == laysolfr)) {
                                mem_st(((*C).sfluxzen + bitcast<u32>(((100i + ig) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((T + bitcast<u32>((102491i + (ig - 1i))))))));
                            }
                            mem_st(((*C).taur + bitcast<u32>(((lay - 1i) + (((*C).nlayers) * ((100i + ig) - 1i))))), bitcast<u32>(tauray));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
            continuing {
                lay = (lay + 1i);
            }
        }
    }
}

fn f_rrsw_reftra_sw(C: ptr<function, S_RRSWColumn>, T_in: u32, W_in: u32, WI_in: u32, lrtchk_in: u32, pgg_in: u32, prmuz_in: f32, ptau_in: u32, pw_in: u32, pref_in: u32, prefd_in: u32, ptra_in: u32, ptrad_in: u32) {
    var T: u32 = T_in;
    var W: u32 = W_in;
    var WI: u32 = WI_in;
    var lrtchk: u32 = lrtchk_in;
    var pgg: u32 = pgg_in;
    var prmuz: f32 = prmuz_in;
    var ptau: u32 = ptau_in;
    var pw: u32 = pw_in;
    var pref: u32 = pref_in;
    var prefd: u32 = prefd_in;
    var ptra: u32 = ptra_in;
    var ptrad: u32 = ptrad_in;
    var denom: f32 = f32(0i);
    var itind: i32 = 0i;
    var jk: i32 = 0i;
    var jl: i32 = 0i;
    var tblind: f32 = f32(0i);
    var za: f32 = f32(0i);
    var za1: f32 = f32(0i);
    var za2: f32 = f32(0i);
    var zbeta: f32 = f32(0i);
    var zdend: f32 = f32(0i);
    var zdenr: f32 = f32(0i);
    var zdent: f32 = f32(0i);
    var ze1: f32 = f32(0i);
    var ze2: f32 = f32(0i);
    var zem1: f32 = f32(0i);
    var zem2: f32 = f32(0i);
    var zemm: f32 = f32(0i);
    var zep1: f32 = f32(0i);
    var zep2: f32 = f32(0i);
    var zg: f32 = f32(0i);
    var zg3: f32 = f32(0i);
    var zgamma1: f32 = f32(0i);
    var zgamma2: f32 = f32(0i);
    var zgamma3: f32 = f32(0i);
    var zgamma4: f32 = f32(0i);
    var zgt: f32 = f32(0i);
    var zr1: f32 = f32(0i);
    var zr2: f32 = f32(0i);
    var zr3: f32 = f32(0i);
    var zr4: f32 = f32(0i);
    var zr5: f32 = f32(0i);
    var zrk: f32 = f32(0i);
    var zrk2: f32 = f32(0i);
    var zrkg: f32 = f32(0i);
    var zrm1: f32 = f32(0i);
    var zrp: f32 = f32(0i);
    var zrp1: f32 = f32(0i);
    var zrpp: f32 = f32(0i);
    var zsr3: f32 = f32(0i);
    var zt1: f32 = f32(0i);
    var zt2: f32 = f32(0i);
    var zt3: f32 = f32(0i);
    var zt4: f32 = f32(0i);
    var zt5: f32 = f32(0i);
    var zto1: f32 = f32(0i);
    var zw: f32 = f32(0i);
    var zwcrit: f32 = f32(0i);
    var zwo: f32 = f32(0i);
    var r0: f32 = sqrt_cr(3.0f);
    zsr3 = r0;
    zwcrit = 0.9999995f;
    {
        jk = 1i;
        loop {
            if (!((jk <= ((*C).nlayers)))) { break; }
                if ((!(bitcast<i32>(mem_ld((lrtchk + bitcast<u32>((jk - 1i))))) != 0i))) {
                    mem_st((pref + bitcast<u32>((jk - 1i))), bitcast<u32>(0.0f));
                    mem_st((ptra + bitcast<u32>((jk - 1i))), bitcast<u32>(1.0f));
                    mem_st((prefd + bitcast<u32>((jk - 1i))), bitcast<u32>(0.0f));
                    mem_st((ptrad + bitcast<u32>((jk - 1i))), bitcast<u32>(1.0f));
                } else {
                    zto1 = bitcast<f32>(mem_ld((ptau + bitcast<u32>((jk - 1i)))));
                    zw = bitcast<f32>(mem_ld((pw + bitcast<u32>((jk - 1i)))));
                    zg = bitcast<f32>(mem_ld((pgg + bitcast<u32>((jk - 1i)))));
                    var r1: f32 = opq((opq(3.0f)) * (bitcast<f32>(mem_ld((pgg + bitcast<u32>((jk - 1i)))))));
                    zg3 = r1;
                    var r2: f32 = opq((opq(5.0f)) + (opq(r1)));
                    var r4: f32 = opq(fma(opq(f_rr_neg(bitcast<f32>(mem_ld((pw + bitcast<u32>((jk - 1i))))), (*C).z0)), opq(r2), opq(8.0f)));
                    var r5: f32 = opq((opq(r4)) * (opq(0.25f)));
                    zgamma1 = r5;
                    var r6: f32 = opq((opq(1.0f)) - (bitcast<f32>(mem_ld((pgg + bitcast<u32>((jk - 1i)))))));
                    var r7: f32 = opq((bitcast<f32>(mem_ld((pw + bitcast<u32>((jk - 1i)))))) * (opq(r6)));
                    var r8: f32 = opq((opq(3.0f)) * (opq(r7)));
                    var r9: f32 = opq((opq(r8)) * (opq(0.25f)));
                    zgamma2 = r9;
                    var r11: f32 = opq(fma(opq(f_rr_neg(r1, (*C).z0)), opq(prmuz), opq(2.0f)));
                    var r12: f32 = opq((opq(r11)) * (opq(0.25f)));
                    zgamma3 = r12;
                    var r13: f32 = opq((opq(1.0f)) - (opq(r12)));
                    zgamma4 = r13;
                    zwo = 0.0f;
                    denom = 1.0f;
                    if (((bitcast<f32>(mem_ld((pgg + bitcast<u32>((jk - 1i)))))) != 1.0f)) {
                        var r14: f32 = opq((opq(1.0f)) - (opq(zw)));
                        var r15: f32 = opq((opq(1.0f)) - (opq(zg)));
                        var r16: f32 = div_cr(zg, r15);
                        var r17: f32 = opq((opq(r16)) * (opq(r16)));
                        var r19: f32 = opq(fma(opq(f_rr_neg(r14, (*C).z0)), opq(r17), opq(1.0f)));
                        denom = r19;
                    }
                    if (((zw > 0.0f) && (denom != 0.0f))) {
                        var r20: f32 = div_cr(zw, denom);
                        zwo = r20;
                    }
                    if ((zwo >= zwcrit)) {
                        var r22: f32 = opq(fma(opq(zgamma1), opq(prmuz), opq(f_rr_neg(zgamma3, (*C).z0))));
                        za1 = r22;
                        var r23: f32 = opq((opq(zgamma1)) * (opq(zto1)));
                        zgt = r23;
                        var r24: f32 = div_cr(zto1, prmuz);
                        var r25: f32 = opq(min(r24, 5e+02f));
                        ze1 = r25;
                        if ((r25 <= 0.06f)) {
                            var r26: f32 = opq((opq(1.0f)) - (opq(ze1)));
                            var r27: f32 = opq((opq(0.5f)) * (opq(ze1)));
                            var r29: f32 = opq(fma(opq(r27), opq(ze1), opq(r26)));
                            ze2 = r29;
                        } else {
                            var r30: f32 = opq((opq(3.5971224f)) + (opq(ze1)));
                            var r31: f32 = div_cr(ze1, r30);
                            tblind = r31;
                            var r33: f32 = opq(fma(opq(1e+04f), opq(r31), opq(0.5f)));
                            var r34: i32 = i32(r33);
                            itind = r34;
                            ze2 = bitcast<f32>(mem_ld((T + bitcast<u32>((0i + (itind - 0i))))));
                        }
                        var r35: f32 = opq((opq(1.0f)) - (opq(ze2)));
                        var r37: f32 = opq(fma(opq(f_rr_neg(za1, (*C).z0)), opq(r35), opq(zgt)));
                        var r38: f32 = opq((opq(1.0f)) + (opq(zgt)));
                        var r39: f32 = div_cr(r37, r38);
                        mem_st((pref + bitcast<u32>((jk - 1i))), bitcast<u32>(r39));
                        var r40: f32 = opq((opq(1.0f)) - (bitcast<f32>(mem_ld((pref + bitcast<u32>((jk - 1i)))))));
                        mem_st((ptra + bitcast<u32>((jk - 1i))), bitcast<u32>(r40));
                        var r41: f32 = div_cr(zgt, r38);
                        mem_st((prefd + bitcast<u32>((jk - 1i))), bitcast<u32>(r41));
                        var r42: f32 = opq((opq(1.0f)) - (bitcast<f32>(mem_ld((prefd + bitcast<u32>((jk - 1i)))))));
                        mem_st((ptrad + bitcast<u32>((jk - 1i))), bitcast<u32>(r42));
                        if ((ze2 == 1.0f)) {
                            mem_st((pref + bitcast<u32>((jk - 1i))), bitcast<u32>(0.0f));
                            mem_st((ptra + bitcast<u32>((jk - 1i))), bitcast<u32>(1.0f));
                            mem_st((prefd + bitcast<u32>((jk - 1i))), bitcast<u32>(0.0f));
                            mem_st((ptrad + bitcast<u32>((jk - 1i))), bitcast<u32>(1.0f));
                        }
                    } else {
                        var r44: f32 = opq((opq(zgamma2)) * (opq(zgamma3)));
                        var r45: f32 = opq(fma(opq(zgamma1), opq(zgamma4), opq(r44)));
                        za1 = r45;
                        var r47: f32 = opq((opq(zgamma2)) * (opq(zgamma4)));
                        var r48: f32 = opq(fma(opq(zgamma1), opq(zgamma3), opq(r47)));
                        za2 = r48;
                        var r50: f32 = opq((opq(zgamma2)) * (opq(zgamma2)));
                        var r51: f32 = opq(fma(opq(zgamma1), opq(zgamma1), opq(f_rr_neg(r50, (*C).z0))));
                        var r52: f32 = sqrt_cr(r51);
                        zrk = r52;
                        var r53: f32 = opq((opq(r52)) * (opq(prmuz)));
                        zrp = r53;
                        var r54: f32 = opq((opq(1.0f)) + (opq(r53)));
                        zrp1 = r54;
                        var r55: f32 = opq((opq(1.0f)) - (opq(r53)));
                        zrm1 = r55;
                        var r56: f32 = opq((opq(2.0f)) * (opq(r52)));
                        zrk2 = r56;
                        var r58: f32 = opq(fma(opq(f_rr_neg(r53, (*C).z0)), opq(r53), opq(1.0f)));
                        zrpp = r58;
                        var r59: f32 = opq((opq(r52)) + (opq(zgamma1)));
                        zrkg = r59;
                        var r61: f32 = opq(fma(opq(r52), opq(zgamma3), opq(r48)));
                        var r62: f32 = opq((opq(r55)) * (opq(r61)));
                        zr1 = r62;
                        var r63: f32 = opq(fma(opq(f_rr_neg(r52, (*C).z0)), opq(zgamma3), opq(r48)));
                        var r64: f32 = opq((opq(r54)) * (opq(r63)));
                        zr2 = r64;
                        var r66: f32 = opq(fma(opq(f_rr_neg(r48, (*C).z0)), opq(prmuz), opq(zgamma3)));
                        var r67: f32 = opq((opq(r56)) * (opq(r66)));
                        zr3 = r67;
                        var r68: f32 = opq((opq(r58)) * (opq(r59)));
                        zr4 = r68;
                        var r69: f32 = opq((opq(r52)) - (opq(zgamma1)));
                        var r70: f32 = opq((opq(r58)) * (opq(r69)));
                        zr5 = r70;
                        var r72: f32 = opq(fma(opq(r52), opq(zgamma4), opq(r45)));
                        var r73: f32 = opq((opq(r54)) * (opq(r72)));
                        zt1 = r73;
                        var r74: f32 = opq(fma(opq(f_rr_neg(r52, (*C).z0)), opq(zgamma4), opq(r45)));
                        var r75: f32 = opq((opq(r55)) * (opq(r74)));
                        zt2 = r75;
                        var r77: f32 = opq(fma(opq(r45), opq(prmuz), opq(zgamma4)));
                        var r78: f32 = opq((opq(r56)) * (opq(r77)));
                        zt3 = r78;
                        zt4 = r68;
                        zt5 = r70;
                        var r79: f32 = opq((opq(zgamma1)) - (opq(r52)));
                        var r80: f32 = div_cr(r79, r59);
                        zbeta = r80;
                        var r81: f32 = opq((opq(r52)) * (opq(zto1)));
                        var r82: f32 = opq(min(r81, 5e+02f));
                        ze1 = r82;
                        var r83: f32 = div_cr(zto1, prmuz);
                        var r84: f32 = opq(min(r83, 5e+02f));
                        ze2 = r84;
                        if ((r82 <= 0.06f)) {
                            var r85: f32 = opq((opq(1.0f)) - (opq(ze1)));
                            var r86: f32 = opq((opq(0.5f)) * (opq(ze1)));
                            var r88: f32 = opq(fma(opq(r86), opq(ze1), opq(r85)));
                            zem1 = r88;
                            var r89: f32 = div_cr(1.0f, r88);
                            zep1 = r89;
                        } else {
                            var r90: f32 = opq((opq(3.5971224f)) + (opq(ze1)));
                            var r91: f32 = div_cr(ze1, r90);
                            tblind = r91;
                            var r93: f32 = opq(fma(opq(1e+04f), opq(r91), opq(0.5f)));
                            var r94: i32 = i32(r93);
                            itind = r94;
                            zem1 = bitcast<f32>(mem_ld((T + bitcast<u32>((0i + (itind - 0i))))));
                            var r95: f32 = div_cr(1.0f, bitcast<f32>(mem_ld((T + bitcast<u32>((0i + (itind - 0i)))))));
                            zep1 = r95;
                        }
                        if ((ze2 <= 0.06f)) {
                            var r96: f32 = opq((opq(1.0f)) - (opq(ze2)));
                            var r97: f32 = opq((opq(0.5f)) * (opq(ze2)));
                            var r99: f32 = opq(fma(opq(r97), opq(ze2), opq(r96)));
                            zem2 = r99;
                            var r100: f32 = div_cr(1.0f, r99);
                            zep2 = r100;
                        } else {
                            var r101: f32 = opq((opq(3.5971224f)) + (opq(ze2)));
                            var r102: f32 = div_cr(ze2, r101);
                            tblind = r102;
                            var r104: f32 = opq(fma(opq(1e+04f), opq(r102), opq(0.5f)));
                            var r105: i32 = i32(r104);
                            itind = r105;
                            zem2 = bitcast<f32>(mem_ld((T + bitcast<u32>((0i + (itind - 0i))))));
                            var r106: f32 = div_cr(1.0f, bitcast<f32>(mem_ld((T + bitcast<u32>((0i + (itind - 0i)))))));
                            zep2 = r106;
                        }
                        var r108: f32 = opq((opq(zr5)) * (opq(zem1)));
                        var r109: f32 = opq(fma(opq(zr4), opq(zep1), opq(r108)));
                        zdenr = r109;
                        var r111: f32 = opq((opq(zt5)) * (opq(zem1)));
                        var r112: f32 = opq(fma(opq(zt4), opq(zep1), opq(r111)));
                        zdent = r112;
                        if (((r109 >= (opq((-(opq(1e-08f)))))) && (r109 <= (1e-08f)))) {
                            mem_st((pref + bitcast<u32>((jk - 1i))), bitcast<u32>(1e-08f));
                            mem_st((ptra + bitcast<u32>((jk - 1i))), bitcast<u32>(zem2));
                        } else {
                            var r114: f32 = opq((opq(zr2)) * (opq(zem1)));
                            var r115: f32 = opq(fma(opq(zr1), opq(zep1), opq(f_rr_neg(r114, (*C).z0))));
                            var r117: f32 = opq(fma(opq(f_rr_neg(zr3, (*C).z0)), opq(zem2), opq(r115)));
                            var r118: f32 = opq((opq(zw)) * (opq(r117)));
                            var r119: f32 = div_cr(r118, zdenr);
                            mem_st((pref + bitcast<u32>((jk - 1i))), bitcast<u32>(r119));
                            var r120: f32 = opq((opq(zem2)) * (opq(zw)));
                            var r122: f32 = opq((opq(zt2)) * (opq(zem1)));
                            var r123: f32 = opq(fma(opq(zt1), opq(zep1), opq(f_rr_neg(r122, (*C).z0))));
                            var r125: f32 = opq(fma(opq(f_rr_neg(zt3, (*C).z0)), opq(zep2), opq(r123)));
                            var r126: f32 = opq((opq(r120)) * (opq(r125)));
                            var r127: f32 = div_cr(r126, zdent);
                            var r128: f32 = opq((opq(zem2)) - (opq(r127)));
                            mem_st((ptra + bitcast<u32>((jk - 1i))), bitcast<u32>(r128));
                        }
                        var r129: f32 = opq((opq(zem1)) * (opq(zem1)));
                        zemm = r129;
                        var r131: f32 = opq(fma(opq(f_rr_neg(zbeta, (*C).z0)), opq(r129), opq(1.0f)));
                        var r132: f32 = opq((opq(r131)) * (opq(zrkg)));
                        var r133: f32 = div_cr(1.0f, r132);
                        zdend = r133;
                        var r134: f32 = opq((opq(1.0f)) - (opq(r129)));
                        var r135: f32 = opq((opq(zgamma2)) * (opq(r134)));
                        var r136: f32 = opq((opq(r135)) * (opq(r133)));
                        mem_st((prefd + bitcast<u32>((jk - 1i))), bitcast<u32>(r136));
                        var r137: f32 = opq((opq(zrk2)) * (opq(zem1)));
                        var r138: f32 = opq((opq(r137)) * (opq(r133)));
                        mem_st((ptrad + bitcast<u32>((jk - 1i))), bitcast<u32>(r138));
                    }
                }
            continuing {
                jk = (jk + 1i);
            }
        }
    }
}

fn f_rrsw_vrtqdr_sw(C: ptr<function, S_RRSWColumn>, T_in: u32, W_in: u32, WI_in: u32, klev_in: i32, kw_in: i32, pref_in: u32, prefd_in: u32, ptra_in: u32, ptrad_in: u32, pdbt_in: u32, prdnd_in: u32, prup_in: u32, prupd_in: u32, ptdbt_in: u32, pfd_in: u32, pfu_in: u32) {
    var T: u32 = T_in;
    var W: u32 = W_in;
    var WI: u32 = WI_in;
    var klev: i32 = klev_in;
    var kw: i32 = kw_in;
    var pref: u32 = pref_in;
    var prefd: u32 = prefd_in;
    var ptra: u32 = ptra_in;
    var ptrad: u32 = ptrad_in;
    var pdbt: u32 = pdbt_in;
    var prdnd: u32 = prdnd_in;
    var prup: u32 = prup_in;
    var prupd: u32 = prupd_in;
    var ptdbt: u32 = ptdbt_in;
    var pfd: u32 = pfd_in;
    var pfu: u32 = pfu_in;
    var ikp: i32 = 0i;
    var ikx: i32 = 0i;
    var jk: i32 = 0i;
    var zreflect: f32 = f32(0i);
    var ztdn: u32 = (W + bitcast<u32>((0i)));
    var r1: f32 = opq(fma(opq(f_rr_neg(bitcast<f32>(mem_ld((prefd + bitcast<u32>(((klev + 1i) - 1i))))), (*C).z0)), bitcast<f32>(mem_ld((prefd + bitcast<u32>((klev - 1i))))), opq(1.0f)));
    var r2: f32 = div_cr(1.0f, r1);
    zreflect = r2;
    var r3: f32 = opq((bitcast<f32>(mem_ld((ptra + bitcast<u32>((klev - 1i)))))) - (bitcast<f32>(mem_ld((pdbt + bitcast<u32>((klev - 1i)))))));
    var r5: f32 = opq((bitcast<f32>(mem_ld((pdbt + bitcast<u32>((klev - 1i)))))) * (bitcast<f32>(mem_ld((pref + bitcast<u32>(((klev + 1i) - 1i)))))));
    var r6: f32 = opq(fma(opq(r3), bitcast<f32>(mem_ld((prefd + bitcast<u32>(((klev + 1i) - 1i))))), opq(r5)));
    var r7: f32 = opq((bitcast<f32>(mem_ld((ptrad + bitcast<u32>((klev - 1i)))))) * (opq(r6)));
    var r9: f32 = opq(fma(opq(r7), opq(r2), bitcast<f32>(mem_ld((pref + bitcast<u32>((klev - 1i)))))));
    mem_st((prup + bitcast<u32>((klev - 1i))), bitcast<u32>(r9));
    var r10: f32 = opq((bitcast<f32>(mem_ld((ptrad + bitcast<u32>((klev - 1i)))))) * (bitcast<f32>(mem_ld((ptrad + bitcast<u32>((klev - 1i)))))));
    var r11: f32 = opq((opq(r10)) * (bitcast<f32>(mem_ld((prefd + bitcast<u32>(((klev + 1i) - 1i)))))));
    var r13: f32 = opq(fma(opq(r11), opq(r2), bitcast<f32>(mem_ld((prefd + bitcast<u32>((klev - 1i)))))));
    mem_st((prupd + bitcast<u32>((klev - 1i))), bitcast<u32>(r13));
    {
        jk = 1i;
        loop {
            if (!((jk <= (klev - 1i)))) { break; }
                ikp = ((klev + 1i) - jk);
                ikx = (ikp - 1i);
                var r15: f32 = opq(fma(opq(f_rr_neg(bitcast<f32>(mem_ld((prupd + bitcast<u32>((ikp - 1i))))), (*C).z0)), bitcast<f32>(mem_ld((prefd + bitcast<u32>((ikx - 1i))))), opq(1.0f)));
                var r16: f32 = div_cr(1.0f, r15);
                zreflect = r16;
                var r17: f32 = opq((bitcast<f32>(mem_ld((ptra + bitcast<u32>((ikx - 1i)))))) - (bitcast<f32>(mem_ld((pdbt + bitcast<u32>((ikx - 1i)))))));
                var r19: f32 = opq((bitcast<f32>(mem_ld((pdbt + bitcast<u32>((ikx - 1i)))))) * (bitcast<f32>(mem_ld((prup + bitcast<u32>((ikp - 1i)))))));
                var r20: f32 = opq(fma(opq(r17), bitcast<f32>(mem_ld((prupd + bitcast<u32>((ikp - 1i))))), opq(r19)));
                var r21: f32 = opq((bitcast<f32>(mem_ld((ptrad + bitcast<u32>((ikx - 1i)))))) * (opq(r20)));
                var r23: f32 = opq(fma(opq(r21), opq(r16), bitcast<f32>(mem_ld((pref + bitcast<u32>((ikx - 1i)))))));
                mem_st((prup + bitcast<u32>((ikx - 1i))), bitcast<u32>(r23));
                var r24: f32 = opq((bitcast<f32>(mem_ld((ptrad + bitcast<u32>((ikx - 1i)))))) * (bitcast<f32>(mem_ld((ptrad + bitcast<u32>((ikx - 1i)))))));
                var r25: f32 = opq((opq(r24)) * (bitcast<f32>(mem_ld((prupd + bitcast<u32>((ikp - 1i)))))));
                var r27: f32 = opq(fma(opq(r25), opq(r16), bitcast<f32>(mem_ld((prefd + bitcast<u32>((ikx - 1i)))))));
                mem_st((prupd + bitcast<u32>((ikx - 1i))), bitcast<u32>(r27));
            continuing {
                jk = (jk + 1i);
            }
        }
    }
    mem_st((ztdn + bitcast<u32>(((1i) - 1i))), bitcast<u32>(1.0f));
    mem_st((prdnd + bitcast<u32>(((1i) - 1i))), bitcast<u32>(0.0f));
    mem_st((ztdn + bitcast<u32>(((2i) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((ptra + bitcast<u32>(((1i) - 1i)))))));
    mem_st((prdnd + bitcast<u32>(((2i) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((prefd + bitcast<u32>(((1i) - 1i)))))));
    {
        jk = 2i;
        loop {
            if (!((jk <= klev))) { break; }
                ikp = (jk + 1i);
                var r29: f32 = opq(fma(opq(f_rr_neg(bitcast<f32>(mem_ld((prefd + bitcast<u32>((jk - 1i))))), (*C).z0)), bitcast<f32>(mem_ld((prdnd + bitcast<u32>((jk - 1i))))), opq(1.0f)));
                var r30: f32 = div_cr(1.0f, r29);
                zreflect = r30;
                var r32: f32 = opq((bitcast<f32>(mem_ld((ztdn + bitcast<u32>((jk - 1i)))))) - (bitcast<f32>(mem_ld((ptdbt + bitcast<u32>((jk - 1i)))))));
                var r33: f32 = opq((bitcast<f32>(mem_ld((ptdbt + bitcast<u32>((jk - 1i)))))) * (bitcast<f32>(mem_ld((pref + bitcast<u32>((jk - 1i)))))));
                var r35: f32 = opq(fma(opq(r33), bitcast<f32>(mem_ld((prdnd + bitcast<u32>((jk - 1i))))), opq(r32)));
                var r36: f32 = opq((bitcast<f32>(mem_ld((ptrad + bitcast<u32>((jk - 1i)))))) * (opq(r35)));
                var r37: f32 = opq((opq(r36)) * (opq(r30)));
                var r38: f32 = opq(fma(bitcast<f32>(mem_ld((ptdbt + bitcast<u32>((jk - 1i))))), bitcast<f32>(mem_ld((ptra + bitcast<u32>((jk - 1i))))), opq(r37)));
                mem_st((ztdn + bitcast<u32>((ikp - 1i))), bitcast<u32>(r38));
                var r39: f32 = opq((bitcast<f32>(mem_ld((ptrad + bitcast<u32>((jk - 1i)))))) * (bitcast<f32>(mem_ld((ptrad + bitcast<u32>((jk - 1i)))))));
                var r40: f32 = opq((opq(r39)) * (bitcast<f32>(mem_ld((prdnd + bitcast<u32>((jk - 1i)))))));
                var r42: f32 = opq(fma(opq(r40), opq(r30), bitcast<f32>(mem_ld((prefd + bitcast<u32>((jk - 1i)))))));
                mem_st((prdnd + bitcast<u32>((ikp - 1i))), bitcast<u32>(r42));
            continuing {
                jk = (jk + 1i);
            }
        }
    }
    {
        jk = 1i;
        loop {
            if (!((jk <= (klev + 1i)))) { break; }
                var r44: f32 = opq(fma(opq(f_rr_neg(bitcast<f32>(mem_ld((prdnd + bitcast<u32>((jk - 1i))))), (*C).z0)), bitcast<f32>(mem_ld((prupd + bitcast<u32>((jk - 1i))))), opq(1.0f)));
                var r45: f32 = div_cr(1.0f, r44);
                zreflect = r45;
                var r46: f32 = opq((bitcast<f32>(mem_ld((ptdbt + bitcast<u32>((jk - 1i)))))) * (bitcast<f32>(mem_ld((prup + bitcast<u32>((jk - 1i)))))));
                var r47: f32 = opq((bitcast<f32>(mem_ld((ztdn + bitcast<u32>((jk - 1i)))))) - (bitcast<f32>(mem_ld((ptdbt + bitcast<u32>((jk - 1i)))))));
                var r49: f32 = opq(fma(opq(r47), bitcast<f32>(mem_ld((prupd + bitcast<u32>((jk - 1i))))), opq(r46)));
                var r50: f32 = opq((opq(r49)) * (opq(r45)));
                mem_st((pfu + bitcast<u32>((jk - 1i))), bitcast<u32>(r50));
                var r52: f32 = opq(fma(opq(r46), bitcast<f32>(mem_ld((prdnd + bitcast<u32>((jk - 1i))))), opq(r47)));
                var r54: f32 = opq(fma(opq(r52), opq(r45), bitcast<f32>(mem_ld((ptdbt + bitcast<u32>((jk - 1i)))))));
                mem_st((pfd + bitcast<u32>((jk - 1i))), bitcast<u32>(r54));
            continuing {
                jk = (jk + 1i);
            }
        }
    }
}

fn lam_4(v_in: f32, dbg: u32, q: ptr<function, i32>) {
    var v: f32 = v_in;
    let _t1 = (*q);
    (*q) = ((*q) + 1i);
    let _t2 = _t1;
    mem_st((dbg + bitcast<u32>(_t2)), bitcast<u32>(v));
}

fn lam_5(a_in: u32, n_in: i32, dbg: u32, q: ptr<function, i32>) {
    var a: u32 = a_in;
    var n: i32 = n_in;
    {
        var i: i32 = 0i;
        loop {
            if (!((i < n))) { break; }
                let _t1 = (*q);
                (*q) = ((*q) + 1i);
                let _t2 = _t1;
                mem_st((dbg + bitcast<u32>(_t2)), bitcast<u32>(bitcast<f32>(mem_ld((a + bitcast<u32>(i))))));
            continuing {
                i = (i + 1i);
            }
        }
    }
}

fn lam_6(a_in: u32, n_in: i32, dbg: u32, q: ptr<function, i32>) {
    var a: u32 = a_in;
    var n: i32 = n_in;
    {
        var i: i32 = 0i;
        loop {
            if (!((i < n))) { break; }
                let _t1 = (*q);
                (*q) = ((*q) + 1i);
                let _t2 = _t1;
                mem_st((dbg + bitcast<u32>(_t2)), bitcast<u32>(f32(bitcast<i32>(mem_ld((a + bitcast<u32>(i)))))));
            continuing {
                i = (i + 1i);
            }
        }
    }
}

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    var P: S_RRSWParams = ld_RRSWParams(ARG[4]);
    var T: u32 = ARG[5];
    var G: u32 = ARG[6];
    var p8w: u32 = ARG[7];
    var p3d: u32 = ARG[8];
    var t3d: u32 = ARG[9];
    var t8w: u32 = ARG[10];
    var qv3d: u32 = ARG[11];
    var tsk: u32 = ARG[12];
    var albd: u32 = ARG[13];
    var scr: u32 = ARG[14];
    var iscr: u32 = ARG[15];
    var rthraten: u32 = ARG[16];
    var sfc: u32 = ARG[17];
    var stride: i32 = bitcast<i32>(mem_ld(ARG[18]));
    var qc3d: u32 = ARG[19];
    var qi3d: u32 = ARG[20];
    var qs3d: u32 = ARG[21];
    var cldfra3d: u32 = ARG[22];
    var effc: u32 = ARG[23];
    var effi: u32 = ARG[24];
    var effs: u32 = ARG[25];
    var xland: u32 = ARG[26];
    var fail: u32 = ARG[27];
    var coszen: u32 = ARG[28];
    var dbg: u32 = ARG[29];
    var tid: u32 = gid.x;
    if (((i32(tid)) >= P.ncol)) {
        return;
    }
    var c: i32 = (P.colOffset + (i32(tid)));
    var nk: i32 = P.nk;
    var nl: i32 = (nk + 1i);
    var coszrs: f32 = bitcast<f32>(mem_ld((coszen + bitcast<u32>(c))));
    if ((coszrs <= 0.0f)) {
        {
            var k: i32 = 1i;
            loop {
                if (!((k <= nk))) { break; }
                    mem_st((rthraten + bitcast<u32>((c + (stride * (k - 1i))))), bitcast<u32>(0.0f));
                continuing {
                    k = (k + 1i);
                }
            }
        }
        {
            var q: i32 = 0i;
            loop {
                if (!((q < 8i))) { break; }
                    mem_st((sfc + bitcast<u32>(((c * 8i) + q))), bitcast<u32>(0.0f));
                continuing {
                    q = (q + 1i);
                }
            }
        }
        return;
    }
    var S: u32 = (scr + bitcast<u32>(i32((tid * (u32(f_rrsw_ws_floats(nl)))))));
    var IS: u32 = (iscr + bitcast<u32>(i32((tid * (u32(f_rrsw_ws_ints(nl)))))));
    var o: i32 = 0i;
    var oi: i32 = 0i;
    var C: S_RRSWColumn = S_RRSWColumn();
    C.nlayers = nl;
    C.fail = 0i;
    C.laytrop = 0i;
    C.layswtch = 0i;
    C.laylow = 0i;
    C.z0 = P.zero;
    let _t1 = lam_1(nl, S, &o);
    C.pavel = _t1;
    let _t2 = lam_1(nl, S, &o);
    C.tavel = _t2;
    let _t3 = lam_1(nl, S, &o);
    C.coldry = _t3;
    let _t4 = lam_1(nl, S, &o);
    C.colh2o = _t4;
    let _t5 = lam_1(nl, S, &o);
    C.colco2 = _t5;
    let _t6 = lam_1(nl, S, &o);
    C.colo3 = _t6;
    let _t7 = lam_1(nl, S, &o);
    C.coln2o = _t7;
    let _t8 = lam_1(nl, S, &o);
    C.colch4 = _t8;
    let _t9 = lam_1(nl, S, &o);
    C.colo2 = _t9;
    let _t10 = lam_1(nl, S, &o);
    C.colmol = _t10;
    let _t11 = lam_1(nl, S, &o);
    C.co2mult = _t11;
    let _t12 = lam_1(nl, S, &o);
    C.fac00 = _t12;
    let _t13 = lam_1(nl, S, &o);
    C.fac01 = _t13;
    let _t14 = lam_1(nl, S, &o);
    C.fac10 = _t14;
    let _t15 = lam_1(nl, S, &o);
    C.fac11 = _t15;
    let _t16 = lam_1(nl, S, &o);
    C.selffac = _t16;
    let _t17 = lam_1(nl, S, &o);
    C.selffrac = _t17;
    let _t18 = lam_1(nl, S, &o);
    C.forfac = _t18;
    let _t19 = lam_1(nl, S, &o);
    C.forfrac = _t19;
    let _t20 = lam_1(nl, S, &o);
    C.reicmc = _t20;
    let _t21 = lam_1(nl, S, &o);
    C.relqmc = _t21;
    let _t22 = lam_1(nl, S, &o);
    C.resnmc = _t22;
    let _t23 = lam_1((nl + 1i), S, &o);
    C.pz = _t23;
    let _t24 = lam_1((nl + 1i), S, &o);
    C.tz = _t24;
    let _t25 = lam_1((7i * nl), S, &o);
    C.wkl = _t25;
    let _t26 = lam_1((112i * nl), S, &o);
    C.cldfmc = _t26;
    let _t27 = lam_1((112i * nl), S, &o);
    C.ciwpmc = _t27;
    let _t28 = lam_1((112i * nl), S, &o);
    C.clwpmc = _t28;
    let _t29 = lam_1((112i * nl), S, &o);
    C.cswpmc = _t29;
    let _t30 = lam_1((112i * nl), S, &o);
    C.taucmc = _t30;
    let _t31 = lam_1((112i * nl), S, &o);
    C.ssacmc = _t31;
    let _t32 = lam_1((112i * nl), S, &o);
    C.asmcmc = _t32;
    let _t33 = lam_1((112i * nl), S, &o);
    C.fsfcmc = _t33;
    let _t34 = lam_1((112i * nl), S, &o);
    C.taormc = _t34;
    let _t35 = lam_1((112i * nl), S, &o);
    C.taug = _t35;
    let _t36 = lam_1((112i * nl), S, &o);
    C.taur = _t36;
    let _t37 = lam_1(112i, S, &o);
    C.sfluxzen = _t37;
    let _t38 = lam_1(14i, S, &o);
    C.albdif = _t38;
    let _t39 = lam_1(14i, S, &o);
    C.albdir = _t39;
    let _t40 = lam_1(29i, S, &o);
    C.adjflux = _t40;
    let _t41 = lam_1((nl + 1i), S, &o);
    C.pbbfd = _t41;
    let _t42 = lam_1((nl + 1i), S, &o);
    C.pbbfu = _t42;
    let _t43 = lam_1((nl + 1i), S, &o);
    C.pbbcd = _t43;
    let _t44 = lam_1((nl + 1i), S, &o);
    C.pbbcu = _t44;
    let _t45 = lam_1((nl + 1i), S, &o);
    C.pbbfddir = _t45;
    let _t46 = lam_1((nl + 1i), S, &o);
    C.pbbcddir = _t46;
    let _t47 = lam_1((nl + 1i), S, &o);
    C.puvfd = _t47;
    let _t48 = lam_1((nl + 1i), S, &o);
    C.puvcd = _t48;
    let _t49 = lam_1((nl + 1i), S, &o);
    C.puvfddir = _t49;
    let _t50 = lam_1((nl + 1i), S, &o);
    C.puvcddir = _t50;
    let _t51 = lam_1((nl + 1i), S, &o);
    C.pnifd = _t51;
    let _t52 = lam_1((nl + 1i), S, &o);
    C.pnicd = _t52;
    let _t53 = lam_1((nl + 1i), S, &o);
    C.pnifddir = _t53;
    let _t54 = lam_1((nl + 1i), S, &o);
    C.pnicddir = _t54;
    let _t55 = lam_1(nl, S, &o);
    var play: u32 = _t55;
    let _t56 = lam_1(nl, S, &o);
    var tlay: u32 = _t56;
    let _t57 = lam_1(nl, S, &o);
    var pdel: u32 = _t57;
    let _t58 = lam_1(nl, S, &o);
    var h2ovmr: u32 = _t58;
    let _t59 = lam_1(nl, S, &o);
    var o3vmr: u32 = _t59;
    let _t60 = lam_1(nl, S, &o);
    var cldfrac: u32 = _t60;
    let _t61 = lam_1(nl, S, &o);
    var clwp: u32 = _t61;
    let _t62 = lam_1(nl, S, &o);
    var ciwp: u32 = _t62;
    let _t63 = lam_1(nl, S, &o);
    var cswp: u32 = _t63;
    let _t64 = lam_1(nl, S, &o);
    var rel: u32 = _t64;
    let _t65 = lam_1(nl, S, &o);
    var rei: u32 = _t65;
    let _t66 = lam_1(nl, S, &o);
    var res: u32 = _t66;
    let _t67 = lam_1(nl, S, &o);
    var qv1d: u32 = _t67;
    let _t68 = lam_1(nl, S, &o);
    var p1d: u32 = _t68;
    let _t69 = lam_1(nl, S, &o);
    var t1d: u32 = _t69;
    let _t70 = lam_1(nl, S, &o);
    var pdp: u32 = _t70;
    let _t71 = lam_1(nl, S, &o);
    var swhr: u32 = _t71;
    let _t72 = lam_1(nl, S, &o);
    var o3mmr: u32 = _t72;
    let _t73 = lam_1(nl, S, &o);
    var spare1: u32 = _t73;
    let _t74 = lam_1(nl, S, &o);
    var spare2: u32 = _t74;
    let _t75 = lam_1((nl + 1i), S, &o);
    var plev: u32 = _t75;
    let _t76 = lam_1((nl + 1i), S, &o);
    var tlev: u32 = _t76;
    var W: u32 = (S + bitcast<u32>(o));
    let _t77 = lam_2(nl, IS, &oi);
    C.jp = _t77;
    let _t78 = lam_2(nl, IS, &oi);
    C.jt = _t78;
    let _t79 = lam_2(nl, IS, &oi);
    C.jt1 = _t79;
    let _t80 = lam_2(nl, IS, &oi);
    C.indself = _t80;
    let _t81 = lam_2(nl, IS, &oi);
    C.indfor = _t81;
    var WI: u32 = (IS + bitcast<u32>(oi));
    oi = (oi + (2i * nl));
    var cloudy: u32 = (IS + bitcast<u32>(oi));
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= nk))) { break; }
                var q: f32 = opq(max(0.0f, bitcast<f32>(mem_ld((qv3d + bitcast<u32>((c + (stride * (k - 1i)))))))));
                mem_st((qv1d + bitcast<u32>((k - 1i))), bitcast<u32>(opq(max(q, 1e-12f))));
                mem_st((t1d + bitcast<u32>((k - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((t3d + bitcast<u32>((c + (stride * (k - 1i)))))))));
                mem_st((p1d + bitcast<u32>((k - 1i))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((p3d + bitcast<u32>((c + (stride * (k - 1i))))))), 1e+02f)));
            continuing {
                k = (k + 1i);
            }
        }
    }
    mem_st((plev + bitcast<u32>(((1i) - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((p8w + bitcast<u32>((c + (stride * ((1i) - 1i)))))))) * (opq(0.01f)))));
    mem_st((tlev + bitcast<u32>(((1i) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((t8w + bitcast<u32>((c + (stride * ((1i) - 1i)))))))));
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= nk))) { break; }
                mem_st((play + bitcast<u32>((k - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((p1d + bitcast<u32>((k - 1i)))))));
                mem_st((plev + bitcast<u32>(((k + 1i) - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((p8w + bitcast<u32>((c + (stride * ((k + 1i) - 1i)))))))) * (opq(0.01f)))));
                mem_st((pdel + bitcast<u32>((k - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((plev + bitcast<u32>((k - 1i)))))) - (bitcast<f32>(mem_ld((plev + bitcast<u32>(((k + 1i) - 1i)))))))));
                mem_st((tlay + bitcast<u32>((k - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((t1d + bitcast<u32>((k - 1i)))))));
                mem_st((tlev + bitcast<u32>(((k + 1i) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((t8w + bitcast<u32>((c + (stride * ((k + 1i) - 1i)))))))));
                mem_st((h2ovmr + bitcast<u32>((k - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((qv1d + bitcast<u32>((k - 1i)))))) * (opq(K_RS_AMDW)))));
            continuing {
                k = (k + 1i);
            }
        }
    }
    mem_st((play + bitcast<u32>(((nk + 1i) - 1i))), bitcast<u32>(opq((opq(0.5f)) * (bitcast<f32>(mem_ld((plev + bitcast<u32>(((nk + 1i) - 1i)))))))));
    mem_st((tlay + bitcast<u32>(((nk + 1i) - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((tlev + bitcast<u32>(((nk + 1i) - 1i)))))) + (opq(0.0f)))));
    mem_st((plev + bitcast<u32>(((nk + 2i) - 1i))), bitcast<u32>(1e-05f));
    mem_st((tlev + bitcast<u32>(((nk + 2i) - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((tlev + bitcast<u32>(((nk + 1i) - 1i)))))) + (opq(0.0f)))));
    mem_st((h2ovmr + bitcast<u32>(((nk + 1i) - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((h2ovmr + bitcast<u32>((nk - 1i)))))));
    {
        var K: i32 = 1i;
        loop {
            if (!((K <= nl))) { break; }
                var acc: f32 = 0.0f;
                {
                    var JJ: i32 = 1i;
                    loop {
                        if (!((JJ <= 31i))) { break; }
                            var h1: f32 = bitcast<f32>(mem_ld((G + bitcast<u32>(((33123i + JJ) - 1i)))));
                            var h2: f32 = bitcast<f32>(mem_ld((G + bitcast<u32>((33123i + JJ)))));
                            var pb1: f32 = select(opq((bitcast<f32>(mem_ld((plev + bitcast<u32>((K - 1i)))))) - (opq(h1))), 0.0f, ((opq((-(opq((bitcast<f32>(mem_ld((plev + bitcast<u32>((K - 1i)))))) - (opq(h1))))))) >= 0.0f));
                            var pb2: f32 = select(opq((bitcast<f32>(mem_ld((plev + bitcast<u32>((K - 1i)))))) - (opq(h2))), 0.0f, ((opq((-(opq((bitcast<f32>(mem_ld((plev + bitcast<u32>((K - 1i)))))) - (opq(h2))))))) >= 0.0f));
                            var pt1: f32 = select(opq((bitcast<f32>(mem_ld((plev + bitcast<u32>(((K + 1i) - 1i)))))) - (opq(h1))), 0.0f, ((opq((-(opq((bitcast<f32>(mem_ld((plev + bitcast<u32>(((K + 1i) - 1i)))))) - (opq(h1))))))) >= 0.0f));
                            var pt2: f32 = select(opq((bitcast<f32>(mem_ld((plev + bitcast<u32>(((K + 1i) - 1i)))))) - (opq(h2))), 0.0f, ((opq((-(opq((bitcast<f32>(mem_ld((plev + bitcast<u32>(((K + 1i) - 1i)))))) - (opq(h2))))))) >= 0.0f));
                            acc = opq(fma((opq((opq((opq((opq(pb2)) - (opq(pb1)))) - (opq(pt2)))) + (opq(pt1)))), bitcast<f32>(mem_ld((G + bitcast<u32>(((33092i + JJ) - 1i))))), opq(acc)));
                        continuing {
                            JJ = (JJ + 1i);
                        }
                    }
                }
                mem_st((o3mmr + bitcast<u32>((K - 1i))), bitcast<u32>(div_cr(acc, (opq((bitcast<f32>(mem_ld((plev + bitcast<u32>((K - 1i)))))) - (bitcast<f32>(mem_ld((plev + bitcast<u32>(((K + 1i) - 1i)))))))))));
                mem_st((o3vmr + bitcast<u32>((K - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((o3mmr + bitcast<u32>((K - 1i)))))) * (opq(K_RS_AMDO)))));
            continuing {
                K = (K + 1i);
            }
        }
    }
    var xl: f32 = bitcast<f32>(mem_ld((xland + bitcast<u32>(c))));
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= nk))) { break; }
                var cf: f32 = bitcast<f32>(mem_ld((cldfra3d + bitcast<u32>((c + (stride * (k - 1i)))))));
                var qc: f32 = opq(max(0.0f, bitcast<f32>(mem_ld((qc3d + bitcast<u32>((c + (stride * (k - 1i)))))))));
                var qi: f32 = opq(max(0.0f, bitcast<f32>(mem_ld((qi3d + bitcast<u32>((c + (stride * (k - 1i)))))))));
                var qs: f32 = opq(max(0.0f, bitcast<f32>(mem_ld((qs3d + bitcast<u32>((c + (stride * (k - 1i)))))))));
                var rc: f32 = opq(max(2.5f, opq((bitcast<f32>(mem_ld((effc + bitcast<u32>((c + (stride * (k - 1i)))))))) * (opq(1e+06f)))));
                if ((((rc <= 2.5f) && (cf > 0.0f)) && ((opq((opq(xl)) - (opq(1.5f)))) > 0.0f))) {
                    rc = 10.5f;
                } else {
                    if ((((rc <= 2.5f) && (cf > 0.0f)) && ((opq((opq(xl)) - (opq(1.5f)))) < 0.0f))) {
                        rc = 7.5f;
                    }
                }
                var ri: f32 = opq(max(5.0f, opq((bitcast<f32>(mem_ld((effi + bitcast<u32>((c + (stride * (k - 1i)))))))) * (opq(1e+06f)))));
                if (((ri <= 5.0f) && (cf > 0.0f))) {
                    var tk: f32 = bitcast<f32>(mem_ld((t3d + bitcast<u32>((c + (stride * (k - 1i)))))));
                    var idx: i32 = i32(opq((opq(tk)) - (opq(179.0f))));
                    idx = min(max(idx, 1i), 75i);
                    var corr: f32 = opq((opq(tk)) - (opq(f32(i32(tk)))));
                    ri = opq(fma(bitcast<f32>(mem_ld((G + bitcast<u32>(((33275i + idx) - 1i))))), opq((opq(1.0f)) - (opq(corr))), opq((bitcast<f32>(mem_ld((G + bitcast<u32>((33275i + idx)))))) * (opq(corr)))));
                    ri = opq(max(ri, 5.0f));
                }
                var rs: f32 = opq(max(1e+01f, opq((bitcast<f32>(mem_ld((effs + bitcast<u32>((c + (stride * (k - 1i)))))))) * (opq(1e+06f)))));
                mem_st((cldfrac + bitcast<u32>((k - 1i))), bitcast<u32>(cf));
                var gravmks: f32 = 9.81f;
                var denom: f32 = opq(max(0.01f, cf));
                var gliqwp: f32 = opq((opq(div_cr(opq((opq((opq(qc)) * (bitcast<f32>(mem_ld((pdel + bitcast<u32>((k - 1i)))))))) * (opq(1e+02f))), gravmks))) * (opq(1e+03f)));
                var gicewp: f32 = opq((opq(div_cr(opq((opq((opq(qi)) * (bitcast<f32>(mem_ld((pdel + bitcast<u32>((k - 1i)))))))) * (opq(1e+02f))), gravmks))) * (opq(1e+03f)));
                mem_st((clwp + bitcast<u32>((k - 1i))), bitcast<u32>(div_cr(gliqwp, denom)));
                mem_st((ciwp + bitcast<u32>((k - 1i))), bitcast<u32>(div_cr(gicewp, denom)));
                var smf: f32 = 1.0f;
                if ((rs > (1.3e+02f))) {
                    smf = opq((opq((div_cr(1.3e+02f, rs)))) * (opq((div_cr(1.3e+02f, rs)))));
                    rs = 1.3e+02f;
                }
                var gsnowp: f32 = opq((opq(div_cr(opq((opq((opq((opq(qs)) * (opq(smf)))) * (bitcast<f32>(mem_ld((pdel + bitcast<u32>((k - 1i)))))))) * (opq(1e+02f))), gravmks))) * (opq(1e+03f)));
                mem_st((cswp + bitcast<u32>((k - 1i))), bitcast<u32>(div_cr(gsnowp, denom)));
                mem_st((rel + bitcast<u32>((k - 1i))), bitcast<u32>(rc));
                mem_st((rei + bitcast<u32>((k - 1i))), bitcast<u32>(ri));
                mem_st((res + bitcast<u32>((k - 1i))), bitcast<u32>(rs));
            continuing {
                k = (k + 1i);
            }
        }
    }
    mem_st((clwp + bitcast<u32>((nl - 1i))), bitcast<u32>(0.0f));
    mem_st((ciwp + bitcast<u32>((nl - 1i))), bitcast<u32>(0.0f));
    mem_st((cswp + bitcast<u32>((nl - 1i))), bitcast<u32>(0.0f));
    mem_st((rel + bitcast<u32>((nl - 1i))), bitcast<u32>(1e+01f));
    mem_st((rei + bitcast<u32>((nl - 1i))), bitcast<u32>(1e+01f));
    mem_st((res + bitcast<u32>((nl - 1i))), bitcast<u32>(1e+01f));
    mem_st((cldfrac + bitcast<u32>((nl - 1i))), bitcast<u32>(0.0f));
    {
        var sd: array<u32, 4>;
        {
            var q: i32 = 0i;
            loop {
                if (!((q < 4i))) { break; }
                    var pm: f32 = opq((bitcast<f32>(mem_ld((play + bitcast<u32>(((q + 1i) - 1i)))))) * (opq(1e+02f)));
                    (*&sd)[q] = u32(i32(opq((opq((opq(pm)) - (opq(f32(i32(pm)))))) * (opq(1e+09f)))));
                continuing {
                    q = (q + 1i);
                }
            }
        }
        _ = lam_3(&sd);
        {
            var w: i32 = 0i;
            loop {
                if (!((w < (f_rrsw_cloud_words(nl))))) { break; }
                    mem_st((cloudy + bitcast<u32>(w)), 0u);
                continuing {
                    w = (w + 1i);
                }
            }
        }
        {
            var sub: i32 = 1i;
            loop {
                if (!((sub <= 112i))) { break; }
                    var prev: f32 = 0.0f;
                    {
                        var lev: i32 = 1i;
                        loop {
                            if (!((lev <= nl))) { break; }
                                var cdf: f32 = lam_3(&sd);
                                var cfl: f32 = select(bitcast<f32>(mem_ld((cldfrac + bitcast<u32>((lev - 1i))))), 0.0f, ((bitcast<f32>(mem_ld((cldfrac + bitcast<u32>((lev - 1i)))))) < (1e-20f)));
                                if ((lev > 1i)) {
                                    var cfp: f32 = select(bitcast<f32>(mem_ld((cldfrac + bitcast<u32>(((lev - 1i) - 1i))))), 0.0f, ((bitcast<f32>(mem_ld((cldfrac + bitcast<u32>(((lev - 1i) - 1i)))))) < (1e-20f)));
                                    if ((prev > (opq((opq(1.0f)) - (opq(cfp)))))) {
                                        cdf = prev;
                                    } else {
                                        cdf = opq((opq(cdf)) * (opq((opq(1.0f)) - (opq(cfp)))));
                                    }
                                }
                                if ((cdf >= (opq((opq(1.0f)) - (opq(cfl)))))) {
                                    var bit: i32 = (((sub - 1i) * nl) + (lev - 1i));
                                    mem_st((cloudy + bitcast<u32>((bit >> u32(5i)))), ((mem_ld((cloudy + bitcast<u32>((bit >> u32(5i)))))) | (1u << u32((bit & 31i)))));
                                }
                                prev = cdf;
                            continuing {
                                lev = (lev + 1i);
                            }
                        }
                    }
                continuing {
                    sub = (sub + 1i);
                }
            }
        }
    }
    {
        var ib: i32 = 16i;
        loop {
            if (!((ib <= 29i))) { break; }
                var solvar: f32 = div_cr(P.scon, K_RS_SCON);
                mem_st((C.adjflux + bitcast<u32>((ib - 1i))), bitcast<u32>(solvar));
            continuing {
                ib = (ib + 1i);
            }
        }
    }
    C.tbound = bitcast<f32>(mem_ld((tsk + bitcast<u32>(c))));
    mem_st((C.pz + bitcast<u32>((0i))), bitcast<u32>(bitcast<f32>(mem_ld((plev + bitcast<u32>(((1i) - 1i)))))));
    mem_st((C.tz + bitcast<u32>((0i))), bitcast<u32>(bitcast<f32>(mem_ld((tlev + bitcast<u32>(((1i) - 1i)))))));
    {
        var l: i32 = 1i;
        loop {
            if (!((l <= nl))) { break; }
                mem_st((C.pavel + bitcast<u32>((l - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((play + bitcast<u32>((l - 1i)))))));
                mem_st((C.tavel + bitcast<u32>((l - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((tlay + bitcast<u32>((l - 1i)))))));
                mem_st((C.pz + bitcast<u32>(l)), bitcast<u32>(bitcast<f32>(mem_ld((plev + bitcast<u32>(((l + 1i) - 1i)))))));
                mem_st((C.tz + bitcast<u32>(l)), bitcast<u32>(bitcast<f32>(mem_ld((tlev + bitcast<u32>(((l + 1i) - 1i)))))));
                mem_st((pdp + bitcast<u32>((l - 1i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((C.pz + bitcast<u32>((l - 1i)))))) - (bitcast<f32>(mem_ld((C.pz + bitcast<u32>(l))))))));
                mem_st((C.wkl + bitcast<u32>((((1i) - 1i) + (7i * (l - 1i))))), bitcast<u32>(bitcast<f32>(mem_ld((h2ovmr + bitcast<u32>((l - 1i)))))));
                mem_st((C.wkl + bitcast<u32>((((2i) - 1i) + (7i * (l - 1i))))), bitcast<u32>(P.co2));
                mem_st((C.wkl + bitcast<u32>((((3i) - 1i) + (7i * (l - 1i))))), bitcast<u32>(bitcast<f32>(mem_ld((o3vmr + bitcast<u32>((l - 1i)))))));
                mem_st((C.wkl + bitcast<u32>((((4i) - 1i) + (7i * (l - 1i))))), bitcast<u32>(K_RS_N2O));
                mem_st((C.wkl + bitcast<u32>((((5i) - 1i) + (7i * (l - 1i))))), bitcast<u32>(0.0f));
                mem_st((C.wkl + bitcast<u32>((((6i) - 1i) + (7i * (l - 1i))))), bitcast<u32>(K_RS_CH4));
                mem_st((C.wkl + bitcast<u32>((((7i) - 1i) + (7i * (l - 1i))))), bitcast<u32>(K_RS_O2));
                var amm: f32 = opq(fma(opq((opq(1.0f)) - (bitcast<f32>(mem_ld((C.wkl + bitcast<u32>((((1i) - 1i) + (7i * (l - 1i))))))))), opq(K_RS_AMD), opq((bitcast<f32>(mem_ld((C.wkl + bitcast<u32>((((1i) - 1i) + (7i * (l - 1i)))))))) * (opq(K_RS_AMW)))));
                mem_st((C.coldry + bitcast<u32>((l - 1i))), bitcast<u32>(div_cr(opq((opq((opq((bitcast<f32>(mem_ld((C.pz + bitcast<u32>((l - 1i)))))) - (bitcast<f32>(mem_ld((C.pz + bitcast<u32>(l))))))) * (opq(1e+03f)))) * (opq(K_RS_AVOGAD))), (opq((opq((opq((opq(1e+02f)) * (opq(K_RS_GRAV)))) * (opq(amm)))) * (opq((opq(1.0f)) + (bitcast<f32>(mem_ld((C.wkl + bitcast<u32>((((1i) - 1i) + (7i * (l - 1i)))))))))))))));
            continuing {
                l = (l + 1i);
            }
        }
    }
    {
        var l: i32 = 1i;
        loop {
            if (!((l <= nl))) { break; }
                {
                    var imol: i32 = 1i;
                    loop {
                        if (!((imol <= 7i))) { break; }
                            mem_st((C.wkl + bitcast<u32>(((imol - 1i) + (7i * (l - 1i))))), bitcast<u32>(opq((bitcast<f32>(mem_ld((C.coldry + bitcast<u32>((l - 1i)))))) * (bitcast<f32>(mem_ld((C.wkl + bitcast<u32>(((imol - 1i) + (7i * (l - 1i)))))))))));
                        continuing {
                            imol = (imol + 1i);
                        }
                    }
                }
            continuing {
                l = (l + 1i);
            }
        }
    }
    {
        var l: i32 = 1i;
        loop {
            if (!((l <= nl))) { break; }
                {
                    var ig: i32 = 1i;
                    loop {
                        if (!((ig <= 112i))) { break; }
                            var at: i32 = ((ig - 1i) + (112i * (l - 1i)));
                            var cl: bool = ((((mem_ld((cloudy + bitcast<u32>(((((ig - 1i) * nl) + (l - 1i)) >> u32(5i)))))) >> u32(((((ig - 1i) * nl) + (l - 1i)) & 31i))) & 1u) != 0u);
                            mem_st((C.cldfmc + bitcast<u32>(at)), bitcast<u32>(select(0.0f, 1.0f, cl)));
                            mem_st((C.clwpmc + bitcast<u32>(at)), bitcast<u32>(select(0.0f, bitcast<f32>(mem_ld((clwp + bitcast<u32>((l - 1i))))), cl)));
                            mem_st((C.ciwpmc + bitcast<u32>(at)), bitcast<u32>(select(0.0f, bitcast<f32>(mem_ld((ciwp + bitcast<u32>((l - 1i))))), cl)));
                            mem_st((C.cswpmc + bitcast<u32>(at)), bitcast<u32>(select(0.0f, bitcast<f32>(mem_ld((cswp + bitcast<u32>((l - 1i))))), cl)));
                            mem_st((C.taucmc + bitcast<u32>(at)), bitcast<u32>(0.0f));
                            mem_st((C.ssacmc + bitcast<u32>(at)), bitcast<u32>(1.0f));
                            mem_st((C.asmcmc + bitcast<u32>(at)), bitcast<u32>(0.0f));
                            mem_st((C.fsfcmc + bitcast<u32>(at)), bitcast<u32>(0.0f));
                        continuing {
                            ig = (ig + 1i);
                        }
                    }
                }
                mem_st((C.reicmc + bitcast<u32>((l - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((rei + bitcast<u32>((l - 1i)))))));
                mem_st((C.relqmc + bitcast<u32>((l - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((rel + bitcast<u32>((l - 1i)))))));
                mem_st((C.resnmc + bitcast<u32>((l - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((res + bitcast<u32>((l - 1i)))))));
            continuing {
                l = (l + 1i);
            }
        }
    }
    f_rrsw_cldprmc_sw(&C, T, W, WI);
    if ((C.fail != 0i)) {
        _ = atomicAdd(&M[fail], 1u);
        return;
    }
    f_rrsw_setcoef_sw(&C, T, W, WI);
    C.cossza = coszrs;
    if ((C.cossza <= (1e-10f))) {
        C.cossza = 1e-10f;
    }
    {
        var ib: i32 = 1i;
        loop {
            if (!((ib <= 14i))) { break; }
                mem_st((C.albdir + bitcast<u32>((ib - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((albd + bitcast<u32>(c))))));
                mem_st((C.albdif + bitcast<u32>((ib - 1i))), bitcast<u32>(bitcast<f32>(mem_ld((albd + bitcast<u32>(c))))));
            continuing {
                ib = (ib + 1i);
            }
        }
    }
    f_rrsw_spcvmc_sw(&C, T, W, WI);
    if ((C.fail != 0i)) {
        _ = atomicAdd(&M[fail], 1u);
        return;
    }
    {
        var i: i32 = 1i;
        loop {
            if (!((i <= nl))) { break; }
                var zdpgcp: f32 = div_cr(P.heatfac, bitcast<f32>(mem_ld((pdp + bitcast<u32>((i - 1i))))));
                var n1: f32 = opq((bitcast<f32>(mem_ld((C.pbbfd + bitcast<u32>(((i + 1i) - 1i)))))) - (bitcast<f32>(mem_ld((C.pbbfu + bitcast<u32>(((i + 1i) - 1i)))))));
                var n0: f32 = opq((bitcast<f32>(mem_ld((C.pbbfd + bitcast<u32>((i - 1i)))))) - (bitcast<f32>(mem_ld((C.pbbfu + bitcast<u32>((i - 1i)))))));
                mem_st((swhr + bitcast<u32>((i - 1i))), bitcast<u32>(opq((opq((opq(n1)) - (opq(n0)))) * (opq(zdpgcp)))));
            continuing {
                i = (i + 1i);
            }
        }
    }
    mem_st((swhr + bitcast<u32>((nl - 1i))), bitcast<u32>(0.0f));
    {
        var k: i32 = 1i;
        loop {
            if (!((k <= nk))) { break; }
                mem_st((rthraten + bitcast<u32>((c + (stride * (k - 1i))))), bitcast<u32>(div_cr(bitcast<f32>(mem_ld((swhr + bitcast<u32>((k - 1i))))), 8.64e+04f)));
            continuing {
                k = (k + 1i);
            }
        }
    }
    mem_st((sfc + bitcast<u32>(((c * 8i) + 0i))), bitcast<u32>(opq((bitcast<f32>(mem_ld((C.pbbfd + bitcast<u32>(((1i) - 1i)))))) - (bitcast<f32>(mem_ld((C.pbbfu + bitcast<u32>(((1i) - 1i)))))))));
    mem_st((sfc + bitcast<u32>(((c * 8i) + 1i))), bitcast<u32>(bitcast<f32>(mem_ld((C.pbbfu + bitcast<u32>(((nk + 2i) - 1i)))))));
    mem_st((sfc + bitcast<u32>(((c * 8i) + 2i))), bitcast<u32>(bitcast<f32>(mem_ld((C.pbbfd + bitcast<u32>(((nk + 2i) - 1i)))))));
    mem_st((sfc + bitcast<u32>(((c * 8i) + 3i))), bitcast<u32>(bitcast<f32>(mem_ld((C.pbbfu + bitcast<u32>(((1i) - 1i)))))));
    mem_st((sfc + bitcast<u32>(((c * 8i) + 4i))), bitcast<u32>(bitcast<f32>(mem_ld((C.pbbfd + bitcast<u32>(((1i) - 1i)))))));
    mem_st((sfc + bitcast<u32>(((c * 8i) + 5i))), bitcast<u32>(0.0f));
    mem_st((sfc + bitcast<u32>(((c * 8i) + 6i))), bitcast<u32>(0.0f));
    mem_st((sfc + bitcast<u32>(((c * 8i) + 7i))), bitcast<u32>(0.0f));
    if ((c == P.debugCol)) {
        var q: i32 = 0i;
        lam_4(f32(nl), dbg, &q);
        lam_4(f32(C.laytrop), dbg, &q);
        lam_4(C.cossza, dbg, &q);
        lam_5((C.adjflux + bitcast<u32>(15i)), 14i, dbg, &q);
        lam_5(C.albdir, 14i, dbg, &q);
        lam_5(C.pavel, nl, dbg, &q);
        lam_5(C.tavel, nl, dbg, &q);
        lam_5(C.pz, (nl + 1i), dbg, &q);
        lam_5(C.coldry, nl, dbg, &q);
        lam_5(C.wkl, (7i * nl), dbg, &q);
        lam_6(C.jp, nl, dbg, &q);
        lam_6(C.jt, nl, dbg, &q);
        lam_6(C.jt1, nl, dbg, &q);
        lam_5(C.fac00, nl, dbg, &q);
        lam_5(C.fac01, nl, dbg, &q);
        lam_5(C.fac10, nl, dbg, &q);
        lam_5(C.fac11, nl, dbg, &q);
        lam_5(C.colh2o, nl, dbg, &q);
        lam_5(C.colco2, nl, dbg, &q);
        lam_5(C.colo3, nl, dbg, &q);
        lam_5(C.colch4, nl, dbg, &q);
        lam_5(C.colo2, nl, dbg, &q);
        lam_5(C.colmol, nl, dbg, &q);
        lam_5(C.selffac, nl, dbg, &q);
        lam_5(C.selffrac, nl, dbg, &q);
        lam_6(C.indself, nl, dbg, &q);
        lam_5(C.forfac, nl, dbg, &q);
        lam_5(C.forfrac, nl, dbg, &q);
        lam_6(C.indfor, nl, dbg, &q);
        lam_5(C.cldfmc, (112i * nl), dbg, &q);
        lam_5(C.ciwpmc, (112i * nl), dbg, &q);
        lam_5(C.clwpmc, (112i * nl), dbg, &q);
        lam_5(C.cswpmc, (112i * nl), dbg, &q);
        lam_5(C.taucmc, (112i * nl), dbg, &q);
        lam_5(C.taormc, (112i * nl), dbg, &q);
        lam_5(C.ssacmc, (112i * nl), dbg, &q);
        lam_5(C.asmcmc, (112i * nl), dbg, &q);
        lam_5(C.reicmc, nl, dbg, &q);
        lam_5(C.relqmc, nl, dbg, &q);
        lam_5(C.resnmc, nl, dbg, &q);
        lam_5(C.pbbfd, (nl + 1i), dbg, &q);
        lam_5(C.pbbfu, (nl + 1i), dbg, &q);
        lam_5(C.pbbcd, (nl + 1i), dbg, &q);
        lam_5(C.pbbcu, (nl + 1i), dbg, &q);
        lam_5(swhr, nl, dbg, &q);
        {
            var l: i32 = 1i;
            loop {
                if (!((l <= nl))) { break; }
                    {
                        var g: i32 = 1i;
                        loop {
                            if (!((g <= 112i))) { break; }
                                lam_4(bitcast<f32>(mem_ld((C.taug + bitcast<u32>(((l - 1i) + (nl * (g - 1i))))))), dbg, &q);
                            continuing {
                                g = (g + 1i);
                            }
                        }
                    }
                continuing {
                    l = (l + 1i);
                }
            }
        }
        {
            var l: i32 = 1i;
            loop {
                if (!((l <= nl))) { break; }
                    {
                        var g: i32 = 1i;
                        loop {
                            if (!((g <= 112i))) { break; }
                                lam_4(bitcast<f32>(mem_ld((C.taur + bitcast<u32>(((l - 1i) + (nl * (g - 1i))))))), dbg, &q);
                            continuing {
                                g = (g + 1i);
                            }
                        }
                    }
                continuing {
                    l = (l + 1i);
                }
            }
        }
        lam_5(C.sfluxzen, 112i, dbg, &q);
    }
}
