"""Operator consent is not a fabricated or verified account-credit balance."""
from __future__ import annotations
import copy,json,os,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from atlas_agent.errors import GateRefused,LimitReached
from .config import ConfigError,load_profile,validate_live
from .usage_budget import UsageBudget
HERE=Path(__file__).parent

class DesktopOperatorFundingTests(unittest.TestCase):
    def setUp(self):
        self.cfg=load_profile(HERE/'profiles/openai-responses.example.json',desktop=True)
        self.cfg['spend'].update({'max_usd_per_call':.10,'max_usd_per_run':2.,'authorised_ceiling_usd':2.,'authorisation_ref':'explicit-test-consent','credit_attestation_file':None})
        self.env=patch.dict(os.environ,{'OPENAI_API_KEY':'dummy-not-a-real-key-0123456789012345'});self.env.start()
    def tearDown(self):self.env.stop()
    def operator(self):
        cfg=copy.deepcopy(self.cfg);cfg['spend']['funding_mode']='operator_authorized_desktop';return cfg
    def gate(self,cfg,**kw):
        return validate_live(cfg,allow_live=kw.pop('allow_live',True),fixture_mode=False,desktop=kw.pop('desktop',True),source_dirty=kw.pop('source_dirty',False),probe=kw.pop('probe',lambda _: {'status':200,'headers':{}}),**kw)
    def test_absent_mode_preserves_original_attestation_requirement(self):
        with self.assertRaises(GateRefused):self.gate(self.cfg)
    def test_explicit_mode_retains_real_budget_and_reports_unknown_credit(self):
        budget,gate=self.gate(self.operator());self.assertTrue(budget.live);self.assertEqual(budget.run_allowance_usd(),2.)
        self.assertEqual(gate['credit_status'],'not_verified_operator_authorized')
        self.assertFalse(gate['credit_balance_programmatically_verified']);self.assertFalse(gate['account_headroom_verified']);self.assertNotIn('atlas_credit_gate',gate)
        self.assertTrue(gate['usd_limits_enforced']);self.assertEqual(gate['pricing_status'],'known')
        with self.assertRaises(LimitReached):budget.reserve(100000,131072)
    def test_remote_no_live_and_dirty_source_refuse(self):
        for kw in ({'desktop':False},{'allow_live':False},{'source_dirty':True},{'source_dirty':None}):
            with self.subTest(kw=list(kw)):
                with self.assertRaises(ConfigError):self.gate(self.operator(),**kw)
    def test_credentials_known_price_caps_and_crosscheck_still_enforced(self):
        with patch.dict(os.environ,{'OPENAI_API_KEY':''}):
            with self.assertRaises(ConfigError):self.gate(self.operator())
        for key,value in [('max_usd_per_call',0),('max_usd_per_run',0),('authorised_ceiling_usd',.01),('authorisation_ref',''),('authorisation_ref','   ')]:
            cfg=self.operator();cfg['spend'][key]=value
            with self.assertRaises(ConfigError):self.gate(cfg)
        cfg=self.operator();cfg['spend']['require_costs_crosscheck']=True
        with self.assertRaises(ConfigError):self.gate(cfg)
    def test_model_catalog_probe_never_called_in_explicit_mode(self):
        def forbidden(_):self.fail('operator-selected model must go to inference, not catalog preflight')
        for model in ('gpt-6-luna','gpt-5.6-luna'):
            cfg=self.operator();cfg['model']=model
            _,gate=self.gate(cfg,probe=forbidden)
            self.assertEqual(gate['model_probe_status'],'not_requested')
        self.gate(self.operator(),probe=None)
    def test_unknown_and_stale_prices_are_usage_only_exclusively_in_operator_mode(self):
        from atlas_agent.pricing import PricingUnavailable
        cfg=self.operator();cfg['model']='gpt-5.6-luna'
        budget,gate=self.gate(cfg)
        self.assertIsInstance(budget,UsageBudget);self.assertIsNone(budget.rates)
        self.assertFalse(gate['usd_limits_enforced']);self.assertEqual(gate['pricing_status'],'unknown')
        self.assertIsNone(gate['pricing_source'])
        with patch('workbench_api_agent.config.pricing_rates',side_effect=PricingUnavailable('stale','pricing_stale')):
            budget,gate=self.gate(self.operator());self.assertIsInstance(budget,UsageBudget)
            with self.assertRaises(PricingUnavailable):self.gate(self.cfg)
        cfg['spend'].pop('funding_mode')
        with self.assertRaises(PricingUnavailable):self.gate(cfg)
    def test_actual_cash_and_run_deadline_gates_are_not_bypassed(self):
        cfg=self.operator();cfg['spend']['max_usd_per_call']=.000001
        budget,_=self.gate(cfg)
        with self.assertRaises(LimitReached) as error:budget.reserve(1000,100)
        self.assertEqual(error.exception.reason_code,'per_call_cost_ceiling')
        budget,_=self.gate(self.operator());budget.committed_usd=2.
        with self.assertRaises(LimitReached) as error:budget.reserve(100,10)
        self.assertEqual(error.exception.reason_code,'per_run_cost_ceiling')
        budget,_=self.gate(self.operator());budget.started-=budget.limits['max_run_seconds']+1
        with self.assertRaises(LimitReached) as error:budget.reserve(100,10)
        self.assertEqual(error.exception.reason_code,'max_run_seconds')
    def test_profile_mode_is_desktop_cloud_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'profile.json';path.write_text(json.dumps(self.operator()))
            load_profile(path,desktop=True)
            with self.assertRaises(ConfigError):load_profile(path)
        cfg=self.operator();cfg.update(provider='nvidia_chat',endpoint='https://integrate.api.nvidia.com/v1/chat/completions',model='nvidia/nemotron-3.5-super-vl-120b-a12b',credentials={'env':'NVIDIA_API_KEY'})
        cfg['spend'].pop('rates',None)
        with patch.dict(os.environ,{'NVIDIA_API_KEY':'dummy-nvidia-key-never-real-0123456789'}):
            budget,gate=self.gate(cfg)
            self.assertIsInstance(budget,UsageBudget)
            self.assertFalse(gate['usd_limits_enforced'])
            with self.assertRaises(ConfigError):self.gate(cfg,desktop=False)
        with patch.dict(os.environ,{'NVIDIA_API_KEY':''}):
            with self.assertRaises(ConfigError):self.gate(cfg)
