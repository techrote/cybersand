"""Independent regression probes for confirmed GEN006 source-custody failures."""
import importlib, json, pathlib, subprocess, sys, tempfile, unittest
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
    def test_known_importer_line_endings_are_canonical_but_semantic_changes_fail(self):
        path="godot/addons/godot-rapier2d/icons/Fluid2D.svg.import"
        p=self.root/path;p.parent.mkdir(parents=True,exist_ok=True)
        (self.root/".gitattributes").write_text("*.import -text\n")
        original=b'[remap]\r\nimporter="texture"\r\n'
        p.write_bytes(original);self.commit()
        before=runner.source_identity(self.root/"godot")
        p.write_bytes(original.replace(b"\r\n",b"\n"))
        self.assertTrue(self.git("status","--porcelain=v1").startswith(" M "))
        self.assertEqual(runner.source_identity(self.root/"godot"),before)
        p.write_bytes(b'[remap]\nimporter="different"\n')
        after=runner.source_identity(self.root/"godot")
        self.assertTrue(any(path in row for row in after["local_delta"]))
        self.assertNotEqual(before["source_inputs_sha256"][path],after["source_inputs_sha256"][path])
    def test_custody_diff_preserves_changed_added_removed_source_and_binaries(self):
        before=runner.source_identity(self.root/"godot")
        (self.root/"godot/probe.gd").write_text("# changed\n")
        (self.root/"godot/probe.gdshader").unlink()
        (self.root/"godot/new.gd").write_text("# added\n")
        after=runner.source_identity(self.root/"godot")
        observed=runner.custody_difference(before,after,{"native_sha256":"a"},{"native_sha256":"b"})
        self.assertFalse(observed["unchanged"])
        self.assertEqual(set(observed["source_changed"]),{"godot/probe.gd"})
        self.assertEqual(set(observed["source_removed"]),{"godot/probe.gdshader"})
        self.assertEqual(set(observed["source_added"]),{"godot/new.gd"})
        self.assertEqual(observed["binaries_after"],{"native_sha256":"b"})
    def test_missing_mandatory_source_is_recorded_without_losing_diagnostics(self):
        before=runner.source_identity(self.root/"godot")
        (self.root/"tools/ci/run_persistent_areas_qualification.py").unlink()
        after=runner.source_identity(self.root/"godot")
        path="tools/ci/run_persistent_areas_qualification.py"
        self.assertIn(path,after["missing_source_inputs"])
        self.assertIn(path,runner.custody_difference(before,after,{},{} )["source_removed"])
    def test_failed_binary_observation_is_written_to_original_custody_report(self):
        campaign=runner.Campaign.__new__(runner.Campaign)
        campaign.project=self.root/"godot";campaign.output=self.root/"evidence";campaign.output.mkdir()
        campaign.native=self.root/"native.bin";campaign.rapier=self.root/"rapier.bin";campaign.engine=self.root/"engine.bin"
        for path in (campaign.native,campaign.rapier,campaign.engine):path.write_bytes(b"fixture")
        campaign.identity=runner.source_identity(campaign.project);campaign.custody_checks=[]
        campaign.report={key:runner.sha(path) for key,path in (("native_sha256",campaign.native),("rapier_sha256",campaign.rapier),("engine_sha256",campaign.engine))}
        campaign.native.unlink()
        self.assertFalse(campaign.record_custody("after-failure"))
        proof=json.loads((campaign.output/"source-custody.json").read_text())
        self.assertIsNone(proof["checks"][0]["binaries_after"]["native_sha256"])
        self.assertEqual(campaign.report["input_custody"],"failed")
if __name__=="__main__":unittest.main()
