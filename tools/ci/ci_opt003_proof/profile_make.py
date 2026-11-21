#!/usr/bin/env python3
"""Proof-only cold Make profiling without editing source, flags or test recipes."""
from __future__ import annotations
import argparse,hashlib,json,os,resource,signal,subprocess,sys,time,shlex
from collections import Counter
from pathlib import Path


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(root,*args):
    return subprocess.check_output(['git',*args],cwd=root,text=True).strip()


def identity(root):
    return {'commit':git(root,'rev-parse','HEAD'),'tree':git(root,'rev-parse','HEAD^{tree}'),
            'tracked_status':git(root,'status','--porcelain','--untracked-files=all'),
            'makefile_sha256':sha(root/'Makefile')}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',required=True,type=Path)
    p.add_argument('--output',required=True,type=Path)
    p.add_argument('--cxx',default='g++-13')
    p.add_argument('--target',choices=['worldgen-test','worldgen-sanitize'],required=True)
    p.add_argument('--jobs',choices=[1,2],default=2,type=int)
    a=p.parse_args();root=a.source.resolve();out=a.output.resolve()
    out.mkdir(parents=True,exist_ok=False)
    before=identity(root)
    if before['tracked_status']:
        raise ValueError('Proof source must have no tracked changes')
    if (root/'build').exists():
        raise ValueError('Cold profile requires an absent build directory')
    here=Path(__file__).resolve().parent
    command=['make','--no-print-directory',f'-j{a.jobs}',
             'CXX='+str(here/'profile_cxx.py'),'SHELL='+str(here/'profile_shell.py'),a.target]
    env=os.environ.copy()
    env.update(CI_OPT003_CXX=a.cxx,CI_OPT003_PROFILE_DIR=str(out/'commands'))
    for key in ('MAKEFLAGS','MFLAGS'):
        env.pop(key,None)
    data={'schema':'cybersand-ci-opt003-make-profile-v1','source_before':before,'command':command,
          'compiler_version':subprocess.check_output([a.cxx,'--version'],text=True).splitlines()[0],
          'sanitizer_environment':{k:env.get(k) for k in ('ASAN_OPTIONS','UBSAN_OPTIONS')},
          'instrumentation_sha256':{f.name:sha(f) for f in (here/'profile_make.py',here/'profile_cxx.py',here/'profile_shell.py')},
          'status':'started','start_time_ns':time.time_ns()}
    (out/'profile.json').write_text(json.dumps(data,indent=2)+'\n')
    start=time.monotonic_ns()
    with (out/'stdout.log').open('w') as log,(out/'lines.jsonl').open('w') as lines:
        proc=subprocess.Popen(command,cwd=root,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
        assert proc.stdout is not None
        for line in proc.stdout:
            now=time.time_ns()
            log.write(line);log.flush()
            lines.write(json.dumps({'time_ns':now,'line':line.rstrip('\n')})+'\n');lines.flush()
            print(line,end='',flush=True)
        rc=proc.wait()
    data.update(status='passed' if rc==0 else 'failed',returncode=rc,
                end_time_ns=time.time_ns(),elapsed_seconds=(time.monotonic_ns()-start)/1e9,
                source_after=identity(root))
    if data['source_after']!=before:
        data.update(status='failed',source_error='tracked source changed during profile')
        rc=125
    commands=[]
    for f in sorted((out/'commands').glob('*.json')):
        row=json.loads(f.read_text());commands.append(row)
        if row.get('status')!='passed':
            data.update(status='failed',command_error='incomplete or failed instrumented command')
            rc=rc or 125
    data['compiler_command_count']=sum(r['kind']=='compiler' for r in commands)
    data['shell_command_count']=sum(r['kind']=='shell' for r in commands)
    # This is additional diagnostic proof, never a substitute for canonical CI.
    # Independently match the unchanged production inventory, not an exit-zero
    # assertion or a nonempty collection of observed commands.
    try:
        sys.path.insert(0,str(root/'tools/ci'))
        import check_worldgen_build_inventory as inventory
        sanitized=a.target=='worldgen-sanitize'
        expected=inventory.expected_commands(sanitized)
        actual=[[inventory.COMPILER,*r['argv'][1:]] for r in commands if r['kind']=='compiler']
        if Counter(map(tuple,actual))!=Counter(map(tuple,expected.values())):
            raise ValueError('Compiler/link receipt inventory differs from original contract')
        test_commands=[]
        for row in sorted(commands,key=lambda r:r['start_time_ns']):
            if row['kind']!='shell': continue
            command=shlex.split(row['argv'][-1])
            if command and (command[0].startswith('./build/test_') or command[0]=='set'):
                test_commands.append(command)
        suffix='_sanitized' if sanitized else ''
        expected_tests=[inventory.showcase_loop(sanitized),*[[f'./build/test_{name}{suffix}'] for name in inventory.TESTS]]
        if test_commands!=expected_tests:
            raise ValueError('Original showcase loop or ordered test receipts are missing/changed')
        if list((out/'commands').glob('*.tmp')):
            raise ValueError('Incomplete command receipt remains')
        data['verified_inventory']={'compiler_commands':actual,'test_commands':test_commands,
                                    'objects':12,'binaries':16,'test_executions':16}
    except (ValueError,KeyError,OSError) as error:
        data.update(status='failed',inventory_error=str(error));rc=rc or 125
    (out/'profile.json').write_text(json.dumps(data,indent=2)+'\n')
    (out/'command-index.json').write_text(json.dumps(commands,indent=2)+'\n')
    print(json.dumps({k:data[k] for k in ('status','elapsed_seconds','returncode','compiler_command_count','shell_command_count')}))
    return rc

if __name__=='__main__':
    raise SystemExit(main())
