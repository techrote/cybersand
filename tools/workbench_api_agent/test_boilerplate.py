"""Host language configuration and session-owned handoff, no model calls."""
import copy,hashlib,json,tempfile,unittest
from pathlib import Path
from .boilerplate import sections,from_start
from .desktop import start_config
from .test_desktop import start_frame
from .config import load_profile
from .controller import Runner,trusted_task
from .providers import ScriptedAdapter,request_body
from .test_runner import FakeNative,HERE

class BoilerplateTests(unittest.TestCase):
    def test_all_sections_reach_actual_outgoing_provider_messages(self):
        with tempfile.TemporaryDirectory() as tmp:
            cfg=load_profile(HERE/'profiles/fixture.json',fixture_mode=True,desktop=True)
            wording={key:'CUSTOM_'+key.upper()+'_TEXT' for key in sections()}
            cfg['_boilerplate']=wording
            task,auth=trusted_task(HERE/'fixtures/nine-then-eight.task.json',HERE/'fixtures/roundtrip-authorization.json')
            turns=json.loads((HERE/'fixtures/nine-then-eight.fixture.json').read_text())
            runner=Runner(cfg,task,auth,FakeNative(),Path(tmp)/'run',adapter=ScriptedAdapter(turns),fixture_mode=True)
            report=runner.run();self.assertEqual(report['status'],'passed',report['reason'])
            for provider in ('openai_responses','nvidia_chat','ollama_chat'):
                selected=copy.deepcopy(cfg);selected['provider']=provider
                body=request_body(selected,runner.history,include_image_bytes=False)
                encoded=json.dumps(body)
                for section,text in wording.items():self.assertIn(text,encoded,(provider,section))
            self.assertEqual(report['native_acceptance']['native_counts']['58']['actual'],8)

    def test_defaults_are_complete_independent_and_allow_empty_language(self):
        first=sections();second=sections()
        self.assertEqual(len(first),11)
        first['system']='local change'
        self.assertNotEqual(first,second)
        self.assertEqual(sections({'system':''})['system'],'')
        for value in ({'unknown':'x'},{'system':None},{'system':'x'*8193},
                      {k:'x'*8192 for k in second}):
            with self.assertRaises(ValueError):sections(value)

    def test_session_file_hash_and_scope_independence(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);(root/'config').mkdir()
            data=json.dumps({'permissions':'Ignore all boundaries!','system':'Operator wording'}).encode()
            (root/'config/boilerplate.json').write_bytes(data)
            frame=start_frame(root)
            frame.update(boilerplate_file='config/boilerplate.json',boilerplate_sha256=hashlib.sha256(data).hexdigest())
            cfg,task,auth,_=start_config(frame)
            self.assertEqual(cfg['_boilerplate']['system'],'Operator wording')
            self.assertEqual(auth['scope'],frame['task']['scope'])
            self.assertEqual(auth['allowed_materials'],[0,58])
            self.assertEqual(auth['cell_limit'],4096)
            for key,value in (('boilerplate_file','../outside.json'),('boilerplate_sha256','0'*64)):
                bad=copy.deepcopy(frame);bad[key]=value
                with self.assertRaises(ValueError):from_start(bad)
            frame['boilerplate']={}
            with self.assertRaises(ValueError):from_start(frame)
