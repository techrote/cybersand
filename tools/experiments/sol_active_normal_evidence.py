#!/usr/bin/env python3
"""Seal common structured values; raw bytes and all attempts remain distinct."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
def sha(raw):return hashlib.sha256(raw).hexdigest()

def main():
    source=ROOT/'build/sol-active-normal/registered-values';target=ROOT/'docs/audits/sol-active-normal-20261105';assert not target.exists();target.mkdir()
    receipt=json.loads((source/'receipt.json').read_text(encoding='utf-8'));comparison=json.loads((source/'comparison.json').read_text(encoding='utf-8'))
    manifest=dict(schema='cybersand.sol-active-normal.evidence.v1',execution_source=receipt['source'],files=[],local_raw_files=[],scope='Copied values only; no live World or original SOL authority')
    def write(name,value):
        raw=(json.dumps(value,indent=2)+'\n').encode();(target/name).write_bytes(raw);manifest['files'].append(dict(path=name,bytes=len(raw),sha256=sha(raw)))
    for arm in range(3):
        values=[json.loads((source/f'run-{platform}-{arm}.log').read_text(encoding='utf-8')) for platform in ['linux-opt','linux-san','windows-msvc']]
        assert values[0]==values[1]==values[2],'Do not collapse unequal observations'
        # Lossless parsed-value equality is explicit; original byte hashes stay in receipt.
        raw=(json.dumps(values[0],separators=(',',':'))+'\n').encode();name=f'arm-{arm}.json';(target/name).write_bytes(raw)
        manifest['files'].append(dict(path=name,bytes=len(raw),sha256=sha(raw),parsed_values_equal_across_three_compilers=True))
    write('execution.json',receipt);write('comparison.json',comparison)
    for path in sorted(source.iterdir()):
        if not path.is_file():continue
        manifest['local_raw_files'].append(dict(path=path.relative_to(ROOT).as_posix(),bytes=path.stat().st_size,sha256=sha(path.read_bytes())))
    write('source-adapter.json',dict(header_sha256=receipt['registration']['header_sha256'],generated=receipt['generated'],input_sha256=receipt['input_sha256'],scope='Ignored generated headers/binaries are not committed; generator is source-pinned'))
    (target/'manifest.json').write_bytes((json.dumps(manifest,indent=2)+'\n').encode())
    print(json.dumps(dict(source=receipt['source'],files=len(manifest['files']),raw_files=len(manifest['local_raw_files']),candidate_decision=comparison['candidate_decision'])))

if __name__=='__main__':main()
