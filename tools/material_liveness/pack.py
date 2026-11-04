#!/usr/bin/env python3
"""Losslessly retain bounded raw evidence as portable JSON shards.

This is a transport codec, not a qualification filter. Failed/truncated output
is retained byte-for-byte with its ORIGINAL campaign receipt. After unpacking,
reduce.py must authenticate the original receipt; a failed attempt stays failed.
No executable, object, archive, credential, or unrelated file is included.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import zlib

SCHEMA = 'mat354.raw-transport.v1'
MAX_FILE = 16 * 1024 * 1024
MAX_TOTAL = 256 * 1024 * 1024
MAX_SHARD = 512 * 1024
ALLOWED_SUFFIXES = {'.json', '.stdout', '.stderr', '.d'}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def safe_name(name):
    if not isinstance(name, str) or not re.fullmatch(r'[A-Za-z0-9_.-]{1,160}', name) or name in {'.', '..'}:
        raise ValueError('unsafe evidence member name')
    return name


def write_new(path, value):
    data = (json.dumps(value, sort_keys=True, separators=(',', ':')) + '\n').encode()
    with path.open('xb') as handle:
        handle.write(data)
    return {'name': path.name, 'bytes': len(data), 'sha256': sha(data)}


def pack(source, destination, prefix):
    source, destination = source.resolve(), destination.resolve()
    safe_name(prefix)
    if source == destination or source in destination.parents:
        raise ValueError('transport destination must be outside raw source directory')
    paths = sorted(p for p in source.iterdir() if p.is_file() and p.suffix in ALLOWED_SUFFIXES)
    if not paths or len(paths) > 10000:
        raise ValueError('empty or excessive evidence inventory')
    if sum(p.stat().st_size for p in paths) > MAX_TOTAL:
        raise ValueError('evidence exceeds bounded uncompressed size')
    destination.mkdir(parents=True, exist_ok=True)
    if any(destination.glob(prefix + '.*.json')):
        raise ValueError('transport prefix exists; preserve prior package')
    shards, members, current, current_size = [], [], [], 0
    for path in paths:
        safe_name(path.name)
        data = path.read_bytes()
        if len(data) > MAX_FILE:
            raise ValueError('individual evidence file exceeds bound')
        info = {'name': path.name, 'bytes': len(data), 'sha256': sha(data)}
        entry = dict(info, zlib_base64=base64.b64encode(zlib.compress(data, 9)).decode('ascii'))
        size = len(json.dumps(entry))
        if current and current_size + size > MAX_SHARD:
            shards.append(write_new(destination / f'{prefix}.{len(shards):03}.json', {'schema': SCHEMA, 'files': current}))
            current, current_size = [], 0
        current.append(entry)
        current_size += size
        members.append(info)
    if current:
        shards.append(write_new(destination / f'{prefix}.{len(shards):03}.json', {'schema': SCHEMA, 'files': current}))
    manifest = {'schema': SCHEMA, 'codec': 'zlib+base64', 'qualification': 'transport-only; authenticate original receipt after unpacking',
                'uncompressed_bytes': sum(x['bytes'] for x in members), 'files': members, 'shards': shards}
    write_new(destination / f'{prefix}.manifest.json', manifest)
    return manifest


def decode_entry(entry):
    safe_name(entry['name'])
    size = entry['bytes']
    if type(size) is not int or not 0 <= size <= MAX_FILE:
        raise ValueError('invalid member length')
    encoded = base64.b64decode(entry['zlib_base64'], validate=True)
    stream = zlib.decompressobj()
    data = stream.decompress(encoded, size + 1)
    if len(data) != size or not stream.eof or stream.unused_data or stream.unconsumed_tail or sha(data) != entry['sha256']:
        raise ValueError('evidence member digest, length or compression mismatch')
    return data


def unpack(manifest_path, destination):
    manifest_path, destination = manifest_path.resolve(), destination.resolve()
    manifest = json.loads(manifest_path.read_text())
    if manifest.get('schema') != SCHEMA or manifest.get('codec') != 'zlib+base64':
        raise ValueError('unknown transport schema')
    if destination.exists() and any(destination.iterdir()):
        raise ValueError('unpack destination is not empty')
    expected, total = {}, 0
    for info in manifest['files']:
        name = safe_name(info['name'])
        if name in expected or type(info['bytes']) is not int or not 0 <= info['bytes'] <= MAX_FILE:
            raise ValueError('duplicate or invalid member inventory')
        expected[name] = info
        total += info['bytes']
    if total != manifest['uncompressed_bytes'] or total > MAX_TOTAL:
        raise ValueError('total evidence bound mismatch')
    # Authenticate every compressed shard and member before publishing any raw
    # file. Memory is bounded by MAX_TOTAL; incomplete input cannot look complete.
    decoded = {}
    for info in manifest['shards']:
        path = manifest_path.parent / safe_name(info['name'])
        data = path.read_bytes()
        if len(data) != info['bytes'] or sha(data) != info['sha256']:
            raise ValueError('shard identity mismatch')
        shard = json.loads(data)
        if shard.get('schema') != SCHEMA:
            raise ValueError('shard schema mismatch')
        for entry in shard['files']:
            name = safe_name(entry['name'])
            observed = {key: entry[key] for key in ('name', 'bytes', 'sha256')}
            if name in decoded or expected.get(name) != observed:
                raise ValueError('shard member differs from manifest')
            decoded[name] = decode_entry(entry)
    if set(decoded) != set(expected):
        raise ValueError('missing evidence member')
    destination.mkdir(parents=True, exist_ok=True)
    for name, data in decoded.items():
        with (destination / name).open('xb') as handle:
            handle.write(data)
    return {'files': len(decoded), 'bytes': total}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    create = commands.add_parser('pack')
    create.add_argument('source', type=Path)
    create.add_argument('destination', type=Path)
    create.add_argument('--prefix', required=True)
    restore = commands.add_parser('unpack')
    restore.add_argument('manifest', type=Path)
    restore.add_argument('destination', type=Path)
    args = parser.parse_args()
    result = pack(args.source, args.destination, args.prefix) if args.command == 'pack' else unpack(args.manifest, args.destination)
    print(json.dumps({key: value for key, value in result.items() if key not in {'files', 'shards'}}))


if __name__ == '__main__':
    main()
