"""Keep the generated-probe egress guard narrow and source-independent."""
import os
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PortableLabGuardTests(unittest.TestCase):
    def test_temp_world_probe_is_selected_but_toolchain_and_unexpected_exes_are_not(self):
        program = r'''
import os, sys, tempfile
from pathlib import Path
root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools/pubpres_mainline"))
from portable_lab_witness import generated_world_executable
import portable_authoring
import subprocess
from types import SimpleNamespace
with tempfile.TemporaryDirectory() as temporary:
    fixture = Path(temporary)
    temp_root = fixture / "system-temp"
    work = temp_root / "cybersand-lab-world-fixture" / "reference"
    work.mkdir(parents=True)
    world = work / "lab-world-probe.exe"
    world.write_bytes(b"native probe")
    assert generated_world_executable([str(world), "2"], work, temp_root) == world.resolve()
    assert generated_world_executable(["lab-world-probe.exe", "2"], work, temp_root) == world.resolve()
    candidate = temp_root / "cybersand-lab-world-fixture" / "candidate"
    candidate.mkdir()
    candidate_probe = candidate / "lab-world-probe.exe"
    candidate_probe.write_bytes(b"candidate probe")
    assert generated_world_executable([str(candidate_probe), "2"], candidate, temp_root) == candidate_probe.resolve()
    compiler = temp_root / "package/dependencies/cxx/bin/g++.exe"
    compiler.parent.mkdir(parents=True)
    compiler.write_bytes(b"compiler")
    os.environ["CYBERSAND_LAB_CXX"] = str(compiler)
    assert generated_world_executable([str(compiler)], work, temp_root) is None
    unexpected_outside_stage = temp_root / "scratch/unexpected.exe"
    unexpected_outside_stage.parent.mkdir(parents=True)
    unexpected_outside_stage.write_bytes(b"unrelated temp exe")
    assert generated_world_executable([str(unexpected_outside_stage)], unexpected_outside_stage.parent, temp_root) is None
    unexpected = work / "unexpected.exe"
    unexpected.write_bytes(b"unexpected")
    try:
        generated_world_executable([str(unexpected)], work, temp_root)
    except RuntimeError:
        pass
    else:
        raise AssertionError("unexpected temporary executable was admitted")
class Observer:
    roots = []
    def register_root(self, process):
        self.roots.append(process)
observer = Observer()
original = subprocess.Popen
subprocess.Popen = lambda *args, **kwargs: SimpleNamespace(pid=len(args) + 1)
try:
    with portable_authoring.capture_popen_roots(observer):
        subprocess.Popen(["foreign.exe"], creationflags=0)
        subprocess.Popen(["owned.exe"], creationflags=portable_authoring.lab.process_owner.CREATE_SUSPENDED)
finally:
    subprocess.Popen = original
assert len(observer.roots) == 1 and observer.roots[0].pid == 2
print("portable-lab-guard-controls-passed")
'''
        completed = subprocess.run([sys.executable, "-B", "-c", program, str(ROOT)], cwd=ROOT,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=30,
                                   env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})
        self.assertEqual(completed.returncode, 0, completed.stderr.decode("utf-8", errors="replace"))
        self.assertIn(b"portable-lab-guard-controls-passed", completed.stdout)


if __name__ == "__main__":
    unittest.main()
