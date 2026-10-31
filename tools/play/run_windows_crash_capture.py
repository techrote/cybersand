#!/usr/bin/env python3
"""One opt-in Windows diagnostic attempt; never requalifies an earlier failed run."""
from __future__ import annotations
import argparse
import hashlib
import json
import ntpath
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import tempfile
import time
import zipfile
import windows_build_process as owned_build
import windows_crash_policy as policy

from windows_crash_contract import (DUMP_FORMAT, child_environment, read_events, read_json, read_load_identities, require, safe_file, sha,
                                   verify_capture, verify_control, verify_dump_timeout_control, verify_module_bindings)

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/ci'))
import run_windows_godot_regressions as windows

BASE='aa74448bad7ec77e5f152d9179a417ce76430009'
EXTRA=('tools/play/windows_crash_debugger.cpp','tools/play/windows_crash_control.c',
       'tools/play/windows_crash_contract.py','tools/play/run_windows_crash_capture.py',
       'tools/play/test_windows_crash_contract.py','tools/play/windows_build_process.py',
       'tools/play/test_windows_build_process.py','tools/play/windows_crash_policy.py',
       '.github/workflows/play-windows-crash-capture.yml',
       'docs/audits/2026-10-31-play-windows-crash-capture.md','.gitattributes',
       'tools/ci/check_repository.py','tools/ci/check_docs.py','tools/ci/check_ci_provider_policy.py')
SCOPES=(*windows.INPUT_SCOPES,*EXTRA)
FIXTURE='test_liquid_desktop_default_host'
PROTECTED=('godot','native','third_party','.github/workflows/gdextension.yml','tools/ci')
ENGINE_FILES={
    'Godot_v4.7-stable_win64.exe':{'sha256':'b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8','bytes':178485256},
    'Godot_v4.7-stable_win64_console.exe':{'sha256':'d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c','bytes':198152},
}
ENGINE_ARCHIVE_BYTES=83764371
CONTROL_MODES=('normal','handled','crash','child-crash','hang')
BUILD_CONTROL_MODES=('normal-child','nonzero','orphan-hang','slow-child','late-child-failure')
SLOW_CONTROL_SECONDS=20
TOOLCHAIN={
    'schema':'play-windows-clang-lld-v2',
    'family':'clang-cl/lld-link',
    'version':'20.1.8',
    'official_installer':{
        'url':'https://github.com/llvm/llvm-project/releases/download/llvmorg-20.1.8/LLVM-20.1.8-win64.exe',
        'bytes':385658654,
        'sha256':'3197846a2b19063687dd56e93e34cd941e3548d907f23a6131571321bdf9fe7b'},
    'compiler':{'path':r'C:\Program Files\LLVM\bin\clang-cl.exe','bytes':101879296,
                'sha256':'57e32b1ea2456f12f97bf802453171bbff12d56b2c486b4eca0c75343c0cda2c'},
    'linker':{'path':r'C:\Program Files\LLVM\bin\lld-link.exe','bytes':67509760,
              'sha256':'6590ac0122cd5e11fcd05cc9cd5b7ad01cb89961487b9b81c4330fb59abcb5d9'},
}
BUILD_OVERRIDE_NAMES=frozenset(('CL','_CL_','LINK','_LINK_','CCC_OVERRIDE_OPTIONS','CCC_ADD_ARGS',
                              'CLANG_CONFIG_FILE_SYSTEM_DIR','CLANG_CONFIG_FILE_USER_DIR'))

def build_environment(environment: dict[str,str]) -> tuple[dict[str,str],list[str]]:
    """Keep SDK discovery inputs; prevent ambient flags/config from changing commands."""
    removed=sorted(name for name in environment if name.upper() in BUILD_OVERRIDE_NAMES)
    return {name:value for name,value in environment.items() if name not in removed},removed

def verify_tool_files(observed: dict|None=None) -> None:
    for role in ('compiler','linker'):
        identity=TOOLCHAIN[role];path=Path(identity['path'])
        actual=({'path':str(path),'bytes':path.stat().st_size,'sha256':sha(path)} if path.is_file()
                else {'path':str(path),'missing':True})
        if observed is not None:observed[role]=actual
        require(actual==identity,'Pinned LLVM '+role+' executable differs or is missing')

def version_command(role: str) -> list[str]:
    require(role in ('compiler','linker'),'Unknown diagnostic tool role')
    return [TOOLCHAIN[role]['path'],*(['--no-default-config'] if role=='compiler' else []),'--version']

def verify_tool_version(role: str, log: str) -> None:
    lines=log.splitlines()
    prefix='clang version ' if role=='compiler' else 'LLD '
    require(lines and re.fullmatch(re.escape(prefix+TOOLCHAIN['version'])+r'(?: \([^\r\n]*\))?',lines[0]) is not None,
            'Pinned LLVM '+role+' version differs')
    if role=='compiler':
        require('Target: x86_64-pc-windows-msvc' in lines,'LLVM compiler target differs')

def version_identity(role: str) -> dict:
    return {'stage':'version','role':role,'toolchain':TOOLCHAIN}

def build_control_command(python: str, mode: str) -> list[str]:
    require(mode in BUILD_CONTROL_MODES,'Unknown build ownership control')
    if mode=='nonzero':
        script='import sys; print("OWNED_NONZERO", flush=True); sys.exit(19)'
    else:
        delay=SLOW_CONTROL_SECONDS if mode in ('orphan-hang','slow-child','late-child-failure') else .4
        child=('import os,sys,time; print("OWNED_CHILD " + str(os.getpid()), flush=True); '
               'time.sleep('+str(delay)+'); sys.exit('+('19' if mode=='late-child-failure' else '0')+')')
        script=('import subprocess,sys,time; p=subprocess.Popen([sys.executable,"-c",'+repr(child)+'],creationflags=subprocess.DETACHED_PROCESS, '
                'stdin=sys.stdin,stdout=sys.stdout,stderr=sys.stderr,close_fds=True); '
                'print("OWNED_PARENT_CHILD " + str(p.pid), flush=True); '+
                ('time.sleep(0.2)' if mode=='orphan-hang' else 'sys.exit(p.wait())'))
    return [python,'-c',script]

def build_control_identity(python: dict, mode: str) -> dict:
    return {'kind':'actual-windows-owned-process-control','mode':mode,'python':python}

def verify_build_control(mode: str, result: dict, log: str) -> None:
    require(mode in BUILD_CONTROL_MODES,'Unknown build ownership control')
    require(result['timeout_seconds']==(policy.ORPHAN_CONTROL_SECONDS if mode=='orphan-hang' else policy.OPERATION_SECONDS),
            'Build ownership control watchdog differs from policy')
    require(result['job_joined'] is True and result['error'] is None,'Build ownership control did not join')
    if mode=='nonzero':
        require(result['status']=='failed' and result['root_exit']==19 and not result['timed_out']
                and not result['termination_requested'] and 'OWNED_NONZERO' in log,'Build nonzero-exit control failed')
        return
    pids=re.findall(r'^OWNED_PARENT_CHILD ([0-9]+)$',log,re.M)
    require(len(pids)==1,'Build child PID control output missing')
    child=int(pids[0]);last=result['samples'][-1]
    require(last['total_processes']==2,'Build ownership control requires exactly two processes')
    require(child!=result['root_pid']
            and any(child in [row['pid'] for row in sample['active_observed']] for sample in result['samples']),
            'Build child was not observed inside its owned job')
    executed=re.findall(r'^OWNED_CHILD ([0-9]+)$',log,re.M)
    require(len(executed)==1,'Build child execution marker missing or duplicated')
    require(int(executed[0])==child,'Build child execution marker PID mismatch')
    exits={row['pid']:row['exit_code'] for row in last['exited_observed']}
    root_exit=19 if mode=='late-child-failure' else 0
    child_exit=124 if mode=='orphan-hang' else root_exit
    require(result['root_exit']==root_exit and exits.get(child)==child_exit,
            'Build child actual termination code mismatch')
    require(result['timed_out']==(mode=='orphan-hang') and result['termination_requested']==(mode=='orphan-hang')
            and result['status']==('failed' if mode in ('orphan-hang','late-child-failure') else 'passed'),
            'Build child-hang or late-exit control failed')
    if mode in ('slow-child','late-child-failure'):
        require(result['seconds']>=SLOW_CONTROL_SECONDS and last['seconds']>=SLOW_CONTROL_SECONDS
                and result['timeout_seconds']==policy.OPERATION_SECONDS,
                'Slow build control did not execute beyond the former watchdog')

def run_build_controls(output: Path, environment: dict) -> dict:
    python={'path':str(Path(sys.executable).resolve()),'sha256':sha(Path(sys.executable)),
            'bytes':Path(sys.executable).stat().st_size}
    results={}
    receipt={'python':python,'results':results}
    write(output/'build-ownership-controls.json',receipt)
    for mode in BUILD_CONTROL_MODES:
        command=build_control_command(python['path'],mode)
        directory=output/('build-control-'+mode)
        identity=build_control_identity(python,mode)
        actual=owned_build.run(command,ROOT,environment,directory,identity,
                               timeout=policy.ORPHAN_CONTROL_SECONDS if mode=='orphan-hang' else policy.OPERATION_SECONDS)
        results[mode]=actual
        write(output/'build-ownership-controls.json',receipt)
        reduced=owned_build.verify(directory,command,identity,cwd=str(ROOT))
        require(reduced==actual,'Build ownership control reduction differs')
        verify_build_control(mode,reduced,(directory/'process.log').read_text())
    return receipt

def write(path: Path, value) -> None:
    path.write_text(json.dumps(value,indent=2,sort_keys=True)+'\n',encoding='utf-8')

def git(root: Path,*args: str,input: bytes|None=None) -> bytes:
    return subprocess.run(['git','-C',str(root),*args],input=input,stdout=subprocess.PIPE,stderr=subprocess.PIPE,
                          timeout=policy.OPERATION_SECONDS,check=True).stdout

def in_scope(path: str) -> bool:
    # Same portable import-bootstrap exclusion as the ordinary Windows runner.
    return not path.startswith('godot/.godot/') and any(path==scope or path.startswith(scope.rstrip('/')+'/') for scope in SCOPES)

def tree_entries(root: Path, revision: str) -> list[tuple[str,str,str,str]]:
    result=[]
    for row in git(root,'ls-tree','-r','-t','-z',revision).split(b'\0'):
        if row:
            header,path=row.split(b'\t',1); mode,kind,oid=header.decode().split()
            result.append((mode,kind,oid,path.decode('utf-8')))
    return result

def blobs(root: Path, objects: dict[str,str]) -> dict[str,bytes]:
    """One bounded Git process, with exact ordered object/size parsing."""
    data=git(root,'cat-file','--batch',input=''.join(oid+'\n' for oid in objects.values()).encode())
    result={};cursor=0
    for path,oid in objects.items():
        end=data.find(b'\n',cursor);require(end>=cursor,'Missing Git batch header')
        header=data[cursor:end].decode().split()
        require(len(header)==3 and header[:2]==[oid,'blob'],'Git batch object identity mismatch')
        length=int(header[2]);cursor=end+1
        require(length>=0 and cursor+length<len(data) and data[cursor+length:cursor+length+1]==b'\n','Truncated Git batch object')
        result[path]=data[cursor:cursor+length];cursor+=length+1
    require(cursor==len(data),'Unexpected Git batch object tail')
    return result

def verify_source_pack(output: Path, source: dict, expected: str) -> dict[str,bytes]:
    require(re.fullmatch(r'[0-9a-f]{40}',expected) is not None,'Expected source must be a full SHA')
    require(source['commit']==expected and sha(output/'source.pack')==source['pack_sha256']
            and (output/'source.pack').stat().st_size==source['pack_bytes'],'Source pack identity mismatch')
    with tempfile.TemporaryDirectory(prefix='play-crash-source-') as temporary:
        repository=Path(temporary)/'git'
        git(Path(temporary),'init','--bare','-q',str(repository))
        git(repository,'index-pack','--stdin',input=(output/'source.pack').read_bytes())
        require(git(repository,'rev-parse',expected+'^{tree}').decode().strip()==source['tree'],'Source commit/tree proof mismatch')
        require(git(repository,'cat-file','commit',expected)==(output/'source.commit').read_bytes(),'Original source commit object mismatch')
        require(source['unchanged_runtime_base']==BASE and not git(repository,'diff','--name-only',BASE,expected,'--',*PROTECTED).strip(),
                'Original failing fixture/production/runtime changed in diagnostic source')
        entries=tree_entries(repository,expected)
        selected={path:oid for _mode,kind,oid,path in entries if kind=='blob' and in_scope(path)}
        require(set(selected)==set(source['inputs']),'Complete scoped source inventory mismatch')
        canonical=blobs(repository,selected)
        for path,oid in selected.items():
            record=source['inputs'][path]
            blob=canonical[path]
            require(record['git_blob']==oid and hashlib.sha256(blob).hexdigest()==record['canonical_sha256'],
                    'Source blob proof mismatch: '+path)
            pointer=re.fullmatch(rb'version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n',blob)
            if path in (windows.NATIVE,windows.RAPIER):
                require(pointer is not None and record['working_sha256']==pointer[1].decode()
                        and record['working_bytes']==int(pointer[2]),'Selected runtime contradicts committed LFS identity')
            else:
                # Checkout pins core.eol=lf. Only explicit committed Windows
                # launch-script rules export CRLF; all other bytes stay exact.
                expected_bytes=blob.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n') if path.endswith(('.bat','.ps1')) else blob
                require(record['working_sha256']==hashlib.sha256(expected_bytes).hexdigest()
                        and record['working_bytes']==len(expected_bytes),'Working source bytes mismatch: '+path)
        return canonical

def source_archive(output: Path, expected: str) -> dict:
    require(re.fullmatch(r'[0-9a-f]{40}',expected) is not None,'Expected source must be a full SHA')
    require(git(ROOT,'rev-parse','HEAD').decode().strip()==expected,'Wrong source HEAD')
    require(not git(ROOT,'status','--porcelain=v1','--untracked-files=all').strip(),'Source checkout is not clean before import')
    require(not git(ROOT,'diff','--name-only',BASE,'HEAD','--',*PROTECTED).strip(),'Original failed fixture/production/runtime/gates changed')
    tree=git(ROOT,'rev-parse','HEAD^{tree}').decode().strip()
    entries=tree_entries(ROOT,'HEAD'); inputs={}; objects={expected,tree,BASE,git(ROOT,'rev-parse',BASE+'^{tree}').decode().strip()}
    objects.update(oid for _mode,kind,oid,_path in tree_entries(ROOT,BASE) if kind=='tree')
    selected=blobs(ROOT,{path:oid for _mode,kind,oid,path in entries if kind=='blob' and in_scope(path)})
    for _mode,kind,oid,path in entries:
        if kind=='tree': objects.add(oid)
        elif kind=='blob' and in_scope(path):
            objects.add(oid); canonical=selected[path]; working=(ROOT/path).read_bytes()
            inputs[path]={'git_blob':oid,'canonical_sha256':hashlib.sha256(canonical).hexdigest(),
                          'working_sha256':hashlib.sha256(working).hexdigest(),'working_bytes':len(working)}
    require(not any((output/name).exists() for name in ('source.commit','source.pack','source.pack.pending')),
            'Refusing to overwrite original source evidence')
    with (output/'source.commit').open('xb') as stream:stream.write(git(ROOT,'cat-file','commit',expected))
    pending=output/'source.pack.pending'
    with pending.open('xb') as stream:
        subprocess.run(['git','-C',str(ROOT),'pack-objects','--stdout','--no-reuse-delta','--no-reuse-object'],
                       input=''.join(oid+'\n' for oid in sorted(objects)).encode(),stdout=stream,stderr=subprocess.PIPE,
                       timeout=policy.OPERATION_SECONDS,check=True)
        stream.flush();os.fsync(stream.fileno())
    pending.replace(output/'source.pack')
    source={'commit':expected,'tree':tree,'unchanged_runtime_base':BASE,'scopes':list(SCOPES),'inputs':inputs,
            'pack_sha256':sha(output/'source.pack'),'pack_bytes':(output/'source.pack').stat().st_size,
            'archive_scope':'Exact commit, all tree objects and complete scoped blobs; unselected documentation blobs/history and LFS payloads are deliberately absent.'}
    verify_source_pack(output,source,expected)
    return source

def source_unchanged(source: dict) -> None:
    require(git(ROOT,'rev-parse','HEAD').decode().strip()==source['commit'],'Source HEAD changed')
    for path,record in source['inputs'].items():
        data=(ROOT/path).read_bytes()
        if path in windows.RAPIER_IMPORT_DESCRIPTORS: data=data.replace(b'\r\n',b'\n')
        require(hashlib.sha256(data).hexdigest()==record['working_sha256'],'Executed input changed: '+path)

def execute(broker: Path, command: list[str], output: Path, timeout_ms: int, environment: dict,
            images: dict, runtimes: dict, *, dump_timeout_control=False) -> dict:
    output.mkdir(exist_ok=False)
    broker_command=[str(broker),'--output',str(output),'--timeout-ms',str(timeout_ms),'--',*command]
    started=time.perf_counter(); outer_timeout=False
    with (output/'broker.log').open('wb') as log:
        process=subprocess.Popen(broker_command,cwd=ROOT,env=environment,stdout=log,stderr=subprocess.STDOUT,
                                 creationflags=subprocess.CREATE_NEW_PROCESS_GROUP)
        try: process.wait(timeout=timeout_ms/1000+policy.CLEANUP_SECONDS)
        except subprocess.TimeoutExpired:
            outer_timeout=True
            # Broker debug ownership kills its remaining debuggees on exit.
            process.kill();process.wait(timeout=policy.CLEANUP_SECONDS)
    receipt={'broker_command':broker_command,'debuggee_command':command,'broker_pid':process.pid,
             'returncode':process.returncode,'timeout_ms':timeout_ms,'outer_timeout':outer_timeout,
             'wall_seconds':time.perf_counter()-started}
    write(output/'process.json',receipt)
    events=read_events(output/'events.jsonl')
    identities=read_load_identities(output,events)
    write(output/'module-identities.json',identities)
    result=verify_dump_timeout_control(events,receipt) if dump_timeout_control else verify_capture(output,events,receipt)
    result['module_bindings']=verify_module_bindings(events,receipt,identities,images,runtimes,result,root=output)
    write(output/'verified.json',result)
    return result

def runtime_proof(source: dict, canonical: dict[str,bytes], runtime: dict) -> None:
    """Recheck retained runtime receipts against authenticated source bytes offline."""
    native=json.loads(canonical[windows.PROVENANCE])
    suffixes={'.c','.cc','.cpp','.cxx','.h','.hh','.hpp','.hxx','.inc','.inl','.tpp'}
    native_paths={path for path in canonical if path.startswith(('native/include/','native/src/','godot/native_extension/'))
                  and Path(path).suffix in suffixes}
    require(native_paths and set(native['source_inputs'])==native_paths,'Native provenance source inventory mismatch')
    require(all(native['source_inputs'][path]==hashlib.sha256(canonical[path].replace(b'\r\n',b'\n')).hexdigest()
                for path in native_paths),'Native runtime source provenance is stale')
    require(runtime['runtime_source_commit']==native['source_commit'] and runtime['runtime_build_commit']==native['build_commit']
            and runtime['native_source_inputs']==native['source_inputs']
            and runtime['runtime_provenance']=={'path':windows.PROVENANCE,'sha256':hashlib.sha256(canonical[windows.PROVENANCE]).hexdigest()},
            'Native runtime receipt contradicts source-bound provenance')
    for path,key in ((windows.NATIVE,'cybersand_runtime'),(windows.RAPIER,'rapier_runtime')):
        expected=source['inputs'][path]
        require(runtime[key]=={'path':path,'sha256':expected['working_sha256'],'size':expected['working_bytes']},
                'Runtime receipt contradicts committed LFS bytes')
    require(native['artifact']==windows.NATIVE and native['sha256']==runtime['cybersand_runtime']['sha256']
            and native['size']==runtime['cybersand_runtime']['size'],'Native publication artifact mismatch')
    # Reuse the current dependency verifier on authenticated canonical files.
    # Its pointer-aware checks intentionally do not require unselected Linux bytes.
    from check_repository import verify_rapier_overrides
    lock=json.loads(canonical['godot/third_party/rapier2d.lock.json'])
    manifests=[json.loads(canonical[path]) for path in lock['runtime_overrides'].values()]
    paths={'third_party/rapier-bvh-build.lock.json'}
    for manifest in manifests:paths.update(manifest['source_inputs']);paths.add(manifest['artifact'])
    paths.update(lock['runtime_overrides'].values())
    with tempfile.TemporaryDirectory(prefix='play-crash-runtime-') as temporary:
        directory=Path(temporary)
        for path in paths:
            target=directory/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(canonical[path])
        errors=verify_rapier_overrides(directory,lock)
        require(not errors,'Rapier canonical provenance failed: '+'; '.join(errors))
    require(runtime['rapier_runtime']['sha256']==windows.RAPIER_SHA256,'Selected Rapier pin changed')

def bindings(report: dict, *, controls=False) -> tuple[dict,dict]:
    if controls:
        tool=report['tools']['control']
        return {tool['path']:{'sha256':tool['sha256'],'bytes':tool['bytes']}},{}
    directory=ntpath.join(report['paths']['output'],'engine')
    images={ntpath.join(directory,name):identity|{'requires_runtime':not name.endswith('_console.exe')}
            for name,identity in ENGINE_FILES.items()}
    runtimes={ntpath.join(report['paths']['source'],path.replace('/','\\')):
              {'sha256':report['source']['inputs'][path]['working_sha256'],'bytes':report['source']['inputs'][path]['working_bytes']}
              for path in (windows.NATIVE,windows.RAPIER)}
    return images,runtimes

def engine(archive: Path, output: Path, environment: dict) -> tuple[Path,dict]:
    require(archive.stat().st_size==ENGINE_ARCHIVE_BYTES and hashlib.sha512(archive.read_bytes()).hexdigest()==windows.GODOT_SHA512,'Godot archive pin mismatch')
    members=tuple(ENGINE_FILES)
    directory=output/'engine'; directory.mkdir()
    binaries={}
    with zipfile.ZipFile(archive) as bundle:
        require(bundle.testzip() is None,'Engine ZIP CRC failure')
        for name in members:
            require(bundle.namelist().count(name)==1,'Engine member inventory mismatch')
            bundle.extract(name,directory);path=directory/name
            binaries[name]={'sha256':sha(path),'bytes':path.stat().st_size}
    require(binaries==ENGINE_FILES,'Extracted official engine identity mismatch')
    console=directory/members[1]
    version=subprocess.run([str(console),'--version'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
                           env=environment,timeout=policy.OPERATION_SECONDS,check=True).stdout
    (output/'version.log').write_bytes(version)
    require(version.decode().strip()==windows.GODOT_VERSION,'Actual engine version mismatch')
    return console,{'version':windows.GODOT_VERSION,'archive_sha512':windows.GODOT_SHA512,
                    'archive_bytes':archive.stat().st_size,'executables':binaries}

def compile_command(source: str, obj: str, extension: str) -> list[str]:
    command=[TOOLCHAIN['compiler']['path'],'--no-default-config','--target=x86_64-pc-windows-msvc',
             '/nologo','/showIncludes','/Od','/W4','/WX','/Z7','/MT','/c',source,'/Fo:'+obj]
    if extension=='cpp':
        command+=['/std:c++17','/EHsc',
                  '/DCYBERSAND_CRASH_CAPTURE_LIMIT_MS='+str(policy.CAPTURE_MS),
                  '/DCYBERSAND_CRASH_MAX_CASE_MS='+str(policy.FIXTURE_MS)]
    return command

def link_command(obj: str, binary: str, pdb: str, extension: str) -> list[str]:
    command=[TOOLCHAIN['linker']['path'],'/NOLOGO','/WX','/MACHINE:X64','/SUBSYSTEM:CONSOLE',
             '/DEBUG:FULL','/OUT:'+binary,'/PDB:'+pdb,obj,'kernel32.lib']
    if extension=='cpp':command+=['Dbghelp.lib','Bcrypt.lib']
    return command

def build_identity(stage: str, source: str, source_sha256: str, *, obj: dict|None=None) -> dict:
    require(stage in ('compile','link') and (obj is not None)==(stage=='link'),'Unknown diagnostic build phase')
    identity={'stage':stage,'source':source,'source_sha256':source_sha256,'toolchain':TOOLCHAIN}
    if obj is not None:identity['object']=obj
    return identity

def retained_identity(path: Path) -> dict:
    require(path.is_file() and path.stat().st_size>0,'Diagnostic output missing: '+path.name)
    return {'sha256':sha(path),'bytes':path.stat().st_size}

def run_tool_operation(directory: Path, environment: dict, record: dict, row: dict) -> None:
    """Seal failure before raising; an exit-zero root cannot hide any owned child."""
    write(directory/'build.json',record)
    operation=directory/row['operation']
    try:
        row['result']=owned_build.run(row['command'],directory,environment,operation,row['identity'])
        require(row['result']['status']=='passed',
                'LLVM diagnostic '+row['identity']['stage']+' failed or timed out; original operation evidence retained')
        require(owned_build.verify(operation,row['command'],row['identity'],cwd=str(directory))==row['result'],
                'Build process reduction differs')
        verify_complete_tool_exits(row['result'])
        verify_tool_files(record['observed_tools'])
        row['status']='passed'
    except (OSError,ValueError) as error:
        row.update(status='failed',error=str(error))
        raise
    finally:
        write(directory/'build.json',record)

def probe_toolchain(directory: Path, environment: dict, record: dict) -> None:
    for role in ('compiler','linker'):
        row={'command':version_command(role),'identity':version_identity(role),
             'operation':role+'-version-operation','status':'pending_owned_operation'}
        record['probes'].append(row)
        run_tool_operation(directory,environment,record,row)
        verify_tool_version(role,(directory/row['operation']/'process.log').read_text(encoding='utf-8'))

def build_tools(output: Path, environment: dict) -> tuple[Path,Path,dict]:
    directory=output/'tools';directory.mkdir()
    environment,removed=build_environment(environment)
    record={'schema':'play-windows-diagnostic-build-v2','toolchain':TOOLCHAIN,
            'observed_tools':{},
            'removed_override_names':removed,
            'sdk_environment':{name:value for name,value in environment.items()
                if name.upper() in ('INCLUDE','LIB','LIBPATH','VCTOOLSVERSION','WINDOWSSDKVERSION')},
            'probes':[],'builds':[]}
    write(directory/'build.json',record)
    try:verify_tool_files(record['observed_tools'])
    finally:write(directory/'build.json',record)
    probe_toolchain(directory,environment,record)
    targets=[]
    for name,extension in (('windows_crash_debugger','cpp'),('windows_crash_control','c')):
        source=ROOT/'tools/play'/f'{name}.{extension}';binary=directory/(name+'.exe')
        obj=directory/(name+'.obj');pdb=directory/(name+'.pdb')
        target={'source':source.relative_to(ROOT).as_posix(),'source_sha256':sha(source),'phases':[],
                'status':'pending_owned_operation'}
        record['builds'].append(target)
        for stage in ('compile','link'):
            command=(compile_command(str(source),str(obj),extension) if stage=='compile'
                     else link_command(str(obj),str(binary),str(pdb),extension))
            identity=build_identity(stage,target['source'],target['source_sha256'],
                                    obj=target.get('object') if stage=='link' else None)
            row={'command':command,'identity':identity,'operation':name+'-'+stage+'-operation',
                 'status':'pending_owned_operation'}
            target['phases'].append(row)
            run_tool_operation(directory,environment,record,row)
            require(sha(source)==target['source_sha256'],'Diagnostic source changed during build')
            if stage=='compile':target['object']=retained_identity(obj)
            else:
                require(retained_identity(obj)==target['object'],'Diagnostic object changed while linking')
                target.update(binary=retained_identity(binary),pdb=retained_identity(pdb),status='passed')
            write(directory/'build.json',record)
        targets.append(binary)
    return targets[0],targets[1],record

def verify_manifest(output: Path) -> dict:
    manifest=read_json(output/'MANIFEST.json')
    paths={path.relative_to(output).as_posix() for path in output.rglob('*')
           if path.is_file() and path.relative_to(output).parts[0]!='engine' and path!=output/'MANIFEST.json'}
    require(set(manifest)==paths,'Complete diagnostic manifest inventory mismatch')
    for relative,expected in manifest.items():
        path=safe_file(output,relative)
        require({'sha256':sha(path),'bytes':path.stat().st_size}==expected,'Diagnostic artifact digest mismatch: '+relative)
    return manifest

def verify_complete_tool_exits(result: dict) -> None:
    last=result['samples'][-1]
    require(last['total_processes']==len({process['pid'] for process in last['exited_observed']}),
            'LLVM operation has an unobserved process exit')

def verify_tool_operation(directory: Path, row: dict, command: list[str], identity: dict, cwd: str) -> None:
    require(row['command']==command and row['identity']==identity,
            'Original build command/source identity mismatch')
    reduced=owned_build.verify(directory/row['operation'],command,identity,cwd=cwd)
    require(row['status']=='passed' and reduced==row['result'] and reduced['status']=='passed'
            and reduced['timeout_seconds']==policy.OPERATION_SECONDS,
            'Original build ownership/deadline reduction mismatch')
    verify_complete_tool_exits(reduced)

def verify_build_record(output: Path, report: dict, canonical: dict[str,bytes]) -> None:
    record=report['build']
    require(record==read_json(output/'tools/build.json') and record['schema']=='play-windows-diagnostic-build-v2',
            'Build receipt mismatch')
    require(record['toolchain']==TOOLCHAIN,'Pinned LLVM toolchain receipt differs from source')
    require(record['observed_tools']=={role:TOOLCHAIN[role] for role in ('compiler','linker')},
            'Observed LLVM tool files differ from source pins')
    require(isinstance(record['removed_override_names'],list)
            and all(isinstance(name,str) and name.upper() in BUILD_OVERRIDE_NAMES for name in record['removed_override_names']),
            'Compiler override sanitation receipt differs')
    require(isinstance(record['sdk_environment'],dict)
            and all(isinstance(name,str) and isinstance(value,str)
                    and name.upper() in ('INCLUDE','LIB','LIBPATH','VCTOOLSVERSION','WINDOWSSDKVERSION')
                    for name,value in record['sdk_environment'].items()),'SDK environment inventory differs')
    directory=output/'tools';tools_path=ntpath.join(report['paths']['output'],'tools')
    require(len(record['probes'])==2,'Complete LLVM version probe inventory required')
    for role,row in zip(('compiler','linker'),record['probes']):
        require(row['operation']==role+'-version-operation','LLVM version probe identity differs')
        verify_tool_operation(directory,row,version_command(role),version_identity(role),tools_path)
        verify_tool_version(role,(directory/row['operation']/'process.log').read_text(encoding='utf-8'))
    require(len(record['builds'])==2 and set(report['tools'])=={'broker','control'},'Diagnostic tool inventory mismatch')
    for role,name,extension in (('broker','windows_crash_debugger','cpp'),('control','windows_crash_control','c')):
        source_path='tools/play/'+name+'.'+extension
        source_sha256=hashlib.sha256(canonical[source_path]).hexdigest()
        rows=[row for row in record['builds'] if row['source']==source_path]
        require(len(rows)==1,'Diagnostic source build inventory differs')
        target=rows[0]
        require(target['source_sha256']==source_sha256 and target['status']=='passed','Diagnostic source build did not complete')
        for key,suffix in (('binary','.exe'),('object','.obj'),('pdb','.pdb')):
            require(target[key]==retained_identity(safe_file(output,'tools/'+name+suffix)),
                    'Retained diagnostic '+key+' differs from build')
        require(report['tools'][role]=={'path':ntpath.join(tools_path,name+'.exe'),**target['binary']},
                'Retained diagnostic executable differs from original tool receipt')
        require(len(target['phases'])==2,'Complete compile and link phase inventory required')
        source=ntpath.join(report['paths']['source'],source_path.replace('/','\\'))
        obj=ntpath.join(tools_path,name+'.obj');binary=ntpath.join(tools_path,name+'.exe');pdb=ntpath.join(tools_path,name+'.pdb')
        for stage,row in zip(('compile','link'),target['phases']):
            require(row['operation']==name+'-'+stage+'-operation','Original build phase identity differs')
            command=compile_command(source,obj,extension) if stage=='compile' else link_command(obj,binary,pdb,extension)
            identity=build_identity(stage,source_path,source_sha256,obj=target['object'] if stage=='link' else None)
            verify_tool_operation(directory,row,command,identity,tools_path)

def verify_directory(output: Path, expected: str) -> dict:
    """Read original artifacts offline, preserving failure as failure."""
    verify_manifest(output)
    report=read_json(output/'campaign.json')
    require(report['schema']=='play-windows-crash-campaign-v6' and report['completed'] is True
            and report['errors']==[] and report['fixture_attempts']==1,'Diagnostic campaign is incomplete')
    require(report['original_failed_run']==41175131563 and report['original_failed_source']==BASE
            and report['original_failure_still_blocking'] is True,'Original failure provenance was rewritten')
    require(report['watchdog_policy']==policy.POLICY,'Diagnostic watchdog policy differs from source')
    require(report.get('dump_format')==DUMP_FORMAT,'Diagnostic dump format differs from source')
    canonical=verify_source_pack(output,report['source'],expected)
    runtime_proof(report['source'],canonical,report['runtime'])
    controls=report['build_ownership_controls']
    require(set(controls['results'])==set(BUILD_CONTROL_MODES),'Complete build ownership control inventory')
    require(controls==read_json(output/'build-ownership-controls.json'),'Original build ownership control receipt differs')
    for mode in BUILD_CONTROL_MODES:
        directory=output/('build-control-'+mode)
        reduced=owned_build.verify(directory,build_control_command(controls['python']['path'],mode),
                                   build_control_identity(controls['python'],mode),cwd=report['paths']['source'])
        require(reduced==controls['results'][mode],'Build ownership control original reduction mismatch')
        verify_build_control(mode,reduced,(directory/'process.log').read_text())
    require(report['engine']=={'version':windows.GODOT_VERSION,'archive_sha512':windows.GODOT_SHA512,
                              'archive_bytes':ENGINE_ARCHIVE_BYTES,'executables':ENGINE_FILES},'Engine receipt differs from official pin')
    require((output/'version.log').read_text(encoding='utf-8').strip()==windows.GODOT_VERSION,'Original version log mismatch')
    verify_build_record(output,report,canonical)
    require(set(report['controls'])==set(CONTROL_MODES)|{'dump-writer-timeout'},'Complete diagnostic control inventory mismatch')
    results={}
    for name in (*('control-'+mode for mode in CONTROL_MODES),'control-dump-writer-timeout','import',FIXTURE):
        directory=output/name;receipt=read_json(directory/'process.json');events=read_events(directory/'events.jsonl')
        control=name.startswith('control-');mode=name.removeprefix('control-')
        limit=policy.case_limit_ms(name,FIXTURE)
        command=([report['tools']['control']['path'],'crash' if mode=='dump-writer-timeout' else mode] if control else
                 [ntpath.join(report['paths']['output'],'engine','Godot_v4.7-stable_win64_console.exe'),
                  '--headless','--path',ntpath.join(report['paths']['source'],'godot'),
                  *(['--editor','--quit'] if name=='import' else ['--script','res://tests/'+FIXTURE+'.gd'])])
        require(receipt['timeout_ms']==limit and receipt['debuggee_command']==command,'Original process command/deadline differs from prescribed attempt')
        expected_broker=[report['tools']['broker']['path'],'--output',ntpath.join(report['paths']['output'],name),
                         '--timeout-ms',str(limit),'--',*command]
        require(receipt['broker_command']==expected_broker,'Original broker executable/arguments mismatch')
        result=(verify_dump_timeout_control(events,receipt) if mode=='dump-writer-timeout' else verify_capture(directory,events,receipt))
        result['module_bindings']=verify_module_bindings(events,receipt,read_json(directory/'module-identities.json'),
                                                        *bindings(report,controls=control),result,root=directory)
        require(result==read_json(directory/'verified.json'),'Reduced process evidence differs from original verification')
        expected_result=report['controls'][mode] if control else report[name if name=='import' else 'fixture']
        require(result==expected_result,'Campaign reduction differs from raw process evidence')
        if mode in CONTROL_MODES:verify_control(mode,result)
        if control:
            log=(directory/'engine.log').read_text(errors='replace')
            require(log.count('CRASH_CONTROL_READY')==(2 if mode=='child-crash' else 1)
                    and ('CRASH_CONTROL_HANDLED' in log)==(mode=='handled'),'Actual injected control markers did not match selected mode')
        results[name]=result
    require(results['import']['effective_exit']==0 and not results['import']['timed_out'],'Import is not qualified')
    import_log=(output/'import/engine.log').read_text(errors='replace')
    require(not re.search(r'SCRIPT ERROR:|ERROR:|\bskipped\b|^\s*SKIP\b',import_log,re.M|re.I),'Import strict diagnostics did not pass')
    fixture=results[FIXTURE];log=(output/FIXTURE/'engine.log').read_text(errors='replace')
    status='observed_process_failure' if fixture['effective_exit'] or fixture['timed_out'] else 'no_process_failure_observed'
    footer='LIQUID_DESKTOP_DEFAULT_HOST: 86 assertions; 0 failures' in log
    require(report['assertion_footer_present']==footer,'Original fixture assertion footer receipt differs')
    if status=='no_process_failure_observed':
        require(footer and not re.search(r'SCRIPT ERROR:|ERROR:|\bskipped\b|^\s*SKIP\b',log,re.M|re.I),
                'Original fixture assertions/strict diagnostics incomplete')
    require(report['status']==status,'Actual nonzero process result was relabelled')
    return {'verified':True,'source_commit':expected,'source_tree':report['source']['tree'],
            'status':status,'effective_exit':fixture['effective_exit'],'captured_exception_count':len(fixture['captures']),
            'assertion_footer_present':footer,'original_failure_still_blocking':True}

def seal(output: Path, report: dict) -> None:
    write(output/'campaign.json',report)
    manifest={path.relative_to(output).as_posix():{'sha256':sha(path),'bytes':path.stat().st_size}
              for path in output.rglob('*') if path.is_file() and path.relative_to(output).parts[0]!='engine'
              and path!=output/'MANIFEST.json'}
    write(output/'MANIFEST.json',manifest)

def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--expected-source-sha',required=True)
    parser.add_argument('--godot-archive',type=Path)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--verify',type=Path,help='Verify retained original directory on any OS; never execute or retry')
    args=parser.parse_args()
    if args.verify:
        result=verify_directory(args.verify.resolve(),args.expected_source_sha);print(json.dumps(result,indent=2))
        return 0 if result['status']=='no_process_failure_observed' else 1
    require(args.output is not None and args.godot_archive is not None,'Execution requires --output and --godot-archive')
    require(sys.platform=='win32' and platform.machine().lower()=='amd64','Actual x86_64 Windows required')
    require(os.environ.get('GITHUB_RUN_ATTEMPT','1')=='1','Automatic reruns are not authorized by this one-attempt diagnostic')
    output=args.output.resolve(); require(not output.exists(),'Retain earlier evidence; output already exists')
    output.mkdir(parents=True)
    report={'schema':'play-windows-crash-campaign-v6','status':'incomplete','completed':False,'errors':[],
            'watchdog_policy':policy.POLICY,
            'dump_format':DUMP_FORMAT,
            'original_failed_run':41175131563,'original_failed_source':BASE,'original_failure_still_blocking':True,
            'scope':'Opt-in debugger evidence only; one prescribed unchanged-fixture attempt, no automatic retries or integration approval. Build Job accounting establishes containment and final empty-job state; LLVM qualification additionally requires the total process count to equal all distinct observed exits.',
            'run_id':os.environ.get('GITHUB_RUN_ID'),'run_attempt':os.environ.get('GITHUB_RUN_ATTEMPT'),
            'platform':platform.platform(),'controls':{},'fixture_attempts':0,
            'paths':{'source':str(ROOT),'output':str(output)}}
    environment,removed=child_environment(dict(os.environ))
    environment.pop('CYBERSAND_CRASH_DUMP_TIMEOUT_CONTROL',None)
    report['removed_environment_names']=removed
    environment['CYBERSAND_SOURCE_REVISION']=args.expected_source_sha
    try:
        report['source']=source_archive(output,args.expected_source_sha)
        report['runtime']=windows.verify_retained_runtime(ROOT)
        report['build_ownership_controls']=run_build_controls(output,environment)
        broker,control,report['build']=build_tools(output,environment)
        report['tools']={name:{'path':str(path.resolve()),'sha256':sha(path),'bytes':path.stat().st_size}
                         for name,path in [('broker',broker),('control',control)]}
        for mode in CONTROL_MODES:
            result=execute(broker,[str(control),mode],output/('control-'+mode),
                           policy.case_limit_ms('control-'+mode,FIXTURE),environment,*bindings(report,controls=True))
            verify_control(mode,result);report['controls'][mode]=result
            write(output/'campaign.json',report)
        report['controls']['dump-writer-timeout']=execute(broker,[str(control),'crash'],output/'control-dump-writer-timeout',
            policy.DUMP_TIMEOUT_CONTROL_MS,environment|{'CYBERSAND_CRASH_DUMP_TIMEOUT_CONTROL':'1'},*bindings(report,controls=True),dump_timeout_control=True)
        binary,report['engine']=engine(args.godot_archive.resolve(),output,environment)
        imported=execute(broker,[str(binary),'--headless','--path',str(ROOT/'godot'),'--editor','--quit'],
                         output/'import',policy.IMPORT_MS,environment,*bindings(report))
        report['import']=imported
        require(imported['effective_exit']==0 and not imported['timed_out'],'Import did not finish under its execution watchdog')
        require(not re.search(r'SCRIPT ERROR:|ERROR:|\bskipped\b|^\s*SKIP\b',(output/'import/engine.log').read_text(errors='replace'),re.M|re.I),
                'Import strict diagnostics did not pass')
        source_unchanged(report['source'])
        report['fixture_attempts']=1;write(output/'campaign.json',report)
        result=execute(broker,[str(binary),'--headless','--path',str(ROOT/'godot'),'--script','res://tests/'+FIXTURE+'.gd'],
                       output/FIXTURE,policy.FIXTURE_MS,environment,*bindings(report))
        report['fixture']=result
        log=(output/FIXTURE/'engine.log').read_text(errors='replace')
        report['assertion_footer_present']='LIQUID_DESKTOP_DEFAULT_HOST: 86 assertions; 0 failures' in log
        source_unchanged(report['source']);verify_source_pack(output,report['source'],args.expected_source_sha)
        report['status']='observed_process_failure' if result['effective_exit'] or result['timed_out'] else 'no_process_failure_observed'
        if report['status']=='no_process_failure_observed':
            require(report['assertion_footer_present'] and not re.search(r'SCRIPT ERROR:|ERROR:|\bskipped\b|^\s*SKIP\b',log,re.M|re.I),
                    'Fixture assertions/strict diagnostics did not complete')
        report['completed']=True
    except (OSError,RuntimeError,ValueError,KeyError,subprocess.SubprocessError,zipfile.BadZipFile) as error:
        report['status']='failed';report['errors'].append(str(error))
        for name,path in (('build','tools/build.json'),('build_ownership_controls','build-ownership-controls.json')):
            if (output/path).is_file():report[name]=read_json(output/path)
    seal(output,report)
    if report['completed']:
        try:verify_directory(output,args.expected_source_sha)
        except (OSError,RuntimeError,ValueError,KeyError,subprocess.SubprocessError) as error:
            report['status']='failed';report['completed']=False;report['errors'].append('Final original-artifact readback: '+str(error))
            seal(output,report)
    print(json.dumps({k:v for k,v in report.items() if k in ('status','completed','errors','fixture_attempts','original_failure_still_blocking')},indent=2))
    return 0 if report['completed'] and report['status']=='no_process_failure_observed' else 1

if __name__=='__main__':
    raise SystemExit(main())
