#!/usr/bin/env python3
"""Adversarial checks: artifacts must match a separately derived source contract."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import verify_windows_godot_shards as subject

SOURCE = "a" * 40


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def case(name: str) -> dict:
    return {"name": name, "flags": ["--script", f"res://tests/{name}.gd"],
            "timeout_seconds": 180, "estimated_seconds": 5.0, "requires_display": False}


def fixture_contract() -> tuple[dict, bytes]:
    manifest = {"schema_version": 1, "source_commit": "b" * 40,
                "build_commit": "c" * 40, "sha256": "d" * 64, "size": 1234,
                "source_inputs": {"native/src/world.cpp": "e" * 64}}
    raw = (json.dumps(manifest) + "\n").encode()
    expected = {
        "source_tree": "f" * 40, "all_discovered_case_count": 4,
        "applicable_case_count": 3, "applicable_cases": ["alpha", "beta", "gamma"],
        "out_of_scope_graphical_cases": ["visual_render"],
        "plans": [[case("alpha"), case("gamma")], [case("beta")]],
        "runtime_source_commit": manifest["source_commit"],
        "runtime_build_commit": manifest["build_commit"],
        "runtime_provenance": {"path": "godot/addons/cybersand_native/runtime-provenance.json",
                               "sha256": digest(raw)},
        "native_source_inputs": manifest["source_inputs"],
        "cybersand_runtime": {"path": "native.dll", "sha256": "d" * 64, "size": 1234},
        "rapier_runtime": {"path": "rapier.dll", "sha256": "1" * 64, "size": 2345},
        "godot_version": "4.7.test-fixture", "godot_archive_sha512": "2" * 128,
        "tested_input_paths": ["godot/tests/alpha.gd", "native/src/world.cpp"],
    }
    return expected, raw


def make_fixture(root: Path, expected: dict, manifest: bytes) -> None:
    for shard, plan in enumerate(expected["plans"]):
        directory = root / f"shard-{shard}"
        directory.mkdir()
        (directory / "runtime-provenance.json").write_bytes(manifest)
        report = {k: copy.deepcopy(v) for k, v in expected.items()
                  if k not in ("plans", "tested_input_paths", "godot_archive_sha512")}
        report.update({
            "source_commit": SOURCE, "run_id": "123", "run_attempt": "1",
            "shard_count": 2, "shard_index": shard, "status": "passed", "completed": True,
            "errors": [], "source_drift": [], "assigned_cases": [c["name"] for c in plan],
            "case_plan": plan, "executed_case_count": len(plan), "results": [], "log_sha256": {},
            "godot_identity": {"version": expected["godot_version"],
                "archive_sha512": expected["godot_archive_sha512"], "archive_size": 3456,
                "console_sha256": "3" * 64, "runtime_sha256": "4" * 64},
            "tested_inputs": {p: "5" * 64 for p in expected["tested_input_paths"]},
        })
        preflight = {"name": "import", "timeout_seconds": 240, "requires_display": False,
                     "flags": ["--editor", "--quit"]}
        for role, item in [("preflight", preflight), *[("case", c) for c in plan]]:
            name = item["name"]; log = name + ".log"; data = (name + " passed\n").encode()
            (directory / log).write_bytes(data)
            report["results"].append({"role": role, "name": name, "status": "passed",
                "log": log, "returncode": 0, "skip_messages": [],
                "requires_display": False, "timeout_seconds": item["timeout_seconds"],
                "command": ["Godot_console.exe", "--headless", "--path", "godot", *item["flags"]]})
            report["log_sha256"][log] = digest(data)
        (directory / "windows-execution.json").write_text(json.dumps(report), encoding="utf-8")


class WindowsCoverageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.expected, self.manifest = fixture_contract()
        make_fixture(self.root, self.expected, self.manifest)

    def verify(self):
        return subject.verify(self.root, SOURCE, "123", "1", 2, expected=self.expected)

    def mutate(self, shard, change):
        path = self.root / f"shard-{shard}" / "windows-execution.json"
        data = json.loads(path.read_text(encoding="utf-8")); change(data)
        path.write_text(json.dumps(data), encoding="utf-8")

    def test_complete_source_matched_shards(self):
        result = self.verify()
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["unique_case_count"], 3)
        self.assertEqual(result["raw_logs_verified"], 5)

    def test_coordinated_omission_cannot_redefine_source_inventory(self):
        def omit(report):
            report["applicable_cases"].remove("gamma")
            report["applicable_case_count"] -= 1
            report["all_discovered_case_count"] -= 1
            if "gamma" in report["assigned_cases"]:
                report["assigned_cases"].remove("gamma")
                report["case_plan"] = [r for r in report["case_plan"] if r["name"] != "gamma"]
                report["results"] = [r for r in report["results"] if r["name"] != "gamma"]
                report["log_sha256"].pop("gamma.log"); report["executed_case_count"] -= 1
        self.mutate(0, omit); self.mutate(1, omit)
        with self.assertRaisesRegex(ValueError, "source-derived"):
            self.verify()

    def test_both_empty_runtime_identities_are_not_authority(self):
        for index in (0, 1):
            self.mutate(index, lambda r: r.update(runtime_provenance=None, native_source_inputs=None,
                                                 cybersand_runtime=None, rapier_runtime=None))
        with self.assertRaisesRegex(ValueError, "source-derived"):
            self.verify()

    def test_missing_runtime_manifest(self):
        (self.root / "shard-0/runtime-provenance.json").unlink()
        with self.assertRaisesRegex(ValueError, "original runtime manifest"):
            self.verify()

    def test_tampered_manifest_with_unchanged_report(self):
        (self.root / "shard-0/runtime-provenance.json").write_text("{}")
        with self.assertRaisesRegex(ValueError, "original runtime manifest"):
            self.verify()

    def test_two_consistently_resealed_manifest_edits_are_refused(self):
        for index in (0, 1):
            (self.root / f"shard-{index}/runtime-provenance.json").write_text("{}")
            self.mutate(index, lambda r: r["runtime_provenance"].update(sha256=digest(b"{}")))
        with self.assertRaisesRegex(ValueError, "source-derived runtime_provenance"):
            self.verify()

    def test_shared_false_source_tree(self):
        for index in (0, 1): self.mutate(index, lambda r: r.update(source_tree="9" * 40))
        with self.assertRaisesRegex(ValueError, "source-derived source_tree"):
            self.verify()

    def test_missing_shard(self):
        (self.root / "shard-1/windows-execution.json").unlink()
        with self.assertRaisesRegex(ValueError, "expected 2"):
            self.verify()

    def test_duplicate_shard_index(self):
        self.mutate(1, lambda r: r.update(shard_index=0))
        with self.assertRaisesRegex(ValueError, "invalid shard"):
            self.verify()

    def test_wrong_source(self):
        self.mutate(1, lambda r: r.update(source_commit="8" * 40))
        with self.assertRaisesRegex(ValueError, "wrong source"):
            self.verify()

    def test_changed_native_runtime(self):
        self.mutate(1, lambda r: r["cybersand_runtime"].update(sha256="8" * 64))
        with self.assertRaisesRegex(ValueError, "source-derived cybersand_runtime"):
            self.verify()

    def test_duplicate_case_with_correct_log_seal(self):
        # Re-seal the new log correctly: refusal must be the source plan check,
        # not accidentally the byte-hash check as in the former negative test.
        (self.root / "shard-1/alpha.log").write_bytes(b"alpha passed\n")
        def duplicate(r):
            r["assigned_cases"] = ["alpha"]; r["case_plan"] = [case("alpha")]
            row = r["results"][1]; row.update(name="alpha", log="alpha.log")
            row["command"][-1] = "res://tests/alpha.gd"
            r["log_sha256"].pop("beta.log"); r["log_sha256"]["alpha.log"] = digest(b"alpha passed\n")
        self.mutate(1, duplicate)
        with self.assertRaisesRegex(ValueError, "source-derived shard plan"):
            self.verify()

    def test_corrupted_log(self):
        (self.root / "shard-0/alpha.log").write_bytes(b"tampered")
        with self.assertRaisesRegex(ValueError, "modified or missing original raw log"):
            self.verify()

    def test_case_watchdog_change(self):
        self.mutate(0, lambda r: r["results"][1].update(timeout_seconds=99999))
        with self.assertRaisesRegex(ValueError, "command or watchdog"):
            self.verify()

    def test_wrong_command(self):
        self.mutate(0, lambda r: r["results"][1]["command"].__setitem__(-1, "res://other.gd"))
        with self.assertRaisesRegex(ValueError, "command or watchdog"):
            self.verify()

    def test_skipped_case(self):
        self.mutate(0, lambda r: r["results"][1].update(status="skipped"))
        with self.assertRaisesRegex(ValueError, "missing, duplicated, unexecuted or failed"):
            self.verify()

    def test_forged_pass_with_nonzero_exit(self):
        self.mutate(0, lambda r: r["results"][1].update(returncode=1))
        with self.assertRaisesRegex(ValueError, "nonpassing execution detail"):
            self.verify()

    def test_wrong_attempt(self):
        self.mutate(0, lambda r: r.update(run_attempt="2"))
        with self.assertRaisesRegex(ValueError, "wrong run/attempt"):
            self.verify()

    def test_godot_pin_change(self):
        for index in (0, 1):
            self.mutate(index, lambda r: r["godot_identity"].update(archive_sha512="0" * 128))
        with self.assertRaisesRegex(ValueError, "pinned Godot"):
            self.verify()

    def test_removed_source_input(self):
        for index in (0, 1):
            self.mutate(index, lambda r: r["tested_inputs"].pop("native/src/world.cpp"))
        with self.assertRaisesRegex(ValueError, "source input inventory"):
            self.verify()

    def test_symlinked_log_is_refused(self):
        path = self.root / "shard-0/alpha.log"; data = path.read_bytes(); path.unlink()
        outside = self.root / "outside.log"; outside.write_bytes(data)
        try:
            path.symlink_to(outside)
        except OSError:
            # Windows hosts without symlink rights still check path traversal.
            self.mutate(0, lambda r: r["log_sha256"].update({"../outside.log": digest(data)}))
        with self.assertRaises(ValueError):
            self.verify()

    def test_profile_timeout_is_not_misclassified_as_default_budget(self):
        # Preserve the source planner's profile-specific deadline, not a
        # blanket 180-second assertion that would silently drop existing scope.
        self.expected["plans"][0][0]["timeout_seconds"] = 1200
        self.mutate(0, lambda r: (r["case_plan"][0].update(timeout_seconds=1200),
                                 r["results"][1].update(timeout_seconds=1200)))
        self.assertEqual(self.verify()["status"], "passed")


class SourceContractTests(unittest.TestCase):
    """Real temporary Git checkout; discovery/runtime providers are explicit fixtures."""
    def setUp(self):
        import subprocess
        import types
        from unittest import mock
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        def git(root, *args):
            return subprocess.check_output(["git", "-C", str(root), *args], stderr=subprocess.PIPE)
        self.git = git
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        git(self.root, "config", "user.name", "fixture"); git(self.root, "config", "user.email", "fixture@example.invalid")
        native = "godot/addons/cybersand_native/bin/native.dll"
        rapier = "godot/addons/godot-rapier2d/bin/rapier.dll"
        provenance = "godot/addons/cybersand_native/runtime-provenance.json"
        self.native = native; self.provenance = provenance
        files = {"native/src/world.cpp": b"frozen\n", "godot/tests/test_one.gd": b"extends Node\n",
                 "godot/tests/test_two.gd": b"extends Node\n"}
        for path, hashchar, size in ((native, "d", 1234), (rapier, "1", 2345)):
            files[path] = (f"version https://git-lfs.github.com/spec/v1\noid sha256:{hashchar * 64}\nsize {size}\n").encode()
        manifest = {"schema_version": 1, "artifact": native, "source_commit": "b" * 40,
                    "build_commit": "c" * 40, "sha256": "d" * 64, "size": 1234,
                    "source_inputs": {"native/src/world.cpp": digest(files["native/src/world.cpp"])}}
        files[provenance] = json.dumps(manifest).encode()
        for relative, content in files.items():
            path = self.root / relative; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(content)
        git(self.root, "add", "."); git(self.root, "commit", "-qm", "fixture source")
        self.sha = git(self.root, "rev-parse", "HEAD").decode().strip()
        records = [types.SimpleNamespace(**{**case(name), "timeout": 180, "weight": 5.0})
                   for name in ("test_one", "test_two")]
        self.runner = types.SimpleNamespace(
            discover_cases=mock.Mock(return_value=records),
            build_shard_plan=mock.Mock(return_value=([[records[0]], [records[1]]], [5.0, 5.0])),
            case_dict=lambda c: case(c.name))
        self.windows = types.SimpleNamespace(
            git=git, INPUT_SCOPES=("godot", "native"), PROVENANCE=provenance,
            NATIVE=native, RAPIER=rapier, RAPIER_SHA256="1" * 64,
            GODOT_VERSION="4.7.fixture", GODOT_SHA512="2" * 128,
            native_input_paths=lambda root: {"native/src/world.cpp"})
        patch = mock.patch.dict("sys.modules", {"run_godot_regressions": self.runner,
                    "run_windows_godot_regressions": self.windows})
        patch.start(); self.addCleanup(patch.stop)

    def contract(self):
        return subject.source_contract(self.root, self.sha, 2)

    def test_exact_checkout_derives_inventory_and_lfs_without_binary(self):
        expected = self.contract()
        self.assertEqual(expected["applicable_cases"], ["test_one", "test_two"])
        self.assertEqual(expected["source_tree"], self.git(self.root, "rev-parse", "HEAD^{tree}").decode().strip())
        self.assertEqual(expected["cybersand_runtime"]["sha256"], "d" * 64)
        self.assertIn("native/src/world.cpp", expected["tested_input_paths"])
        self.runner.discover_cases.assert_called_once_with(self.root)

    def test_wrong_checkout_sha(self):
        with self.assertRaisesRegex(ValueError, "coverage checkout"):
            subject.source_contract(self.root, "0" * 40, 2)

    def test_dirty_source_is_rejected(self):
        import subprocess
        (self.root / "native/src/world.cpp").write_text("changed\n")
        with self.assertRaises(subprocess.CalledProcessError):
            self.contract()

    def test_committed_stale_manifest_is_rejected(self):
        (self.root / "native/src/world.cpp").write_text("changed\n")
        self.git(self.root, "add", "."); self.git(self.root, "commit", "-qm", "stale source")
        self.sha = self.git(self.root, "rev-parse", "HEAD").decode().strip()
        with self.assertRaisesRegex(ValueError, "manifest is stale"):
            self.contract()

    def test_mismatched_committed_lfs_pointer_is_rejected(self):
        path = self.root / self.native
        path.write_text(path.read_text().replace("d" * 64, "9" * 64))
        self.git(self.root, "add", "."); self.git(self.root, "commit", "-qm", "mismatched pointer")
        self.sha = self.git(self.root, "rev-parse", "HEAD").decode().strip()
        with self.assertRaisesRegex(ValueError, "pointer differs"):
            self.contract()

    def test_empty_source_discovery_is_not_passed(self):
        self.runner.discover_cases.return_value = []
        with self.assertRaisesRegex(ValueError, "no applicable"):
            self.contract()


if __name__ == "__main__":
    unittest.main()
