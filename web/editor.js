// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Редактор пресетов: конфиг CM1 (секции namelist) по каталогу полей порта,
// своя зондировка, проверка сборки сценария тем же кодом, что и прогон.
// Свои пресеты - в localStorage браузера (te.presets.v1).
const v = '?v=' + Date.now();
const { ConfigParser, NamelistParser, NamelistCatalogue, ScenarioBuilder, PRESETS, parseSounding, loadSounding,
  inventorySections, BaseState } = await import('./core/config.js' + v);
const T = await import('./thermo.js' + v);
const { mountSounding } = await import('./sounding-ui.js' + v);
const { T: tr, LANG } = await import('./i18n.js');
// копия пресета: название на языке страницы (у встроенных - русское в коде)
const copyTitle = t => tr(t) + (LANG === 'en' ? ' (custom)' : ' (своя)');
const { listPresets, savePreset, deletePreset, getPreset, newId, presetToLink, presetFromLink } = await import('./presets.js' + v);

const $ = id => document.getElementById(id);
const doc = await (await fetch('../data/namelist_doc.json')).json();

// подписи по-русски для частых полей; остальные - имя namelist
const RU = {
  nx: 'точек по x', ny: 'точек по y', nz: 'уровней по z', dx: 'шаг по x, м', dy: 'шаг по y, м', dz: 'шаг по z, м',
  dtl: 'шаг по времени, с', timax: 'длительность, с', tapfrq: 'вывод, с', terrain_flag: 'рельеф',
  cm1setup: 'режим турбулентности', testcase: 'LES-случай', adapt_dt: 'переменный шаг', imoist: 'влага',
  ptype: 'микрофизика', ihail: 'град (1) / крупа (0)', iautoc: 'автоконверсия', icor: 'Кориолис', fcor: 'f, 1/с',
  lspgrad: 'крупномасштабный градиент', wbc: 'граница запад', ebc: 'граница восток', sbc: 'граница юг', nbc: 'граница север',
  bbc: 'нижняя граница', tbc: 'верхняя граница', isnd: 'зондировка', iwnd: 'профиль ветра', iinit: 'начальное возмущение',
  irandp: 'случайный шум', imove: 'движение области', umove: 'скорость области u, м/с', vmove: 'скорость области v, м/с',
  irdamp: 'слой Рэлея', zd: 'начало слоя Рэлея, м', rdalpha: 'сила слоя Рэлея, 1/с', ndcnst: 'капель, см⁻³',
  idiss: 'диссипативный нагрев', apmasscon: 'сохранение сухой массы', sgsmodel: 'подсеточная модель',
  stretch_x: 'растяжение по x', stretch_y: 'растяжение по y', stretch_z: 'растяжение по z', ztop: 'верх области, м',
  dx_inner: 'шаг в центре, м', dx_outer: 'шаг на краю, м', nos_x_len: 'без растяжения, м', tot_x_len: 'длина области, м',
  dy_inner: 'шаг в центре, м', dy_outer: 'шаг на краю, м', nos_y_len: 'без растяжения, м', tot_y_len: 'длина области, м',
  str_bot: 'растяжение от, м', str_top: 'растяжение до, м', dz_bot: 'шаг у земли, м', dz_top: 'шаг наверху, м',
  radopt: 'излучение', dtrad: 'шаг излучения, с', ctrlat: 'широта', ctrlon: 'долгота', year: 'год', month: 'месяц',
  day: 'день', hour: 'час', minute: 'минута', second: 'секунда', isfcflx: 'потоки с поверхности', sfcmodel: 'модель поверхности',
  tsk0: 'температура поверхности, K', lu0: 'тип поверхности', cnst_znt: 'шероховатость, м', v_t: 'скорость падения, м/с',
  psolver: 'акустика', eqtset: 'уравнения', irbc: 'излучающие границы', itern: 'форма рельефа', iorigin: 'начало координат',
  axisymm: 'осесимметрия', hrdamp: 'боковое демпфирование', xhd: 'полоса демпфирования, м',
};
const OPTS = {
  ptype: { 0: 'без микрофизики', 2: 'Годдард-LFO', 5: 'Моррисон', 6: 'Ротунно-Эмануэль' },
  isnd: { 5: 'Вейсман-Клемп', 7: 'файл input_sounding', 17: 'файл (3 столбца)' },
  iwnd: { 0: 'без ветра', 1: 'RKW', 2: 'суперячейка WK', 3: 'мультиячейка', 4: 'WK мультиячейка', 6: 'постоянный' },
  iinit: { 0: 'нет', 1: 'тёплый пузырь', 2: 'холодный бассейн', 3: 'линия пузырей', 7: 'вихрь Ротунно-Эмануэля', 8: 'линейный термик',
    12: 'подталкивание восходящего потока' },
  wbc: { 1: 'периодическая', 2: 'открытая', 3: 'стенка', 4: 'стенка без скольжения' },
  cm1setup: { 0: 'без турбулентности', 1: 'LES', 2: 'мезомасштаб (PBL)', 3: 'DNS' },
  radopt: { 0: 'нет', 2: 'RRTMG' }, imoist: { 0: 'сухо', 1: 'влажно' }, icor: { 0: 'нет', 1: 'есть' },
  irdamp: { 0: 'нет', 1: 'к базовому', 2: 'к среднему' }, imove: { 0: 'нет', 1: 'да' },
  bbc: { 1: 'скольжение', 2: 'прилипание', 3: 'полускольжение' }, tbc: { 1: 'скольжение', 2: 'прилипание' },
  lu0: { 3: 'суша (лето)', 16: 'вода' }, terrain_flag: { false: 'нет', true: 'есть' },
};
for (const k of ['ebc', 'sbc', 'nbc']) OPTS[k] = OPTS.wbc;
const SECTION_RU = { param0: 'Сетка', param1: 'Шаги и время', param2: 'Физика и постановка', param3: 'Параметры схем',
  param4: 'Растяжение по x', param5: 'Растяжение по y', param6: 'Растяжение по z', param7: 'DNS', param8: 'Пузырь и прочее (var1..var20)',
  param11: 'Излучение', param12: 'Поверхность', param14: 'Диагностика', param15: 'Осреднение', engine1: 'Порт' };

// ---- модель: { секция: { поле: токен } }, токены как в JSON (1000 и 1000.0 - разные типы)
function fromJSONText(text) {
  const q = text.replace(/(:\s*)(-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)(?=\s*[,}\n])/g, '$1"#$2"');
  const o = JSON.parse(q), m = {};
  for (const [s, fs] of Object.entries(o)) {
    m[s] = {};
    for (const [k, val] of Object.entries(fs)) m[s][k] = typeof val === 'string' && val.startsWith('#') ? val.slice(1) : String(val);
  }
  return m;
}
function toJSONText(m) {
  const secs = Object.entries(m).filter(([, fs]) => Object.keys(fs).length);
  return '{\n' + secs.map(([s, fs]) => ` "${s}": {\n` + Object.entries(fs).map(([k, t]) => `  "${k}": ${t}`).join(',\n') + '\n }').join(',\n') + '\n}\n';
}
function fromConfiguration(conf) {
  const m = {};
  for (const [k, x] of Object.entries(conf.values)) {
    const sp = NamelistCatalogue.spec(k);
    const s = sp ? sp.section : NamelistCatalogue.diagnosticFields.includes(k) ? 'param8' : NamelistCatalogue.ownSection;
    (m[s] ??= {})[k] = x.t === 'bool' ? String(x.v) : x.t === 'int' ? String(x.v) : (Number.isInteger(x.v) ? x.v.toFixed(1) : String(x.v));
  }
  return m;
}
const valueToken = (val, old) => {
  if (val === 'true' || val === 'false') return val;
  if (!/^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/.test(val.trim())) return null;
  val = val.trim();
  // вещественное поле остаётся вещественным: 1000 -> 1000.0, если раньше было с точкой
  if (old && /[.eE]/.test(old) && !/[.eE]/.test(val)) return val + '.0';
  return val;
};

// ---- состояние
let cur = null;   // { id?, builtin?, base, title, model, sounding, sndSpec?, sndPrev? }
let showAll = false;

async function builtinText(p) { return (await fetch('../data/presets/' + p.file, { cache: 'no-store' })).text(); }

async function open(key) {
  if (key.startsWith('b:')) {
    const p = PRESETS.find(x => x.file === key.slice(2));
    cur = { builtin: p, base: p.name ?? p.file.replace('.json', ''), title: p.title, model: fromJSONText(await builtinText(p)), sounding: null };
  } else {
    const r = getPreset(key.slice(2));
    cur = { id: r.id, base: r.base, title: r.title, model: fromJSONText(r.text), sounding: r.sounding,
      sndSpec: r.sndSpec ?? null, sndPrev: r.sndPrev ?? null };
  }
  render();
}

function fillPick(sel) {
  const own = listPresets();
  $('pick').innerHTML = `<optgroup label="Свои">${own.map(r => `<option value="u:${r.id}">${esc(r.title)}</option>`).join('') || '<option disabled>пока нет</option>'}</optgroup>`
    + `<optgroup label="Встроенные">${PRESETS.map(p => `<option value="b:${p.file}">${esc(p.title)}${p.notBuildable ? ' (не собирается)' : ''}</option>`).join('')}</optgroup>`;
  if (sel) $('pick').value = sel;
}
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

// ---- форма
function ruleOf(name) { return NamelistCatalogue.spec(name)?.rule ?? { kind: 'supported' }; }
function choices(name) {
  const r = ruleOf(name);
  const list = r.kind === 'referenceOnly' ? r.allowed : r.kind === 'substituted' ? [...r.supported, ...Object.keys(r.alternatives).map(k => ({ t: 'int', v: +k }))] : null;
  const o = OPTS[name];
  const tok = x => x.t === 'double' && Number.isInteger(x.v) ? x.v.toFixed(1) : String(x.v);
  if (list) return list.map(x => ({ v: tok(x), label: o?.[x.v] ? `${tok(x)} - ${o[x.v]}` : tok(x) }));
  if (o) return Object.entries(o).map(([k, l]) => ({ v: k, label: `${k} - ${l}` }));
  return null;
}

function render() {
  const ro = !!cur.builtin;
  $('title').value = ro ? tr(cur.title) : cur.title; $('title').disabled = ro;
  $('del').disabled = ro;
  const sections = [...new Set(NamelistCatalogue.fields.map(s => s.section))];
  const extra = Object.keys(cur.model).filter(s => !sections.includes(s));
  let html = '';
  for (const s of [...sections, ...extra]) {
    const fields = s === 'param8' ? NamelistCatalogue.diagnosticFields.map(n => ({ name: n, rule: { kind: 'supported' } }))
      : s === NamelistCatalogue.ownSection ? NamelistCatalogue.ownFields.map(n => ({ name: n, rule: { kind: 'supported' } }))
      : NamelistCatalogue.fields.filter(f => f.section === s);
    const vis = fields.filter(f => showAll || f.rule.kind !== 'ignored');
    if (!vis.length) continue;
    html += `<section class="sec"><h2>${SECTION_RU[s] ?? s}<span>${s}</span></h2><div class="grid">`;
    for (const fl of vis) {
      const val = cur.model[s]?.[fl.name] ?? '';
      const ch = choices(fl.name);
      const id = `f_${s}_${fl.name}`;
      const r = fl.rule;
      let note = '';
      if (r.kind === 'notPorted') note = `<div class="note np">нет в порте: ${esc(r.enables)}</div>`;
      if (r.kind === 'substituted') note = `<div class="note sub">иначе - ${esc(r.given)}</div>`;
      html += `<div class="fld"><label for="${id}"><span>${esc(RU[fl.name] ?? '')}</span><b>${fl.name}</b></label>`;
      if (ch) {
        const same = (a, b) => a === b || (a !== '' && b !== '' && !isNaN(a) && !isNaN(b) && Number(a) === Number(b));
        const has = ch.some(c => same(c.v, val));
        html += `<select id="${id}" data-s="${s}" data-f="${fl.name}" ${ro ? 'disabled' : ''}><option value="">не задано</option>`
          + (val !== '' && !has ? `<option value="${esc(val)}" selected>${esc(val)} - нет в порте</option>` : '')
          + ch.map(c => `<option value="${esc(c.v)}" ${same(c.v, val) ? 'selected' : ''}>${esc(c.label)}</option>`).join('') + '</select>';
      } else {
        html += `<input id="${id}" data-s="${s}" data-f="${fl.name}" value="${esc(val)}" inputmode="decimal" placeholder="не задано" ${ro ? 'disabled' : ''}>`;
      }
      html += note + '</div>';
    }
    html += '</div></section>';
  }
  $('form').innerHTML = html;
  check();
  if (!$('sndPanel').classList.contains('hidden')) mountPanel();
}

function onEdit(e) {
  const el = e.target, s = el.dataset.s, k = el.dataset.f;
  if (!s || cur.builtin) return;
  const raw = el.value;
  if (raw === '') { delete cur.model[s]?.[k]; el.classList.remove('bad'); }
  else {
    const t = valueToken(raw, cur.model[s]?.[k]);
    if (t == null) { el.classList.add('bad'); return; }
    el.classList.remove('bad');
    (cur.model[s] ??= {})[k] = t;
  }
  persist();
  scheduleCheck();
}
function showDoc(name) {
  const d = doc[name];
  $('docName').textContent = name + (d ? ` - README.namelist:${d.readme}` : '');
  const r = ruleOf(name);
  const rule = { supported: 'поддержано', referenceOnly: 'только значения из списка', substituted: 'часть значений заменяется',
    notPorted: 'нет в порте', ignored: 'на счёт не влияет' }[r.kind] ?? '';
  $('doc').textContent = (rule ? `[${rule}]\n\n` : '') + (d?.text ?? 'описания в README.namelist нет');
}

// ---- сохранение
const record = () => ({ id: cur.id, base: cur.base, title: cur.title, text: toJSONText(cur.model), sounding: cur.sounding,
  sndSpec: cur.sndSpec ?? null, sndPrev: cur.sndPrev ?? null });
let saveTimer = 0;
function persist() {
  if (cur.builtin) return;
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => savePreset(record()), 300);
}
// встроенный пресет не меняется: первая правка делает свою копию
function fork() {
  if (!cur.builtin) return;
  const id = newId();
  cur = { id, base: cur.base, title: copyTitle(cur.title), model: cur.model, sounding: cur.sounding, sndSpec: null, sndPrev: null };
  savePreset(record());
  fillPick('u:' + id);
  $('title').value = cur.title; $('title').disabled = false; $('del').disabled = false;
  $('form').querySelectorAll('input,select').forEach(e => { e.disabled = false; });
}

// ---- зондировка
let panel = null;
function gridTop(conf) {
  try { const zh = ScenarioBuilder.verticalGrid(conf).zh; return zh[zh.length - 1]; } catch { return 20000; }
}
// исходное состояние конструктора: сохранённое, из файла или из аналитической зондировки пресета
function initialSpec(conf) {
  if (cur.sndSpec) return cur.sndSpec;
  const params = { ...T.DEFAULT_PARAMS };
  const zs = T.levelHeights(Math.max(22000, gridTop(conf) + 1000));
  if (lastSounding) {
    const { prof, wind } = T.fromText(lastSounding.text);
    params.psfc = prof.psfc;
    return { mode: 'nodes', params, nodes: T.nodesFrom(prof), wind: { ...T.DEFAULT_WIND, kind: 'nodes', nodes: thin(wind.nodes) } };
  }
  const isnd = conf.int('isnd') ?? 5, iwnd = conf.int('iwnd') ?? 2, testcase = conf.int('testcase') ?? 0;
  let wind;
  if (iwnd === 2) wind = { ...T.DEFAULT_WIND };
  else if (iwnd === 0) wind = { ...T.DEFAULT_WIND, kind: 'calm' };
  else {
    const wp = ScenarioBuilder.windProfile(iwnd, testcase);
    const w = wp ? BaseState.windProfile(wp, T.WIND_NODE_Z.map(z => Math.max(z, 1))) : null;
    wind = w ? { ...T.DEFAULT_WIND, kind: 'nodes', nodes: T.WIND_NODE_Z.map((z, k) => ({ z, u: +(+w.u[k]).toFixed(1), v: +(+w.v[k]).toFixed(1) })) }
      : { ...T.DEFAULT_WIND };
  }
  if (isnd === 5) return { mode: 'params', params, wind };
  const an = ScenarioBuilder.analyticSounding(isnd, testcase);
  if (!an) return { mode: 'params', params, wind };
  const b = new BaseState({ sounding: an, zh: zs, moist: (conf.int('imoist') ?? 1) !== 0, umove: 0, vmove: 0, wind: { kind: 'calm' } });
  const p0 = b.prs0[0] * Math.exp(zs[0] * 9.81 / (287.04 * b.t0[0]));
  const prof = { psfc: p0 / 100, thSfc: b.th0[0], qvSfc: b.qv0[0], z: zs, th: [...b.th0], qv: [...b.qv0] };
  params.psfc = Math.round(prof.psfc);
  return { mode: 'nodes', params, nodes: T.nodesFrom(prof), wind };
}
const thin = nodes => {
  const out = [];
  for (const z of T.WIND_NODE_Z) {
    let best = nodes[0];
    for (const n of nodes) if (Math.abs(n.z - z) < Math.abs(best.z - z)) best = n;
    out.push({ z, u: best.u, v: best.v });
  }
  out[0] = { z: 0, u: nodes[0].u, v: nodes[0].v };
  return out;
};
let lastSounding = null;
let mountSeq = 0;
async function mountPanel() {
  // два быстрых вызова: собирается только последний
  const seq = ++mountSeq;
  panel?.destroy(); panel = null;
  let conf;
  try { conf = ConfigParser.parseText(toJSONText(cur.model)); } catch { $('sndBody').textContent = 'конфиг не разобран'; return; }
  const isnd = conf.int('isnd') ?? 5;
  lastSounding = null;
  if (cur.sounding) lastSounding = { text: cur.sounding };
  else if (isnd === 7 || isnd === 17) {
    const t = await (await fetch('../data/presets/' + cur.base + '.input_sounding')).text().catch(() => null);
    if (t) lastSounding = { text: t };
  }
  $('sndSrc').textContent = cur.sndSpec ? 'своя (конструктор)' : cur.sounding ? 'свой файл'
    : lastSounding ? 'файл пресета' : `аналитическая, isnd=${isnd}`;
  $('sndReset').disabled = cur.builtin || !cur.sounding;
  if (seq !== mountSeq) return;
  panel = mountSounding($('sndBody'), {
    spec: initialSpec(conf), gridTop: gridTop(conf), readOnly: false,
    onChange: (spec, text) => {
      fork();
      if (!cur.sndPrev) cur.sndPrev = { isnd: cur.model.param2?.isnd ?? null };
      cur.sndSpec = spec; cur.sounding = text;
      (cur.model.param2 ??= {}).isnd = '7';
      $('sndSrc').textContent = 'своя (конструктор)'; $('sndReset').disabled = false;
      const el = document.getElementById('f_param2_isnd'); if (el) el.value = '7';
      persist(); scheduleCheck();
    },
  });
}
$('snd').onclick = () => {
  const p = $('sndPanel');
  p.classList.toggle('hidden');
  if (!p.classList.contains('hidden')) { mountPanel(); p.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
  else { panel?.destroy(); panel = null; }
};
$('sndReset').onclick = () => {
  if (cur.builtin) return;
  const prev = cur.sndPrev?.isnd;
  if (prev == null) delete cur.model.param2?.isnd; else (cur.model.param2 ??= {}).isnd = prev;
  cur.sounding = null; cur.sndSpec = null; cur.sndPrev = null;
  savePreset(record()); render();
};
$('sndFile').onclick = () => $('fileSnd').click();

// ---- проверка: разбор, зондировка, сборка сценария
let checkTimer = 0;
function scheduleCheck() { clearTimeout(checkTimer); checkTimer = setTimeout(check, 400); }
let lastOk = false;
async function check() {
  const out = [];
  let ok = false, conf = null;
  try {
    conf = ConfigParser.parseText(toJSONText(cur.model));
    const isnd = conf.int('isnd') ?? 5;
    let snd = null;
    if (cur.sounding && (isnd === 7 || isnd === 17)) snd = parseSounding(cur.sounding, { windsFromFile: isnd === 7, moist: (conf.int('imoist') ?? 1) !== 0 });
    else snd = await loadSounding(cur.base, conf, f => fetch('../data/presets/' + f).then(r => r.ok ? r.text() : null));
    if ((isnd === 7 || isnd === 17) && !snd) throw new Error('isnd=' + isnd + ': нужен файл зондировки (кнопка «Зондировка»)');
    if (cur.builtin?.notBuildable) throw new Error(cur.builtin.notBuildable);
    const sc = ScenarioBuilder.scenario(conf, snd);
    const g = sc.grid;
    const stride = Math.ceil(g.fieldBytes / 256) * 256;
    const arenaGB = stride * sc.arenaFields.length / 2 ** 30;
    const steps = Math.round((conf.double('timax') ?? 7200) / sc.dt);
    const pts = g.nx * g.ny * g.nz;
    const subs = conf.schedule.totalSubsteps;
    const msStep = 110 * pts / 576000 * subs / 7;   // суперячейка 1 км: 110 мс, 7 подшагов
    const run = steps * msStep / 60000;
    const sx = g.hx.spacingRange, sz = sc.vertical;
    out.push(['Сетка', `${g.nx}×${g.ny}×${g.nz}`],
      ['Область', `${((g.hx.length) / 1000).toFixed(0)}×${(g.hy.length / 1000).toFixed(0)}×${(sz.zf[sz.nz] / 1000).toFixed(1)} км`],
      ['Шаг по x', sx.min === sx.max ? `${sx.min} м` : `${sx.min}–${sx.max} м`],
      ['dt, подшагов', `${sc.dt} с, ${conf.schedule.nsound}`],
      ['Шагов', String(steps)],
      ['Память', `${arenaGB.toFixed(2)} ГБ`],
      ['Прогон', `≈ ${run < 1 ? '<1' : run.toFixed(0)} мин`]);
    // больше 2 ГБ - кусками (memsplit.js); предел - копия арены в JS при сборке (около 4 ГБ в Safari)
    if (arenaGB > 3.9) throw new Error(`память ${arenaGB.toFixed(2)} ГБ - больше предела браузера (около 4 ГБ): уменьши сетку`);
    if (arenaGB > 1.9) out.push(['Внимание', 'больше 2 ГБ: память кусками, шаг медленнее; нужно 8+ ГБ свободной памяти']);
    ok = true;
  } catch (e) {
    out.push(['ошибка', String(e?.message ?? e)]);
  }
  lastOk = ok;
  $('run').disabled = !ok;
  const err = out.find(r => r[0] === 'ошибка');
  let html = err ? `<p class="msg err">${esc(err[1])}</p>` : '<p class="msg ok">Сценарий собирается</p>';
  html += '<table class="kv">' + out.filter(r => r[0] !== 'ошибка').map(([k, x]) => `<tr><td>${k}</td><td>${esc(x)}</td></tr>`).join('') + '</table>';
  if (cur.sounding) html += `<p class="msg">Зондировка: свой файл, ${cur.sounding.trim().split('\n').length - 1} уровней</p>`;
  if (conf) {
    const inv = inventorySections(conf);
    if (inv.length) html += '<div class="inv">' + inv.map(s => `<h3>${esc(s.title)}</h3><ul>${s.lines.map(l => `<li>${esc(l)}</li>`).join('')}</ul>`).join('') + '</div>';
  }
  $('check').innerHTML = html;
}

// ---- действия
$('pick').onchange = () => open($('pick').value);
$('form').addEventListener('input', onEdit);
$('form').addEventListener('change', onEdit);
$('form').addEventListener('focusin', e => { if (e.target.dataset.f) showDoc(e.target.dataset.f); });
$('title').oninput = () => { cur.title = $('title').value; persist(); clearTimeout(window._ft); window._ft = setTimeout(() => fillPick('u:' + cur.id), 400); };
$('showAll').onchange = e => { showAll = e.target.checked; render(); };
$('copy').onclick = () => {
  const id = newId();
  savePreset({ ...record(), id, title: copyTitle(cur.title) });
  fillPick('u:' + id); open('u:' + id);
};
$('del').onclick = () => {
  if (cur.builtin || !confirm(`Удалить «${cur.title}»?`)) return;
  deletePreset(cur.id); fillPick(); open('b:supercell.json'); $('pick').value = 'b:supercell.json';
};
$('import').onclick = () => $('fileConf').click();
$('fileConf').onchange = async e => {
  const file = e.target.files[0]; if (!file) return;
  const text = await file.text();
  try {
    const conf = ConfigParser.parseText(text);
    const model = NamelistParser.looksLikeNamelist(text) ? fromConfiguration(conf) : fromJSONText(text);
    const id = newId();
    savePreset({ id, base: 'supercell', title: file.name.replace(/\.(json|input|txt)$/, ''), text: toJSONText(model), sounding: null });
    fillPick('u:' + id); open('u:' + id);
  } catch (err) { alert('Конфиг не разобран: ' + (err?.message ?? err)); }
  e.target.value = '';
};
$('fileSnd').onchange = async e => {
  const file = e.target.files[0]; if (!file) return;
  const text = await file.text();
  try {
    parseSounding(text);
    fork();
    if (!cur.sndPrev) cur.sndPrev = { isnd: cur.model.param2?.isnd ?? null };
    cur.sounding = text; cur.sndSpec = null;
    if (!['7', '17'].includes(cur.model.param2?.isnd)) (cur.model.param2 ??= {}).isnd = '7';
    savePreset(record()); render();
  }
  catch (err) { alert('Зондировка не разобрана: ' + (err?.message ?? err)); }
  e.target.value = '';
};
$('export').onclick = () => {
  const dl = (name, text) => { const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([text])); a.download = name; a.click(); };
  const nm = (cur.title || 'preset').replace(/[^\wа-яё -]/gi, '_');
  dl(nm + '.json', toJSONText(cur.model));
  if (cur.sounding) dl(nm + '.input_sounding', cur.sounding);
};
$('share').onclick = async () => {
  const code = await presetToLink({ ...record(), title: cur.title });
  const url = location.origin + location.pathname + '#p=' + code;
  let ok = false;
  try { await navigator.clipboard.writeText(url); ok = true; } catch {}
  const b = $('share'), was = b.textContent;
  b.textContent = ok ? 'Скопировано' : 'Не скопировано';
  if (!ok) prompt('Ссылка на пресет', url);
  setTimeout(() => { b.textContent = was; }, 1500);
};
$('run').onclick = () => {
  if (!lastOk) return;
  if (cur.builtin) { location.href = 'index.html?s=' + cur.base; return; }
  savePreset(record());
  location.href = 'index.html?u=' + cur.id;
};

const q = new URLSearchParams(location.search);
// пресет по ссылке (#p=...): сохраняется как свой и открывается
let linked = null;
if (location.hash.startsWith('#p=')) {
  try {
    const p = await presetFromLink(location.hash.slice(3));
    linked = newId();
    savePreset({ ...p, id: linked });
  } catch (e) { alert('Ссылка на пресет не читается: ' + (e?.message ?? e)); }
  history.replaceState(null, '', location.pathname + location.search);
}
const start = linked ? 'u:' + linked : q.get('u') && getPreset(q.get('u')) ? 'u:' + q.get('u') : 'b:' + (q.get('s') || 'supercell') + '.json';
fillPick(start);
await open(start);
if (q.get('snd') === '1') $('snd').click();
window.webkit?.messageHandlers?.out?.postMessage('РЕДАКТОР ГОТОВ');
