"""Unpriced operator mode: synthetic provider/native flow, never live acceptance."""
from __future__ import annotations
import json,os,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from atlas_agent.errors import LimitReached
from .config import load_profile
from .controller import Runner,trusted_task
from .providers import ScriptedAdapter,HTTPAdapter
from .test_runner import FakeNative
from .usage_budget import UsageBudget,conservative_image_tokens

HERE=Path(__file__).parent


class UsageBudgetTests(unittest.TestCase):
    def setUp(self):
        self.limits=load_profile(HERE/'profiles/openai-responses.example.json',desktop=True)['limits']

    def budget(self,**limits):return UsageBudget(self.limits|limits)

    def test_no_zero_price_or_claimed_dollar_ceiling(self):
        b=self.budget();r=b.reserve(100,20);result=b.commit(r,90,10,15)
        self.assertIsNone(b.rates);self.assertIsNone(result['computed_usd'])
        self.assertIsNone(b.run_allowance_usd());self.assertIsNone(b.remaining_usd())
        snap=b.snapshot();self.assertFalse(snap['cash_ceiling_enforced'])
        for key,value in snap.items():
            if key.endswith('_usd'):self.assertIsNone(value,key)
        self.assertEqual(snap['input_tokens'],90);self.assertEqual(snap['output_tokens'],15)

    def test_per_call_cumulative_pending_and_unknown_usage_token_bounds(self):
        b=self.budget(max_input_tokens_per_call=100,max_total_input_tokens=150,max_total_output_tokens=30)
        with self.assertRaises(LimitReached):b.reserve(101,10)
        r=b.reserve(80,20)
        with self.assertRaises(LimitReached):b.reserve(80,10)
        with self.assertRaises(LimitReached):b.reserve(10,11)
        b.mark_ambiguous(r)
        self.assertEqual(b.snapshot()['ambiguous_attempts'],1)
        with self.assertRaises(LimitReached):b.reserve(71,1)
        with self.assertRaises(ValueError):b.release(r)
        r=b.reserve(10,10);b.release(r,rate_limited=True)
        self.assertEqual(b.snapshot()['rate_limited_attempts'],1)
        self.assertEqual(b.input_tokens,80)

    def test_request_time_and_reported_overrun_still_enforce_configured_caps(self):
        b=self.budget(max_model_calls=1,max_total_retries=0)
        b.start_iteration()
        with self.assertRaises(LimitReached):b.start_iteration()
        r=b.reserve(10,10)
        self.assertTrue(b.commit(r,11,0,10)['exceeded_reservation'])
        with self.assertRaises(LimitReached):b.reserve(1,1)
        b=self.budget();b.started-=b.limits['max_run_seconds']+1
        with self.assertRaises(LimitReached) as error:b.reserve(1,1)
        self.assertEqual(error.exception.reason_code,'max_run_seconds')
        b=self.budget(max_input_tokens_per_call=100)
        r=b.reserve(50,10)
        with self.assertRaises(LimitReached) as error:b.commit(r,101,0,10)
        self.assertEqual(error.exception.reason_code,'max_input_tokens_per_call')
        self.assertEqual(b.input_tokens,101)
        b=self.budget();r=b.reserve(100,10)
        with self.assertRaises(LimitReached) as error:b.commit(r,100,0,11)
        self.assertEqual(error.exception.reason_code,'max_output_tokens')
        self.assertEqual(b.output_tokens,11)

    def test_image_estimate_uses_existing_generic_dimensions_rule_not_dollars(self):
        self.assertEqual(conservative_image_tokens(1,1),3)
        self.assertLess(conservative_image_tokens(3840,2160),21000)
        self.assertGreater(conservative_image_tokens(1920,1080),conservative_image_tokens(1280,720))
        for dims in ((0,1),(1,False),(1,1.5)):
            with self.assertRaises(ValueError):conservative_image_tokens(*dims)

    def test_unpriced_exact_model_runs_complete_injected_tool_loop_and_acknowledged_stop(self):
        cfg=load_profile(HERE/'profiles/openai-responses.example.json',desktop=True)
        cfg['model']='gpt-5.6-luna'
        cfg['spend'].update(funding_mode='operator_authorized_desktop',authorisation_ref='explicit-unit-test-operator',
            max_usd_per_call=.1,max_usd_per_run=2.,authorised_ceiling_usd=2.)
        cfg['limits'].update(max_output_tokens=1024,tokens_per_minute=10000000)
        task,auth=trusted_task(HERE/'fixtures/nine-then-eight.task.json',HERE/'fixtures/roundtrip-authorization.json')
        turns=json.loads((HERE/'fixtures/nine-then-eight.fixture.json').read_text())
        native=FakeNative();native.desktop=True
        def forbidden_probe(_):self.fail('no catalog preflight allowed')
        with tempfile.TemporaryDirectory() as tmp,patch.dict(os.environ,{'OPENAI_API_KEY':'dummy-no-network-0123456789012345'}):
            scripted=ScriptedAdapter(turns)
            calls=[]
            def fake_http(endpoint,key,body,*args):
                self.assertEqual(endpoint,'https://api.openai.com/v1/responses')
                self.assertEqual(body['model'],'gpt-5.6-luna');calls.append(body)
                decision=scripted.request(runner.history,10000000,45)
                output=([{'type':'function_call','call_id':decision.call_id,'name':decision.tool,
                    'arguments':json.dumps(decision.args)}] if decision.kind=='tool' else
                    [{'type':'message','content':[{'type':'output_text','text':decision.text}]}])
                return {'model':'gpt-5.6-luna','status':'completed','output':output,
                    'usage':{'input_tokens':12000,'output_tokens':20}}
            runner=Runner(cfg,task,auth,native,Path(tmp)/'result',adapter=HTTPAdapter(cfg),
                allow_live=True,source_dirty=False,credit_probe=forbidden_probe)
            with patch('workbench_api_agent.providers.http_post',side_effect=fake_http):result=runner.run()
            self.assertEqual(result['status'],'passed',result['reason'])
            self.assertEqual(result['model'],'gpt-5.6-luna')
            self.assertEqual(result['measured']['model_calls'],9)
            self.assertEqual(len(calls),9)
            self.assertEqual(result['measured']['applied_edits'],2)
            self.assertEqual(result['measured']['native_ticks'],4)
            self.assertTrue(result['stop_acknowledged']);self.assertTrue(native.stop_called.is_set())
            self.assertEqual(len(result['native_receipts']),8)
            self.assertIsNone(result['budget']['committed_usd'])
            self.assertIn('no-USD-ceiling-enforced',result['billing'])
            self.assertFalse(result['funding_gate']['usd_limits_enforced'])
            self.assertTrue(result['budget']['input_tokens']>0)
            self.assertGreater(result['budget']['reservation_overruns'],0)
            events=[json.loads(line) for line in (Path(tmp)/'result/events.jsonl').read_text().splitlines()]
            self.assertTrue(all(e['api_cost_status']=='unknown_unpriced_model' for e in events if e['type']=='provider'))
            self.assertTrue(any(e['type']=='token_estimate_exceeded' for e in events))
