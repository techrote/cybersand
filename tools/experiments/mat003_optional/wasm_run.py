"""Registered standalone Wasm32/Node specimens. This never builds Godot."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[3]


def digest(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''):h.update(block)
    return h.hexdigest()


def collect(output,sdk):
    output=Path(output).resolve();sdk=Path(sdk).resolve();output.mkdir(parents=True,exist_ok=False)
    registration=Path(__file__).with_name('wasm-registration-v3.json');spec=json.loads(registration.read_text())
    started=time.monotonic()
    result={'status':'failed','timing':False,'validation_class':'author-validation-pending-independent-review',
            'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            'registration_sha256':digest(registration),'commands':[],'builds':[],'cases':[]}

    def command(argv,label,timeout,build=False,setup_info=False):
        remaining=spec['limits']['aggregate_seconds']-(time.monotonic()-started)
        if remaining<=0:raise ValueError('aggregate watchdog')
        before=time.monotonic();code=None;stop=None
        try:
            with (output/(label+'.stdout')).open('xb') as out,(output/(label+'.stderr')).open('xb') as err:
                code=subprocess.run(list(map(str,argv)),cwd=output,stdout=out,stderr=err,timeout=min(timeout,remaining)).returncode
        except (subprocess.TimeoutExpired,OSError) as error:stop=type(error).__name__+': '+str(error)
        stderr=(output/(label+'.stderr')).read_text(errors='replace')
        receipt={'argv':list(map(str,argv)),'exit_code':code,'stop':stop,'timeout_seconds':timeout,
                 'elapsed_watchdog_seconds':time.monotonic()-before,'compiler_cache_info_allowed':build,
                 'sdk_sanity_info_allowed':setup_info,
                 'stdout_sha256':digest(output/(label+'.stdout')),'stderr_sha256':digest(output/(label+'.stderr'))}
        result['commands'].append(receipt);(output/(label+'.receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n')
        invalid_setup=setup_info and any(line.strip() and not line.startswith('shared:INFO:') for line in stderr.splitlines())
        if code!=0 or stop or (stderr and not (build or setup_info)) or invalid_setup or ((build or setup_info) and re.search(r'warning:|error:|traceback|fatal error',stderr,re.I)):
            raise ValueError('retained command failure: '+label)
        if sum(p.stat().st_size for p in output.rglob('*') if p.is_file())>spec['limits']['output_bytes']:raise ValueError('output bound')
        return (output/(label+'.stdout')).read_text()

    try:
        revision=subprocess.check_output(['git','-C',sdk,'rev-parse','HEAD'],text=True).strip()
        if revision!=spec['sdk_source_commit']:raise ValueError('SDK Git identity')
        subprocess.run(['git','-C',sdk,'diff','--exit-code'],check=True,stdout=subprocess.DEVNULL)
        releases=json.loads((sdk/'emscripten-releases-tags.json').read_text())
        if releases['releases'][spec['emscripten']]!=spec['release_build_identity']:raise ValueError('SDK release identity')
        compiler=(sdk/'upstream/emscripten/em++').resolve()
        node=Path(os.environ.get('EMSDK_NODE') or shutil.which('node') or '').resolve()
        compiler_version=command([compiler,'--version'],'compiler-version',30,setup_info=True)
        node_version=command([node,'--version'],'node-version',30).strip()
        if not re.search(r'\b4\.0\.20\b',compiler_version.splitlines()[0]) or node_version!=spec['node_version']:
            raise ValueError('compiler/Node version drift')
        tools=[compiler,node,sdk/'upstream/bin/clang',sdk/'upstream/bin/wasm-ld']
        result['tool_sha256']={str(p):digest(p) for p in tools}
        result.update(sdk_source_commit=revision,release_build_identity=spec['release_build_identity'],compiler=str(compiler),node=str(node),
                      compiler_version=compiler_version,node_version=node_version,python=sys.version)
        archives=[p for directory in ('downloads','zips') if (sdk/directory).exists() for p in (sdk/directory).rglob('*') if p.is_file() and p.name.endswith(('.xz','.gz','.zip','.bz2'))]
        if len(archives)<2:raise ValueError('SDK_KEEP_DOWNLOADS archive retention absent')
        result['downloaded_archive_sha256']={p.relative_to(sdk).as_posix():{'bytes':p.stat().st_size,'sha256':digest(p)} for p in archives}
        license_files=[sdk/'LICENSE',sdk/'upstream/emscripten/LICENSE']
        for directory in (sdk/'upstream/emscripten/system/lib',sdk/'node'):
            if directory.exists():license_files.extend(p for p in directory.rglob('*') if p.is_file() and p.name.lower() in ('license','license.txt','license.md','copyright','copying','copying.txt'))
        for path in sorted(set(license_files)):
            target=output/'licenses'/path.relative_to(sdk);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,target)
        result['license_sha256']={p.relative_to(output/'licenses').as_posix():digest(p) for p in (output/'licenses').rglob('*') if p.is_file()}
        sources=[p for d in ('native/include','native/src') for p in (ROOT/d).rglob('*') if p.suffix in ('.cpp','.hpp')]
        sources += [p for d in ('tools/experiments/mat003_optional','tools/experiments/mat003_touch') for p in (ROOT/d).glob('*') if p.suffix in ('.cpp','.py','.json')]
        for path in sources:
            target=output/'source'/path.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,target)
        result['source_sha256']={p.relative_to(ROOT).as_posix():digest(output/'source'/p.relative_to(ROOT)) for p in sources}
        abi=output/'wasm_abi.hpp';abi.write_text('#pragma once\n#ifndef __EMSCRIPTEN__\n#error Emscripten target required\n#endif\nstatic_assert(sizeof(void*) == 4, "Wasm32 pointer ABI");\n')
        result['abi_assertion_sha256']=digest(abi)
        shutil.copytree(output/'source/native',output/'compiled/native')
        overlay=json.loads((output/'source/tools/experiments/mat003_touch/registration-v3.json').read_text())['source_overlay']
        path=output/'compiled'/overlay['file'];before=path.read_bytes()
        if before.count(overlay['old'].encode())!=1:raise ValueError('overlay context')
        path.write_bytes(before.replace(overlay['old'].encode(),overlay['new'].encode()))
        result['compiled_sha256']={p.relative_to(output/'compiled').as_posix():digest(p) for p in (output/'compiled').rglob('*') if p.is_file()}
        for kind,bits in (('optional',8),('optional',16),('touch',0)):
            name=kind+'-'+str(bits);binary=output/(name+'.js')
            args=[compiler,*spec['flags'],'-include',abi]
            if kind=='optional':args += [f'-DMAT003_TAIL_BITS={bits}','-I'+str(output/'source/native/include'),output/'source/tools/experiments/mat003_optional/fixture.cpp']
            else:args += [*spec['touch_additional_flags'],'-I'+str(output/'compiled/native/include'),output/'source/tools/experiments/mat003_touch/fixture.cpp',
                          *(output/'compiled/native/src'/n for n in ('world.cpp','material_rules.cpp','scheduler_geometry.cpp','settled_world_discovery.cpp'))]
            command([*args,'-o',binary],'build-'+name,spec['limits']['compile_timeout_seconds'],build=True)
            assets={p.name:digest(p) for p in output.glob(name+'.*') if p.is_file()}
            if binary.name not in assets or name+'.wasm' not in assets:raise ValueError('missing JS/Wasm assets')
            result['builds'].append({'kind':kind,'bits':bits,'path':binary.name,'assets':assets})
        for build in result['builds']:
            contexts=[(side,mode) for side in (512,1024,2048) for mode in ('absent','allocated-unread','accessed-clustered','accessed-dispersed')] if build['kind']=='optional' else [('serial-1',),('phased-1',),('phased-4',)]
            for context in contexts:
                label=f"case-{len(result['cases']):03d}";print(label,build['kind'],context,flush=True)
                row=json.loads(command([node,output/build['path'],*context],label,spec['limits']['case_timeout_seconds']))
                if row.get('status')!='passed' or row.get('timing') is not False:raise ValueError('case failure')
                if build['kind']=='optional' and (row['tail_bits'],row['side'],row['mode'])!=(build['bits'],*context):raise ValueError('optional context')
                if build['kind']=='touch' and (row['mode']!=context[0] or row['native_ticks']!=513 or row['recoveries']!=9):raise ValueError('touch context')
                result['cases'].append({'kind':build['kind'],'result':row})
        if len(result['cases'])!=27:raise ValueError('case coverage')
        result['system_library_sha256']={p.relative_to(sdk).as_posix():digest(p) for p in (sdk/'upstream/emscripten/cache').rglob('*.a') if p.is_file()}
        result['status']='passed'
    except Exception as error:
        result['error']=str(error);raise
    finally:
        result['elapsed_watchdog_seconds']=time.monotonic()-started
        (output/'result.json').write_text(json.dumps(result,indent=2)+'\n')
        (output/'inventory.json').write_text(json.dumps({p.relative_to(output).as_posix():digest(p) for p in output.rglob('*') if p.is_file()},indent=2)+'\n')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--sdk',type=Path,required=True);args=p.parse_args()
    collect(args.output,args.sdk)
