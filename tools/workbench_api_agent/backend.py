"""Thin consumer of #547's authenticated HTTP client; no competing World."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import re
import threading
import time

from remote_workbench.client import api, read_token, validate_base
from .config import ConfigError, HARD

class NativeError(RuntimeError):
    def __init__(self, code:str, request_id:str|None=None):
        super().__init__(code);self.code=code;self.request_id=request_id

STATUS={'observe':'observed','prepare_edit':'proposed','apply_edit':'applied','step':'completed','stop':'stopped'}
FILE=re.compile(r'^frames/(\d{3})-(observe|prepare_edit|apply_edit|step|stop)\.png$')


def integer(n):return type(n) is int


def validate_tool(name:str,args:dict,scope:dict,allowed:set[int],protected:list[dict],
                  last_observation:str|None,last_proposal:str|None,ticks_so_far:int,max_ticks:int)->int:
    if name not in ('observe','prepare_edit','apply_edit','step') or not isinstance(args,dict):
        raise NativeError('unknown_or_nonobject_tool')
    r=scope
    def inside(x:int,y:int)->bool:
        return r['x']<=x<r['x']+r['width'] and r['y']<=y<r['y']+r['height']
    if name=='observe':
        if set(args)!={'region','detail'} or args.get('detail')!='cells':raise NativeError('invalid_observation_shape')
        area=args['region']
        if not isinstance(area,dict) or set(area)!={'x','y','width','height'} or any(not integer(area.get(k)) for k in ('x','y','width','height')):
            raise NativeError('invalid_observation_integer')
        x,y,w,h=[area[k] for k in ('x','y','width','height')]
        if w<1 or h<1 or w*h>4096 or not inside(x,y) or not inside(x+w-1,y+h-1):raise NativeError('observe_out_of_scope')
        return 0
    if name=='prepare_edit':
        if set(args)!={'observation_id','operations'} or not isinstance(args.get('observation_id'),str) or args['observation_id']!=last_observation:
            raise NativeError('invalid_or_stale_observation_id')
        ops=args['operations']
        if not isinstance(ops,list) or not 1<=len(ops)<=96:raise NativeError('edit_operations_count_invalid')
        count=0
        for op in ops:
            if not isinstance(op,dict) or set(op)!={'shape','x0','y0','x1','y1','material'} or op['shape']!='rectangle':
                raise NativeError('edit_unknown_shape_or_keys')
            if any(not integer(op[k]) for k in ('x0','y0','x1','y1','material')):raise NativeError('edit_integer_required')
            x0,y0,x1,y1=op['x0'],op['y0'],op['x1'],op['y1']
            if x1<x0 or y1<y0 or not inside(x0,y0) or not inside(x1,y1):raise NativeError('edit_out_of_scope')
            if op['material'] not in allowed:raise NativeError('edit_material_not_authorized')
            if (x1-x0+1)*(y1-y0+1)>4096:raise NativeError('edit_area_limit')
            count+=(x1-x0+1)*(y1-y0+1)
            for p in protected:
                if not (x1<p['x'] or x0>=p['x']+p['width'] or y1<p['y'] or y0>=p['y']+p['height']):
                    raise NativeError('edit_protected_area')
        if count>4096:raise NativeError('edit_total_cells_limit')
        return 0
    if name=='apply_edit':
        if set(args)!={'proposal_id'} or not isinstance(args.get('proposal_id'),str) or args['proposal_id']!=last_proposal:
            raise NativeError('edit_proposal_unknown_or_stale')
        return 0
    if set(args)!={'ticks'} or not integer(args['ticks']) or not 1<=args['ticks']<=120:
        raise NativeError('step_ticks_invalid')
    if ticks_so_far+args['ticks']>max_ticks:raise NativeError('native_ticks_budget_exceeded')
    return args['ticks']


class Workbench:
    def __init__(self,base:str,token_file:Path,timeout:float=10):
        self.base=validate_base(base)
        self.token=read_token(token_file)
        self.timeout=min(30,max(1,timeout))
        self.session_id=None
        self.generation_id=None
        self.stop_request_id=None
        self.host_stop_lock=threading.Lock()    # ONLY serializes host Stop invocations; no receipt lock
        self.last_identity=None

    def _get(self,path):
        return api(self.base,self.token,'GET',path,timeout=self.timeout)

    def session(self)->dict:
        code,x=self._get('/v1/session')
        if code!=200 or not isinstance(x,dict):raise NativeError('native_session_unreachable')
        if self.session_id is not None and (x.get('session_id')!=self.session_id or x.get('generation_id')!=self.generation_id):
            raise NativeError('native_session_or_generation_changed')
        return x

    def open(self)->dict:
        x=self.session()
        if x.get('phase')!='ready' or not x.get('generation_id') or x.get('native_generation') is None:
            raise NativeError('native_session_not_ready')
        self.session_id=x['session_id'];self.generation_id=x['generation_id']
        return x

    def query(self,rid:str)->tuple[int,dict]:
        code,x=self._get('/v1/requests/'+rid)
        if not isinstance(x,dict):raise NativeError('native_request_not_json',rid)
        return code,x

    def _submit(self,tool:str,args:dict,rid:str)->tuple[int,dict]:
        if self.session_id is None:raise NativeError('native_session_not_open')
        document={'session_id':self.session_id,'request_id':rid,'tool':tool,'args':args}
        try:
            code,x=api(self.base,self.token,'POST','/v1/commands',body=document,timeout=self.timeout)
        except (TimeoutError,OSError) as e:
            # The POST may have arrived. Inspect the SAME request identity;
            # never synthesize another tool or new request ID after uncertainty.
            try:return self.query(rid)
            except Exception:raise NativeError('native_submission_outcome_unknown',rid) from None
        if not isinstance(x,dict):raise NativeError('native_submission_malformed',rid)
        if code not in (200,202):raise NativeError('native_rejected_'+str(x.get('error','http_'+str(code))),rid)
        return code,x

    def wait(self,rid:str,stop_event:threading.Event,deadline:float,*,stopping:bool=False)->dict:
        end=time.monotonic()+deadline
        while True:
            if time.monotonic()>end:raise NativeError('native_receipt_deadline_outcome_unknown',rid)
            if stop_event.is_set() and not stopping:raise NativeError('host_cancellation_during_native_wait',rid)
            try:code,x=self.query(rid)
            except (TimeoutError,OSError):
                stop_event.wait(0.15)  # cancelled wait is not a new mutation
                continue
            if code==202 and x.get('state')=='pending':
                stop_event.wait(0.12)
                continue
            if code!=200 or x.get('state')!='complete':raise NativeError('native_receipt_not_complete',rid)
            rec=x.get('receipt')
            if not isinstance(rec,dict) or rec.get('status') not in set(STATUS.values())|{'refused'}:
                raise NativeError('native_receipt_invalid',rid)
            return x

    def call(self,tool:str,args:dict,rid:str,stop_event:threading.Event,deadline:float)->dict:
        code,x=self._submit(tool,args,rid)
        if code==200 and x.get('state')=='complete':return x
        return self.wait(rid,stop_event,deadline)

    def stop(self,rid:str,deadline:float=25)->dict:
        # This can run from another thread while a model HTTP request or native
        # receipt polling is blocked. Do NOT acquire the ordinary op lock.
        with self.host_stop_lock:
            if self.stop_request_id and self.stop_request_id!=rid:
                rid=self.stop_request_id
            else:self.stop_request_id=rid
            code,x=self._submit('stop',{},rid)
        if code==200 and x.get('state')=='complete':return x
        return self.wait(rid,threading.Event(),deadline,stopping=True)

    def original_png(self,frame:dict,out:Path,max_bytes:int)->dict:
        if not isinstance(frame,dict) or frame.get('status')!='original_post_draw':raise NativeError('native_original_frame_missing')
        path=frame.get('path');sha=frame.get('sha256')
        if not isinstance(path,str) or not FILE.fullmatch(path) or not isinstance(sha,str) or not re.fullmatch(r'[0-9a-f]{64}',sha):
            raise NativeError('native_frame_metadata_invalid')
        code,raw=self._get('/v1/frames/'+path.removeprefix('frames/'))
        if code!=200 or not isinstance(raw,bytes) or len(raw)>max_bytes or not raw.startswith(b'\x89PNG\r\n\x1a\n'):
            raise NativeError('native_frame_retrieval_invalid')
        if hashlib.sha256(raw).hexdigest()!=sha:raise NativeError('native_frame_checksum_mismatch')
        out.parent.mkdir(parents=True,exist_ok=True)
        fd=out.open('xb')
        try:
            fd.write(raw)
        finally:fd.close()
        return {'path':str(out),'sha256':sha,'bytes':len(raw), 'width':frame.get('width'),'height':frame.get('height')}
