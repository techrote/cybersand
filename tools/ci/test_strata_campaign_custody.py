#!/usr/bin/env python3
"""Independent adverse controls for admission of retained Strata campaigns.

These are synthetic receipt fixtures, never execution or qualification evidence.
Each mutation updates dependent checksums unless the checksum itself is under
test. This makes the verifier reject the contradictory claim, not merely a stale
copy of otherwise valid bytes. No Godot or native process is launched.
"""
from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import qualify_strata_workbench as gate


def digest(value: str | bytes) -> str:
    return hashlib.sha256(value.encode() if isinstance(value, str) else value).hexdigest()


def write(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def runtime_fixture(platform: str) -> dict:
    linux = platform == "linux"
    native = "godot/addons/cybersand_native/bin/" + (
        "libcybersand_native.linux.x86_64.so" if linux else "cybersand_native.windows.x86_64.dll")
    rapier = "godot/addons/godot-rapier2d/bin/" + (
        "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so" if linux else
        "libgodot_rapier.windows.x86_64-pc-windows-msvc.dll")
    manifest = "godot/addons/cybersand_native/runtime-provenance" + (".linux" if linux else "") + ".json"
    return {
        "runtime_source_commit": "c" * 40, "runtime_build_commit": "d" * 40,
        "runtime_provenance": {"path": manifest, "sha256": digest(manifest)},
        "native_source_inputs": {"native/src/receipt_fixture.cpp": digest("native fixture")},
        "cybersand_runtime": {"path": native, "sha256": digest(native), "size": 4096},
        "rapier_runtime": {"path": rapier, "sha256": digest(rapier), "size": 8192},
    }


class CampaignFixture:
    def __init__(self, folder: Path, platform: str = "linux") -> None:
        self.folder = folder
        self.platform = platform
        self.runtime = runtime_fixture(platform)
        names = ["godot/project.godot", "godot/tools/qualify_workbench_strata.gd",
                 "godot/tools/qualify_workbench_strata_maximum.gd",
                 *("godot/tests/" + name + ".gd" for name in gate.REGRESSIONS)]
        inputs = {name: digest(name) for name in names}
        inputs.update(self.runtime["native_source_inputs"])
        inputs[self.runtime["runtime_provenance"]["path"]] = self.runtime["runtime_provenance"]["sha256"]
        self.source = {"source_commit": "a" * 40, "source_tree": "b" * 40,
                       "source_inputs_sha256": inputs}
        project_inputs = {name.removeprefix("godot/"): value for name, value in inputs.items()
                          if name.startswith("godot/")}
        for kind in ("cybersand_runtime", "rapier_runtime"):
            item = self.runtime[kind]
            project_inputs[item["path"].removeprefix("godot/")] = item["sha256"]
        self.report = dict(deepcopy(self.source), schema="strata-workbench-qualification-v1",
                           status="passed", completed=True, input_custody="passed", local_delta=[],
                           platform=platform, runtime=deepcopy(self.runtime),
                           godot={"path": str(folder / "pinned engine" / "Godot"),
                                  "version": gate.custody.windows.GODOT_VERSION,
                                  "sha256": gate.GODOT_SHA256[platform]},
                           project={"path": str(folder / "qualified project"), "inputs_sha256": project_inputs},
                           selected_scenes=list(gate.SCENES), cases=[], scenes=[])
        self.add_case("import", ["--headless", "--editor", "--quit"], "Import completed")
        for name, marker in gate.REGRESSIONS.items():
            self.add_case(name, ["--script", "res://tests/" + name + ".gd"], marker + " fixture")
        maximum_process = self.add_case("maximum", ["--script", gate.MAXIMUM_HARNESS], "STRATA_MAXIMUM fixture")
        owner = self.owner()
        maximum = {
            "schema": "strata-maximum-execution-v1", "completed": True, "failures": [], "checks": 200,
            "source_revision": self.source["source_commit"], "ordinary_workbench": True, "extent": [2048, 2048],
            "display_server": "X11" if platform == "linux" else "Windows", "rendering_method": "gl_compatibility",
            "process_id": maximum_process["pid"] if platform == "linux" else maximum_process["pid"] + 10000,
            "world_count": {"play_borrowed": 1, "decorative_owned": 3},
            "identity": {"before": deepcopy(owner), "after": deepcopy(owner)},
            "play_hash_before": digest("maximum native play"), "play_hash_after": digest("maximum native play"),
            "planes": {name: {"extent": [2048, 2048], "native_material": 131, "pixel_delta": 0.8,
                              "owner": str(-9000000000000000000 + index)}
                       for index, name in enumerate(("scripted", "effects", "background"))},
            "teardown": {"native_world_count": 0, "pending_native_world_count": 0},
        }
        maximum_path = folder / "maximum" / "maximum.json"
        write(maximum_path, maximum)
        self.report["maximum"] = {"report_sha256": gate.sha(maximum_path), "result": maximum,
                                  "process": deepcopy(maximum_process)}
        for scene in gate.SCENES:
            entry = {"name": scene, "status": "passed", "phases": {}}
            self.report["scenes"].append(entry)
            saved = folder / scene / "userdata" / "authored-layout.strata"
            saved.parent.mkdir(parents=True, exist_ok=True)
            saved.write_bytes(b"synthetic authored layout fixture")
            for phase in ("install", "reopen"):
                process = self.add_case(scene + "/" + phase, ["--script", gate.HARNESS],
                                        "STRATA_WORKBENCH " + json.dumps({"scene": scene, "phase": phase,
                                                                       "checks": 720, "failures": []}))
                result = self.result(scene, phase, process["pid"], saved)
                path = folder / scene / (phase + ".json")
                write(path, result)
                entry["phases"][phase] = {"report_sha256": gate.sha(path), "process": deepcopy(process), "result": result}
        self.flush()

    def add_case(self, label: str, flags: list[str], message: str) -> dict:
        base = [self.report["godot"]["path"], "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
                "--rendering-driver", "opengl3", "--path", self.report["project"]["path"]]
        directory = self.folder / label
        directory.mkdir(parents=True, exist_ok=True)
        log = directory / "process.log"
        log.write_text("Godot Engine v" + gate.custody.windows.GODOT_VERSION + "\n" + message + "\n", encoding="utf-8")
        raw = {"command": base + flags, "status": "passed", "exit_code": 0,
               "pid": 1000 + len(self.report["cases"]), "seconds": 1.25,
               "timeout_seconds": 420, "log_sha256": gate.sha(log)}
        self.write_resources(label, raw)
        write(directory / "process.json", raw)
        embedded = dict(raw, label=label)
        self.report["cases"].append(embedded)
        return embedded

    @staticmethod
    def owner() -> dict:
        return {"world_generation": 17, "physical_epoch": 8, "worker_id": "-9223371958320626182",
                "actor_session_id": "221", "actor_body_ids": ["1871", "1872"], "rapier_tick": 0}

    def write_resources(self, label: str, case: dict) -> None:
        pid = case["pid"]
        process = {"pid": pid, "parent_pid": 99, "start_id": 100, "image_name": "fixture-engine",
                   "cpu_seconds": 0.2, "rss_bytes": 1048576, "os_peak_rss_bytes": 1048576}
        rows = [process]
        if self.platform == "win32":
            rows.append(dict(process, pid=pid + 10000, parent_pid=pid, start_id=101))
        samples = [{"elapsed_seconds": elapsed, "processes": deepcopy(rows),
                    "tree_cpu_seconds_observed": sum(row["cpu_seconds"] for row in rows),
                    "tree_rss_bytes": sum(row["rss_bytes"] for row in rows)} for elapsed in (0.0, 0.5)]
        resources = {"schema": "strata-process-resources-v1", "available": True,
                     "scope": "observed_process_and_descendants", "sample_interval_seconds": 0.5,
                     "root_pid": pid, "root_start_id": 100, "process_identities": [[row["pid"], row["start_id"]] for row in rows],
                     "sample_count": 2, "samples": samples, "observed_cpu_seconds": samples[-1]["tree_cpu_seconds_observed"],
                     "peak_observed_tree_rss_bytes": samples[-1]["tree_rss_bytes"], "observer_wall_seconds": 0.001,
                     "observation_errors": [], "semantics": "synthetic fixture; no measured performance claim"}
        path = self.folder / label / "resources.json"
        write(path, resources)
        case["resources_sha256"] = gate.sha(path)
        case["resources"] = {key: value for key, value in resources.items() if key != "samples"}

    def result(self, scene: str, phase: str, pid: int, saved: Path) -> dict:
        owner = self.owner()
        return {
            "schema": "strata-workbench-execution-v1", "completed": True, "failures": [], "checks": 720,
            "scene": scene, "phase": phase, "source_revision": self.source["source_commit"],
            "display_server": "X11" if self.platform == "linux" else "Windows",
            "rendering_method": "gl_compatibility", "rendering_adapter": "synthetic fixture",
            "process_id": pid if self.platform == "linux" else pid + 10000,
            "ordinary_workbench": True,
            "plane_native_hashes": {name: digest(scene + name) for name in ("play", "scripted", "effects", "background")},
            "world_count": {"play_borrowed": 1, "decorative_owned": 3},
            "save": {"sha256": gate.sha(saved), "path": str(saved)},
            "transitions": [{"iteration": index // 4, "mode": ("disabled", "stack", "flat", "stack")[index % 4],
                             "before": deepcopy(owner), "after": deepcopy(owner)} for index in range(12)],
            "edit_readback": {"target_after": 131, "material": 131,
                              "play_hash_before": digest(scene), "play_hash_after": digest(scene)},
            "refusals": {name: True for name in ("locked", "hidden", "outside", "invalid_document", "stale_generation")},
            "undo_redo": {"undo_native": True, "redo_native": True},
            "transforms": {"samples": 216, "max_error": 0.00005},
            "cost_samples": [{"mode": mode, "elapsed_usec": 750000, "callback_intervals_usec": [16667] * 45,
                              "callback_p50_usec": 16667, "callback_p95_usec": 16667, "callback_max_usec": 16667,
                              "godot_process_seconds": [0.001] * 45, "godot_tracked_static_memory_bytes": 1048576,
                              "native_snapshots_during_sample": 0, "decorative_uploads_during_sample": 0}
                             for mode in ("disabled", "flat", "stack")],
            "actual_play": {"before": deepcopy(owner), "after": dict(owner, rapier_tick=10),
                            "position_before": [100, 100], "position_after": [100, 102], "distance": 2.0},
            "backtracking_gesture": {"points": 4, "native_targets_correct": True},
            "fresh_process_reopen": phase == "reopen",
        }

    def scene(self, name: str = gate.SCENES[0]) -> dict:
        return next(entry for entry in self.report["scenes"] if entry["name"] == name)

    def case(self, label: str) -> dict:
        return next(entry for entry in self.report["cases"] if entry["label"] == label)

    def change_case(self, label: str, **values) -> None:
        entry = self.case(label)
        entry.update(values)
        write(self.folder / label / "process.json", {key: value for key, value in entry.items() if key != "label"})
        if "/" in label:
            scene, phase = label.split("/")
            self.scene(scene)["phases"][phase]["process"] = deepcopy(entry)
        elif label == "maximum":
            self.report["maximum"]["process"] = deepcopy(entry)

    def change_log(self, label: str, text: str) -> None:
        path = self.folder / label / "process.log"
        path.write_text(text, encoding="utf-8")
        self.change_case(label, log_sha256=gate.sha(path))

    def change_result(self, phase: str, change, scene: str = gate.SCENES[0]) -> None:
        receipt = self.scene(scene)["phases"][phase]
        change(receipt["result"])
        path = self.folder / scene / (phase + ".json")
        write(path, receipt["result"])
        receipt["report_sha256"] = gate.sha(path)

    def change_maximum(self, change) -> None:
        receipt = self.report["maximum"]
        change(receipt["result"])
        path = self.folder / "maximum" / "maximum.json"
        write(path, receipt["result"])
        receipt["report_sha256"] = gate.sha(path)

    def change_resources(self, label: str, change) -> None:
        path = self.folder / label / "resources.json"
        resources = json.loads(path.read_text())
        change(resources)
        write(path, resources)
        self.change_case(label, resources_sha256=gate.sha(path),
                         resources={key: value for key, value in resources.items() if key != "samples"})

    def flush(self, refresh_ledger: bool = True) -> None:
        if refresh_ledger:
            self.report["evidence_sha256"] = {path.relative_to(self.folder).as_posix(): gate.sha(path)
                for path in self.folder.rglob("*") if path.is_file() and path.name != "qualification.json"
                and "userdata" not in path.parts and "bootstrap-userdata" not in path.parts}
        write(self.folder / "qualification.json", self.report)

    def verify(self) -> None:
        with patch.object(gate, "retained_runtime_manifest", side_effect=runtime_fixture):
            gate.verify_campaign(self.folder, self.source)


class CampaignCustody(unittest.TestCase):
    def test_complete_linux_and_windows_receipts(self):
        for platform in ("linux", "win32"):
            with self.subTest(platform=platform), tempfile.TemporaryDirectory(prefix="strata-custody-") as temporary:
                CampaignFixture(Path(temporary), platform).verify()

    def test_reject_internally_consistent_false_claims(self):
        first = gate.SCENES[0]
        phase = first + "/install"
        controls = {
            "missing_fixture": lambda f: f.report["cases"].remove(f.case("test_workbench_strata_document")),
            "duplicate_fixture": lambda f: f.report["cases"].append(deepcopy(f.case("test_depth_compositor"))),
            "missing_scene": lambda f: f.report["scenes"].pop(),
            "missing_maximum_case": lambda f: f.report["cases"].remove(f.case("maximum")),
            "missing_maximum_receipt": lambda f: f.report.pop("maximum"),
            "wrong_maximum_extent": lambda f: f.change_maximum(lambda r: r.update(extent=[1024, 1024])),
            "missing_maximum_plane": lambda f: f.change_maximum(lambda r: r["planes"].pop("effects")),
            "wrong_maximum_native_material": lambda f: f.change_maximum(lambda r: r["planes"]["effects"].update(native_material=0)),
            "wrong_maximum_pixel": lambda f: f.change_maximum(lambda r: r["planes"]["effects"].update(pixel_delta=0)),
            "nonfinite_maximum_pixel": lambda f: f.change_maximum(lambda r: r["planes"]["effects"].update(pixel_delta=float("inf"))),
            "missing_maximum_engine_pid": lambda f: f.change_maximum(lambda r: r.pop("process_id")),
            "wrong_maximum_engine_pid": lambda f: f.change_maximum(lambda r: r.update(process_id=789000)),
            "numeric_maximum_instance_id": lambda f: f.change_maximum(lambda r: [entry.update(worker_id=991) for entry in r["identity"].values()]),
            "wrong_maximum_actor_id_container": lambda f: f.change_maximum(lambda r: [entry.update(actor_body_ids="123") for entry in r["identity"].values()]),
            "unretired_maximum_plane": lambda f: f.change_maximum(lambda r: r["teardown"].update(native_world_count=1)),
            "unqualified_source": lambda f: f.report.update(source_commit="9" * 40),
            "claimed_linux_from_windows": lambda f: f.change_result("install", lambda r: r.update(display_server="Windows")),
            "unpinned_engine": lambda f: f.report["godot"].update(sha256="9" * 64),
            "missing_engine_receipt": lambda f: f.report.pop("godot"),
            "missing_runtime_receipt": lambda f: f.report.pop("runtime"),
            "uncommitted_runtime": lambda f: f.report["runtime"]["cybersand_runtime"].update(sha256="9" * 64),
            "missing_loaded_source": lambda f: f.report["project"]["inputs_sha256"].pop("tools/qualify_workbench_strata.gd"),
            "failed_fixture": lambda f: f.change_case("test_workbench_strata_layers", status="failed", exit_code=1),
            "skipped_fixture": lambda f: f.change_case("test_workbench_strata_layers", status="skipped"),
            "timed_out_fixture": lambda f: f.change_case("test_depth_compositor", status="timeout", seconds=421),
            "unbounded_process": lambda f: f.change_case(phase, timeout_seconds=0),
            "nonfinite_timeout": lambda f: f.change_case(phase, timeout_seconds=float("inf")),
            "excessive_timeout": lambda f: f.change_case(phase, timeout_seconds=99999),
            "nonfinite_elapsed": lambda f: f.change_case(phase, seconds=float("nan")),
            "error_log_rehashed": lambda f: f.change_log(phase, (f.folder / phase / "process.log").read_text() + "ERROR: injected failure\n"),
            "empty_log_rehashed": lambda f: f.change_log(phase, ""),
            "missing_fixture_marker": lambda f: f.change_log("test_workbench_strata_document", "Godot Engine v" + gate.custody.windows.GODOT_VERSION + "\n"),
            "wrong_script_command": lambda f: f.change_case(phase, command=f.case(phase)["command"][:-1] + ["res://standalone.gd"]),
            "headless_scene_command": lambda f: f.change_case(phase, command=f.case(phase)["command"] + ["--headless"]),
            "wrong_project_command": lambda f: f.change_case(phase, command=["unrelated-project" if value == f.report["project"]["path"] else value for value in f.case(phase)["command"]]),
            "reused_wrapper_process": lambda f: f.change_case(first + "/reopen", pid=f.case(phase)["pid"]),
            "reused_engine_process": lambda f: f.change_result("reopen", lambda r: r.update(process_id=f.scene()["phases"]["install"]["result"]["process_id"])),
            "embedded_result_spoof": lambda f: f.scene()["phases"]["install"]["result"].update(checks=721),
            "embedded_process_spoof": lambda f: f.scene()["phases"]["install"]["process"].update(pid=9000),
            "different_native_reopen": lambda f: f.change_result("reopen", lambda r: r["plane_native_hashes"].update(effects="9" * 64)),
            "different_saved_reopen": lambda f: f.change_result("reopen", lambda r: r["save"].update(sha256="9" * 64)),
            "missing_resource_hash": lambda f: f.change_case(phase, resources_sha256=None),
            "empty_resource_samples": lambda f: f.change_resources(phase, lambda r: r.update(samples=[], sample_count=0)),
            "missing_engine_sample_with_claimed_identity": lambda f: f.change_resources(phase, lambda r: [sample.update(processes=[]) for sample in r["samples"]]),
            "nonfinite_cpu_counter": lambda f: f.change_resources(phase, lambda r: r.update(observed_cpu_seconds=float("inf"))),
        }
        for name, mutate in controls.items():
            with self.subTest(control=name), tempfile.TemporaryDirectory(prefix="strata-custody-") as temporary:
                fixture = CampaignFixture(Path(temporary))
                mutate(fixture)
                fixture.flush()
                with self.assertRaises((RuntimeError, KeyError, TypeError, ValueError, OSError)):
                    fixture.verify()

    def test_windows_wrapper_alone_cannot_claim_engine_resources(self):
        first = gate.SCENES[0] + "/install"
        with tempfile.TemporaryDirectory(prefix="strata-custody-") as temporary:
            fixture = CampaignFixture(Path(temporary), "win32")
            def wrapper_only(resources):
                wrapper = fixture.case(first)["pid"]
                resources["process_identities"] = [row for row in resources["process_identities"] if row[0] == wrapper]
                for sample in resources["samples"]:
                    sample["processes"] = [row for row in sample["processes"] if row["pid"] == wrapper]
                    sample["tree_rss_bytes"] = sum(row["rss_bytes"] for row in sample["processes"])
                    sample["tree_cpu_seconds_observed"] = sum(row["cpu_seconds"] for row in sample["processes"])
                resources["peak_observed_tree_rss_bytes"] = max(row["tree_rss_bytes"] for row in resources["samples"])
                resources["observed_cpu_seconds"] = resources["samples"][-1]["tree_cpu_seconds_observed"]
            fixture.change_resources(first, wrapper_only)
            fixture.flush()
            with self.assertRaises((RuntimeError, KeyError, TypeError, ValueError)):
                fixture.verify()

    def test_reject_missing_or_changed_original_evidence(self):
        controls = {
            "no_ledger": lambda f: f.report.pop("evidence_sha256"),
            "empty_ledger": lambda f: f.report.update(evidence_sha256={}),
            "omitted_fixture_log": lambda f: f.report["evidence_sha256"].pop("test_workbench_strata_document/process.log"),
            "unlisted_file": lambda f: (f.folder / "unlisted-receipt.json").write_text("{}"),
            "changed_original_log": lambda f: (f.folder / "test_depth_compositor/process.log").write_text("changed\n"),
            "escaped_ledger_path": lambda f: f.report["evidence_sha256"].update({"../outside.json": "9" * 64}),
        }
        for name, mutate in controls.items():
            with self.subTest(control=name), tempfile.TemporaryDirectory(prefix="strata-custody-") as temporary:
                fixture = CampaignFixture(Path(temporary))
                mutate(fixture)
                fixture.flush(refresh_ledger=False)
                with self.assertRaises((RuntimeError, KeyError, TypeError, ValueError)):
                    fixture.verify()


if __name__ == "__main__":
    unittest.main()
