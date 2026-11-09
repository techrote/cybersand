"""JSONL desktop entry point using the SAME provider-neutral Runner as HTTP."""
from __future__ import annotations
import hashlib
import json
import math
import os
import time
from pathlib import Path
import sys
import threading
if __package__ in (None,''):
    sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
    __package__='workbench_api_agent'
from .config import ConfigError,DESKTOP_HARD,load_profile,credential
from .backend import NativeError
from .controller import Runner
from .desktop_backend import DesktopWorkbench
from .providers import ScriptedAdapter,parse_json
from .cli import git_status,openai_probe
from atlas_agent.errors import AgentError
from .boilerplate import from_start
MAX_LINE=32768

class Protocol:
    def __init__(self,output=None):
        self.output=output;self.output_fd=None if output is not None else sys.stdout.fileno()
        self.lock=threading.Lock();self.root=None;self.seq=0;self.total=0;self.secrets=[]
    def clean(self,value):
        if isinstance(value,str):
            for key in self.secrets:
                if key:value=value.replace(key,'[REDACTED]')
            return value
        if isinstance(value,list):return [self.clean(v) for v in value]
        if isinstance(value,dict):return {k:self.clean(v) for k,v in value.items() if k.lower() not in ('authorization','api_key','api-key')}
        return value
    def send(self,frame):
        data=json.dumps(self.clean(frame),separators=(',',':'),ensure_ascii=True,allow_nan=False).encode()+b'\n'
        if len(data)>MAX_LINE:raise ConfigError('desktop control frame exceeds32KiB')
        with self.lock:
            if self.output is not None:self.output.write(data);self.output.flush()
            else:
                offset=0
                while offset<len(data):
                    written=os.write(self.output_fd,data[offset:])
                    if written<=0:raise BrokenPipeError('desktop stdout closed')
                    offset+=written
    def event(self,event,payload):
        payload=self.clean(payload);data=json.dumps(payload,separators=(',',':'),ensure_ascii=True,allow_nan=False).encode()
        if len(data)<=16000:
            self.send({'type':'event','event':event,'payload':payload});return
        if self.root is None or len(data)>16*1024*1024 or self.total+len(data)>100*1024*1024:raise ConfigError('raw desktop diagnostic evidence capacity exceeded; no silent truncation')
        self.seq+=1;self.total+=len(data);rel='events/%06d.json'%self.seq;path=self.root/rel
        path.parent.mkdir(exist_ok=True)
        with path.open('xb') as stream:stream.write(data)
        self.send({'type':'event','event':event,'payload_file':rel,'payload_sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)})
    def finished(self,report):
        keep=('authoring_mode','schema','status','reason','detail','runner_id','provider','model','session_id','generation_id','native_acceptance','model_final_unverified_report','stop_acknowledged','measured','budget','applied_limits','funding_gate','billing','local_gpu_compute_cost','rate_history')
        selected={k:report[k] for k in keep if k in report}
        path=self.root/'runner-evidence/receipt.json' if self.root else None
        if path and path.is_file():
            selected['projection']='selected report state; full original receipt retained locally'
            selected['original_receipt']={'path':'runner-evidence/receipt.json','sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size}
        encoded=json.dumps(self.clean(selected),separators=(',',':'),ensure_ascii=True).encode()
        if len(encoded)>16000 and self.root:
            if len(encoded)>16*1024*1024:raise ConfigError('final desktop state exceeds bounded report capacity')
            rel='reports/finished.json';path=self.root/rel;path.parent.mkdir(exist_ok=True)
            with path.open('xb') as stream:stream.write(encoded)
            self.send({'type':'finished','receipt_file':rel,'receipt_sha256':hashlib.sha256(encoded).hexdigest(),'bytes':len(encoded)})
        else:self.send({'type':'finished','receipt':selected})

def start_config(frame):
    if frame.get('protocol')!=1 or frame.get('type')!='start':raise ConfigError('desktop protocol1 start required')
    path=Path(frame.get('profile_path','')).resolve(strict=True)
    if path.stat().st_size>128000:raise ConfigError('profile exceeds128KiB')
    if hashlib.sha256(path.read_bytes()).hexdigest()!=frame.get('profile_sha256'):raise ConfigError('profile changed before Start')
    fixture=frame.get('fixture_mode') is True
    cfg=load_profile(path,fixture_mode=fixture,desktop=True)
    cfg['_authoring_mode']=frame.get('authoring_mode','tools')
    if cfg['_authoring_mode'] not in ('tools','scanline'):raise ConfigError('unknown authoring mode')
    try:cfg['_boilerplate']=from_start(frame)
    except ValueError as exc:raise ConfigError(str(exc)) from exc
    if cfg['provider']=='fixture' and not fixture:raise ConfigError('scripted provider requires explicit fixture mode')
    if fixture and cfg['provider']!='fixture':raise ConfigError('fixture mode cannot bypass cloud funding')
    if cfg['provider'] in ('fixture','ollama_chat') and frame.get('compute_consent') is not True:raise ConfigError('explicit local/scripted compute consent required')
    if cfg['provider'] not in ('fixture','ollama_chat') and frame.get('allow_live') is not True:raise ConfigError('explicit charged-provider Start grant required')
    overrides=frame.get('overrides',{})
    if not isinstance(overrides,dict) or set(overrides)-{'model','max_model_calls','max_tools','max_output_tokens','request_timeout_seconds','tokens_per_minute'}:raise ConfigError('unsupported desktop override')
    if 'model' in overrides:
        model=overrides['model']
        if not isinstance(model,str) or not 1<=len(model)<=120 or any(c in model for c in '\r\n\x00'):raise ConfigError('invalid model override')
        cfg['model']=model
    for k,v in overrides.items():
        if k=='model':continue
        if k=='request_timeout_seconds' and type(v) is float and math.isfinite(v) and v.is_integer():v=int(v)
        if type(v) is not int or not 1<=v<=DESKTOP_HARD[k]:raise ConfigError('desktop limit outside explicit host bounds: '+k)
        cfg['limits'][k]=v
    if cfg['limits']['tokens_per_minute']<1024:raise ConfigError('TPM must be at least1024')
    cfg['limits']['max_retries']=min(2,cfg['limits']['max_retries']);cfg['limits']['max_total_retries']=min(2,cfg['limits']['max_total_retries'])
    raw=frame.get('task',{});scope=raw.get('scope')
    if not isinstance(scope,dict) or set(scope)!={'x','y','width','height'} or any(type(v) is not int for v in scope.values()):raise ConfigError('desktop scope invalid')
    if scope['x']<0 or scope['y']<0 or scope['width']<1 or scope['height']<1 or scope['x']+scope['width']>2147483647 or scope['y']+scope['height']>2147483647:raise ConfigError('desktop scope outside finite coordinate bounds')
    cells=raw.get('cell_limit',4096)
    if type(cells) is not int or not 1<=cells<=65536:raise ConfigError('desktop Cells grant invalid')
    allowed=raw.get('allowed_materials');protected=raw.get('protected_regions',[])
    if not isinstance(allowed,list) or not allowed or len(allowed)>256 or any(type(n) is not int or not 0<=n<=255 for n in allowed):raise ConfigError('desktop materials invalid')
    if not isinstance(protected,list) or len(protected)>32:raise ConfigError('desktop protection invalid')
    for p in protected:
        if not isinstance(p,dict) or set(p)!={'x','y','width','height'} or any(type(v) is not int for v in p.values()) or p['width']<1 or p['height']<1:raise ConfigError('desktop protected rectangle invalid')
    prompt=raw.get('prompt')
    if not isinstance(prompt,str) or not 1<=len(prompt)<=8192:raise ConfigError('desktop prompt size invalid')
    acceptance=raw.get('acceptance',{'native_counts':{},'completed_ticks':None,'min_applied_edits':0})
    if not isinstance(acceptance,dict) or set(acceptance)!={'native_counts','completed_ticks','min_applied_edits'}:raise ConfigError('desktop acceptance invalid')
    auth={'version':1,'scope':scope,'allowed_materials':allowed,'protected':protected,'cell_limit':cells}
    history=frame.get('rate_history',[])
    if not isinstance(history,list) or len(history)>4096:raise ConfigError('invalid retained local rate history')
    for row in history:
        if not isinstance(row,dict) or set(row)!={'expires_utc','tokens'} or type(row['tokens']) is not int or not 0<=row['tokens']<=10000000 or type(row['expires_utc']) not in (int,float) or not math.isfinite(row['expires_utc']) or row['expires_utc']>time.time()+61:raise ConfigError('invalid retained local rate reservation')
    auth['rate_history']=history
    task={'schema':'cybersand.workbench-api-agent.task/1','instructions':prompt,'acceptance':acceptance}
    return cfg,task,auth,fixture

class Desktop:
    def __init__(self,protocol):
        self.protocol=protocol;self.runner=None;self.backend=None;self.worker=None
        self.stop_event=threading.Event();self.finished=threading.Event();self.started=False
        self._preflight_stop_thread=None
    def _phase(self,name):
        details={'start_received':'Start received; native task identity acknowledged.',
                 'validate_profile':'Validating host profile and frozen grants.',
                 'credential_check':'Checking selected provider credential; value is not logged.',
                 'source_check':'Checking tracked source content against Git HEAD.',
                 'funding_check':'Checking host authorization and request limits.',
                 'model_probe':'Checking model availability; no inference.',
                 'model_probe_complete':'Model availability check returned.',
                 'runner_ready':'Preflight complete; controller ready.'}
        self.protocol.event('runner.preflight',{'phase':name,'detail':details.get(name,name)})
    def _checkpoint(self,name):
        if self.stop_event.is_set():raise NativeError('host_stop_requested')
        self._phase(name)
    def _request_preflight_stop(self):
        if self.backend is None:return
        if self._preflight_stop_thread and self._preflight_stop_thread.is_alive():return
        def stop():
            try:
                result=self.backend.stop('desktop-preflight-stop',25)
                self.protocol.event('startup.native_stop',{'native_stop_acknowledged':result['receipt']['status']=='stopped','receipt':result})
            except Exception as exc:
                try:self.protocol.event('startup.native_stop',{'native_stop_acknowledged':False,'reason':getattr(exc,'code','native_stop_unconfirmed')})
                except Exception:pass
        self._preflight_stop_thread=threading.Thread(target=stop,name='preflight-native-stop',daemon=True)
        self._preflight_stop_thread.start()
    def receive(self,frame):
        if self.finished.is_set():return
        kind=frame.get('type')
        if kind=='start':
            if self.started:raise ConfigError('desktop duplicate start refused')
            self.started=True
            try:
                root=Path(frame.get('bridge_root','')).resolve(strict=True)
                if not root.is_dir():raise ConfigError('desktop bridge root unavailable')
                self.protocol.root=root;raw=frame.get('task',{})
                auth={'cell_limit':raw.get('cell_limit',4096),'scope':raw.get('scope',{}),
                      'allowed_materials':raw.get('allowed_materials',[0,58]),'protected':raw.get('protected_regions',[])}
                # Only establish the host's already-acknowledged native authority.
                self.backend=DesktopWorkbench(self.protocol.send,frame.get('session',{}),auth,root,frame.get('authoring_mode','tools'))
                self.backend.open();self._phase('start_received')
            except Exception as exc:
                try:self.protocol.finished({'status':'unconfirmed_stop','reason':getattr(exc,'code','desktop_start_metadata_invalid'),'stop_acknowledged':False})
                finally:self.finished.set()
                return
            self.worker=threading.Thread(target=self._run,args=(frame,),name='provider-neutral-runner',daemon=True);self.worker.start()
        elif kind=='native_result':
            if self.backend:self.backend.deliver(frame)
        elif kind=='stop':
            self.stop_event.set()
            if not self.started:
                self.protocol.finished({'status':'unconfirmed_stop','reason':'host_stop_before_start','stop_acknowledged':False})
                self.finished.set();return
            if self.runner:self.runner.request_host_stop_async()
            else:self._request_preflight_stop()
        else:raise ConfigError('desktop unknown protocol frame')
    def disconnected(self):
        self.stop_event.set()
        if self.runner:self.runner.request_host_stop_async()
        if self.backend:self.backend.fail()
    def _run(self,frame):
        report=None
        try:
            root=Path(frame.get('bridge_root','')).resolve(strict=True)
            if not root.is_dir() or root.is_symlink():raise ConfigError('fresh desktop bridge root required')
            self.protocol.root=root
            self._checkpoint('validate_profile')
            cfg,task,auth,fixture=start_config(frame)
            self.backend.auth=auth
            self._checkpoint('credential_check')
            if cfg['provider'] not in ('fixture','ollama_chat'):self.protocol.secrets.append(credential(cfg))
            dirty=False
            if not fixture:
                self._checkpoint('source_check')
                _,dirty=git_status()
                if dirty:raise ConfigError('tracked source dirty; live funding/source gate blocked')
            adapter=None
            if fixture:
                turns=frame.get('fixture_turns')
                selected=frame.get('fixture_script_path')
                if selected:
                    if turns is not None:raise ConfigError('select fixture_script_path OR fixture_turns, never both')
                    script=Path(selected).resolve(strict=True)
                    if script.stat().st_size>1024*1024:raise ConfigError('fixture script exceeds1MiB')
                    content=script.read_bytes()
                    if frame.get('fixture_script_sha256') and hashlib.sha256(content).hexdigest()!=frame['fixture_script_sha256']:raise ConfigError('selected fixture script changed')
                    turns=parse_json(content,1024*1024)
                if turns is None:turns=json.loads((Path(__file__).parent/'fixtures/nine-then-eight.fixture.json').read_text(encoding='utf-8'))
                if not isinstance(turns,list) or not 1<=len(turns)<=4096:raise ConfigError('fixture turns invalid')
                adapter=ScriptedAdapter(turns)
            self._checkpoint('funding_check')
            def model_probe(model):
                self._checkpoint('model_probe')
                result=openai_probe(model,credential(cfg))
                if self.stop_event.is_set():raise NativeError('host_stop_requested')
                self._phase('model_probe_complete');return result
            self.runner=Runner(cfg,task,auth,self.backend,root/'runner-evidence',adapter=adapter,
                fixture_mode=fixture,allow_live=frame.get('allow_live') is True or (cfg['provider']=='ollama_chat' and frame.get('compute_consent') is True),stop_event=self.stop_event,
                source_dirty=dirty,event_callback=self.protocol.event,
                credit_probe=model_probe if cfg['provider']=='openai_responses' else None)
            self.protocol.event('runner.cost_status',{
                'usd_limits_enforced':self.runner.funding_gate.get('usd_limits_enforced',True),
                'pricing_status':self.runner.funding_gate.get('pricing_status','known')})
            self._checkpoint('runner_ready')
            report=self.runner.run()
        except Exception as exc:
            reason='host_stop_requested' if self.stop_event.is_set() else (str(exc) if isinstance(exc,ConfigError) else getattr(exc,'reason_code',getattr(exc,'code','desktop_'+type(exc).__name__)))
            ack=False
            try:
                if self.backend is None and self.protocol.root:
                    self.backend=DesktopWorkbench(self.protocol.send,frame.get('session',{}),{'cell_limit':frame.get('task',{}).get('cell_limit',4096)},self.protocol.root)
                    self.backend.open()
                if self.backend and self.backend.session_id:ack=self.backend.stop('desktop-preflight-stop',25)['receipt']['status']=='stopped'
            except Exception:pass
            status=('stopped_or_failed' if self.stop_event.is_set() else 'refused') if ack else 'unconfirmed_stop'
            report={'schema':'cybersand.workbench-api-agent.receipt/1','status':status,'reason':reason,'stop_acknowledged':ack}
            if isinstance(exc,AgentError) and not self.stop_event.is_set():report['detail']=str(exc)
        finally:
            if self._preflight_stop_thread:self._preflight_stop_thread.join(timeout=28)
            try:self.protocol.finished(report or {'status':'internal_failure','reason':'desktop_missing_report','stop_acknowledged':False})
            except (OSError,ValueError,ConfigError):pass
            self.finished.set()

def main():
    app=Desktop(Protocol())
    app.protocol.event('runner.preflight',{'phase':'waiting_for_start','detail':'Python process ready; waiting for Start frame.'})
    def reader():
        try:
            pending=bytearray()
            while True:
                # A daemon blocked in BufferedReader.readline owns its Python
                # buffer lock at interpreter finalization (_enter_buffered_busy).
                # Raw OS reads have no Python buffered-stdio lock to strand.
                block=os.read(sys.stdin.fileno(),4096)
                if not block:
                    if pending:raise ConfigError('desktop EOF inside protocol frame')
                    break
                pending.extend(block)
                while b'\n' in pending:
                    end=pending.index(10)+1;raw=bytes(pending[:end]);del pending[:end]
                    if len(raw)>MAX_LINE:raise ConfigError('desktop input frame exceeds32KiB')
                    value=parse_json(raw,MAX_LINE)
                    if not isinstance(value,dict):raise ConfigError('desktop frame must be an object')
                    app.receive(value)
                if len(pending)>=MAX_LINE:raise ConfigError('desktop input frame exceeds32KiB')
        except Exception as exc:
            try:app.protocol.event('startup.error',{'reason':getattr(exc,'code','desktop_protocol_input_invalid')})
            except Exception:pass
        finally:app.disconnected()
    thread=threading.Thread(target=reader,name='desktop-stdin',daemon=True);thread.start()
    while not app.finished.wait(.05):
        if not thread.is_alive() and not app.started:return 3
    if app.worker:app.worker.join(timeout=1)
    return 0

if __name__=='__main__':raise SystemExit(main())
