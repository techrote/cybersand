#!/usr/bin/env python3
"""Build isolated live-policy runtimes; preserve canonical provenance and guards."""
import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import la_selective_experiment as p

ROOT=Path(__file__).resolve().parents[2]
BASE='4cd9ca193176e315f8e81316e2221b275cdccbde'
PROFILE='native/tests/fixtures/sol_active_normal_live_001.json'
OUTPUT=ROOT/'build/sol-active-normal-live/runtimes-001'
BINARIES={'windows':'cybersand_native.windows.x86_64.dll','linux':'libcybersand_native.linux.x86_64.so'}

def sha(path):return p.sha(path.read_bytes())
def lfsha(path):return p.sha(path.read_bytes().replace(b'\r\n',b'\n'))

def source_identity():
    assert not p.git('status','--porcelain'),'Commit inputs before execution'
    subprocess.run(['git','merge-base','--is-ancestor',BASE,'HEAD'],cwd=ROOT,check=True)
    profile=json.loads((ROOT/PROFILE).read_text())
    retained=json.loads((ROOT/'godot/addons/cybersand_native/runtime-provenance.json').read_text())
    suffixes={'.c','.cc','.cpp','.cxx','.h','.hh','.hpp','.hxx','.inc','.inl','.tpp'}
    paths={f.relative_to(ROOT).as_posix() for d in ['native/include','native/src','godot/native_extension']
           for f in (ROOT/d).rglob('*') if f.is_file() and f.suffix in suffixes}
    assert paths==set(retained['source_inputs']) and len(paths)==84
    inventory={n:lfsha(ROOT/n) for n in sorted(paths)}
    delta={n:{'retained':retained['source_inputs'][n],'candidate':h} for n,h in inventory.items() if h!=retained['source_inputs'][n]}
    assert set(delta)==set(profile['production_files'])
    frozen={n:lfsha(ROOT/n) for n in p.git('ls-files','godot/addons','third_party').decode().splitlines()
            if n.endswith('.json') and ('provenance' in n or 'lock' in n)}
    for n in frozen:assert (ROOT/n).read_bytes().replace(b'\r\n',b'\n')==p.git('show',BASE+':'+n),n
    return dict(source=p.git('rev-parse','HEAD').decode().strip(),tree=p.git('rev-parse','HEAD^{tree}').decode().strip(),
        base=BASE,profile_sha256=lfsha(ROOT/PROFILE),native_inputs=inventory,delta=delta,frozen_manifests=frozen,
        runner_sha256=lfsha(Path(__file__)),builder_sha256={n:lfsha(ROOT/n) for n in
        ['tools/build_native_extension.sh','tools/build_native_extension_windows.sh','tools/toolchains/g++','tools/verify_pinned_source_tree.py']})

def build():
    assert not OUTPUT.exists(),'Preserve previous build attempt'
    info=source_identity();OUTPUT.mkdir(parents=True)
    receipt=dict(identity=info,qualification='experimental runtime only; canonical manifests unchanged',platforms={})
    def host(platform):
        folder=OUTPUT/platform;folder.mkdir();rows=[]
        def run(name,argv,env=None,timeout=180):
            row=p.command(name,argv,folder,env,timeout=timeout);rows.append(row);return row
        if platform=='windows':
            sdk=Path('C:/Users/_/lcb-local-toolchain/env/godot-cpp-101ae38034304346a46ea9ea84ae156d3e860496')
            compiler=Path('C:/Users/_/lcb-local-toolchain/llvm-mingw-20260826/bin/x86_64-w64-mingw32-g++.exe')
            library=sdk/'bin/libgodot-cpp.windows.template_debug.x86_64.a'
            tool=dict(sdk=str(sdk),library_sha256=sha(library),compiler=str(compiler),compiler_sha256=sha(compiler),
                sdk_ledger_sha256=sha(sdk/'.cybersand-source-files.sha256'))
            run('compiler-version',[str(compiler),'--version'])
            env=dict(os.environ,CYBERSAND_ALLOW_TOOLCHAIN_DRIFT='0',CYBERSAND_VERIFY_M11_OUTPUT='0',
                GODOT_CPP_ROOT=str(sdk),WINDOWS_CXX=str(compiler),CYBERSAND_NATIVE_OUTPUT=str(OUTPUT/BINARIES[platform]),
                PATH='C:/Users/_/lcb-local-toolchain/shims;'+os.environ['PATH'])
            built=run('build',['C:/Program Files/Git/bin/bash.exe','tools/build_native_extension_windows.sh'],env,900)
        else:
            linux=['wsl.exe','-d','Ubuntu-24.04','--cd',p.wsl_path(ROOT),'--']
            sdk='/home/i/render-publication-abc-tools/godot-cpp-101ae38034304346a46ea9ea84ae156d3e860496'
            code="import hashlib,json,pathlib,subprocess,shutil;paths={'wrapper':pathlib.Path('tools/toolchains/g++'),'driver':pathlib.Path(shutil.which('g++')).resolve(),'frontend':pathlib.Path(subprocess.check_output(['g++','-print-prog-name=cc1plus'],text=True).strip()).resolve(),'linker':pathlib.Path(shutil.which('ld')).resolve(),'library':pathlib.Path("+repr(sdk+ '/bin/libgodot-cpp.linux.template_debug.x86_64.a')+"),'sdk_ledger':pathlib.Path("+repr(sdk+'/.cybersand-source-files.sha256')+")};print(json.dumps({k:dict(path=str(v),sha256=hashlib.sha256(v.read_bytes()).hexdigest()) for k,v in paths.items()}))"
            row=run('toolchain-identity',linux+['python3','-c',code]);assert row['clean']
            tool=json.loads((ROOT/row['log']).read_text())
            run('compiler-version',linux+['g++','--version']);run('linker-version',linux+['ld','--version'])
            built=run('build',linux+['env','CYBERSAND_ALLOW_TOOLCHAIN_DRIFT=0','CYBERSAND_VERIFY_M11_OUTPUT=0',
                'GODOT_CPP_ROOT='+sdk,'LINUX_CXX='+p.wsl_path(ROOT/'tools/toolchains/g++'),
                'CYBERSAND_NATIVE_OUTPUT='+p.wsl_path(OUTPUT/BINARIES[platform]),'bash','tools/build_native_extension.sh'],timeout=900)
        binary=OUTPUT/BINARIES[platform]
        return dict(toolchain=tool,commands=rows,clean=built['clean'],output=str(binary.relative_to(ROOT)),
            output_sha256=sha(binary) if binary.exists() else None)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        for platform,row in zip(BINARIES,pool.map(host,BINARIES)):
            receipt['platforms'][platform]=row;p.write(OUTPUT/'receipt.json',receipt)
    after=source_identity();assert info==after,'Source changed during build'
    receipt['post_source_equality']=True;p.write(OUTPUT/'receipt.json',receipt)
    return int(not all(r['clean'] for r in receipt['platforms'].values()))

def identity():
    info=source_identity();receipt=json.loads((OUTPUT/'receipt.json').read_text())
    assert receipt['post_source_equality'] and receipt['identity']['native_inputs']==info['native_inputs']
    for platform,row in receipt['platforms'].items():
        assert row['clean'] and all(c['clean'] for c in row['commands'])
        assert sha(ROOT/row['output'])==row['output_sha256']
    return dict(**info,rebuild=receipt)

if __name__=='__main__':
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('action',choices=['build','identity']);args=parser.parse_args()
    if args.action=='build':raise SystemExit(build())
    print(json.dumps(identity()))
