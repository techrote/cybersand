#!/usr/bin/env python3
"""Authenticate one original landscape and the previously admitted Windows assets."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import zipfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--assets', type=Path)
    args = parser.parse_args()
    root, output = args.candidate.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    sys.path[:0] = [str(root / 'tools'), str(root / 'tools/ci')]
    import qualify_workbench_landscapes as custody
    import package_workbench_landscape_review as package
    manifest, maps = custody.load_maps(custody.MANIFEST)
    manifest['maps'] = [item for item in maps if item['name'] == 'graftloom-slipway']
    custody.require(len(manifest['maps']) == 1, 'Pinned Graftloom unavailable')
    custody.write_json(output / 'graftloom-manifest.json', manifest)
    custody.materialize_maps(output / 'graftloom-manifest.json', output / 'fixtures')
    if args.assets:
        matches = list(args.assets.resolve().rglob('CyberSand-Gentek80-Windows-bf1bd8c8e6f1.zip'))
        custody.require(len(matches) == 1, 'Expected exactly one original admitted ZIP')
        archive = matches[0]
        custody.require(custody.sha(archive) == '1ecfef2bca82e73200cc686ce225f8e60a5bccd49a9853cc12f66863d11e06f1',
                        'Original admitted ZIP hash mismatch')
        destination = output / 'dependencies'
        destination.mkdir(exist_ok=False)
        names = set(package.DEPENDENCIES) | {'vcruntime140.dll', 'vc-runtime-provenance.json'}
        with zipfile.ZipFile(archive) as bundle:
            custody.require(len(bundle.namelist()) == len(set(bundle.namelist())), 'Duplicate original ZIP member')
            for name in sorted(names):
                data = bundle.read(name)
                if name in package.DEPENDENCIES:
                    custody.require(hashlib.sha256(data).hexdigest() == package.DEPENDENCIES[name], 'Dependency changed: ' + name)
                (destination / name).write_bytes(data)
        package.verify_vc_runtime(destination)
        custody.write_json(output / 'asset-receipt.json', {'source_zip':str(archive), 'sha256':custody.sha(archive),
                          'files_sha256':{name:custody.sha(destination / name) for name in sorted(names)}})
        with Path(os.environ['GITHUB_ENV']).open('a', encoding='utf-8') as stream:
            stream.write('GODOT_EXE=' + str(destination / 'Godot_v4.7-stable_win64_console.exe') + '\n')
            stream.write('ASSETS_ZIP=' + str(archive) + '\n')


if __name__ == '__main__':
    main()
