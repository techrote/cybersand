"""Keyless deterministic A-gate (mock provider/native ONLY; B is separate)."""
from __future__ import annotations
import copy
import hashlib
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
import json
from pathlib import Path
import struct
import tempfile
import threading
import time
import unittest
import zlib

from workbench_api_agent.config import load_profile,ConfigError
from workbench_api_agent.controller import trusted_task
from workbench_api_agent.backend import validate_tool,NativeError,Workbench
from workbench_api_agent.providers import (Decision,parse_response,ProviderError,HTTPAdapter,
    ScriptedAdapter,parse_json,render_history_response,render_history_chat)
from workbench_api_agent.controller import Runner
HERE=Path(__file__).resolve().parent

def png(red):
    def chunk(name,data):return struct.pack('>I',len(data))+name+data+struct.pack('>I',zlib.crc32(name+data)&0xffffffff)
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',1,1,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(bytes([0,red,5,5,255])))+chunk(b'IEND',b'')

class FakeNative:
    # Only for controller unit tests; never credited as real native acceptance.
    def __init__(self):
        self.session_id=None;self.generation_id=None;self.commands=[];self.count=0;self.tick=0
        self.stop_called=threading.Event();self.process_alive=True;self.generation=3
    def open(self):
        self.session_id='mock-native-sid';self.generation_id='mock-native-sid:3'
        return {'phase':'ready','session_id':self.session_id,'generation_id':self.generation_id,'native_generation':3}
    def call(self,tool,args,rid,stop_event,deadline):
        self.commands.append((tool,args,rid))
        seq=len(self.commands)
        result={'status':{'observe':'observed','prepare_edit':'proposed','apply_edit':'applied','step':'completed'}[tool],
                'identity':{'render_world_generation':3,'native_revision':seq}}
        if tool=='observe':
            result['observation_id']='obs-'+str(seq)
            result['native_counts']={'58':self.count}
        elif tool=='prepare_edit':result['proposal_id']='prop-'+str(seq)
        elif tool=='apply_edit':
            self.count=9 if self.count==0 else 8
            result['confirmed_writes']=9 if self.count==9 else 1
        elif tool=='step':self.tick+=args['ticks'];result['completed']=args['ticks']
        frame={'status':'none'}
        if tool in ('observe','step'):
            data=png(self.count)
            frame={'status':'original_post_draw','path':f'frames/{seq:03d}-{tool}.png',
                   'sha256':hashlib.sha256(data).hexdigest(),'width':1,'height':1}
        return {'state':'complete','receipt':{'tool':tool,'status':result['status'],'result':result,
             'frame':frame,'completed_native_ticks_total':self.tick},'request_id':rid}
    def original_png(self,frame,out,max_bytes):
        out.parent.mkdir(parents=True,exist_ok=True);data=png(self.count)
        out.write_bytes(data)
        return {'path':str(out),'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),'width':1,'height':1}
    def stop(self,rid,deadline):
        self.stop_called.set();self.process_alive=False
        return {'state':'complete','receipt':{'status':'stopped','tool':'stop','result':{'status':'stopped'},'frame':{'status':'none'}}}

class ScriptedTests(unittest.TestCase):
    def setUp(self):
        self.t=tempfile.TemporaryDirectory()
        self.root=Path(self.t.name)
        self.profile=load_profile(HERE/'profiles/fixture.json',fixture_mode=True)
        self.task,self.auth=trusted_task(HERE/'fixtures/nine-then-eight.task.json',HERE/'fixtures/roundtrip-authorization.json')
        self.turns=json.loads((HERE/'fixtures/nine-then-eight.fixture.json').read_text())
        self.native=FakeNative()
    def tearDown(self):self.t.cleanup()
    def runner(self,cfg=None,turns=None):
        return Runner(cfg or self.profile,self.task,self.auth,self.native,self.root/'result',
             adapter=ScriptedAdapter(turns or self.turns),fixture_mode=True)
    def test_full_fixture_is_NOT_model_or_native_qualification(self):
        result=self.runner().run()
        self.assertEqual(result['status'],'passed',result['reason'])
        self.assertEqual([x[0] for x in self.native.commands],
                         ['observe','prepare_edit','apply_edit','observe',
                          'prepare_edit','apply_edit','observe','step'])
        self.assertTrue(self.native.stop_called.is_set())
        self.assertTrue(result['native_acceptance']['passed'])
        self.assertEqual(result['native_acceptance']['native_counts']['58']['actual'],8)
        self.assertEqual(result['measured']['native_ticks'],4)
        self.assertTrue(result['measured']['model_seen_image'])
        self.assertTrue((self.root/'result/receipt.json').exists())
        self.assertEqual(len(list((self.root/'result/frames').glob('*.png'))),4)

    def test_compact_success_keeps_full_evidence_outside_model_context(self):
        runner=self.runner()
        for tool,status,rows in (('prepare_edit','proposed','footprint'),('apply_edit','applied','readback')):
            native={'status':status,'proposal_id':'p1','changed_cells':990,'distinct_cells':990,
                    'excluded_operations':0,'identity':{'world_generation':3,'world_revision':8},
                    rows:[{'x':x,'y':0,'before':0,'after':58,'actual':58} for x in range(990)]}
            if tool=='apply_edit':native['confirmed_writes']=990
            receipt={'tool':tool,'status':status,'result':native,'completed_native_ticks_total':0}
            original=copy.deepcopy(receipt)
            summary,retained=runner._native_summary({'receipt':receipt})
            message=json.loads(runner._project(summary))
            expected={'status':status,'changed_cells':990}
            if tool=='prepare_edit':expected['proposal_id']='p1'
            else:expected['confirmed_writes']=990
            self.assertEqual(message,expected)
            self.assertLess(len(runner._project(summary)),100)
            self.assertIs(retained,receipt);self.assertEqual(retained,original)
            self.assertIn('original_receipt_sha256',summary)

    def test_compact_exceptions_and_nonchanging_cells_remain_explicit(self):
        runner=self.runner()
        native={'status':'proposed','proposal_id':'p','changed_cells':0,'distinct_cells':9,
                'excluded_operations':2,'reason':'source_material_excluded'}
        self.assertEqual(json.loads(runner._project(native)),native)
        refusal={'status':'refused','reason':'stale_observation','identity':{'revision':3}}
        self.assertEqual(json.loads(runner._project(refusal)),refusal)
        applied={'status':'applied','confirmed_writes':18,'changed_cells':9}
        self.assertEqual(json.loads(runner._project(applied)),applied)

    def test_observation_and_step_retain_model_navigation_and_rare_materials(self):
        runner=self.runner()
        obs={'status':'observed','observation_id':'o1','native_counts':{'0':23,'58':9,'1':32},
             'region':{'x':0,'y':0,'width':8,'height':8},
             'viewport_native_region':{'x':0,'y':0,'width':16,'height':16},
             'viewport_framebuffer_rect':{'x':5,'y':5,'width':160,'height':160},
             'palette':[{'id':0,'name':'Empty'},{'id':58,'name':'Hard Wall'},
                        {'id':1,'name':'Sand'},{'id':2,'name':'Water'}],
             'identity':{'world_revision':2},'original_receipt_sha256':'a'*64}
        result=json.loads(runner._project(obs))
        for k in ('observation_id','native_counts','region','viewport_native_region','viewport_framebuffer_rect'):
            self.assertEqual(result[k],obs[k])
        self.assertEqual(result['palette'],[{'id':1,'name':'Sand'}])
        self.assertNotIn('identity',result);self.assertNotIn('original_receipt_sha256',result)
        step=json.loads(runner._project({'status':'completed','completed':4,
            'completed_native_ticks_total':12,'observation':obs}))
        self.assertEqual(step['completed'],4);self.assertEqual(step['completed_native_ticks_total'],12)
        self.assertEqual(step['observation']['observation_id'],'o1')
        from .controller import LimitError
        runner.limit=runner.limit|{'max_tool_result_bytes':80}
        with self.assertRaisesRegex(LimitError,'native_projection_capacity'):runner._project(obs)
        self.assertEqual(obs['original_receipt_sha256'],'a'*64)

    def test_old_image_markers_are_short_and_model_audit_metadata_is_absent(self):
        from .providers import request_body
        runner=self.runner();report=runner.run()
        self.assertEqual(report['status'],'passed')
        text=json.dumps(request_body(runner.cfg,runner.history,include_image_bytes=False))
        self.assertEqual(text.count('[Earlier image omitted.]'),3)
        self.assertNotIn('original_receipt_sha256',text)
        self.assertNotIn('selected_native_fields',text)
        self.assertNotIn('EARLIER ORIGINAL PNG',text)
        self.assertEqual(len(report['native_receipts']),8)
        self.assertEqual(sum(r['original_png'] is not None for r in report['native_receipts']),4)
        for r in report['native_receipts']:
            if r['original_png']:self.assertTrue(Path(r['original_png']['path']).is_file())

    def test_summary_capacity_failure_retains_native_receipt_and_stops(self):
        cfg=copy.deepcopy(self.profile);cfg['limits']['max_tool_result_bytes']=1
        report=self.runner(cfg=cfg).run()
        self.assertEqual(report['reason'],'native_projection_capacity')
        self.assertTrue(report['stop_acknowledged'])
        self.assertEqual(len(report['native_receipts']),1)
        self.assertEqual(report['native_receipts'][0]['receipt']['status'],'observed')
        self.assertTrue(Path(report['native_receipts'][0]['original_png']['path']).is_file())
    def test_validations_refuse_before_mutation(self):
        scope=self.auth['scope']
        with self.assertRaises(NativeError):validate_tool('step',{'ticks':True},scope,{0,58},[],None,None,0,120)
        with self.assertRaises(NativeError):validate_tool('prepare_edit',{'observation_id':'obs','operations':[
           {'shape':'rectangle','x0':10,'y0':10,'x1':11,'y1':11,'material':58}]},scope,{0,58},[], 'obs',None,0,120)
        with self.assertRaises(NativeError):validate_tool('observe',{'detail':'cells','region':{'x':20,'y':20,'width':8,'height':8}},scope,{0,58},[],None,None,0,120)
        with self.assertRaises(NativeError):validate_tool('prepare_edit',{'observation_id':'obs','operations':[
           {'shape':'rectangle','x0':66,'y0':66,'x1':66,'y1':66,'material':58}]},scope,{0,58},self.auth['protected'], 'obs',None,0,120)
        with self.assertRaises(NativeError):validate_tool('foo',{},scope,{0,58},[],None,None,0,120)
    def test_count_mismatch_prevents_revision_and_stops(self):
        self.turns[4]['require_native_counts']['58']=99
        report=self.runner(turns=self.turns).run()
        self.assertEqual(report['status'],'stopped_or_failed')
        self.assertTrue(report['stop_acknowledged'])
        self.assertNotIn('step',[t[0] for t in self.native.commands])
    def test_model_budget_exhaustion_stops(self):
        cfg=copy.deepcopy(self.profile);cfg['limits']['max_model_calls']=2
        r=self.runner(cfg=cfg).run()
        self.assertEqual(r['status'],'stopped_or_failed')
        self.assertIn('model_call_limit',r['reason'])
        self.assertTrue(self.native.stop_called.is_set())
    def test_atlas_reserved_budget_failure_still_stops_native(self):
        from atlas_agent.errors import LimitReached
        runner=self.runner()
        def blocked():raise LimitReached('bound exceeded','max_total_input_tokens')
        runner.budget.start_iteration=blocked
        report=runner.run()
        self.assertTrue(report['stop_acknowledged'])
        self.assertEqual(report['reason'],'max_total_input_tokens')
        self.assertEqual(self.native.commands,[])
    def test_unexpected_provider_exception_still_stops_native(self):
        class BrokenProvider:
            def request(self,*args):raise IndexError('bad provider internal output shape')
        runner=Runner(self.profile,self.task,self.auth,self.native,self.root/'result',
                      adapter=BrokenProvider(),fixture_mode=True)
        report=runner.run()
        self.assertEqual(report['status'],'internal_failure')
        self.assertTrue(report['stop_acknowledged'])
        self.assertEqual(report['reason'],'runner_internal_IndexError')
        self.assertNotIn('bad provider', (self.root/'result/receipt.json').read_text())
    def test_model_cannot_step_with_prepared_proposal(self):
        steps=self.turns[:2]+[{'tool':'step','args':{'ticks':4}}]
        report=self.runner(turns=steps).run()
        self.assertEqual(report['status'],'stopped_or_failed')
        self.assertIn('prepared_edit',report['reason'])
        self.assertEqual(len(self.native.commands),2)
    def test_concurrent_stop_bypasses_blocked_provider(self):
        gate=threading.Event();entered=threading.Event()
        class Blocked:
            def request(self,*a):
                entered.set();gate.wait(5)
                raise ProviderError('cancelled_fixture_provider')
        runner=Runner(self.profile,self.task,self.auth,self.native,self.root/'result',
                      adapter=Blocked(),fixture_mode=True)
        thread=threading.Thread(target=runner.run,daemon=True);thread.start()
        self.assertTrue(entered.wait(4))
        runner.request_host_stop_async()
        self.assertTrue(self.native.stop_called.wait(1),'Stop was blocked on provider call')
        gate.set();thread.join(5);self.assertFalse(thread.is_alive())

class ProviderProtocolTests(unittest.TestCase):
    def setUp(self):
        self.t=tempfile.TemporaryDirectory();self.root=Path(self.t.name)
        p=self.root/'observation.png';p.write_bytes(png(7))
        self.image={'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
                    'width':1,'height':1}
        self.history=[{'kind':'user','text':'observe then inspect'},
                      {'kind':'call','tool':'observe','args':{'region':{'x':28,'y':28,'width':8,'height':8},'detail':'cells'},'id':'abc_1'},
                      {'kind':'result','id':'abc_1','text':'native wall count 9','image':self.image}]
    def tearDown(self):self.t.cleanup()
    def test_openai_stateless_tool_and_original_image(self):
        a=render_history_response(self.history,100000,'low')
        self.assertEqual(a[-1]['type'],'function_call_output')
        self.assertEqual(a[-1]['output'][1]['type'],'input_image')
        self.assertTrue(a[-1]['output'][1]['image_url'].startswith('data:image/png;base64,'))
        doc={'model':'gpt-6-luna','status':'completed','output':[{'type':'function_call',
             'call_id':'call_01','name':'step','arguments':'{"ticks":4}'}],
             'usage':{'input_tokens':200,'output_tokens':30}}
        d=parse_response(doc,'openai_responses','gpt-6-luna',seen=True)
        self.assertEqual((d.kind,d.tool,d.args),( 'tool','step',{'ticks':4}))
        self.assertTrue(d.saw_image)
    def test_nvidia_and_ollama_chat_shapes(self):
        rendered=render_history_chat(self.history,100000,'low')
        self.assertEqual(rendered[-1]['role'],'user')
        self.assertEqual(rendered[-1]['content'][1]['type'],'image_url')
        for model in ('nvidia-vision-model-fixture','qwen3-vl:8b'):
            doc={'model':model,'choices':[{'finish_reason':'tool_calls','message':{'content':None,
                 'tool_calls':[{'id':'call_X','type':'function','function':{'name':'step','arguments':'{"ticks":4}'}}]}}],
                 'usage':{'prompt_tokens':300,'completion_tokens':40}}
            d=parse_response(doc,'nvidia_chat' if model.startswith('nvidia') else 'ollama_chat',model)
            self.assertEqual((d.kind,d.call_id,d.args),('tool','call_X',{'ticks':4}))
    def test_parallel_truncated_or_prose_json_no_tool(self):
        call={'type':'function_call','call_id':'x','name':'step','arguments':'{"ticks":4}'}
        with self.assertRaises(ProviderError):parse_response({'status':'completed','output':[call,call]},'openai_responses','m')
        with self.assertRaises(ProviderError):parse_response({'choices':[{'finish_reason':'length','message':{'tool_calls':[],'content':'hi'}}]},'nvidia_chat','m')
        d=parse_response({'status':'completed','output':[{'type':'message','content':[{'type':'output_text','text':'{"tool":"step"}'}]}]},'openai_responses','m')
        self.assertEqual(d.kind,'final')
        with self.assertRaises(ProviderError):parse_json('{"ticks":1,"ticks":2}')
        with self.assertRaises(ProviderError):parse_response({'status':'incomplete','output':[call]},'openai_responses','m')
    def test_openai_private_file_key_uses_unmodified_atlas_credit_gate(self):
        import os
        import workbench_api_agent.config as configuration
        cfg=load_profile(HERE/'profiles/openai-responses.example.json',fixture_mode=True)
        with tempfile.TemporaryDirectory() as folder:
            secret=Path(folder)/'key'
            secret.write_text('only-test-secret-not-a-real-cloud-key-0123456789',encoding='utf-8')
            secret.chmod(0o600)
            cfg['credentials']={'file':str(secret)}
            cfg['spend'].update({'max_usd_per_run':0.25,'max_usd_per_call':0.05,
                                 'authorised_ceiling_usd':0.25,'authorisation_ref':'explicit-test-only'})
            seen=[]
            original_eval=configuration.atlas_credit_evaluate
            original_enforce=configuration.atlas_credit_enforce
            original_rates=configuration.pricing_rates
            configuration.pricing_rates=lambda v:configuration.Rates(
                v['model'],0.1,0.1,0.5,1000000,True,
                {'method':'patch','patch_size':32,'patch_budget':{'low':30000,'high':30000,'auto':30000},'multiplier':2.46},
                'test-fixture','test-only',120000)
            def check_atlas_gate(gate_cfg,env,*a,**k):
                seen.append((gate_cfg['api']['key_env'],env['CYBERSAND_WB_OPENAI_KEY']))
                return {'passed':True,'checks':[],'facts':{},'rates':None}
            configuration.atlas_credit_evaluate=check_atlas_gate
            configuration.atlas_credit_enforce=lambda report:None
            try:
                from workbench_api_agent.config import validate_live
                budget,gate=validate_live(cfg,allow_live=True,fixture_mode=False,
                                          probe=lambda model:{'status':200,'headers':{}},
                                          source_dirty=False)
            finally:
                configuration.atlas_credit_evaluate=original_eval
                configuration.atlas_credit_enforce=original_enforce
                configuration.pricing_rates=original_rates
            self.assertEqual(seen,[('CYBERSAND_WB_OPENAI_KEY',secret.read_text())])
            self.assertNotIn('CYBERSAND_WB_OPENAI_KEY',os.environ)
            self.assertEqual(gate['mode'],'live')
    def test_profiles_keyless_validation(self):
        for name in ('openai-responses.example.json','nvidia-catalog.example.json',
                     'ollama-qwen3-vl-8b.example.json','fixture.json'):
            self.assertIn('capabilities',load_profile(HERE/'profiles'/name,fixture_mode=True))
        cfg=load_profile(HERE/'profiles/fixture.json',fixture_mode=True)
        cfg['capabilities']['images']=False
        temp=self.root/'bad.json';temp.write_text(json.dumps(cfg))
        with self.assertRaises(ConfigError):load_profile(temp,fixture_mode=True)

class LiveHTTPFixtureTests(unittest.TestCase):
    """Actual localhost HTTP request serialization, mocked MODEL responses."""
    def setUp(self):
        self.captured=[];self.reply={}
        outer=self
        class Server(BaseHTTPRequestHandler):
            def log_message(self,*args):pass
            def do_POST(self):
                n=int(self.headers.get('Content-Length','0'))
                outer.captured.append((self.path,json.loads(self.rfile.read(n))))
                raw=json.dumps(outer.reply).encode()
                self.send_response(200);self.send_header('Content-Type','application/json')
                self.send_header('Content-Length',str(len(raw)));self.end_headers();self.wfile.write(raw)
        self.server=ThreadingHTTPServer(('127.0.0.1',0),Server)
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start()
        self.root=tempfile.TemporaryDirectory()
        p=Path(self.root.name)/'frame.png';p.write_bytes(png(77))
        self.history=[{'kind':'user','text':'inspect latest original screenshot'},
                      {'kind':'result','id':'prior','text':'native count 9',
                       'image':{'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
                                'width':1,'height':1}}]
    def tearDown(self):
        self.server.shutdown();self.server.server_close();self.thread.join(3);self.root.cleanup()
    def cfg(self,name,provider):
        profile=load_profile(HERE/'profiles'/name,fixture_mode=True)
        profile['provider']=provider
        profile['model']='gpt-6-luna' if provider=='openai_responses' else ('test-nvidia' if provider=='nvidia_chat' else 'qwen3-vl:8b')
        profile['endpoint']=f'http://127.0.0.1:{self.server.server_port}/v1/'+('responses' if provider=='openai_responses' else 'chat/completions')
        return profile
    def test_http_openai_image_and_function_call(self):
        cfg=self.cfg('openai-responses.example.json','openai_responses')
        self.reply={'model':'gpt-6-luna','status':'completed','output':[{'type':'function_call',
              'name':'step','arguments':'{"ticks":4}','call_id':'response_call_A'}],
              'usage':{'input_tokens':150,'output_tokens':30}}
        got=HTTPAdapter(cfg,fixture_mode=True).request(self.history,2000000,5)
        self.assertEqual(got.tool,'step')
        path,payload=self.captured[0]
        self.assertEqual(path,'/v1/responses')
        self.assertFalse(payload['store'])
        self.assertNotIn('previous_response_id',payload)
        image=next(item for item in payload['input'][-1]['output'] if item.get('type')=='input_image')
        self.assertTrue(image['image_url'].startswith('data:image/png;base64,'))
    def test_http_nvidia_and_ollama_image_and_function_call(self):
        for provider,name in (('nvidia_chat','nvidia-catalog.example.json'),
                              ('ollama_chat','ollama-qwen3-vl-8b.example.json')):
            cfg=self.cfg(name,provider)
            self.reply={'model':cfg['model'],'choices':[{'finish_reason':'tool_calls','message':{'content':None,
                 'tool_calls':[{'id':'chat_call_A','type':'function','function':{'name':'step','arguments':'{"ticks":4}'}}]}}],
                 'usage':{'prompt_tokens':160,'completion_tokens':20}}
            got=HTTPAdapter(cfg,fixture_mode=True).request(self.history,2000000,5)
            self.assertEqual((got.kind,got.args),('tool',{'ticks':4}))
            path,payload=self.captured[-1]
            self.assertEqual(path,'/v1/chat/completions')
            self.assertEqual(payload['model'],cfg['model'])
            self.assertTrue(payload['messages'][-1]['content'][1]['image_url']['url'].startswith('data:image/png;base64,'))
            self.assertNotIn('previous_response_id',payload)
            self.assertNotIn('response_format',payload)


class NativeUncertaintyTests(unittest.TestCase):
    def test_http_post_connection_error_queries_same_id_without_new_post(self):
        import workbench_api_agent.backend as backend
        originals=backend.api
        requests=[]
        def api(base,token,method,path,**kwargs):
            requests.append((method,path))
            if method=='POST':raise TimeoutError('message might have reached owner')
            if path.startswith('/v1/requests/'):
                return 202,{'state':'pending','request_id':'native-id'}
            return 200,{'phase':'ready','session_id':'native-sid','generation_id':'native-sid:3','native_generation':3}
        backend.api=api
        try:
            with tempfile.TemporaryDirectory(prefix='wbapi-test-token-') as temp:
                owner_token=Path(temp)/'workbench-token'
                owner_token.write_text('m'*48,encoding='utf-8')
                owner_token.chmod(0o600)
                wb=Workbench('http://127.0.0.1:8765',owner_token,1)
            wb.open()
            code,doc=wb._submit('apply_edit',{'proposal_id':'p'},'native-id')
            self.assertEqual((code,doc['state']),(202,'pending'))
            self.assertEqual(sum(x[0]=='POST' for x in requests),1)
            self.assertEqual(requests[-1],('GET','/v1/requests/native-id'))
        finally:backend.api=originals

if __name__=='__main__':unittest.main()
