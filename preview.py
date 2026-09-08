#!/usr/bin/env python3
"""Preview the supplied export if present, otherwise the local rebuilt export."""
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('cybersand_serve_web', ROOT / 'source/tools/serve_web.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

if __name__ == '__main__':
    module.main(ROOT / ('static-web' if (ROOT / 'static-web/index.html').is_file() else 'source/build/web'))
