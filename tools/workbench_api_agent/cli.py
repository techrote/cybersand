"""CLI for trusted-host configuration, keyless fixtures and explicit live run."""
from __future__ import annotations
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import threading
from urllib.error import HTTPError
from urllib.parse import quote
from urllib.request import Request,build_opener,ProxyHandler

from .config import ConfigError, load_profile, credential
from .controller import trusted_task
from .backend import Workbench,NativeError
from .controller import Runner
from .providers import ScriptedAdapter


def _source_command(command,timeout=8):
    # Windows descendants may retain inherited output handles after Git exits.
    # PIPE communicate() then waits for EOF, even indefinitely during timeout
    # cleanup. Files need no reader threads/EOF; DEVNULL avoids the Godot stdin.
    with tempfile.TemporaryFile() as out,tempfile.TemporaryFile() as err:
        result=subprocess.run(command,stdin=subprocess.DEVNULL,stdout=out,stderr=err,
            timeout=timeout,close_fds=True,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
        out.seek(0);err.seek(0)
        stdout=out.read(65537);stderr=err.read(65537)
    if len(stdout)>65536 or len(stderr)>65536:raise ConfigError('source command output exceeded capacity')
    return subprocess.CompletedProcess(command,result.returncode,
        stdout.decode('utf-8',errors='replace'),stderr.decode('utf-8',errors='replace'))


def git_status()->tuple[str,bool]:
    root=Path(__file__).resolve().parents[2]
    def git(*a):return _source_command(['git','-C',str(root),*a])
    try:
        head=git('rev-parse','HEAD')
        # Godot can rewrite CRLF checkout bytes to their identical HEAD LF
        # content while Git's cached stat size still makes porcelain say M.
        # Compare content, separately retaining staged AND unstaged checks.
        options=('--no-ext-diff','--no-textconv','--ignore-submodules=none','--quiet')
        unstaged=git('diff',*options,'--')
        staged=git('diff','--cached',*options,'HEAD','--')
        after=git('rev-parse','HEAD')
    except (OSError,subprocess.SubprocessError) as exc:
        raise ConfigError('cannot establish source version/cleanliness') from exc
    revision=head.stdout.strip()
    if head.returncode or after.returncode or not re.fullmatch(r'[0-9a-f]{40}|[0-9a-f]{64}',revision) or after.stdout.strip()!=revision or unstaged.returncode not in (0,1) or staged.returncode not in (0,1):
        raise ConfigError('cannot establish stable source version/content cleanliness')
    return revision,unstaged.returncode==1 or staged.returncode==1


def openai_probe(model:str,key:str)->dict:
    # Uncharged model-availability request reused by the Atlas credit gate.
    opener=build_opener(ProxyHandler({}))
    req=Request('https://api.openai.com/v1/models/'+quote(model,safe=''),
                method='GET',headers={'Authorization':'Bearer '+key})
    try:
        with opener.open(req,timeout=8) as response:
            response.read(1024)
            return {'status':response.status,'headers':dict(response.headers)}
    except HTTPError as e:
        return {'status':e.code,'headers':{}}
    except Exception:
        return {'status':503,'headers':{}}


def run(argv:list[str]|None=None)->int:
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='command',required=True)
    dry=sub.add_parser('dry-run',help='Keyless config validation; NO provider/native connections')
    dry.add_argument('--profile',type=Path,required=True)
    dry.add_argument('--task',type=Path,required=True)
    dry.add_argument('--authorization',type=Path,required=True)
    start=sub.add_parser('run',help='Run fixture or explicitly authorised provider on existing World')
    for a in (start,):
        a.add_argument('--profile',type=Path,required=True)
        a.add_argument('--task',type=Path,required=True)
        a.add_argument('--authorization',type=Path,required=True)
        a.add_argument('--base',default='http://127.0.0.1:8765')
        a.add_argument('--token-file',type=Path,required=True)
        a.add_argument('--output',type=Path,required=True)
        a.add_argument('--fixture-script',type=Path,help='Deterministic scripted provider: NOT a model')
        a.add_argument('--allow-live',action='store_true',help='Explicit charge/compute authorization; no implicit key usage')
    stop=sub.add_parser('stop',help='Host-only native Stop; does not invoke a model')
    stop.add_argument('--base',default='http://127.0.0.1:8765')
    stop.add_argument('--token-file',type=Path,required=True)
    stop.add_argument('--request-id',required=True)
    status=sub.add_parser('status',help='Host-only session status; no model')
    status.add_argument('--base',default='http://127.0.0.1:8765')
    status.add_argument('--token-file',type=Path,required=True)
    args=parser.parse_args(argv)
    try:
        if args.command in ('status','stop'):
            wb=Workbench(args.base,args.token_file)
            state=wb.session()
            if args.command=='status':
                print(json.dumps(state,sort_keys=True));return 0
            if not re.fullmatch('[A-Za-z0-9_-]{1,72}',args.request_id):raise ConfigError('invalid Stop request ID')
            if state.get('phase') not in ('ready','stopping'):raise NativeError('session_not_accepting_stop')
            wb.session_id=state['session_id'];wb.generation_id=state['generation_id']
            result=wb.stop(args.request_id,25)
            print(json.dumps({'stop_acknowledged':result['receipt']['status']=='stopped',
                'request_id':args.request_id,'session_id':wb.session_id},sort_keys=True))
            return 0 if result['receipt']['status']=='stopped' else 4
        fixture=args.command=='dry-run' or bool(getattr(args,'fixture_script',None))
        cfg=load_profile(args.profile,fixture_mode=fixture)
        task,auth=trusted_task(args.task,args.authorization)
        if args.command=='dry-run':
            print(json.dumps({'result':'validated_keyless_no_provider_or_native_access',
                              'provider':cfg['provider'],'model':cfg['model'],
                              'limits':cfg['limits'],'task_acceptance':task['acceptance']},sort_keys=True))
            return 0
        if getattr(args,'fixture_script',None):
            if cfg['provider']!='fixture':raise ConfigError('fixture script requires explicit fixture provider profile')
            turns=json.loads(args.fixture_script.read_text(encoding='utf-8'))
            if not isinstance(turns,list) or not 1<=len(turns)<=64:raise ConfigError('invalid fixture turns')
            adapter=ScriptedAdapter(turns)
        else:adapter=None
        if not fixture and not args.allow_live:raise ConfigError('explicit --allow-live required for provider call')
        dirty=False
        if not fixture:
            head,dirty=git_status()
            if dirty:raise ConfigError('tracked source dirty; live gate blocked')
        wb=Workbench(args.base,args.token_file)
        event=threading.Event()
        runner=Runner(cfg,task,auth,wb,args.output,adapter=adapter,fixture_mode=fixture,
                      allow_live=args.allow_live,
                      credit_probe=(lambda m:openai_probe(m,credential(cfg))) if cfg['provider']=='openai_responses' and not fixture else None,
                      stop_event=event,source_dirty=dirty)
        def terminate(_signal,_frame):
            # Starts independent Stop worker immediately, even while provider
            # POST, HTTP native receipt wait or sleep is outstanding.
            runner.request_host_stop_async()
        oldint=signal.signal(signal.SIGINT,terminate)
        oldterm=signal.signal(signal.SIGTERM,terminate)
        try:result=runner.run()
        finally:
            signal.signal(signal.SIGINT,oldint);signal.signal(signal.SIGTERM,oldterm)
        print(json.dumps({'status':result['status'],'reason':result['reason'],
             'receipt':str(args.output/'receipt.json'),
             'native_acceptance':result['native_acceptance']['passed'],
             'stop_acknowledged':result['stop_acknowledged']},sort_keys=True))
        return 0 if result['status']=='passed' else 4
    except (ConfigError,NativeError,ValueError,OSError,KeyError) as e:
        print(json.dumps({'error':getattr(e,'code','run_refused'),
                          'category':type(e).__name__,'charged_provider_requests':'none_if_preflight'},sort_keys=True),file=sys.stderr)
        return 3

if __name__=='__main__':raise SystemExit(run())
