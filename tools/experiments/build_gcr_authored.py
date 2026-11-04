"""Build source-matched authored-compound runtimes with the retained pinned tools."""
import argparse
import concurrent.futures
import os
from pathlib import Path

from run_gcr_causal import run
from run_gcr_creep import ROOT,git,linux,sha,write

def native_inputs():
    return {p.relative_to(ROOT).as_posix():sha(p,True)
            for folder in ('native/src','native/include','godot/native_extension')
            for p in (ROOT/folder).rglob('*')
            if p.is_file() and p.suffix in {'.c','.cpp','.h','.hpp','.inc'}}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();folder=args.output.resolve()
    if folder.exists(): raise RuntimeError('Output must be fresh')
    inputs=native_inputs();source=git('rev-parse','HEAD').decode().strip()
    if git('diff','--binary','HEAD','--','native','godot/native_extension'):
        raise RuntimeError('Native source must be committed before building')
    tracked=set(git('ls-tree','-r','--name-only','HEAD').decode().splitlines())
    if not set(inputs).issubset(tracked): raise RuntimeError('Uncommitted native input')
    folder.mkdir(parents=True)
    write(folder/'identity.json',{'source':source,'tree':git('rev-parse','HEAD^{tree}').decode().strip(),
          'native_inputs':inputs,'uncompiled_dirty_paths':git('status','--porcelain=v1').decode().splitlines()})
    def build(platform):
        name='cybersand_native.windows.x86_64.dll' if platform=='windows' else 'libcybersand_native.linux.x86_64.so'
        output=folder/name;env=dict(os.environ)
        if platform=='windows':
            env.update(PATH='C:/Users/_/lcb-local-toolchain/shims;'+env['PATH'],
                GODOT_CPP_ROOT='C:/Users/_/lcb-local-toolchain/env/godot-cpp-101ae38034304346a46ea9ea84ae156d3e860496',
                WINDOWS_CXX='C:/Users/_/lcb-local-toolchain/llvm-mingw-20260826/bin/x86_64-w64-mingw32-g++.exe',
                CYBERSAND_NATIVE_OUTPUT=output.as_posix())
            command=['C:/Program Files/Git/bin/bash.exe','tools/build_native_extension_windows.sh']
        else:
            command=['wsl','-d','Ubuntu-24.04','--cd',str(ROOT),'--','env','LINUX_CXX=/usr/bin/g++-13',
                'GODOT_CPP_ROOT=/home/i/render-publication-abc-tools/godot-cpp-101ae38034304346a46ea9ea84ae156d3e860496',
                'CYBERSAND_NATIVE_OUTPUT='+linux(output),'bash','tools/build_native_extension.sh']
        receipt=run(command,folder/(platform+'.log'),1200,env,platform,'bash')
        receipt.update(source=source,platform=platform)
        if receipt['ok']:
            assert native_inputs()==inputs
            receipt.update(artifact=str(output),sha256=sha(output),bytes=output.stat().st_size,source_inputs=inputs)
        write(folder/(platform+'.json'),receipt)
        print(platform,receipt['ok'],flush=True)
        return receipt
    with concurrent.futures.ThreadPoolExecutor(2) as pool:
        receipts=list(pool.map(build,['windows','linux']))
    assert native_inputs()==inputs
    write(folder/'completion.json',{'ok':all(r['ok'] for r in receipts),'source':source,'native_inputs_unchanged':True})
    return 0 if all(r['ok'] for r in receipts) else 1

if __name__=='__main__': raise SystemExit(main())
