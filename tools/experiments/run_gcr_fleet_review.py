"""Authenticate and launch the explicit flyer budget/painting playground."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
CODE = {'.gd', '.tscn', '.gdshader', '.tres', '.gdextension'}

def digest(path, normalized=False):
    data = Path(path).read_bytes()
    return hashlib.sha256(data.replace(b'\r\n', b'\n') if normalized else data).hexdigest()

def authenticate(args):
    def git(*values):
        return subprocess.check_output(['git', '-C', str(ROOT), *values], timeout=30)
    if git('diff', '--binary', 'HEAD'):
        raise RuntimeError('Commit the review source before launching a source-labelled fleet')
    tracked = set(git('ls-tree', '-r', '--name-only', 'HEAD', '--', 'godot').decode().splitlines())
    inputs = {}
    for path in sorted((ROOT/'godot').rglob('*')):
        if not path.is_file() or '.godot' in path.parts or not (path.suffix in CODE or path.name == 'project.godot'):
            continue
        relative = path.relative_to(ROOT).as_posix()
        if relative not in tracked:
            raise RuntimeError('Uncommitted executable project input '+relative)
        inputs[relative] = digest(path, True)
        if digest(args.project/path.relative_to(ROOT/'godot'), True) != inputs[relative]:
            raise RuntimeError('Isolated project differs: '+relative)
    platform = 'windows' if os.name == 'nt' else 'linux'
    native_path = ROOT/('godot/addons/cybersand_native/runtime-provenance.json' if platform == 'windows' else 'godot/addons/cybersand_native/runtime-provenance.linux.json')
    native = json.loads(native_path.read_text(encoding='utf-8'))
    for relative, expected in native['source_inputs'].items():
        if digest(ROOT/relative, True) != expected:
            raise RuntimeError('Native rebuild required: '+relative)
    runtimes = {}
    for name, manifest in [('native',native),('rapier',json.loads((ROOT/f'godot/addons/godot-rapier2d/runtime-provenance.{platform}.json').read_text(encoding='utf-8')))]:
        for path in [ROOT/manifest['artifact'],args.project/Path(manifest['artifact']).relative_to('godot')]:
            if digest(path) != manifest['sha256']:
                raise RuntimeError('Runtime differs: '+str(path))
        runtimes[name] = manifest['sha256']
    version = subprocess.check_output([str(args.godot),'--version'],text=True,timeout=30).strip()
    if version != '4.7.stable.official.5b4e0cb0f':
        raise RuntimeError('Pinned Godot4.7 required')
    return {'source':git('rev-parse','HEAD').decode().strip(),'tree':git('rev-parse','HEAD^{tree}').decode().strip(),
            'scope':'Developer flyer LA budgets/scaling and retained RFT reference; no rest modes, physical campaign or owner acceptance',
            'scene':'res://gcr_fleet_playground.tscn','runtimes':runtimes,'native_build_source':native['source_commit'],
            'godot':version,'launch_entrypoint_sha256':digest(args.godot),'project_inputs':inputs,
            'input_identity':hashlib.sha256(json.dumps(inputs,sort_keys=True).encode()).hexdigest()}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,default=Path('C:/Godot47/Godot_v4.7-stable_win64_console.exe'))
    parser.add_argument('--project',type=Path,default=ROOT/'godot')
    parser.add_argument('--identity-only',action='store_true')
    args = parser.parse_args()
    args.project = args.project.resolve()
    identity = authenticate(args)
    print(json.dumps(identity,indent=2),flush=True)
    if args.identity_only:
        return 0
    env = os.environ.copy()
    env['CYBERSAND_SOURCE_REVISION'] = identity['source']
    env['CYBERSAND_INPUT_IDENTITY'] = identity['input_identity']
    return subprocess.call([str(args.godot),'--path',str(args.project),'--resolution','1600x1100',identity['scene']],env=env)

if __name__ == '__main__':
    raise SystemExit(main())
