#!/usr/bin/env python3
"""Synthetic authority/custody adversaries, not native outcome evidence."""
from __future__ import annotations
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

import qualify
from bundle_architecture_evidence import bundle
from verify_collaborative_evidence import Custody, FLAGSHIP_EXTENTS, NATIVE_TICK_SOURCE, sha, verify, comparison_canonical_bytes
from verify_windows_launcher import audit_payload, owned, process_inventory, query_self_test

SOURCE = "1" * 40
NATIVE = "2" * 64
PNG = b"\x89PNG\r\n\x1a\nsynthetic-test-only"


def write(root: Path, path: str, value) -> str:
    target = root / path
    target.parent.mkdir(parents=True, exist_ok=True)
    raw = value if isinstance(value, bytes) else (json.dumps(value, sort_keys=True) + "\n").encode()
    target.write_bytes(raw)
    return sha(raw)


def complete(**fields) -> dict:
    return dict(source_revision=SOURCE, checks=1, failures=[], passed=True, model_calls=0, **fields)


def capacity(**fields) -> dict:
    return complete(native_active_core_capacity=1024, development_memory_configuration=False, **fields)


def frames(root: Path, parent: str, count: int, *, ui=False) -> list:
    rows = []
    for index in range(count):
        name = f"synthetic-{index}.png"
        digest = write(root, parent + "/" + name, PNG + str(index).encode())
        rows.append({"path" if ui else "image": name, "sha256" if ui else "image_sha256": digest})
    return rows


def fixture(root: Path) -> None:
    """A tiny synthetic report graph exercises orchestration, never physics."""
    ids = [f"part-{i}" for i in range(40)]
    observations = []
    jobs = [(identity, "source", "identity") for identity in ids]
    jobs += [(identity, "replay", "identity") for identity in ids]
    jobs += [(identity, "replay", transform) for identity in ids[:4]
             for transform in ("mirror_x", "mirror_y", "rotate_90", "rotate_180", "rotate_270")]
    for identity, phase, transform in jobs:
        path = f"observations/{identity}-{phase}-{transform}.json"
        digest = write(root, "catalogue/" + path, {"synthetic": True, "id": identity, "provenance":{"source_revision":SOURCE,"native_binary_sha256":NATIVE}})
        observations.append(dict(id=identity, phase=phase, transform=transform, status="completed",
                                 source_revision=SOURCE, native_binary_sha256=NATIVE, record_path=path, record_sha256=digest))
    write(root, "catalogue/native-catalogue-report.json",
          capacity(modules=[{"id": identity} for identity in ids], observations=observations))
    library_sha = write(root, "catalogue/curated-library-v2.json", {"synthetic": True})
    rendered = frames(root, "catalogue/rendered", 40)
    gallery_sha = write(root, "catalogue/rendered/native-parts-contact-gallery.png", PNG)
    write(root, "catalogue/rendered/catalogue-render-report.json", complete(render_source_revision=SOURCE,
          native_source_revision=SOURCE, same_source=True, validation_only=False, archival_development_requested=False,
          native_modules_checked=40, rendered=rendered, gallery_sha256=gallery_sha))
    provenance = {"source_revision": SOURCE, "native_binary_sha256": NATIVE}
    details = []
    for index in range(24):
        row = {}
        for key in ("before", "after", "recipe", "native_record"):
            path = f"{index}-{key}.json"
            value = {"provenance": provenance, "state": "completed"} if key == "native_record" else {"synthetic": True}
            row[key] = {"path": path, "sha256": write(root, "detail/" + path, value)}
        details.append(row)
    detail_sha = write(root, "detail/cases.json", capacity(cases=details))
    write(root, "detail/analysis.json", capacity(registered_cases=24, retained_rows=24, evaluable_cases=24,
          constraints_preserved_cases=24, exact_projection_cases=24, native_binary_sha256=[NATIVE], manifest_sha256=detail_sha))
    sources, parts, cases = [], [], []
    plane_sha = write(root, "comparison/source.u16le", b"\0\0")
    for index in range(6):
        path = f"source-{index}.json"
        record_sha = write(root, "comparison/" + path, {"provenance": provenance, "state": "completed"})
        sources.append(dict(record_path=path, record_sha256=record_sha, source_plane_path="source.u16le", source_sha256=plane_sha))
    for identity in ids:
        path = identity + ".json"
        record_sha = write(root, "comparison/" + path, {"provenance": provenance, "state": "completed"})
        module = {"id": identity, "synthetic": True}
        module_sha = sha(comparison_canonical_bytes(module)); module["content_sha256"] = module_sha
        write(root, "comparison/modules/" + path, module)
        parts.append(dict(id=identity, record_path=path, record_sha256=record_sha, module_sha256=module_sha))
    for index in range(60):
        program = f"program-{index}.json"
        program_sha = write(root, "comparison/" + program, {"synthetic": True, "index": index})
        attempted = index < 40
        path = f"case-{index}.json" if attempted else ""
        record_sha = write(root, "comparison/" + path, {"provenance": provenance, "state": "completed"}) if attempted else ""
        cases.append(dict(source_plane_path="source.u16le", source_sha256=plane_sha,
                          result_plane_path="source.u16le", result_sha256=plane_sha, program_path=program, program_sha256=program_sha,
                          native_attempted=attempted, raw_native_record_path=path, raw_native_record_sha256=record_sha,
                          status="completed" if attempted else "refused-before-native"))
    comparison_sha = write(root, "comparison/cases.json", complete(development_core_capacity=0, cases=cases,
                                                                 source_observations=sources, module_observations=parts))
    write(root, "comparison/analysis.json", complete(development_core_capacity=0, case_count=60,
          manifest_sha256=comparison_sha, native_completed=40, pre_native_refusals=20))

    examples, attempts, reopened = [], [], []
    for identity, extent in FLAGSHIP_EXTENTS.items():
        plane = identity + ".u16le"
        plane_sha = write(root, "flagships/" + plane, bytes(extent[0] * extent[1] * 2))
        start = identity + "-start.json"
        start_sha = write(root, "flagships/" + start, {"synthetic": True, "id": identity})
        examples.append(dict(id=identity, extent=extent, all_tasks_completed=True, clearance_occupancy_verified=True,
                             stages=3, native_receipt_chunks=3, plane=plane, sha256=plane_sha, start_path=start, start_sha256=start_sha))
        witness_start_sha = write(root, "gameplay/" + start, {"synthetic": True, "id": identity})
        write(root, "gameplay/" + identity + "-actual-workbench.png", PNG)
        attempts.append(dict(id=identity, status="completed", actor_ticks=90, native_ticks=90, contact_samples=12,
                             command_refusals=0, left_corridor=False, worker_failed=False, source_derivation={},
                             ordinary_history={"ok": True}, start_path=start, saved_start_sha256=witness_start_sha))
        reopened.append(dict(id=identity, actor_ticks=90, native_ticks=90, fresh_commands_accepted=True))
    flagship_sha = write(root, "flagships/flagships-native.json", complete(core_capacity=1024, examples=examples))
    write(root, "flagships/flagships-render.json", complete(native_source_revision=SOURCE, display="synthetic-test",
          renders=frames(root, "flagships", 12)))
    actor_sha = write(root, "gameplay/architecture-gameplay.json", capacity(cropped_route_worlds=False, native_tick_source=NATIVE_TICK_SOURCE,
          display="synthetic-test", manifest_sha256=flagship_sha, attempts=attempts))
    write(root, "gameplay/architecture-gameplay-reopen.json", capacity(route_source_revision=SOURCE, native_tick_source=NATIVE_TICK_SOURCE,
          route_report_sha256=actor_sha, attempts=reopened))
    plane_sha = write(root, "ui/connected-native-region.u16le", b"\0\0")
    records = [dict(source_revision=SOURCE, status="completed", result_sha256="result", expected_sha256="result") for _ in range(3)]
    write(root, "ui/collaborative-ui.json", capacity(catalogue_sha256=library_sha, display="synthetic-test",
          captures=frames(root, "ui", 7, ui=True), native_sha256=plane_sha, native_records=records))
    plane_sha = write(root, "hierarchy/workshop.u16le", b"\0\0")
    start_sha = write(root, "hierarchy/workshop-start.json", {"synthetic": True})
    result = dict(delegated_workers=[{}] * 3, final_campaign_state="completed", prior_campaigns=1,
                  partial_checked_cells=4096, preserved_outside_recovery_except_declared_attachments=True,
                  approved_outside_recovery_cells=256, protected_passage_empty=True,
                  plane="workshop.u16le", plane_sha256=plane_sha, start="workshop-start.json", start_sha256=start_sha)
    hierarchy_sha = write(root, "hierarchy/hierarchy-native.json", complete(core_capacity=1024, result=result))
    write(root, "hierarchy/independent-hierarchy-verification.json", dict(source_revision=SOURCE, status="PASS", errors=[],
          manifest_sha256=hierarchy_sha, final_plane_sha256=plane_sha, runtime={"native_active_core_capacity": 1024},
          counts={"native_stages":10,"workers":3}, recovery={"attachment_cells":1024,"solid_contact_requirements":128,
          "approved_outside_recovery_cells":256,"all_other_outside_cells_preserved":True},
          files=[{"path":"workshop.u16le","sha256":plane_sha,"bytes":2}]))
    write(root, "hierarchy/hierarchy-reopen.json", complete(core_capacity=1024,
          result={"fresh_process": True, "plane_sha256": plane_sha}))
    write(root, "hierarchy/hierarchy-render.json", complete(native_source_revision=SOURCE, display="synthetic-test",
          renders=frames(root, "hierarchy", 3)))


class FakeRunner:
    def __init__(self, path: Path):
        self.evidence, self.calls = path, []
        self.args = SimpleNamespace(godot=Path("unused-engine"))
    def godot(self, project, label, script=None, marker=None, **options):
        self.calls.append(dict(kind="godot", label=label, script=script, marker=marker, options=options))
    def execute(self, label, command, **options):
        self.calls.append(dict(kind="execute", label=label, command=command, options=options))
        return ""


class OrchestrationTests(unittest.TestCase):
    def test_development_overrides_are_refused_even_zero(self):
        qualify.validate_collaborative_environment({})
        for name in qualify.COLLABORATIVE_FORBIDDEN_ENV:
            for value in ("1", "0", "128"):
                with self.subTest(name=name, value=value), self.assertRaises(ValueError):
                    qualify.validate_collaborative_environment({name: value})

    def test_all_cases_required_with_fresh_process_paths(self):
        with tempfile.TemporaryDirectory() as temporary:
            runner = FakeRunner(Path(temporary))
            result = qualify.collaborative_cases(runner, qualify.ROOT / "godot", SOURCE, NATIVE)
            self.assertEqual(result, Path(temporary) / "architecture/collaborative/custody.json")
            self.assertEqual(len(runner.calls), 42)
            self.assertEqual(len({row["label"] for row in runner.calls}), 42)
            by_label = {row["label"]: row for row in runner.calls}
            for row in runner.calls:
                if row["kind"] == "godot":
                    script = qualify.ROOT / "godot/tests" / (row["script"] + ".gd")
                    self.assertTrue(script.is_file(), str(script))
                    self.assertIn(row["marker"], script.read_text(encoding="utf-8"))
                    self.assertFalse(set(row["options"].get("env", {})) & set(qualify.COLLABORATIVE_FORBIDDEN_ENV))
            native = by_label["collaborative-full-world-gameplay"]
            reopen = by_label["collaborative-gameplay-fresh-reopen"]
            self.assertNotEqual(native["script"], reopen["script"])
            self.assertEqual(native["options"]["env"], reopen["options"]["env"])
            self.assertTrue(native["options"]["graphical"] and reopen["options"]["graphical"])
            self.assertIn("flagships-native.json", native["options"]["env"]["ARCHITECTURE_GAMEPLAY_MANIFEST"])
            for name in ("catalogue-render", "flagships-render", "native-ui", "hierarchy-render"):
                self.assertTrue(by_label["collaborative-" + name]["options"]["graphical"])

    def test_no_directory_escape_and_no_stale_digest(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            gate = Custody(root, SOURCE, NATIVE)
            write(root, "plane.u16le", b"\0\0")
            with self.assertRaises(ValueError):
                gate.file("../outside.json")
            with self.assertRaises(ValueError):
                gate.file("plane.u16le", "0" * 64)

    def test_bundle_requires_collaborative_success_before_copy(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); evidence = root / "evidence"; package = root / "package"
            write(evidence, "qualification.json", {"status": "passed", "architecture_m3_m5": True,
                  "development_dirty_allowed": False, "actual_model_calls": 0, "platform": "win32", "graphical": True,
                  "source_commit": SOURCE, "results": [{"status": "passed"}],
                  "source_files_sha256": {"addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll": NATIVE}})
            write(package, "candidate-manifest.json", {"source_commit": SOURCE, "native_sha256": NATIVE, "files_sha256": {}})
            with self.assertRaisesRegex(ValueError, "completed M6/M7"):
                bundle(evidence, package, True)
            self.assertFalse((package / "architecture-evidence").exists())


class LauncherTests(unittest.TestCase):
    def query_fixture(self):
        executable = str(Path(sys.executable).resolve()).lower()
        paths = [executable, executable + ".nonexistent-query-control"]
        row = {"ProcessId":os.getpid(), "ParentProcessId":123, "ExecutablePath":executable,
               "CreationDate":"2026-11-25T00:00:00.0000000Z", "MainWindowHandle":0}
        return {"powershell_version":"5.1.20348.2227", "paths":paths, "processes":[row]}

    def test_two_scalar_query_paths_and_exact_self_identity(self):
        value = self.query_fixture()
        with patch("verify_windows_launcher.powershell", return_value=json.dumps(value)):
            result = query_self_test({})
        self.assertTrue(result["passed"])
        self.assertEqual(result["observed_self"]["ProcessId"], os.getpid())
        self.assertEqual(len(result["paths"]), 2)

    def test_nested_powershell_path_array_is_not_accepted(self):
        value = self.query_fixture()
        env = {"CYBERSAND_LAUNCHER_PATHS":json.dumps(value["paths"])}
        value["paths"] = [value["paths"]]
        with patch("verify_windows_launcher.powershell", return_value=json.dumps(value)):
            with self.assertRaisesRegex(ValueError, "two scalar path filters"):
                process_inventory(env)

    def test_empty_query_cannot_masquerade_as_a_pristine_process_inventory(self):
        value = self.query_fixture(); value["processes"] = []
        with patch("verify_windows_launcher.powershell", return_value=json.dumps(value)):
            with self.assertRaisesRegex(RuntimeError, "exact caller"):
                query_self_test({})

    def test_query_self_identity_requires_pid_image_and_creation(self):
        for field, changed in (("ProcessId",os.getpid()+1),("ExecutablePath","different.exe"),("CreationDate","")):
            value = self.query_fixture(); value["processes"][0][field] = changed
            with self.subTest(field=field), patch("verify_windows_launcher.powershell", return_value=json.dumps(value)):
                with self.assertRaisesRegex(RuntimeError, "exact caller"):
                    query_self_test({})

    def test_pristine_and_generated_import_boundary(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            code = write(root, "godot/main.gd", b"source")
            imported = write(root, "godot/icon.svg.import", b"generated-old")
            manifest = {"files_sha256":{"godot/main.gd":code,"godot/icon.svg.import":imported}}
            self.assertEqual(audit_payload(root, manifest), [])
            write(root, "godot/icon.svg.import", b"generated-new")
            with self.assertRaises(ValueError): audit_payload(root, manifest)
            self.assertEqual(len(audit_payload(root, manifest, after_import=True)), 1)
            write(root, "godot/main.gd", b"changed-code")
            with self.assertRaises(ValueError): audit_payload(root, manifest, after_import=True)

    def test_unlisted_source_or_override_cannot_enter_launch(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            code = write(root, "godot/main.gd", b"source")
            manifest = {"files_sha256":{"godot/main.gd":code}}
            write(root, "godot/override.cfg", b"additional-config")
            for after_import in (False, True):
                with self.assertRaisesRegex(ValueError, "Unlisted packaged file"):
                    audit_payload(root, manifest, after_import=after_import)
            (root / "godot/override.cfg").unlink()
            write(root, "godot/main.gd.uid", b"uid://generated")
            write(root, "godot/.godot/imported/cache.ctex", b"generated-cache")
            with self.assertRaises(ValueError): audit_payload(root, manifest)
            self.assertEqual(len(audit_payload(root, manifest, after_import=True)), 2)
            write(root, "godot/unknown.gd.uid", b"uid://unknown")
            with self.assertRaises(ValueError): audit_payload(root, manifest, after_import=True)

    def test_exact_launcher_parent_and_image_required(self):
        paths = {"c:/package/godot.exe"}
        self.assertTrue(owned({"ParentProcessId":12,"ExecutablePath":"C:/package/Godot.exe"},12,paths))
        self.assertFalse(owned({"ParentProcessId":13,"ExecutablePath":"C:/package/Godot.exe"},12,paths))
        self.assertFalse(owned({"ParentProcessId":12,"ExecutablePath":"C:/elsewhere/Godot.exe"},12,paths))


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        fixture(self.root)

    def tearDown(self):
        self.temporary.cleanup()

    def mutate(self, path: str, action):
        value = json.loads((self.root / path).read_bytes())
        action(value)
        write(self.root, path, value)

    def test_complete_synthetic_custody_graph(self):
        result = verify(self.root, SOURCE, NATIVE)
        self.assertTrue(result["passed"])
        self.assertEqual(result["counts"]["comparison_pre_native_refusals"], 20)
        self.assertEqual(result["counts"]["full_world_actor_trials"], 4)
        self.assertEqual(result["physical_owner_acceptance"], "pending")

    def test_raw_comparison_record_changed_after_reduction(self):
        write(self.root, "comparison/case-0.json", {"changed": True})
        with self.assertRaisesRegex(ValueError, "digest mismatch"): verify(self.root, SOURCE, NATIVE)

    def test_same_source_another_dll_cannot_qualify(self):
        path = "comparison/cases.json"
        value = json.loads((self.root / path).read_bytes())
        row = value["cases"][0]
        row["raw_native_record_sha256"] = write(self.root, "comparison/" + row["raw_native_record_path"],
                {"state":"completed","provenance":{"source_revision":SOURCE,"native_binary_sha256":"9"*64}})
        manifest_sha = write(self.root, path, value)
        self.mutate("comparison/analysis.json", lambda item: item.update(manifest_sha256=manifest_sha))
        with self.assertRaisesRegex(ValueError, "runtime differs"): verify(self.root, SOURCE, NATIVE)

    def test_detail_reduction_requires_exact_manifest(self):
        self.mutate("detail/cases.json", lambda row: row.update(changed=True))
        with self.assertRaisesRegex(ValueError, "exact manifest"): verify(self.root, SOURCE, NATIVE)

    def test_negative_outcome_counts_are_not_a_denominator(self):
        self.mutate("comparison/analysis.json", lambda row: row.update(native_completed=-1, pre_native_refusals=61))
        with self.assertRaisesRegex(ValueError, "nonnegative integers"): verify(self.root, SOURCE, NATIVE)

    def test_reduced_capacity_does_not_qualify(self):
        self.mutate("catalogue/native-catalogue-report.json", lambda row: row.update(native_active_core_capacity=128))
        with self.assertRaisesRegex(ValueError, "1024"): verify(self.root, SOURCE, NATIVE)

    def test_duplicate_native_observations_do_not_fill_denominator(self):
        self.mutate("catalogue/native-catalogue-report.json", lambda row: row["observations"].__setitem__(99, row["observations"][0]))
        with self.assertRaisesRegex(ValueError, "cohorts"): verify(self.root, SOURCE, NATIVE)

    def test_archival_render_cannot_qualify_current_source(self):
        self.mutate("catalogue/rendered/catalogue-render-report.json", lambda row: row.update(archival_development_requested=True))
        with self.assertRaisesRegex(ValueError, "exact source"): verify(self.root, SOURCE, NATIVE)

    def test_actual_png_hash_is_required(self):
        write(self.root, "catalogue/rendered/synthetic-0.png", PNG + b"changed")
        with self.assertRaisesRegex(ValueError, "digest mismatch"): verify(self.root, SOURCE, NATIVE)

    def test_render_cached_ticks_do_not_qualify_native_progress(self):
        self.mutate("gameplay/architecture-gameplay.json", lambda row: row.update(native_tick_source="host.latest_snapshot.tick_index"))
        with self.assertRaisesRegex(ValueError, "worker publication"): verify(self.root, SOURCE, NATIVE)

    def test_reopened_render_cached_ticks_do_not_qualify_native_progress(self):
        self.mutate("gameplay/architecture-gameplay-reopen.json", lambda row: row.update(native_tick_source="host.latest_snapshot.tick_index"))
        with self.assertRaisesRegex(ValueError, "worker publication"): verify(self.root, SOURCE, NATIVE)

    def test_cropped_route_cannot_qualify_full_world(self):
        self.mutate("gameplay/architecture-gameplay.json", lambda row: row.update(cropped_route_worlds=True))
        with self.assertRaisesRegex(ValueError, "complete actual"): verify(self.root, SOURCE, NATIVE)

    def test_missing_flagship_is_retained_as_failure(self):
        self.mutate("flagships/flagships-native.json", lambda row: row["examples"].pop())
        with self.assertRaisesRegex(ValueError, "Four distinct"): verify(self.root, SOURCE, NATIVE)

    def test_wrong_source_reopen_refuses(self):
        self.mutate("gameplay/architecture-gameplay-reopen.json", lambda row: row.update(route_source_revision="3" * 40))
        with self.assertRaisesRegex(ValueError, "exact process"): verify(self.root, SOURCE, NATIVE)

    def test_no_partial_native_evidence_cannot_claim_recovery(self):
        self.mutate("hierarchy/hierarchy-native.json", lambda row: row["result"].update(partial_checked_cells=0))
        with self.assertRaisesRegex(ValueError, "partial Stop"): verify(self.root, SOURCE, NATIVE)


if __name__ == "__main__":
    unittest.main()
