#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
# This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
# must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
"""Сайт по https для устройств в домашней сети (WebGPU требует https).
Сертификат самоподписанный: build/tls (openssl, см. CONTEXT.md).

  python3 tools/serve_https.py [порт]    # из корня репо, по умолчанию 8991
"""
import http.server
import ssl
import sys

port = int(sys.argv[1]) if len(sys.argv) > 1 else 8991
class NoCache(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()


srv = http.server.ThreadingHTTPServer(('0.0.0.0', port), NoCache)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain('build/tls/cert.pem', 'build/tls/key.pem')
srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
print(f'https://0.0.0.0:{port}/web/')
srv.serve_forever()
