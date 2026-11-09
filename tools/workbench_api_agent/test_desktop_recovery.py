"""Synthetic refusal recovery and per-request rate allowance; no paid services."""
from __future__ import annotations
import copy,json,tempfile,time,threading,unittest
from pathlib import Path
from unittest.mock import patch
from .backend import NativeError
from .config import load_profile
from .controller import Runner
from .desktop import start_config
from .desktop_backend import DesktopWorkbench,DESKTOP_NATIVE_PALETTE,desktop_tool_schemas,validate_desktop_tool
from .providers import HTTPAdapter,ScriptedAdapter,Decision,ProviderError
from . import test_desktop as desktop_tests
from .test_desktop import start_frame
from .test_runner import FakeNative
from .usage_budget import UsageBudget

HERE=Path(__file__).parent


class DesktopRecoveryTests(unittest.TestCase):
    run_bridge=desktop_tests.DesktopTests.run_bridge
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        self.frame=start_frame(self.root);self.auth=start_config(self.frame)[2]
        self.turns=json.loads((HERE/'fixtures/nine-then-eight.fixture.json').read_text())
    def tearDown(self):self.temp.cleanup()

    def test_protected_native_prepare_refusal_returns_reason_then_model_corrects(self):
        turns=self.turns[:2]+copy.deepcopy(self.turns)
        app,_,calls=self.run_bridge(turns,{2:{'status':'refused','reason':'source_material_protected'}})
        self.assertEqual(app.runner.report['status'],'passed',app.runner.report['reason'])
        feedback=next(h for h in app.runner.history if h['kind']=='result' and h.get('native',{}).get('reason')=='source_material_protected')
        self.assertEqual(json.loads(feedback['text']),{'status':'refused','reason':'source_material_protected',
            'mutation':'none','next_action':'correct_operations_or_observe'})
        self.assertEqual(calls.count('apply_edit'),2)
        self.assertTrue(app.runner.report['stop_acknowledged'])
        self.assertEqual(len(app.runner.report['native_receipts']),10)

    def test_refused_apply_retires_handles_fresh_observe_then_corrects_without_replay(self):
        turns=self.turns[:3]+copy.deepcopy(self.turns)
        app,_,calls=self.run_bridge(turns,{3:{'status':'refused','reason':'source_cells_changed','proposal_id':'prop-2'}})
        self.assertEqual(app.runner.report['status'],'passed',app.runner.report['reason'])
        feedback=next(h for h in app.runner.history if h['kind']=='result' and h.get('native',{}).get('reason')=='source_cells_changed')
        self.assertEqual(json.loads(feedback['text'])['next_action'],'observe')
        self.assertEqual(calls[:5],['observe','prepare_edit','apply_edit','observe','prepare_edit'])
        applies=[h['args']['proposal_id'] for h in app.runner.history if h['kind']=='call' and h['tool']=='apply_edit']
        self.assertEqual(len(applies),len(set(applies)))
        self.assertEqual(app.runner.stats.applied_edits,2)

    def test_uncertain_or_mutating_refusal_stops_without_native_replay(self):
        for index,raw in enumerate(({'status':'unconfirmed','reason':'native_write_readback_mismatch'},
                {'status':'refused','reason':'source_cells_changed','issued_writes':1},
                {'status':'refused','reason':'authoring_host_quarantined_after_uncertain_outcome'},
                {'status':'refused','reason':'source_cells_changed','identity':{'world_generation':4}})):
            with self.subTest(raw=raw):
                # Each invocation has a distinct session-owned evidence root.
                self.root=Path(self.temp.name)/str(index);self.root.mkdir();self.frame=start_frame(self.root)
                self.auth=start_config(self.frame)[2]
                app,_,calls=self.run_bridge(self.turns,{3:raw})
                self.assertEqual(calls,['observe','prepare_edit','apply_edit','stop'])
                self.assertNotEqual(app.runner.report['status'],'passed')
                self.assertTrue(app.runner.report['stop_acknowledged'])

    def test_refused_apply_cannot_replay_same_proposal_or_step(self):
        turns=self.turns[:3]+[{'tool':'apply_edit','args':{'proposal_id':'prop-2'}},{'tool':'step','args':{'ticks':1}}]
        app,_,calls=self.run_bridge(turns,{3:{'status':'refused','reason':'stale_proposal','proposal_id':'prop-2'}})
        self.assertEqual(calls,['observe','prepare_edit','apply_edit','stop'])
        self.assertEqual(app.runner.stats.applied_edits,0)

    def test_palette_filters_match_native_named_ids_without_write_grant(self):
        params=desktop_tool_schemas()['prepare_edit']['properties']['operations']['items']['anyOf']
        for variant in params:
            self.assertEqual(variant['properties']['replace_only_material']['anyOf'][0]['enum'],list(DESKTOP_NATIVE_PALETTE))
        args={'observation_id':'o','operations':[{'shape':'rectangle','x0':30,'y0':30,'x1':30,'y1':30,'material':58,'replace_only_material':2}]}
        validate_desktop_tool('prepare_edit',args,self.auth['scope'],{0,58},[],'o',None,0,480)
        for field,value in (('replace_only_material',255),('material',2)):
            bad=copy.deepcopy(args);bad['operations'][0][field]=value
            with self.assertRaises(NativeError):validate_desktop_tool('prepare_edit',bad,self.auth['scope'],{0,58},[],'o',None,0,480)

    def rate_runner(self,**limits):
        cfg=load_profile(HERE/'profiles/fixture.json',fixture_mode=True,desktop=True)
        cfg['limits'].update(max_output_tokens=32768,tokens_per_minute=20000,max_total_output_tokens=250000)
        cfg['limits'].update(limits)
        native=FakeNative();native.desktop=True
        r=Runner(cfg,{'instructions':'test','acceptance':{}},self.auth,native,self.root/'rate',
            adapter=HTTPAdapter(cfg,fixture_mode=True),fixture_mode=True)
        r.output.mkdir();r.history=[{'kind':'user','text':'test'}]
        return r

    def test_requested32768_output_is_paced_with_real_per_request20000_cap_no_config_mutation(self):
        r=self.rate_runner();seen=[]
        def http(endpoint,key,body,*args):
            seen.append(body)
            return {'model':r.cfg['model'],'choices':[{'finish_reason':'stop','message':{'content':'done'}}],
                'usage':{'prompt_tokens':100,'completion_tokens':20}}
        with patch('workbench_api_agent.providers.http_post',side_effect=http):r._provider();r._provider()
        self.assertEqual([body['max_tokens'] for body in seen],[20000,19880])
        self.assertEqual(r.cfg['limits']['max_output_tokens'],32768)
        events=[json.loads(line) for line in (r.output/'events.jsonl').read_text().splitlines()]
        caps=[e for e in events if e['type']=='rate.output_cap']
        self.assertEqual(caps[0]['configured_output_tokens'],32768)
        self.assertEqual(caps[0]['effective_output_tokens'],20000)

    def test_unknown_oversized_input_gets_one_request_per_window_then_stop_cancels_wait(self):
        r=self.rate_runner(tokens_per_minute=1024)
        r.budget=UsageBudget(r.cfg['limits'])
        clock=[0.];r._rate_clock=lambda:clock[0]
        called=[]
        class Adapter:
            def request_with_output_cap(self,history,capacity,timeout,cap):
                called.append(cap)
                return Decision('final',text='synthetic',usage={'input_tokens':1500,'output_tokens':20})
        r.adapter=Adapter()
        r._provider();self.assertEqual(called,[1024])
        def stop(_):r.stop_event.set();return True
        r._rate_wait=stop
        with self.assertRaisesRegex(NativeError,'host_stop_requested'):r._provider()
        self.assertEqual(called,[1024])
        events=[json.loads(line) for line in (r.output/'events.jsonl').read_text().splitlines()]
        self.assertTrue(any(e['type']=='rate.output_cap' and e['estimated_input_above_tpm'] for e in events))
        self.assertTrue(any(e['type']=='rate.wait' for e in events))

    def test_rate_retry_keeps_first_output_cap_and_identical_http_body_after_allowance_grows(self):
        r=self.rate_runner();clock=[0.];r._rate_clock=lambda:clock[0]
        r._rate_reservations=[{'at':-50.,'tokens':15000}]
        waits=[];seen=[]
        def wait(delay):waits.append(delay);clock[0]+=delay;return False
        r._rate_wait=wait
        def http(endpoint,key,body,*args):
            seen.append(copy.deepcopy(body))
            if len(seen)==1:raise ProviderError('provider_rate_limit',429,11)
            return {'model':r.cfg['model'],'choices':[{'finish_reason':'stop','message':{'content':'done'}}],
                'usage':{'prompt_tokens':100,'completion_tokens':20}}
        with patch('workbench_api_agent.providers.http_post',side_effect=http):r._provider()
        self.assertEqual(waits,[11])
        self.assertEqual([body['max_tokens'] for body in seen],[5000,5000])
        self.assertEqual(seen[0],seen[1])
        self.assertEqual(r.cfg['limits']['max_output_tokens'],32768)
