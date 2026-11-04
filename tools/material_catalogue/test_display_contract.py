"""Actual file mutations against the bounded B admission (all in temp copies)."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import compatibility
import display_contract as contract
import legacy_display_names as legacy
import presentation
from consumer_test_support import copy_b_inputs


ACCEPTED_MAIN = "751edc0b495dc85484ad5509a7c95f863651c76b"
ACCEPTED_TREE = "b0d42a256285e6049a6d3bdd1613d7ecd89f43c6"
PRE390_MAIN = "0103de80d11304388868f89f7b26c672ad6100ad"
PRE390_TREE = "0ba07dc799afca43716bbab966f48266fa924718"
PRE377_MAIN = "01f9b7c8e382ca6bdbaf0bf70c7847adc12fe0bc"
PRE377_TREE = "4cf99921dc2b33233c3a254f4b6f27ed7cb0f204"
LEGACY_MAIN = "7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1"
LEGACY_TREE = "36ce5a01e754a141c321f41cac7f1c6b6059c371"
FROZEN_AUTHORITY = "0fd4af5987e77db4da3e37c757cf2c0917ae9e15"
BENCHMARK = "native/bench/lcb201_pressure_idle_cost.cpp"
BENCHMARK_BLOB = "d251777990a137d42264275e7eb25a6ab6760af7"
BENCHMARK_SHA256 = "872c65fdc684a01ace9b55bfb6e92181070c21b34503f4460e4d8f8cf0297e6d"
PROBE = "native/tests/material_liveness_probe.cpp"
PROBE_BLOB = "5185801e469cfed975b901243a42f3a02a0e1ee4"
PROBE_SHA256 = "26e421d2b9de3e4e6c0c6e7e74f503f3f26f7baf17b02c6d02712eb15dcc9bb9"
PROBE_FIXTURE = "native/tests/fixtures/material_liveness_campaign_v1.json"
PROBE_FIXTURE_SHA256 = "320bd76b5bc69d68fe7ed21324999f9f1b9272109da646138a2b31820f1f2b4b"
WORKER = "godot/scripts/simulation_worker.gd"
REGION_TESTS = ("godot/tests/lcb201_pressure_host_case.gd",
                "godot/tests/test_simulation_worker_interest_ownership.gd")
REGION_SOURCE_IDENTITIES = {
    WORKER: ("ff5ddf9026476c52717650e747f367bb1f6bd5e5",
             "6b1c27ff4e0013db58436079834ceae2c26589a752ee166462437c9aff2dbdbf"),
    REGION_TESTS[0]: ("31a213fb6edeff23a403de8309e45262c75768d4",
                      "420ffd9afb23f7b7cd0198c4de4671e92c391f3ac170d681bb7ebd3f848f5532"),
    REGION_TESTS[1]: ("b422610c5119fef79ea5309e0bdd4ac00953149e",
                      "aaf52310f6d73fd3fb469996eea4938334b0fed96da23a888562e54b24766d2d"),
}
LOCK_SHA256 = "8b4d3351cbe4380e976655d10dc34c4bf9e81d95442719a53770b62d219183dc"
ORACLE_SHA256 = "f7c27a60ddd6185c78b2fcc1fab956a0496021024090b467b8071305239d30a1"


class DisplayContractTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="mat353b-source-guards-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        copy_b_inputs(self.root)

    def check(self):
        return contract.check(self.root)

    def test_fixture_copy_refuses_the_real_source_checkout_before_writing(self):
        path = contract.ROOT / contract.MAIN
        before = (path.read_bytes(), path.stat().st_mtime_ns)
        for target in (contract.ROOT, contract.ROOT / "tools/material_catalogue"):
            with self.subTest(target=target), self.assertRaisesRegex(ValueError, "outside the task source"):
                copy_b_inputs(target)
        self.assertEqual(before, (path.read_bytes(), path.stat().st_mtime_ns))

    def test_actual_admitted_source_nonwriting(self):
        before = {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in self.root.rglob("*") if p.is_file()}
        report = self.check()
        self.assertEqual(report["status"], "PASS")
        self.assertFalse(report["runtime_execution"])
        self.assertTrue(report["b_consumer_report_required"])
        self.assertEqual(before, {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in before})

    def test_374_benchmark_is_authenticated_as_accepted_source(self):
        accepted = subprocess.run(
            ["git", "-C", str(contract.ROOT), "show", ACCEPTED_MAIN + ":" + BENCHMARK],
            check=True, capture_output=True, timeout=30).stdout
        self.assertEqual(hashlib.sha256(accepted).hexdigest(), BENCHMARK_SHA256)
        self.assertEqual((self.root / BENCHMARK).read_bytes(), accepted)
        inventory = contract.script_inventory()
        self.assertEqual(inventory[BENCHMARK], BENCHMARK_BLOB)
        with patch.object(contract, "B_ADMISSION_BASELINE", PRE377_MAIN), \
                patch.object(contract, "B_ADMISSION_TREE", PRE377_TREE):
            benchmark_inventory = contract.script_inventory()
        with patch.object(contract, "B_ADMISSION_BASELINE", LEGACY_MAIN), \
                patch.object(contract, "B_ADMISSION_TREE", LEGACY_TREE):
            old_inventory = contract.script_inventory()
        # Keep the accepted #374 transition independently checked at its own
        # source; later #377/#390 additions do not rewrite that historical delta.
        self.assertEqual(set(benchmark_inventory) - set(old_inventory), {BENCHMARK})
        self.assertEqual({name: benchmark_inventory[name] for name in old_inventory}, old_inventory)
        self.assertNotIn("tools/lcb/pressure_idle_cost.py", inventory)
        report = self.check()
        self.assertEqual(report["status"], "PASS")
        self.assertEqual(report["admission_source_commit"], ACCEPTED_MAIN)
        self.assertEqual(report["admission_source_tree"], ACCEPTED_TREE)
        self.assertEqual(report["legacy_display_oracle_commit"], LEGACY_MAIN)
        self.assertEqual(report["legacy_display_oracle_tree"], LEGACY_TREE)
        self.assertEqual(report["executable_source_count"], len(inventory) + 1)

    def test_old_inventory_refuses_the_accepted_374_addition(self):
        # Reproduce the original intake blocker using the historical inventory,
        # while retaining the actual newly accepted benchmark in the candidate.
        with patch.object(contract, "B_ADMISSION_BASELINE", LEGACY_MAIN), \
                patch.object(contract, "B_ADMISSION_TREE", LEGACY_TREE):
            with self.assertRaises(ValueError) as refusal:
                self.check()
        self.assertIn("unapproved executable source inventory", str(refusal.exception))
        self.assertIn("missing=[]", str(refusal.exception))
        self.assertIn("extra=" + repr(sorted((BENCHMARK, PROBE, *REGION_TESTS))), str(refusal.exception))

    def test_377_probe_and_fixture_are_authenticated_as_accepted_source(self):
        inventory = contract.script_inventory()
        with patch.object(contract, "B_ADMISSION_BASELINE", PRE390_MAIN), \
                patch.object(contract, "B_ADMISSION_TREE", PRE390_TREE):
            probe_inventory = contract.script_inventory()
        with patch.object(contract, "B_ADMISSION_BASELINE", PRE377_MAIN), \
                patch.object(contract, "B_ADMISSION_TREE", PRE377_TREE):
            previous = contract.script_inventory()
        self.assertEqual(set(probe_inventory) - set(previous), {PROBE})
        self.assertEqual({name: probe_inventory[name] for name in previous}, previous)
        self.assertEqual(inventory[PROBE], PROBE_BLOB)
        for relative, digest in ((PROBE, PROBE_SHA256), (PROBE_FIXTURE, PROBE_FIXTURE_SHA256)):
            accepted = subprocess.run(
                ["git", "-C", str(contract.ROOT), "show", ACCEPTED_MAIN + ":" + relative],
                check=True, capture_output=True, timeout=30).stdout
            self.assertEqual(hashlib.sha256(accepted).hexdigest(), digest)
            self.assertEqual((contract.ROOT / relative).read_bytes(), accepted)
        self.assertEqual((self.root / PROBE).read_bytes(), (contract.ROOT / PROBE).read_bytes())
        # JSON is separately authenticated data, not an executable-suffix exemption.
        self.assertNotIn(".json", contract.EXECUTABLE_SUFFIXES)
        self.assertNotIn(PROBE_FIXTURE, inventory)
        report = self.check()
        self.assertEqual(report["admission_source_commit"], ACCEPTED_MAIN)
        self.assertEqual(report["executable_source_count"], len(inventory) + 1)

    def test_pre377_admission_refuses_the_accepted_probe(self):
        with patch.object(contract, "B_ADMISSION_BASELINE", PRE377_MAIN), \
                patch.object(contract, "B_ADMISSION_TREE", PRE377_TREE):
            with self.assertRaises(ValueError) as refusal:
                self.check()
        self.assertIn("unapproved executable source inventory", str(refusal.exception))
        self.assertIn("missing=[]", str(refusal.exception))
        self.assertIn("extra=" + repr(sorted((PROBE, *REGION_TESTS))), str(refusal.exception))

    def test_390_worker_and_tests_are_authenticated_as_accepted_source(self):
        inventory = contract.script_inventory()
        with patch.object(contract, "B_ADMISSION_BASELINE", PRE390_MAIN), \
                patch.object(contract, "B_ADMISSION_TREE", PRE390_TREE):
            previous = contract.script_inventory()
        self.assertEqual(set(inventory) - set(previous), set(REGION_TESTS))
        self.assertEqual(set(previous) - set(inventory), set())
        self.assertEqual({name for name in previous if inventory[name] != previous[name]}, {WORKER})
        for relative, (blob, digest) in REGION_SOURCE_IDENTITIES.items():
            with self.subTest(path=relative):
                accepted = subprocess.run(
                    ["git", "-C", str(contract.ROOT), "show", ACCEPTED_MAIN + ":" + relative],
                    check=True, capture_output=True, timeout=30).stdout
                self.assertEqual(hashlib.sha256(accepted).hexdigest(), digest)
                self.assertEqual(inventory[relative], blob)
                self.assertEqual((self.root / relative).read_bytes(), accepted)
        # The new tests are ordinary authenticated executables. Neither their
        # directory nor their suffix is an exclusion or a count-only allowance.
        self.assertEqual(contract.EXECUTABLE_ROOTS, ("godot", "native"))
        self.assertEqual(contract.EXECUTABLE_SUFFIXES,
                         {".gd", ".tscn", ".tres", ".godot", ".gdshader", ".gdextension", ".cfg",
                          ".h", ".hh", ".hpp", ".hxx", ".c", ".cc", ".cpp", ".cxx", ".inc"})
        report = self.check()
        self.assertEqual(report["admission_source_commit"], ACCEPTED_MAIN)
        self.assertEqual(report["admission_source_tree"], ACCEPTED_TREE)
        self.assertEqual(report["executable_source_count"], len(inventory) + 1)

    def test_pre390_admission_refuses_both_accepted_gd_tests(self):
        with patch.object(contract, "B_ADMISSION_BASELINE", PRE390_MAIN), \
                patch.object(contract, "B_ADMISSION_TREE", PRE390_TREE):
            with self.assertRaises(ValueError) as refusal:
                self.check()
        self.assertIn("unapproved executable source inventory", str(refusal.exception))
        self.assertIn("missing=[]", str(refusal.exception))
        self.assertIn("extra=" + repr(sorted(REGION_TESTS)), str(refusal.exception))

    def test_390_test_tamper_removal_rename_and_copy_fail_closed(self):
        for relative in REGION_TESTS:
            path = self.root / relative
            original = path.read_bytes()
            alternate = path.with_name("unadmitted_" + path.name)
            for mutation in ("tamper", "remove", "rename", "copy"):
                with self.subTest(path=relative, mutation=mutation):
                    try:
                        if mutation == "tamper":
                            path.write_bytes(original + b"\n# unapproved test change\n")
                        elif mutation == "remove":
                            path.unlink()
                        elif mutation == "rename":
                            path.rename(alternate)
                        else:
                            alternate.write_bytes(original)
                        with self.assertRaises(ValueError) as refusal:
                            self.check()
                        if mutation == "tamper":
                            self.assertIn(relative + ": executable source drift", str(refusal.exception))
                        else:
                            missing = [relative] if mutation in ("remove", "rename") else []
                            extra = [alternate.relative_to(self.root).as_posix()] if mutation in ("rename", "copy") else []
                            self.assertIn("unapproved executable source inventory", str(refusal.exception))
                            self.assertIn("missing=" + repr(missing), str(refusal.exception))
                            self.assertIn("extra=" + repr(extra), str(refusal.exception))
                    finally:
                        alternate.unlink(missing_ok=True)
                        path.write_bytes(original)

    def test_390_worker_tamper_and_rollback_are_refused(self):
        path = self.root / WORKER
        original = path.read_bytes()
        old_worker = subprocess.run(
            ["git", "-C", str(contract.ROOT), "show", PRE390_MAIN + ":" + WORKER],
            check=True, capture_output=True, timeout=30).stdout
        self.assertNotEqual(original, old_worker)
        for payload in (original + b"\n# unapproved worker change\n", old_worker):
            with self.subTest(rollback=payload == old_worker):
                try:
                    path.write_bytes(payload)
                    with self.assertRaisesRegex(ValueError, WORKER + ": executable source drift"):
                        self.check()
                finally:
                    path.write_bytes(original)

    def test_pre390_admission_still_refuses_worker_when_new_tests_are_hidden(self):
        # Isolate the changed worker from the first inventory-set failure. An
        # attempt to hide the two new tests cannot make a stale worker baseline
        # authenticate the accepted #390 production source.
        for relative in REGION_TESTS:
            (self.root / relative).unlink()
        with patch.object(contract, "B_ADMISSION_BASELINE", PRE390_MAIN), \
                patch.object(contract, "B_ADMISSION_TREE", PRE390_TREE):
            with self.assertRaisesRegex(ValueError, WORKER + ": executable source drift"):
                self.check()

    def test_wrong_b_admission_commit_is_refused(self):
        with patch.object(contract, "B_ADMISSION_BASELINE", PRE390_MAIN):
            with self.assertRaisesRegex(ValueError, "B admission tree differs"):
                self.check()

    def test_accepted_probe_tamper_removal_rename_and_copy_fail_closed(self):
        path = self.root / PROBE
        original = path.read_bytes()
        alternate = self.root / "native/tests/unadmitted_liveness_probe.cpp"
        for mutation in ("tamper", "remove", "rename", "copy"):
            with self.subTest(mutation=mutation):
                try:
                    if mutation == "tamper":
                        path.write_bytes(original + b"\n// unapproved probe change\n")
                    elif mutation == "remove":
                        path.unlink()
                    elif mutation == "rename":
                        path.rename(alternate)
                    else:
                        alternate.write_bytes(original)
                    with self.assertRaises(ValueError) as refusal:
                        self.check()
                    if mutation == "tamper":
                        self.assertIn(PROBE + ": executable source drift", str(refusal.exception))
                    else:
                        missing = [PROBE] if mutation in ("remove", "rename") else []
                        extra = [alternate.relative_to(self.root).as_posix()] if mutation in ("rename", "copy") else []
                        self.assertIn("missing=" + repr(missing), str(refusal.exception))
                        self.assertIn("extra=" + repr(extra), str(refusal.exception))
                finally:
                    alternate.unlink(missing_ok=True)
                    path.write_bytes(original)

    def test_accepted_benchmark_bytes_cannot_change(self):
        path = self.root / BENCHMARK
        path.write_bytes(path.read_bytes() + b"\n// unapproved benchmark change\n")
        with self.assertRaisesRegex(ValueError, "lcb201_pressure_idle_cost.cpp: executable source drift"):
            self.check()

    def test_accepted_benchmark_cannot_be_removed(self):
        (self.root / BENCHMARK).unlink()
        with self.assertRaises(ValueError) as refusal:
            self.check()
        self.assertIn("missing=['" + BENCHMARK + "']", str(refusal.exception))
        self.assertIn("extra=[]", str(refusal.exception))

    def test_accepted_benchmark_cannot_be_renamed(self):
        renamed = "native/bench/renamed_idle_cost.cpp"
        (self.root / BENCHMARK).rename(self.root / renamed)
        with self.assertRaises(ValueError) as refusal:
            self.check()
        self.assertIn("missing=['" + BENCHMARK + "']", str(refusal.exception))
        self.assertIn("extra=['" + renamed + "']", str(refusal.exception))

    def test_accepted_benchmark_cannot_admit_an_additional_copy(self):
        copied = "native/bench/copied_idle_cost.cpp"
        (self.root / copied).write_bytes((self.root / BENCHMARK).read_bytes())
        with self.assertRaises(ValueError) as refusal:
            self.check()
        self.assertIn("missing=[]", str(refusal.exception))
        self.assertIn("extra=['" + copied + "']", str(refusal.exception))

    def test_374_admission_does_not_exempt_arbitrary_executable_suffixes(self):
        native_suffixes = {".h", ".hh", ".hpp", ".hxx", ".c", ".cc", ".cpp", ".cxx", ".inc"}
        # Keep the expected scope independent of the implementation's suffix
        # set, so deleting a checked suffix cannot delete its negative control.
        executable_suffixes = (".gd", ".tscn", ".tres", ".godot", ".gdshader", ".gdextension", ".cfg",
                               ".h", ".hh", ".hpp", ".hxx", ".c", ".cc", ".cpp", ".cxx", ".inc")
        for suffix in executable_suffixes:
            with self.subTest(suffix=suffix):
                directory = "native/bench" if suffix in native_suffixes else "godot"
                relative = directory + "/unadmitted_source" + suffix
                path = self.root / relative
                path.write_bytes(b"unadmitted executable source\n")
                try:
                    with self.assertRaises(ValueError) as refusal:
                        self.check()
                    self.assertIn("unapproved executable source inventory", str(refusal.exception))
                    self.assertIn("extra=['" + relative + "']", str(refusal.exception))
                finally:
                    path.unlink()

    def test_wrong_b_admission_tree_is_refused(self):
        with patch.object(contract, "B_ADMISSION_TREE", LEGACY_TREE):
            with self.assertRaisesRegex(ValueError, "B admission tree differs"):
                self.check()

    def test_new_baseline_cannot_silently_admit_changed_main_or_identity(self):
        inventory = contract.script_inventory()
        for name in (contract.MAIN, contract.IDENTITY):
            with self.subTest(name=name):
                # Model a future accepted inventory containing changed Main or
                # routing source. Advancing its baseline cannot extend this
                # consumer's narrowly approved old-to-new transformation.
                changed_inventory = {**inventory, name: "0" * 40}
                with patch.object(contract, "script_inventory", return_value=changed_inventory):
                    with self.assertRaisesRegex(ValueError, "B admission baseline differs from frozen legacy display source"):
                        self.check()

    def test_b_admission_keeps_frozen_27_owner_authentication(self):
        self.assertEqual(compatibility.BASELINE, FROZEN_AUTHORITY)
        self.assertEqual(legacy.BASELINE, LEGACY_MAIN)
        self.assertEqual(contract.B_ADMISSION_BASELINE, ACCEPTED_MAIN)
        self.assertEqual(len({compatibility.BASELINE, legacy.BASELINE, contract.B_ADMISSION_BASELINE}), 3)
        frozen_sources = compatibility.retained_sources(contract.ROOT)
        self.assertEqual(len(frozen_sources), 27)
        for relative, frozen in frozen_sources.items():
            actual = (contract.ROOT / relative).read_bytes()
            self.assertEqual(actual, frozen, relative)
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(actual)
        lock = self.root / compatibility.LOCK
        lock.parent.mkdir(parents=True, exist_ok=True)
        lock.write_bytes((contract.ROOT / compatibility.LOCK).read_bytes())
        before = (lock.read_bytes(), lock.stat().st_mtime_ns)
        self.assertEqual(hashlib.sha256(before[0]).hexdigest(), LOCK_SHA256)
        self.assertEqual(compatibility.read_lock(lock), compatibility.build_lock(frozen_sources))
        report = compatibility.check(self.root, baseline_repository=contract.ROOT)
        self.assertEqual(report["baseline"], FROZEN_AUTHORITY)
        self.assertEqual(report["protected_sources"], 27)
        self.assertEqual(report["display_consumer_source_guard"]["admission_source_commit"], ACCEPTED_MAIN)
        self.assertEqual(before, (lock.read_bytes(), lock.stat().st_mtime_ns))
        wrong = json.loads(before[0])
        wrong["source_commit"] = ACCEPTED_MAIN
        lock.write_text(json.dumps(wrong) + "\n", encoding="utf-8")
        with self.assertRaisesRegex(compatibility.CompatibilityError, "source_commit: expected retained"):
            compatibility.check(self.root, baseline_repository=contract.ROOT)

    def test_legacy_oracle_stays_frozen_and_ignores_accepted_apparatus_and_candidate_inputs(self):
        self.assertEqual((legacy.BASELINE, legacy.BASELINE_TREE), (LEGACY_MAIN, LEGACY_TREE))
        fixture = self.root / legacy.FIXTURE
        before = (fixture.read_bytes(), fixture.stat().st_mtime_ns)
        self.assertEqual(hashlib.sha256(before[0]).hexdigest(), ORACLE_SHA256)
        # These intentionally invalid inputs must be irrelevant to the old
        # display oracle. Only the separate B/presentation guards consume them.
        for relative in (BENCHMARK, PROBE, WORKER, *REGION_TESTS,
                         presentation.PRESENTATION, contract.RESOURCE):
            (self.root / relative).write_bytes(b"not a legacy oracle input\n")
        with patch.object(legacy, "git_bytes", wraps=legacy.git_bytes) as historical_reads:
            report = legacy.check(self.root, contract.ROOT)
        self.assertEqual([call.args[1] for call in historical_reads.call_args_list],
                         [legacy.MAIN, legacy.CELL])
        self.assertEqual(report["source_commit"], LEGACY_MAIN)
        self.assertEqual(report["fixture_sha256"], ORACLE_SHA256)
        self.assertEqual(report["cases"], 277)
        self.assertEqual(before, (fixture.read_bytes(), fixture.stat().st_mtime_ns))

    def test_historical_display_authority_cannot_follow_current_b_baseline(self):
        # Even when accepted Main/CellWorld still have their historical bytes,
        # moving their oracle identity would rewrite the frozen source authority.
        with patch.object(legacy, "BASELINE", ACCEPTED_MAIN), \
                patch.object(legacy, "BASELINE_TREE", ACCEPTED_TREE):
            with self.assertRaisesRegex(ValueError, "frozen legacy-name fixture"):
                self.check()
        path = self.root / legacy.FIXTURE
        original = json.loads(path.read_bytes())
        original.update({"source_commit": ACCEPTED_MAIN, "source_tree": ACCEPTED_TREE})
        path.write_text(json.dumps(original, sort_keys=True, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "frozen legacy-name fixture"):
            self.check()

    def test_missing_stale_and_poisoned_generated_resource_fail_closed(self):
        path = self.root / contract.RESOURCE
        original = path.read_bytes()
        for payload in (None, original + b"\n", original.replace(b'"sand"', b'"poisoned sand"', 1)):
            with self.subTest(payload=payload is None):
                path.unlink()
                if payload is not None:
                    path.write_bytes(payload)
                with self.assertRaisesRegex(ValueError, "missing|stale"):
                    self.check()
                path.write_bytes(original)

    def test_frozen_oracle_cannot_be_rewritten_with_candidate(self):
        path = self.root / legacy.FIXTURE
        path.write_bytes(path.read_bytes().replace(b'"sand"', b'"poisoned sand"', 1))
        with self.assertRaisesRegex(ValueError, "frozen legacy-name fixture"):
            self.check()

    def test_decorative_unused_preload_and_runtime_fallback_are_refused(self):
        path = self.root / contract.MAIN
        old = legacy.git_bytes(contract.ROOT, contract.MAIN).decode("utf-8")
        path.write_text(old.replace("extends Control\n", "extends Control\n\n" + contract.PRELOAD, 1))
        with self.assertRaisesRegex(ValueError, "declared.*consumer"):
            self.check()

    def test_second_direct_alias_and_indirect_consumers_are_refused(self):
        payloads = (
            'extends RefCounted\nconst Other = preload("res://scripts/generated/material_ui_names.gd")\n',
            'extends RefCounted\nconst Other = preload("res://scripts/../scripts/generated/material_ui_names.gd")\n',
            'extends RefCounted\nfunc x():\n\treturn load("res://scripts/generated/" + "material_" + "ui_names.gd")\n',
        )
        for payload in payloads:
            with self.subTest(payload=payload):
                path = self.root / "godot/scripts/second_consumer.gd"
                path.write_text(payload)
                with self.assertRaisesRegex(ValueError, "unapproved executable source inventory"):
                    self.check()
                path.unlink()

    def test_existing_script_cannot_hide_indirect_import(self):
        path = self.root / "godot/scripts/web_demo_controller.gd"
        path.write_text(path.read_text() + '\nfunc alias_name():\n\treturn load("res://scripts/generated/" + "material_ui_" + "names.gd")\n')
        with self.assertRaisesRegex(ValueError, "indirect/alias imports"):
            self.check()

    def test_native_indirect_consumer_cannot_bypass_name_scan(self):
        path = self.root / "native/src/second_consumer.cpp"
        path.write_text('auto path = "res://scripts/generated/material_ui_" "names.gd";\n')
        with self.assertRaisesRegex(ValueError, "unapproved executable source inventory"):
            self.check()

    def test_outside_scripts_addon_and_embedded_consumers_are_refused(self):
        for relative, payload in (
            ("godot/second_consumer.gd", 'extends Node\nconst Names = preload("res://scripts/generated/material_ui_names.gd")\n'),
            ("godot/addons/second/reader.gd", 'extends Node\nfunc x(): return load("res://scripts/generated/" + "material_ui_names.gd")\n'),
            ("godot/second_consumer.tres", '[gd_resource type="GDScript" format=3]\n[resource]\nscript/source = "extends Node"\n'),
        ):
            with self.subTest(relative=relative):
                path = self.root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(payload)
                with self.assertRaisesRegex(ValueError, "unapproved executable source inventory"):
                    self.check()
                path.unlink()

    def test_changed_project_routing_and_embedded_scene_source_are_refused(self):
        for relative in ("godot/project.godot", "godot/main.tscn"):
            with self.subTest(relative=relative):
                path = self.root / relative
                original = path.read_bytes()
                path.write_bytes(original + b'\n; changed routing or embedded code\n')
                with self.assertRaisesRegex(ValueError, "drift outside the single B consumer"):
                    self.check()
                path.write_bytes(original)

    def test_generated_file_renaming_is_not_an_import_bypass(self):
        path = self.root / "godot/scripts/innocent_labels.gd"
        path.write_bytes((self.root / contract.RESOURCE).read_bytes())
        with self.assertRaisesRegex(ValueError, "renamed resources"):
            self.check()

    def test_main_alias_or_second_use_is_not_approved(self):
        path = self.root / contract.MAIN
        path.write_text(path.read_text() + '\nconst Another = MaterialUiNames\n')
        with self.assertRaisesRegex(ValueError, "alias/second use"):
            self.check()

    def test_identity_omission_and_unrelated_fingerprint_drift_are_refused(self):
        path = self.root / contract.IDENTITY
        original = path.read_text()
        for changed in (original.replace(contract.IDENTITY_ENTRY, ""), original + "\n# drift\n"):
            with self.subTest(omitted=changed != original):
                path.write_text(changed)
                with self.assertRaisesRegex(ValueError, "stale source fingerprint"):
                    self.check()
        path.write_text(original)

    def test_script_file_alias_is_refused_even_when_bytes_match(self):
        path = self.root / "godot/scripts/web_demo_controller.gd"
        saved = self.root / "web.gd"
        path.rename(saved)
        path.symlink_to(saved)
        with self.assertRaisesRegex(ValueError, "source aliases"):
            self.check()

    def test_current_report_requires_current_route_and_recovers_after_rollback_control(self):
        path = self.root / contract.MAIN
        candidate = path.read_bytes()
        path.write_bytes(legacy.git_bytes(contract.ROOT, contract.MAIN))
        with self.assertRaisesRegex(ValueError, "declared.*consumer"):
            self.check()
        path.write_bytes(candidate)
        self.assertEqual(self.check()["status"], "PASS")


if __name__ == "__main__":
    unittest.main()
