"""Read-only Wasm S0 source/command verification and accepted Linux byte comparison."""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import zipfile

from wasm_run import digest


def verify(root,commit,linux_archive):
    root=Path(root).resolve();r=json.loads((root/'result.json').read_bytes());inventory=json.loads((root/'inventory.json').read_bytes())
    if set(inventory)!={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.name!='inventory.json'}:raise ValueError('evidence inventory')
    for name,seal in inventory.items():
        path=root/name
        if not path.resolve().is_relative_to(root) or path.is_symlink() or digest(path)!=seal:raise ValueError('evidence seal')
    if r.get('status')!='passed' or r.get('source_commit')!=commit or r.get('timing') is not False or r.get('world_qualification') is not False:raise ValueError('completion/source/scope identity')
    reg=root/'source/tools/experiments/mat003_optional/wasm-storage-registration.json';spec=json.loads(reg.read_bytes())
    if digest(reg)!=r['registration_sha256']:raise ValueError('registration seal')
    required={*spec['frozen_inputs_sha256'],'tools/experiments/mat003_optional/wasm-storage-registration.json','tools/experiments/mat003_optional/wasm_storage_run.py','tools/experiments/mat003_optional/wasm_run.py'}
    if set(r['source_sha256'])!=required:raise ValueError('source inventory')
    for name,seal in r['source_sha256'].items():
        path=root/'source'/name
        if digest(path)!=seal or path.read_bytes()!=subprocess.check_output(['git','show',commit+':'+name]):raise ValueError('frozen Git source')
        if name in spec['frozen_inputs_sha256'] and seal!=spec['frozen_inputs_sha256'][name]:raise ValueError('changed S0 input')
    if (r['sdk_source_commit'],r['release_build_identity'],r['node_version'])!=(spec['sdk_source_commit'],spec['release_build_identity'],spec['node_version']) or not re.search(r'\b4\.0\.20\b',r['compiler_version'].splitlines()[0]):raise ValueError('SDK/tool identity')
    if len(r['downloaded_archive_sha256'])<2 or len(r['tool_sha256'])!=4 or not r['system_library_sha256'] or not r['license_sha256']:raise ValueError('toolchain receipts')
    for name,seal in r['license_sha256'].items():
        if digest(root/'licenses'/name)!=seal:raise ValueError('license seal')
    if (root/'wasm_abi.hpp').read_bytes()!=b'static_assert(sizeof(void*) == 4, "Wasm32 pointer ABI");\n' or digest(root/'wasm_abi.hpp')!=r['abi_assertion_sha256']:raise ValueError('Wasm32 ABI assertion')
    if set(r['assets'])!={'storage.js','storage.wasm'}:raise ValueError('asset inventory')
    for name,seal in r['assets'].items():
        if digest(root/name)!=seal:raise ValueError('asset seal')
    labels=['compiler-version','node-version','build-storage','case-storage']
    if len(r['commands'])!=4:raise ValueError('command matrix')
    original=r['commands'][2]['argv'][-1].rsplit('/',1)[0]
    normal=lambda argv:[str(value).replace(original,'$EVIDENCE') for value in argv]
    expected=[[r['compiler'],'--version'],[r['node'],'--version'],
              [r['compiler'],*spec['flags'],'-include','$EVIDENCE/wasm_abi.hpp','-I$EVIDENCE/source/native/include','$EVIDENCE/source/tools/experiments/mat003_prepass/test_carriers.cpp','-o','$EVIDENCE/storage.js'],
              [r['node'],'$EVIDENCE/storage.js']]
    for index,(label,receipt,argv) in enumerate(zip(labels,r['commands'],expected)):
        if receipt!=json.loads((root/(label+'.receipt.json')).read_bytes()) or receipt['exit_code']!=0 or receipt['stop'] or normal(receipt['argv'])!=argv:raise ValueError('ordered command binding')
        timeout=30 if index<2 else spec['limits']['compile_timeout_seconds'] if index==2 else spec['limits']['case_timeout_seconds']
        if receipt['timeout_seconds']!=timeout or receipt['elapsed_watchdog_seconds']>timeout+1:raise ValueError('command watchdog')
        for stream in ('stdout','stderr'):
            if digest(root/(label+'.'+stream))!=receipt[stream+'_sha256']:raise ValueError('stream seal')
        err=(root/(label+'.stderr')).read_text(encoding='utf-8')
        if re.search(r'warning:|error:|traceback|fatal error',err,re.I) or (err and index not in (0,2)) or (index==0 and any(line.strip() and not line.startswith('shared:INFO:') for line in err.splitlines())):raise ValueError('diagnostic')
    result=r['storage_result']
    if result!=json.loads((root/'case-storage.stdout').read_bytes()):raise ValueError('result stdout binding')
    reader=Path(__file__).parent.parent/'mat003_prepass/verify.py'
    if digest(reader)!=spec['frozen_inputs_sha256']['tools/experiments/mat003_prepass/verify.py']:raise ValueError('S0 validator source')
    module_spec=importlib.util.spec_from_file_location('mat003_s0_validator',reader);module=importlib.util.module_from_spec(module_spec);module_spec.loader.exec_module(module)
    errors=module.validate_result(result,json.loads((root/'source/tools/experiments/mat003_prepass/registration.json').read_bytes()))
    if errors:raise ValueError('S0 record validation: '+repr(errors))
    if digest(linux_archive)!='e73030777e54ba2b7b04e8abe046c5bca8f4c513770b6e48cee3fb76d15c9380':raise ValueError('accepted Linux archive identity')
    with zipfile.ZipFile(linux_archive) as archive:linux=json.loads(archive.read('normal.json'))
    if {k:v for k,v in result.items() if k!='arms'}!={k:v for k,v in linux.items() if k!='arms'}:raise ValueError('Linux/Wasm fixture summary disagreement')
    if len(result['arms'])!=17 or len(linux['arms'])!=17:raise ValueError('17-arm coverage')
    for wasm,native in zip(result['arms'],linux['arms']):
        if {k:v for k,v in wasm.items() if k!='descriptor_bytes'}!={k:v for k,v in native.items() if k!='descriptor_bytes'}:raise ValueError('Linux/Wasm exact arm records or array accounting disagree')
        if (wasm['descriptor_bytes'],native['descriptor_bytes'])!=((56,72) if wasm['representation']=='split' else (0,0)):raise ValueError('observed split ABI metadata')
    if r['elapsed_watchdog_seconds']>spec['limits']['aggregate_seconds']:raise ValueError('aggregate watchdog')
    return {'status':'verified','arms':17,'checks':result['checks'],'exact_linux_normal_records_compared':True,'wasm_split_descriptor_bytes':56,'linux_split_descriptor_bytes':72,
            'timing':False,'native_world_qualified':False,'sanitizers':False,'validation_class':'author-validation-pending-independent-review'}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('evidence',type=Path);p.add_argument('--source-commit',required=True);p.add_argument('--linux-archive',type=Path,required=True);a=p.parse_args()
    print(json.dumps(verify(a.evidence,a.source_commit,a.linux_archive),indent=2))
