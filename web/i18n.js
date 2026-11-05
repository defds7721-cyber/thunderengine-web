// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Перевод интерфейса. Исходный язык - русский (строки в коде как есть);
// английский - словарь data/i18n/en.json { русская строка: английская },
// собранный tools/i18n_extract.py + переводом. Строки-шаблоны с {0}, {1}
// ищутся в показанном тексте как образцы, подставленные куски переводятся
// тем же словарём (сообщения ядра с числами и вложенными сообщениями).
// В английском режиме страница переводится сама: наблюдатель DOM ловит
// новый текст; текст на холстах - через T() в коде.
//
// Язык: ?lang=en|ru (запоминается), иначе сохранённый, иначе язык браузера.
const KEY = 'te.lang';
const q = new URLSearchParams(location.search);
let lang = q.get('lang');
try {
  if (lang === 'en' || lang === 'ru') localStorage.setItem(KEY, lang);
  else lang = localStorage.getItem(KEY);
} catch {}
if (lang !== 'en' && lang !== 'ru') lang = /^ru\b/i.test(navigator.language || '') ? 'ru' : 'en';
export const LANG = lang;
document.documentElement.lang = lang;

const exact = new Map();
let patterns = [];
const CYR = /[А-Яа-яЁё]/;
const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

if (lang === 'en') {
  try {
    const dict = await (await fetch(new URL('../data/i18n/en.json', import.meta.url))).json();
    for (const [ru, en] of Object.entries(dict)) {
      if (en == null) continue;
      if (/\{\d+\}/.test(ru)) {
        // образец: литералы между подстановками должны содержать хоть что-то, кроме пробелов
        const lits = ru.split(/\{\d+\}/);
        if (!lits.some(x => x.trim().length)) continue;
        const order = [...ru.matchAll(/\{(\d+)\}/g)].map(m => +m[1]);
        const re = new RegExp('^' + lits.map(esc).join('([\\s\\S]+?)') + '$');
        patterns.push({ re, order, en, weight: lits.join('').length });
      } else exact.set(ru, en);
    }
    // длинные образцы - первыми: точнее
    patterns.sort((a, b) => b.weight - a.weight);
  } catch (e) { console.warn('перевод не загружен', e); }
}

// перевод строки; без русских букв - как есть
export function T(s, depth = 0) {
  if (lang !== 'en' || s == null) return s;
  s = String(s);
  if (!CYR.test(s)) return s;
  const lead = s.match(/^\s*/)[0], trail = s.match(/\s*$/)[0], core = s.trim();
  const hit = exact.get(core);
  if (hit != null) return lead + hit + trail;
  if (depth < 3) {
    for (const p of patterns) {
      const m = core.match(p.re);
      if (!m) continue;
      let out = p.en;
      p.order.forEach((n, i) => { out = out.replace('{' + n + '}', T(m[i + 1], depth + 1)); });
      return lead + out + trail;
    }
  }
  // запасной ход: склеенная строка - известные фразы внутри по границам слов, длинные первыми
  if (!phraseRe) {
    const keys = [...exact.keys()].filter(k => k.length >= 2 && CYR.test(k)).sort((x, y) => y.length - x.length);
    phraseRe = new RegExp('(?<![А-Яа-яЁёA-Za-z])(' + keys.map(esc).join('|') + ')(?![А-Яа-яЁёA-Za-z])', 'g');
  }
  return s.replace(phraseRe, w => exact.get(w) ?? w);
}
let phraseRe = null;

// ---- страница
const ATTRS = ['title', 'aria-label', 'placeholder'];
function translateNode(n) {
  if (n.nodeType === 3) {
    const v = n.nodeValue;
    if (v && CYR.test(v)) { const t = T(v); if (t !== v) n.nodeValue = t; }
    return;
  }
  if (n.nodeType !== 1) return;
  const tag = n.tagName;
  if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'TEXTAREA') return;
  for (const a of ATTRS) {
    const v = n.getAttribute(a);
    if (v && CYR.test(v)) { const t = T(v); if (t !== v) n.setAttribute(a, t); }
  }
  for (const c of n.childNodes) translateNode(c);
}
if (lang === 'en') {
  const run = () => {
    translateNode(document.body);
    if (CYR.test(document.title)) document.title = T(document.title);
    new MutationObserver(list => {
      for (const m of list) {
        if (m.type === 'characterData') translateNode(m.target);
        else if (m.type === 'attributes') translateNode(m.target);
        else m.addedNodes.forEach(translateNode);
      }
    }).observe(document.body, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ATTRS });
  };
  if (document.body) run(); else addEventListener('DOMContentLoaded', run);
}

// переключатель языка: <select> с RU/EN, смена - перезагрузка с ?lang=
export function langSwitch(el) {
  el.innerHTML = '<option value="ru">RU</option><option value="en">EN</option>';
  el.value = lang;
  el.setAttribute('aria-label', lang === 'en' ? 'Language' : 'Язык');
  el.onchange = () => {
    const u = new URL(location.href);
    u.searchParams.set('lang', el.value);
    location.href = u.toString();
  };
}
