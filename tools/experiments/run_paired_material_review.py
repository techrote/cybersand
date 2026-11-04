"""Authenticate and launch the native paired-wall / finite-curing review room."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
CODE = {'.gd', '.tscn', '.tres', '.gdshader', '.gdextension', '.json'}
NATIVE = {'.cpp', '.hpp', '.h', '.inc', '.inl', '.c'}

def digest(path, normalized=False):
    value = path.read_bytes()
    return hashlib.sha256(value.replace(b'\r\n', b'\n') if normalized else value).hexdigest()

def authenticate(args):
    def git(*values):
        return subprocess.check_output(['git', '-C', str(ROOT), *values], timeout=30)
    if git('diff', '--binary', 'HEAD'):
        raise RuntimeError('Commit the review source before launching a source-labelled room')
    tracked = set(git('ls-tree', '-r', '--name-only', 'HEAD', '--', 'godot').decode().splitlines())
    inputs = {}
    for p in sorted((ROOT/'godot').rglob('*')):
        if not p.is_file() or '.godot' in p.parts or not (p.suffix in CODE or p.name == 'project.godot'):
            continue
        relative = p.relative_to(ROOT).as_posix()
        if relative not in tracked:
            raise RuntimeError('Uncommitted executable/configuration input: '+relative)
        inputs[relative] = digest(p, True)
        if digest(args.project/p.relative_to(ROOT/'godot'), True) != inputs[relative]:
            raise RuntimeError('Review project differs: '+relative)
    platform = 'windows' if os.name == 'nt' else 'linux'
    name = 'runtime-provenance.json' if platform == 'windows' else 'runtime-provenance.linux.json'
    native = json.loads((ROOT/'godot/addons/cybersand_native'/name).read_text(encoding='utf-8'))
    expected = {p.relative_to(ROOT).as_posix():digest(p,True)
                for folder in ['native/src','native/include','godot/native_extension']
                for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix in NATIVE}
    if native['source_inputs'] != expected:
        raise RuntimeError('Native runtime inputs require rebuilding or an incomplete input manifest was supplied')
    runtimes = {}
    for label, manifest in [('native', native), ('rapier', json.loads((ROOT/f'godot/addons/godot-rapier2d/runtime-provenance.{platform}.json').read_text(encoding='utf-8')))]:
        for p in [ROOT/manifest['artifact'], args.project/Path(manifest['artifact']).relative_to('godot')]:
            if digest(p) != manifest['sha256']:
                raise RuntimeError('Runtime bytes differ: '+str(p))
        runtimes[label] = manifest['sha256']
    version = subprocess.check_output([str(args.godot), '--version'], text=True, timeout=30).strip()
    if version != '4.7.stable.official.5b4e0cb0f':
        raise RuntimeError('Pinned Godot4.7 required')
    return {'source':git('rev-parse','HEAD').decode().strip(),
            'tree':git('rev-parse','HEAD^{tree}').decode().strip(),
            'scene':'res://paired_material_playground.tscn', 'godot':version,
            'godot_executable':str(args.godot.resolve()), 'godot_executable_sha256':digest(args.godot),
            'native_build_source':native['source_commit'], 'runtimes':runtimes,
            'inputs':inputs, 'input_identity':hashlib.sha256(json.dumps(inputs,sort_keys=True).encode()).hexdigest(),
            'scope':'Native paired forms and finite-curing developer review; current-main actor coupling, no GCR-LA/rest/default or owner-acceptance claim'}

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', type=Path, default=Path('C:/Godot47/Godot_v4.7-stable_win64_console.exe'))
    p.add_argument('--project', type=Path, default=ROOT/'godot')
    p.add_argument('--identity-only', action='store_true')
    args = p.parse_args(); args.project = args.project.resolve()
    identity = authenticate(args)
    print(json.dumps(identity,indent=2),flush=True)
    if args.identity_only: return 0
    env = dict(os.environ, CYBERSAND_SOURCE_REVISION=identity['source'], CYBERSAND_INPUT_IDENTITY=identity['input_identity'])
    return subprocess.call([str(args.godot),'--path',str(args.project),'--maximized',identity['scene']],env=env)

if __name__ == '__main__':
    raise SystemExit(main())
