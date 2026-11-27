"""Adversarial publication receipts; these fixtures make no gameplay claim."""
from __future__ import annotations

import copy
import hashlib
import json
import ntpath
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import zipfile
import zlib

import run_workbench_actor_qualification as gate


def encoded(value):
    return (json.dumps(value, sort_keys=True) + "\n").encode()


def sha(value):
    return hashlib.sha256(value).hexdigest()


def png():
    def chunk(kind, value):
        return len(value).to_bytes(4, "big") + kind + value + zlib.crc32(kind + value).to_bytes(4, "big")
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", b"\0\0\0\4\0\0\0\3\x08\x06\0\0\0")
            + chunk(b"IDAT", zlib.compress((b"\0" + b"\x20\x40\x60\xff" * 4) * 3)) + chunk(b"IEND", b""))


class SandboxPublication(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="sandbox-publication-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = {"source_commit": "a" * 40, "source_tree": "b" * 40,
                       "source_inputs": {"native/src/example.cpp": "c" * 64}}
        self.inputs = {"godot/scripts/example.gd": sha(b"unit fixture script"),
                       "godot/scripts/example.gd.uid": sha(b"uid://unitfixture\n")}
        self.args = SimpleNamespace()
        self.candidates = {}
        self.rapier = {}
        self.before = {}
        for platform in gate.NATIVE:
            directory = self.root / "candidates" / platform
            directory.mkdir(parents=True)
            setattr(self.args, platform, directory)
            binary = (b"MZ" if platform == "windows" else b"\x7fELF") + b"unit-test-runtime"
            (directory / Path(gate.NATIVE[platform]).name).write_bytes(binary)
            manifest = {"schema": 1, "kind": "workbench-actor-native-candidate", "platform": platform,
                        **self.source, "build_inputs": self.inputs, "artifact": gate.NATIVE[platform],
                        "sha256": sha(binary), "size": len(binary), "toolchain": "unit fixture"}
            (directory / "actor-candidate.json").write_bytes(encoded(manifest))
            self.candidates[platform] = manifest
            self.rapier[platform] = sha((platform + " Rapier unit fixture").encode())
            provenance = self.root / ("godot/addons/godot-rapier2d/runtime-provenance." + platform + ".json")
            provenance.parent.mkdir(parents=True, exist_ok=True)
            provenance.write_bytes(encoded({"sha256": self.rapier[platform]}))
            for name in (gate.NATIVE[platform], gate.PROVENANCE[platform]):
                path = self.root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                self.before[name] = encoded({"build_commit": "old", "sha256": "old"}) if name.endswith(".json") else b"old binary"
                path.write_bytes(self.before[name])
        for name in ("linux_report", "windows_report", "windows_installed_report"):
            path = self.root / name / "qualification.json"
            setattr(self.args, name, path)
        self.args.windows_modules_report = self.root / "modules.json"
        self.args.windows_extraction_report = self.root / "extraction.json"
        self.args.windows_package = self.root / "CyberSand-Actor-Sandbox-Windows-aaaaaaaaaaaa.zip"
        self.package_root = r"D:\runner-temp\actor-workshop-installed"
        self.payload = {
            gate.NATIVE["windows"]: (self.args.windows / Path(gate.NATIVE["windows"]).name).read_bytes(),
            gate.RAPIER["windows"]: b"windows Rapier unit fixture",
            "vcruntime140.dll": b"VC runtime unit fixture", "Godot_v4.7-stable_win64.exe": b"GUI engine fixture",
            "Godot_v4.7-stable_win64_console.exe": b"console engine fixture",
            "Open Workbench.cmd": b"unit fixture launcher", "godot/project.godot": b"unit fixture project",
            "godot/scripts/example.gd": b"unit fixture script",
            "godot/scripts/example.gd.uid": b"uid://unitfixture\n",
        }
        self.package = {"schema": 1, "source_commit": self.source["source_commit"],
                        "source_tree": self.source["source_tree"], "godot_version": gate.VERSION,
                        "native_sha256": self.candidates["windows"]["sha256"],
                        "files_sha256": {name: sha(data) for name, data in self.payload.items()}}
        for platform in gate.NATIVE:
            self.make_report(getattr(self.args, platform + "_report"), platform)
        self.make_report(self.args.windows_installed_report, "windows", installed=True)
        self.make_archive()
        self.make_modules()
        self.patches = [patch.object(gate, "ROOT", self.root), patch.object(gate, "source", return_value=self.source),
                        patch.object(gate, "project_inputs", return_value=self.inputs),
                        patch.object(gate.subprocess, "check_output", return_value=gate.SANDBOX_BRANCH + "\n")]
        for item in self.patches:
            item.start()
            self.addCleanup(item.stop)

    def capacity(self):
        rows = []
        for family in ("barrels", "mixed", "articulated"):
            for count in (16, 32, 64):
                bodies, joints, equipment = {"barrels": (count, 0, 0),
                    "mixed": (count * 7 // 2, count * 3, count * 5 // 8),
                    "articulated": (count * 5, count * 5, count)}[family]
                rows.append({"family": family, "actors": count, "bodies": bodies, "proxies": bodies,
                             "joints": joints, "native_registered_bodies": bodies, "native_registered_proxies": bodies,
                             "native_ticks": 30, "rapier_ticks": 30, "passed": True, "headless": False,
                             "equipment_owner_actors": equipment, "equipment_prepared_actors": equipment,
                             "equipment_worker_frame_tick": 29, "equipment_last_error": "",
                             "equipment_accepted_actors": int(equipment > 0)})
        return {"checks": 900, "failures": [], "rows": rows}

    def phases(self, name):
        labels = {"test_workbench_actor_composition_reopen": [("fresh-process reopened cast moves", 60)],
                  "test_workbench_actor_interaction_reopen": [
                      ("fresh saved composition remains physically playable", 12),
                      ("fresh64-barrel composition progresses both owners", 12)]}.get(name, [])
        return [{"label": label, "requested_rapier_ticks": ticks, "native_ticks": ticks - 1,
                 "rapier_ticks": ticks, "passed": True} for label, ticks in labels]

    def make_report(self, path, platform, installed=False):
        path.parent.mkdir()
        frames = path.parent / "frames"
        frames.mkdir()
        captures = {}
        for key, filename, names in (
            ("graphical_capture", "workshop.json", ["workshop-1.png", "workshop-2.png", "workshop-3.png", "workshop-4.png"]),
            ("sandbox_graphical_capture", "sandbox.json", sorted(gate.SANDBOX_CAPTURE_FILES))):
            images = []
            for name in names:
                (frames / name).write_bytes(png())
                images.append({"file": name, "actors": 64, "actual_bodies": 64, "native_tick": 100, "rapier_tick": 100})
            captures[key] = {"status": "passed", "failure": "", "display": "Windows" if platform == "windows" else "X11",
                             "window": [4, 3], "images": images}
            (frames / filename).write_bytes(encoded(captures[key]))
        names = set(gate.SANDBOX_CASES) | {"import", "test_workbench_actor_composition",
            "test_workbench_actor_composition_reopen", "test_workbench_actor_interaction_reopen",
            "actor_workshop_render", "actor_sandbox_render"}
        if not installed:
            names |= set(gate.CASES)
        results = []
        for name in sorted(names):
            log = "Godot Engine v" + gate.VERSION + "\n"
            if name in gate.SANDBOX_RECEIPTS:
                receipt = self.capacity() if name == "test_workbench_actor_capacity" else {
                    "checks": 9, "failures": [], "headless": False, "phases": self.phases(name)}
                log += gate.SANDBOX_RECEIPTS[name] + json.dumps(receipt) + "\n"
            elif name in ("test_workbench_actor_composition", "test_workbench_actor_composition_reopen"):
                log += "WB_ACTOR_COMPOSE " + json.dumps({"checks": 9, "failures": [], "headless": False, "phases": self.phases(name)}) + "\n"
            elif name in ("test_workbench_actor_composition_session", "test_workbench_actor_composition_native"):
                log += "Workbench actor composition " + name.rsplit("_", 1)[-1] + ": 9 checks, 0 failures\n"
            elif name == "test_prepared_physical_owner":
                log += "PREPARED_PHYSICAL_OWNER: 9 assertions; 0 failures\n"
            elif name == "test_workbench_actor_equipment_extent":
                log += "Workbench actor equipment extent: 9 checks, 0 failures\n"
            elif name == "test_physical_actor_effect_cancellation":
                log += "Physical actor effect cancellation: 9 checks, 0 failures\n"
            elif name == "test_workbench_actor_catalog":
                log += "WB_ACTOR_CATALOG checks=59 failures=0 models=59\n"
            elif name in ("actor_workshop_render", "actor_sandbox_render"):
                key, prefix = (("graphical_capture", "WB_ACTOR_CAPTURE ") if name == "actor_workshop_render"
                               else ("sandbox_graphical_capture", "WB_ACTOR_SANDBOX_CAPTURE "))
                log += prefix + json.dumps(captures[key]) + "\n"
            else:
                contract = json.loads(Path(gate.__file__).with_name("workbench_actor_sandbox_receipts.json").read_text())[name]
                if contract["kind"] == "json":
                    receipt = dict(contract.get("equal", {}))
                    if "positive_integer" in contract:
                        receipt[contract["positive_integer"]] = 9
                    log += contract["prefix"] + json.dumps(receipt) + "\n"
                elif contract["kind"] == "regex":
                    log += contract["pattern"].replace(r"(\d+)", "9").removeprefix("^").removesuffix("$") + "\n"
                elif contract["kind"] == "literal":
                    log += "\n".join(contract["required_lines"]) + "\n"
            log_name = name + ".log"
            (path.parent / log_name).write_bytes(log.encode("utf-8"))
            command = [ntpath.join(self.package_root, "Godot_v4.7-stable_win64_console.exe"),
                       "--path", ntpath.join(self.package_root, "godot")] if installed else [
                           "/engine/Godot_v4.7-stable_linux.x86_64" if platform == "linux" else r"D:\engine\Godot_v4.7-stable_win64_console.exe",
                           "--path", "unit-source"]
            if name == "import":
                command.extend(["--editor", "--quit"])
            else:
                script = {"actor_workshop_render": "capture_workbench_actor_workshop",
                          "actor_sandbox_render": "capture_workbench_actor_sandbox"}.get(name, name.removesuffix("_reopen"))
                command.extend(["--script", "res://tests/" + script + ".gd"])
            row = {"name": name, "status": "passed", "natural_completion": True, "returncode": 0,
                   "diagnostic_error": False, "skip_messages": [], "launch_error": None, "capture_error": None,
                   "timeout_kind": None, "requires_display": True, "log": log_name, "log_sha256": sha(log.encode()),
                   "command": command}
            gate.completion(gate.runner.Case(name, (), 1, 1), row, path.parent)
            results.append(row)
        report = {"schema": 1, "status": "passed", "completed": True, "candidate": self.candidates[platform],
                  "platform": platform, "godot_version": gate.VERSION, "rapier_sha256": self.rapier[platform],
                  "results": results, "executed_cases": len(results), **captures,
                  "installed_package": self.package if installed else None,
                  "userdata": {"retained": True, "temporary_directory_removed": True}}
        path.write_bytes(encoded(report))

    def make_archive(self, extra=None):
        with zipfile.ZipFile(self.args.windows_package, "w") as archive:
            for name, data in self.payload.items():
                archive.writestr(name, data)
            archive.writestr("candidate-manifest.json", encoded(self.package))
            if extra:
                archive.writestr(*extra)
        extraction = {"status": "passed", "source_commit": self.source["source_commit"],
                      "archive": self.args.windows_package.name, "sha256": gate.digest(self.args.windows_package),
                      "installed_report": "installed-windows/qualification.json",
                      "modules_report": "installed-windows/runtime-modules.json"}
        self.args.windows_extraction_report.write_bytes(encoded(extraction))

    def make_modules(self):
        def record(name):
            path = ntpath.join(self.package_root, name)
            digest = self.package["files_sha256"][name]
            return {"relative_path": name, "expected_path": path, "observed_path": path,
                    "expected_sha256": digest, "packaged_sha256": digest, "observed_sha256": digest, "status": "verified"}
        modules = {"status": "passed", "source_commit": self.source["source_commit"], "source_tree": self.source["source_tree"],
                   "package": self.package_root, "modules": [record(name) for name in ("vcruntime140.dll", gate.NATIVE["windows"], gate.RAPIER["windows"])],
                   "executable": record("Godot_v4.7-stable_win64.exe"),
                   "cleanup": {"terminated_owned_process": True, "environment_restored": True, "error": None}}
        self.args.windows_modules_report.write_bytes(encoded(modules))

    def edit(self, path, mutate):
        value = json.loads(path.read_text())
        mutate(value)
        path.write_bytes(encoded(value))

    def refuse(self):
        with self.assertRaises((ValueError, OSError, KeyError, zipfile.BadZipFile, zlib.error)):
            gate.publish_sandbox(self.args)
        for name, before in self.before.items():
            self.assertEqual(before, (self.root / name).read_bytes(), "refusal changed " + name)

    def case(self, report, name):
        return next(row for row in report["results"] if row["name"] == name)

    def test_complete_evidence_stages_only_four_runtime_paths(self):
        files_before = {p.relative_to(self.root).as_posix(): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        gate.publish_sandbox(self.args)
        files_after = {p.relative_to(self.root).as_posix(): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        self.assertEqual(set(files_before), set(files_after))
        self.assertEqual({p for p in files_before if files_before[p] != files_after[p]}, set(self.before))
        for platform in gate.NATIVE:
            result = json.loads((self.root / gate.PROVENANCE[platform]).read_text())
            self.assertEqual("evaluation-candidate-passed", result["status"])
            self.assertEqual(44, len(result["qualification"]["cases"]))
        windows = json.loads((self.root / gate.PROVENANCE["windows"]).read_text())
        self.assertEqual(21, len(windows["installed_package_qualification"]["qualification"]["cases"]))

    def test_wrong_branch_refuses(self):
        with patch.object(gate.subprocess, "check_output", return_value="main\n"):
            self.refuse()

    def test_retained_pair_still_reduces_the_same_run_extraction_without_mutating_runtime(self):
        workflow = (Path(__file__).resolve().parents[2] / ".github/workflows/workbench-actor-sandbox.yml").read_text()
        reducer_step = next(step for step in workflow.split("      - name: ")
                            if step.startswith("Verify complete same-run evidence"))
        self.assertNotIn("\n        if:", reducer_step)
        self.assertIn("mode+=(--verify-only)", reducer_step)
        self.assertIn('publish-sandbox "${mode[@]}"', reducer_step)
        self.args.verify_only = True
        with patch.object(gate, "sandbox_package", wraps=gate.sandbox_package) as reducer:
            gate.publish_sandbox(self.args)
            reducer.assert_called_once()
        for name, before in self.before.items():
            self.assertEqual(before, (self.root / name).read_bytes())
        self.edit(self.args.windows_extraction_report, lambda receipt: receipt.update(sha256="d" * 64))
        self.refuse()

    def test_windows_package_requires_only_qualified_windows_reciprocal_tuple(self):
        windows = "godot/tools/swarm004-runtime.windows.json"
        linux = "godot/tools/swarm004-runtime.linux.json"
        cli = "godot/tools/gentek_reciprocal.exe"
        exe = b"MZ-unit-reciprocal"
        binding = encoded({"platform": "windows", "artifact": cli, "sha256": sha(exe), "bytes": len(exe)})
        self.inputs.update({windows: sha(binding), linux: sha(b"linux binding fixture")})
        self.payload.update({windows: binding, cli: exe})

        def verify():
            self.package["files_sha256"] = {name: sha(data) for name, data in self.payload.items()}
            self.make_archive()
            installed = json.loads(self.args.windows_installed_report.read_bytes())
            installed["installed_package"] = self.package
            return gate.sandbox_package(self.args, self.candidates["windows"], installed)

        self.assertEqual(verify()["status"], "passed")
        for name, data in ((cli, exe + b"changed"), (windows, binding + b" "), (linux, b"linux binding fixture"),
                           ("godot/tools/gentek_reciprocal", b"linux CLI")):
            with self.subTest(name=name), patch.dict(self.payload, {name: data}):
                with self.assertRaises(ValueError):
                    verify()
        del self.payload[cli]
        with self.assertRaises(ValueError):
            verify()

    def test_missing_baseline_and_sandbox_cases_refuse(self):
        for name in ("test_workbench_input", "test_workbench_actor_manipulation"):
            with self.subTest(name=name):
                original = self.args.linux_report.read_bytes()
                self.edit(self.args.linux_report, lambda r: r["results"].remove(self.case(r, name)))
                self.refuse()
                self.args.linux_report.write_bytes(original)

    def test_pending_and_different_source_or_runtime_refuse(self):
        for mutate in (lambda r: r.update(status="pending"), lambda r: r["candidate"].update(source_commit="e" * 40),
                       lambda r: r["candidate"].update(sha256="f" * 64)):
            original = self.args.windows_report.read_bytes()
            self.edit(self.args.windows_report, mutate)
            self.refuse()
            self.args.windows_report.write_bytes(original)
        (self.args.windows / Path(gate.NATIVE["windows"]).name).write_bytes(b"wrong bytes")
        self.refuse()

    def test_failed_or_duplicate_process_receipt_refuses(self):
        for mutate in (lambda r: r["results"][0].update(status="failed"),
                       lambda r: r["results"].append(copy.deepcopy(r["results"][0]))):
            original = self.args.linux_report.read_bytes()
            self.edit(self.args.linux_report, mutate)
            self.refuse()
            self.args.linux_report.write_bytes(original)

    def test_capacity_ticks_counts_missing_family_or_duplicates_refuse(self):
        for mutate in (lambda rows: rows[0].update(native_ticks=29), lambda rows: rows[0].update(rapier_ticks=0),
                       lambda rows: rows[0].update(native_ticks=float("nan")), lambda rows: rows[0].update(rapier_ticks=float("inf")),
                       lambda rows: rows[0].update(native_ticks=30.5), lambda rows: rows[0].update(rapier_ticks=True),
                       lambda rows: rows[3].update(bodies=55, native_registered_bodies=55),
                       lambda rows: rows[0].update(native_registered_proxies=15),
                       lambda rows: rows.pop(), lambda rows: rows.append(copy.deepcopy(rows[0]))):
            original = self.args.linux_report.read_bytes()
            report = json.loads(original)
            row = self.case(report, "test_workbench_actor_capacity")
            log_path = self.args.linux_report.parent / row["log"]
            original_log = log_path.read_bytes()
            mutate(row["assertion_receipt"]["rows"])
            log_path.write_text(gate.SANDBOX_RECEIPTS[row["name"]] + json.dumps(row["assertion_receipt"]) + "\n")
            row["log_sha256"] = gate.digest(log_path)
            self.args.linux_report.write_bytes(encoded(report))
            self.refuse()
            self.args.linux_report.write_bytes(original)
            log_path.write_bytes(original_log)

    def test_missing_installed_reopens_and_captures_refuse(self):
        for name in ("test_workbench_actor_composition_reopen", "test_workbench_actor_interaction_reopen", "actor_sandbox_render"):
            original = self.args.windows_installed_report.read_bytes()
            self.edit(self.args.windows_installed_report, lambda r: r["results"].remove(self.case(r, name)))
            self.refuse()
            self.args.windows_installed_report.write_bytes(original)
        (self.args.windows_installed_report.parent / "frames/06-barrel-crowd-64.png").unlink()
        self.refuse()

    def test_raw_log_hash_diagnostics_skip_and_escaping_path_refuse(self):
        report = json.loads(self.args.linux_report.read_text())
        row = self.case(report, "test_workbench_input")
        log = self.args.linux_report.parent / row["log"]
        original_log = log.read_bytes()
        original_report = self.args.linux_report.read_bytes()
        for text in ("ERROR: poisoned log", "SKIP test body"):
            log.write_bytes(original_log + text.encode() + b"\n")
            row["log_sha256"] = gate.digest(log)
            self.args.linux_report.write_bytes(encoded(report))
            self.refuse()
        log.write_bytes(original_log + b"changed")
        self.args.linux_report.write_bytes(original_report)
        self.refuse()
        log.write_bytes(original_log)
        self.edit(self.args.linux_report, lambda r: self.case(r, "test_workbench_input").update(log="../outside.log"))
        self.refuse()

    def test_zero_exit_without_each_source_owned_footer_refuses(self):
        original = self.args.linux_report.read_bytes()
        report = json.loads(original)
        for row in report["results"]:
            with self.subTest(name=row["name"]):
                path = self.args.linux_report.parent / row["log"]
                before = path.read_bytes()
                path.write_text("premature zero exit\n")
                old_hash = row["log_sha256"]
                row["log_sha256"] = gate.digest(path)
                self.args.linux_report.write_bytes(encoded(report))
                self.refuse()
                path.write_bytes(before)
                row["log_sha256"] = old_hash
        self.args.linux_report.write_bytes(original)

    def test_zip_source_script_cannot_be_relabelled_as_candidate(self):
        name = "godot/scripts/example.gd"
        self.payload[name] = b"different application script"
        self.package["files_sha256"][name] = sha(self.payload[name])
        self.edit(self.args.windows_installed_report, lambda r: r.update(installed_package=self.package))
        self.make_archive()
        self.refuse()

    def test_canonical_lf_source_accepts_authenticated_crlf_uid_payload(self):
        name = "godot/scripts/example.gd.uid"
        self.payload[name] = b"uid://unitfixture\r\n"
        self.package["files_sha256"][name] = sha(self.payload[name])
        self.assertNotEqual(self.package["files_sha256"][name], self.inputs[name])
        self.edit(self.args.windows_installed_report, lambda r: r.update(installed_package=self.package))
        self.make_archive()
        gate.publish_sandbox(self.args)
        for platform in gate.NATIVE:
            self.assertEqual("evaluation-candidate-passed", json.loads((self.root / gate.PROVENANCE[platform]).read_text())["status"])

    def test_canonical_lf_source_rejects_changed_uid_with_consistent_raw_hashes(self):
        name = "godot/scripts/example.gd.uid"
        self.payload[name] = b"uid://changedidentity\r\n"
        self.package["files_sha256"][name] = sha(self.payload[name])
        self.edit(self.args.windows_installed_report, lambda r: r.update(installed_package=self.package))
        self.make_archive()
        self.refuse()

    def test_truncated_or_corrupt_framebuffer_refuses(self):
        path = self.args.windows_installed_report.parent / "frames/06-barrel-crowd-64.png"
        original = path.read_bytes()
        for data in (original[:33], original[:-12], original[:-13] + b"x" + original[-12:]):
            path.write_bytes(data)
            self.refuse()

    def test_graphical_crowd_requires_finite_integer_body_and_tick_counts(self):
        report_path = self.args.windows_installed_report
        original = report_path.read_bytes()
        capture_path = report_path.parent / "frames/sandbox.json"
        original_capture = capture_path.read_bytes()
        for key, invalid in (("actors", 64.0), ("actual_bodies", 64.0), ("native_tick", float("nan")),
                             ("native_tick", float("inf")), ("rapier_tick", 1.5), ("rapier_tick", True)):
            report = json.loads(original)
            capture = report["sandbox_graphical_capture"]
            crowd = next(row for row in capture["images"] if row["file"] == "06-barrel-crowd-64.png")
            crowd[key] = invalid
            capture_path.write_bytes(encoded(capture))
            process = self.case(report, "actor_sandbox_render")
            log = report_path.parent / process["log"]
            original_log = log.read_bytes()
            log.write_text("WB_ACTOR_SANDBOX_CAPTURE " + json.dumps(capture) + "\n")
            process["log_sha256"] = gate.digest(log)
            report_path.write_bytes(encoded(report))
            self.refuse()
            log.write_bytes(original_log)
        report_path.write_bytes(original)
        capture_path.write_bytes(original_capture)

    def test_missing_wrong_hash_or_wrong_path_modules_refuse(self):
        for mutate in (lambda m: m["modules"].pop(), lambda m: m["modules"][0].update(observed_sha256="f" * 64),
                       lambda m: m["modules"][0].update(observed_path=r"C:\Windows\System32\vcruntime140.dll"),
                       lambda m: m["cleanup"].update(environment_restored=False)):
            original = self.args.windows_modules_report.read_bytes()
            self.edit(self.args.windows_modules_report, mutate)
            self.refuse()
            self.args.windows_modules_report.write_bytes(original)

    def test_extraction_proof_and_zip_payload_must_match(self):
        for mutate in (lambda e: e.update(status="failed"), lambda e: e.update(sha256="f" * 64),
                       lambda e: e.update(source_commit="f" * 40)):
            original = self.args.windows_extraction_report.read_bytes()
            self.edit(self.args.windows_extraction_report, mutate)
            self.refuse()
            self.args.windows_extraction_report.write_bytes(original)
        self.payload["vcruntime140.dll"] += b"changed"
        self.make_archive()
        self.refuse()

    def test_extra_traversing_and_case_colliding_zip_members_refuse(self):
        for name in ("unexpected.dll", "../evil", "C:/evil", "VCRUNTIME140.DLL"):
            self.make_archive((name, b"extra"))
            self.refuse()

    def test_installed_process_must_use_extracted_project(self):
        self.edit(self.args.windows_installed_report,
                  lambda r: r["results"][0].update(command=[r"D:\source\Godot.exe", "--path", r"D:\source\godot"]))
        self.refuse()

    def test_wrong_engine_or_source_fixture_refuses(self):
        for installed in (False, True):
            path = self.args.windows_installed_report if installed else self.args.linux_report
            original = path.read_bytes()
            for wrong_engine in (False, True):
                report = json.loads(original)
                row = self.case(report, "test_workbench_actor_interaction")
                if wrong_engine:
                    row["command"][0] = ntpath.join(ntpath.dirname(row["command"][0]), "Other.exe")
                else:
                    row["command"][row["command"].index("--script") + 1] = "res://tests/other.gd"
                path.write_bytes(encoded(report))
                self.refuse()
            path.write_bytes(original)

    def test_replayed_author_or_headless_reopen_receipts_refuse(self):
        original = self.args.windows_installed_report.read_bytes()
        for name in ("test_workbench_actor_composition_reopen", "test_workbench_actor_interaction_reopen"):
            for mutate in (lambda a: a.update(phases=[]), lambda a: a.update(headless=True),
                           lambda a: a["phases"][0].update(native_ticks=float("inf"))):
                report = json.loads(original)
                row = self.case(report, name)
                log = self.args.windows_installed_report.parent / row["log"]
                original_log = log.read_bytes()
                mutate(row["assertion_receipt"])
                prefix = "WB_ACTOR_COMPOSE " if "composition" in name else gate.SANDBOX_RECEIPTS[name]
                log.write_text(prefix + json.dumps(row["assertion_receipt"]) + "\n")
                row["log_sha256"] = gate.digest(log)
                self.args.windows_installed_report.write_bytes(encoded(report))
                self.refuse()
                log.write_bytes(original_log)
        self.args.windows_installed_report.write_bytes(original)


if __name__ == "__main__":
    unittest.main()
