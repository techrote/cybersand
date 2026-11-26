#!/usr/bin/env python3
"""Owned-process discovery adversaries; no synthetic gameplay evidence."""
from __future__ import annotations

import copy
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from execute_with_resources import execute_with_resources
from presentation_metrics import validate_cpu_trace
from process_discovery import discover_application, process_identity, validate_discovery


def fixture_process(proc: Path, pid: int, parent: int, start: int, executable: Path):
    folder = proc / str(pid)
    folder.mkdir(parents=True)
    (folder / "status").write_text(f"Name:\tfixture\nPid:\t{pid}\nPPid:\t{parent}\n")
    values = ["S",str(parent)] + ["0"] * 18
    values[19] = str(start)
    (folder / "stat").write_text(f"{pid} (fixture (odd) name) " + " ".join(values))
    (folder / "exe").symlink_to(executable)


class DiscoveryTests(unittest.TestCase):
    def test_absent_children_finds_only_owned_executable_and_creation_chain(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            engine, other = root / "engine", root / "other"
            engine.write_bytes(b"engine"); other.write_bytes(b"wrapper")
            proc = root / "proc"
            for row in ((10,1,100,other),(11,10,200,other),(12,11,300,engine),(99,1,400,engine)):
                fixture_process(proc,*row)
            record = discover_application(10,engine,proc)
            self.assertEqual(record["method"],"status_parent_graph")
            self.assertEqual([row["pid"] for row in record["ancestry"]],[10,11,12])
            validate_discovery(record,owner_pid=10,pid=12,creation_identity="linux-start-ticks:300",executable=engine)
            # A changed parent or earlier-than-parent birth cannot be borrowed.
            (proc / "12/status").write_text("Pid:\t12\nPPid:\t99\n")
            self.assertIsNone(discover_application(10,engine,proc))
            (proc / "12/status").write_text("Pid:\t12\nPPid:\t11\n")
            original = process_identity
            def changed_identity(pid, where=Path("/proc")):
                row = original(pid,where)
                if pid == 12:
                    row.update(start_ticks=50,creation_identity="linux-start-ticks:50")
                return row
            with patch("process_discovery.process_identity",side_effect=changed_identity):
                self.assertIsNone(discover_application(10,engine,proc))

    def test_receipt_refuses_foreign_root_pid_reuse_parent_and_executable(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder); engine=root/"engine"; engine.write_bytes(b"engine")
            other=root/"other"; other.write_bytes(b"other")
            proc=root/"proc"
            fixture_process(proc,10,1,100,other);fixture_process(proc,11,10,200,engine)
            record=discover_application(10,engine,proc)
            for change in (
                lambda x:x.update(owner_pid=99),lambda x:x.update(executable=str(other)),
                lambda x:x.update(method="owned_root"),
                lambda x:x.update(creation_identity="linux-start-ticks:201"),
                lambda x:x["ancestry"][1].update(parent_pid=99),
                lambda x:x["ancestry"][0].update(start_ticks=300,creation_identity="linux-start-ticks:300"),
                lambda x:x["ancestry"].append(x["ancestry"][0])):
                altered=copy.deepcopy(record);change(altered)
                with self.assertRaises(ValueError):
                    validate_discovery(altered,owner_pid=10,pid=11,
                                       creation_identity="linux-start-ticks:200",executable=engine)

    def test_permission_error_never_authorizes_broader_proc_scan(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);engine=root/"engine";engine.write_bytes(b"engine")
            other=root/"other";other.write_bytes(b"other");proc=root/"proc"
            fixture_process(proc,10,1,100,other);fixture_process(proc,11,10,200,engine)
            original=Path.read_text
            def read(path,*args,**kwargs):
                if path.name == "children":
                    raise PermissionError("deliberate proc child permission refusal")
                return original(path,*args,**kwargs)
            with patch.object(Path,"read_text",read),patch.object(Path,"iterdir",side_effect=AssertionError("forbidden fallback")):
                self.assertIsNone(discover_application(10,engine,proc))

    def test_actual_lookup_refuses_child_and_ancestor_birth_change_during_final_read(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);engine=root/"engine";engine.write_bytes(b"engine")
            other=root/"other";other.write_bytes(b"other");proc=root/"proc"
            fixture_process(proc,10,1,100,other);fixture_process(proc,11,10,200,engine)
            children=proc/"10/task/10/children";children.parent.mkdir(parents=True);children.write_text("11")
            original=process_identity
            for replaced_pid in (10,11):
                reads={}
                def replaced(pid,where=Path("/proc")):
                    row=original(pid,where);reads[pid]=reads.get(pid,0)+1
                    if pid == replaced_pid and reads[pid] >= 2:
                        row.update(start_ticks=row["start_ticks"]+1,
                                   creation_identity="linux-start-ticks:"+str(row["start_ticks"]+1))
                    return row
                with self.subTest(replaced_pid=replaced_pid),patch("process_discovery.process_identity",side_effect=replaced):
                    self.assertIsNone(discover_application(10,engine,proc))

    @unittest.skipUnless(sys.platform.startswith("linux"),"Linux proc ancestry")
    def test_live_owned_wrapped_process_and_independent_cpu_receipt(self):
        # A sleeping Python child behind a different executable (the shell)
        # exercises actual descendants even on this kernel without children.
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);wrapper=root/"wrapper.sh"
            wrapper.write_text('#!/bin/sh\n"$@"\nstatus=$?\nexit "$status"\n');wrapper.chmod(0o755)
            engine=Path(sys.executable).resolve()
            report=execute_with_resources(engine,["-c","import time; time.sleep(1.0)"],root/"run","f"*40,{},10,wrapper)
            self.assertNotEqual(report["wrapper_pid"],report["observed_application_pid"])
            self.assertTrue(report["process_cpu"]["summary"]["complete"])
            self.assertFalse(report["surviving_children_at_exit"])
            chain=report["application_discovery"]["ancestry"]
            self.assertEqual(chain[0]["pid"],report["wrapper_pid"])
            self.assertEqual(chain[-1]["pid"],report["observed_application_pid"])
            receipt={"source_identity":{"source_sha":"f"*40,
                     "engine_sha256":hashlib.sha256(engine.read_bytes()).hexdigest()},
                     "process_id":report["observed_application_pid"]}
            self.assertTrue(validate_cpu_trace(root/"run/process-cpu.json",report,receipt)["complete"])
            report["application_discovery"]["creation_identity"] += "-reused"
            with self.assertRaises(ValueError):
                validate_cpu_trace(root/"run/process-cpu.json",report,receipt)


if __name__ == "__main__":
    unittest.main()
