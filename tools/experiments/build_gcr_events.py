from pathlib import Path
import sys,os,json,hashlib,subprocess,concurrent.futures
sys.path.insert(0,'tools/experiments')
from run_gcr_causal import run
from run_gcr_creep import sha,linux,write,git
root=Path.cwd();source=git('rev-parse','HEAD').decode().strip()
inputs={p.relative_to(root).as_posix():sha(p,True) for folder in ['native/src','native/include','godot/native_extension'] for p in (root/folder).rglob('*') if p.is_file() and p.suffix in {'.c','.cpp','.h','.hpp','.inc'}}
folder=root/'build/native-events-01';folder.mkdir()
def build(platform):
    name='cybersand_native.windows.x86_64.dll' if platform=='windows' else 'libcybersand_native.linux.x86_64.so'
    output=folder/name
    env=dict(os.environ)
    if platform=='windows':
        env.update(PATH='C:/Users/_/lcb-local-toolchain/shims;'+env['PATH'],GODOT_CPP_ROOT='C:/Users/_/lcb-local-toolchain/env/godot-cpp-101ae38034304346a46ea9ea84ae156d3e860496',WINDOWS_CXX='C:/Users/_/lcb-local-toolchain/llvm-mingw-20260826/bin/x86_64-w64-mingw32-g++.exe',CYBERSAND_NATIVE_OUTPUT=output.as_posix())
        cmd=['C:/Program Files/Git/bin/bash.exe','tools/build_native_extension_windows.sh']
    else:
        cmd=['wsl','-d','Ubuntu-24.04','--cd',str(root),'--','env','LINUX_CXX=/usr/bin/g++-13','GODOT_CPP_ROOT=/home/i/render-publication-abc-tools/godot-cpp-101ae38034304346a46ea9ea84ae156d3e860496','CYBERSAND_NATIVE_OUTPUT='+linux(output),'bash','tools/build_native_extension.sh']
    receipt=run(cmd,folder/(platform+'.log'),1200,env,platform,'bash')
    receipt.update(source=source,platform=platform)
    if receipt['ok']:
        assert all(sha(root/p,True)==h for p,h in inputs.items())
        receipt.update(artifact=str(output),sha256=sha(output),bytes=output.stat().st_size,source_inputs=inputs)
    write(folder/(platform+'.json'),receipt)
    print(platform,receipt['ok'],flush=True)
    return receipt
with concurrent.futures.ThreadPoolExecutor(2) as pool: receipts=list(pool.map(build,['windows','linux']))
write(folder/'completion.json',dict(ok=all(x['ok'] for x in receipts),source=source))
raise SystemExit(0 if all(x['ok'] for x in receipts) else 1)
