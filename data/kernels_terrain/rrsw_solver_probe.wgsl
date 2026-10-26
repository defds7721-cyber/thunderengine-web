// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// rrsw_solver_probe: сгенерировано, не править руками.

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

fn f_rr_neg(x_in: f32, z0_in: u32) -> f32 {
    var x: f32 = x_in;
    var z0: u32 = z0_in;
    return bitcast<f32>(((bitcast<u32>(x)) ^ (2147483648u ^ z0)));
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

override WGX: u32 = 1u;
override WGY: u32 = 1u;
override WGZ: u32 = 1u;

@compute @workgroup_size(WGX, WGY, WGZ)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x >= ARG[0] || gid.y >= ARG[1] || gid.z >= ARG[2]) { return; }
    Z0 = ARG[3];
    var nl: i32 = bitcast<i32>(mem_ld(ARG[4]));
    var prmu0: f32 = bitcast<f32>(mem_ld(ARG[5]));
    var T: u32 = ARG[6];
    var in: u32 = ARG[7];
    var out: u32 = ARG[8];
    var ws: u32 = ARG[9];
    var wsi: u32 = ARG[10];
    var ncase: i32 = bitcast<i32>(mem_ld(ARG[11]));
    var zero: u32 = mem_ld(ARG[12]);
    var tid: u32 = gid.x;
    if (((i32(tid)) >= ncase)) {
        return;
    }
    var inN: i32 = (((4i * nl) + 2i) + (2i * (nl + 1i)));
    var outN: i32 = (6i * (nl + 1i));
    var x: u32 = (in + bitcast<u32>(i32((tid * (u32(inN))))));
    var y: u32 = (out + bitcast<u32>(i32((tid * (u32(outN))))));
    var W: u32 = (ws + bitcast<u32>(i32((tid * (u32((12i * (nl + 1i))))))));
    var WI: u32 = (wsi + bitcast<u32>(i32((tid * (u32(nl))))));
    var C: S_RRSWColumn = S_RRSWColumn();
    C.nlayers = nl;
    C.fail = 0i;
    C.z0 = zero;
    var ztau: u32 = W;
    var zomc: u32 = (W + bitcast<u32>(nl));
    var zg: u32 = (W + bitcast<u32>((2i * nl)));
    var pref: u32 = y;
    var prefd: u32 = (y + bitcast<u32>((nl + 1i)));
    var ptra: u32 = (y + bitcast<u32>((2i * (nl + 1i))));
    var ptrad: u32 = (y + bitcast<u32>((3i * (nl + 1i))));
    var pfd: u32 = (y + bitcast<u32>((4i * (nl + 1i))));
    var pfu: u32 = (y + bitcast<u32>((5i * (nl + 1i))));
    var ztdbt: u32 = (W + bitcast<u32>((3i * nl)));
    var zdbt: u32 = ((W + bitcast<u32>((3i * nl))) + bitcast<u32>((nl + 1i)));
    var rdnd: u32 = ((W + bitcast<u32>((3i * nl))) + bitcast<u32>((2i * (nl + 1i))));
    var rup: u32 = ((W + bitcast<u32>((3i * nl))) + bitcast<u32>((3i * (nl + 1i))));
    var rupd: u32 = ((W + bitcast<u32>((3i * nl))) + bitcast<u32>((4i * (nl + 1i))));
    var W2: u32 = ((W + bitcast<u32>((3i * nl))) + bitcast<u32>((5i * (nl + 1i))));
    {
        var i: i32 = 0i;
        loop {
            if (!((i < nl))) { break; }
                mem_st((ztau + bitcast<u32>(i)), bitcast<u32>(bitcast<f32>(mem_ld((x + bitcast<u32>(i))))));
                mem_st((zomc + bitcast<u32>(i)), bitcast<u32>(bitcast<f32>(mem_ld((x + bitcast<u32>((nl + i)))))));
                mem_st((zg + bitcast<u32>(i)), bitcast<u32>(bitcast<f32>(mem_ld((x + bitcast<u32>(((2i * nl) + i)))))));
                mem_st((WI + bitcast<u32>(i)), bitcast<u32>(select(0i, 1i, ((bitcast<f32>(mem_ld((x + bitcast<u32>(((3i * nl) + i)))))) > 0.5f))));
            continuing {
                i = (i + 1i);
            }
        }
    }
    var albp: f32 = bitcast<f32>(mem_ld((x + bitcast<u32>((4i * nl)))));
    var albd: f32 = bitcast<f32>(mem_ld((x + bitcast<u32>(((4i * nl) + 1i)))));
    {
        var i: i32 = 0i;
        loop {
            if (!((i <= nl))) { break; }
                mem_st((ztdbt + bitcast<u32>(i)), bitcast<u32>(bitcast<f32>(mem_ld((x + bitcast<u32>((((4i * nl) + 2i) + i)))))));
                mem_st((zdbt + bitcast<u32>(i)), bitcast<u32>(bitcast<f32>(mem_ld((x + bitcast<u32>(((((4i * nl) + 2i) + (nl + 1i)) + i)))))));
            continuing {
                i = (i + 1i);
            }
        }
    }
    f_rrsw_reftra_sw(&C, T, W2, WI, WI, zg, prmu0, ztau, zomc, pref, prefd, ptra, ptrad);
    mem_st((pref + bitcast<u32>(nl)), bitcast<u32>(albp));
    mem_st((prefd + bitcast<u32>(nl)), bitcast<u32>(albd));
    mem_st((ptra + bitcast<u32>(nl)), bitcast<u32>(0.0f));
    mem_st((ptrad + bitcast<u32>(nl)), bitcast<u32>(0.0f));
    mem_st((rup + bitcast<u32>(nl)), bitcast<u32>(albp));
    mem_st((rupd + bitcast<u32>(nl)), bitcast<u32>(albd));
    mem_st((zdbt + bitcast<u32>(nl)), bitcast<u32>(0.0f));
    f_rrsw_vrtqdr_sw(&C, T, W2, WI, nl, 1i, pref, prefd, ptra, ptrad, zdbt, rdnd, rup, rupd, ztdbt, pfd, pfu);
}
