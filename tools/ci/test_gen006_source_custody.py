"""Independent regression probes for confirmed GEN006 source-custody failures."""
import importlib, pathlib, subprocess, sys, tempfile, unittest
ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tools/ci"))
runner=importlib.import_module("run_persistent_areas_qualification")
class SourceCustody(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.root=pathlib.Path(self.temp.name)
        for name in ("Makefile","tools/build_native_extension.sh","tools/build_native_extension_windows.sh","tools/ci/run_persistent_areas_qualification.py","tools/ci/run_gen006_storage_recovery.py","godot/probe.gd","godot/probe.gdshader"):
            p=self.root/name; p.parent.mkdir(parents=True,exist_ok=True); p.write_text("# fixture\n")
        self.git("init","-q"); self.commit()
    def tearDown(self): self.temp.cleanup()
    def git(self,*args):
        return subprocess.check_output(["git",*args],cwd=self.root,text=True)
    def commit(self):
        self.git("add","."); self.git("-c","user.name=Independent review","-c","user.email=review@example.test","commit","-qm","fixture")
    def delta(self): return runner.source_identity(self.root/"godot")["local_delta"]
    def test_generated_script_and_shader_uids_are_not_source_drift(self):
        for name in ("probe.gd.uid","probe.gdshader.uid"): (self.root/"godot"/name).write_text("uid://generated\n")
        self.assertEqual(self.delta(),[])
    def test_modified_tracked_uid_is_source_drift(self):
        p=self.root/"godot/probe.gd.uid";p.write_text("uid://original\n");self.commit();p.write_text("uid://changed\n")
        self.assertTrue(any("probe.gd.uid" in item for item in self.delta()))
    def test_untracked_unknown_uid_is_source_drift(self):
        (self.root/"godot/unknown.gd.uid").write_text("uid://unknown\n")
        self.assertTrue(any("unknown.gd.uid" in item for item in self.delta()))
    def test_first_unstaged_runtime_delta_preserves_porcelain_columns(self):
        p=self.root/"godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so";p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b"old runtime");self.commit();p.write_bytes(b"source built runtime")
        self.assertTrue(self.git("status","--porcelain=v1").startswith(" M "))
        self.assertEqual(self.delta(),[])
if __name__=="__main__":unittest.main()
