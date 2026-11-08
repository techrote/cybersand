"""Non-streaming, stateless-provider adapters. No JSON extracted from prose."""
from __future__ import annotations
import base64
from dataclasses import dataclass
import hashlib
import json
import math
import datetime as dt
from email.utils import parsedate_to_datetime
import os
import re
import time
from typing import Any
from urllib.request import Request, build_opener, HTTPRedirectHandler, ProxyHandler
from urllib.error import HTTPError, URLError

from .config import ConfigError, credential, strict_endpoint

class ProviderError(RuntimeError):
    def __init__(self,kind:str,status:int|None=None,retry_after:float|None=None):
        super().__init__(kind);self.kind=kind;self.status=status;self.retry_after=retry_after

class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs):return None

_OPENER=build_opener(ProxyHandler({}),NoRedirect())

def parse_json(raw:bytes|str, max_size:int=9000000):
    if len(raw)>max_size:raise ProviderError('provider_response_oversize')
    def reject_constant(_):raise ProviderError('nonstandard_numeric_constant')
    def reject_duplicate(pairs):
        out={}
        for k,v in pairs:
            if k in out:raise ProviderError('duplicate_json_key')
            out[k]=v
        return out
    try:return json.loads(raw,parse_constant=reject_constant,object_pairs_hook=reject_duplicate)
    except (ValueError,UnicodeError,TypeError,RecursionError) as e:raise ProviderError('invalid_provider_json') from None


def retry_after(headers)->float|None:
    value=headers.get('Retry-After','')
    try:
        v=float(value)
        return v if math.isfinite(v) and v>=0 else None
    except (ValueError,TypeError):
        try:
            stamp=parsedate_to_datetime(value)
            if stamp.tzinfo is None:return None
            return max(0.,stamp.timestamp()-dt.datetime.now(dt.timezone.utc).timestamp())
        except (ValueError,TypeError,OverflowError):return None

def http_post(url:str, key:str, body:dict, timeout:float,max_request_bytes:int,trace=None)->dict:
    raw=json.dumps(body,separators=(',',':'),ensure_ascii=True,allow_nan=False).encode()
    if len(raw)>max_request_bytes: raise ProviderError('model_request_oversize')
    if trace:trace('http.request',{'endpoint':url,'body':body,'request_bytes':len(raw)})
    head={'Content-Type':'application/json','Accept':'application/json'}
    if key:head['Authorization']='Bearer '+key
    req=Request(url,method='POST',data=raw,headers=head)
    try:
        with _OPENER.open(req,timeout=timeout) as resp:
            if resp.status!=200 or resp.headers.get_content_type()!='application/json':
                raise ProviderError('unexpected_provider_content_type_or_status',resp.status)
            data=resp.read(8500001)
            if trace:trace('http.response',{'http_status':resp.status,'body':data.decode('utf-8','replace'),'response_bytes':len(data),'body_truncated':len(data)>8500000,'body_limit':8500000})
            if len(data)>8500000:raise ProviderError('provider_response_oversize')
            value=parse_json(data)
            if not isinstance(value,dict):raise ProviderError('provider_response_not_object')
            return value
    except HTTPError as e:
        data=e.read(8500001)
        if trace:trace('http.response',{'http_status':e.code,'body':data.decode('utf-8','replace'),'response_bytes':len(data),'body_truncated':len(data)>8500000,'body_limit':8500000})
        if 300<=e.code<400:raise ProviderError('provider_redirect_refused',e.code) from None
        if e.code in (401,403):raise ProviderError('provider_auth_denied',e.code) from None
        if e.code==429:
            body=data[:2048].decode('utf-8','ignore').lower()
            if any(w in body for w in ('quota','billing','credit','balance','hard_limit','insufficient_quota')):
                raise ProviderError('provider_quota_exhausted',429) from None
            if trace:
                try:
                    err=parse_json(data).get('error',{})
                    kinds=(err.get('code'),err.get('type'))
                except (ProviderError,AttributeError):kinds=()
                if not any(v in ('rate_limit_exceeded','slow_down','rate_limit_error') for v in kinds):
                    raise ProviderError('provider_unclassified_429',429) from None
            raise ProviderError('provider_rate_limit',429,retry_after(e.headers)) from None
        if e.code>=500:raise ProviderError('provider_server_outcome_unknown',e.code) from None
        raise ProviderError('provider_request_rejected',e.code) from None
    except (URLError,TimeoutError,OSError):
        raise ProviderError('provider_connection_outcome_unknown') from None

# Tool names exactly match the native host dispatcher. Stop/session are NOT model tools.
TOOL_SCHEMAS={
 'observe': {'type':'object','additionalProperties':False,
             'properties':{'region':{'type':'object','additionalProperties':False,
                          'properties':{k:{'type':'integer'} for k in ('x','y','width','height')},
                          'required':['x','y','width','height']},'detail':{'type':'string','enum':['cells']}},
             'required':['region','detail']},
 'prepare_edit':{'type':'object','additionalProperties':False,'properties':{
       'observation_id':{'type':'string'},'operations':{'type':'array','minItems':1,'maxItems':96,
         'items':{'type':'object','additionalProperties':False,'properties':{
           'shape':{'type':'string','enum':['rectangle']},
           'x0':{'type':'integer'},'x1':{'type':'integer'},'y0':{'type':'integer'},'y1':{'type':'integer'},'material':{'type':'integer'}},
           'required':['shape','x0','x1','y0','y1','material']}}},'required':['observation_id','operations']},
 'apply_edit':{'type':'object','additionalProperties':False,'properties':{'proposal_id':{'type':'string'}},'required':['proposal_id']},
 'step':{'type':'object','additionalProperties':False,'properties':{'ticks':{'type':'integer','minimum':1,'maximum':120}},'required':['ticks']}
}

def tool_defs(provider:str,strict:bool,schemas=None)->list[dict]:
    result=[]
    for name,parameters in (schemas or TOOL_SCHEMAS).items():
        desc={'observe':'Observe a bounded region and receive original rendered PNG plus native cell readback.',
              'prepare_edit':'Prepare one bounded rectangular material edit proposal; it is not applied yet.',
              'apply_edit':'Apply the matching prepared proposal against native revision fencing.',
              'step':'Advance the existing native World by 1 to 120 ticks.'}[name]
        if schemas is not None and name=='prepare_edit':
            desc='Prepare one bounded edit using 1 to 8 disc, line or rectangle primitives, with optional replace_only_material source filters. It is not applied until a matching native acknowledgment.'
        fn={'name':name,'description':desc,'parameters':parameters}
        if strict:fn['strict']=True
        result.append({'type':'function', 'function':fn} if provider!='openai_responses' else {'type':'function',**fn})
    return result

@dataclass(frozen=True)
class Decision:
    kind:str                # tool | final
    call_id:str=''
    tool:str=''
    args:dict|None=None
    text:str=''
    usage:dict|None=None
    model:str=''
    raw_sha256:str=''
    saw_image:bool=False


def normalized_tool(name:object, raw:object, call_id:object)->tuple[str,dict,str]:
    if not isinstance(name,str) or name not in TOOL_SCHEMAS:raise ProviderError('provider_unsupported_tool')
    if not isinstance(call_id,str) or not 1<=len(call_id)<=100 or not re.fullmatch(r'[A-Za-z0-9_-]+',call_id):
        raise ProviderError('provider_invalid_call_id')
    if not isinstance(raw,str) or len(raw)>32000:raise ProviderError('provider_invalid_tool_arguments')
    args=parse_json(raw.encode(),32000)
    if not isinstance(args,dict):raise ProviderError('provider_arguments_not_object')
    return name,args,call_id


def image_data(entry:dict, max_bytes:int)->str:
    file=entry.get('image')
    if not file: return ''
    from pathlib import Path
    data=Path(file['path']).read_bytes()
    if len(data)>max_bytes or not data.startswith(b'\x89PNG\r\n\x1a\n'):
        raise ProviderError('image_invalid_or_too_large')
    if hashlib.sha256(data).hexdigest()!=file['sha256']:raise ProviderError('original_image_changed')
    return 'data:image/png;base64,'+base64.b64encode(data).decode('ascii')


def render_history_response(history:list[dict], max_image_bytes:int,detail:str)->list[dict]:
    inp=[]
    for h in history:
        kind=h['kind']
        if kind in ('user','comment'):
            content=[{'type':'input_text','text':h['text']}]
            uri=image_data(h,max_image_bytes)
            if uri:content.append({'type':'input_image','image_url':uri,'detail':detail})
            inp.append({'role':'user','content':content})
        elif kind=='call':inp.append({'type':'function_call','call_id':h['id'],'name':h['tool'],
                                      'arguments':json.dumps(h['args'],sort_keys=True,separators=(',',':'))})
        elif kind=='result':
            content=[{'type':'input_text','text':h['text']}]
            uri=image_data(h,max_image_bytes)
            if uri:content.append({'type':'input_image','image_url':uri,'detail':detail})
            inp.append({'type':'function_call_output','call_id':h['id'],'output':content})
    return inp


def render_history_chat(history:list[dict],max_image_bytes:int,detail:str)->list[dict]:
    messages=[]
    for h in history:
        kind=h['kind']
        if kind in ('user','comment'):
            uri=image_data(h,max_image_bytes)
            if uri:content=[{'type':'text','text':h['text']},{'type':'image_url','image_url':{'url':uri,'detail':detail}}]
            else:content=h['text']
            messages.append({'role':'user','content':content})
        elif kind=='call':
            messages.append({'role':'assistant','content':None,'tool_calls':[
                {'id':h['id'],'type':'function','function':{
                    'name':h['tool'],'arguments':json.dumps(h['args'],separators=(',',':'),sort_keys=True)}}]})
        elif kind=='result':
            messages.append({'role':'tool','tool_call_id':h['id'],'content':h['text']})
            uri=image_data(h,max_image_bytes)
            if uri:messages.append({'role':'user','content':[{'type':'text','text':'Original post-draw observation for the immediately preceding tool result; same native session.'},
                {'type':'image_url','image_url':{'url':uri,'detail':detail}}]})
    return messages

class HTTPAdapter:
    def __init__(self,cfg:dict, *, fixture_mode:bool=False,trace=None,tool_schemas=None,argument_feedback=False):
        self.cfg=cfg;self.fixture_mode=fixture_mode
        strict_endpoint(cfg['provider'],cfg['endpoint'],fixture_mode)
        self.key='' if fixture_mode else credential(cfg)
        self.trace=trace;self.tool_schemas=tool_schemas;self.argument_feedback=argument_feedback

    def _trace(self,event,payload):
        if not self.trace:return
        def clean(value):
            if isinstance(value,str):
                if value.startswith('data:image/') and ';base64,' in value:
                    raw=base64.b64decode(value.split(',',1)[1]);return {'image_bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
                return value.replace(self.key,'[REDACTED]') if self.key else value
            if isinstance(value,list):return [clean(v) for v in value]
            if isinstance(value,dict):return {k:clean(v) for k,v in value.items() if k.lower() not in ('authorization','api_key','api-key')}
            return value
        self.trace(event,clean(payload))

    def request(self,history:list[dict],max_request_bytes:int,timeout:float)->Decision:
        cfg=self.cfg;provider=cfg['provider'];model=cfg['model'];caps=cfg['capabilities'];lim=cfg['limits']
        if provider=='openai_responses':
            body={'model':model,'input':render_history_response(history,lim['max_image_bytes'],caps['image_detail']),
                  'tools':tool_defs(provider,caps['strict_tools'],self.tool_schemas), 'max_output_tokens':lim['max_output_tokens'],
                  'store':False, 'stream':False, 'truncation':'disabled'}
            if caps['parallel_tools']:body['parallel_tool_calls']=False
        else:
            body={'model':model,'messages':[{'role':'system','content':SYSTEM_MESSAGE},
                  *render_history_chat(history,lim['max_image_bytes'],caps['image_detail'])],
                  'tools':tool_defs(provider,caps['strict_tools'],self.tool_schemas),
                  'max_tokens':lim['max_output_tokens'],'stream':False}
            if caps['parallel_tools']:body['parallel_tool_calls']=False
        answer=http_post(cfg['endpoint'],self.key,body,timeout,max_request_bytes,self._trace if self.trace else None)
        sha=hashlib.sha256(json.dumps(answer,sort_keys=True,separators=(',',':')).encode()).hexdigest()
        seen=any(h.get('image') for h in history)
        try:return parse_response(answer,provider,model,sha,seen)
        except ProviderError as exc:
            if not self.argument_feedback or exc.kind not in ('invalid_provider_json','provider_invalid_tool_arguments','provider_arguments_not_object'):
                raise
            if provider=='openai_responses':
                if answer.get('status')!='completed':raise
                calls=[c for c in answer.get('output',[]) if isinstance(c,dict) and c.get('type')=='function_call']
            else:
                choices=answer.get('choices') or []
                if len(choices)!=1 or choices[0].get('finish_reason')!='tool_calls':raise
                calls=(choices[0].get('message') or {}).get('tool_calls') or []
            if len(calls)!=1 or not isinstance(calls[0],dict):raise
            c=calls[0];fn=c if provider=='openai_responses' else c.get('function',{})
            name=fn.get('name');cid=c.get('call_id') if provider=='openai_responses' else c.get('id')
            if name not in TOOL_SCHEMAS or not isinstance(cid,str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,100}',cid):raise
            return Decision('invalid_tool',cid,name,{},text=exc.kind,usage=answer.get('usage'),model=model,raw_sha256=sha,saw_image=seen)

SYSTEM_MESSAGE=('You are operating a native CyberSand World through four bounded authoring tools. '
 'Only propose operations within the trusted scope and allowed materials listed in the task. '
 'You may request one tool call at a time; wait for native readback before revising. '
 'No shell, code, endpoint, key or authorization changes. The host owns Stop. '
 'A final message is unverified until the native receipts and rendering match declared checks.')


def parse_response(answer:dict,provider:str,requested_model:str,sha:str='',seen:bool=False)->Decision:
    model=answer.get('model')
    if model is not None and model!=requested_model:raise ProviderError('provider_model_changed')
    if provider=='openai_responses':
        if answer.get('status')!='completed':raise ProviderError('response_incomplete_or_failed')
        items=answer.get('output')
        if not isinstance(items,list):raise ProviderError('response_output_missing')
        calls=[x for x in items if isinstance(x,dict) and x.get('type')=='function_call']
        usage=answer.get('usage')
        if not isinstance(usage,dict):usage=None
        if len(calls)>1:raise ProviderError('parallel_tool_calls_not_supported')
        if calls:
            c=calls[0];n,args,id=normalized_tool(c.get('name'),c.get('arguments'),c.get('call_id'))
            return Decision('tool',id,n,args,usage=usage,model=model or requested_model,raw_sha256=sha,saw_image=seen)
        texts=[]
        for it in items:
            if isinstance(it,dict) and it.get('type')=='message':
                for part in it.get('content',[]):
                    if isinstance(part,dict) and part.get('type')=='output_text' and isinstance(part.get('text'),str):
                        texts.append(part['text'])
        return Decision('final',text='\n'.join(texts)[:8000],usage=usage,model=model or requested_model,raw_sha256=sha,saw_image=seen)
    choices=answer.get('choices')
    if not isinstance(choices,list) or len(choices)!=1:raise ProviderError('chat_choices_invalid')
    one=choices[0];fin=one.get('finish_reason');msg=one.get('message')
    if not isinstance(msg,dict):raise ProviderError('chat_message_missing')
    calls=msg.get('tool_calls') or []
    if not isinstance(calls,list) or len(calls)>1:raise ProviderError('parallel_tool_calls_not_supported')
    usage=answer.get('usage');usage=usage if isinstance(usage,dict) else None
    if calls:
        if fin!='tool_calls':raise ProviderError('truncated_or_unfinished_tool_call')
        c=calls[0];fn=c.get('function') if isinstance(c,dict) else None
        if not isinstance(fn,dict):raise ProviderError('malformed_chat_tool_call')
        n,args,id=normalized_tool(fn.get('name'),fn.get('arguments'),c.get('id'))
        return Decision('tool',id,n,args,usage=usage,model=model or requested_model,raw_sha256=sha,saw_image=seen)
    if fin!='stop':raise ProviderError('chat_completion_incomplete')
    text=msg.get('content');
    if not isinstance(text,str):raise ProviderError('final_text_missing')
    return Decision('final',text=text[:8000],usage=usage,model=model or requested_model,raw_sha256=sha,saw_image=seen)

class ScriptedAdapter:
    """Deterministic test fixture. Not a real model or paid provider."""
    def __init__(self,turns:list[dict]):self.turns=turns;self.idx=0
    def request(self,history:list[dict],max_request_bytes:int,timeout:float)->Decision:
        if self.idx>=len(self.turns):raise ProviderError('fixture_exhausted')
        step=self.turns[self.idx];self.idx+=1
        name=step.get('tool')
        if 'require_native_counts' in step:
            prior=next((h for h in reversed(history) if h['kind']=='result' and 'native_counts' in h.get('native',{})),None)
            if prior is None or any(prior['native']['native_counts'].get(k)!=v for k,v in step['require_native_counts'].items()):
                raise ProviderError('fixture_native_readback_not_satisfied')
        if name:
            args=step.get('args') or {}
            # Test fixture can use $last_obs/$last_proposal so that a revision is
            # based on actual returned native IDs, never fabricated provider IDs.
            if name=='prepare_edit' and args.get('observation_id')=='$last_obs':
                result=next((h for h in reversed(history) if h['kind']=='result' and h.get('native',{}).get('observation_id')),None)
                if result is None:raise ProviderError('fixture_no_native_observation')
                args={**args,'observation_id':result['native']['observation_id']}
            if name=='apply_edit' and args.get('proposal_id')=='$last_proposal':
                result=next((h for h in reversed(history) if h['kind']=='result' and h.get('native',{}).get('proposal_id')),None)
                if result is None:raise ProviderError('fixture_no_native_proposal')
                args={**args,'proposal_id':result['native']['proposal_id']}
            return Decision('tool','fixture-call-%03d'%self.idx,name,args,usage={'input_tokens':128,'output_tokens':16},model='scripted-provider-not-model',saw_image=any(h.get('image') for h in history))
        return Decision('final',text=step.get('final','Fixture controller completed; verify real native checks.'),
                        usage={'input_tokens':64,'output_tokens':20},model='scripted-provider-not-model',saw_image=any(h.get('image') for h in history))
