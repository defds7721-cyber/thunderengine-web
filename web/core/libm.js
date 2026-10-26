// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Эталонная libm для float: powf, expf, logf, sinf, cosf,
// tanhf - инструкция в инструкцию по дизассемблеру, таблицы и константы
// сняты из памяти процесса (lldb: disassemble -n powf; memory read ...).
//
// Зачем: эти функции эталонной libm НЕ округляют корректно - на 1e6 случайных
// аргументов расходятся с Float(f(Double(x))) powf 0.6 %, expf 0.6 %,
// cosf/sinf 1.3 %, tanhf 1 %, logf 0.003 % (замер 2026-10-18).
// Эталон (начальное состояние, таблицы микрофизики) зовёт именно их; JS обязан повторить те же биты. Алгоритм - семейство
// ARM optimized-routines (таблица log2/exp2 на 128 узлов, многочлены в
// double, одно округление в float в конце).
//
// Ветви за пределами основного пути (powf: x <= 0, денормалы, y = 0/inf/nan;
// sinf/cosf: |x| >= 120) заменены на f(Math.*) - в коде порта таких
// аргументов нет; при необходимости дописать по тому же дизассемблеру.

import { fmaf as fmaF } from './f32.js';

const fr = Math.fround;
const dv = new DataView(new ArrayBuffer(8));
const f64 = u => { dv.setBigUint64(0, u); return dv.getFloat64(0); };
const u64 = d => { dv.setFloat64(0, d); return dv.getBigUint64(0); };
const f32b = w => { dv.setUint32(0, w >>> 0); return dv.getFloat32(0); };
const b32 = x => { dv.setFloat32(0, x); return dv.getUint32(0); };
const M64 = (1n << 64n) - 1n;

// ---- точное fma в double (Boldo-Melquiond: TwoProduct, TwoSum, сложение с
// округлением к нечётному); верно без переполнения и потери порядка
const SPLIT = 134217729;
function twoProd(a, b) {
  const p = a * b;
  let t = SPLIT * a; const ah = t - (t - a), al = a - ah;
  t = SPLIT * b; const bh = t - (t - b), bl = b - bh;
  return [p, ((ah * bh - p) + ah * bl + al * bh) + al * bl];
}
function twoSum(a, b) { const s = a + b, bb = s - a; return [s, (a - (s - bb)) + (b - bb)]; }
function nextAway(x, up) {            // соседний double в сторону знака up (>0 вверх)
  let u = u64(x);
  if (x === 0) return up > 0 ? 5e-324 : -5e-324;
  u = (x > 0) === (up > 0) ? u + 1n : u - 1n;
  return f64(u & M64);
}
function addRO(a, b) {                // a + b с округлением к нечётному
  const [s, e] = twoSum(a, b);
  if (e === 0 || !isFinite(s)) return s;
  if (u64(s) & 1n) return s;
  return nextAway(s, e);
}
export function fmaD(a, b, c) {
  if (!isFinite(a) || !isFinite(b) || !isFinite(c) || a === 0 || b === 0) return a * b + c;
  const [uh, ul] = twoProd(a, b);
  const [th, tl] = twoSum(c, uh);
  return th + addRO(tl, ul);
}
const roundAway = d => Math.sign(d) * Math.round(Math.abs(d));        // frinta / fcvtas
const roundEven = d => { const r = Math.round(d); return (Math.abs(d % 1) === 0.5 && r % 2 !== 0) ? r - 1 : r; };  // frintn

const powC = [0x7f7fffff, 0x3f338000];
const powClamp = [0x40e0000000000000n, 0xc0e0000000000000n];
const powLog = [0xc0471559dca827ebn, 0x404ec71c53b3b1e8n, 0xc05715476529654cn, 0x40671547652aef42n, 0x3ff6c16c16c16c17n, 0xc05042bd4b9a7c99n, 0x3ff6a13cd1537290n, 0xc050014332be0033n, 0x3ff6816816816817n, 0xc04f804ae8d0cd02n, 0x3ff661ec6a5122f9n, 0xc04efec61b011f85n, 0x3ff642c8590b2164n, 0xc04e7df5fe538ab3n, 0x3ff623fa77016240n, 0xc04dfdd89d586e2bn, 0x3ff6058160581606n, 0xc04d7e6c0abc3579n, 0x3ff5e75bb8d015e7n, 0xc04cffae611ad12bn, 0x3ff5c9882b931057n, 0xc04c819dc2d45fe4n, 0x3ff5ac056b015ac0n, 0xc04c043859e2fdb3n, 0x3ff58ed2308158edn, 0xc04b877c57b1b070n, 0x3ff571ed3c506b3an, 0xc04b0b67f4f46810n, 0x3ff5555555555555n, 0xc04a8ff971810a5en, 0x3ff5390948f40febn, 0xc04a152f142981b4n, 0x3ff51d07eae2f815n, 0xc0499b072a96c6b2n, 0x3ff5015015015015n, 0xc04921800924dd3bn, 0x3ff4e5e0a72f0539n, 0xc048a8980abfbd32n, 0x3ff4cab88725af6en, 0xc048304d90c11fd3n, 0x3ff4afd6a052bf5bn, 0xc047b89f02cf2aadn, 0x3ff49539e3b2d067n, 0xc047418acebbf18fn, 0x3ff47ae147ae147bn, 0xc046cb0f6865c8ean, 0x3ff460cbc7f5cf9an, 0xc046552b49986277n, 0x3ff446f86562d9fbn, 0xc045dfdcf1eeae0en, 0x3ff42d6625d51f87n, 0xc0456b22e6b578e5n, 0x3ff4141414141414n, 0xc044f6fbb2cec598n, 0x3ff3fb013fb013fbn, 0xc0448365e695d797n, 0x3ff3e22cbce4a902n, 0xc044106017c3eca3n, 0x3ff3c995a47babe7n, 0xc0439de8e1559f6fn, 0x3ff3b13b13b13b14n, 0xc0432bfee370ee68n, 0x3ff3991c2c187f63n, 0xc042baa0c34be1ecn, 0x3ff3813813813814n, 0xc04249cd2b13cd6cn, 0x3ff3698df3de0748n, 0xc041d982c9d52708n, 0x3ff3521cfb2b78c1n, 0xc04169c05363f158n, 0x3ff33ae45b57bcb2n, 0xc040fa848044b351n, 0x3ff323e34a2b10bfn, 0xc0408bce0d95fa38n, 0x3ff30d190130d190n, 0xc0401d9bbcfa61d4n, 0x3ff2f684bda12f68n, 0xc03f5fd8a9063e35n, 0x3ff2e025c04b8097n, 0xc03e857d3d361368n, 0x3ff2c9fb4d812ca0n, 0xc03dac22d3e441d3n, 0x3ff2b404ad012b40n, 0xc03cd3c712d31109n, 0x3ff29e4129e4129en, 0xc03bfc67a7fff4ccn, 0x3ff288b01288b013n, 0xc03b2602497d5346n, 0x3ff27350b8812735n, 0xc03a5094b54d2828n, 0x3ff25e22708092f1n, 0xc0397c1cb13c7ec1n, 0x3ff2492492492492n, 0xc038a8980abfbd32n, 0x3ff23456789abcdfn, 0xc037d60496cfbb4cn, 0x3ff21fb78121fb78n, 0xc037046031c79f85n, 0x3ff20b470c67c0d9n, 0xc03633a8bf437ce1n, 0x3ff1f7047dc11f70n, 0xc03563dc29ffacb2n, 0x3ff1e2ef3b3fb874n, 0xc03494f863b8df35n, 0x3ff1cf06ada2811dn, 0xc033c6fb650cde51n, 0x3ff1bb4a4046ed29n, 0xc032f9e32d5bfdd1n, 0x3ff1a7b9611a7b96n, 0xc0322dadc2ab3497n, 0x3ff19453808ca29cn, 0xc03162593186da70n, 0x3ff1811811811812n, 0xc03097e38ce60649n, 0x3ff16e0689427379n, 0xc02f9c95dc1d1165n, 0x3ff15b1e5f75270dn, 0xc02e0b1ae8f2fd56n, 0x3ff1485f0e0acd3bn, 0xc02c7b528b70f1c5n, 0x3ff135c81135c811n, 0xc02aed391ab6674en, 0x3ff12358e75d3033n, 0xc02960caf9abb7can, 0x3ff1111111111111n, 0xc027d60496cfbb4cn, 0x3ff0fef010fef011n, 0xc0264ce26c067157n, 0x3ff0ecf56be69c90n, 0xc024c560fe68af88n, 0x3ff0db20a88f4696n, 0xc0233f7cde14cf5an, 0x3ff0c9714fbcda3bn, 0xc021bb32a600549dn, 0x3ff0b7e6ec259dc8n, 0xc020387efbca869en, 0x3ff0a6810a6810a7n, 0xc01d6ebd1f1febfen, 0x3ff0953f39010954n, 0xc01a6f9c377dd31bn, 0x3ff0842108421084n, 0xc0177394c9d958d5n, 0x3ff073260a47f7c6n, 0xc0147aa07357704fn, 0x3ff0624dd2f1a9fcn, 0xc01184b8e4c56af8n, 0x3ff05197f7d73404n, 0xc00d23afc49139f9n, 0x3ff0410410410410n, 0xc00743ee861f3556n, 0x3ff03091b51f5e1an, 0xc0016a21e20a0a45n, 0x3ff0204081020408n, 0xbff72c7ba20f7327n, 0x3ff0101010101010n, 0xbfe720d9c06a835fn, 0x3ff0000000000000n, 0x0000000000000000n, 0x3fefc07f01fc07f0n, 0x3ff6fe50b6ef0851n, 0x3fef81f81f81f820n, 0x4006e79685c2d22an, 0x3fef44659e4a4271n, 0x40111cd1d5133413n, 0x3fef07c1f07c1f08n, 0x4016bad3758efd87n, 0x3feecc07b301ecc0n, 0x401c4dfab90aab5fn, 0x3fee9131abf0b767n, 0x4020eb389fa29f9bn, 0x3fee573ac901e574n, 0x4023aa2fdd27f1c3n, 0x3fee1e1e1e1e1e1en, 0x402663f6fac91316n, 0x3fede5d6e3f8868an, 0x402918a16e46335bn, 0x3fedae6076b981dbn, 0x402bc84240adabban, 0x3fed77b654b82c34n, 0x402e72ec117fa5b2n, 0x3fed41d41d41d41dn, 0x40308c588cda79e4n, 0x3fed0cb58f6ec074n, 0x4031dcd197552b7bn, 0x3fecd85689039b0bn, 0x40332ae9e278ae1an, 0x3feca4b3055ee191n, 0x403476a9f983f74dn, 0x3fec71c71c71c71cn, 0x4035c01a39fbd688n, 0x3fec3f8f01c3f8f0n, 0x40370742d4ef027fn, 0x3fec0e070381c0e0n, 0x40384c2bd02f03b3n, 0x3febdd2b899406f7n, 0x40398edd077e70dfn, 0x3febacf914c1bad0n, 0x403acf5e2db4ec94n, 0x3feb7d6c3dda338bn, 0x403c0db6cdd94deen, 0x3feb4e81b4e81b4fn, 0x403d49ee4c325970n, 0x3feb2036406c80d9n, 0x403e840be74e6a4dn, 0x3feaf286bca1af28n, 0x403fbc16b902680an, 0x3feac5701ac5701bn, 0x4040790adbb03009n, 0x3fea98ef606a63ben, 0x40411307dad30b76n, 0x3fea6d01a6d01a6dn, 0x4041ac05b291f070n, 0x3fea41a41a41a41an, 0x40424407ab0e073an, 0x3fea16d3f97a4b02n, 0x4042db10fc4d9aafn, 0x3fe9ec8e951033d9n, 0x40437124cea4cdedn, 0x3fe9c2d14ee4a102n, 0x404406463b1b0449n, 0x3fe999999999999an, 0x40449a784bcd1b8bn, 0x3fe970e4f80cb872n, 0x40452dbdfc4c96b3n, 0x3fe948b0fcd6e9e0n, 0x4045c01a39fbd688n, 0x3fe920fb49d0e229n, 0x4046518fe4677ba7n, 0x3fe8f9c18f9c18fan, 0x4046e221cd9d0cden, 0x3fe8d3018d3018d3n, 0x404771d2ba7efb3cn, 0x3fe8acb90f6bf3aan, 0x404800a563161c54n, 0x3fe886e5f0abb04an, 0x40488e9c72e0b226n, 0x3fe8618618618618n, 0x40491bba891f1709n, 0x3fe83c977ab2beddn, 0x4049a802391e232fn, 0x3fe8181818181818n, 0x404a33760a7f6051n, 0x3fe7f405fd017f40n, 0x404abe18797f1f49n, 0x3fe7d05f417d05f4n, 0x404b47ebf73882a1n, 0x3fe7ad2208e0ecc3n, 0x404bd0f2e9e79031n, 0x3fe78a4c8178a4c8n, 0x404c592fad295b56n, 0x3fe767dce434a9b1n, 0x404ce0a4923a587dn, 0x3fe745d1745d1746n, 0x404d6753e032ea0fn, 0x3fe724287f46debcn, 0x404ded3fd442364cn, 0x3fe702e05c0b8170n, 0x404e726aa1e754d2n, 0x3fe6e1f76b4337c7n, 0x404ef6d67328e220n];
const exp2T = [0x3eeebfbdff30d656n, 0x3f762e4453e10daen, 0x3ff0000000000000n, 0x3feff63da9fb3335n, 0x3fefec9a3e778061n, 0x3fefe315e86e7f85n, 0x3fefd9b0d3158574n, 0x3fefd06b29ddf6den, 0x3fefc74518759bc8n, 0x3fefbe3ecac6f383n, 0x3fefb5586cf9890fn, 0x3fefac922b7247f7n, 0x3fefa3ec32d3d1a2n, 0x3fef9b66affed31bn, 0x3fef9301d0125b51n, 0x3fef8abdc06c31ccn, 0x3fef829aaea92de0n, 0x3fef7a98c8a58e51n, 0x3fef72b83c7d517bn, 0x3fef6af9388c8dean, 0x3fef635beb6fcb75n, 0x3fef5be084045cd4n, 0x3fef54873168b9aan, 0x3fef4d5022fcd91dn, 0x3fef463b88628cd6n, 0x3fef3f49917ddc96n, 0x3fef387a6e756238n, 0x3fef31ce4fb2a63fn, 0x3fef2b4565e27cddn, 0x3fef24dfe1f56381n, 0x3fef1e9df51fdee1n, 0x3fef187fd0dad990n, 0x3fef1285a6e4030bn, 0x3fef0cafa93e2f56n, 0x3fef06fe0a31b715n, 0x3fef0170fc4cd831n, 0x3feefc08b26416ffn, 0x3feef6c55f929ff1n, 0x3feef1a7373aa9cbn, 0x3feeecae6d05d866n, 0x3feee7db34e59ff7n, 0x3feee32dc313a8e5n, 0x3feedea64c123422n, 0x3feeda4504ac801cn, 0x3feed60a21f72e2an, 0x3feed1f5d950a897n, 0x3feece086061892dn, 0x3feeca41ed1d0057n, 0x3feec6a2b5c13cd0n, 0x3feec32af0d7d3den, 0x3feebfdad5362a27n, 0x3feebcb299fddd0dn, 0x3feeb9b2769d2ca7n, 0x3feeb6daa2cf6642n, 0x3feeb42b569d4f82n, 0x3feeb1a4ca5d920fn, 0x3feeaf4736b527dan, 0x3feead12d497c7fdn, 0x3feeab07dd485429n, 0x3feea9268a5946b7n, 0x3feea76f15ad2148n, 0x3feea5e1b976dc09n, 0x3feea47eb03a5585n, 0x3feea34634ccc320n, 0x3feea23882552225n, 0x3feea155d44ca973n, 0x3feea09e667f3bcdn, 0x3feea012750bdabfn, 0x3fee9fb23c651a2fn, 0x3fee9f7df9519484n, 0x3fee9f75e8ec5f74n, 0x3fee9f9a48a58174n, 0x3fee9feb564267c9n, 0x3feea0694fde5d3fn, 0x3feea11473eb0187n, 0x3feea1ed0130c132n, 0x3feea2f336cf4e62n, 0x3feea427543e1a12n, 0x3feea589994cce13n, 0x3feea71a4623c7adn, 0x3feea8d99b4492edn, 0x3feeaac7d98a6699n, 0x3feeace5422aa0dbn, 0x3feeaf3216b5448cn, 0x3feeb1ae99157736n, 0x3feeb45b0b91ffc6n, 0x3feeb737b0cdc5e5n, 0x3feeba44cbc8520fn, 0x3feebd829fde4e50n, 0x3feec0f170ca07ban, 0x3feec49182a3f090n, 0x3feec86319e32323n, 0x3feecc667b5de565n, 0x3feed09bec4a2d33n, 0x3feed503b23e255dn, 0x3feed99e1330b358n, 0x3feede6b5579fdbfn, 0x3feee36bbfd3f37an, 0x3feee89f995ad3adn, 0x3feeee07298db666n, 0x3feef3a2b84f15fbn, 0x3feef9728de5593an, 0x3feeff76f2fb5e47n, 0x3fef05b030a1064an, 0x3fef0c1e904bc1d2n, 0x3fef12c25bd71e09n, 0x3fef199bdd85529cn, 0x3fef20ab5fffd07an, 0x3fef27f12e57d14bn, 0x3fef2f6d9406e7b5n, 0x3fef3720dcef9069n, 0x3fef3f0b555dc3fan, 0x3fef472d4a07897cn, 0x3fef4f87080d89f2n, 0x3fef5818dcfba487n, 0x3fef60e316c98398n, 0x3fef69e603db3285n, 0x3fef7321f301b460n, 0x3fef7c97337b9b5fn, 0x3fef864614f5a129n, 0x3fef902ee78b3ff6n, 0x3fef9a51fbc74c83n, 0x3fefa4afa2a490dan, 0x3fefaf482d8e67f1n, 0x3fefba1bee615a27n, 0x3fefc52b376bba97n, 0x3fefd0765b6e4540n, 0x3fefdbfdad9cbe14n, 0x3fefe7c1819e90d8n, 0x3feff3c22b8f71f1n];
const expC = [0x40671547652b82fen, 0x4338000000000000n];
const expS = [0x7f7fffff];
const logC = [0x3f3f8000, 0x7f800000];
const logT = [0x3fd55561555ccbadn, 0xbfe00006000349d2n, 0x3fefffffffff6666n, 0x3fe62e42fefa39efn, 0x3ff0000000000000n, 0x0000000000000000n, 0x3fefc07f01fc07f0n, 0x3f7fe02a6b106789n, 0x3fef81f81f81f820n, 0x3f8fc0a8b0fc03e4n, 0x3fef44659e4a4271n, 0x3f97b91b07d5b11bn, 0x3fef07c1f07c1f08n, 0x3f9f829b0e783300n, 0x3feecc07b301ecc0n, 0x3fa39e87b9febd60n, 0x3fee9131abf0b767n, 0x3fa77458f632dcfcn, 0x3fee573ac901e574n, 0x3fab42dd711971bfn, 0x3fee1e1e1e1e1e1en, 0x3faf0a30c01162a6n, 0x3fede5d6e3f8868an, 0x3fb16536eea37ae1n, 0x3fedae6076b981dbn, 0x3fb341d7961bd1d1n, 0x3fed77b654b82c34n, 0x3fb51b073f06183fn, 0x3fed41d41d41d41dn, 0x3fb6f0d28ae56b4cn, 0x3fed0cb58f6ec074n, 0x3fb8c345d6319b21n, 0x3fecd85689039b0bn, 0x3fba926d3a4ad563n, 0x3feca4b3055ee191n, 0x3fbc5e548f5bc743n, 0x3fec71c71c71c71cn, 0x3fbe27076e2af2e6n, 0x3fec3f8f01c3f8f0n, 0x3fbfec9131dbeabbn, 0x3fec0e070381c0e0n, 0x3fc0d77e7cd08e59n, 0x3febdd2b899406f7n, 0x3fc1b72ad52f67a0n, 0x3febacf914c1bad0n, 0x3fc29552f81ff523n, 0x3feb7d6c3dda338bn, 0x3fc371fc201e8f74n, 0x3feb4e81b4e81b4fn, 0x3fc44d2b6ccb7d1en, 0x3feb2036406c80d9n, 0x3fc526e5e3a1b438n, 0x3feaf286bca1af28n, 0x3fc5ff3070a793d4n, 0x3feac5701ac5701bn, 0x3fc6d60fe719d21dn, 0x3fea98ef606a63ben, 0x3fc7ab890210d909n, 0x3fea6d01a6d01a6dn, 0x3fc87fa06520c911n, 0x3fea41a41a41a41an, 0x3fc9525a9cf456b4n, 0x3fea16d3f97a4b02n, 0x3fca23bc1fe2b563n, 0x3fe9ec8e951033d9n, 0x3fcaf3c94e80bff3n, 0x3fe9c2d14ee4a102n, 0x3fcbc286742d8cd6n, 0x3fe999999999999an, 0x3fcc8ff7c79a9a22n, 0x3fe970e4f80cb872n, 0x3fcd5c216b4fbb91n, 0x3fe948b0fcd6e9e0n, 0x3fce27076e2af2e6n, 0x3fe920fb49d0e229n, 0x3fcef0adcbdc5936n, 0x3fe8f9c18f9c18fan, 0x3fcfb9186d5e3e2bn, 0x3fe8d3018d3018d3n, 0x3fd0402594b4d041n, 0x3fe8acb90f6bf3aan, 0x3fd0a324e27390e3n, 0x3fe886e5f0abb04an, 0x3fd1058bf9ae4ad5n, 0x3fe8618618618618n, 0x3fd1675cababa60en, 0x3fe83c977ab2beddn, 0x3fd1c898c16999fbn, 0x3fe8181818181818n, 0x3fd22941fbcf7966n, 0x3fe7f405fd017f40n, 0x3fd2895a13de86a3n, 0x3fe7d05f417d05f4n, 0x3fd2e8e2bae11d31n, 0x3fe7ad2208e0ecc3n, 0x3fd347dd9a987d55n, 0x3fe78a4c8178a4c8n, 0x3fd3a64c556945ean, 0x3fe767dce434a9b1n, 0x3fd404308686a7e4n, 0x3fe745d1745d1746n, 0x3fd4618bc21c5ec2n, 0x3fe724287f46debcn, 0x3fd4be5f957778a1n, 0x3fe702e05c0b8170n, 0x3fd51aad872df82dn, 0x3fe6e1f76b4337c7n, 0x3fd5767717455a6cn, 0x3fe6c16c16c16c17n, 0x3fd5d1bdbf5809can, 0x3fe6a13cd1537290n, 0x3fd62c82f2b9c795n, 0x3fe6816816816817n, 0x3fd686c81e9b14afn, 0x3fe661ec6a5122f9n, 0x3fd6e08eaa2ba1e4n, 0x3fe642c8590b2164n, 0x3fd739d7f6bbd007n, 0x3fe623fa77016240n, 0x3fd792a55fdd47a2n, 0x3fe6058160581606n, 0x3fd7eaf83b82afc3n, 0x3fe5e75bb8d015e7n, 0x3fd842d1da1e8b17n, 0x3fe5c9882b931057n, 0x3fd89a3386c1425bn, 0x3fe5ac056b015ac0n, 0x3fd8f11e873662c7n, 0x3fe58ed2308158edn, 0x3fd947941c2116fbn, 0x3fe571ed3c506b3an, 0x3fd99d958117e08bn, 0x3fe5555555555555n, 0xbfd269621134db92n, 0x3fe5390948f40febn, 0xbfd214456d0eb8d4n, 0x3fe51d07eae2f815n, 0xbfd1bf99635a6b95n, 0x3fe5015015015015n, 0xbfd16b5ccbacfb73n, 0x3fe4e5e0a72f0539n, 0xbfd1178e8227e47cn, 0x3fe4cab88725af6en, 0xbfd0c42d676162e3n, 0x3fe4afd6a052bf5bn, 0xbfd07138604d5862n, 0x3fe49539e3b2d067n, 0xbfd01eae5626c691n, 0x3fe47ae147ae147bn, 0xbfcf991c6cb3b379n, 0x3fe460cbc7f5cf9an, 0xbfcef5ade4dcffe6n, 0x3fe446f86562d9fbn, 0xbfce530effe71012n, 0x3fe42d6625d51f87n, 0xbfcdb13db0d48940n, 0x3fe4141414141414n, 0xbfcd1037f2655e7bn, 0x3fe3fb013fb013fbn, 0xbfcc6ffbc6f00f71n, 0x3fe3e22cbce4a902n, 0xbfcbd087383bd8adn, 0x3fe3c995a47babe7n, 0xbfcb31d8575bce3dn, 0x3fe3b13b13b13b14n, 0xbfca93ed3c8ad9e3n, 0x3fe3991c2c187f63n, 0xbfc9f6c407089664n, 0x3fe3813813813814n, 0xbfc95a5adcf7017fn, 0x3fe3698df3de0748n, 0xbfc8beafeb38fe8cn, 0x3fe3521cfb2b78c1n, 0xbfc823c16551a3c2n, 0x3fe33ae45b57bcb2n, 0xbfc7898d85444c73n, 0x3fe323e34a2b10bfn, 0xbfc6f0128b756abcn, 0x3fe30d190130d190n, 0xbfc6574ebe8c133an, 0x3fe2f684bda12f68n, 0xbfc5bf406b543db2n, 0x3fe2e025c04b8097n, 0xbfc527e5e4a1b58dn, 0x3fe2c9fb4d812ca0n, 0xbfc4913d8333b561n, 0x3fe2b404ad012b40n, 0xbfc3fb45a59928ccn, 0x3fe29e4129e4129en, 0xbfc365fcb0159016n, 0x3fe288b01288b013n, 0xbfc2d1610c86813an, 0x3fe27350b8812735n, 0xbfc23d712a49c202n, 0x3fe25e22708092f1n, 0xbfc1aa2b7e23f72an, 0x3fe2492492492492n, 0xbfc1178e8227e47cn, 0x3fe23456789abcdfn, 0xbfc08598b59e3a07n, 0x3fe21fb78121fb78n, 0xbfbfe89139dbd566n, 0x3fe20b470c67c0d9n, 0xbfbec739830a1120n, 0x3fe1f7047dc11f70n, 0xbfbda727638446a2n, 0x3fe1e2ef3b3fb874n, 0xbfbc885801bc4b23n, 0x3fe1cf06ada2811dn, 0xbfbb6ac88dad5b1cn, 0x3fe1bb4a4046ed29n, 0xbfba4e7640b1bc38n, 0x3fe1a7b9611a7b96n, 0xbfb9335e5d594989n, 0x3fe19453808ca29cn, 0xbfb8197e2f40e3f0n, 0x3fe1811811811812n, 0xbfb700d30aeac0e1n, 0x3fe16e0689427379n, 0xbfb5e95a4d9791cbn, 0x3fe15b1e5f75270dn, 0xbfb4d3115d207eacn, 0x3fe1485f0e0acd3bn, 0xbfb3bdf5a7d1ee64n, 0x3fe135c81135c811n, 0xbfb2aa04a44717a5n, 0x3fe12358e75d3033n, 0xbfb1973bd1465567n, 0x3fe1111111111111n, 0xbfb08598b59e3a07n, 0x3fe0fef010fef011n, 0xbfaeea31c006b87cn, 0x3fe0ecf56be69c90n, 0xbfaccb73cdddb2ccn, 0x3fe0db20a88f4696n, 0xbfaaaef2d0fb10fcn, 0x3fe0c9714fbcda3bn, 0xbfa894aa149fb343n, 0x3fe0b7e6ec259dc8n, 0xbfa67c94f2d4bb58n, 0x3fe0a6810a6810a7n, 0xbfa466aed42de3ean, 0x3fe0953f39010954n, 0xbfa252f32f8d183fn, 0x3fe0842108421084n, 0xbfa0415d89e74444n, 0x3fe073260a47f7c6n, 0xbf9c63d2ec14aaf2n, 0x3fe0624dd2f1a9fcn, 0xbf98492528c8cabfn, 0x3fe05197f7d73404n, 0xbf9432a925980cc1n, 0x3fe0410410410410n, 0xbf90205658935847n, 0x3fe03091b51f5e1an, 0xbf882448a388a2aan, 0x3fe0204081020408n, 0xbf8010157588de71n, 0x3fe0101010101010n, 0xbf70080559588b35n, 0x3fe0000000000000n, 0x0000000000000000n];
const scW = [0x7f800000, 0x42f00000, 0x4c800000, 0x3f490fdb, 0x39800000, 0x32800000, 0x4c800000];
const scD = [0x3fe45f306dc9c883n, 0x3ff921fb54442d18n, 0x3c91a62633145c07n, 0x3ef99169fc938f4an, 0xbf56c07f16945df4n, 0x3fa55553c7899699n, 0xbfdffffffcb82e97n, 0xbf29943e0fc4818fn, 0x3f811073afd145ebn, 0xbfc555545268a02an, 0xc010a8b9fc97b22cn, 0xc00d31f4a0a55230n, 0x402ef88f0b1250c1n, 0x400537b6744fa779n, 0x3fb39502de83d49cn, 0x3fd45f306e000000n, 0xbdeb1bbead603d8bn];
const scBig = [0x3fd45f306e000000n, 0xbdeb1bbead603d8bn, 0x3fd45f306e000000n, 0xbdeb1bbead603d8bn, 0x3fd45f306e000000n, 0xbdeb1bbead603d8bn, 0x3fd45f306e000000n, 0xbdeb1bbead603d8bn, 0x3fd45f306e000000n, 0xbdeb1bbead603d8bn, 0x3fd45f306e000000n, 0xbdeb1bbead603d8bn, 0x3fd45f306e000000n, 0xbdeb1bbead603d8bn, 0x3fd45f306e000000n, 0xbdeb1bbead603d8bn, 0x3fd45f306e000000n, 0xbdeb1bbead603d8bn, 0x3fd45f306e000000n, 0xbdeb1bbead603d8bn, 0x3fd45f306e000000n, 0xbdeb1bbead603d8bn, 0x3fd45f306e000000n, 0xbdeb1bbead603d8bn, 0xbfc7419f24000000n, 0xbdeb1bbead603d8bn, 0xbfad067c92000000n, 0x3dc391054a7f09d6n, 0x3f77cc1b72000000n, 0x3d9c882a53f84eb0n, 0xbf6067c91b000000n, 0xbd6bbead603d8a83n, 0xbf09f246c7000000n, 0x3d0054a7f09d5f48n, 0xbf09f246c7000000n, 0x3d0054a7f09d5f48n, 0xbf09f246c7000000n, 0x3d0054a7f09d5f48n, 0x3ee836e4e4000000n, 0x3d0054a7f09d5f48n, 0xbecf246c6f000000n, 0x3ca529fc2757d1f5n, 0x3e7b727221000000n, 0xbc95ac07b1505c16n, 0x3e7b727221000000n, 0xbc95ac07b1505c16n, 0xbe5236377d000000n, 0xbc76b01ec5417056n, 0x3e4b939105000000n, 0x3c629fc2757d1f53n, 0xbe21b1bbeb000000n, 0x3c34fe13abe8fa9an, 0xbdeb1bbead000000n, 0xbc080f62a0b82b2dn, 0xbdeb1bbead000000n, 0xbc080f62a0b82b2dn, 0x3dc391054a000000n, 0x3befc2757d1f534en, 0x3d9c882a54000000n, 0xbb7ec54170565912n, 0xbd6bbead60000000n, 0xbb7ec54170565912n, 0xbd6bbead60000000n, 0xbb7ec54170565912n, 0x3d41054a7f000000n, 0x3b33abe8fa9a6ee0n, 0x3d0054a7f1000000n, 0xbb28a82e0acb223fn, 0x3d0054a7f1000000n, 0xbb28a82e0acb223fn, 0x3ca529fc27000000n, 0x3ac5f47d4d377037n, 0x3ca529fc27000000n, 0x3ac5f47d4d377037n, 0x3ca529fc27000000n, 0x3ac5f47d4d377037n, 0x3c84a7f09d000000n, 0x3aa7d1f534ddc0dbn, 0x3c629fc275000000n, 0x3a8f47d4d377036en, 0x3c34fe13ac000000n, 0xba370565911f924fn, 0xbc2603d8a8000000n, 0xba370565911f924fn, 0xbc080f62a1000000n, 0x3a21f534ddc0db63n, 0x3befc2757d000000n, 0x39ef534ddc0db629n, 0xbb7ec54170000000n, 0xb99596447e493ad5n, 0xbb7ec54170000000n, 0xb99596447e493ad5n, 0xbb7ec54170000000n, 0xb99596447e493ad5n, 0x3b33abe8fb000000n, 0xb9596447e493ad4dn, 0x3b33abe8fb000000n, 0xb9596447e493ad4dn, 0xbb28a82e0b000000n, 0x393a6ee06db14acdn, 0x3b0d5f47d5000000n, 0xb916447e493ad4cen, 0xbad505c159000000n, 0xb8f911f924eb5336n, 0x3ac5f47d4d000000n, 0x38dbb81b6c52b328n, 0x3aa7d1f535000000n, 0xb8b11f924eb53362n, 0x3a8f47d4d3000000n, 0x38adc0db6295993cn, 0xba37056591000000n, 0xb83f924eb53361den, 0xba37056591000000n, 0xb83f924eb53361den, 0x3a21f534de000000n, 0xb83f924eb53361den, 0x39ef534ddc000000n, 0x37db6c52b3278872n, 0x39ef534ddc000000n, 0x37db6c52b3278872n, 0xb99596447e000000n, 0xb7b24eb53361de38n, 0xb99596447e000000n, 0xb7b24eb53361de38n, 0x3984d37703000000n, 0x37ab6295993c4390n, 0x39634ddc0e000000n, 0xb78275a99b0ef1bfn];
const thS = [0x7f800000, 0x41102cb4, 0x4d000000, 0x32000000];
const thD = [0x40671547652b82fen];
const thP = [0x3e075604, 0xbeaaa9ed, 0xbbd621d2, 0x3cadd2b4, 0xbd5cb058, 0x3e088701, 0xbeaaaaa6, 0xbb883ecc, 0x3c991673, 0xbd585d60, 0x3e0851d2, 0xbeaaa8ae];

const PL = powLog.map(f64), EX = exp2T.slice(2), EXC0 = f64(exp2T[0]), EXC1 = f64(exp2T[1]);
const PA = PL.slice(0, 4);
const LT = logT.map(f64), LA = LT.slice(0, 4);
const SD = scD.map(f64);
const TH_P = thP.map(f32b);

// хвост exp2 (общий у powf, expf, tanhf): s = 2^(ki/128) из таблицы, многочлен по r
function exp2Tail(ki, r) {
  const k = BigInt(ki);
  const t = BigInt.asUintN(64, EX[Number(BigInt.asUintN(64, k) & 127n)] + BigInt.asUintN(64, k << 45n));
  const s = f64(t);
  const p = fmaD(EXC0, r, EXC1);
  return fmaD(p * r, s, s);
}

export function powf(x, y) {
  x = fr(x); y = fr(y);   // аргументы float, как у C (литерал 0.4 - не double)
  if (x === 1) return 1;
  if (y === 1) return fr(x * 1);
  const ix = b32(x), iy = b32(y);
  if (((iy & 0x7fffffff) - 1) >>> 0 >= powC[0] >>> 0 || ((ix - 0x800000) >>> 0) >= 0x7f000000) return fr(Math.pow(x, y));
  const tmp = (ix - powC[1]) >>> 0;
  const i = (tmp >>> 16) & 127;
  const top = tmp & 0xff800000;
  const iz = (ix - top) >>> 0;
  const kScaled = (top | 0) >> 16;
  const invc = PL[4 + 2 * i], logc = PL[5 + 2 * i];
  const z = f32b(iz);
  const r = fmaD(z, invc, -1);
  const y0 = logc + kScaled;
  const r2 = r * r;
  let a = fmaD(r, PA[0], PA[1]);
  const b = fmaD(r, PA[2], PA[3]);
  a = fmaD(a, r2, b);
  const l = fmaD(a, r, y0);
  let yd = y * l;
  yd = Math.min(yd, f64(powClamp[0])); yd = Math.max(yd, f64(powClamp[1]));
  const kd = roundAway(yd);
  return fr(exp2Tail(kd, yd - kd));
}

export function expf(x) {
  x = fr(x);
  const ix = b32(x);
  if (((ix >>> 23) & 0xff) >= 0x86) {
    if (x >= 0 || x !== x) return fr(x * f32b(expS[0]));
    return 0;
  }
  const C = f64(expC[0]), SHIFT = f64(expC[1]);
  const d1 = fmaD(C, x, SHIFT);
  const ki = u64(d1);
  const kd = d1 - SHIFT;
  const r = fmaD(C, x, -kd);
  const t = BigInt.asUintN(64, EX[Number(ki & 127n)] + BigInt.asUintN(64, ki << 45n));
  const s = f64(t);
  const p = fmaD(EXC0, r, EXC1);
  return fr(fmaD(p * r, s, s));
}

export function logf(x) {
  x = fr(x);
  let ix = b32(x);
  if (((ix - 0x800000) >>> 0) >= 0x7f000000) {
    if (x !== x) return x;
    if (x === 0) return -Infinity;
    if (x < 0 || ix === 0x7f800000) return x < 0 ? NaN : x;
    // денормал: нормировка как в эталоне (orr 1.0, fsub 1.0, порядок -0x3f000000)
    const s = fr(f32b((ix | 0x3f800000) >>> 0) - 1);
    ix = (b32(s) - 0x3f000000) >>> 0;
  }
  const i = (((ix & 0x7fffff) + 0x8000) >>> 16);
  const z = f64(BigInt.asUintN(64, (BigInt(ix) | 0x1ff800000n) << 29n));
  const invc = LT[4 + 2 * i], logc = LT[5 + 2 * i];
  const r = fmaD(z, invc, -1);
  const k = ((ix - logC[0]) | 0) >> 23;
  const r2 = r * r;
  let d0 = fmaD(k, LA[3], logc);
  const d17 = fmaD(r, LA[0], LA[1]);
  d0 = fmaD(r, LA[2], d0);
  d0 = fmaD(r2, d17, d0);
  return fr(d0);
}

function cosPoly(r) {            // r - double; 1 + r²·(...)
  const d1 = r * r;
  let d3 = fmaD(d1, SD[3], SD[4]);
  const d5 = fmaD(d1, SD[5], SD[6]);
  const d2 = d1 * d1;
  d3 = fmaD(d2, d3, d5);
  return fmaD(d1, d3, 1);
}
function sinPoly(r) {
  const d4 = r * r, d5 = r * d4;
  const d17 = fmaD(d4, SD[7], SD[8]);
  const d6 = d4 * d5;
  const d18 = fmaD(d5, SD[9], r);
  return fmaD(d6, d17, d18);
}
// sinf+72: n - номер четверти (уже +1 для cos), r - остаток
function quadrant(n, r) {
  const neg = ((n >> 1) & 1) === 1;
  const v = (n & 1) ? cosPoly(r) : sinPoly(r);
  return fr(neg ? -v : v);
}

export function cosf(x0) {
  x0 = fr(x0);
  const x = Math.abs(x0);
  const w = b32(x);
  if (w >= scW[1]) {
    if (w >= scW[0]) return NaN;
    return fr(Math.cos(x));      // |x| >= 120: ветвь эталона не перенесена
  }
  if (w < scW[3]) {
    if (w >= scW[4]) return fr(cosPoly(x));
    return fr(fr(f32b(scW[6]) - x) * f32b(scW[5]));
  }
  const q = x * SD[0];
  const n = roundEven(q);
  const r = fmaD(-n, SD[1], x);
  return quadrant(n + 1, r);
}

export function sinf(x) {
  x = fr(x);
  const w = b32(x) & 0x7fffffff;
  if (w >= scW[1]) {
    if (w >= scW[0]) return NaN;
    return fr(Math.sin(x));      // |x| >= 120: ветвь эталона не перенесена
  }
  if (w < scW[3]) {
    if (w >= scW[4]) return fr(sinPoly(x));
    return fr(fmaF(x, f32b(scW[6]), x) * f32b(scW[5]));
  }
  const q = x * SD[0];
  const n = roundEven(q);
  const r = fmaD(-n, SD[1], x);
  return quadrant(n, r);
}

export function tanhf(x) {
  x = fr(x);
  const ax = Math.abs(x), neg = b32(x) >>> 31 === 1;
  const sign = v => (neg ? -Math.abs(v) : Math.abs(v));
  if (x !== x) return x + x;
  if (ax >= f32b(thS[1])) return sign(1);
  if (ax >= 0.75) {
    const s1 = fr(-(ax + ax));
    const d0 = f64(thD[0]) * s1;
    const kd = roundAway(d0);
    const e = exp2Tail(kd, d0 - kd);
    return sign(fr((1 - e) / (1 + e)));
  }
  if (ax >= 0.125) {
    const set = Math.trunc(ax * 2) & 1;
    const c = TH_P.slice(2 + 5 * set, 7 + 5 * set);
    const s1 = fr(x * x);
    let s4 = fmaF(s1, c[0], c[1]);
    let s5 = fmaF(s1, s4, c[2]);
    let s6 = fmaF(s1, s5, c[3]);
    let s7 = fmaF(s1, s6, c[4]);
    const t = fr(s1 * s7);
    return sign(fmaF(x, t, x));
  }
  if (ax >= f32b(thS[3])) {
    const s1 = fr(x * x);
    const s3 = fr(s1 * fmaF(s1, TH_P[0], TH_P[1]));
    return fmaF(x, s3, x);
  }
  return fr(fmaF(x, f32b(thS[2]), x) * f32b(thS[3]));
}

// ---- asinf, atanf (тем же способом: дизассемблер + константы из памяти)
const PIO2 = f64(0x3ff921fb54442d18n), PIO2F = fr(f64(0x3ff921fb44000000n));
const TINY_K = f32b(0x4d000000), TINY_S = f32b(0x32000000);
const AS_HI = [0x3f5ee93cb2957053n, 0x3f6140186da86810n, 0x3f807e5fa0a35d8bn, 0x3f9b21ec14e82132n,
  0x3fbe2b8cc3173f9en, 0x3ff6a09e64c7c6e1n].map(f64);
const AS_LO = [0x3fa15e1a450e8b98n, 0x3f9169f766637e01n, 0x3f9fe10bae9583ban, 0x3fa6d55e6da5eec2n,
  0x3fb3334481d0bc2fn, 0x3fc555554d58f2f9n].map(f64);
const AT_HI = [0x3fed6b74d6295266n, 0xbf75505d3cf68fb0n, 0xbfe0dfcb5ed76ca4n, 0xbfe70baa17f25493n,
  0x3fd98dc25f02f8e9n, 0x3fd022d8b8d718a9n, 0x3fc626645186b1cen, 0x3fc207f5efa5231dn].map(f64);
const AT_LO = [0x4002609372076e2cn, 0x3f953db49b9fcf6bn, 0xc00792d5bf17c0bcn, 0xc013e370146726b3n,
  0x40038f4c070b63c1n, 0x400e4fa479729042n, 0x4015e43168d7c2b6n, 0x401ae0fb08f2dc00n, 0x3f680bc0fe23203dn].map(f64);
const withSign = (v, x) => (b32(x) >>> 31 ? -Math.abs(v) : Math.abs(v));
const tinyF = x => fr(fmaF(x, TINY_K, x) * TINY_S);

export function asinf(x) {
  x = fr(x);
  const ax = Math.abs(x);
  if (!(ax < 1)) {
    if (ax === 1) return withSign(PIO2F, x);
    return NaN;
  }
  if (ax > 0.5) {
    const d1 = fr(1 - ax), d16 = Math.sqrt(d1), c = AS_HI;
    const d3 = fmaD(d1, c[0], c[1]);
    let d5 = fmaD(d1, c[2], c[3]), d7 = fmaD(d1, c[4], c[5]);
    const q = d1 * d1;
    d5 = fmaD(q, d3, d5); d7 = fmaD(q, d5, d7);
    return withSign(fr(fmaD(-d7, d16, PIO2)), x);
  }
  if (ax >= TINY_S) {
    const c = AS_LO, d1 = x * x;
    const d3 = fmaD(d1, c[0], c[1]);
    let d5 = fmaD(d1, c[2], c[3]), d7 = fmaD(d1, c[4], c[5]);
    const d2 = d1 * d1;
    d5 = fmaD(d2, d3, d5); d7 = fmaD(d2, d5, d7);
    return fr(fmaD(x, d1 * d7, x));
  }
  return tinyF(x);
}

export function atanf(x) {
  x = fr(x);
  const ax = Math.abs(x);
  if (x !== x) return x - x;
  if (ax >= f32b(0x4ae1e273)) return withSign(PIO2F, x);
  if (ax > 1) {
    const c = AT_HI, d0 = 1 / ax, d1 = ax * ax;
    let d30 = d0 * d0;
    const d2 = d1 + c[0], d3 = d1 + c[1], d4 = d1 + c[2], d5 = d1 + c[3];
    d30 = d30 * d30;
    let d6 = fmaD(d1, d2, c[4]);
    const d7 = fmaD(d1, d3, c[5]);
    let d16 = fmaD(d1, d4, c[6]);
    const d17 = fmaD(d1, d5, c[7]);
    d6 *= d7; d30 *= d30; d16 *= d17; d30 *= d30; d6 *= d16;
    return withSign(fr(fmaD(-(d0 * d6), d30, PIO2)), x);
  }
  if (ax >= TINY_S) {
    const c = AT_LO, d1 = x * x;
    const d2 = d1 + c[0], d3 = d1 + c[1], d4 = d1 + c[2], d5 = d1 + c[3];
    let d6 = fmaD(d1, d2, c[4]);
    const d7 = fmaD(d1, d3, c[5]);
    let d16 = fmaD(d1, d4, c[6]);
    const d17 = fmaD(d1, d5, c[7]);
    d6 *= d7; d16 *= d17;
    const d0 = x * c[8];
    d6 *= d16;
    return fr(d0 * d6);
  }
  return tinyF(x);
}
