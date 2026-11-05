#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
# This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
# must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
"""Описания полей namelist для редактора пресетов: data/namelist_doc.json.

Поле и строка README берутся из каталога полей эталона (записи вида
FieldSpec("имя", section: "...", readme: N, ...)), текст - абзац
README.namelist эталона CM1 r20.2 с этой строки до следующего поля.

  python3 tools/namelist_doc.py <каталог полей> <README.namelist>
"""
import json
import re
import sys
from pathlib import Path

cat = Path(sys.argv[1]).read_text()
readme = Path(sys.argv[2]).read_text(errors='replace').splitlines()
specs = re.findall(r'FieldSpec\("(\w+)",\s*section:\s*"(\w+)",\s*readme:\s*(\d+)', cat)
field_start = re.compile(r'^ {1,3}[a-z_0-9]+(, *[a-z_0-9]+)* +- ')
out = {}
for name, section, line in specs:
    i = int(line) - 1
    block = [readme[i].rstrip()]
    for j in range(i + 1, min(i + 60, len(readme))):
        t = readme[j]
        if field_start.match(t) or re.match(r'^\s*-{5,}|^\s*param\d+ section|^ ?&', t):
            break
        block.append(t.rstrip())
    while block and not block[-1].strip():
        block.pop()
    out[name] = {'section': section, 'readme': int(line), 'text': '\n'.join(block)}
Path('data/namelist_doc.json').write_text(json.dumps(out, ensure_ascii=False, indent=1))
print(len(out), 'полей')
