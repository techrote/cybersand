"""One untimed Wasm32 run of the unchanged registered 17-arm S0 fixture."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

from wasm_run import digest

ROOT=Path(__file__).resolve().parents[3]


def collect(output,sdk):
    output=Path(output).resolve();sdk=Path(sdk).resolve();output.mkdir(parents=True,exist_ok=False)
    reg=Path(__file__).with_name('wasm-storage-registration.json');spec=json.loads(reg.read_bytes());started=time.monotonic()
    r={'status':'failed','timing':False,'world_qualification':False,'validation_class':'author-validation-pending-independent-review',
       'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'registration_sha256':digest(reg),'commands':[]}
    def command(argv,label,timeout,info=False,build=False):
        remaining=spec['limits']['aggregate_seconds']-(time.monotonic()-started)
        if remaining<=0:raise ValueError('aggregate watchdog')
        before=time.monotonic();code=None;stop=None
        try:
            with (output/(label+'.stdout')).open('xb') as out,(output/(label+'.stderr')).open('xb') as err:
                code=subprocess.run(list(map(str,argv)),cwd=output,stdout=out,stderr=err,timeout=min(timeout,remaining)).returncode
        except Exception as error:stop=str(error)
        receipt={'argv':list(map(str,argv)),'exit_code':code,'stop':stop,'timeout_seconds':timeout,'elapsed_watchdog_seconds':time.monotonic()-before,
                 'stdout_sha256':digest(output/(label+'.stdout')),'stderr_sha256':digest(output/(label+'.stderr'))}
        r['commands'].append(receipt);(output/(label+'.receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n')
        err=(output/(label+'.stderr')).read_text(encoding='utf-8',errors='replace')
        if code!=0 or stop or (err and not(info or build)) or (info and any(line.strip() and not line.startswith('shared:INFO:') for line in err.splitlines())) or re.search(r'warning:|error:|traceback|fatal error',err,re.I):raise ValueError('retained command refusal: '+label)
        if sum(p.stat().st_size for p in output.rglob('*') if p.is_file())>spec['limits']['output_bytes']:raise ValueError('output bound')
        return (output/(label+'.stdout')).read_text(encoding='utf-8')
    try:
        if subprocess.check_output(['git','-C',sdk,'rev-parse','HEAD'],text=True).strip()!=spec['sdk_source_commit']:raise ValueError('SDK source')
        subprocess.run(['git','-C',sdk,'diff','--exit-code'],check=True,stdout=subprocess.DEVNULL)
        if json.loads((sdk/'emscripten-releases-tags.json').read_bytes())['releases'][spec['emscripten']]!=spec['release_build_identity']:raise ValueError('release build')
        compiler=sdk/'upstream/emscripten/em++';node=Path(os.environ['EMSDK_NODE'])
        r['compiler_version']=command([compiler,'--version'],'compiler-version',30,info=True);r['node_version']=command([node,'--version'],'node-version',30).strip()
        if not re.search(r'\b4\.0\.20\b',r['compiler_version'].splitlines()[0]) or r['node_version']!=spec['node_version']:raise ValueError('tool version')
        r.update(compiler=str(compiler),node=str(node),sdk_source_commit=spec['sdk_source_commit'],release_build_identity=spec['release_build_identity'],python=sys.version)
        r['tool_sha256']={str(p):digest(p) for p in (compiler,node,sdk/'upstream/bin/clang',sdk/'upstream/bin/wasm-ld')}
        r['downloaded_archive_sha256']={p.relative_to(sdk).as_posix():{'bytes':p.stat().st_size,'sha256':digest(p)} for p in (sdk/'downloads').glob('*') if p.is_file() and p.name.endswith(('.xz','.gz','.zip'))}
        if len(r['downloaded_archive_sha256'])<2:raise ValueError('SDK_KEEP_DOWNLOADS absent')
        licenses=[sdk/'LICENSE',sdk/'upstream/emscripten/LICENSE']
        for directory in (sdk/'upstream/emscripten/system/lib',sdk/'node'):
            licenses.extend(p for p in directory.rglob('*') if p.is_file() and p.name.lower() in ('license','license.txt','license.md','copying','copying.txt','copyright'))
        for path in sorted(set(licenses)):
            target=output/'licenses'/path.relative_to(sdk);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,target)
        r['license_sha256']={p.relative_to(output/'licenses').as_posix():digest(p) for p in (output/'licenses').rglob('*') if p.is_file()}
        names=[*spec['frozen_inputs_sha256'],str(reg.relative_to(ROOT)).replace('\\','/'),'tools/experiments/mat003_optional/wasm_storage_run.py','tools/experiments/mat003_optional/wasm_run.py']
        for name in names:
            target=output/'source'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,target)
            if name in spec['frozen_inputs_sha256'] and digest(target)!=spec['frozen_inputs_sha256'][name]:raise ValueError('unchanged frozen input: '+name)
        r['source_sha256']={name:digest(output/'source'/name) for name in names}
        abi=output/'wasm_abi.hpp';abi.write_text('static_assert(sizeof(void*) == 4, "Wasm32 pointer ABI");\n')
        r['abi_assertion_sha256']=digest(abi)
        binary=output/'storage.js'
        command([compiler,*spec['flags'],'-include',abi,'-I'+str(output/'source/native/include'),output/'source/tools/experiments/mat003_prepass/test_carriers.cpp','-o',binary],'build-storage',spec['limits']['compile_timeout_seconds'],build=True)
        r['assets']={p.name:digest(p) for p in output.glob('storage.*') if p.is_file()}
        if not {'storage.js','storage.wasm'}<=set(r['assets']):raise ValueError('missing JS/Wasm')
        result=json.loads(command([node,binary],'case-storage',spec['limits']['case_timeout_seconds']))
        module_spec=importlib.util.spec_from_file_location('frozen_s0_validator',output/'source/tools/experiments/mat003_prepass/verify.py')
        validator=importlib.util.module_from_spec(module_spec);module_spec.loader.exec_module(validator)
        errors=validator.validate_result(result,json.loads((output/'source/tools/experiments/mat003_prepass/registration.json').read_bytes()))
        if errors:raise ValueError('S0 record validation: '+repr(errors))
        r['storage_result']=result;r['system_library_sha256']={p.relative_to(sdk).as_posix():digest(p) for p in (sdk/'upstream/emscripten/cache').rglob('*.a') if p.is_file()};r['status']='passed'
    except Exception as error:r['error']=str(error);raise
    finally:
        r['elapsed_watchdog_seconds']=time.monotonic()-started;(output/'result.json').write_text(json.dumps(r,indent=2)+'\n')
        (output/'inventory.json').write_text(json.dumps({p.relative_to(output).as_posix():digest(p) for p in output.rglob('*') if p.is_file()},indent=2)+'\n')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--sdk',type=Path,required=True);a=p.parse_args();collect(a.output,a.sdk)
