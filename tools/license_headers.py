#!/usr/bin/env python3
"""Заголовок лицензии (AGPL-3.0, NOTICE) в начало исходников; повторный
запуск ничего не меняет. Сгенерированные ядра WGSL получают тот же
заголовок от генератора ядер (LICENSE_HEADER).

  python3 tools/license_headers.py
"""
from pathlib import Path

LINES = [
    'SPDX-License-Identifier: AGPL-3.0-only',
    'Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web',
    'This file is part of ThunderEngine. Any use of it, modified or not, including on a website,',
    'must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).',
]
SKIP = {'node_modules', '.build', 'build', 'tape', '.git'}


def head(prefix):
    return ''.join(f'{prefix}{l}\n' for l in LINES)


done = 0
for f in sorted(Path('.').rglob('*')):
    if not f.is_file() or SKIP & set(f.parts):
        continue
    ext = f.suffix
    if ext not in ('.js', '.html', '.py', '.wgsl'):
        continue
    s = f.read_text()
    if 'SPDX-License-Identifier' in s[:600]:
        continue
    if ext == '.html':
        # сразу после <!doctype html>, а не после первой строки: в ней может начинаться
        # <script type="module">, и HTML-комментарий внутри модуля - синтаксическая ошибка
        block = '<!--\n' + ''.join(f'  {l}\n' for l in LINES) + '-->\n'
        i = s.lower().find('<!doctype html>')
        if i == 0:
            j = len('<!doctype html>')
            s = s[:j] + '\n' + block + s[j:].lstrip('\n')
        else:
            s = block + s
    elif ext == '.py':
        h = head('# ')
        if s.startswith('#!'):
            first, rest = s.split('\n', 1)
            s = first + '\n' + h + rest
        else:
            s = h + s
    else:
        s = head('// ') + s
    f.write_text(s)
    done += 1
print('заголовков поставлено:', done)
