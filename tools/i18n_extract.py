#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
# This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
# must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
"""Русские строки интерфейса и ядра для перевода: data/i18n/strings.json.

Строковые литералы ('', "", ``) с кириллицей из web/*.js, web/core/*.js и
текст HTML. Шаблон `...${x}...` становится ключом с {0}, {1}... - так его
ищет web/i18n.js в показанном тексте. Комментарии пропускаются.

  python3 tools/i18n_extract.py
"""
import json
import re
from pathlib import Path

CYR = re.compile('[А-Яа-яЁё]')
out = []


def add(s, where):
    s = s.strip()
    if s and CYR.search(s) and s not in seen:
        seen.add(s)
        out.append({'ru': s, 'at': where})


def strip_comments(src):
    # // и /* */ вне строк
    res, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c in '\'"`':
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == '\\' else 1
            res.append(src[i:j + 1]); i = j + 1
        elif src.startswith('//', i):
            j = src.find('\n', i); i = n if j < 0 else j
        elif src.startswith('/*', i):
            j = src.find('*/', i); i = n if j < 0 else j + 2
        else:
            res.append(c); i += 1
    return ''.join(res)


LIT = re.compile(r"'((?:[^'\\\n]|\\.)*)'|\"((?:[^\"\\\n]|\\.)*)\"|`((?:[^`\\]|\\.)*)`")


def scan(src, where):
    for m in LIT.finditer(src):
        s = m.group(1) or m.group(2)
        if m.group(3) is not None:
            s = template_key(m.group(3), where)
        if s is None:
            continue
        if '<' in s:
            for part in re.split(r'<[^>]*>', s):
                add(part, where)
            for a in re.finditer(r'(?:aria-label|placeholder|title)="([^"]*)"', s):
                add(a.group(1), where)
            continue
        add(s, where)


def template_key(body, where=None):
    # ${...} с вложенными скобками -> {k}; строки внутри подстановок - тоже в перевод
    res, k, i = [], 0, 0
    while i < len(body):
        if body.startswith('${', i):
            d, j = 0, i + 1
            while j < len(body):
                if body[j] == '{': d += 1
                elif body[j] == '}':
                    d -= 1
                    if d == 0: break
                j += 1
            if where:
                scan(body[i + 2:j], where)
            res.append('{%d}' % k); k += 1; i = j + 1
        else:
            res.append(body[i]); i += 1
    return ''.join(res)


seen = set()
files = sorted(Path('web').glob('*.js')) + sorted(Path('web/core').glob('*.js'))
for f in files:
    scan(strip_comments(f.read_text()), str(f))
for f in sorted(Path('web').glob('*.html')):
    src = re.sub(r'<script.*?</script>', '', f.read_text(), flags=re.S)
    src = re.sub(r'<style.*?</style>', '', src, flags=re.S)
    for part in re.split(r'<[^>]*>', src):
        add(part, str(f))
    for m in re.finditer(r'(?:aria-label|placeholder|title)="([^"]*)"', src):
        add(m.group(1), str(f))
# названия и описания сценариев сайта
for x in json.loads(Path('data/index.json').read_text()):
    for k in ('title', 'summary', 'off'):
        if isinstance(x.get(k), str):
            add(x[k], 'data/index.json')
Path('data/i18n/strings.json').write_text(json.dumps(out, ensure_ascii=False, indent=0))
print(len(out), 'строк')
