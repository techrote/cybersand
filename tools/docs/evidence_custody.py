#!/usr/bin/env python3
"""Describe and verify immutable evidence retained outside a compact checkout.

No network, deletion, Git rewrite, or automatic restoration occurs. Reconstruction
reads an already available immutable Git object and verifies both Git and SHA-256
identities before exclusively creating one requested output file.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

PREDECESSOR = '20170bd6259498c3d2774ab274567febb043fc1d'
BASELINE = '00cdb02f103265b6dc5224c68283e9a0c8cb449f'
PACKET = 'docs/audits/2026-11-24-docs-renaissance'
MANIFEST = 'docs/audits/2026-11-25-docs-renaissance-ultima/retrieval/predecessor-custody.json'
KEEP = {PACKET + '/assets-b.json', PACKET + '/closure/preservation-manifest.json'}


def git(root: Path, *args: str) -> bytes:
    return subprocess.check_output(['git', '--no-lazy-fetch', '-C', str(root), *args],
                                   env=os.environ | {'GIT_NO_LAZY_FETCH': '1'})


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def tree(root: Path, revision: str, prefix: str) -> list[dict]:
    result = []
    for record in git(root, 'ls-tree', '-r', '-l', '-z', revision, prefix).split(b'\0'):
        if not record:
            continue
        metadata, path = record.split(b'\t', 1)
        mode, kind, blob, size = metadata.decode().split()
        if kind == 'blob':
            if not size.isdecimal():
                raise ValueError('Immutable evidence blob unavailable locally; fetch explicitly before verifying: '+blob)
            result.append({'path': path.decode(), 'git_blob': blob, 'bytes': int(size)})
    return result


def read_blobs(root: Path, rows: list[dict]) -> dict[str, bytes]:
    # One bounded process; --batch retains exact bytes, including original whitespace.
    ids = sorted({row['git_blob'] for row in rows})
    if not ids:
        return {}
    output = subprocess.check_output(
        ['git', '--no-lazy-fetch', '-C', str(root), 'cat-file', '--batch'], input=('\n'.join(ids)+'\n').encode(),
        env=os.environ | {'GIT_NO_LAZY_FETCH': '1'})
    cursor = 0
    data = {}
    for expected in ids:
        end = output.index(b'\n', cursor)
        header = output[cursor:end].decode().split()
        if header == [expected, 'missing']:
            raise ValueError('Immutable evidence blob unavailable locally; fetch explicitly before verifying: '+expected)
        if len(header) != 3:
            raise ValueError('Unexpected Git batch header for '+expected)
        oid, kind, length = header
        if oid != expected or kind != 'blob' or not length.isdecimal():
            raise ValueError('Unavailable or unexpected Git blob: '+expected)
        start = end + 1
        data[oid] = output[start:start+int(length)]
        cursor = start+int(length)+1
    return data


def classification(path: str) -> str:
    if '/preserved/' in path:
        return 'byte-preserved-original'
    if '.contexts.' in path:
        return 'derived-retrieved-context'
    if path.endswith(('.png', '.jpg', '.pdf')):
        return 'visual-evidence'
    if '/retrieval/' in path and path.endswith('.json'):
        return 'retrieval-input-or-result'
    if '/recovery/' in path:
        return 'recovery-custody'
    return 'audit-source-or-receipt'


def create(root: Path) -> dict:
    rows = tree(root, PREDECESSOR, PACKET)
    blobs = read_blobs(root, rows)
    for row in rows:
        retained = '/preserved/' in row['path'] or row['path'] in KEEP
        row.update(sha256=sha(blobs[row['git_blob']]), classification=classification(row['path']),
                   disposition='retained-byte-exact' if retained else 'immutable-predecessor-only',
                   reason=('Keep original document custody and directly used image/preservation identity.' if retained else
                           'Retained in full predecessor lineage; omit duplicate/raw audit payload from ordinary checkout.'),
                   immutable_url='https://github.com/techrote/cybersand/blob/'+PREDECESSOR+'/'+row['path'])
    retained = [r for r in rows if r['disposition'] == 'retained-byte-exact']
    return {'schema': 1, 'authority': 'historical-non-authoritative', 'predecessor': PREDECESSOR,
            'predecessor_tree': git(root, 'rev-parse', PREDECESSOR+'^{tree}').decode().strip(),
            'accepted_baseline': BASELINE, 'packet': PACKET,
            'custody': 'Full predecessor branch and immutable Git commit preserved. No history rewrite or external artifact expiry dependency.',
            'accessibility': 'Git objects verified locally by this tool; remote content readback is a separate dated receipt.',
            'reconstruction': 'Fetch the preserved predecessor branch if absent, then use this tool --extract PATH --output NEW_FILE. No automatic fetch or checkout.',
            'summary': {'files': len(rows), 'bytes': sum(r['bytes'] for r in rows),
                        'retained_files': len(retained), 'retained_bytes': sum(r['bytes'] for r in retained),
                        'omitted_files': len(rows)-len(retained),
                        'omitted_bytes': sum(r['bytes'] for r in rows)-sum(r['bytes'] for r in retained),
                        'preserved_originals': sum(r['classification']=='byte-preserved-original' for r in rows)},
            'items': rows}


def verify(root: Path, manifest: dict, compact: bool = False) -> dict:
    if manifest.get('predecessor') != PREDECESSOR or manifest.get('accepted_baseline') != BASELINE:
        raise ValueError('Unrecognized custody source; do not trust mutable source identity')
    expected = create(root)
    if manifest != expected:
        raise ValueError('Custody manifest differs from independently reconstructed immutable source')
    for row in manifest['items']:
        path = root/row['path']
        if row['disposition'] == 'retained-byte-exact':
            if not path.is_file() or path.is_symlink() or sha(path.read_bytes()) != row['sha256']:
                raise ValueError('Retained evidence changed or missing: '+row['path'])
        elif compact and path.exists():
            raise ValueError('Omitted predecessor payload remains in compact checkout: '+row['path'])
    # Originals are independently bound to accepted main, not merely to #774 copies.
    preserved = json.loads(git(root, 'show', PREDECESSOR+':'+PACKET+'/closure/preservation-manifest.json'))
    original_rows = [{'git_blob': r['original_git_blob']} for r in preserved['records']]
    original_blobs = read_blobs(root, original_rows)
    for record in preserved['records']:
        original = git(root, 'rev-parse', BASELINE+':'+record['original_path']).decode().strip()
        copy = (root/record['preserved_destination']).read_bytes()
        if original != record['original_git_blob'] or copy != original_blobs[original] or sha(copy) != record['original_content_sha256']:
            raise ValueError('Accepted original custody failure: '+record['original_path'])
    return {'status': 'passed', 'mode': 'compact' if compact else 'retention-only',
            'predecessor': PREDECESSOR, 'verified_source_files': len(manifest['items']),
            'verified_originals': len(preserved['records']), **manifest['summary']}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--manifest', type=Path)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--create', action='store_true')
    action.add_argument('--verify', action='store_true')
    action.add_argument('--extract', metavar='REPOSITORY_PATH')
    parser.add_argument('--compact', action='store_true')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    manifest_path = args.manifest or root/MANIFEST
    if args.create:
        value = create(root)
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        manifest_path.write_text(json.dumps(value, indent=2)+'\n', encoding='utf-8')
        print(json.dumps(value['summary'], indent=2))
        return
    value = json.loads(manifest_path.read_text(encoding='utf-8'))
    receipt = verify(root, value, args.compact)
    if args.extract:
        if not args.output:
            parser.error('--extract requires --output NEW_FILE')
        rows = [r for r in value['items'] if r['path'] == args.extract]
        if len(rows) != 1:
            raise ValueError('Requested path is not in the verified custody manifest')
        row = rows[0]
        data = git(root, 'cat-file', 'blob', row['git_blob'])
        if sha(data) != row['sha256']:
            raise ValueError('Reconstruction digest mismatch')
        with args.output.open('xb') as target:
            target.write(data)
        receipt['reconstructed'] = {'path': row['path'], 'sha256': sha(data), 'bytes': len(data)}
    print(json.dumps(receipt, indent=2))


if __name__ == '__main__':
    main()
