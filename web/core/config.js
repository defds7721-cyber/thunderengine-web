// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Разбор namelist и сборка сценария: NamelistParser,
// ConfigParse, FieldSpec, NamelistCatalogue, Inventory, ConfigChoice,
// ScenarioBuilder, Preset.all и AcousticSchedule.
//
//   ConfigParser.parseText(text)  - JSON или namelist.input CM1 -> Configuration
//   ConfigParser.parse(obj)       - разобранный JSON -> Configuration
//   ScenarioBuilder.scenario(configuration, sounding) -> SupercellScenario
//   PRESETS, loadSounding(name, configuration, fetchText), parseSounding(text, opts)
//   inventorySections(configuration) - опись «нет в порте» / «заменено»
import { f } from './f32.js';
import { HorizontalGrid, VerticalGrid, ThermoConstants, Stretch, roundHalfAway } from './grid.js';
import { BaseState, Sounding, SoundingFactory, WarmBubble, ColdPool, BubbleLine, RotunnoEmanuelVortex, uniformWind } from './base.js';
import { SupercellScenario, ScenarioRadiation } from './scenario.js';
import { TerrainGeometry } from './terrain.js';

async function optional(path) {
  try { return await import(path); }
  catch (e) { if (e instanceof SyntaxError) throw e; return {}; }
}
const TS = await optional('./timestep.js');
const RAD = await optional('./radiation.js');

// ---- ConfigValue: { t: 'int' | 'double' | 'bool', v }
const CV = {
  int: v => ({ t: 'int', v }), double: v => ({ t: 'double', v }), bool: v => ({ t: 'bool', v }),
  desc(x) {
    if (x.t === 'bool') return x.v ? 'true' : 'false';
    if (x.t === 'double') return Number.isInteger(x.v) ? x.v.toFixed(1) : String(x.v);
    return String(x.v);
  },
  matches(a, b) {
    if (a.t === 'int' && b.t === 'int') return a.v === b.v;
    if (a.t === 'bool' && b.t === 'bool') return a.v === b.v;
    if (a.t === 'double' && b.t === 'double') { const s = Math.max(Math.abs(a.v), Math.abs(b.v), 1.0); return Math.abs(a.v - b.v) <= 1e-9 * s; }
    if ((a.t === 'int' && b.t === 'double') || (a.t === 'double' && b.t === 'int')) {
      const i = a.t === 'int' ? a.v : b.v, d = a.t === 'double' ? a.v : b.v;
      return Math.abs(i - d) <= 1e-9 * Math.max(Math.abs(d), 1.0);
    }
    return false;
  },
};
export const ConfigValue = CV;

// Число JSON с сохранённым типом: 1000.0 - вещественное, 1000 - целое
// (как NSNumber у JSONSerialization).
class JNum { constructor(v, isInt) { this.v = v; this.isInt = isInt; } }

// Разбор JSON с типами чисел (JSON.parse их теряет).
function parseJSONTyped(text) {
  let i = 0;
  const ws = () => { while (i < text.length && /\s/.test(text[i])) i++; };
  const err = m => { throw new Error(`JSON: ${m} (позиция ${i})`); };
  function value() {
    ws();
    const c = text[i];
    if (c === '{') {
      i++; const o = {}; ws();
      if (text[i] === '}') { i++; return o; }
      for (;;) {
        ws(); const k = value(); if (typeof k !== 'string') err('ключ не строка');
        ws(); if (text[i] !== ':') err('нет :'); i++;
        o[k] = value(); ws();
        if (text[i] === ',') { i++; continue; }
        if (text[i] === '}') { i++; return o; }
        err('нет , или }');
      }
    }
    if (c === '[') {
      i++; const a = []; ws();
      if (text[i] === ']') { i++; return a; }
      for (;;) {
        a.push(value()); ws();
        if (text[i] === ',') { i++; continue; }
        if (text[i] === ']') { i++; return a; }
        err('нет , или ]');
      }
    }
    if (c === '"') {
      const m = /^"(?:[^"\\]|\\.)*"/.exec(text.slice(i)); if (!m) err('строка');
      i += m[0].length; return JSON.parse(m[0]);
    }
    if (text.startsWith('true', i)) { i += 4; return true; }
    if (text.startsWith('false', i)) { i += 5; return false; }
    if (text.startsWith('null', i)) { i += 4; return null; }
    const m = /^-?\d+(\.\d+)?([eE][+-]?\d+)?/.exec(text.slice(i));
    if (!m) err('неизвестное значение');
    i += m[0].length;
    return new JNum(Number(m[0]), !m[1] && !m[2]);
  }
  const v = value(); ws();
  if (i !== text.length) err('лишние символы');
  return v;
}

// ---- FieldSpec / NamelistCatalogue
const R = {
  supported: { kind: 'supported' }, ignored: { kind: 'ignored' },
  ref: vals => ({ kind: 'referenceOnly', allowed: vals }),
  sub: (supported, alternatives, given) => ({ kind: 'substituted', supported, alternatives, given }),
  notPorted: (enables, activeWhen = 'nonZero') => ({ kind: 'notPorted', enables, activeWhen }),
};
const I = CV.int, D = CV.double, B = CV.bool;
const ints = (...a) => a.map(I);
const spec = (name, section, readme, rule) => ({ name, section, readmeLine: readme, rule, reference: `README.namelist:${readme}` });
const wall = (side, axis) => R.sub(ints(1, 2), { 3: `жёсткая стенка со скольжением (${side})`, 4: `жёсткая стенка без скольжения (${side})` },
  `периодическая по ${axis}`);

export const NamelistCatalogue = {
  fields: [
    spec('nx', 'param0', 20, R.supported), spec('ny', 'param0', 22, R.supported), spec('nz', 'param0', 24, R.supported),
    spec('ppnode', 'param0', 26, R.ignored), spec('timeformat', 'param0', 38, R.ignored), spec('timestats', 'param0', 44, R.ignored),
    spec('terrain_flag', 'param0', 49, R.ref([B(false), B(true)])), spec('procfiles', 'param0', 52, R.ignored),
    spec('dx', 'param1', 58, R.supported), spec('dy', 'param1', 60, R.supported), spec('dz', 'param1', 62, R.supported),
    spec('dtl', 'param1', 70, R.supported), spec('timax', 'param1', 86, R.supported), spec('run_time', 'param1', 88, R.ignored),
    spec('tapfrq', 'param1', 94, R.supported), spec('rstfrq', 'param1', 97, R.supported), spec('statfrq', 'param1', 100, R.supported),
    spec('prclfrq', 'param1', 106, R.ignored),
    spec('cm1setup', 'param2', 116, R.ref(ints(0, 1, 2, 3))),
    spec('testcase', 'param2', 139, R.ref(ints(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10))),
    spec('adapt_dt', 'param2', 194, R.ref(ints(0, 1))), spec('irst', 'param2', 199, R.ref(ints(0))),
    spec('rstnum', 'param2', 201, R.ignored), spec('iconly', 'param2', 205, R.ref(ints(0))),
    spec('hadvordrs', 'param2', 209, R.ref(ints(5))), spec('vadvordrs', 'param2', 210, R.ref(ints(5))),
    spec('hadvordrv', 'param2', 211, R.ref(ints(5))), spec('vadvordrv', 'param2', 212, R.ref(ints(5))),
    spec('advwenos', 'param2', 223, R.ref(ints(2))), spec('advwenov', 'param2', 224, R.ref(ints(0, 2))),
    spec('weno_order', 'param2', 229, R.ref(ints(5))), spec('apmasscon', 'param2', 243, R.supported),
    spec('idiff', 'param2', 253, R.ref(ints(0))), spec('mdiff', 'param2', 261, R.ref(ints(0))),
    spec('difforder', 'param2', 268, R.ref(ints(6))), spec('imoist', 'param2', 280, R.supported),
    spec('ipbl', 'param2', 282, R.ref(ints(0, 1, 2))), spec('sgsmodel', 'param2', 310, R.ref(ints(0, 1))),
    spec('tconfig', 'param2', 328, R.ignored), spec('bcturbs', 'param2', 335, R.ref(ints(1, 2))),
    spec('horizturb', 'param2', 340, R.ref(ints(0, 1))), spec('doimpl', 'param2', 350, R.ref(ints(0, 1))),
    spec('irdamp', 'param2', 363, R.ref(ints(0, 1, 2))), spec('hrdamp', 'param2', 372, R.ref(ints(0, 1))),
    spec('psolver', 'param2', 376, R.ref(ints(2, 3))), spec('ptype', 'param2', 409, R.ref(ints(0, 2, 5, 6))),
    spec('ihail', 'param2', 442, R.supported), spec('iautoc', 'param2', 447, R.supported),
    spec('icor', 'param2', 450, R.ref(ints(0, 1))), spec('lspgrad', 'param2', 457, R.ref(ints(0, 1, 2, 3))),
    spec('eqtset', 'param2', 467, R.ref(ints(1, 2))), spec('idiss', 'param2', 478, R.supported),
    spec('efall', 'param2', 480, R.ref(ints(0))), spec('rterm', 'param2', 482, R.ref(ints(0, 1))),
    spec('wbc', 'param2', 488, wall('западная', 'x')), spec('ebc', 'param2', 490, wall('восточная', 'x')),
    spec('sbc', 'param2', 492, wall('южная', 'y')), spec('nbc', 'param2', 494, wall('северная', 'y')),
    spec('bbc', 'param2', 501, R.ref(ints(1, 2, 3))), spec('tbc', 'param2', 510, R.ref(ints(1, 2))),
    spec('irbc', 'param2', 517, R.ref(ints(4))), spec('roflux', 'param2', 522, R.ref(ints(0))),
    spec('nudgeobc', 'param2', 530, R.ref(ints(0))), spec('isnd', 'param2', 539, R.supported),
    spec('iwnd', 'param2', 576, R.supported), spec('itern', 'param2', 593, R.ref(ints(0, 1))),
    spec('iinit', 'param2', 601, R.supported), spec('irandp', 'param2', 614, R.ref(ints(0, 1))),
    spec('ibalance', 'param2', 619, R.ref(ints(0))), spec('iorigin', 'param2', 629, R.ref(ints(1, 2))),
    spec('axisymm', 'param2', 638, R.ref(ints(0, 1))), spec('imove', 'param2', 644, R.supported),
    spec('iptra', 'param2', 648, R.ref(ints(0))), spec('npt', 'param2', 652, R.ignored),
    spec('pdtra', 'param2', 654, R.ignored), spec('iprcl', 'param2', 656, R.ref(ints(0))),
    spec('nparcels', 'param2', 660, R.ignored),
    spec('kdiff2', 'param3', 665, R.ignored), spec('kdiff6', 'param3', 667, R.ignored),
    spec('fcor', 'param3', 671, R.supported), spec('kdiv', 'param3', 673, R.ref([D(0.1)])),
    spec('alph', 'param3', 678, R.ref([D(0.6)])), spec('rdalpha', 'param3', 683, R.supported),
    spec('zd', 'param3', 686, R.supported), spec('xhd', 'param3', 689, R.supported),
    spec('alphobc', 'param3', 692, R.ignored), spec('umove', 'param3', 694, R.supported),
    spec('vmove', 'param3', 699, R.supported), spec('v_t', 'param3', 704, R.supported),
    spec('l_h', 'param3', 710, R.supported), spec('lhref1', 'param3', 715, R.supported),
    spec('lhref2', 'param3', 716, R.supported), spec('l_inf', 'param3', 727, R.supported),
    spec('ndcnst', 'param3', 731, R.supported),
    spec('stretch_x', 'param4', 1004, R.ref(ints(0, 1, 2))), spec('dx_inner', 'param4', 1011, R.supported),
    spec('dx_outer', 'param4', 1013, R.supported), spec('nos_x_len', 'param4', 1015, R.supported),
    spec('tot_x_len', 'param4', 1017, R.supported),
    spec('stretch_y', 'param5', 1024, R.ref(ints(0, 1, 2))), spec('dy_inner', 'param5', 1031, R.supported),
    spec('dy_outer', 'param5', 1033, R.supported), spec('nos_y_len', 'param5', 1035, R.supported),
    spec('tot_y_len', 'param5', 1037, R.supported),
    spec('stretch_z', 'param6', 1044, R.ref(ints(0, 1, 3))), spec('ztop', 'param6', 1063, R.supported),
    spec('str_bot', 'param6', 1066, R.supported), spec('str_top', 'param6', 1068, R.supported),
    spec('dz_bot', 'param6', 1070, R.supported), spec('dz_top', 'param6', 1072, R.supported),
    spec('isfcflx', 'param12', 821, R.ref(ints(0, 1))), spec('sfcmodel', 'param12', 823, R.ref(ints(0, 1, 3, 5))),
    spec('radopt', 'param11', 743, R.ref(ints(0, 2))), spec('dtrad', 'param11', 780, R.supported),
    spec('ctrlat', 'param11', 784, R.supported), spec('ctrlon', 'param11', 786, R.supported),
    spec('year', 'param11', 796, R.supported), spec('month', 'param11', 798, R.supported),
    spec('day', 'param11', 800, R.supported), spec('hour', 'param11', 802, R.supported),
    spec('minute', 'param11', 804, R.supported), spec('second', 'param11', 806, R.supported),
    spec('oceanmodel', 'param12', 891, R.ref(ints(0, 1))), spec('initsfc', 'param12', 902, R.ref(ints(1, 2))),
    spec('tsk0', 'param12', 909, R.supported), spec('tmn0', 'param12', 913, R.ignored),
    spec('xland0', 'param12', 918, R.ref([D(1.0), D(2.0)])), spec('lu0', 'param12', 921, R.ref(ints(3, 16))),
    spec('season', 'param12', 924, R.ref(ints(1))), spec('cecd', 'param12', 937, R.ref(ints(1, 2, 3))),
    spec('pertflx', 'param12', 951, R.ref(ints(0))), spec('cnstce', 'param12', 955, R.supported),
    spec('cnstcd', 'param12', 958, R.supported), spec('isftcflx', 'param12', 964, R.ignored),
    spec('iz0tlnd', 'param12', 970, R.ignored), spec('oml_hml0', 'param12', 977, R.ignored),
    spec('oml_gamma', 'param12', 979, R.ignored), spec('set_flx', 'param12', 984, R.ref(ints(0, 1))),
    spec('cnst_shflx', 'param12', 986, R.supported), spec('cnst_lhflx', 'param12', 988, R.supported),
    spec('set_znt', 'param12', 990, R.ref(ints(0, 1))), spec('cnst_znt', 'param12', 992, R.supported),
    spec('set_ust', 'param12', 994, R.ref(ints(0, 1))), spec('cnst_ust', 'param12', 996, R.supported),
    spec('bc_temp', 'param7', 1078, R.ref(ints(1, 2))), spec('ptc_top', 'param7', 1083, R.supported),
    spec('ptc_bot', 'param7', 1088, R.supported), spec('viscosity', 'param7', 1093, R.supported),
    spec('pr_num', 'param7', 1095, R.supported), spec('sc_num', 'param7', 1097, R.ignored),
    spec('dodomaindiag', 'param14', 1635, R.supported), spec('diagfrq', 'param14', 1643, R.supported),
    spec('doazimavg', 'param15', 1651, R.supported), spec('azimavgfrq', 'param15', 1664, R.supported),
    spec('rlen', 'param15', 1666, R.ignored), spec('do_adapt_move', 'param15', 1669, R.ref([B(false)])),
    spec('adapt_move_frq', 'param15', 1676, R.ignored),
  ],
  unportedSections: {
    param9: 'выбор выводимых полей', param10: 'статистический вывод',
    param13: 'вывод траекторий частиц', nssl2mom_params: 'микрофизику NSSL',
  },
  sectionsWithoutDocumentation: ['param16'],
  ownSection: 'engine1',
  ownFields: ['radar_x', 'radar_y', 'frame_interval', 'area_lat', 'area_lon', 'area_side_km', 'env_kind', 'env_epoch'],
  diagnosticSection: 'param8',
  diagnosticReadmeLine: 1100,
  diagnosticFields: Array.from({ length: 20 }, (_, i) => `var${i + 1}`),
  spec(name) { return this.fields.find(s => s.name === name) ?? null; },
};

// ---- Inventory
export class Inventory {
  constructor({ missing, substitutions, unportedSections }) {
    this.missing = missing; this.substitutions = substitutions; this.unportedSections = unportedSections;
  }
  get missingLines() {
    return [...this.missing.map(m => `${m.field} = ${CV.desc(m.value)}: нет в порте - ${m.enables} (${m.reference})`),
      ...this.unportedSections.map(s => `секция ${s}: нет в порте - ${NamelistCatalogue.unportedSections[s] ?? ''}`)];
  }
  get substitutionLines() {
    return this.substitutions.map(s => `${s.field}: просили ${s.asked}, поставлено ${s.given} (${s.reference})`);
  }
  get isEmpty() { return !this.missing.length && !this.substitutions.length && !this.unportedSections.length; }
  screenSections(extra = []) {
    const out = [];
    const notPorted = [...this.missing.map(m => `${m.field} = ${CV.desc(m.value)}: ${m.enables} (${m.reference})`),
      ...this.unportedSections.map(s => `секция ${s}: ${NamelistCatalogue.unportedSections[s] ?? ''}`)];
    if (notPorted.length) out.push({ title: 'нет в порте', lines: notPorted });
    if (this.substitutions.length) {
      out.push({ title: 'заменено', lines: this.substitutions.map(s => `${s.field}: просили ${s.asked} - поставлено ${s.given} (${s.reference})`) });
    }
    if (extra.length) out.push({ title: 'известные расхождения и обходы', lines: extra });
    return out;
  }
}
export const inventorySections = (configuration, extra = []) => configuration.inventory.screenSections(extra);

// ---- AcousticSchedule
export class AcousticSchedule {
  static maxNsound = 192;
  static smallStep(minHorizontalSpacing, minVerticalSpacing = null, twoDimensional = false) {
    if (minVerticalSpacing == null) return f(f(f(0.60) * f(minHorizontalSpacing)) / f(360.0));
    const m = f(Math.min(minHorizontalSpacing, minVerticalSpacing));
    return f(f((twoDimensional ? f(0.60) : f(0.50)) * m) / f(360.0));
  }
  // init(dt:minHorizontalSpacing:twoDimensional:minVerticalSpacing:)
  static fromSpacing({ dt, minHorizontalSpacing, twoDimensional, minVerticalSpacing = null }) {
    const dtsm = AcousticSchedule.smallStep(minHorizontalSpacing, minVerticalSpacing, twoDimensional);
    let n = Math.max(Math.trunc(roundHalfAway(dt / dtsm)), 4);
    if (n % 2 !== 0) n += 1;
    if (dt / n > dtsm) n += 2;
    if (!(n <= AcousticSchedule.maxNsound)) {
      const e = new Error(`шаг по времени dt=${dt} с требует ${n} акустических подшагов при пределе ${AcousticSchedule.maxNsound}; нужен меньший dt`);
      e.tooManySubsteps = true; throw e;
    }
    return new AcousticSchedule({ nsound: n, dt });
  }
  // init(nsound:dt:)
  constructor({ nsound: n, dt }) {
    this.nsound = n; this.dt = dt;
    let n1 = Math.max(Math.trunc(roundHalfAway(n / 3.0)), 1);
    let d1 = dt / (n1 * 3.0);
    if (d1 > dt / n) { n1 += 1; d1 = dt / (n1 * 3.0); }
    this.loops = [{ count: n1, dts: d1 }, { count: Math.trunc(n / 2), dts: dt / n }, { count: n, dts: dt / n }];
  }
  get totalSubsteps() { return this.loops.reduce((s, l) => s + l.count, 0); }
}

// ---- ConfigParse
export class Configuration {
  constructor({ values, inventory, schedule, gridLevels = null }) {
    this.values = values; this.inventory = inventory; this.schedule = schedule; this.gridLevels = gridLevels;
  }
  static parseGridLevels(text) {
    const out = [];
    for (const raw of text.split(/\r\n|\r|\n/)) {
      const line = raw.replace(/^[ \t]+|[ \t]+$/g, '');
      if (!line) continue;
      const tok = line.split(' ')[0];
      const v = Number(tok);
      if (!/^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/.test(tok)) throw new Error(`input_grid_z: не число - «${line.slice(0, 40)}»`);
      out.push(f(v));
    }
    return out;
  }
  int(n) { const x = this.values[n]; if (!x) return null; if (x.t === 'int') return x.v; if (x.t === 'double') return Math.trunc(x.v); return null; }
  double(n) { const x = this.values[n]; if (!x) return null; if (x.t === 'double' || x.t === 'int') return x.v; return null; }
  bool(n) { const x = this.values[n]; return x && x.t === 'bool' ? x.v : null; }
  get radar() { return [this.double('radar_x') ?? 0, this.double('radar_y') ?? 0]; }
  get hasRadar() { return this.values.radar_x != null || this.values.radar_y != null; }
  get isStretched() { return (this.int('stretch_x') ?? 0) !== 0 || (this.int('stretch_y') ?? 0) !== 0; }
  get nx() { return this.int('nx'); } get ny() { return this.int('ny'); } get nz() { return this.int('nz'); }
  get dx() { return this.double('dx'); } get dy() { return this.double('dy'); } get dz() { return this.double('dz'); }
  get dt() { return this.double('dtl'); }
}

function convert(v) {
  if (v instanceof JNum) return v.isInt ? CV.int(v.v) : CV.double(v.v);
  if (typeof v === 'boolean') return CV.bool(v);
  if (typeof v === 'number') return Number.isInteger(v) ? CV.int(v) : CV.double(v);
  return null;
}
const cmpKey = (a, b) => (a < b ? -1 : a > b ? 1 : 0);

export const ConfigParser = {
  required: ['nx', 'ny', 'nz', 'dx', 'dy', 'dz', 'dtl'],

  // Текст: namelist.input CM1 или JSON (типы чисел сохраняются).
  parseText(text) {
    if (NamelistParser.looksLikeNamelist(text)) return NamelistParser.parse(text);
    const root = parseJSONTyped(text);
    if (root == null || typeof root !== 'object' || Array.isArray(root)) throw new Error('секция корень не является объектом JSON');
    return ConfigParser.parse(root);
  },

  parse(root) {
    const values = {}, missing = [], subs = [], unported = [];
    for (const section of Object.keys(root).sort(cmpKey)) {
      const raw = root[section];
      if (NamelistCatalogue.sectionsWithoutDocumentation.includes(section)) {
        throw new Error(`секция ${section} не описана в README.namelist эталона и потому не заводится: поле без ссылки на источник завести нельзя`);
      }
      if (NamelistCatalogue.unportedSections[section] != null) { unported.push(section); continue; }
      const isObj = raw != null && typeof raw === 'object' && !Array.isArray(raw) && !(raw instanceof JNum);
      if (section === NamelistCatalogue.diagnosticSection || section === NamelistCatalogue.ownSection) {
        if (!isObj) throw new Error(`секция ${section} не является объектом JSON`);
        const allowed = section === NamelistCatalogue.diagnosticSection ? NamelistCatalogue.diagnosticFields : NamelistCatalogue.ownFields;
        for (const field of Object.keys(raw).sort(cmpKey)) {
          if (!allowed.includes(field)) throw new Error(`секция ${section}: поле ${field} не заведено. Поле без ссылки на README.namelist не заводится (SCHEMA.md)`);
          const value = convert(raw[field]);
          if (!value) throw new Error(`секция ${section}, поле ${field}: значение не число и не логическое`);
          values[field] = value;
        }
        continue;
      }
      if (!isObj) throw new Error(`секция ${section} не является объектом JSON`);
      if (!NamelistCatalogue.fields.some(s => s.section === section)) throw new Error(`секция ${section} не заведена и не числится непортированной`);
      for (const field of Object.keys(raw).sort(cmpKey)) {
        const sp = NamelistCatalogue.spec(field);
        if (!sp || sp.section !== section) throw new Error(`секция ${section}: поле ${field} не заведено. Поле без ссылки на README.namelist не заводится (SCHEMA.md)`);
        const value = convert(raw[field]);
        if (!value) throw new Error(`секция ${section}, поле ${field}: значение не число и не логическое`);
        const rule = sp.rule;
        switch (rule.kind) {
          case 'supported': values[field] = value; break;
          case 'ignored': break;
          case 'referenceOnly':
            if (!rule.allowed.some(a => CV.matches(value, a))) {
              throw new Error(`поле ${field} = ${CV.desc(value)}: поддерживается только ${rule.allowed.map(CV.desc).join(', ')}`
                + ` - иное значение означает другую схему, и считать её мы будем неправильно (${sp.reference})`);
            }
            values[field] = value;
            break;
          case 'notPorted': {
            const active = value.t === 'bool' ? value.v : rule.activeWhen === 'positive' ? value.v > 0 : value.v !== 0;
            if (active) missing.push({ field, enables: rule.enables, reference: sp.reference, value });
            break;
          }
          case 'substituted':
            if (rule.supported.some(a => CV.matches(value, a))) values[field] = value;
            else if (value.t === 'int' && rule.alternatives[value.v] != null) {
              subs.push({ field, asked: rule.alternatives[value.v], given: rule.given, reference: sp.reference, value: value.v });
            } else {
              throw new Error(`поле ${field} = ${CV.desc(value)}: поддерживается только `
                + [...rule.supported.map(CV.desc), ...Object.keys(rule.alternatives).sort((a, b) => a - b)].join(', ')
                + ` - иное значение означает другую схему, и считать её мы будем неправильно (${sp.reference})`);
            }
            break;
        }
      }
    }
    for (const fl of ConfigParser.required) if (values[fl] == null) {
      throw new Error(`секция ${NamelistCatalogue.spec(fl)?.section ?? '?'}: обязательное поле ${fl} отсутствует`);
    }
    const dOf = n => { const x = values[n]; return x && (x.t === 'double' || x.t === 'int') ? x.v : null; };
    const iOf = n => { const x = values[n]; return x ? (x.t === 'int' ? x.v : x.t === 'double' ? Math.trunc(x.v) : null) : null; };
    let dx = dOf('dx'), dy = dOf('dy');
    if ((iOf('stretch_x') ?? 0) !== 0 && dOf('dx_inner') != null) dx = dOf('dx_inner');
    if ((iOf('stretch_y') ?? 0) !== 0 && dOf('dy_inner') != null) dy = dOf('dy_inner');
    const nyv = iOf('ny');
    let schedule;
    const explicitZ = (iOf('psolver') ?? 3) === 2;
    let dzMin = dOf('dz');
    if (explicitZ && (iOf('stretch_z') ?? 0) !== 0 && dOf('dz_bot') != null) dzMin = dOf('dz_bot');
    const minH = nyv === 1 ? dx : Math.min(dx, dy);
    try {
      schedule = AcousticSchedule.fromSpacing({ dt: dOf('dtl'), minHorizontalSpacing: minH, twoDimensional: nyv === 1,
        minVerticalSpacing: explicitZ ? dzMin : null });
    } catch (e) {
      if (e.tooManySubsteps && (iOf('adapt_dt') ?? 0) === 1) {
        const dtsm = AcousticSchedule.smallStep(minH, explicitZ ? dzMin : null, nyv === 1);
        schedule = new AcousticSchedule({ nsound: AcousticSchedule.maxNsound, dt: f(f(AcousticSchedule.maxNsound) * dtsm) });
      } else throw e;
    }
    return new Configuration({ values, inventory: new Inventory({ missing, substitutions: subs, unportedSections: unported }), schedule });
  },
};

// ---- NamelistParser
export const NamelistParser = {
  looksLikeNamelist(text) { return text.split('\n').some(l => l.replace(/^[ \t]+/, '').startsWith('&')); },
  sections(text) {
    const root = {};
    let current = null, body = {};
    text.split('\n').forEach((raw, n) => {
      let line = raw;
      const bang = line.indexOf('!');
      if (bang >= 0) line = line.slice(0, bang);
      line = line.replace(/^[ \t\r]+|[ \t\r]+$/g, '');
      if (!line) return;
      if (line.startsWith('&')) { current = line.slice(1).trim(); body = {}; return; }
      if (line === '/') {
        if (current == null) throw new Error(`строка ${n + 1}: не разобрана: ${line}`);
        root[current] = body; current = null; body = {};
        return;
      }
      if (current == null) throw new Error(`строка ${n + 1}: не разобрана: ${line}`);
      for (const piece of line.split(',')) {
        const p = piece.trim();
        if (!p) continue;
        const eq = p.indexOf('=');
        if (eq < 0) throw new Error(`строка ${n + 1}: не разобрана: ${p}`);
        const name = p.slice(0, eq).trim().toLowerCase();
        const value = p.slice(eq + 1).trim();
        body[name] = NamelistParser.parseValue(name, value);
      }
    });
    if (!Object.keys(root).length) throw new Error('это не namelist CM1: нет ни одной секции &param');
    return root;
  },
  parseValue(name, v) {
    const low = v.toLowerCase();
    if (low === '.true.' || low === 't') return true;
    if (low === '.false.' || low === 'f') return false;
    if (/^[+-]?\d+$/.test(v)) return new JNum(parseInt(v, 10), true);
    const d = v.replace(/[dD]/g, 'e');
    if (/^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/.test(d)) return new JNum(Number(d), false);
    throw new Error(`поле ${name}: значение «${v}» не число и не логическое`);
  },
  parse(text) {
    const root = NamelistParser.sections(text);
    for (const s of NamelistCatalogue.sectionsWithoutDocumentation) delete root[s];
    return ConfigParser.parse(root);
  },
};

// ---- ScenarioBuilder
// Типы шага (простые объекты с умолчаниями эталона; TimeStep принимает их как есть).
export const StepTypes = {
  SurfaceFluxes: () => ({ constantRoughness: null, cecd: 3, cnstcd: 0.001, cnstce: 0.001, xland: 2, tsk0: 299.28,
    znt0: 0.01 / 100, mavail: 1.0, heatAndMoisture: true, constantFriction: null, constantFluxes: null,
    heatFluxCutoff: null, model: 1, testcase: 0, mostUseAverage: false }),
  PBL: () => ({ vertical: true, linf: 75, horizontal: true, lh: 100, lhref1: 100, lhref2: 1000 }),
  DNS: () => ({ viscosity: 16.23, prandtl: 1.0, wallCondition: 1, wallThetaBottom: 300.0, wallThetaTop: 300.0, th0r: 300.0 }),
  LandSurfacePBL: (lu, tsk, tmn) => ({ lu, tsk, tmn }),
  landSummer(lu) {
    switch (lu) {
      case 3: return { albd: 18, slmo: 0.50, sfem: 0.985, sfz0: 10, therin: 4 };
      case 16: return { albd: 8, slmo: 1.0, sfem: 0.98, sfz0: 0.01, therin: 6 };
      case 18: return { albd: 14, slmo: 0.35, sfem: 0.95, sfz0: 40, therin: 5 };
      default: return null;
    }
  },
};

export const ScenarioBuilder = {
  verticalGrid(c) {
    return ScenarioBuilder.verticalGridFrom({ nz: c.nz, dz: c.dz, stretchZ: c.int('stretch_z') ?? 0,
      ztop: c.double('ztop') ?? 0, strBot: c.double('str_bot') ?? 0, strTop: c.double('str_top') ?? 0,
      dzBot: c.double('dz_bot') ?? 0, dzTop: c.double('dz_top') ?? 0, levels: c.gridLevels });
  },
  verticalGridFrom({ nz, dz, stretchZ, ztop, strBot, strTop, dzBot, dzTop, levels = null }) {
    if (stretchZ === 3) {
      if (!levels) throw new Error('stretch_z = 3: нужен файл input_grid_z рядом с namelist (Configuration.gridLevels); без него CM1 останавливается (param.F:9011)');
      const fc = VerticalGrid.facesFromHalfLevels(levels, nz);
      if (!fc) throw new Error(`stretch_z = 3: в input_grid_z ${levels.length} уровней при nz = ${nz}, или грани не возрастают (param.F:7653-7659)`);
      return new VerticalGrid(fc, dz);
    }
    if (stretchZ !== 1) return VerticalGrid.uniform(nz, dz);
    const fc = VerticalGrid.williamsonChenFaces({ nz, ztop, strBot, strTop, dzBot, dzTop });
    if (!fc) throw new Error('stretch_z = 1: nz, ztop, str_bot, str_top, dz_bot, dz_top несовместимы (CM1 остановилась бы, param.F:7463-7510)');
    return new VerticalGrid(fc, dz);
  },
  analyticSounding(isnd, testcase) {
    switch (isnd) {
      case 5: return { kind: 'weismanKlemp', qvPbl: BaseState.qvPbl };
      case 8: return { kind: 'constantLapse', testcase };
      case 9: return { kind: 'constantN' };
      case 14: return { kind: 'convectiveBoundaryLayer' };
      case 15: return { kind: 'dycoms', testcase };
      case 18: return { kind: 'shearBoundaryLayer' };
      case 19: return { kind: 'bomex', testcase };
      case 20: return { kind: 'rico' };
      case 22: return { kind: 'stableBoundaryLayer' };
      default: return null;
    }
  },
  windProfile(iwnd, testcase) {
    switch (iwnd) {
      case 0: return { kind: 'calm' };
      case 1: return { kind: 'rkw88' };
      case 2: return { kind: 'weismanKlemp' };
      case 3: return { kind: 'cm1Multicell' };
      case 4: return { kind: 'weismanKlempMulticell' };
      case 6: return uniformWind(testcase);
      case 8: return { kind: 'hurricaneBoundaryLayer' };
      case 9: return { kind: 'bomex' };
      case 10: return { kind: 'dycomsDrizzle' };
      case 11: return { kind: 'rico' };
      default: return null;
    }
  },

  scenario(c, sounding = null) {
    const isnd = c.int('isnd') ?? 5;
    const moving = (c.int('imove') ?? 0) === 1;
    const umove = moving ? (c.double('umove') ?? 0) : 0;
    const vmove = moving ? (c.double('vmove') ?? 0) : 0;
    const moist = (c.int('imoist') ?? 1) !== 0;
    const testcase = c.int('testcase') ?? 0;
    const thermo = ThermoConstants.forTestcase(testcase);
    const iwnd = c.int('iwnd') ?? 2;
    const wind = ScenarioBuilder.windProfile(iwnd, testcase);
    if (!wind) throw new Error(`iwnd = ${iwnd} не портирован; есть 0 (штиль), 1 (RKW88), 2 (Вейсман-Клемп), 3 (мультиячейка CM1), 4 (мультиячейка Вейсмана-Клемпа), 6 (постоянный), 8 (ураганный ПС), 9 (BOMEX), 10 (DYCOMS RF02), 11 (RICO)`);

    let base = null;
    switch (isnd) {
      case 5:
        if (sounding) throw new Error(`isnd = ${isnd} - аналитическая зондировка, внешний файл не используется; передавать его значит вводить в заблуждение`);
        if (!moist) base = new BaseState({ sounding: { kind: 'weismanKlemp', qvPbl: BaseState.qvPbl }, zh: ScenarioBuilder.verticalGrid(c).zh,
          moist: false, umove, vmove, wind, thermo });
        break;
      case 8: case 9: case 14: case 15: case 18: case 19: case 20: case 22: {
        if (sounding) throw new Error(`isnd = ${isnd} - аналитическая зондировка, внешний файл не используется; передавать его значит вводить в заблуждение`);
        const analytic = ScenarioBuilder.analyticSounding(isnd, testcase);
        base = new BaseState({ sounding: analytic, zh: ScenarioBuilder.verticalGrid(c).zh, moist, umove, vmove, wind, thermo });
        break;
      }
      case 7: case 17: {
        if (!sounding) throw new Error(`isnd = ${isnd} требует внешнего файла зондировки (README.namelist:539), а он не передан`);
        const vertical = ScenarioBuilder.verticalGrid(c);
        const p = sounding.interpolated(vertical.zh, { moist, umove, vmove });
        base = new BaseState({ th0: p.th0, qv0: p.qv0, pi0: p.pi0, u0: p.u0, v0: p.v0, rh0: p.rh0 });
        break;
      }
      case 1:
        throw new Error('isnd = 1 (сухая адиабатическая, README.namelist:539) не портирован. Портированы 5 (аналитическая Вейсмана-Клемпа), 7/17 (внешний файл) и LES-случаи 8, 14, 18, 19, 20, 22. Сценарий построить нечем');
      default:
        throw new Error(`isnd = ${isnd} не портирован; поддерживаются 5 (Вейсмана-Клемпа), 7 и 17 (внешний файл), 8 (постоянный dθ/dz), 14 (конвективный ПС), 18 (сдвиговый ПС), 19 (BOMEX), 20 (RICO), 22 (устойчивый ПС)`);
    }

    const axisymm = (c.int('axisymm') ?? 0) === 1;
    const wallAsked = fl => c.inventory.substitutions.find(s => s.field === fl)?.value ?? (c.int(fl) ?? 1);
    if (axisymm) {
      if ((c.int('iorigin') ?? 2) !== 1) throw new Error('axisymm=1 требует iorigin=1 (param.F:1692)');
      if (c.ny !== 1) throw new Error('axisymm=1 требует ny=1 (param.F:1854)');
      if (!(wallAsked('wbc') === 3 && wallAsked('ebc') === 3)) throw new Error('axisymm=1 требует wbc=3 (param.F:1821); ebc=3 - единственная портированная внешняя стенка');
      if (!((c.int('sbc') ?? 1) === 1 && (c.int('nbc') ?? 1) === 1)) throw new Error('axisymm=1 требует sbc=nbc=1 (param.F:1838)');
      if (c.bool('terrain_flag') ?? false) throw new Error('axisymm=1 несовместим с рельефом (param.F:1803)');
      if ((c.int('cm1setup') ?? 1) === 1) throw new Error('axisymm=1 несовместим с cm1setup=1 (param.F:1870)');
      if (!(umove === 0 && vmove === 0)) throw new Error('axisymm=1 требует imove=0 (param.F:1708)');
    }
    const horizontal = (axis, n, dx, lo, hi) => {
      const s = c.int(`stretch_${axis}`) ?? 0;
      const axi = axisymm && axis === 'x';
      if (s === 0) return axi ? HorizontalGrid.uniform({ n, dx, centred: false, axisymmetric: true }) : null;
      if (![1, 2].includes(s)) throw new Error(`stretch_${axis} = ${s} не портирован; есть 0, 1, 2`);
      const inner = c.double(`d${axis}_inner`), outer = c.double(`d${axis}_outer`);
      const nos = c.double(`nos_${axis}_len`), tot = c.double(`tot_${axis}_len`);
      if (inner == null || outer == null || nos == null || tot == null) {
        throw new Error(`stretch_${axis} = ${s}, а d${axis}_inner/outer, nos_${axis}_len, tot_${axis}_len не заданы`);
      }
      return HorizontalGrid.stretched({ n, dx, stretch: s === 1 ? Stretch.both : Stretch.westOnly, inner, outer,
        noStretchLength: nos, totalLength: tot, centred: (c.int('iorigin') ?? 2) === 2,
        openWest: lo === 2, openEast: hi === 2, axisymmetric: axi });
    };
    const hx = horizontal('x', c.nx, c.dx, c.int('wbc') ?? 1, c.int('ebc') ?? 1);
    const hy = horizontal('y', c.ny, c.dy, c.int('sbc') ?? 1, c.int('nbc') ?? 1);
    const sc = new SupercellScenario({ nx: c.nx, ny: c.ny, nz: c.nz, dx: c.dx, dy: c.dy, dz: c.dz, dt: c.schedule.dt,
      umove, vmove, base, wind, hx, hy, vertical: ScenarioBuilder.verticalGrid(c) });
    sc.originAtCorner = (c.int('iorigin') ?? 2) === 1;
    sc.axisymmetric = axisymm;
    sc.thermo = thermo;
    sc.moist = moist;
    sc.wenoMomentum = (c.int('advwenov') ?? 0) === 2;
    const isfcflx = c.int('isfcflx') ?? 0;
    const bbc = c.int('bbc') ?? 1;
    if (bbc === 1) {
      if (isfcflx !== 0) throw new Error('isfcflx = 1 при bbc = 1: у CM1 потоки считаются только при bbc = 3');
    } else if (bbc === 2) {
      if (!(isfcflx === 0 && (c.int('cm1setup') ?? 1) === 3)) throw new Error('bbc = 2 портирован только при cm1setup = 3 и isfcflx = 0');
      sc.noSlipBottom = true;
    } else if (bbc === 3) {
      const sfcmodel = c.int('sfcmodel') ?? 0, setZnt = c.int('set_znt') ?? 0;
      if (![1, 3, 5].includes(sfcmodel)) throw new Error(`bbc = 3 портирован только с sfcmodel = 1, 3 и 5 (дано ${sfcmodel})`);
      if (sfcmodel === 3) {
        const ok = isfcflx === 1 && (c.int('cm1setup') ?? 1) === 2 && (c.int('ipbl') ?? 0) === 1
          && (c.int('isftcflx') ?? 0) === 0 && (c.int('iz0tlnd') ?? 0) === 0
          && (c.int('oceanmodel') ?? 1) === 1 && (c.int('season') ?? 1) === 1
          && setZnt === 0 && (c.int('set_ust') ?? 0) === 0 && (c.int('set_flx') ?? 0) === 0
          && (c.int('pertflx') ?? 0) === 0 && (c.int('imove') ?? 0) === 0 && moist;
        if (!ok) throw new Error('sfcmodel = 3 портирован при isfcflx = 1, cm1setup = 2, ipbl = 1, imoist = 1, isftcflx = iz0tlnd = 0, oceanmodel = 1, season = 1, без set_znt/set_ust/set_flx/pertflx/imove');
        const nx = c.nx, ny = c.ny, nc = nx * ny;
        const lu = new Array(nc).fill(c.int('lu0') ?? 16);
        const tsk = new Array(nc).fill(f(c.double('tsk0') ?? 299.28));
        const tmn = new Array(nc).fill(f(c.double('tmn0') ?? 297.28));
        if ((c.int('initsfc') ?? 1) === 2) {
          if (!((c.int('iorigin') ?? 2) === 1 && (c.int('stretch_x') ?? 0) === 0)) throw new Error('initsfc = 2 портирован при iorigin = 1 без растяжения по x');
          const dx = f(c.dx), maxx = f(f(nx) * dx);
          const x1 = f(f(3.0 / 8.0) * maxx), x2 = f(f(5.0 / 8.0) * maxx);
          for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++) {
            const xh = f(f(0.5) * f(f(f(i) * dx) + f(f(i + 1) * dx)));
            const land = xh >= x1 && xh <= x2;
            lu[i + nx * j] = land ? 18 : 16;
            tsk[i + nx * j] = land ? f(280.0) : f(287.0);
            tmn[i + nx * j] = f(tsk[i + nx * j] - f(0.5));
          }
        }
        for (const l of new Set(lu)) if (!StepTypes.landSummer(l)) throw new Error(`lu_index = ${l}: LANDUSE.TBL портирован для 3, 16, 18`);
        sc.landPBL = StepTypes.LandSurfacePBL(lu, tsk, tmn);
      } else if (sfcmodel === 5) {
        const z0 = c.double('cnst_znt');
        if (!(isfcflx === 1 && !moist && setZnt === 1 && z0 != null && z0 > 0)) {
          throw new Error('sfcmodel = 5 требует isfcflx = 1, imoist = 0 и set_znt = 1 с cnst_znt > 0 (param.F:739, 1490, 1507)');
        }
        const fl = StepTypes.SurfaceFluxes();
        fl.model = 5; fl.constantRoughness = z0; fl.xland = c.double('xland0') ?? 2; fl.tsk0 = c.double('tsk0') ?? 299.28;
        fl.testcase = testcase; fl.mostUseAverage = [1, 11].includes(testcase);
        sc.surfaceFluxes = fl;
      } else {
        if (setZnt === 1) {
          const z0 = c.double('cnst_znt');
          if (!(z0 != null && z0 > 0)) throw new Error('bbc = 3 с set_znt = 1 требует cnst_znt > 0');
          if (isfcflx === 0) sc.surfaceRoughness = z0;
        }
        if (isfcflx === 1 || setZnt === 0) {
          const fl = StepTypes.SurfaceFluxes();
          fl.constantRoughness = setZnt === 1 ? c.double('cnst_znt') : null;
          fl.cecd = c.int('cecd') ?? 3;
          fl.cnstcd = c.double('cnstcd') ?? 0.001;
          fl.cnstce = c.double('cnstce') ?? 0.001;
          fl.xland = c.double('xland0') ?? 2;
          fl.tsk0 = c.double('tsk0') ?? 299.28;
          fl.heatAndMoisture = isfcflx === 1;
          if ((c.int('lu0') ?? 16) === 3) { fl.znt0 = 10.0 / 100; fl.mavail = 0.50; }
          else { fl.znt0 = 0.01 / 100; fl.mavail = 1.0; }
          if (fl.xland > 1.5) fl.mavail = 1.0;
          if ([2, 6].includes(testcase)) fl.heatFluxCutoff = 3000;
          fl.testcase = testcase;
          if ((c.int('set_ust') ?? 0) === 1 && setZnt === 0) fl.constantFriction = c.double('cnst_ust') ?? 0;
          if ((c.int('set_flx') ?? 0) === 1 && isfcflx === 1) fl.constantFluxes = { heat: c.double('cnst_shflx') ?? 0, moisture: c.double('cnst_lhflx') ?? 0 };
          sc.surfaceFluxes = fl;
        }
      }
    } else throw new Error(`bbc = ${bbc} не портирован; есть 1 (скольжение) и 3 (трение)`);

    const iinit = c.int('iinit') ?? 1;
    switch (iinit) {
      case 0: sc.perturbation = { kind: 'none' }; break;
      case 1: {
        sc.perturbation = { kind: 'warmBubble' };
        const amp = c.double('var6');
        if (amp != null && amp > 0) {
          if ((c.int('iorigin') ?? 2) !== 2) throw new Error('пузырь задан через &param8 (var6 > 0) при iorigin = 1: var2 у CM1 - абсолютная координата, а не смещение от центра, и перенести её нечем');
          const bb = new WarmBubble();
          bb.amplitude = amp;
          bb.offsetX = c.double('var2') ?? 0;
          bb.centerZ = c.double('var3') ?? bb.centerZ;
          bb.radiusH = c.double('var4') ?? bb.radiusH;
          bb.radiusV = c.double('var5') ?? bb.radiusV;
          sc.bubble = bb;
        }
        break;
      }
      case 2: sc.perturbation = { kind: 'coldPool', cp: new ColdPool() }; break;
      case 3: sc.perturbation = { kind: 'bubbleLine', bl: new BubbleLine() }; break;
      case 7: sc.perturbation = { kind: 'vortex', vx: new RotunnoEmanuelVortex(c.int('var1') ?? 0) }; break;
      case 8: sc.perturbation = { kind: 'lineThermal', seed: c.int('var1') ?? 0 }; break;
      default: throw new Error(`iinit = ${iinit} не портирован; есть 1 (тёплый пузырь), 2 (холодный бассейн), 3 (линия пузырей), 7 (вихрь Ротунно–Эмануэля) и 8 (линейный термик со случайными возмущениями)`);
    }
    const cm1setup = c.int('cm1setup') ?? 1;
    const les = cm1setup === 1 && (c.int('sgsmodel') ?? 0) === 1;
    if (les) { const t = c.int('tconfig'); if (t != null && t !== 1) throw new Error(`tconfig = ${t} при sgsmodel = 1 не портирован (есть 1)`); }
    const ipbl = c.int('ipbl') ?? 0, horizturb = c.int('horizturb') ?? 0;
    const meso = cm1setup === 2 && (ipbl === 2 || horizturb === 1);
    const ysu = cm1setup === 2 && ipbl === 1;
    if (ysu && !(sc.landPBL != null && horizturb === 0 && (c.int('idiss') ?? 0) === 0)) {
      throw new Error('ipbl = 1 (YSU) портирован с bbc = 3, sfcmodel = 3, без horizturb и idiss');
    }
    if (meso) {
      const p = StepTypes.PBL();
      p.vertical = ipbl === 2; p.horizontal = horizturb === 1;
      p.linf = c.double('l_inf') ?? 75; p.lh = c.double('l_h') ?? 100;
      p.lhref1 = c.double('lhref1') ?? 100; p.lhref2 = c.double('lhref2') ?? 1000;
      sc.pbl = p;
    }
    if ((c.int('irandp') ?? 0) === 1) {
      sc.randomPerturbationSeed = c.int('var1') ?? 0;
      sc.randomPerturbationTestcase = testcase;
    }
    if (c.bool('terrain_flag') ?? false) {
      const itern = c.int('itern') ?? 0;
      if (itern !== 1) throw new Error(`terrain_flag с itern = ${itern}: портирован только колокол (itern = 1)`);
      const analytic = ScenarioBuilder.analyticSounding(isnd, testcase);
      if (!analytic) throw new Error(`рельеф с isnd = ${isnd} (зондировка из файла) не портирован`);
      const order = Math.max(c.int('hadvordrs') ?? 5, c.int('hadvordrv') ?? 5);
      const g = sc.grid;
      sc.terrain = new TerrainGeometry({ grid: g, flat: ScenarioBuilder.verticalGrid(c), zs: TerrainGeometry.bellHill(g.hx),
        periodicX: (c.int('wbc') ?? 1) === 1, periodicY: (c.int('sbc') ?? 1) === 1, advectionOrder: order });
      sc.columnBase = zh => new BaseState({ sounding: analytic, zh, moist, umove, vmove, wind, thermo });
    }
    if (testcase === 9) sc.turbulenceRampSeconds = 1800;
    if ((c.int('cm1setup') ?? 1) === 1) sc.initialTKETestcase = testcase;
    if (testcase === 5) sc.morrisonDrizzleFallSpeed = true;
    if ([4, 5].includes(testcase)) {
      if ((c.int('radopt') ?? 0) !== 0) throw new Error(`testcase ${testcase} с radopt ≥ 1: CM1 останавливается (param.F:2024)`);
      sc.simpleRadiation = true;
    }
    if ((c.int('adapt_dt') ?? 0) === 1) {
      const setup = c.int('cm1setup') ?? 1;
      if (!(setup === 0 || setup === 2 || (setup === 1 && (c.int('sgsmodel') ?? 0) === 1))) {
        throw new Error(`adapt_dt = 1 при cm1setup = ${setup}, sgsmodel = ${c.int('sgsmodel') ?? 0} не портирован: ksmax (calcksquick) собирается только по K схемы TKE (cm1setup=1, sgsmodel=1)`);
      }
      const freq = { tape: f(c.double('tapfrq') ?? 0), stat: f(c.double('statfrq') ?? 0), restart: f(c.double('rstfrq') ?? 0) };
      if (c.bool('dodomaindiag') === true) freq.domainDiag = f(c.double('diagfrq') ?? 0);
      if (c.bool('doazimavg') === true) freq.azimAvg = f(c.double('azimavgfrq') ?? 0);
      sc.adaptiveTimeStep = { dtl: f(c.double('dtl') ?? sc.dt), frequency: freq, ksCheck: (c.int('cm1setup') ?? 1) >= 1 };
    }
    if ((c.int('psolver') ?? 3) === 2) sc.explicitAcoustics = true;
    if ((c.int('eqtset') ?? 2) === 1) {
      if (moist) throw new Error('eqtset = 1 портирован только при imoist = 0');
      sc.usePressureTendency = false;
    }
    const dnsOn = cm1setup === 3;
    if (dnsOn) {
      const d = StepTypes.DNS();
      d.viscosity = c.double('viscosity') ?? 16.23; d.prandtl = c.double('pr_num') ?? 1.0;
      d.wallCondition = c.int('bc_temp') ?? 1;
      d.wallThetaBottom = c.double('ptc_bot') ?? 300.0; d.wallThetaTop = c.double('ptc_top') ?? 300.0;
      sc.dns = d;
    }
    if ((c.int('doimpl') ?? 1) === 0) {
      if (!(dnsOn || les)) throw new Error('doimpl = 0 портирован только при cm1setup = 3 (DNS) или cm1setup = 1, sgsmodel = 1 (LES)');
      sc.explicitVerticalDiffusion = true;
    }
    sc.bcturbs = c.int('bcturbs') ?? 1;
    if ((c.int('tbc') ?? 1) === 2) {
      if (!dnsOn) throw new Error('tbc = 2 портирован только при cm1setup = 3');
      sc.noSlipTop = true;
    }
    const irdamp = c.int('irdamp') ?? 0;
    sc.rayleighZd = c.double('zd') ?? 15000;
    sc.rayleighAlpha = c.double('rdalpha') ?? 3.3333333333e-3;
    sc.useTKE = les || meso || dnsOn || ysu;
    sc.rayleighDamping = irdamp !== 0;
    if (irdamp === 2) {
      if (!((c.int('stretch_x') ?? 0) === 0 && (c.int('stretch_y') ?? 0) === 0)) throw new Error('irdamp = 2 с растянутой горизонталью не портирован');
      sc.rayleighToAverage = true;
    }
    if ((c.int('hrdamp') ?? 0) === 1) {
      if (irdamp !== 1) throw new Error('hrdamp = 1 без irdamp = 1 не портирован');
      sc.lateralDampingWidth = c.double('xhd') ?? 100000;
    }
    if ((c.int('rterm') ?? 0) === 1) {
      if (!sc.useTKE) throw new Error('rterm = 1 без турбулентности или слоя Рэлея не портирован');
      sc.radiativeRelaxation = true;
    }
    sc.dissipativeHeating = (c.int('idiss') ?? 0) !== 0 && (les || meso);
    sc.conserveDryMass = (c.int('apmasscon') ?? 0) !== 0;
    sc.ihail = c.int('ihail') ?? 1;
    sc.iautoc = c.int('iautoc') ?? 1;
    const ptype = c.int('ptype') ?? 2;
    if (moist && ptype === 0) throw new Error('ptype = 0 при imoist = 1 (только пар) не портирован');
    if (ptype === 5) { sc.morrison = true; sc.ndcnst = c.double('ndcnst') ?? 250; }
    if ((c.int('radopt') ?? 0) === 2) {
      if (ptype !== 5) throw new Error('radopt = 2 портирован только с ptype = 5 (Моррисон)');
      const dtrad = c.double('dtrad'), lat = c.double('ctrlat'), lon = c.double('ctrlon');
      const y = c.int('year'), mo = c.int('month'), d = c.int('day'), h = c.int('hour'), mi = c.int('minute'), se = c.int('second');
      if ([dtrad, lat, lon, y, mo, d, h, mi, se].some(v => v == null)) throw new Error('radopt = 2: в &param11 нет даты/точки/dtrad - у CM1 умолчаний нет');
      const args = { year: y, month: mo, day: d, hour: h, minute: mi, second: se, ctrlat: f(lat), ctrlon: f(lon), dtrad: f(dtrad), testcase };
      const sun = RAD.RadiationSun ? new RAD.RadiationSun(args) : args;
      const tsk0 = c.double('tsk0');
      if (tsk0 == null) throw new Error('radopt = 2: нет tsk0 (&param12)');
      sc.radiation = new ScenarioRadiation({ sun, lu0: c.int('lu0') ?? 16, tsk0: f(tsk0) });
    }
    if (ptype === 6) {
      const vt = c.double('v_t');
      if (vt == null) throw new Error('ptype = 6 без v_t в &param3: у CM1 умолчания нет');
      sc.rotunnoEmanuel = true;
      sc.fallSpeedVT = f(vt);
    }
    if (testcase === 10) {
      if (!moist) throw new Error('testcase 10 при imoist = 0: сухое подтягивание θ (solve1.F:1538-1545) не портировано');
      sc.tqNudge = true;
    }
    if ([3, 4, 5, 6, 7, 10].includes(testcase)) {
      if (!TS.LargeScaleForcing) throw new Error(`testcase ${testcase}: крупномасштабный форсинг (LargeScaleForcing) ещё не перенесён в браузер`);
      const vg = ScenarioBuilder.verticalGrid(c);
      sc.forcing = TS.LargeScaleForcing.forTestcase(testcase, vg.zh, vg.zf, sc.base.u0, sc.base.v0, umove, vmove);
    }
    if ((c.int('icor') ?? 0) === 1) {
      sc.coriolis = c.double('fcor') ?? 0;
      const lspgrad = c.int('lspgrad') ?? 0;
      sc.largeScalePG = [1, 2, 3].includes(lspgrad);
      sc.largeScalePGMode = lspgrad === 0 ? 1 : lspgrad;
      if (lspgrad === 2 && sc.forcing?.hasGeostrophic !== true) {
        throw new Error('lspgrad = 2 требует профилей ug/vg, их задаёт только testcase 3/7 (base.F:2724, 2844)');
      }
      sc.hurricaneRadius = [6, 10].includes(testcase) ? 40000.0 : 1.0e30;
    }
    const w = c.int('wbc') ?? 1, e = c.int('ebc') ?? 1, s = c.int('sbc') ?? 1, n = c.int('nbc') ?? 1;
    if (!(w === e && s === n)) {
      throw new Error(`границы wbc=${w} ebc=${e} sbc=${s} nbc=${n} заданы вразнобой; по каждой оси обе стенки обязаны быть либо периодическими (1), либо открытыми (2)`);
    }
    sc.openX = w === 2;
    sc.openY = s === 2;
    sc.rigidX = axisymm && wallAsked('wbc') === 3;
    return sc;
  },
};

// ---- Preset.all
const derivedNote = what => 'dtl=6 при dx=1 км - сверенное отношение суперячейки; ' + what + '; эталонного прогона CM1 с этой постановкой нет';
const P = (file, title, summary, timestep, extra = {}) => ({ file, name: file.replace(/\.json$/, ''), title, summary,
  notBuildable: null, timestep, bundledSounding: null, soundingFile: null, ...extra });
export const PRESETS = [
  P('supercell.json', 'суперячейка 1 км',
    'классическая суперячейка Вейсмана-Клемпа: раскол, правый шторм, мезоциклон, крюк. Штатный конфиг CM1 (Моррисон); шаг сверен, горизонт сверен только на Годдарде',
    { kind: 'verified', text: 'штатный dtl=6 из namelist CM1; сверка одного шага из состояния эталона на 2580 с сходится по u,v,w до 4e-3 м/с (0.00 шагового приращения), перебор по dt 3..6 доживает до 3000 с с |w|max 54-56 при 53.5 у CM1 (KNOWN_GAPS, 2026-09-18). До 2026-09-18 стоял обход dt=3. Всё это - на Годдарде; на Моррисоне (с 2026-09-24) сверен один шаг, перебор по dt не повторялся' }),
  P('squall_line.json', 'шкваловая линия',
    'линия ячеек при слабом сдвиге (Bryan et al. 2003): холодный бассейн, новые ячейки на переднем крае, 300 км области',
    { kind: 'verified', text: 'штатный dtl=6 из config_files/squall_line (Bryan et al. 2003, слабый сдвиг RKW88, линейный термик). Отличие от примера CM1: микрофизика Моррисона (ptype=5), как в примере CM1 (с 2026-09-24; до того - Годдард). До горизонта на этой конфигурации не сверялось' }),
  P('dry2d.json', 'сухой 2D-пузырь', 'тест динамики без влаги',
    { kind: 'verified', text: 'конфигурация сверки dry2d_match: 300 шагов, расхождение theta\' 0.0069 K и w 0.159 м/с. При dx=100 выходит dtsm=0.167 с, и dt=3 потребовал бы nsound=18 вместо 6 - другое расписание подшагов и другой результат' },
    { notBuildable: 'isnd=1 (сухая адиабатическая) не портирован, и сценария сухого пузыря в ядре нет - он собирается в приложении вручную. Конфигурация разбирается и проверяется, сценарий пока не строится' }),
  P('supercell_stretched.json', 'суперячейка 500 м в центре',
    'та же суперячейка на растянутой сетке: 500 м в центральных 40 км, мезоциклон разрешается',
    { kind: 'verified', text: 'растянутая сетка CM1 (stretch_x=stretch_y=1, README.stretch): 500 м в центральных 40 км, до 2 км у краёв, область та же 120 км; dtl=3 под 500 м. Сверка одного шага из состояния эталона на растянутой сетке (2580 с): w, u, v 0.00, th 0.00, qv 0.01, qc 0.00, tke 0.01 шагового приращения (KNOWN_GAPS, 2026-09-18). До горизонта не сверялось' }),
  P('tornado_stretched.json', 'торнадо-сетка 100 м',
    '100 м в центральных 20 км, 50 м у земли, трение о землю - постановка для торнадо; долго и без гарантии',
    { kind: 'derived', text: 'dtl=0.6: по dtsmall CM1 при min_dx=100 м dtsm=0.167 с → nsound=4 (dts=0.15); CFL адвекции при |u| до 70 м/с и dx=100 м - 0.42, при |w| до 60 м/с и dz=50 м - 0.72. Растяжение сверено на stx_2580, трение на sfc_2580 (оба 0.00 шагового приращения), их сочетание на 100 м против CM1 не гонялось' }),
  P('single_cell.json', 'одиночная ячейка',
    'та же среда, сдвиг 5 м/с: одна ячейка, пик 45 м/с на 25-й минуте, к часу слабеет, после часа - россыпь мелких ячеек по краю холодного бассейна (прогон 2 ч)',
    { kind: 'derived', text: 'dtl=6 при dx=1 км - сверенное отношение суперячейки; среда - термодинамика Вейсмана-Клемпа с прямым сдвигом 5 м/с на 6 км (SoundingFactory), эталонного прогона CM1 с ней нет' },
    { bundledSounding: () => SoundingFactory.weismanKlemp({ shearTop: 5 }) }),
  P('multicell.json', 'мультиячейка',
    'сдвиг 15 м/с, прямой годограф: одна ячейка час, потом кластер из 3-6 ячеек с потоками 40-50 м/с, новые - на заднем фланге (прогон 2 ч)',
    { kind: 'derived', text: 'dtl=6 при dx=1 км; термодинамика Вейсмана-Клемпа с прямым сдвигом 15 м/с на 6 км, эталонного прогона CM1 нет' },
    { bundledSounding: () => SoundingFactory.weismanKlemp({ shearTop: 15 }) }),
  P('supercell_straight.json', 'суперячейка, прямой сдвиг',
    'сдвиг 30 м/с без кривизны годографа: раскол на 45-й минуте, зеркальная пара расходится на 50 км за час, между ними - новые ячейки (прогон 2 ч)',
    { kind: 'derived', text: 'dtl=6 при dx=1 км; термодинамика Вейсмана-Клемпа с прямым сдвигом 30 м/с на 6 км, эталонного прогона CM1 нет' },
    { bundledSounding: () => SoundingFactory.weismanKlemp({ shearTop: 30 }) }),
  P('pulse_storm.json', 'гроза без ветра',
    'ветра нет (iwnd=0): одна ячейка стоит на месте, пик на 30-й минуте (|w| 39 м/с, 72 dBZ), к часу распадается, потом кольцо новых ячеек по краю холодного бассейна. Картина строго симметрична - без ветра нарушить симметрию нечем (прогон 2 ч)',
    { kind: 'derived', text: derivedNote('штиль iwnd=0 (base.F:2208)') }),
  P('shear_wk82.json', 'сдвиг Вейсмана-Клемпа 1982',
    'профиль CM1 iwnd=4 (у CM1 назван «мультиячейка»), u = 35·th(z/3 км): сдвиг 0-6 км 33 м/с, поэтому НЕ мультиячейка, а раскол на зеркальную пару с 50-й минуты, ядра 31-36 м/с, к 2 ч разошлись на ±26 км (прогон 2 ч)',
    { kind: 'derived', text: derivedNote('iwnd=4, Weisman & Klemp 1982 (base.F:2345)') }),
  P('squall_cold_pool.json', 'шквал от холодного бассейна',
    'запуск «обрушением плотины» (холод −6 K на 2.5 км): линия по всему фронту к 20-й минуте, |w| 24-36 м/с, с 100-й минуты рвётся на 9-16 ячеек, позади - полоса слабого эха до 125 км (прогон 3 ч)',
    { kind: 'derived', text: derivedNote('iinit=2 (init3d.F:553), остальное - как шкваловая линия') }),
  P('mcs.json', 'МКС',
    'линейный термик при сдвиге 20 м/с на 0-5 км: система живёт все 4 часа, 3-7 ядер вдоль линии, |w| 30-53 м/с, эхо >40 dBZ 550-800 км², шлейф эха тянется по сдвигу на 100+ км (прогон 4 ч)',
    { kind: 'derived', text: derivedNote('линейный термик, прямой сдвиг 20 м/с на 5 км') },
    { bundledSounding: () => SoundingFactory.sounding({ wind: SoundingFactory.straight({ shear: 20, depth: 5000 }) }) }),
  P('bubble_line_shear.json', 'линия ячеек при сильном сдвиге',
    'три пузыря CM1 (iinit=3), сдвиг у земли 25 м/с на 0-2.5 км, CAPE 3100: мощные ячейки (|w| 44-60 м/с, 77 dBZ), к часу линия смыкается, край рваный. Эхо-дугу на сетке 1 км получить НЕ удалось (прогон 3 ч)',
    { kind: 'derived', text: derivedNote('iinit=3 (init3d.F:585), qv_pbl 16 г/кг, сдвиг 25 м/с на 2.5 км') },
    { bundledSounding: () => SoundingFactory.sounding({ qvPbl: 0.016, wind: SoundingFactory.straight({ shear: 25, depth: 2500 }) }) }),
  P('derecho_env.json', 'деречо-среда',
    'холодный бассейн при сдвиге у земли 20 м/с и CAPE 3100: линия не распадается все 3 часа, |w| до 55 м/с, идёт около 65 км/ч, эхо на 130 км. Среда деречо; сама буря деречо - сотни км и 6+ часов - в эту область не влезает (прогон 3 ч)',
    { kind: 'derived', text: derivedNote('iinit=2, qv_pbl 16 г/кг, сдвиг 20 м/с на 2.5 км') },
    { bundledSounding: () => SoundingFactory.sounding({ qvPbl: 0.016, wind: SoundingFactory.straight({ shear: 20, depth: 2500 }) }) }),
  P('supercell_high_cape.json', 'суперячейка, высокий CAPE',
    'годограф Вейсмана-Клемпа, qv 16 г/кг (CAPE 3100 против 1960): |w| до 73 м/с, раскол на 50-й минуте, к 2 ч эхо >40 dBZ на 2000 км², наковальня выходит за край области (прогон 2 ч)',
    { kind: 'derived', text: derivedNote('qv_pbl 16 г/кг, годограф iwnd=2') },
    { bundledSounding: () => SoundingFactory.sounding({ qvPbl: 0.016, wind: SoundingFactory.quarterCircle({ scale: 1.0 }) }) }),
  P('hslc.json', 'низкий CAPE, сильный сдвиг',
    'qv 12 г/кг (CAPE 980), сдвиг 0-6 км 47 м/с: медленный разгон - эхо лишь к 40-й минуте, ядра 13 м/с; к 2 ч |w| 45 м/с и раскол; правый шторм стоит в западной трети области (прогон 2 ч)',
    { kind: 'derived', text: derivedNote('qv_pbl 12 г/кг, годограф iwnd=2 ×1.5') },
    { bundledSounding: () => SoundingFactory.sounding({ qvPbl: 0.012, wind: SoundingFactory.quarterCircle({ scale: 1.5 }) }) }),
  P('hurricane_3d.json', 'ураган',
    'штатный hurricane_3d CM1: вихрь Ротунно–Эмануэля над океаном 28 °C, f-плоскость, 384×384 (4 км в центре, до 16 км к краям), 59 уровней; тяжёлый - арена около 4 ГБ, 8 суток модели',
    { kind: 'verified', text: 'штатный dtl=10 из config_files/hurricane_3d. Сверен один шаг из состояния эталона (w 0.01, θ 0.00 шагового приращения) и вихрь при t=0 (u, v, π′ до 2e-7); до горизонта не сверялось' },
    { soundingFile: 'hurricane_3d.input_sounding' }),
  P('target3d.json', 'суперячейка 500 м, равномерно',
    '200x200x64 на 500 м по всей области 100 км - тяжёлая, для планшета с запасом памяти',
    { kind: 'verified', text: 'штатное отношение dtl/dx = 6 с / 1000 м, перенесённое на dx=500 м; до горизонта на этой сетке не сверялось' }),
];

// Внешняя зондировка от пользователя (isnd=7: пять столбцов; 17: три).
export function parseSounding(text, { windsFromFile = true, moist = true } = {}) {
  return new Sounding({ text, windsFromFile, moist });
}

// Зондировка пресета: встроенная (SoundingFactory) или файл рядом с пресетом.
// fetchText(имя файла) -> текст или null. Без зондировки (isnd=5 и др.) - null.
export async function loadSounding(name, configuration, fetchText) {
  const p = PRESETS.find(x => x.name === name || x.file === name);
  if (p?.bundledSounding) return p.bundledSounding();
  const isnd = configuration.int('isnd') ?? 5;
  if (isnd !== 7 && isnd !== 17) return null;
  const file = p?.soundingFile ?? `${name}.input_sounding`;
  const text = await fetchText(file);
  if (text == null) return null;
  return new Sounding({ text, windsFromFile: isnd === 7, moist: (configuration.int('imoist') ?? 1) !== 0 });
}

// ---- ConfigChoice
export const ConfigChoice = {
  describe(c) {
    const dims = c.ny === 1 ? `${c.nx}x${c.nz} (2D)` : `${c.nx}x${c.ny}x${c.nz}`;
    return `${dims}, dx=${c.dx.toFixed(0)} м, dz=${c.dz.toFixed(0)} м, dt=${c.dt.toFixed(1)} с, подшагов ${c.schedule.nsound}`;
  },
  finish(c, s) {
    const isnd = c.int('isnd') ?? 5;
    if ((isnd === 7 || isnd === 17) && !s) return { kind: 'needsSounding', configuration: c };
    return { kind: 'ready', configuration: c, sounding: s };
  },
  // choose(preset, sounding:) - конфигурация пресета (obj или текст) и его зондировка
  choosePreset(p, configuration, sounding = null) {
    if (p.notBuildable) return { kind: 'blocked', reason: p.notBuildable };
    try { return ConfigChoice.finish(configuration, sounding ?? (p.bundledSounding ? p.bundledSounding() : null)); }
    catch (e) { return { kind: 'failed', reason: String(e.message ?? e) }; }
  },
  // choose(contentsOf:sounding:) - свой файл: namelist.input или JSON
  chooseText(text, sounding = null) {
    try { return ConfigChoice.finish(ConfigParser.parseText(text), sounding); }
    catch (e) { return { kind: 'failed', reason: String(e.message ?? e) }; }
  },
};

export { Sounding, SoundingFactory, BaseState };
