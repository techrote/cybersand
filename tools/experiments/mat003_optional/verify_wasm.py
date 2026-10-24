"""Read-only verification of the registered standalone Wasm/Node archive.

This checks archived claims and compares them with desktop specimen results.
It does not rerun Wasm, reproduce the SDK build, or qualify Godot/browser code.
"""
import argparse
import hashlib
import itertools
import json
from pathlib import Path, PurePosixPath
import re
import subprocess


def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def verify(root, expected_commit, windows_optional, windows_touch):
    root=Path(root).resolve()
    inventory=json.loads((root/'inventory.json').read_text())
    actual={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.name!='inventory.json'}
    if set(inventory)!=actual:raise ValueError('evidence inventory')
    for name,seal in inventory.items():
        path=root/name
        if not path.resolve().is_relative_to(root) or path.is_symlink() or digest(path)!=seal:raise ValueError('evidence seal')
    r=json.loads((root/'result.json').read_text())
    if r.get('status')!='passed' or r.get('timing') is not False or r.get('source_commit')!=expected_commit:
        raise ValueError('result identity/completion')
    names=subprocess.check_output(['git','ls-tree','-r','--name-only',expected_commit,'native','tools/experiments/mat003_optional','tools/experiments/mat003_touch'],text=True).splitlines()
    required={name for name in names if (name.startswith(('native/include/','native/src/')) and PurePosixPath(name).suffix in ('.cpp','.hpp')) or
              (name.startswith(('tools/experiments/mat003_optional/','tools/experiments/mat003_touch/')) and len(PurePosixPath(name).parts)==4 and PurePosixPath(name).suffix in ('.cpp','.py','.json'))}
    if set(r['source_sha256'])!=required:raise ValueError('source inventory')
    for name,seal in r['source_sha256'].items():
        path=root/'source'/name
        if digest(path)!=seal or path.read_bytes()!=subprocess.check_output(['git','show',expected_commit+':'+name]):raise ValueError('frozen source mismatch')
    reg=root/'source/tools/experiments/mat003_optional/wasm-registration-v4.json'
    spec=json.loads(reg.read_text())
    if digest(reg)!=r['registration_sha256']:raise ValueError('registration seal')
    if (r['sdk_source_commit'],r['release_build_identity'],r['node_version'])!=(spec['sdk_source_commit'],spec['release_build_identity'],spec['node_version']):raise ValueError('SDK identity')
    if not re.search(r'\b4\.0\.20\b',r['compiler_version'].splitlines()[0]):raise ValueError('compiler version')
    if len(r['downloaded_archive_sha256'])<2 or len(r['tool_sha256'])!=4 or not r['system_library_sha256']:raise ValueError('missing toolchain receipts')
    if not r['license_sha256']:raise ValueError('missing license notices')
    for name,seal in r['license_sha256'].items():
        if digest(root/'licenses'/name)!=seal:raise ValueError('license seal')
    abi=b'#pragma once\n#ifndef __EMSCRIPTEN__\n#error Emscripten target required\n#endif\nstatic_assert(sizeof(void*) == 4, "Wasm32 pointer ABI");\n'
    if (root/'wasm_abi.hpp').read_bytes()!=abi or digest(root/'wasm_abi.hpp')!=r['abi_assertion_sha256']:raise ValueError('Wasm32 ABI assertion')
    native={name for name in required if name.startswith('native/')}
    if set(r['compiled_sha256'])!=native:raise ValueError('compiled inventory')
    overlay=json.loads((root/'source/tools/experiments/mat003_touch/registration-v3.json').read_text())['source_overlay']
    for name,seal in r['compiled_sha256'].items():
        expected=(root/'source'/name).read_bytes()
        if name==overlay['file']:
            if expected.count(overlay['old'].encode())!=1:raise ValueError('overlay context')
            expected=expected.replace(overlay['old'].encode(),overlay['new'].encode())
        if (root/'compiled'/name).read_bytes()!=expected or digest(root/'compiled'/name)!=seal:raise ValueError('compiled literal overlay')
    if [(b['kind'],b['bits'],b['path']) for b in r['builds']]!=[('optional',8,'optional-8.js'),('optional',16,'optional-16.js'),('touch',0,'touch-0.js')]:raise ValueError('build coverage')
    labels=['compiler-version','node-version']+['build-'+b['kind']+'-'+str(b['bits']) for b in r['builds']]+[f'case-{i:03d}' for i in range(27)]
    if len(r['commands'])!=len(labels) or len(r['cases'])!=27:raise ValueError('full matrix coverage')
    original_root=r['commands'][2]['argv'][-1].rsplit('/',1)[0]
    normal=lambda argv:[str(v).replace(original_root,'$EVIDENCE') for v in argv]
    expected_commands=[[r['compiler'],'--version'],[r['node'],'--version']]
    contexts=[]
    for build in r['builds']:
        stem=build['path'][:-3]
        assets={p.name for p in root.glob(stem+'.*') if p.is_file()}
        if set(build['assets'])!=assets or not {stem+'.js',stem+'.wasm'}<=assets:raise ValueError('JS/Wasm asset coverage')
        for name,seal in build['assets'].items():
            if digest(root/name)!=seal:raise ValueError('JS/Wasm asset seal')
        args=[r['compiler'],*spec['flags'],'-include','$EVIDENCE/wasm_abi.hpp']
        if build['kind']=='optional':args += [f"-DMAT003_TAIL_BITS={build['bits']}",'-I$EVIDENCE/source/native/include','$EVIDENCE/source/tools/experiments/mat003_optional/fixture.cpp']
        else:args += [*spec['touch_additional_flags'],'-I$EVIDENCE/compiled/native/include','$EVIDENCE/source/tools/experiments/mat003_touch/fixture.cpp',
                      *('$EVIDENCE/compiled/native/src/'+name for name in ('world.cpp','material_rules.cpp','scheduler_geometry.cpp','settled_world_discovery.cpp'))]
        expected_commands.append([*args,'-o','$EVIDENCE/'+build['path']])
        configs=list(itertools.product((512,1024,2048),('absent','allocated-unread','accessed-clustered','accessed-dispersed'))) if build['kind']=='optional' else [('serial-1',),('phased-1',),('phased-4',)]
        contexts.extend((build,context) for context in configs)
    expected_commands.extend([[r['node'],'$EVIDENCE/'+build['path'],*map(str,context)] for build,context in contexts])
    for i,(label,receipt,expected) in enumerate(zip(labels,r['commands'],expected_commands)):
        if json.loads((root/(label+'.receipt.json')).read_text())!=receipt or receipt['exit_code']!=0 or receipt['stop']:raise ValueError('command receipt')
        if normal(receipt['argv'])!=expected:raise ValueError('ordered command binding')
        limit=30 if i<2 else spec['limits']['compile_timeout_seconds'] if i<5 else spec['limits']['case_timeout_seconds']
        if receipt['timeout_seconds']!=limit or receipt['elapsed_watchdog_seconds']>limit+1:raise ValueError('command watchdog')
        for stream in ('stdout','stderr'):
            if digest(root/(label+'.'+stream))!=receipt[stream+'_sha256']:raise ValueError('stream seal')
        err=(root/(label+'.stderr')).read_text()
        if i==0:
            if any(line.strip() and not line.startswith('shared:INFO:') for line in err.splitlines()):raise ValueError('version diagnostic')
        elif 2<=i<5:
            if re.search(r'warning:|error:|traceback|fatal error',err,re.I):raise ValueError('compiler diagnostic')
        elif err:raise ValueError('runtime diagnostic')
    optional_checks=touch_checks=0
    for i,(row,(build,context)) in enumerate(zip(r['cases'],contexts)):
        data=row['result']
        if row['kind']!=build['kind'] or data!=json.loads((root/f'case-{i:03d}.stdout').read_text()) or data.get('status')!='passed' or data.get('timing') is not False:raise ValueError('case result binding')
        if build['kind']=='optional':
            if (data['tail_bits'],data['side'],data['mode'])!=(build['bits'],*context):raise ValueError('optional context')
            win=next(c for c in windows_optional['cases'] if (c['tail_bits'],c['side'],c['mode'],c['sanitized'])==(build['bits'],*context,False))
            for key in data:
                if key not in ('owner_object_size','pointer_capacity_bytes') and data[key]!=win[key]:raise ValueError('desktop/Wasm logical disagreement: '+key)
            if data['owner_object_size']!=72 or data['pointer_capacity_bytes']!=data['resident_owners']*4:raise ValueError('Wasm32 owner/pointer accounting')
            optional_checks+=data['checks']
        else:
            if data['mode']!=context[0]:raise ValueError('touch context')
            win=next(c for c in windows_touch['cases'] if (c['mode'],c['sanitized'])==(context[0],False))
            if any(data[key]!=win[key] for key in data):raise ValueError('desktop/Wasm native touch disagreement')
            touch_checks+=data['checks']
    if r['elapsed_watchdog_seconds']>spec['limits']['aggregate_seconds']:raise ValueError('aggregate watchdog')
    return {'status':'verified','builds':3,'optional_cases':24,'touch_cases':3,'optional_checks':optional_checks,'touch_checks':touch_checks,
            'timing':False,'sanitizers':False,'windows_normal_compared':True,'godot_or_browser_qualified':False,
            'validation_class':'author-validation-pending-independent-review'}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('evidence',type=Path);p.add_argument('--source-commit',required=True)
    p.add_argument('--windows-optional',type=Path,required=True);p.add_argument('--windows-touch',type=Path,required=True);a=p.parse_args()
    print(json.dumps(verify(a.evidence,a.source_commit,json.loads(a.windows_optional.read_text()),json.loads(a.windows_touch.read_text())),indent=2))
