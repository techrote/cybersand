#!/usr/bin/env python3
"""Read-only dependency snapshot, executed on the actual compiler host."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

def snapshot(sdk,compiler,wrapper):
    sdk=Path(sdk);compiler=Path(compiler).resolve();wrapper=Path(wrapper)
    paths={p.resolve() for d in ['include','gen/include','gdextension','bin'] for p in (sdk/d).rglob('*') if p.is_file()}
    paths.add(sdk/'.cybersand-source-files.sha256');paths.add(compiler);paths.add(wrapper)
    if sys.platform=='win32':
        toolchain=compiler.parent.parent
        paths.update(p.resolve() for p in toolchain.rglob('*') if p.is_file())
    else:
        for name in ['cc1plus','collect2']:
            paths.add(Path(subprocess.check_output([str(compiler),'-print-prog-name='+name],text=True).strip()).resolve())
        paths.add(Path('/usr/bin/ld').resolve())
    return {str(p):{'size':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(paths)}

if __name__=='__main__':print(json.dumps(snapshot(*sys.argv[1:]),sort_keys=True))
