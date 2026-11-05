// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Экран «нет WebGPU»: что сделать на этом устройстве, остальные платформы - свёрнуто.
// Каждый текст - отдельный узел с русским литералом, чтобы его нашёл i18n.js.

const ua = navigator.userAgent;
const IOS = /iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
const ANDROID = /Android/.test(ua);
const WIN = /Windows/.test(ua);
const MAC = /Macintosh/.test(ua) && !IOS;
const LINUX = /Linux/.test(ua) && !ANDROID;
const YA = /YaBrowser/.test(ua), SAMSUNG = /SamsungBrowser/.test(ua), FF = /Firefox|FxiOS/.test(ua);

// шаг: строка или [текст, код, текст]; код (адреса chrome://) не переводится
const FLAG = ['Если не помогло: открыть адрес', 'chrome://flags/#enable-unsafe-webgpu', ', выбрать Enabled и перезапустить браузер.'];
const PLATFORMS = [
  { key: 'android', title: 'Android', steps: [
    'Открыть сайт в Google Chrome: Яндекс Браузер, Samsung Internet и Firefox на Android WebGPU обычно не дают.',
    'Обновить Chrome через Google Play. Нужен Chrome 121 или новее и Android 12 или новее.',
    FLAG,
  ] },
  { key: 'ios', title: 'iPhone и iPad', steps: [
    'Обновить систему до iOS 26 или новее: там WebGPU в Safari включён сам.',
    'На iOS 18: Настройки - Приложения - Safari - Дополнения - Feature Flags - включить WebGPU.',
    'Chrome и другие браузеры на iPhone работают на движке Safari: им нужно то же самое.',
  ] },
  { key: 'win', title: 'Windows', steps: [
    'Открыть сайт в Chrome или Edge последней версии (Firefox - с версии 141).',
    'В настройках браузера (Система) включить «Использовать аппаратное ускорение» и перезапустить браузер.',
    'Обновить драйвер видеокарты с сайта NVIDIA, AMD или Intel.',
    ['Открыть', 'chrome://gpu', ': в строке WebGPU должно быть Hardware accelerated.'],
    FLAG,
  ] },
  { key: 'mac', title: 'Mac', steps: [
    'Safari на macOS 26 или новее, либо Chrome последней версии.',
  ] },
  { key: 'linux', title: 'Linux', steps: [
    'Chrome последней версии с включёнными флагами:',
    ['', 'chrome://flags/#enable-unsafe-webgpu', ''],
    ['', 'chrome://flags/#enable-vulkan', ''],
  ] },
];

function el(tag, text, cls) {
  const e = document.createElement(tag);
  if (text != null) e.textContent = text;
  if (cls) e.className = cls;
  return e;
}

function stepList(steps) {
  const ol = el('ol');
  for (const s of steps) {
    const li = el('li');
    if (typeof s === 'string') li.append(el('span', s));
    else {
      if (s[0]) li.append(el('span', s[0]), ' ');
      li.append(el('code', s[1]));
      if (s[2]) li.append(el('span', s[2]));
    }
    ol.append(li);
  }
  return ol;
}

export function showNoGpu() {
  const mine = ANDROID ? 'android' : IOS ? 'ios' : WIN ? 'win' : MAC ? 'mac' : LINUX ? 'linux' : null;
  const box = el('div', null, 'nogpu');
  box.append(el('h2', 'Браузер не даёт доступ к видеокарте'));
  box.append(el('p', 'Гроза считается на видеокарте через WebGPU. Без него сайт работать не может.', 'muted'));
  if (YA) box.append(el('p', 'Яндекс Браузер WebGPU обычно не даёт: проще открыть сайт в Chrome.'));
  else if (SAMSUNG) box.append(el('p', 'Samsung Internet WebGPU не даёт: откройте сайт в Chrome.'));
  else if (FF && (ANDROID || LINUX)) box.append(el('p', 'Firefox здесь WebGPU пока не даёт: откройте сайт в Chrome.'));
  const p = PLATFORMS.find(x => x.key === mine);
  if (p) { box.append(el('h3', p.title)); box.append(stepList(p.steps)); }
  const more = el('details');
  more.append(el('summary', 'Другие устройства'));
  for (const x of PLATFORMS) if (x !== p) { more.append(el('h3', x.title)); more.append(stepList(x.steps)); }
  box.append(more);
  const again = el('button', 'Проверить снова', 'btn on');
  again.onclick = () => location.reload();
  box.append(again);
  document.body.append(box);
}
