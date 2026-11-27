"""Challenge source sealing and actual helper imports without running campaigns."""
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import closure_request as request


class ClosureSourceAdmission(unittest.TestCase):
    def test_new_helpers_import_before_expensive_platform_work(self):
        for name in ('verify_closure_runtimes.py','restore_atomic.py','run_closure_hosted.py','run_native_owner.py'):
            with self.subTest(name=name):
                result=subprocess.run([sys.executable,str(Path(__file__).with_name(name)),'--help'],
                    text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30)
                self.assertEqual(result.returncode,0,result.stderr)

    def test_request_cannot_survive_a_different_source_or_uncommitted_marker(self):
        with tempfile.TemporaryDirectory() as temporary, mock.patch.dict(os.environ,{'GITHUB_ACTIONS':'false'}):
            root=Path(temporary)
            def git(*args):
                return subprocess.run(['git','-c','user.name=Closure admission test','-c','user.email=closure@example.invalid',
                    '-C',str(root),*args],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
            git('init');(root/'source.txt').write_text('original input\n');git('add','source.txt');git('commit','-m','source')
            value={'schema':'pubpres-closure-run-v1','phase':'runtimes','purpose':'Synthetic source refusal test',
                'historical_main':request.M,'current_main':'b'*40,'frozen_donor':request.D,
                'payload_sha256':request.fingerprint(root),'physical_acceptance':'HOLD'}
            (root/'.github').mkdir();path=root/request.REQUEST;path.write_bytes((json.dumps(value)+'\n').encode('utf-8'))
            git('add',request.REQUEST);git('commit','-m','registered marker')
            self.assertEqual(request.validate(root),value)
            changed=copy.deepcopy(value);changed['purpose']='Uncommitted marker mutation';path.write_text(json.dumps(changed)+'\n')
            with self.assertRaisesRegex(ValueError,'committed source'):request.validate(root)
            path.write_bytes((json.dumps(value)+'\n').encode('utf-8'))
            (root/'source.txt').write_text('different committed input\n');git('add','source.txt');git('commit','-m','source moved')
            with self.assertRaisesRegex(ValueError,'complete resulting source tree'):request.validate(root)


if __name__=='__main__':unittest.main()
