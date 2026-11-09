"""Deterministic bridge tests: synthetic native receipts, never product acceptance."""
from __future__ import annotations
import base64
import copy
import hashlib
import io
import json
from pathlib import Path
import tempfile
import subprocess
import sys
import queue
import threading
import time
import unittest
from unittest.mock import patch
from .backend import NativeError,validate_tool
from .config import ConfigError,load_profile,credential
from .desktop import Desktop,Protocol,start_config
from .desktop_backend import DesktopWorkbench,desktop_tool_schemas,validate_desktop_tool
from .providers import retry_after,HTTPAdapter,ProviderError,Decision
from .test_runner import png
HERE=Path(__file__).parent

def start_frame(root):
    profile=HERE/'profiles/fixture.json'
    return {'type':'start','protocol':1,'profile_path':str(profile.resolve()),
        'profile_sha256':hashlib.sha256(profile.read_bytes()).hexdigest(),'bridge_root':str(root),
        'fixture_mode':True,'compute_consent':True,'overrides':{},
        'task':{'prompt':'Build nine and revise to eight walls.','scope':{'x':28,'y':28,'width':8,'height':8},
            'allowed_materials':[0,58],'protected_regions':[],'cell_limit':4096,
            'acceptance':{'native_counts':{'58':8},'completed_ticks':4,'min_applied_edits':2}},
        'session':{'task_id':'desktop-test','authorized':True,'authorization_receipt':{
            'status':'authorized','task_id':'desktop-test','generation':3,'cell_limit':4096}}}

class DesktopTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        self.frame=start_frame(self.root);self.auth=start_config(self.frame)[2]
    def tearDown(self):self.temp.cleanup()
    def backend(self,send=lambda _:None):
        b=DesktopWorkbench(send,self.frame['session'],self.auth,self.root);b.open();return b
    def validate(self,name,args,limit=4096,protected=()):
        return validate_desktop_tool(name,args,{'x':0,'y':0,'width':2048,'height':2048},{0,58},protected,'obs','prop',0,480,limit)
    def test_desktop_shape_schema_strict_and_remote_unchanged(self):
        s=desktop_tool_schemas()['prepare_edit']['properties']['operations']
        self.assertEqual((s['minItems'],s['maxItems']),(1,8))
        for v in s['items']['anyOf']:
            self.assertEqual(set(v['required']),set(v['properties']))
            self.assertEqual(v['properties']['material']['enum'],[0,58])
        from .providers import TOOL_SCHEMAS
        self.assertEqual(TOOL_SCHEMAS['prepare_edit']['properties']['operations']['maxItems'],96)
        from .providers import tool_defs
        desc=next(t['description'] for t in tool_defs('openai_responses',True,desktop_tool_schemas()) if t['name']=='prepare_edit')
        self.assertTrue(all(s in desc for s in ('disc','line','rectangle','replace_only_material','8')))
        self.assertNotIn('bounded rectangular',desc)
    def test_distinct_cells_shapes_and_replace_filter(self):
        ops=[{'shape':'disc','x':20,'y':20,'radius':2,'material':58,'replace_only_material':0},
             {'shape':'line','x0':0,'y0':0,'x1':4,'y1':4,'material':0},
             {'shape':'rectangle','x0':30,'y0':30,'x1':30,'y1':30,'material':58}]
        self.validate('prepare_edit',{'observation_id':'obs','operations':ops})
        self.validate('observe',{'region':None,'detail':'counts'})
        self.validate('prepare_edit',{'observation_id':'obs','operations':[{'shape':'rectangle','x0':0,'y0':0,'x1':255,'y1':255,'material':58}]},65536)
        with self.assertRaises(NativeError):self.validate('prepare_edit',{'observation_id':'obs','operations':ops},4)
        with self.assertRaises(NativeError):self.validate('prepare_edit',{'observation_id':'obs','operations':ops},4096,[{'x':20,'y':20,'width':1,'height':1}])
        with self.assertRaises(NativeError):self.validate('observe',{'region':{'x':0,'y':0,'width':257,'height':256},'detail':'cells'},65536)
    def test_desktop_limits_do_not_relax_remote_profile(self):
        p=json.loads((HERE/'profiles/fixture.json').read_text());p['limits'].update({'max_model_calls':4096,'max_tools':8192,'max_output_tokens':131072})
        path=self.root/'profile.json';path.write_text(json.dumps(p))
        self.assertEqual(load_profile(path,fixture_mode=True,desktop=True)['limits']['max_tools'],8192)
        with self.assertRaises(ConfigError):load_profile(path,fixture_mode=True)
    def test_consent_and_frozen_profile_required(self):
        for key,value in [('compute_consent',False),('profile_sha256','0'*64)]:
            f=copy.deepcopy(self.frame);f[key]=value
            with self.assertRaises(ConfigError):start_config(f)
    def test_environment_credential_works_without_getuid_file_refuses(self):
        cfg={'provider':'nvidia_chat','credentials':{'env':'NVIDIA_API_KEY'}}
        with patch.dict('os.environ',{'NVIDIA_API_KEY':'dummy-key-not-real-0123456789'}):self.assertEqual(credential(cfg),'dummy-key-not-real-0123456789')
        path=self.root/'private';path.write_text('dummy-key-not-real-0123456789')
        import workbench_api_agent.config as c
        with patch.object(c.os,'getuid',None,create=True):
            # A non-callable absent-equivalent UID implementation cannot establish ownership.
            cfg['credentials']={'file':str(path)}
            with self.assertRaises(ConfigError):credential(cfg)
    def test_native_stop_bypasses_pending_call_and_requires_ack(self):
        sent=[];b=self.backend(sent.append);cancel=threading.Event();errors=[]
        def ordinary():
            try:b.call('observe',{'region':None,'detail':'counts'},'normal',cancel,1)
            except NativeError as e:errors.append(e.code)
        t=threading.Thread(target=ordinary);t.start()
        while not sent:time.sleep(.001)
        result=[]
        stop=threading.Thread(target=lambda:result.append(b.stop('stop',1)));stop.start()
        while len(sent)<2:time.sleep(.001)
        b.deliver({'id':'stop','receipt':{'status':'retired','owner_receipt':{'status':'stopped','no_further_agent_mutations':True}}})
        stop.join(1);self.assertEqual(result[0]['receipt']['status'],'stopped')
        cancel.set();t.join(1);self.assertIn('host_cancellation_during_native_wait',errors)
        with self.assertRaises(NativeError):b._normalize('stop','x',{'receipt':{'status':'retired'}})
    def test_file_hash_path_and_png_identity(self):
        b=self.backend();raw=png(7);path=self.root/'image.png';path.write_bytes(raw)
        obs={'status':'observed','observation_id':'o','image_status':'matched_post_draw','identity':{'world_generation':3,'world_revision':0,'manual_intent_revision':0,'completed_tick':0},'render_identity':{'tick':0},'native_counts':{'58':7}}
        r=b._normalize('observe','x',{'receipt':obs,'png_file':'image.png','png_sha256':hashlib.sha256(raw).hexdigest()})
        image=b.original_png(r['receipt']['frame'],self.root/'saved.png',1000)
        self.assertEqual(image['sha256'],hashlib.sha256(raw).hexdigest())
        for name in ('../image.png','C:/image.png','a\\image.png'):
            with self.assertRaises(NativeError):b._file(name,'x')
        with self.assertRaises(NativeError):b._file('image.png','0'*64)
    def test_large_raw_diagnostics_file_and_effective_key_redaction(self):
        stream=io.BytesIO();p=Protocol(stream);p.root=self.root;p.secrets=['dummyNvidiaKey']
        p.event('http.response',{'body':'dummyNvidiaKey'+'x'*20000})
        event=json.loads(stream.getvalue());data=(self.root/event['payload_file']).read_bytes()
        self.assertNotIn(b'dummyNvidiaKey',data);self.assertEqual(hashlib.sha256(data).hexdigest(),event['payload_sha256'])
    def test_retry_after_not_shortened_and_date_supported(self):
        self.assertEqual(retry_after({'Retry-After':'61'}),61)
        self.assertIsNone(retry_after({'Retry-After':'inf'}))
        self.assertEqual(retry_after({'Retry-After':'Sun, 06 Nov 1994 08:49:37 GMT'}),0)

    def run_bridge(self,turns=None,refusals=None):
        frames=[];count=0;tick=0;serial=0;native_calls=[]
        p=Protocol(io.BytesIO());app=Desktop(p)
        def identity():return {'world_generation':3,'world_revision':serial,'completed_tick':tick,'manual_intent_revision':0}
        def observed():
            return {'status':'observed','image_status':'matched_post_draw','observation_id':'obs-'+str(serial),
                    'native_counts':{'58':count},'identity':identity(),'render_identity':{'tick':tick}}
        def send(frame):
            nonlocal count,tick,serial
            frames.append(frame)
            if frame['type']!='native_request':return
            tool=frame['tool'];native_calls.append(tool);serial+=1
            if serial in (refusals or {}):raw=copy.deepcopy(refusals[serial])
            elif tool=='stop':raw={'status':'retired','owner_receipt':{'status':'stopped','no_further_agent_mutations':True}}
            elif tool=='observe':raw=observed()
            elif tool=='prepare_edit':raw={'status':'proposed','proposal_id':'prop-'+str(serial),'changed_cells':9 if count==0 else 1,'identity':identity()}
            elif tool=='apply_edit':
                first=count==0;count=9 if first else 8
                rows=[{'x':x,'y':y,'before':0,'after':58,'actual':58} for y in range(30,33) for x in range(30,33)] if first else [{'x':31,'y':31,'before':58,'after':0,'actual':0}]
                raw={'status':'applied','proposal_id':frame['args']['proposal_id'],'confirmed_writes':len(rows),'issued_writes':len(rows),'changed_cells':len(rows),'distinct_cells':len(rows),'readback':rows,'identity_after':identity(),'identity_before':identity()}
            else:
                before=tick;tick+=frame['args']['ticks'];raw={'status':'stepped','requested':frame['args']['ticks'],'completed':frame['args']['ticks'],'before_tick':before,'after_tick':tick,'still_paused':True,'observation':observed()}
            reply={'type':'native_result','id':frame['id'],'receipt':raw}
            if tool in ('observe','step'):reply['framebuffer_png_base64']=base64.b64encode(png(count)).decode()
            app.receive(reply)
        p.send=send
        if turns is not None:self.frame['fixture_turns']=turns
        app.receive(self.frame)
        self.assertTrue(app.finished.wait(5),'desktop fixture timed out')
        return app,frames,native_calls

    def test_same_runner_complete_scripted_bridge_original_frames_and_stop(self):
        app,frames,calls=self.run_bridge()
        self.assertEqual(app.runner.report['status'],'passed',app.runner.report['reason'])
        self.assertTrue(app.runner.report['stop_acknowledged'])
        self.assertEqual(calls,['observe','prepare_edit','apply_edit','observe','prepare_edit','apply_edit','observe','step','stop'])
        self.assertEqual(len(list((self.root/'runner-evidence/frames').glob('*.png'))),4)
        self.assertTrue(all('projection' in h.get('native',{}) for h in app.runner.history if h['kind']=='result'))
        self.assertEqual(frames[-1]['type'],'finished')
    def test_one_local_validation_refusal_then_corrected_call_no_native_replay(self):
        turns=[{'tool':'observe','args':{'region':'bad','detail':'cells'}},
               {'tool':'observe','args':{'region':None,'detail':'counts'}},{'final':'done'}]
        app,frames,calls=self.run_bridge(turns)
        self.assertEqual(calls,['observe','stop'])
        self.assertEqual(app.runner.stats.tool_calls,2)
        self.assertTrue(any(h.get('native',{}).get('native_dispatched') is False for h in app.runner.history))
    def test_repeated_argument_errors_stop_at_total_tool_budget(self):
        self.frame['overrides']['max_tools']=2
        turns=[{'tool':'observe','args':{'region':'bad','detail':'cells'}}]*3
        app,_,calls=self.run_bridge(turns)
        self.assertEqual(calls,['stop']);self.assertEqual(app.runner.report['reason'],'tool_call_limit')
    def test_parent_disconnect_releases_wait_without_success(self):
        b=self.backend();errors=[]
        def wait():
            try:b.call('observe',{},'one',threading.Event(),5)
            except NativeError as e:errors.append(e.code)
        t=threading.Thread(target=wait);t.start();time.sleep(.02);b.fail();t.join(1)
        self.assertEqual(errors,['desktop_parent_disconnected'])

    def test_actual_jsonl_child_stop_while_native_request_pending(self):
        child=subprocess.Popen([sys.executable,'-u',str(HERE/'desktop.py')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        messages=queue.Queue()
        reader=threading.Thread(target=lambda:[messages.put(json.loads(line)) for line in child.stdout],daemon=True);reader.start()
        def send(frame):child.stdin.write(json.dumps(frame).encode()+b'\n');child.stdin.flush()
        def next_kind(kind):
            while True:
                f=messages.get(timeout=5)
                if f['type']==kind:return f
        try:
            send(self.frame);normal=next_kind('native_request');self.assertEqual(normal['tool'],'observe')
            send({'type':'stop','reason':'unit-human-stop'});stop=next_kind('native_request');self.assertEqual(stop['tool'],'stop')
            send({'type':'native_result','id':stop['id'],'receipt':{'status':'retired','owner_receipt':{'status':'stopped','no_further_agent_mutations':True}}})
            final=None
            while final is None:
                f=messages.get(timeout=5)
                if f['type']=='native_request':self.fail('native Stop was replayed')
                if f['type']=='finished':final=f
            self.assertTrue(final['receipt']['stop_acknowledged']);self.assertNotEqual(final['receipt']['status'],'passed')
            child.wait(timeout=5)
        finally:
            if child.poll() is None:child.kill();child.wait(timeout=5)
            child.stdin.close();child.stdout.close();child.stderr.close()

    def test_retry_minimum_and_actual_attempt_budget(self):
        from .controller import Runner,LimitError
        from .test_runner import FakeNative
        cfg=load_profile(HERE/'profiles/fixture.json',fixture_mode=True,desktop=True)
        cfg['limits'].update({'max_model_calls':2,'max_retries':2,'max_total_retries':2,'tokens_per_minute':1000000})
        native=FakeNative();native.desktop=True
        class Rate:
            def __init__(self,delay):self.delay=delay;self.calls=0
            def request(self,*_):self.calls+=1;raise ProviderError('provider_rate_limit',429,self.delay)
        rate=Rate(61)
        r=Runner(cfg,{'instructions':'test','acceptance':{}},self.auth,native,self.root/'unused',adapter=rate,fixture_mode=True)
        r.history=[{'kind':'user','text':'test'}];r.output.mkdir()
        with self.assertRaisesRegex(LimitError,'not_shortened'):r._provider()
        self.assertEqual(rate.calls,1)
        rate=Rate(0)
        r=Runner(cfg,{'instructions':'test','acceptance':{}},self.auth,native,self.root/'unused2',adapter=rate,fixture_mode=True,rate_wait=lambda _:False)
        r.history=[{'kind':'user','text':'test'}];r.output.mkdir()
        with self.assertRaisesRegex(LimitError,'model_call_limit'):r._provider()
        self.assertEqual(rate.calls,2);self.assertEqual(r.stats.provider_attempts,2);self.assertEqual(native.commands,[])

    def test_rate_wait_stop_prevents_late_http_and_exports_reservations(self):
        from .controller import Runner
        from .test_runner import FakeNative
        cfg=load_profile(HERE/'profiles/fixture.json',fixture_mode=True,desktop=True)
        cfg['limits'].update({'tokens_per_minute':50000,'max_output_tokens':1024})
        native=FakeNative();native.desktop=True
        class Never:
            calls=0
            def request(self,*_):self.calls+=1;raise AssertionError('late HTTP')
        adapter=Never();event=threading.Event()
        def cancel(_):event.set();return True
        events=[]
        r=Runner(cfg,{'instructions':'test','acceptance':{}},self.auth,native,self.root/'wait',adapter=adapter,fixture_mode=True,stop_event=event,rate_wait=cancel,event_callback=lambda name,payload:events.append((name,payload)))
        r.output.mkdir();r.history=[{'kind':'user','text':'test'}]
        r._rate_reservations=[{'at':time.monotonic(),'tokens':50000}]
        with self.assertRaises(NativeError):r._provider()
        self.assertEqual(adapter.calls,0);self.assertEqual(len(r._rate_history()),1)
        self.assertTrue(any(name=='rate.wait' and value['reserved_tokens']==50000 for name,value in events))

    def test_local_native_evidence_does_not_inflate_model_text_or_reservation(self):
        from .controller import Runner
        from .providers import request_body
        from .test_runner import FakeNative
        from atlas_agent.errors import LimitReached
        cfg=load_profile(HERE/'profiles/fixture.json',fixture_mode=True,desktop=True)
        r=Runner(cfg,{'instructions':'test','acceptance':{}},self.auth,FakeNative(),self.root/'counting',fixture_mode=True)
        r.history=[{'kind':'user','text':'inspect native facts'},
                   {'kind':'result','id':'call1','text':'selected native count58=8','native':{'native_counts':{'58':8}}}]
        before=r._history_safeguard()[0];first=r._reserve();r.budget.release(first)
        original={'local_only_sentinel':'x'*3000000,'readback':[{'x':n,'actual':58} for n in range(65536)]}
        r.history[-1]['native']=original;r.history[-1]['receipt_sha256']='a'*64
        self.assertEqual(r._history_safeguard()[0],before)
        second=r._reserve();self.assertEqual(second.input_tokens,first.input_tokens);r.budget.release(second)
        body=request_body(cfg,r.history,include_image_bytes=False)
        self.assertNotIn('local_only_sentinel',json.dumps(body));self.assertIs(r.history[-1]['native'],original)
        self.assertIn('selected native count58=8',json.dumps(body));self.assertIn('tools',body)
        r.history[0]['text']='x'*30000
        with self.assertRaises(LimitReached) as raised:r._reserve()
        self.assertEqual(raised.exception.reason_code,'max_input_tokens_per_call')

    def test_forged_apply_and_missing_original_image_fail_closed(self):
        b=self.backend()
        for raw in ({'status':'applied','confirmed_writes':9},
                    {'status':'applied','confirmed_writes':9,'identity_after':{'world_generation':3,'world_revision':1,'completed_tick':0,'manual_intent_revision':0}}):
            with self.assertRaises(NativeError):b._normalize('apply_edit','bad',{'receipt':raw})
        ident={'world_generation':3,'world_revision':1,'completed_tick':0,'manual_intent_revision':0}
        raw={'status':'applied','identity_before':ident,'identity_after':ident,'confirmed_writes':1,'issued_writes':1,'changed_cells':1,'distinct_cells':1,'readback':[{'x':30,'y':30,'before':0,'after':58,'actual':0}]}
        with self.assertRaisesRegex(NativeError,'not_authoritative'):b._normalize('apply_edit','bad',{'receipt':raw})
        with self.assertRaises(NativeError):b._normalize('observe','bad',{'receipt':{'status':'observed','identity':ident}})

    def test_effective_provider_key_and_image_data_never_enter_trace(self):
        cfg=load_profile(HERE/'profiles/fixture.json',fixture_mode=True);events=[]
        a=HTTPAdapter(cfg,fixture_mode=True,trace=lambda e,p:events.append((e,p)));a.key='dummy-NVIDIA-file-key'
        a._trace('http.response',{'body':'malformed '+a.key,'Authorization':a.key,'image':'data:image/png;base64,'+base64.b64encode(png(2)).decode()})
        encoded=json.dumps(events);self.assertNotIn(a.key,encoded);self.assertNotIn('data:image/',encoded);self.assertIn('image_bytes',encoded)

    def test_finished_large_history_uses_hashed_reference(self):
        p=Protocol(io.BytesIO());p.root=self.root
        p.finished({'status':'stopped','rate_history':[{'expires_utc':time.time()+30,'tokens':1}]*1000})
        f=json.loads(p.output.getvalue());data=(self.root/f['receipt_file']).read_bytes()
        self.assertEqual(hashlib.sha256(data).hexdigest(),f['receipt_sha256']);self.assertTrue(f['receipt_file'].startswith('reports/'))

    def test_preflight_failure_still_requests_real_native_stop(self):
        frames=[];p=Protocol(io.BytesIO());app=Desktop(p)
        def send(f):
            frames.append(f)
            if f['type']=='native_request':app.receive({'type':'native_result','id':f['id'],'receipt':{'status':'retired','owner_receipt':{'status':'stopped','no_further_agent_mutations':True}}})
        p.send=send;self.frame['profile_sha256']='0'*64;app.receive(self.frame)
        self.assertTrue(app.finished.wait(2));self.assertEqual([x['tool'] for x in frames if x['type']=='native_request'],['stop']);self.assertTrue(frames[-1]['receipt']['stop_acknowledged'])

    def test_large_scope_observation_capacity_is_explained_and_repeated_errors_recover(self):
        self.frame['task']['scope']={'x':0,'y':0,'width':160,'height':320}
        self.frame['task']['cell_limit']=16384
        self.frame['session']['authorization_receipt']['cell_limit']=16384
        turns=[{'tool':'observe','args':{'region':{'x':0,'y':0,'width':160,'height':h},'detail':'cells'}} for h in (320,160)]
        turns += [{'tool':'observe','args':{'region':None,'detail':'cells'}},{'final':'recovered'}]
        app,_,calls=self.run_bridge(turns)
        self.assertEqual(calls,['observe','stop'])
        feedback=[h['native'] for h in app.runner.history if h['kind']=='result' and h.get('native',{}).get('native_dispatched') is False]
        self.assertEqual(len(feedback),2)
        for f in feedback:
            self.assertEqual(f['reason'],'observe_cell_limit_exceeded')
            self.assertEqual(f['cell_limit'],16384)
            self.assertIsNone(f['recommended_arguments']['region'])
        self.assertEqual(app.runner.report['model_final_unverified_report'],'recovered')
        self.assertTrue(app.runner.report['stop_acknowledged'])
        self.assertEqual(json.loads(app.runner.history[0]['text'].split('Native permissions (host-enforced): ')[1].split('\n')[0])['cell_limit'],16384)
