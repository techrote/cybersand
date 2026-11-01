"""Acquire the preregistered Y1 population sequentially with bounded subprocesses.

Build source-matched runtimes first. Run from the source root. Outputs are local;
only the compact reduction and retention index belong in Git.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import subprocess


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(args):
    root = Path.cwd()
    protocol_path = root/'docs/audits/y1-envelope-2026-11-01/protocol.json'
    protocol = json.loads(protocol_path.read_text(encoding='utf-8-sig'))
    output = args.output.resolve()
    output.mkdir(parents=True,exist_ok=False)
    source = subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
    env = os.environ.copy()
    env['CYBERSAND_SOURCE_REVISION'] = source
    records = []
    project = args.project.resolve()
    native = project/'addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll'
    built = json.loads((root/'build/windows-build-receipt.json').read_text())
    assert digest(native)==built['sha256'], 'runtime changed since source-matched build'
    for relative, expected in built['inputs'].items():
        assert digest(root/relative)==expected, relative
    for folder in ['scripts','tests']:
        for path in (root/'godot'/folder).rglob('*.gd'):
            assert digest(path)==digest(project/path.relative_to(root/'godot')),path
    receipt = {'source':source,'tree':subprocess.check_output(['git','show','-s','--format=%T','HEAD'],text=True).strip(),
               'protocol_sha256':digest(protocol_path),'native_sha256':digest(native),
               'engine_sha256':digest(args.godot.resolve()),'checks':records,'order':[]}

    def execute(name, script, extra=(), limit=180):
        command = [str(args.godot.resolve()),'--headless','--path',str(project),'--script',f'res://tests/{script}.gd']
        if extra:
            command += ['--',f'--protocol={protocol_path}',*extra]
        log = output/(name+'.log')
        started = datetime.datetime.now(datetime.timezone.utc).isoformat()
        with log.open('wb') as stream:
            try:
                completed = subprocess.run(command,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=limit)
                code = completed.returncode
            except subprocess.TimeoutExpired:
                code = 124
        errors = 'ERROR:' in log.read_text(errors='replace')
        records.append({'name':name,'command':command,'timeout':limit,'start':started,'exit':code,'error_output':errors,'log_sha256':digest(log)})
        (output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
        print(name,code,'ERROR' if errors else '',flush=True)
        if code or errors:
            raise RuntimeError(log.read_text(errors='replace')[-3500:])

    execute('selector-controls','test_y1_envelope')
    for index,spec in enumerate(protocol['cases']):
        if args.only and spec['id'] != args.only:
            continue
        order = ['B0','Y1'] if index%2==0 else ['Y1','B0']
        for arm in order:
            name = f'{spec["id"]}-{arm}'
            receipt['order'].append(name)
            execute(name,'test_y1_envelope',[f'--case={spec["id"]}',f'--candidate={arm}',f'--output={output/(name+".json")}'])
    if args.only:
        return
    for rep in range(3):
        for case in ['mass-1-30','mass-1-90']:
            for arm in (['Y1','B0'] if rep%2==0 else ['B0','Y1']):
                name = f'timing-{rep}-{case}-{arm}'
                execute(name,'test_y1_envelope',[f'--case={case}',f'--candidate={arm}',f'--output={output/(name+".json")}'])
    for arm in ['B0','Y1']:
        name = 'determinism-anchor-30-'+arm
        execute(name,'test_y1_envelope',['--case=anchor-30',f'--candidate={arm}',f'--output={output/(name+".json")}'])
        for case in ['anchor-30','water']:
            name = f'telemetry-off-{case}-{arm}'
            execute(name,'test_y1_envelope',[f'--case={case}',f'--candidate={arm}','--telemetry=off',f'--output={output/(name+".json")}'])
    # Real asynchronous runs follow the complete synchronous population.
    for index,spec in enumerate(protocol['async_cases']):
        for arm in (['B0','Y1'] if index%2==0 else ['Y1','B0']):
            name = f'{spec["id"]}-{arm}'
            execute(name,'test_y1_envelope_async',[f'--case={spec["id"]}',f'--candidate={arm}',f'--output={output/(name+".json")}'],60)


if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--project',type=Path,default=Path('build/godot'))
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--only',help='preflight only; not a complete qualification')
    run(parser.parse_args())
