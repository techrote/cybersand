#!/usr/bin/env python3
"""Inventory exact original evidence for the parent to persist, without copying it."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parent
ARTIFACTS = ROOT / 'artifacts'


def identity(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        while data := stream.read(1024 * 1024):
            h.update(data)
    return {'path': str(path), 'relative_path': path.relative_to(ROOT).as_posix(),
            'bytes': path.stat().st_size, 'sha256': h.hexdigest()}


def main():
    closure = json.loads((ROOT / 'independent_hosted_closure.json').read_bytes())
    original_archives = {row['name']: row['archive'] for row in closure['artifacts']}
    scopes = {'raw_host_evidence': [], 'build_receipts': [], 'msvc_receipts': [],
              'diagnostic_receipts': [], 'complete_qualification': [], 'independent_review': []}
    for directory in sorted(ARTIFACTS.iterdir()):
        if not directory.is_dir():
            continue
        expected = original_archives[directory.name]
        actual = identity(directory.with_suffix('.zip'))
        assert (actual['sha256'], actual['bytes']) == (expected['sha256'], expected['bytes'])
        if directory.name.startswith('sol281-host-'):
            scope = 'raw_host_evidence'
        elif directory.name.startswith('sol281-build-'):
            scope = 'build_receipts'
        elif directory.name.startswith('sol281-msvc-'):
            scope = 'msvc_receipts'
        elif directory.name.startswith('sol364b-diagnostic-'):
            scope = 'diagnostic_receipts'
        elif directory.name.startswith('sol281-qualified-'):
            scope = 'complete_qualification'
        else:
            raise ValueError('Unregistered directory: ' + directory.name)
        with zipfile.ZipFile(directory.with_suffix('.zip')) as bundle:
            for member in sorted(bundle.infolist(), key=lambda row: row.filename):
                path = directory / member.filename
                if member.is_dir() or 'host-state' in Path(member.filename).parts:
                    continue
                if scope == 'build_receipts' and (path.name == 'source.tar.gz' or path.suffix in ('.so', '.dll')):
                    continue
                value = identity(path)
                h = hashlib.sha256()
                with bundle.open(member) as stream:
                    while data := stream.read(1024 * 1024):
                        h.update(data)
                assert value['sha256'] == h.hexdigest() and value['bytes'] == member.file_size
                value['zip_original_bytes_verified'] = True
                scopes[scope].append(value)
    for path in sorted(ROOT.glob('*')):
        if path.is_file() and path.name not in ('handover_manifest_v2.json',):
            scopes['independent_review'].append(identity(path))
    for path in sorted((ROOT / 'observations').glob('*.json')):
        scopes['independent_review'].append(identity(path))
    manifest = {'schema': 'cybersand.sol364b.independent-handover-paths.v2',
        'source': '9597abd76c01e4a940ff3ea26ff01fca43bf55a6',
        'tree': '11e986214f056f3f39631bb0331b3cd4930c3d1c', 'run_id': 41848472642,
        'scopes': scopes,
        'inventory_correction': 'First convenience manifest was built from extracted-directory globbing and included one unrelated temporary file absent from the authenticated ZIP. It is retained unchanged. This version enumerates only original ZIP members and verifies every included original against both extracted bytes and the authenticated ZIP. The independent closure and full physical/CPU reduction did not include that temporary file and are unchanged.',
        'summary': {name: {'files': len(rows), 'bytes': sum(row['bytes'] for row in rows)}
                    for name, rows in scopes.items()},
        'excluded_payloads': 'ZIP transport copies, ephemeral host-state directories, source.tar.gz and compiled native runtime objects. Their immutable archive/runtime identities remain in independent_hosted_closure.json and independent_hosted_review_final.json, and original bytes remain in scratch artifacts. No claimed original is altered.',
        'instruction': 'Persist original file bytes, source labels and failures. Parent may reuse independently byte-verified identical diagnostic inputs already durably retained. This manifest does not authorize integration or a runtime/provenance refresh.'}
    target = ROOT / 'handover_manifest_v2.json'
    with target.open('x') as stream:
        json.dump(manifest, stream, indent=2, sort_keys=True)
        stream.write('\n')
    print(json.dumps({'manifest': identity(target), 'summary': manifest['summary']}, indent=2))


if __name__ == '__main__':
    main()
