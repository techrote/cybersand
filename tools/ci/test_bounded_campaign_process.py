#!/usr/bin/env python3
"""Real small process trees; no Godot/native gameplay or performance claim."""
from __future__ import annotations
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

import bounded_campaign_process as subject

FIXTURE = r'''
import json,os,subprocess,sys,time
from pathlib import Path
root=Path(sys.argv[1]);mode=sys.argv[2]
(root/(mode+".pid")).write_text(str(os.getpid()))
if mode=="grandchild" or mode=="unrelated":
    while True:
        (root/(mode+".heartbeat")).write_text(str(time.monotonic_ns()))
        time.sleep(.02)
if mode=="child":
    subprocess.Popen([sys.executable,__file__,str(root),"grandchild"])
    while True:time.sleep(.05)
if mode in ("timeout","early-success","early-failure"):
    subprocess.Popen([sys.executable,__file__,str(root),"child"])
    deadline=time.monotonic()+10
    while not (root/"grandchild.heartbeat").exists():
        if time.monotonic()>deadline:sys.exit(66)
        time.sleep(.01)
    if mode=="early-success":sys.exit(0)
    if mode=="early-failure":sys.exit(7)
    while True:time.sleep(.05)
if mode=="success":sys.exit(0)
if mode=="failure":sys.exit(7)
if mode=="joined-history":
    subprocess.run([sys.executable,"-c","pass"],check=True)
    sys.exit(0)
'''


def alive(pid: int) -> bool:
    if os.name == "nt":
        from ctypes import wintypes as w
        api=ctypes.WinDLL("kernel32",use_last_error=True)
        api.OpenProcess.argtypes=[w.DWORD,w.BOOL,w.DWORD];api.OpenProcess.restype=w.HANDLE
        api.WaitForSingleObject.argtypes=[w.HANDLE,w.DWORD];api.WaitForSingleObject.restype=w.DWORD
        api.CloseHandle.argtypes=[w.HANDLE];api.CloseHandle.restype=w.BOOL
        handle=api.OpenProcess(0x100000,False,pid)  # SYNCHRONIZE only.
        if not handle:
            if ctypes.get_last_error()==87:return False
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            result=api.WaitForSingleObject(handle,0)
            if result==0:return False
            if result==258:return True
            raise RuntimeError(f"Process liveness query failed: {result}")
        finally:api.CloseHandle(handle)
    try:
        text=Path(f"/proc/{pid}/stat").read_text()
        return text[text.rfind(")")+2:].split()[0] not in ("Z","X")
    except FileNotFoundError:return False


class ActualProcessTests(unittest.TestCase):
    output: Path
    rows=[]

    def exercise(self,mode: str) -> None:
        folder=self.output/mode;folder.mkdir(parents=True)
        fixture=folder/"fixture with spaces.py";fixture.write_text(FIXTURE)
        outsider=subprocess.Popen([sys.executable,str(fixture),str(folder),"unrelated"])
        command=[sys.executable,str(fixture),str(folder),mode]
        record=folder/"retirement.json"
        began=time.monotonic();error="";returned=None
        try:
            if mode=="timeout":
                with self.assertRaises(subprocess.TimeoutExpired) as caught:
                    subject.run_campaign(command,cwd=folder,timeout=3,record_path=record)
                self.assertEqual(caught.exception.timeout,3);error=type(caught.exception).__name__
            elif mode=="early-success":
                with self.assertRaises(subject.CampaignRetirementError) as caught:
                    subject.run_campaign(command,cwd=folder,timeout=20,record_path=record)
                error=type(caught.exception).__name__
            else:
                result=subject.run_campaign(command,cwd=folder,timeout=20,record_path=record)
                returned=result.returncode
                self.assertEqual(returned,0 if mode=="success" else 7)
            value=json.loads(record.read_text())
            self.assertIs(value["retired"],True)
            self.assertEqual(value["status"],"retired")
            self.assertEqual(value["command"],command)
            self.assertEqual(value["timed_out"],mode=="timeout")
            self.assertEqual(value["parent_left_descendants"],mode.startswith("early-"))
            self.assertEqual(value["method"],"suspended-windows-process-job" if os.name=="nt" else "owned-linux-process-group")
            pids={p.stem:int(p.read_text()) for p in folder.glob("*.pid")}
            self.assertEqual(pids[mode],value["pid"])
            if mode.startswith("early-") or mode=="timeout":
                self.assertIn("child",pids);self.assertIn("grandchild",pids)
            for name,pid in pids.items():
                if name!="unrelated":self.assertFalse(alive(pid),(name,pid))
            self.assertTrue(alive(outsider.pid),"Unrelated process must remain alive")
            heartbeat=folder/"grandchild.heartbeat"
            before=heartbeat.read_bytes() if heartbeat.exists() else b""
            time.sleep(.15)
            self.assertEqual(before,heartbeat.read_bytes() if heartbeat.exists() else b"",
                "Retired descendants cannot mutate uploaded evidence")
            self.rows.append({"mode":mode,"parent_pid":value["pid"],"observed_pids":pids,
                "unrelated_pid":outsider.pid,"unrelated_survived":True,"retired":True,
                "heartbeat_stable":True,"elapsed_seconds":time.monotonic()-began,
                "exception":error,"returncode":returned,"record":value})
        finally:
            outsider.kill();outsider.wait(timeout=10)
            # A failed assertion remains failed, but no test child is left alive.
            for p in folder.glob("*.pid"):
                pid=int(p.read_text())
                if pid!=os.getpid() and alive(pid):
                    if os.name=="nt":
                        subprocess.run(["taskkill","/PID",str(pid),"/T","/F"],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
                    else:os.kill(pid,9)

    def test_success(self):self.exercise("success")
    def test_nonzero(self):self.exercise("failure")
    def test_timeout_descendants(self):self.exercise("timeout")
    def test_early_success_refused(self):self.exercise("early-success")
    def test_early_nonzero_retired(self):self.exercise("early-failure")

    def test_invalid_request_before_launch(self):
        for timeout in (0,-1,float("inf"),float("nan"),True):
            with self.subTest(timeout=timeout),self.assertRaises(ValueError):
                subject.run_campaign([sys.executable,"-c","raise SystemExit(99)"],cwd=self.output,timeout=timeout)
        for command in ([],[7],["bad\0command"]):
            with self.subTest(command=command),self.assertRaises(ValueError):
                subject.run_campaign(command,cwd=self.output,timeout=1)

    def test_launch_failure_retains_exact_child(self):
        folder=self.output/"launch-failure";folder.mkdir()
        record=folder/"retirement.json";owners=[]
        name="_WindowsJob" if os.name=="nt" else "_LinuxGroup"
        base=getattr(subject,name)
        class FailingLaunch(base):
            def launch(owner,command,cwd):
                owners.append(owner)
                super().launch(command,cwd)
                raise OSError("injected failure after child creation")
        command=[sys.executable,"-c","import time;time.sleep(30)"]
        with mock.patch.object(subject,name,FailingLaunch),self.assertRaisesRegex(OSError,"after child creation"):
            subject.run_campaign(command,cwd=folder,timeout=20,record_path=record)
        value=json.loads(record.read_text());child=owners[0].process
        self.assertEqual(value["pid"],child.pid);self.assertTrue(value["retired"])
        self.assertFalse(alive(child.pid));self.assertIsNotNone(child.returncode)
        self.rows.append({"mode":"launch-failure","parent_pid":child.pid,"record":value,
            "scope":"Real child; injected exception after creation before caller assignment."})

    def test_owner_creation_refusal_has_explicit_no_child_proof(self):
        folder=self.output/"owner-creation-refusal";folder.mkdir();record=folder/"retirement.json"
        name="_WindowsJob" if os.name=="nt" else "_LinuxGroup"
        with mock.patch.object(subject,name,side_effect=OSError("injected owner creation refusal")):
            with self.assertRaisesRegex(OSError,"owner creation refusal"):
                subject.run_campaign([sys.executable,"-c","raise SystemExit(99)"],cwd=folder,timeout=20,record_path=record)
        value=json.loads(record.read_text())
        self.assertIs(value["process_created"],False);self.assertIsNone(value["pid"])
        self.assertIs(value["retired"],True)
        self.assertEqual(value["retirement_proof"],{"complete":True,"scope":"no process created","no_process_created":True})
        self.rows.append({"mode":"owner-creation-refusal","record":value,
            "scope":"Injected constructor refusal before creation of any process."})

    def assignment_refusal(self, refuse_kill: bool):
        mode="assignment-and-kill-refusal" if refuse_kill else "assignment-refusal"
        folder=self.output/mode;folder.mkdir();record=folder/"retirement.json"
        owners=[];base=subject._WindowsJob
        class RefusingAssignment(base):
            def __init__(owner):
                super().__init__();owners.append(owner);owner.original_kill=None
                def refuse_assignment(job,handle):
                    owner.original_kill=owner.process.kill
                    if refuse_kill:
                        def denied():raise OSError("injected direct-child termination refusal")
                        owner.process.kill=denied
                    ctypes.set_last_error(5)
                    return False
                owner.api.AssignProcessToJobObject=refuse_assignment
        command=[sys.executable,"-c","from pathlib import Path;import time;Path('resumed').touch();time.sleep(30)"]
        try:
            with mock.patch.object(subject,"_WindowsJob",RefusingAssignment):
                with self.assertRaises(subject.CampaignRetirementError if refuse_kill else OSError):
                    subject.run_campaign(command,cwd=folder,timeout=20,record_path=record)
            value=json.loads(record.read_text());owner=owners[0];child=owner.process
            self.assertEqual(value["pid"],child.pid)
            self.assertIs(value["retired"],not refuse_kill)
            self.assertIs(alive(child.pid),refuse_kill)
            self.assertFalse((folder/"resumed").exists(),"Unassigned child must never execute its code")
            self.rows.append({"mode":mode,"parent_pid":child.pid,"record":value,
                "unassigned_child_alive_at_record":refuse_kill,"child_never_resumed":True,
                "scope":"Actual Windows suspended child; injected assignment and optional termination refusal."})
        finally:
            for owner in owners:
                if owner.process is not None and owner.process.poll() is None:
                    owner.original_kill();owner.process.wait(timeout=10)

    @unittest.skipUnless(os.name=="nt","Actual Windows assignment refusal requires Windows")
    def test_assignment_refusal_retires_suspended_child(self):self.assignment_refusal(False)

    @unittest.skipUnless(os.name=="nt","Actual Windows assignment refusal requires Windows")
    def test_assignment_and_termination_refusal_is_not_retired(self):self.assignment_refusal(True)

    @unittest.skipUnless(os.name=="nt","Actual Windows lifetime accounting requires Windows")
    def test_missing_lifetime_handle_stays_unproven(self):
        folder=self.output/"joined-history";folder.mkdir()
        fixture=folder/"fixture.py";fixture.write_text(FIXTURE)
        record=folder/"retirement.json"
        result=subject.run_campaign([sys.executable,str(fixture),str(folder),"joined-history"],
            cwd=folder,timeout=20,record_path=record)
        value=json.loads(record.read_text());proof=value["retirement_proof"]
        self.assertEqual(result.returncode,0)
        self.assertIs(value["retired"],False)
        self.assertEqual(value["status"],"retirement-unproven")
        self.assertGreater(proof["job_lifetime_processes"],len(proof["retained_job_pids"]))
        self.assertFalse(alive(value["pid"]))
        self.rows.append({"mode":"joined-history","record":value,
            "scope":"Actual Windows child already exited before snapshot; accounting alone does not prove its retirement."})


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    args.output=args.output.resolve();args.output.mkdir(parents=True,exist_ok=False)
    inputs=(Path(__file__),Path(subject.__file__))
    before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    ActualProcessTests.output=args.output
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(ActualProcessTests))
    after={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    passed=result.wasSuccessful() and before==after
    value={"schema":"gen006-campaign-process-retirement-tests-v1","status":"passed" if passed else "failed",
        "platform":sys.platform,"python":sys.version,"supervisor_pid":os.getpid(),"tests":result.testsRun,
        "failures":len(result.failures),"errors":len(result.errors),"skipped":len(result.skipped),"cases":ActualProcessTests.rows,
        "source_sha256":before,"source_after_sha256":after,"source_unchanged":before==after,
        "scope":"Real small Python process trees, including nested writer and unrelated-process controls; no Godot/native gameplay claim."}
    (args.output/"results.json").write_text(json.dumps(value,indent=2)+"\n")
    print("GEN006_CAMPAIGN_RETIREMENT_TESTS "+json.dumps({"status":value["status"],"tests":result.testsRun,"cases":len(value["cases"])}),flush=True)
    return 0 if passed else 1


if __name__=="__main__":raise SystemExit(main())
