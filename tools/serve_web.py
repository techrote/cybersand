#!/usr/bin/env python3
"""Serve a Godot Web export over loopback HTTP using Python 3.10+."""
from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import threading
import webbrowser


class WebHandler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map,
                      '.wasm': 'application/wasm', '.pck': 'application/octet-stream'}

    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cross-Origin-Resource-Policy', 'same-origin')
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()


def main(default_directory: Path | None = None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, default=default_directory or Path(__file__).resolve().parent)
    parser.add_argument('--port', type=int, default=8000)
    parser.add_argument('--bind', default='127.0.0.1')
    parser.add_argument('--open', action='store_true')
    args = parser.parse_args()
    directory = args.directory.resolve()
    for filename in ('index.html', 'index.js', 'index.wasm', 'index.pck'):
        if not (directory / filename).is_file():
            parser.error(f'Incomplete export: missing {directory / filename}')
    server = ThreadingHTTPServer((args.bind, args.port), partial(WebHandler, directory=str(directory)))
    url = f'http://{args.bind}:{server.server_port}/'
    print(f'Serving {directory}\n{url}\nPress Ctrl+C to stop.', flush=True)
    if args.open:
        threading.Timer(0.2, webbrowser.open, args=(url,)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
