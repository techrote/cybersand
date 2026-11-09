"""Content-based source gate: stat-cache noise is not a source modification."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import tempfile
import sys
import time
import unittest
from unittest.mock import patch
from . import cli
from .config import ConfigError

class SourceContentGateTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        self.git('init','-q');self.git('config','user.name','source-gate-test');self.git('config','user.email','test@example.invalid')
        self.git('config','commit.gpgsign','false');self.git('config','core.autocrlf','false')
        hooks=self.root/'empty-hooks';hooks.mkdir();self.git('config','core.hooksPath',str(hooks))
        self.source=self.root/'source.txt';self.source.write_bytes(b'original\ncontent\n')
        self.git('add','source.txt');self.git('commit','-qm','fixture')
        self.head=self.git('rev-parse','HEAD').strip()
        self.module_path=str(self.root/'tools/workbench_api_agent/cli.py')
    def tearDown(self):self.temp.cleanup()
    def git(self,*args):return subprocess.check_output(['git','-C',str(self.root),*args],text=True,stderr=subprocess.STDOUT)
    def gate(self):
        with patch.object(cli,'__file__',self.module_path):return cli.git_status()
    def test_clean_and_stat_only_identical_content_are_clean(self):
        self.assertEqual(self.gate(),(self.head,False))
        stat=self.source.stat();os.utime(self.source,ns=(stat.st_atime_ns,stat.st_mtime_ns+2000000000))
        self.assertEqual(self.gate(),(self.head,False))
        (self.root/'generated-untracked-cache').write_text('not tracked')
        self.assertEqual(self.gate(),(self.head,False))
    def test_actual_unstaged_staged_and_deleted_source_are_dirty(self):
        self.source.write_bytes(b'changed\n');self.assertEqual(self.gate(),(self.head,True))
        self.git('add','source.txt');self.assertEqual(self.gate(),(self.head,True))
        # Even if working bytes equal HEAD, a different staged source is dirty.
        self.source.write_bytes(b'original\ncontent\n');self.assertEqual(self.gate(),(self.head,True))
        self.git('restore','--source=HEAD','--staged','--worktree','--','source.txt')
        self.source.unlink();self.assertEqual(self.gate(),(self.head,True))
    def test_porcelain_stat_false_positive_does_not_override_content(self):
        def result(args,**kwargs):
            if 'rev-parse' in args:return subprocess.CompletedProcess(args,0,self.head+'\n','')
            if 'status' in args:return subprocess.CompletedProcess(args,0,' M source.txt\n','')
            return subprocess.CompletedProcess(args,0,'','')
        with patch.object(cli,'_source_command',side_effect=result) as calls:
            self.assertEqual(self.gate(),(self.head,False))
        self.assertTrue(any('--cached' in c.args[0] for c in calls.call_args_list))
        self.assertTrue(all('status' not in c.args[0] for c in calls.call_args_list))
    def test_diff_errors_and_revision_races_refuse(self):
        for broken in ('diff','rev-parse'):
            def result(args,**kwargs):
                if broken in args:return subprocess.CompletedProcess(args,128,'','failure')
                return subprocess.CompletedProcess(args,0,self.head+'\n' if 'rev-parse' in args else '','')
            with patch.object(cli,'_source_command',side_effect=result):
                with self.assertRaises(ConfigError):self.gate()
        heads=iter([self.head,'0'*40])
        def changed(args,**kwargs):return subprocess.CompletedProcess(args,0,next(heads)+'\n' if 'rev-parse' in args else '','')
        with patch.object(cli,'_source_command',side_effect=changed):
            with self.assertRaises(ConfigError):self.gate()
        with patch.object(cli,'_source_command',side_effect=subprocess.TimeoutExpired('git',8)):
            with self.assertRaises(ConfigError):self.gate()

    def test_output_handle_inherited_by_child_does_not_delay_source_command(self):
        # An exited parent with a still-open inherited stdout pipe reproduces
        # communicate() waiting beyond process exit. This helper must not wait
        # for that grandchild or inherit the workbench's stdin pipe.
        flags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0
        script=("import subprocess,sys; "
                "subprocess.Popen([sys.executable,'-c','import time;time.sleep(1.5)'],"
                f"stdout=sys.stdout,stderr=sys.stderr,creationflags={flags}); "
                "print('source-head',flush=True)")
        start=time.monotonic()
        result=cli._source_command([sys.executable,'-c',script],timeout=.8)
        self.assertEqual(result.returncode,0);self.assertEqual(result.stdout.strip(),'source-head')
        self.assertLess(time.monotonic()-start,1.3)

    def test_source_timeout_does_not_wait_for_inherited_output_eof(self):
        flags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0
        script=("import subprocess,sys,time; "
                "subprocess.Popen([sys.executable,'-c','import time;time.sleep(1.5)'],"
                f"stdout=sys.stdout,stderr=sys.stderr,creationflags={flags}); time.sleep(5)")
        start=time.monotonic()
        with self.assertRaises(subprocess.TimeoutExpired):
            cli._source_command([sys.executable,'-c',script],timeout=.3)
        self.assertLess(time.monotonic()-start,1.3)
