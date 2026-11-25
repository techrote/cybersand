#!/usr/bin/env python3
"""Independent raw Windows runtime byte audit; never executes the payload."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess

SOURCE = '934cc0c0eef70dad528155e9a92eebe25e2757eb'
TREE = '0c30ea3eaea61c5091c23b984837f29d7b7c828e'
PREDECESSOR = '80623d039aa49bc0c1d84a9206d89812ffa99ea6'
ENGINES = {
    'Godot_v4.7-stable_win64.exe': 'b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8',
    'Godot_v4.7-stable_win64_console.exe': 'd8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c',
}
MANIFESTS = (
    ('godot/addons/cybersand_native/runtime-provenance.json', '668f2dd094fca611a97c2b6aa38c4cd072179fe9cf591e53578ef57c7db1625e', 5820416),
    ('godot/addons/godot-rapier2d/runtime-provenance.windows.json', 'b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7', 9987072),
)

def sha(path):
    value = hashlib.sha256()
    with path.open('rb') as source:
        for data in iter(lambda: source.read(1024 * 1024), b''):
            value.update(data)
    return value.hexdigest()

def need(value, message):
    if not value:
        raise ValueError(message)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--payload', type=Path, required=True)
    parser.add_argument('--repository', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    need(not args.output.exists(), 'Preserve original audit receipts')
    git = lambda *flags: subprocess.check_output(['git', *flags], cwd=args.repository)
    need(git('rev-parse', SOURCE + '^{tree}').decode().strip() == TREE, 'Wrong frozen application tree')
    path = args.payload / 'evaluation-manifest.json'
    manifest = json.loads(path.read_text())
    need(manifest['source_commit'] == SOURCE and manifest['source_tree'] == TREE, 'Wrong actual payload source')
    files = manifest['files_sha256']
    rows = []
    for name, expected in ENGINES.items():
        current = args.payload / name
        need(current.is_file() and not current.is_symlink(), 'Missing or symbolic engine payload')
        actual = sha(current)
        need(actual == expected == files[name], 'Actual official Windows engine bytes differ')
        rows.append({'path': name, 'bytes': current.stat().st_size, 'sha256': actual, 'kind': 'official-Godot-4.7-Windows-engine'})
    native = []
    for name, expected, size in MANIFESTS:
        raw = git('show', SOURCE + ':' + name)
        need(raw == git('show', PREDECESSOR + ':' + name), 'Predecessor retained runtime manifest changed')
        need(raw == (args.payload / name).read_bytes(), 'Shipped native runtime manifest differs from frozen source')
        provenance = json.loads(raw)
        artifact = provenance['artifact']
        need(artifact.startswith('godot/addons/') and '..' not in Path(artifact).parts, 'Unexpected runtime artifact path')
        pointer = git('show', SOURCE + ':' + artifact)
        need(pointer == git('show', PREDECESSOR + ':' + artifact), 'Retained runtime LFS pointer changed')
        match = re.fullmatch(rb'version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n', pointer)
        need(match and match[1].decode() == expected and int(match[2]) == size, 'Frozen LFS pointer differs from independent runtime pin')
        current = args.payload / artifact
        need(current.is_file() and not current.is_symlink(), 'Actual native payload is absent or symbolic')
        actual = sha(current)
        need(actual == expected == provenance['sha256'] == files[artifact], 'Actual native DLL bytes differ from manifest, LFS and independent pin')
        need(current.stat().st_size == size == provenance['size'], 'Actual native DLL size differs')
        item = {'path': artifact, 'bytes': size, 'sha256': actual, 'kind': 'retained-native-Windows-DLL',
                'manifest_path': name, 'manifest_sha256': hashlib.sha256(raw).hexdigest(),
                'build_commit': provenance['build_commit'], 'source_inputs': provenance['source_inputs']}
        rows.append(item)
        native.append(name)
    receipt = {'schema': 'strata2-independent-actual-Windows-runtime-bytes-v1', 'status': 'passed',
               'source_commit': SOURCE, 'source_tree': TREE, 'predecessor_archive': PREDECESSOR,
               'payload_manifest_sha256': sha(path), 'runtime_files': rows, 'native_manifests': native,
               'auditor_sha256': sha(Path(__file__)),
               'scope': 'Independent actual extracted Windows engine/DLL byte hashing against frozen source, predecessor LFS pointers, manifests and separately pinned expected digests. No runtime execution, complete package audit or physical owner acceptance claim.'}
    args.output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    print(json.dumps({'status': receipt['status'], 'source_commit': SOURCE, 'files': len(rows), 'output': str(args.output)}))

if __name__ == '__main__':
    main()
