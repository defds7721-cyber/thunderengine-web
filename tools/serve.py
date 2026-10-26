#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
# This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
# must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
"""Сайт для разработки: раздача корня репо без кэша (вложенные модули JS иначе
берутся из кэша WebKit и проверка идёт на старом коде).

  python3 tools/serve.py [порт]       # из корня репо, по умолчанию 8990
"""
import http.server
import sys


class NoCache(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, *a):
        pass


port = int(sys.argv[1]) if len(sys.argv) > 1 else 8990
http.server.ThreadingHTTPServer(('127.0.0.1', port), NoCache).serve_forever()
