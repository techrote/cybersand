"""Startup/lifetime regressions; synthetic ACKs, no provider calls."""
from __future__ import annotations
import copy,hashlib,io,json,os,queue,subprocess,sys,tempfile,threading,time,unittest
from pathlib import Path
from unittest.mock import patch
from . import desktop
from .test_desktop import start_frame
HERE=Path(__file__).parent

class StartupTests(unittest.TestCase):
    def setUp(self):self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
    def tearDown(self):self.temp.cleanup()
    def test_missing_key_refusal_exits_cleanly_repeatedly_with_stdin_open(self):
        profile=HERE/'profiles/openai-responses.example.json'
        for n in range(3):
            folder=self.root/str(n);folder.mkdir();frame=start_frame(folder)
            frame.update({'profile_path':str(profile.resolve()),'profile_sha256':hashlib.sha256(profile.read_bytes()).hexdigest(),'fixture_mode':False,'allow_live':True})
            env=dict(os.environ);env.pop('OPENAI_API_KEY',None)
            child=subprocess.Popen([sys.executable,'-u',str(HERE/'desktop.py')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env)
            events=queue.Queue()
            reader=threading.Thread(target=lambda:[events.put(json.loads(line)) for line in child.stdout],daemon=True);reader.start()
            def send(f):child.stdin.write(json.dumps(f).encode()+b'\n');child.stdin.flush()
            try:
                boot=events.get(timeout=3);self.assertEqual(boot['event'],'runner.preflight');self.assertEqual(boot['payload']['phase'],'waiting_for_start')
                send(frame);phases=[];finished=None;stops=0
                while finished is None:
                    event=events.get(timeout=5)
                    if event['type']=='native_request':
                        self.assertEqual(event['tool'],'stop');stops+=1
                        send({'type':'native_result','id':event['id'],'receipt':{'status':'retired','owner_receipt':{'status':'stopped','no_further_agent_mutations':True}}})
                    elif event.get('event')=='runner.preflight':phases.append(event['payload']['phase'])
                    elif event['type']=='finished':finished=event['receipt']
                self.assertEqual(stops,1);self.assertTrue(finished['stop_acknowledged']);self.assertEqual(finished['status'],'refused')
                self.assertIn('credential_check',phases);self.assertNotIn('model_probe',phases)
                # Deliberately keep parent stdin open: old BufferedReader daemon
                # owned its lock here and crashed during interpreter shutdown.
                self.assertEqual(child.wait(timeout=4),0)
                stderr=child.stderr.read();self.assertNotIn(b'_enter_buffered_busy',stderr);self.assertNotIn(b'Fatal Python error',stderr)
            finally:
                if child.poll() is None:child.kill();child.wait(timeout=4)
                child.stdin.close();child.stdout.close();child.stderr.close()

    def test_stop_during_source_preflight_acknowledges_without_waiting_for_git(self):
        profile=HERE/'profiles/ollama-qwen3-vl-8b.example.json';frame=start_frame(self.root)
        frame.update({'profile_path':str(profile.resolve()),'profile_sha256':hashlib.sha256(profile.read_bytes()).hexdigest(),'fixture_mode':False,'compute_consent':True})
        frames=[];blocked=threading.Event();release=threading.Event();acked=threading.Event()
        protocol=desktop.Protocol(io.BytesIO());app=desktop.Desktop(protocol)
        def send(f):
            frames.append(f)
            if f['type']=='native_request':
                self.assertEqual(f['tool'],'stop')
                app.receive({'type':'native_result','id':f['id'],'receipt':{'status':'retired','owner_receipt':{'status':'stopped','no_further_agent_mutations':True}}});acked.set()
        protocol.send=send
        def git():blocked.set();release.wait(3);return 'a'*40,False
        with patch.object(desktop,'git_status',side_effect=git),patch.object(desktop,'Runner') as runner:
            app.receive(frame);self.assertTrue(blocked.wait(1));self.assertIsNone(app.runner)
            app.receive({'type':'stop'});self.assertTrue(acked.wait(1),'native Stop waited for source check')
            self.assertFalse(app.finished.is_set());release.set();self.assertTrue(app.finished.wait(2));runner.assert_not_called()
        self.assertTrue(frames[-1]['receipt']['stop_acknowledged']);self.assertNotEqual(frames[-1]['receipt']['status'],'passed')
        self.assertTrue(any(f.get('event')=='runner.preflight' and f['payload']['phase']=='source_check' for f in frames))

    def test_stop_before_start_has_bounded_unconfirmed_exit(self):
        p=desktop.Protocol(io.BytesIO());app=desktop.Desktop(p);app.receive({'type':'stop'})
        self.assertTrue(app.finished.is_set());f=json.loads(p.output.getvalue())
        self.assertEqual(f['receipt']['status'],'unconfirmed_stop');self.assertFalse(f['receipt']['stop_acknowledged'])
