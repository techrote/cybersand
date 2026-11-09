"""Adapter to the existing authorized desktop World, never a World owner."""
from __future__ import annotations
import base64
import copy
import hashlib
from pathlib import Path
import struct
import threading
import time
from .backend import NativeError, validate_tool

MAX_FILE = 16*1024*1024
DESKTOP_NATIVE_PALETTE = (2,14,29,13,19,23,25,26,27,3,58,0,8,16,12,7,9,28)
# Exact pre-write exits in the frozen authoring Geometry/session/host paths.
# Generic refusals, interrupted operations and unconfirmed outcomes are not proof.
PREPARE_REFUSALS = frozenset(('source_material_protected','protected_region','invalid_replace_filter',
    'outside_authorized_scope','replacement_material_not_allowed','disc_exceeds_cell_budget',
    'line_exceeds_cell_budget','rectangle_exceeds_cell_budget','distinct_cell_budget_exceeded',
    'invalid_primitive_count','operation_not_object','invalid_shape','unsupported_shape',
    'non_integer_or_missing_field','unknown_operation_field','reversed_rectangle_bounds',
    'missing_or_stale_observation','stale_observation','observation_not_matched_to_frame'))
APPLY_REFUSALS = frozenset(('unknown_or_retired_proposal','stale_proposal','source_cells_changed',
    'invalid_proposal_id','proposal_not_preflight_recordable'))

def desktop_tool_schemas(allowed=(0,58)):
    from .providers import TOOL_SCHEMAS
    s=copy.deepcopy(TOOL_SCHEMAS)
    s['observe']['properties']['region']={'anyOf':[s['observe']['properties']['region'],{'type':'null'}]}
    s['observe']['properties']['detail']['enum']=['cells','counts']
    variants=[]
    for shape in ('disc','line','rectangle'):
        coords=('x','y','radius') if shape=='disc' else ('x0','y0','x1','y1')
        props={'shape':{'type':'string','enum':[shape]},'material':{'type':'integer','enum':list(allowed)},
               **{k:{'type':'integer'} for k in coords},'replace_only_material':{'anyOf':[{'type':'integer','enum':list(DESKTOP_NATIVE_PALETTE)},{'type':'null'}]}}
        variants.append({'type':'object','additionalProperties':False,'properties':props,'required':list(props)})
    s['prepare_edit']['properties']['operations'].update({'maxItems':8,'items':{
        'anyOf':variants}})
    return s

def _line(x,y,ex,ey):
    dx,dy=abs(ex-x),-abs(ey-y);sx,sy=(1 if x<ex else -1),(1 if y<ey else -1);err=dx+dy
    while True:
        yield x,y
        if (x,y)==(ex,ey):return
        twice=2*err
        if twice>=dy:err+=dy;x+=sx
        if twice<=dx:err+=dx;y+=sy

def validate_desktop_tool(name,args,scope,allowed,protected,last_observation,last_proposal,ticks_so_far,max_ticks,cell_limit=4096):
    if name not in ('observe','prepare_edit'):
        return validate_tool(name,args,scope,allowed,protected,last_observation,last_proposal,ticks_so_far,max_ticks)
    if not isinstance(args,dict):raise NativeError('unknown_or_nonobject_tool')
    def inside(x,y):return scope['x']<=x<scope['x']+scope['width'] and scope['y']<=y<scope['y']+scope['height']
    if name=='observe':
        if set(args)!={'region','detail'} or args['detail'] not in ('cells','counts'):raise NativeError('invalid_observation_shape')
        area=args['region']
        if area is None:return 0 # Host selects the bounded camera/scope window.
        if not isinstance(area,dict) or set(area)!={'x','y','width','height'} or any(type(v) is not int for v in area.values()):raise NativeError('invalid_observation_integer')
        x,y,w,h=(area[k] for k in ('x','y','width','height'))
        if w<1 or h<1 or w*h>cell_limit or not inside(x,y) or not inside(x+w-1,y+h-1):raise NativeError('observe_out_of_scope')
        return 0
    if set(args)!={'observation_id','operations'} or not isinstance(args['observation_id'],str) or args['observation_id']!=last_observation:raise NativeError('invalid_or_stale_observation_id')
    ops=args['operations']
    if not isinstance(ops,list) or not 1<=len(ops)<=8:raise NativeError('edit_operations_count_invalid')
    seen=set()
    for op in ops:
        if not isinstance(op,dict):raise NativeError('edit_unknown_shape_or_keys')
        shape=op.get('shape');coords=('x','y','radius') if shape=='disc' else ('x0','y0','x1','y1')
        required={'shape','material',*coords}
        if shape not in ('disc','line','rectangle') or set(op)-required-{'replace_only_material'} or required-set(op):raise NativeError('edit_unknown_shape_or_keys')
        if any(type(op[k]) is not int for k in ('material',*coords)):raise NativeError('edit_integer_required')
        filt=op.get('replace_only_material')
        if filt is not None and (type(filt) is not int or filt not in DESKTOP_NATIVE_PALETTE):raise NativeError('edit_filter_invalid')
        if op['material'] not in allowed:raise NativeError('edit_material_not_authorized')
        if shape=='disc':
            x,y,r=(op[k] for k in coords)
            if not 0<=r<=144:raise NativeError('edit_area_limit')
            if not inside(x-r,y-r) or not inside(x+r,y+r):raise NativeError('edit_out_of_scope')
            points=((x+dx,y+dy) for dy in range(-r,r+1) for dx in range(-r,r+1) if dx*dx+dy*dy<=r*r)
        else:
            x0,y0,x1,y1=(op[k] for k in coords)
            if not inside(x0,y0) or not inside(x1,y1):raise NativeError('edit_out_of_scope')
            if shape=='rectangle':
                if x1<x0 or y1<y0 or (x1-x0+1)*(y1-y0+1)>cell_limit:raise NativeError('edit_area_limit')
                points=((x,y) for y in range(y0,y1+1) for x in range(x0,x1+1))
            else:
                if max(abs(x1-x0),abs(y1-y0))+1>cell_limit:raise NativeError('edit_area_limit')
                points=_line(x0,y0,x1,y1)
        for point in points:
            if any(p['x']<=point[0]<p['x']+p['width'] and p['y']<=point[1]<p['y']+p['height'] for p in protected):raise NativeError('edit_protected_area')
            seen.add(point)
            if len(seen)>cell_limit:raise NativeError('edit_total_cells_limit')
    return 0

class DesktopWorkbench:
    desktop=True
    allow_argument_feedback=True
    observe_retires_proposal=True
    def __init__(self,send,session,auth,bridge_root):
        self.send=send;self.source=copy.deepcopy(session);self.auth=copy.deepcopy(auth)
        self.root=Path(bridge_root).resolve(strict=True)
        self.session_id=self.generation_id=None
        self.host_stop_lock=threading.Lock();self._lock=threading.Lock();self._pending={};self._closed=''
        self.stop_request_id=None;self._stop_done=threading.Event();self._stop_result=None;self._stop_error=None
        self._ticks=0;self.tool_schemas=desktop_tool_schemas(auth.get('allowed_materials',(0,58)));self._images={}
    def open(self):
        s=self.source;ack=s.get('authorization_receipt',{});tid=s.get('task_id');gen=ack.get('generation',s.get('world_generation'))
        if s.get('authorized') is not True or not isinstance(tid,str) or not 1<=len(tid)<=128:raise NativeError('desktop_native_authorization_missing')
        if ack.get('status')!='authorized' or ack.get('task_id',tid)!=tid or type(gen) is not int or gen<0:raise NativeError('desktop_native_authorization_unconfirmed')
        if ack.get('cell_limit')!=self.auth['cell_limit']:raise NativeError('desktop_native_grant_mismatch')
        self.session_id=tid;self.generation_id=str(gen)
        return {'phase':'ready','session_id':tid,'generation_id':self.generation_id,'native_generation':gen}
    def validate(self,*args):return validate_desktop_tool(*args,cell_limit=self.auth['cell_limit'])
    def deliver(self,frame):
        with self._lock:
            entry=self._pending.get(frame.get('id'))
            if entry is None or entry['event'].is_set():return False
            entry['frame']=frame;entry['event'].set();return True
    def fail(self,reason='desktop_parent_disconnected'):
        with self._lock:
            self._closed=reason
            for entry in self._pending.values():entry['event'].set()
    def _exchange(self,tool,args,rid,stop_event,deadline,stopping=False):
        with self._lock:
            if self._closed:raise NativeError(self._closed,rid)
            if rid in self._pending or (not stopping and any(not p['stopping'] for p in self._pending.values())):raise NativeError('desktop_native_request_already_pending',rid)
            entry={'event':threading.Event(),'frame':None,'stopping':stopping};self._pending[rid]=entry
        try:
            self.send({'type':'native_request','id':rid,'tool':tool,'args':args})
            end=time.monotonic()+deadline
            while not entry['event'].wait(.025):
                if not stopping and stop_event.is_set():raise NativeError('host_cancellation_during_native_wait',rid)
                if time.monotonic()>=end:raise NativeError('native_receipt_deadline_outcome_unknown',rid)
            if self._closed:raise NativeError(self._closed,rid)
            if not stopping and stop_event.is_set():raise NativeError('host_cancellation_during_native_wait',rid)
            return self._normalize(tool,rid,entry['frame'],args)
        finally:
            with self._lock:self._pending.pop(rid,None)
    def call(self,tool,args,rid,stop_event,deadline):return self._exchange(tool,args,rid,stop_event,deadline)
    def stop(self,rid,deadline=25):
        with self.host_stop_lock:
            first=self.stop_request_id is None
            if first:self.stop_request_id=rid
            rid=self.stop_request_id
        if first:
            try:self._stop_result=self._exchange('stop',{},rid,threading.Event(),deadline,stopping=True)
            except Exception as exc:self._stop_error=exc
            finally:self._stop_done.set()
        elif not self._stop_done.wait(deadline):raise NativeError('desktop_native_stop_unconfirmed',rid)
        if self._stop_error:raise self._stop_error
        return self._stop_result
    def _file(self,relative,sha,max_bytes=MAX_FILE):
        if not isinstance(relative,str) or not relative or '\\' in relative or ':' in relative or Path(relative).is_absolute() or '..' in Path(relative).parts:raise NativeError('desktop_file_reference_invalid')
        path=self.root/relative;cursor=path
        while cursor!=self.root:
            if cursor.is_symlink():raise NativeError('desktop_file_symlink_refused')
            cursor=cursor.parent
        resolved=path.resolve(strict=True)
        if not resolved.is_relative_to(self.root) or resolved.stat().st_size>max_bytes:raise NativeError('desktop_file_capacity_or_path_invalid')
        raw=resolved.read_bytes()
        if not isinstance(sha,str) or hashlib.sha256(raw).hexdigest()!=sha:raise NativeError('desktop_file_checksum_mismatch')
        return raw
    def _normalize(self,tool,rid,message,args=None):
        from .providers import parse_json
        raw=parse_json(self._file(message['receipt_file'],message.get('receipt_sha256')),MAX_FILE) if message.get('receipt_file') else message.get('receipt')
        if not isinstance(raw,dict):raise NativeError('desktop_native_receipt_missing',rid)
        if raw.get('status')=='refused' and tool in ('prepare_edit','apply_edit'):
            allowed=PREPARE_REFUSALS if tool=='prepare_edit' else APPLY_REFUSALS
            reason=raw.get('reason')
            preflight=(tool=='prepare_edit' and isinstance(reason,str) and reason.startswith('authored_start_preflight_failed:') and len(reason)<=200)
            if not isinstance(reason,str) or (reason not in allowed and not preflight):raise NativeError('native_nonacceptance_refused',rid)
            if raw.get('interrupted_by_human') or any(raw.get(k,0)!=0 for k in
                    ('issued_writes','confirmed_writes','changed_cells')) or raw.get('readback'):
                raise NativeError('desktop_refusal_has_possible_mutation',rid)
            if raw.get('task_id',self.session_id)!=self.session_id:
                raise NativeError('desktop_native_identity_missing_or_changed',rid)
            for key in ('identity','identity_before','identity_after'):
                if key in raw and (not isinstance(raw[key],dict) or
                        str(raw[key].get('world_generation'))!=self.generation_id):
                    raise NativeError('desktop_native_identity_missing_or_changed',rid)
            if ('identity_before' in raw and 'identity_after' in raw and raw['identity_before']!=raw['identity_after']):
                raise NativeError('desktop_refusal_has_possible_mutation',rid)
            if tool=='apply_edit' and raw.get('proposal_id',(args or {}).get('proposal_id'))!=(args or {}).get('proposal_id'):
                raise NativeError('desktop_apply_proposal_identity_mismatch',rid)
            return {'state':'complete','request_id':rid,'receipt':{'tool':tool,'status':'refused',
                'result':raw,'frame':{'status':'none'},'non_mutating_refusal':True,
                'completed_native_ticks_total':self._ticks}}
        if tool=='stop':
            native=raw.get('owner_receipt',raw)
            if not isinstance(native,dict) or native.get('status')!='stopped' or native.get('no_further_agent_mutations') is not True:raise NativeError('desktop_native_stop_unconfirmed',rid)
            status='stopped'
        else:
            native=raw;status=raw.get('status');expected={'observe':'observed','prepare_edit':'proposed','apply_edit':'applied','step':'completed'}[tool]
            if tool=='step' and status in ('stepped','completed'):
                obs=raw.get('observation',{});requested=raw.get('requested');completed=raw.get('completed');before=raw.get('before_tick');after=raw.get('after_tick')
                if any(type(v) is not int for v in (requested,completed,before,after)) or not 1<=requested<=120 or completed!=requested or after!=before+completed or raw.get('still_paused') is not True or obs.get('status')!='observed' or obs.get('image_status')!='matched_post_draw' or obs.get('identity',{}).get('completed_tick')!=after or obs.get('render_identity',{}).get('tick')!=after:raise NativeError('desktop_step_missing_exact_matched_observation',rid)
                status='completed'
            if status!=expected:raise NativeError('native_nonacceptance_'+str(status),rid)
            if tool=='apply_edit' and args is not None and raw.get('proposal_id')!=args.get('proposal_id'):raise NativeError('desktop_apply_proposal_identity_mismatch',rid)
            identity=raw.get('identity_after',raw.get('identity',raw.get('observation',{}).get('identity',{})))
            if not isinstance(identity,dict) or any(type(identity.get(k)) is not int for k in ('world_generation','world_revision','completed_tick','manual_intent_revision')) or str(identity['world_generation'])!=self.generation_id:raise NativeError('desktop_native_identity_missing_or_changed',rid)
            if tool=='apply_edit':self._verify_apply(raw,rid)
            if tool=='step':
                completed=raw.get('completed')
                if type(completed) is not int or completed<0:raise NativeError('native_tick_total_missing',rid)
                self._ticks+=completed
        frame={'status':'none'}
        if tool in ('observe','step') and not (message.get('png_file') or message.get('framebuffer_png_base64')):raise NativeError('native_original_frame_missing',rid)
        if message.get('png_file') or message.get('framebuffer_png_base64'):
            observed=raw.get('observation',{}) if tool=='step' else raw
            native_tick=observed.get('identity',{}).get('completed_tick');render_tick=observed.get('render_identity',{}).get('tick')
            if tool not in ('observe','step') or observed.get('status')!='observed' or observed.get('image_status')!='matched_post_draw' or type(native_tick) is not int or type(render_tick) is not int or native_tick!=render_tick:raise NativeError('desktop_frame_not_native_matched',rid)
            image=self._file(message['png_file'],message.get('png_sha256'),8*1024*1024) if message.get('png_file') else base64.b64decode(message['framebuffer_png_base64'],validate=True)
            if message.get('png_sha256') and hashlib.sha256(image).hexdigest()!=message['png_sha256']:raise NativeError('native_frame_checksum_mismatch',rid)
            if len(image)>8*1024*1024 or len(image)<24 or image[:8]!=b'\x89PNG\r\n\x1a\n' or image[12:16]!=b'IHDR':raise NativeError('native_original_frame_invalid',rid)
            width,height=struct.unpack('>II',image[16:24])
            if not 1<=width<=16384 or not 1<=height<=16384:raise NativeError('native_frame_dimensions_invalid',rid)
            sha=hashlib.sha256(image).hexdigest();self._images[sha]=image
            frame={'status':'original_post_draw','sha256':sha,'width':width,'height':height}
        return {'state':'complete','request_id':rid,'receipt':{'tool':tool,'status':status,'result':native,'frame':frame,'completed_native_ticks_total':self._ticks}}

    def _verify_apply(self,raw,rid):
        before=raw.get('identity_before',{});after=raw.get('identity_after',{})
        if not isinstance(before,dict) or any(type(before.get(k)) is not int for k in ('world_generation','world_revision','completed_tick','manual_intent_revision')) or before['world_generation']!=after['world_generation'] or before['completed_tick']!=after['completed_tick'] or before['manual_intent_revision']!=after['manual_intent_revision'] or after['world_revision']<before['world_revision']:raise NativeError('desktop_apply_identity_unconfirmed',rid)
        rows=raw.get('readback');count=raw.get('distinct_cells');changed=raw.get('changed_cells');issued=raw.get('issued_writes');confirmed=raw.get('confirmed_writes');limit=self.auth['cell_limit']
        if not isinstance(rows,list) or type(count) is not int or not 1<=count<=limit or len(rows)!=count or type(changed) is not int or not 0<=changed<=count or type(issued) is not int or type(confirmed) is not int or not 0<=issued==confirmed<=8*limit:raise NativeError('desktop_apply_readback_missing_or_invalid',rid)
        seen=set();actual_changed=0;s=self.auth['scope']
        for row in rows:
            if not isinstance(row,dict) or any(type(row.get(k)) is not int for k in ('x','y','before','after','actual')):raise NativeError('desktop_apply_readback_invalid',rid)
            x,y=row['x'],row['y']
            if (x,y) in seen or not s['x']<=x<s['x']+s['width'] or not s['y']<=y<s['y']+s['height'] or row['before'] not in (0,58) or row['after'] not in self.auth['allowed_materials'] or row['actual']!=row['after'] or any(p['x']<=x<p['x']+p['width'] and p['y']<=y<p['y']+p['height'] for p in self.auth.get('protected',[])):raise NativeError('desktop_apply_readback_not_authoritative',rid)
            seen.add((x,y));actual_changed+=row['before']!=row['after']
        if actual_changed!=changed:raise NativeError('desktop_apply_changed_count_mismatch',rid)
    def original_png(self,frame,out,max_bytes):
        image=self._images.pop(frame.get('sha256'),None)
        if not isinstance(image,bytes) or len(image)>max_bytes or hashlib.sha256(image).hexdigest()!=frame.get('sha256'):raise NativeError('native_original_frame_missing_or_changed')
        out.parent.mkdir(parents=True,exist_ok=True)
        with out.open('xb') as stream:stream.write(image)
        return {'path':str(out),'sha256':frame['sha256'],'bytes':len(image),'width':frame['width'],'height':frame['height']}
