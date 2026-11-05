// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Свои пресеты - в localStorage этого браузера: { id, base, title, text, sounding, updated }.
// text - конфиг CM1 (JSON секций namelist), sounding - input_sounding или null,
// base - встроенный пресет, от которого скопирован (его зондировка по умолчанию).
const KEY = 'te.presets.v1';

function all() {
  try { return JSON.parse(localStorage.getItem(KEY) || '[]'); } catch { return []; }
}
function store(list) {
  try { localStorage.setItem(KEY, JSON.stringify(list)); return true; } catch { return false; }
}
export const listPresets = () => all().sort((a, b) => b.updated - a.updated);
export const getPreset = id => all().find(p => p.id === id) ?? null;
export function savePreset(p) {
  const list = all().filter(x => x.id !== p.id);
  list.push({ ...p, updated: Date.now() });
  return store(list);
}
export const deletePreset = id => store(all().filter(p => p.id !== id));
// Пресет в ссылке: JSON -> deflate -> base64url (#p=...). Зондировка из
// конструктора едет вместе с файлом, получатель видит то же самое.
const unb64u = s => Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0));
async function pipe(u8, stream) { return new Uint8Array(await new Response(new Blob([u8]).stream().pipeThrough(stream)).arrayBuffer()); }
export async function presetToLink(p) {
  const { title, base, text, sounding, sndSpec, sndPrev } = p;
  const z = await pipe(new TextEncoder().encode(JSON.stringify({ v: 1, title, base, text, sounding, sndSpec, sndPrev })), new CompressionStream('deflate-raw'));
  let s = '';
  for (let i = 0; i < z.length; i += 0x8000) s += String.fromCharCode(...z.subarray(i, i + 0x8000));
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
export async function presetFromLink(code) {
  const o = JSON.parse(new TextDecoder().decode(await pipe(unb64u(code), new DecompressionStream('deflate-raw'))));
  if (o.v !== 1 || typeof o.text !== 'string') throw new Error('ссылка не на пресет');
  return { title: String(o.title || 'пресет по ссылке'), base: o.base || 'supercell', text: o.text, sounding: o.sounding ?? null,
    sndSpec: o.sndSpec ?? null, sndPrev: o.sndPrev ?? null };
}
export const newId = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
