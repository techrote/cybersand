"""One bounded agent controller; #547 remains sole World and edit authority."""
from __future__ import annotations
import hashlib
import json
import math
import os
from pathlib import Path
import secrets
import random
import threading
import time
from dataclasses import dataclass,field,replace

from atlas_agent.pricing import text_tokens_upper_bound, image_tokens_upper_bound
from atlas_agent.errors import LimitReached
from .config import ConfigError, validate_live
from .usage_budget import conservative_image_tokens
from .boilerplate import sections
from .backend import Workbench,NativeError,STATUS,validate_tool
from .providers import ProviderError,Decision,HTTPAdapter,ScriptedAdapter,request_body

class LimitError(RuntimeError):pass


def clean_payload(obj):return json.dumps(obj,sort_keys=True,ensure_ascii=True,separators=(',',':'),allow_nan=False)

def hash_file(path:Path)->str:return hashlib.sha256(path.read_bytes()).hexdigest()


def trusted_task(path:Path,auth_path:Path)->tuple[dict,dict]:
    from .config import read_json
    if path.stat().st_size>16000 or auth_path.stat().st_size>16000:raise ConfigError('task or host authorization too large')
    task=read_json(path);auth=read_json(auth_path)
    if set(task)!={'schema','instructions','acceptance'} or task['schema']!='cybersand.workbench-api-agent.task/1':
        raise ConfigError('task schema mismatch')
    if not isinstance(task['instructions'],str) or not 5<=len(task['instructions'])<=6000:
        raise ConfigError('task instructions size invalid')
    accept=task['acceptance']
    if not isinstance(accept,dict) or set(accept)!={'native_counts','completed_ticks','min_applied_edits'}:
        raise ConfigError('task acceptance checks required')
    if (not isinstance(accept['native_counts'],dict) or any(not isinstance(k,str) or not k.isdecimal() or
        type(v) is not int or v<0 or v>4096 for k,v in accept['native_counts'].items())):
        raise ConfigError('native count acceptance invalid')
    if type(accept['completed_ticks']) is not int or not 0<=accept['completed_ticks']<=480:
        raise ConfigError('ticks acceptance invalid')
    if type(accept['min_applied_edits']) is not int or not 0<=accept['min_applied_edits']<=20:
        raise ConfigError('edit acceptance invalid')
    if auth.get('version')!=1 or not isinstance(auth.get('scope'),dict):raise ConfigError('native authorization schema invalid')
    region=auth['scope']
    if set(region)!={'x','y','width','height'} or any(type(region[k]) is not int for k in region):
        raise ConfigError('authorisation scope invalid')
    if any(region[k]<0 for k in ('x','y')) or region['width']<=0 or region['height']<=0:
        raise ConfigError('authorization scope invalid')
    if not isinstance(auth.get('allowed_materials'),list) or not all(type(n) is int for n in auth['allowed_materials']):
        raise ConfigError('authorisation materials invalid')
    if not isinstance(auth.get('protected'),list):raise ConfigError('authorisation protection invalid')
    for p in auth['protected']:
        if not isinstance(p,dict) or set(p)!={'x','y','width','height'} or any(type(v) is not int for v in p.values()):
            raise ConfigError('authorisation protected invalid')
    return task,auth


@dataclass
class Stats:
    model_calls:int=0
    provider_attempts:int=0
    tool_calls:int=0
    native_ticks:int=0
    applied_edits:int=0
    model_seen_image:bool=False
    original_frames:int=0
    original_bytes:int=0
    provider_retries:int=0
    images_projected:int=0
    model_reports:list=field(default_factory=list)


class Runner:
    def __init__(self, cfg:dict,task:dict,auth:dict,wb:Workbench,output:Path,
                 *,adapter=None,fixture_mode:bool=False,allow_live:bool=False,
                 credit_probe=None,stop_event=None,source_dirty:bool|None=True,event_callback=None,rate_clock=None,rate_wait=None):
        self.cfg=cfg;self.task=task;self.auth=auth;self.wb=wb
        self.output=output;self.stop_event=stop_event or threading.Event()
        self.event_callback=event_callback
        self.desktop=bool(getattr(wb,'desktop',False))
        self.adapter=adapter or HTTPAdapter(cfg,fixture_mode=fixture_mode,trace=event_callback,
            tool_schemas=getattr(wb,'tool_schemas',None),argument_feedback=getattr(wb,'allow_argument_feedback',False))
        self.budget,self.funding_gate=validate_live(cfg,allow_live=allow_live,fixture_mode=fixture_mode,probe=credit_probe,source_dirty=source_dirty,desktop=self.desktop)
        self.stats=Stats()
        self.history=[]
        self.results=[]
        self.last_observation=None;self.pending_proposal=None
        self._needs_observation=False
        self.last_counts={};self.last_revision=None
        self.native_session=None
        self.sid=None;self.generation=None
        self.call_ids=set()
        self.request_ids=set()
        self.runner_id='wbapi-'+secrets.token_hex(8)
        self.started=time.monotonic()
        self.limit=cfg['limits']
        self.failure=''
        self.stop_result=None
        self.report=None
        self._stop_thread=None
        self._argument_repairs=0
        self._retry_wait=0.
        self._rate_reservations=[]
        self._rate_clock=rate_clock or time.monotonic
        self._rate_wait=rate_wait or self.stop_event.wait
        for entry in auth.get('rate_history',[]) if self.desktop else []:
            ttl=entry['expires_utc']-time.time()
            if ttl>0:self._rate_reservations.append({'at':self._rate_clock()+ttl-60,'tokens':entry['tokens']})

    def _timeout(self)->float:
        remaining=self.limit['max_run_seconds']-(time.monotonic()-self.started)
        if remaining<=0:raise LimitError('task_wallclock_deadline')
        return min(remaining,float(self.limit.get('request_timeout_seconds',45)))

    def _id(self)->str:
        value=self.runner_id+'-'+str(self.stats.tool_calls+1)
        if value in self.request_ids:raise NativeError('new_request_id_collision')
        self.request_ids.add(value)
        return value

    def _event(self,event:dict)->None:
        record={**event,'at_elapsed_seconds':round(time.monotonic()-self.started,3),
                'measured':{k:getattr(self.stats,k) for k in ('model_calls','provider_attempts','tool_calls','native_ticks','applied_edits')}}
        encoded=clean_payload(record)
        if len(encoded)>35000:raise LimitError('event_record_capacity_exceeded')
        with (self.output/'events.jsonl').open('a',encoding='utf-8') as out:out.write(encoded+'\n')
        if self.event_callback:
            name=str(record.get('type','event'))
            self.event_callback(name if name.startswith('rate.') else 'runner.'+name,record)

    def _native_summary(self,response:dict)->tuple[dict,dict]:
        receipt=response['receipt']
        native=receipt.get('result') or {}
        if not isinstance(native,dict):raise NativeError('native_result_not_object')
        # These fields are source-backed and bounded, never model-authored.
        keys=('status','observation_id','proposal_id','confirmed_writes','changed_cells','distinct_cells','excluded_operations','native_counts',
              'identity','completed','completed_tick','reason','revision','region','palette',
              'operation_index','render_identity','viewport_native_region','viewport_logical_region',
              'viewport_framebuffer_rect','observation_cell_limit','authorized_scope')
        summary={k:native[k] for k in keys if k in native}
        if self.desktop and isinstance(native.get('observation'),dict):
            summary['observation']={k:native['observation'][k] for k in keys if k in native['observation']}
        summary['tool']=receipt.get('tool')
        summary['status']=receipt.get('status')
        summary['completed_native_ticks_total']=receipt.get('completed_native_ticks_total')
        summary['projection']='selected_native_fields; original receipt retained in evidence'
        summary['original_receipt_sha256']=hashlib.sha256(clean_payload(receipt).encode()).hexdigest()
        return summary,receipt

    def _project(self,summary:dict)->str:
        # Model context is not the audit archive. Tool-call IDs already name the
        # operation; the host validates identities/readback before this display.
        status=summary.get('status')
        compact={'status':status}
        def fields(source,names):return {k:source[k] for k in names if source.get(k) is not None}
        def observation(source):
            result=fields(source,('observation_id','region','native_counts',
                'viewport_native_region','viewport_framebuffer_rect'))
            counts=source.get('native_counts',{})
            palette=[]
            for item in source.get('palette') or []:
                if not isinstance(item,dict):continue
                material=item.get('id')
                if type(material) in (int,float) and math.isfinite(material) and material==int(material) and material not in (0,58) and counts.get(str(int(material)),0)>0:
                    palette.append(item)
            if palette:result['palette']=palette
            return result
        if status=='proposed':
            compact.update(fields(summary,('proposal_id','changed_cells')))
            if summary.get('distinct_cells')!=summary.get('changed_cells'):
                compact.update(fields(summary,('distinct_cells',)))
        elif status=='applied':
            compact.update(fields(summary,('confirmed_writes','changed_cells')))
        elif status=='observed':
            compact.update(observation(summary))
        elif status=='completed':
            compact.update(fields(summary,('completed','completed_native_ticks_total')))
            compact.update(observation(summary))
            if isinstance(summary.get('observation'),dict):
                compact['observation']=observation(summary['observation'])
        else:
            # Unusual outcomes retain their detail; only audit annotations go.
            compact={k:v for k,v in summary.items() if k not in
                     ('projection','original_receipt_sha256','tool')}
        if summary.get('excluded_operations'):compact['excluded_operations']=summary['excluded_operations']
        if summary.get('reason'):compact['reason']=summary['reason']
        text=clean_payload(compact)
        # Do not replace necessary view/count/error detail with an opaque hash
        # when it is oversized. Preserve the original and fail explicitly.
        if len(text)>self.limit['max_tool_result_bytes']:raise LimitError('native_projection_capacity')
        return text

    def _history_safeguard(self):
        # Keep a canonical fully stateless message/call/result conversation.
        # Images older than the newest are projected away ONLY for the model,
        # with an explicit note; original PNGs remain untouched on disk.
        imgs=[i for i,h in enumerate(self.history) if h.get('image')]
        if len(imgs)>1:
            for i in imgs[:-1]:
                h=self.history[i]
                h.pop('image')
                h['text']+='\n'+sections(self.cfg.get('_boilerplate'),self.cfg.get('_authoring_mode','tools'))['earlier_image']
                self.stats.images_projected+=1
        # Count the provider's real message/tool/schema projection, not local
        # h.native evidence (which remains retained, never silently truncated).
        # Images are represented by a marker here and priced separately below.
        projection=request_body(self.cfg,self.history,getattr(self.wb,'tool_schemas',None),include_image_bytes=False)
        text_bytes=len(clean_payload(projection).encode())
        if text_bytes>self.limit['max_history_bytes']:
            raise LimitError('canonical_history_bytes_exceeded_no_silent_truncation')
        images=sum(1 for h in self.history if h.get('image'))
        if images>1:raise LimitError('active_image_projection_failed')
        return text_bytes,images

    def _reserve(self,fixed_output_cap=None):
        b,imgs=self._history_safeguard()
        upper=text_tokens_upper_bound(b,0.65)+512
        for h in self.history:
            image=h.get('image')
            if image:
                width=image.get('width');height=image.get('height')
                if type(width) is not int or type(height) is not int or width<1 or height<1:
                    raise LimitError('original_frame_missing_dimensions_for_cost_reservation')
                upper+=(conservative_image_tokens(width,height) if self.budget.rates is None else
                    image_tokens_upper_bound(self.budget.rates,width,height,self.cfg['capabilities']['image_detail']))
        if b>self.limit['max_request_bytes']:raise LimitError('model_context_capacity')
        output_cap=self._output_cap(upper,fixed_output_cap)
        self.budget.start_iteration()
        return self.budget.reserve(upper,output_cap)

    def _output_cap(self,input_estimate,fixed_output_cap=None):
        requested=self.limit['max_output_tokens']
        limit=self.limit.get('tokens_per_minute',0) if self.desktop else 0
        if not limit:return requested if fixed_output_cap is None else fixed_output_cap
        while True:
            if self.stop_event.is_set():raise NativeError('host_stop_requested')
            now=self._rate_clock()
            self._rate_reservations[:]=[r for r in self._rate_reservations if now-r['at']<60]
            used=sum(r['tokens'] for r in self._rate_reservations)
            available=max(0,limit-used)
            oversized=input_estimate>limit and self.budget.rates is None and not self._rate_reservations
            if available>0 and (input_estimate<=available or oversized) and (fixed_output_cap is None or fixed_output_cap<=available):
                effective=min(requested,available) if fixed_output_cap is None else fixed_output_cap
                if effective!=requested or oversized:
                    self._event({'type':'rate.output_cap','configured_output_tokens':requested,
                        'effective_output_tokens':effective,'estimated_input_tokens':input_estimate,
                        'tokens_per_minute':limit,'estimated_input_above_tpm':oversized,
                        'estimate_is_guaranteed_bound':False,'local_estimate':True})
                return effective
            if not self._rate_reservations:
                raise LimitError('estimated_input_above_TPM_reduce_inspection')
            delay=max(.01,min(r['at']+60-now for r in self._rate_reservations))
            self._event({'type':'rate.wait','wait_seconds':round(delay,3),'estimated_tokens':input_estimate,
                'reserved_tokens':used,'tokens_per_minute':limit,'local_estimate':True})
            if self._rate_wait(min(delay,self._timeout())):raise NativeError('host_stop_requested')
            self._timeout()

    def _settle(self,res,decision:Decision):
        usage=decision.usage
        if usage is None:
            self.budget.mark_ambiguous(res)
            raise ProviderError('provider_usage_not_reported_cost_unknown')
        if self.cfg['provider']=='openai_responses':
            a=usage.get('input_tokens');b=usage.get('output_tokens')
            cached=(usage.get('input_tokens_details') or {}).get('cached_tokens',0)
            reasoning=(usage.get('output_tokens_details') or {}).get('reasoning_tokens',0)
        else:
            a=usage.get('prompt_tokens',usage.get('input_tokens'))
            b=usage.get('completion_tokens',usage.get('output_tokens'))
            cached=(usage.get('prompt_tokens_details') or {}).get('cached_tokens',0)
            reasoning=(usage.get('completion_tokens_details') or {}).get('reasoning_tokens',0)
        if any(type(v) is not int or v<0 for v in (a,b,cached,reasoning)):
            self.budget.mark_ambiguous(res)
            raise ProviderError('provider_usage_malformed_cost_unknown')
        result=self.budget.commit(res,a,cached,b,reasoning)
        if result['exceeded_reservation']:
            if self.budget.rates is not None:raise LimitError('provider_usage_exceeded_reserved_upper_bound')
            self._event({'type':'token_estimate_exceeded','reported_input_tokens':a,'reported_output_tokens':b,
                'estimate_is_guaranteed_bound':False,'configured_token_limits_enforced':True})

    def _pace(self,res):
        limit=self.limit.get('tokens_per_minute',0) if self.desktop else 0
        if not limit:return None
        estimate=max(res.input_tokens,res.output_tokens)
        while True:
            now=self._rate_clock()
            self._rate_reservations[:]=[r for r in self._rate_reservations if now-r['at']<60]
            if sum(r['tokens'] for r in self._rate_reservations)+estimate<=limit or (
                    self.budget.rates is None and estimate>limit and not self._rate_reservations):break
            if not self._rate_reservations:raise LimitError('estimated_input_above_TPM_reduce_inspection')
            delay=max(.01,min(r['at']+60-now for r in self._rate_reservations))
            self._event({'type':'rate.wait','wait_seconds':round(delay,3),'estimated_tokens':estimate,'reserved_tokens':sum(r['tokens'] for r in self._rate_reservations),'tokens_per_minute':limit,'local_estimate':True})
            if self._rate_wait(min(delay,self._timeout())):raise NativeError('host_stop_requested')
            self._timeout()
        item={'at':self._rate_clock(),'tokens':estimate}
        self._rate_reservations.append(item)
        self._event({'type':'rate.reservation','rate_history':self._rate_history(),'local_estimate':True})
        return item

    def _rate_history(self):
        return [{'expires_utc':time.time()+max(0.,r['at']+60-self._rate_clock()),'tokens':r['tokens']} for r in self._rate_reservations if r['at']+60>self._rate_clock()]

    def _provider(self)->Decision:
        retry=0
        fixed_output_cap=None
        while True:
            if self.stop_event.is_set():raise NativeError('host_stop_requested')
            if (self.stats.provider_attempts if self.desktop else self.stats.model_calls)>=self.limit['max_model_calls']:raise LimitError('model_call_limit')
            res=self._reserve(fixed_output_cap)
            if fixed_output_cap is None:fixed_output_cap=res.output_tokens
            paced=None
            try:
                paced=self._pace(res)
                if self.stop_event.is_set():raise NativeError('host_stop_requested')
                self.stats.provider_attempts+=1
                capped=getattr(self.adapter,'request_with_output_cap',None)
                decision=(capped(self.history,self.limit['max_request_bytes'],self._timeout(),res.output_tokens)
                    if callable(capped) else self.adapter.request(self.history,self.limit['max_request_bytes'],self._timeout()))
            except ProviderError as e:
                if e.kind=='provider_rate_limit':
                    self.budget.release(res,rate_limited=True)
                    retry+=1;self.stats.provider_retries+=1
                    if retry>self.limit['max_retries'] or self.stats.provider_retries>self.limit['max_total_retries']:
                        raise LimitError('provider_rate_retry_exhausted') from None
                    delay=e.retry_after if e.retry_after is not None else (10.*2**(retry-1) if self.desktop else .5*2**retry)
                    if self.desktop and e.retry_after is None:delay+=random.uniform(.05,.25)
                    if delay>60 or self._retry_wait+delay>120:raise LimitError('retry_after_exceeds_bounded_wait_not_shortened')
                    self._retry_wait+=delay
                    if self._timeout()<=delay:raise LimitError('retry_exceeds_task_deadline')
                    self._event({'type':'rate.retry','attempt':self.stats.provider_retries,'wait_seconds':delay,'delay_seconds':delay,'same_history':True})
                    self._rate_wait(delay)
                    continue
                if e.kind in ('provider_request_rejected','provider_auth_denied','provider_quota_exhausted',
                              'provider_redirect_refused','model_request_oversize','provider_unsupported_tool',
                              'invalid_provider_json','provider_unclassified_429'):
                    self.budget.release(res)
                else:self.budget.mark_ambiguous(res)
                raise
            except NativeError:
                self.budget.release(res)
                raise
            self._settle(res,decision)
            if paced is not None:
                usage=decision.usage or {}
                a=usage.get('input_tokens',usage.get('prompt_tokens'));b=usage.get('output_tokens',usage.get('completion_tokens'))
                if type(a) is int and type(b) is int:
                    paced['tokens']=a+b
                    self._event({'type':'rate.settled','rate_history':self._rate_history(),'source':'provider_usage','local_estimate':True})
            self.stats.model_calls+=1
            self.stats.model_seen_image|=decision.saw_image
            self._event({'type':'provider','call':self.stats.model_calls,
                         'provider':self.cfg['provider'],'model':decision.model,
                         'kind':decision.kind,'reported_usage':decision.usage,
                         'raw_response_sha256':decision.raw_sha256,
                         'api_cost_status':('unknown_unpriced_model' if self.budget.rates is None else
                             'local_api_cost_zero_gpu_compute_unknown' if self.cfg['provider'] in ('ollama_chat','fixture') else 'calculated_from_reported_tokens_not_bill')})
            return decision

    def _dispatch(self,d:Decision)->None:
        if d.call_id in self.call_ids:raise ProviderError('reused_provider_call_id')
        self.call_ids.add(d.call_id)
        if self.stats.tool_calls>=self.limit['max_tools']:raise LimitError('tool_call_limit')
        model_tool=d.tool; model_args=d.args
        canonical=getattr(self.wb,'canonical_packet',None)
        conversion_error=None
        if callable(canonical):
            try:
                name,args=canonical(d.tool,d.args)
                d=replace(d,tool=name,args=args)
            except NativeError as exc:
                conversion_error=exc
                d=replace(d,tool='prepare_edit' if model_tool in ('prepare_stamp','prepare_pixels') else d.tool)
        if self.pending_proposal and d.tool!='apply_edit' and not (getattr(self.wb,'observe_retires_proposal',False) and d.tool=='observe'):
            raise NativeError('prepared_edit_must_be_applied_or_retired_before_another_tool')
        if self.stop_event.is_set():raise NativeError('host_stop_requested')
        validator=getattr(self.wb,'validate',validate_tool)
        try:
            if conversion_error:raise conversion_error
            if self._needs_observation and d.tool!='observe':raise NativeError('fresh_observation_required_after_refused_apply')
            if d.kind=='invalid_tool':raise NativeError('invalid_tool_arguments')
            ticks=validator(d.tool,d.args,self.auth['scope'],set(self.auth['allowed_materials']),self.auth['protected'],
                                self.last_observation,self.pending_proposal,self.stats.native_ticks,self.limit['max_native_ticks'])
        except NativeError as exc:
            if not getattr(self.wb,'allow_argument_feedback',False) or d.tool not in STATUS:raise
            self._argument_repairs+=1;self.stats.tool_calls+=1
            self.history.append({'kind':'call','id':d.call_id,'tool':model_tool,'args':model_args or {}})
            feedback={'status':'refused','origin':'client_validation','native_dispatched':False,'reason':exc.code,'remaining_tool_calls':self.limit['max_tools']-self.stats.tool_calls}
            if self.desktop:
                feedback['cell_limit']=self.auth.get('cell_limit',4096)
                if d.tool=='observe':feedback['recommended_arguments']={'region':None,'detail':'cells'}
            self.history.append({'kind':'result','id':d.call_id,'text':clean_payload(feedback),'native':feedback})
            self._event({'type':'tool_validation_refused','tool':d.tool,'provider_call_id':d.call_id,**feedback})
            return
        rid=self._id()
        self.stats.tool_calls+=1
        self._event({'type':'tool_proposed','tool':d.tool,'provider_call_id':d.call_id,'native_request_id':rid,
                     'arguments_sha256':hashlib.sha256(clean_payload(d.args).encode()).hexdigest()})
        self.history.append({'kind':'call','id':d.call_id,'tool':model_tool,'args':model_args})
        try:
            result=self.wb.call(d.tool,d.args,rid,self.stop_event,min(330,self._timeout()))
        except NativeError as e:
            self._event({'type':'tool_native_unknown_or_rejected','tool':d.tool,'native_request_id':rid,
                         'error':e.code})
            raise
        summary,receipt=self._native_summary(result)
        if self.desktop and receipt.get('status')=='refused' and receipt.get('non_mutating_refusal') is True and d.tool in ('prepare_edit','apply_edit'):
            if d.tool=='apply_edit' or str(summary.get('reason','')).startswith('authored_start_preflight_failed:'):
                self.pending_proposal=None;self.last_observation=None;self.last_counts={};self._needs_observation=True
            elif summary.get('reason') in ('missing_or_stale_observation','stale_observation','observation_not_matched_to_frame'):
                self.last_observation=None
            feedback={'status':'refused','reason':summary.get('reason'),'mutation':'none',
                'next_action':'observe' if self._needs_observation or self.last_observation is None else 'correct_operations_or_observe'}
            if 'operation_index' in summary:feedback['operation_index']=summary['operation_index']
            self.results.append({'request_id':rid,'tool':d.tool,'receipt':receipt,'original_png':None})
            self.history.append({'kind':'result','id':d.call_id,'text':clean_payload(feedback),'native':summary,
                'receipt_sha256':hashlib.sha256(clean_payload(receipt).encode()).hexdigest()})
            self._event({'type':'native_refusal','tool':d.tool,'native_request_id':rid,**feedback})
            return
        if receipt.get('status')!= {'observe':'observed','prepare_edit':'proposed','apply_edit':'applied','step':'completed'}[d.tool]:
            raise NativeError('native_nonacceptance_'+str(receipt.get('status')),rid)
        if d.tool=='observe':
            self._needs_observation=False
            if getattr(self.wb,'observe_retires_proposal',False):self.pending_proposal=None
            self.last_observation=summary.get('observation_id')
            if not isinstance(self.last_observation,str) or not self.last_observation:raise NativeError('native_observation_id_missing',rid)
            counts=summary.get('native_counts') or {}
            if not isinstance(counts,dict):raise NativeError('native_counts_missing',rid)
            self.last_counts=counts
        elif d.tool=='prepare_edit':
            self.pending_proposal=summary.get('proposal_id')
            if not isinstance(self.pending_proposal,str) or not self.pending_proposal:raise NativeError('native_proposal_id_missing',rid)
        elif d.tool=='apply_edit':
            if type(summary.get('confirmed_writes')) is not int:raise NativeError('native_writes_not_reported',rid)
            self.pending_proposal=None
            self.last_observation=None
            self.stats.applied_edits+=1
        elif d.tool=='step':
            if type(receipt.get('completed_native_ticks_total')) is not int:raise NativeError('native_tick_total_missing',rid)
            self.stats.native_ticks=receipt['completed_native_ticks_total']
            observed=summary.get('observation')
            if self.desktop and isinstance(observed,dict):
                self.last_observation=observed.get('observation_id')
                self.last_counts=observed.get('native_counts',{})
        image=None;frame=receipt.get('frame') or {}
        if frame.get('status')=='original_post_draw':
            self.stats.original_frames+=1
            if self.stats.original_frames>self.limit['max_images']:raise LimitError('original_image_count_limit')
            image=self.wb.original_png(frame,self.output/'frames'/(rid+'.png'),self.limit['max_image_bytes'])
            self.stats.original_bytes+=image['bytes']
            if self.stats.original_bytes>self.limit['max_evidence_bytes']:raise LimitError('original_image_disk_budget')
        # Retain confirmed native work even if the model summary hits capacity.
        self.results.append({'request_id':rid,'tool':d.tool,'receipt':receipt,'original_png':image})
        projected=self._project(summary)
        record={'kind':'result','id':d.call_id,'text':projected,'native':summary,'receipt_sha256':hashlib.sha256(clean_payload(receipt).encode()).hexdigest()}
        if image:record['image']=image
        self.history.append(record)
        self._event({'type':'native_result','tool':d.tool,'native_request_id':rid,
                     'native_status':receipt.get('status'),'native_receipt_sha256':record['receipt_sha256'],
                     'original_png':{k:v for k,v in image.items() if k!='path'} if image else None})

    def check_acceptance(self)->dict:
        criteria=self.task['acceptance']
        counts=self.last_counts
        count_checks={k:{'expected':v,'actual':counts.get(k),
                         'passed':counts.get(k)==v} for k,v in criteria['native_counts'].items()}
        check={'native_counts':count_checks,
               'completed_ticks':{'expected':criteria['completed_ticks'],'actual':self.stats.native_ticks,
                                  'passed':self.stats.native_ticks==criteria['completed_ticks']},
               'applied_edits':{'minimum':criteria['min_applied_edits'],'actual':self.stats.applied_edits,
                                'passed':self.stats.applied_edits>=criteria['min_applied_edits']},
               'observation_images':{'minimum':1,'actual':self.stats.original_frames,'passed':self.stats.original_frames>0},
               'model_saw_image':{'passed':self.stats.model_seen_image}}
        check['passed']=all(v['passed'] for v in count_checks.values()) and all(v['passed'] for k,v in check.items() if k not in ('native_counts','passed'))
        return check

    def request_host_stop_async(self)->None:
        self.stop_event.set()
        if self._stop_thread and self._stop_thread.is_alive():return
        if not self.wb.session_id:return
        def perform():
            try:self.stop_result=self.wb.stop(self.runner_id+'-stop',25)
            except Exception as e:self.failure='host_stop_unconfirmed_'+type(e).__name__
        self._stop_thread=threading.Thread(target=perform,name='host-native-stop',daemon=True)
        self._stop_thread.start()

    def _finish(self,status:str,reason:str,final_text:str='')->dict:
        self.request_host_stop_async()
        if self._stop_thread:self._stop_thread.join(timeout=28)
        stop_ack=isinstance(self.stop_result,dict) and (self.stop_result.get('receipt') or {}).get('status')=='stopped'
        if not stop_ack:
            status='unconfirmed_stop';reason=reason+'; native_stop_not_acknowledged'
        checks=self.check_acceptance()
        if status=='model_final':
            status='passed' if checks['passed'] and stop_ack else 'unverified_native_acceptance'
            reason='native_and_rendered_checks_passed' if status=='passed' else 'model_final_not_native_proof'
        self.report={'schema':'cybersand.workbench-api-agent.receipt/1','status':status,'reason':reason,
                     'runner_id':self.runner_id,'provider':self.cfg['provider'],'model':self.cfg['model'],
                     'profile_sha256':hashlib.sha256(clean_payload(self.cfg).encode()).hexdigest(),
                     'task_sha256':hashlib.sha256(clean_payload(self.task).encode()).hexdigest(),
                     'authorisation_sha256':hashlib.sha256(clean_payload(self.auth).encode()).hexdigest(),
                     'session_id':self.sid,'generation_id':self.generation,
                     'native_receipts':self.results,'native_acceptance':checks,
                     'model_final_unverified_report':final_text[:8000],
                     'stop_receipt':self.stop_result,'stop_acknowledged':stop_ack,
                     'funding_gate':self.funding_gate,'applied_limits':self.limit,
                     'measured':self.stats.__dict__, 'budget':self.budget.snapshot(),
                     'billing':('unknown-unpriced-model; token-usage-only; no-USD-ceiling-enforced' if self.budget.rates is None else
                         'estimated-from-reported-tokens-not-provider-invoice'),
                     'local_gpu_compute_cost':'unknown' if self.cfg['provider']=='ollama_chat' else 'not_local_gpu',
                     'context_projection':{'old_images_elided_from_model_history':self.stats.images_projected,
                                            'original_images_retained':self.stats.original_frames}}
        if self.desktop:
            self.report['rate_history']=self._rate_history()
            self.report['authoring_mode']=self.cfg.get('_authoring_mode','tools')
        (self.output/'receipt.json').write_text(json.dumps(self.report,sort_keys=True,indent=2)+'\n',encoding='utf-8')
        return self.report

    def run(self)->dict:
        if self.output.exists():raise ConfigError('output path already exists; protect original evidence')
        self.output.mkdir(parents=True,mode=0o700);(self.output/'frames').mkdir(mode=0o700)
        try:
            source=self.wb.open();self.sid=source['session_id'];self.generation=source['generation_id']
            self._event({'type':'native_session_open','session_id':self.sid,'generation_id':self.generation,
                        'native_generation':source['native_generation']})
            scope=self.auth['scope'];allowed=self.auth['allowed_materials']
            wording=sections(self.cfg.get('_boilerplate'),self.cfg.get('_authoring_mode','tools'))
            prompt='\n'.join((wording['task_prefix']+' '+self.task['instructions'],
                wording['permissions']+' '+clean_payload({'scope':scope,'allowed_materials':allowed,'protected':self.auth['protected'],**({'cell_limit':self.auth.get('cell_limit',4096)} if self.desktop else {})}),
                wording['workflow'],wording['summary_policy']))
            self.history=[{'kind':'user','text':prompt}]
            while True:
                decision=self._provider()
                if decision.kind=='final':return self._finish('model_final','model_final',decision.text)
                if decision.kind not in ('tool','invalid_tool') or decision.args is None:raise ProviderError('model_response_not_one_tool')
                self._dispatch(decision)
        except (NativeError,ProviderError,LimitError,ConfigError,ValueError,LimitReached) as exc:
            reason=getattr(exc,'code',getattr(exc,'kind',getattr(exc,'reason_code',str(exc))))
            self.failure=str(reason)
            self._event({'type':'runner_stop_reason','reason':str(reason)})
            return self._finish('stopped_or_failed',str(reason))
        except Exception as exc:
            # In particular, an unexpected Atlas/pricing or provider shape
            # error must still initiate host Stop rather than strand a World.
            # Do not serialize an exception message containing provider data.
            self.failure='runner_internal_'+type(exc).__name__
            try:self._event({'type':'runner_internal_failure','reason':self.failure})
            except (OSError,ValueError,LimitError):pass
            return self._finish('internal_failure',self.failure)
