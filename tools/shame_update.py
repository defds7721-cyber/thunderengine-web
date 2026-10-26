#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
# This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
# must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
"""Доска почёта: журнал срабатываний ключа-приманки (canarytokens) ->
data/shame.json, 10 последних. Наружу - только время, страна и запрос
(ни IP, ни провайдера; в ответе canarytokens есть и IP создателя токена).
Ничего из ответа не печатается: логи Actions публичного репо видны всем.

  CANARY_HISTORY_URL=... python3 tools/shame_update.py
"""
import json
import os
import re
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

OUT = Path('data/shame.json')
# свои проверки утёкших ключей у GitHub и AWS - не в счёт
# AWS пишет о себе «AWS Internal» (src_ip и useragent) - карантин утёкшего ключа
SECURITY = re.compile(r'github|aws[ -]?internal|amazon-security|gitguardian', re.I)


def first(v):
    return v[0] if isinstance(v, list) and v else v


def entry(hit):
    t = hit.get('time_of_hit')
    try:
        when = datetime.fromtimestamp(float(t), timezone.utc)
    except (TypeError, ValueError):
        return None
    geo = hit.get('geo_info') or {}
    cc = geo.get('country') if isinstance(geo, dict) else None
    log = ((hit.get('additional_info') or {}).get('aws_key_log_data') or {})
    event = first(log.get('eventName')) or ''
    source = (first(log.get('eventSource')) or '').replace('.amazonaws.com', '')
    action = f'{source}:{event}' if source and event else event or None
    ua = str(first(log.get('userAgent')) or hit.get('useragent') or '')
    org = str(geo.get('org') or '') if isinstance(geo, dict) else ''
    src = str(hit.get('src_ip') or '')
    return {'time': when.isoformat().replace('+00:00', 'Z'),
            'cc': cc if isinstance(cc, str) and re.fullmatch(r'[A-Z]{2}', cc) else None,
            'action': action,
            'security': bool(SECURITY.search(ua) or SECURITY.search(org) or SECURITY.search(src))}


def main():
    url = os.environ.get('CANARY_HISTORY_URL')
    if not url:
        sys.exit('нет CANARY_HISTORY_URL')
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            data = json.load(r)
    except Exception as e:  # без текста ответа и адреса
        sys.exit(f'журнал не получен: {type(e).__name__}')
    hits = (((data.get('canarydrop') or {}).get('triggered_details') or {}).get('hits')) or []
    if isinstance(hits, dict):
        hits = list(hits.values())
    rows = [e for e in (entry(h) for h in hits if isinstance(h, dict)) if e]
    rows.sort(key=lambda e: e['time'], reverse=True)
    bots = [{k: e[k] for k in ('time', 'cc', 'action')} for e in rows if not e['security']][:10]
    checks = sum(e['security'] for e in rows)
    old = json.loads(OUT.read_text()) if OUT.exists() else {}
    if old.get('entries') == bots and old.get('checks', 0) == checks:
        print('без изменений')
        return
    OUT.write_text(json.dumps({'updated': datetime.now(timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z'),
                               'checks': checks, 'entries': bots}, ensure_ascii=False, indent=1) + '\n')
    print(f'обновлено: попались {len(bots)}, проверок {checks}')


if __name__ == '__main__':
    main()
