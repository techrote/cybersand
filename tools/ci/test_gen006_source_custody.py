"""Independent regression probes for confirmed GEN006 source-custody failures."""
import ast, copy, hashlib, importlib, json, pathlib, subprocess, sys, tempfile, unittest
from types import SimpleNamespace
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
class PortableCustodyPaths(unittest.TestCase):
    """Exercise the actual producer expressions, including Windows on Linux CI.

    Git source keys and archive members use slash separators on both platforms.
    Hash values still identify the original bytes; the verifier is not allowed
    to repair a producer's receipt after execution.
    """
    # Direct campaign/build producers and the packaging helpers this profile
    # reuses. Counts force review when another relative-path producer is added.
    PRODUCERS = {
        "tools/ci/build_gentek80_runtime.py": 1,
        "tools/ci/run_windows_godot_regressions.py": 1,
        "tools/ci/native_candidate_identity.py": 2,
        "tools/ci/run_persistent_areas_qualification.py": 2,
        "tools/ci/run_persistent_area_ramcache_qualification.py": 1,
        "tools/ci/run_persistent_area_recovery.py": 1,
        "tools/ci/run_persistent_area_residency_memory.py": 2,
        "tools/ci/run_workbench_qualification.py": 1,
        "tools/package_gen006_persistent_areas.py": 2,
        "tools/package_gen006_ramcache.py": 1,
        "tools/package_explore001_candidate.py": 2,
        "tools/package_wave_flow_candidate.py": 1,
    }
    ROOTS = (
        pathlib.PureWindowsPath("C:/work/cybersand"),
        pathlib.PureWindowsPath("D:/Path With Spaces/CyberSand"),
        pathlib.PureWindowsPath("//server/share/CyberSand"),
        pathlib.PurePosixPath("/work/Path With Spaces/CyberSand"),
    )

    @staticmethod
    def tree(relative):
        return ast.parse((ROOT / relative).read_text(encoding="utf-8"), filename=relative)

    @staticmethod
    def evaluate(node, namespace):
        return eval(compile(ast.Expression(copy.deepcopy(node)), "<actual producer expression>", "eval"), namespace)

    def test_all_current_relative_key_expressions_match_git_paths(self):
        for relative, count in self.PRODUCERS.items():
            tree = self.tree(relative)
            parents = {child: node for node in ast.walk(tree) for child in ast.iter_child_nodes(node)}
            calls = [node for node in ast.walk(tree) if isinstance(node, ast.Call)
                     and isinstance(node.func, ast.Attribute) and node.func.attr == "relative_to"]
            self.assertEqual(len(calls), count, relative)
            if relative == "tools/package_explore001_candidate.py":
                self.assertEqual({ast.unparse(call) for call in calls},
                                 {"cli.relative_to(destination)", "p.relative_to(args.output)"})
            for call in calls:
                attribute = parents.get(call)
                expression = parents.get(attribute)
                self.assertIsInstance(attribute, ast.Attribute, (relative, call.lineno))
                self.assertEqual(attribute.attr, "as_posix", (relative, call.lineno))
                self.assertIsInstance(expression, ast.Call, (relative, call.lineno))
                for root in self.ROOTS:
                    for expected in ("godot/scripts/persistent_area_store.gd", "godot/tools/gentek_reciprocal.exe",
                                     "Folder With Spaces/MixedCase-é.txt"):
                        path = root / expected
                        namespace = dict(path=path, p=path, cli=path, ROOT=root, root=root, source_root=root,
                            folder=root, output=root, destination=root, project=root/"godot",
                            args=SimpleNamespace(repo=root, output=root), self=SimpleNamespace(output=root))
                        with self.subTest(producer=relative, line=call.lineno, root=str(root), path=expected):
                            self.assertEqual(self.evaluate(expression, namespace), expected)
                            if isinstance(root, pathlib.PureWindowsPath):
                                # str(relative_to(...)) would emit a foreign key in the CLI binding and inventory.
                                native_key = str(self.evaluate(call, namespace))
                                self.assertEqual(native_key, expected.replace("/", "\\"))
                                self.assertNotEqual(native_key, expected)

    def recovery_identities(self, root):
        tree = self.tree("tools/ci/run_persistent_area_recovery.py")
        functions = [node for node in ast.walk(tree) if isinstance(node, ast.FunctionDef)
                     and node.name == "identities"]
        self.assertEqual(len(functions), 1)
        source_paths = [root/name for name in ("godot/scripts/persistent_area_store.gd",
                                              "native/include/cybersand/world.hpp", "Folder With Spaces/Case-é.gd")]
        args = SimpleNamespace(repo=root, godot=root/"Godot.exe", native=root/"native.dll")
        payloads = {path: ("raw:"+path.name+"\r\n").encode() for path in source_paths+[args.godot, args.native]}
        namespace = dict(args=args, source_files=source_paths,
                         digest=lambda path: hashlib.sha256(payloads[path]).hexdigest())
        module = ast.Module(body=[copy.deepcopy(functions[0])], type_ignores=[])
        exec(compile(module, "<actual recovery identities>", "exec"), namespace)
        return namespace["identities"], payloads, source_paths

    def healthy_verifier(self):
        tree = self.tree("tools/ci/gen006_ramcache_runtime_publication.py")
        functions = [node for node in tree.body if isinstance(node, ast.FunctionDef)
                     and node.name == "verify_healthy_recovery"]
        self.assertEqual(len(functions), 1)
        def require(condition, message):
            if not condition:
                raise RuntimeError(message)
        namespace = {"require": require}
        exec(compile(ast.Module(body=[copy.deepcopy(functions[0])], type_ignores=[]),
                     "<unchanged strict healthy verifier>", "exec"), namespace)
        return namespace["verify_healthy_recovery"]

    @staticmethod
    def proof(identity):
        parent = dict(source_commit="a"*40, source_tree="b"*40, local_delta=[], missing_source_inputs=[],
            source_inputs_sha256=copy.deepcopy(identity["source_files"]),
            engine_sha256=identity["godot_sha256"], native_sha256=identity["native_sha256"])
        before = {key:copy.deepcopy(parent[key]) for key in
                  ("source_commit", "source_tree", "local_delta", "missing_source_inputs", "source_inputs_sha256")}
        proof = dict(passed=True, qualified_source=True, diagnostic=False, source_unchanged=True,
            inputs_unchanged=True, source_before=before, source_after=copy.deepcopy(before),
            before=copy.deepcopy(identity), after=copy.deepcopy(identity),
            runs=[dict(mode=mode, passed=True, exit_code=0, timed_out=False, pid=20+i,
                       observed_pid=20+i, checks=25, failures=0) for i, mode in enumerate(("seed", "verify"))])
        return parent, proof

    def test_recovery_uses_portable_keys_and_preserves_raw_byte_hashes(self):
        verify = self.healthy_verifier()
        for root in self.ROOTS:
            identities, payloads, paths = self.recovery_identities(root)
            before = identities()
            expected = {path.relative_to(root).as_posix(): hashlib.sha256(payloads[path]).hexdigest() for path in paths}
            self.assertEqual(before["source_files"], expected)
            self.assertEqual(identities(), before)
            self.assertNotEqual(expected[paths[0].relative_to(root).as_posix()],
                                hashlib.sha256(payloads[paths[0]].replace(b"\r\n", b"\n")).hexdigest())
            parent, proof = self.proof(before)
            verify(parent, proof)
            payloads[paths[0]] += b"changed source"
            after = identities()
            self.assertNotEqual(after, before)
            proof["before"] = proof["after"] = after
            with self.assertRaisesRegex(RuntimeError, "input/runtime identities"):
                verify(parent, proof)

    def test_strict_recovery_verifier_still_refuses_wrong_keys_hashes_and_identity(self):
        identities, _, _ = self.recovery_identities(self.ROOTS[0])
        parent, original = self.proof(identities())
        verify = self.healthy_verifier()
        for fault in ("backslash_keys", "wrong_digest", "empty_sources", "extra_source", "wrong_case",
                      "engine", "native", "source_commit", "source_tree", "after_changed"):
            proof = copy.deepcopy(original)
            if fault == "source_commit" or fault == "source_tree":
                proof["source_before"][fault] = proof["source_after"][fault] = "f"*40
            elif fault == "after_changed":
                proof["after"]["native_sha256"] = "f"*64
            else:
                for identity in (proof["before"], proof["after"]):
                    files = identity["source_files"]
                    first = next(iter(files))
                    if fault == "backslash_keys": identity["source_files"] = {key.replace("/", "\\"): value for key, value in files.items()}
                    elif fault == "wrong_digest": files[first] = "f"*64
                    elif fault == "empty_sources": identity["source_files"] = {}
                    elif fault == "extra_source": files["unadmitted/source.gd"] = "f"*64
                    elif fault == "wrong_case": files[first.upper()] = files.pop(first)
                    else: identity["godot_sha256" if fault == "engine" else "native_sha256"] = "f"*64
            with self.subTest(fault=fault), self.assertRaises(RuntimeError):
                verify(parent, proof)

    def test_memory_initial_and_final_custody_use_the_same_portable_key(self):
        tree = self.tree("tools/ci/run_persistent_area_residency_memory.py")
        expressions = {}
        for node in ast.walk(tree):
            if isinstance(node, ast.Assign):
                for target in node.targets:
                    if isinstance(target, ast.Name) and target.id in ("hashes", "unchanged"):
                        self.assertNotIn(target.id, expressions)
                        expressions[target.id] = node.value
        self.assertEqual(set(expressions), {"hashes", "unchanged"})
        for root in self.ROOTS:
            sources = [root/"godot/tests/native-memory.gd", root/"Folder With Spaces/fixture.gd"]
            payloads = {path: ("original:"+path.name).encode() for path in sources}
            namespace = dict(args=SimpleNamespace(repo=root), sources=sources,
                digest=lambda path: hashlib.sha256(payloads[path]).hexdigest())
            namespace["hashes"] = self.evaluate(expressions["hashes"], namespace)
            self.assertEqual(set(namespace["hashes"]), {path.relative_to(root).as_posix() for path in sources})
            self.assertTrue(self.evaluate(expressions["unchanged"], namespace))
            payloads[sources[0]] += b"changed"
            self.assertFalse(self.evaluate(expressions["unchanged"], namespace))


if __name__=="__main__":unittest.main()
