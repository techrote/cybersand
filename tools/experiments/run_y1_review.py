"""Launch the experimental comparison only after source/runtime authentication."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot',type=Path,default=Path('C:/Godot47/Godot_v4.7-stable_win64_console.exe'))
    parser.add_argument('--project',type=Path,default=Path('godot'))
    parser.add_argument('--identity-only',action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    project = args.project.resolve()
    platform = 'windows' if os.name=='nt' else 'linux'
    manifest_path = root/'godot/addons/cybersand_native'/('runtime-provenance.json' if platform=='windows' else 'runtime-provenance.linux.json')
    manifest = json.loads(manifest_path.read_text())
    sha = lambda path:hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    for relative,expected in manifest['source_inputs'].items():
        if sha(root/relative) != expected:
            raise RuntimeError('Rebuild required for '+relative)
    runtime = project/Path(manifest['artifact']).relative_to('godot')
    if hashlib.sha256(runtime.read_bytes()).hexdigest()!=manifest['sha256']:
        raise RuntimeError('Review runtime differs from source-bound publication')
    for path in (root/'godot').rglob('*'):
        if path.is_file() and '.godot' not in path.parts and path.suffix in {'.gd','.tscn','.gdshader','.tres'}:
            if sha(path)!=sha(project/path.relative_to(root/'godot')):
                raise RuntimeError('Review project source differs: '+str(path))
    version = subprocess.check_output([str(args.godot.resolve()),'--version'],text=True,timeout=30).strip()
    if version!='4.7.stable.official.5b4e0cb0f':
        raise RuntimeError('Expected the pinned official Godot 4.7 runtime')
    source = subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip()
    env = os.environ.copy()
    env['CYBERSAND_SOURCE_REVISION'] = source
    protocol = root/'docs/audits/y1-envelope-2026-11-01/protocol.json'
    print(json.dumps({'source':source,'runtime_source':manifest['source_commit'],'native_sha256':manifest['sha256'],
                      'engine_sha256':hashlib.sha256(args.godot.read_bytes()).hexdigest(),'godot':version,
                      'protocol_sha256':hashlib.sha256(protocol.read_bytes()).hexdigest(),
                      'status':'AWAITING OWNER GAMEPLAY ACCEPTANCE'},indent=2),flush=True)
    if not args.identity_only:
        return subprocess.call([str(args.godot.resolve()),'--path',str(project),'--resolution','1200x760',
                                'res://y1_envelope_review.tscn','--',f'--protocol={protocol}'],env=env)
    return 0


if __name__=='__main__':
    sys.exit(main())
