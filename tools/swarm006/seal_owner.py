#!/usr/bin/env python3
"""Seal a fresh source-bound SWARM006 archive, sidecar and owner launcher."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[2]
REQUIRED = {
    'Open Workbench.cmd', 'Godot_v4.7-stable_win64.exe', 'Godot_v4.7-stable_win64_console.exe',
    'godot/project.godot', 'godot/tools/gentek_reciprocal.exe', 'godot/tools/swarm004-runtime.json',
    'godot/tools/swarm004-runtime.windows.json',
    'godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll',
    'godot/addons/cybersand_native/cybersand_native.gdextension', 'godot/main.tscn',
    'godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll',
    'godot/addons/godot-rapier2d/godot-rapier2d.gdextension', 'vcruntime140.dll',
    'godot/scripts/workbench_reciprocal_protocol.gd', 'godot/scripts/workbench_reciprocal_panel.gd',
    'READ-ME.md',
}

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def validate_package(directory: Path, source: str) -> dict:
    directory = directory.resolve()
    manifest = json.loads((directory/'candidate-manifest.json').read_text(encoding='utf-8'))
    if not re.fullmatch('[0-9a-f]{40}', source) or manifest.get('source_commit') != source or manifest.get('programme') != 'GENTEK-SWARM-006' or manifest.get('draft_hold') is not True:
        raise ValueError('Owner package is not the exact experimental source')
    entries = manifest.get('files_sha256')
    if not isinstance(entries, dict) or not REQUIRED <= entries.keys() or len(entries) > 10000:
        raise ValueError('Incomplete or unbounded launch contents')
    seen = set()
    total = 0
    for name, expected in entries.items():
        if not isinstance(name,str) or name.startswith('/') or '\\' in name or ':' in name or any(x in ('','..','.') for x in name.split('/')):
            raise ValueError('Unsafe package manifest path')
        path = directory/name
        if name.casefold() in seen or path.is_symlink() or not path.resolve().is_relative_to(directory) or not isinstance(expected,str) or not re.fullmatch('[0-9a-f]{64}',expected) or not path.is_file() or sha(path) != expected:
            raise ValueError('Changed/unsafe package file: '+name)
        seen.add(name.casefold())
        total += path.stat().st_size
        if path.stat().st_size > 1073741824 or total > 2147483648:
            raise ValueError('Package exceeds the bounded owner-package capacity')
    actual = {p.relative_to(directory).as_posix() for p in directory.rglob('*') if p.is_file() and p != directory/'candidate-manifest.json'}
    if actual != entries.keys():
        raise ValueError('Package has unlisted or missing files')
    runtime = json.loads((directory/'godot/tools/swarm004-runtime.json').read_text(encoding='utf-8'))
    preferred = json.loads((directory/'godot/tools/swarm004-runtime.windows.json').read_text(encoding='utf-8'))
    expected_programme = manifest.get('runtime_programme', 'GENTEK-SWARM-006')
    if (expected_programme not in ('GENTEK-SWARM-006', 'GENTEK-SWARM-004-005-MAINLINE')
            or preferred != runtime or runtime.get('platform') != 'windows'
            or runtime.get('artifact') != 'godot/tools/gentek_reciprocal.exe'
            or any((directory/name).exists() for name in ('godot/tools/gentek_reciprocal', 'godot/tools/swarm004-runtime.linux.json'))
            or runtime.get('schema') != 1 or runtime.get('draft_hold') is not True or runtime.get('source') != source or runtime.get('programme') != expected_programme or runtime.get('sha256') != manifest.get('reciprocal_cli_sha256') or runtime.get('sha256') != entries['godot/tools/gentek_reciprocal.exe'] or manifest.get('native_sha256') != entries['godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll']):
        raise ValueError('Runtime source/binary identity mismatch')
    if manifest.get('qualification_programme') == 'GENTEK-SWARM-004-005-006-UNIFIED' and (
            not re.fullmatch('[0-9a-f]{64}', str(manifest.get('native_definition_sha256', '')))
            or runtime.get('native_definition_sha256') != manifest['native_definition_sha256']
            or runtime.get('qualification_programme') != manifest['qualification_programme']):
        raise ValueError('Unified package native definition/qualification mismatch')
    return manifest

def seal(directory: Path, output: Path, source: str) -> dict:
    manifest = validate_package(directory, source)
    output.mkdir(parents=True,exist_ok=True)
    label = 'SWARM456' if manifest.get('qualification_programme') == 'GENTEK-SWARM-004-005-006-UNIFIED' else 'SWARM006'
    name = f'CyberSand-{label}-Draft-HOLD-Windows-{source[:12]}.zip'
    archive=output/name
    launcher=output/f'CyberSand-{label}-Windows-Owner-Acceptance.ps1'
    if any(p.exists() for p in (archive,Path(str(archive)+'.sha256'),launcher)):
        raise ValueError('Refusing to overwrite a prior sealed evaluator')
    with zipfile.ZipFile(archive,'x',zipfile.ZIP_DEFLATED,compresslevel=6) as package:
        for path in sorted(directory.rglob('*')):
            if path.is_file(): package.write(path,path.relative_to(directory).as_posix())
    digest=sha(archive)
    Path(str(archive)+'.sha256').write_text(f'{digest}  {name}\n',encoding='ascii')
    template=(ROOT/'tools/swarm006/owner_launcher.ps1.in').read_text(encoding='utf-8')
    template=template.replace('SWARM006', label)
    values={'__SOURCE_COMMIT__':source,'__ZIP_NAME__':name,'__ZIP_SHA256__':digest,'__MANIFEST_SHA256__':sha(directory/'candidate-manifest.json')}
    for key,value in values.items():
        if template.count(key) != 1: raise ValueError('Launcher binding placeholder mismatch: '+key)
        template=template.replace(key,value)
    launcher.write_text(template,encoding='utf-8-sig',newline='\r\n')
    result={'source_commit':source,'archive':name,'archive_sha256':digest,'launcher_sha256':sha(launcher),'manifest_sha256':values['__MANIFEST_SHA256__']}
    (output/(label.lower()+'-owner-seal.json')).write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    return result

def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--source',required=True)
    args=parser.parse_args();print(json.dumps(seal(args.package,args.output,args.source)))

if __name__=='__main__':main()
