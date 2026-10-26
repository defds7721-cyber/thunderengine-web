// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Память модели больше одного буфера WebGPU (предел Safari - 2 ГБ на буфер).
// Адрес в M остаётся сплошным (слово u32), M режется на куски по 2^28 слов
// (1 ГБ): кусок - адрес >> 28, место в нём - младшие 28 бит. Ядра не
// переводятся заново: при загрузке текст WGSL переписывается - объявление M
// становится M0..Mn-1, любое M[x] - mem_ld/mem_st, атомарные - через свои
// функции. При одном куске текст не меняется вовсе.
// ?memchunk=N - куски по 2^N слов на любом сценарии (проверка раскладки на малых сетках)
const forced = +(new URLSearchParams(globalThis.location?.search ?? '').get('memchunk') || 0);
export const CHUNK_SHIFT = forced || 28;
export const FORCE_SPLIT = forced > 0;
export const CHUNK_WORDS = 1 << CHUNK_SHIFT;
// второй и следующие куски - на привязках 200+, чтобы не столкнуться с
// привязками самих шейдеров
export const chunkBinding = (base, j) => j === 0 ? base : 200 + j;

const DECL = /@group\(0\)\s*@binding\((\d+)\)\s*var<storage,\s*(read_write|read)>\s*M\s*:\s*array<(atomic<u32>|u32)>;/;

// индекс закрывающей скобки для открывающей в позиции i
function close(s, i) {
  const open = s[i], shut = open === '[' ? ']' : ')';
  let d = 0;
  for (let k = i; k < s.length; k++) {
    if (s[k] === open) d++;
    else if (s[k] === shut && --d === 0) return k;
  }
  throw new Error('memsplit: скобка не закрыта');
}
// конец выражения правой части присваивания: ';' на нулевой глубине
function stmtEnd(s, i) {
  let d = 0;
  for (let k = i; k < s.length; k++) {
    const c = s[k];
    if (c === '(' || c === '[' || c === '{') d++;
    else if (c === ')' || c === ']' || c === '}') d--;
    else if (c === ';' && d === 0) return k;
  }
  throw new Error('memsplit: нет конца присваивания');
}

export function splitWGSL(src, n) {
  if (n <= 1) return src;
  const m = src.match(DECL);
  if (!m) return src;
  const [decl, bind, access, elem] = m;
  const atomic = elem !== 'u32', rw = access === 'read_write';
  const B = +bind, mask = `0x${(CHUNK_WORDS - 1).toString(16)}u`;
  const decls = [];
  for (let j = 0; j < n; j++) decls.push(`@group(0) @binding(${chunkBinding(B, j)}) var<storage, ${access}> M${j}: array<${elem}>;`);
  const ld = j => atomic ? `atomicLoad(&M${j}[i])` : `M${j}[i]`;
  const sw = body => `switch (o >> ${CHUNK_SHIFT}u) { ${Array.from({ length: n }, (_, j) => `${j === n - 1 ? 'default' : `case ${j}u`}: { ${body(j)} }`).join(' ')} }`;
  let fns = `fn mem_ld(o: u32) -> u32 { let i = o & ${mask}; ${sw(j => `return ${ld(j)};`)} }`;
  if (rw) fns += `\nfn mem_st(o: u32, v: u32) { let i = o & ${mask}; ${sw(j => atomic ? `atomicStore(&M${j}[i], v);` : `M${j}[i] = v;`)} }`;
  let s = src.replace(decl, decls.join('\n'));
  // старые mem_ld/mem_st (переводчик) - на новые
  s = s.replace(/fn mem_ld\(o: u32\) -> u32 \{[^\n]*\}\n?/, '').replace(/fn mem_st\(o: u32, v: u32\) \{[^\n]*\}\n?/, '');
  // атомарные над M
  const used = new Set();
  s = s.replace(/\b(atomic\w+)\(&M\[/g, (all, op) => { used.add(op); return `m_${op}(&M[`; });
  let out = '', k = 0;
  for (;;) {
    const r = /(^|[^\w.])(m_atomic\w+\(&)?M\[/g;
    r.lastIndex = k;
    const f = r.exec(s);
    if (!f) { out += s.slice(k); break; }
    const at = f.index + f[1].length;
    const lb = at + (f[2] ? f[2].length : 0) + 1;
    const rb = close(s, lb);
    const idx = s.slice(lb + 1, rb);
    if (f[2]) {
      // m_atomicX(&M[e], v) -> m_atomicX(e, v)
      out += s.slice(k, at) + f[2].slice(0, -1) + idx;
      k = rb + 1;
      continue;
    }
    const tail = s.slice(rb + 1);
    const asg = tail.match(/^\s*=(?!=)/);
    if (asg) {
      const e = stmtEnd(s, rb + 1 + asg[0].length);
      out += s.slice(k, at) + `mem_st(${idx}, ${s.slice(rb + 1 + asg[0].length, e).trim()})`;
      k = e;
    } else {
      out += s.slice(k, at) + `mem_ld(${idx})`;
      k = rb + 1;
    }
  }
  s = out;
  // вложенные M[...] внутри уже заменённых индексов
  while (/(^|[^\w.])M\[/.test(s)) s = splitWGSL.rest(s);
  const helpers = [...used].map(op => {
    if (op === 'atomicLoad') return `fn m_atomicLoad(o: u32) -> u32 { return mem_ld(o); }`;
    if (op === 'atomicStore') return `fn m_atomicStore(o: u32, v: u32) { mem_st(o, v); }`;
    return `fn m_${op}(o: u32, v: u32) -> u32 { let i = o & ${mask}; ${sw(j => `return ${op}(&M${j}[i], v);`)} }`;
  });
  // функции памяти - сразу после объявлений кусков
  const at = s.indexOf(decls[n - 1]) + decls[n - 1].length;
  return s.slice(0, at) + '\n' + fns + '\n' + helpers.join('\n') + s.slice(at);
}
// повторный проход только по чтениям/записям (без объявления)
splitWGSL.rest = s => {
  let out = '', k = 0;
  for (;;) {
    const r = /(^|[^\w.])M\[/g;
    r.lastIndex = k;
    const f = r.exec(s);
    if (!f) return out + s.slice(k);
    const at = f.index + f[1].length, lb = at + 1, rb = close(s, lb), idx = s.slice(lb + 1, rb);
    const asg = s.slice(rb + 1).match(/^\s*=(?!=)/);
    if (asg) {
      const e = stmtEnd(s, rb + 1 + asg[0].length);
      out += s.slice(k, at) + `mem_st(${idx}, ${s.slice(rb + 1 + asg[0].length, e).trim()})`;
      k = e;
    } else { out += s.slice(k, at) + `mem_ld(${idx})`; k = rb + 1; }
  }
};
