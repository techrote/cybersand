#!/usr/bin/env python3
"""Read-only Windows source/extracted artifact audit; does not execute the app.

Use the API artifact's SHA-256 as --archive-sha256. Reports and native files are
read directly from ZIP; no extraction, retagging, metric tuning or acceptance is
performed. Partial receipt timing may differ; completed material outcomes may not.
"""
from __future__ import annotations
import argparse
import base64
from collections import Counter
import hashlib
import json
import ntpath
from pathlib import Path
import re
import zipfile

NATIVE_TICK_SOURCE = "CyberSimulationWorker.take_latest_snapshot(0).tick_index"


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


class Audit:
    def __init__(self, path: Path, source: str, expected: str, native: str | None = None):
        self.path, self.source = path, source
        self.checks = 0
        self.errors = []
        self.files = {}
        self.expected = expected.removeprefix("sha256:")
        self.expected_native = native
        with path.open("rb") as archive_input:
            self.actual = hashlib.file_digest(archive_input, "sha256").hexdigest()
        self.check(bool(re.fullmatch(r"[0-9a-f]{40}", source)), "exact_source")
        if native is not None: self.check(bool(re.fullmatch(r"[0-9a-f]{64}", native)), "exact_runtime_digest")
        self.check(self.actual == self.expected, "API_archive_digest")
        self.zip = zipfile.ZipFile(path)
        names = self.zip.namelist()
        self.check(len(names) == len(set(names)), "unique_ZIP_names")
        self.prefixes = {phase: self.locate(phase + "/qualification.json")[:-len("qualification.json")]
                         for phase in ("application", "extracted-evaluator")}

    def check(self, value, label: str):
        self.checks += 1
        if not value: self.errors.append(label)

    def locate(self, suffix: str) -> str:
        names = [name for name in self.zip.namelist() if name == suffix or name.endswith("/" + suffix)]
        if len(names) != 1: raise ValueError("Expected one retained file: " + suffix)
        return names[0]

    def raw(self, name: str, expected: str | None = None) -> bytes:
        if name not in self.zip.namelist(): raise ValueError("Missing retained artifact member: " + name)
        info = self.zip.getinfo(name)
        if info.file_size > 128 * 1024 * 1024: raise ValueError("Oversize retained input: " + name)
        data = self.zip.read(name); digest = sha(data)
        self.files[name] = digest
        if expected is not None: self.check(digest == expected, "retained_hash:" + name)
        return data

    def doc(self, name: str):
        value = json.loads(self.raw(name))
        if not isinstance(value, dict): raise ValueError("Expected a report object: " + name)
        return value

    def phase(self, phase: str) -> dict:
        prefix = self.prefixes[phase]
        report = self.doc(prefix + "qualification.json")
        self.check(report.get("source_commit") == self.source, phase + ":exact_source")
        self.check(report.get("status") == "passed" and report.get("graphical") is True
                   and report.get("platform") == "win32" and report.get("actual_model_calls") == 0
                   and not report.get("development_dirty_allowed") and report.get("collaborative_m6_m7") is True,
                   phase + ":complete_graphical_default_scope")
        rows = report.get("results", [])
        labels = [row.get("label") for row in rows]
        self.check(len(rows) == {"application":89,"extracted-evaluator":72}[phase], phase + ":frozen_process_denominator")
        self.check(rows and len(set(labels)) == len(rows) and all(row.get("status") == "passed" for row in rows),
                   phase + ":all_processes_passed")
        base = prefix + "architecture/collaborative/"
        reference = report["collaborative_evidence"]
        self.raw(prefix + reference["path"], reference["sha256"])
        custody = self.doc(base + "custody.json")
        self.check(custody.get("source_revision") == self.source and custody.get("passed") is True
                   and custody.get("native_active_core_capacity") == 1024 and custody.get("cropped_route_worlds") is False,
                   phase + ":custody_default_full_World")
        for name, digest in custody["files_sha256"].items(): self.raw(base + name, digest)
        native = report["source_files_sha256"]["addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"]
        self.check(custody.get("native_binary_sha256") == native, phase + ":native_runtime")
        if self.expected_native is not None:
            self.check(native == self.expected_native, phase + ":independently_custodied_native_runtime")
        batch = self.doc(prefix + "native/native-session.json")
        attempts = batch["attempts"]
        histogram = dict(Counter(row["state"] for row in attempts))
        evaluable = []
        for row in attempts:
            raw = base64.b64decode(row.get("material_cells_base64", ""), validate=True)
            if raw:
                self.check(sha(raw) == row["material_sha256"], phase + ":batch_plane:" + row["attempt_id"])
                evaluable.append(row)
        self.check(len(attempts) == 75 and len(evaluable) == 72
                   and histogram == {"completed":68, "partial":4, "refused":2, "stopped":1}, phase + ":retained_original_pilot")
        legacy = self.doc(prefix + "architecture/comparison/cases.json")
        self.check(legacy.get("source_commit") == self.source and legacy.get("runtime",{}).get("bridge_sha256") == native
                   and len(legacy.get("cases",[])) == 30, phase + ":original_30_architecture_cases")
        for row in legacy["cases"]:
            for key in ("before","after"):
                self.raw(prefix + "architecture/comparison/" + row[key]["path"], row[key]["sha256"])
        original_examples = []
        for name in ("representatives.json","module-compositions.json"):
            manifest = self.doc(prefix + "architecture/stages/" + name)
            self.check(manifest.get("source_revision") == self.source, phase + ":original_examples_source:" + name)
            original_examples.extend(manifest["examples"])
            for row in manifest["examples"]:
                self.raw(prefix + "architecture/stages/" + row["plane"], row["sha256"])
        self.check(len(original_examples) == 9, phase + ":original_nine_examples")
        catalogue = self.doc(base + "catalogue/native-catalogue-report.json")
        detail = self.doc(base + "detail/cases.json")
        comparison = self.doc(base + "comparison/cases.json")
        flagships = self.doc(base + "flagships/flagships-native.json")
        hierarchy = self.doc(base + "hierarchy/hierarchy-native.json")
        gameplay = self.doc(base + "gameplay/architecture-gameplay.json")
        reopened = self.doc(base + "gameplay/architecture-gameplay-reopen.json")
        actor_trials = []
        for report_name, actor_report in (("route",gameplay),("fresh_reopen",reopened)):
            self.check(actor_report.get("native_tick_source") == NATIVE_TICK_SOURCE
                       and actor_report.get("source_revision") == self.source
                       and actor_report.get("native_active_core_capacity") == 1024
                       and actor_report.get("passed") is True and actor_report.get("failures") == [],
                       phase + ":" + report_name + ":current_worker_publication")
            for row in actor_report["attempts"]:
                bounds = row.get("native_tick_bounds", {})
                cache = row.get("render_cached_native_tick_bounds", {})
                pause = row.get("acknowledged_pause_ticks", {})
                self.check(row.get("native_tick_source") == NATIVE_TICK_SOURCE
                           and bounds.get("end",-1)-bounds.get("begin",0) == row.get("native_ticks")
                           and cache.get("end",-1)-cache.get("begin",0) == row.get("render_cached_native_ticks")
                           and pause.get("native_published",-1) >= bounds.get("end",0)
                           and row.get("samples") and all(sample.get("accepted") is True for sample in row["samples"]),
                           phase + ":" + report_name + ":retained_tick_interval:" + row["id"])
                samples = row["samples"]
                gaps = [sample["actor_tick"]-sample["native_tick"] for sample in samples]
                cached_gaps = [sample["actor_tick"]-sample["render_cached_native_tick"] for sample in samples]
                actor_trials.append({"kind":report_name, **{key:row.get(key) for key in
                    ("id","status","actor_ticks","native_ticks","render_cached_native_ticks","contact_samples",
                     "command_refusals","left_corridor","worker_failed","acknowledged_pause_ticks")},
                    "max_actor_minus_native_publication":max(gaps), "max_actor_minus_render_cache":max(cached_gaps)})
        self.check(reopened.get("route_report_sha256") == self.files[base + "gameplay/architecture-gameplay.json"],
                   phase + ":fresh_actor_report_consumes_exact_route_report")
        if phase == "extracted-evaluator":
            launch_ref = report["delivered_launcher"]
            self.raw(prefix + launch_ref["path"], launch_ref["sha256"])
            launcher = self.doc(prefix + launch_ref["path"])
            self.check(launcher.get("source_revision") == self.source and launcher.get("passed") is True
                       and launcher.get("pristine_payload_verified") is True and launcher.get("launcher_exit_code") == 0
                       and launcher.get("native_binary_sha256") == native and launcher.get("failures") == [],
                       "extracted:actual_pristine_CMD_pass")
            process = launcher.get("observed_process", {})
            query = launcher.get("query_self_test", {})
            query_paths, observed_self = query.get("paths", []), query.get("observed_self", {})
            self.check(query.get("passed") is True and query.get("checks") == 3 and query.get("failures") == []
                       and isinstance(query.get("powershell_version"), str)
                       and len(query_paths) == 2 and all(isinstance(value, str) and ntpath.isabs(value) for value in query_paths)
                       and query_paths[1] == query_paths[0] + ".nonexistent-query-control"
                       and observed_self.get("ProcessId", 0) > 0 and observed_self.get("CreationDate")
                       and ntpath.normcase(observed_self.get("ExecutablePath", "")) == ntpath.normcase(query_paths[0]),
                       "extracted:actual_scalar_query_self_observation")
            command = launcher.get("launcher_command", [])
            executable = process.get("ExecutablePath", "")
            self.check(len(command) == 4 and command[1:3] == ["/d", "/c"]
                       and ntpath.basename(command[-1]).lower() == "open workbench.cmd"
                       and ntpath.normcase(ntpath.dirname(command[-1])) == ntpath.normcase(ntpath.dirname(executable))
                       and ntpath.basename(executable).lower() == "godot_v4.7-stable_win64.exe"
                       and process.get("ProcessId", 0) > 0 and process.get("CreationDate")
                       and process.get("ParentProcessId") == launcher.get("launcher_pid")
                       and type(process.get("MainWindowHandle")) is int and process["MainWindowHandle"] != 0
                       and "--workbench" in process.get("CommandLine", ""),
                       "extracted:visible_exact_Workbench_route")
            self.check(launcher.get("preexisting_processes") == [] and not launcher.get("cleanup_failures")
                       and launcher.get("cleanup") == "Only exact observed child image/PID/creation identities closed; none remain",
                       "extracted:isolated_launch_and_exact_cleanup")
            identity = (process.get("ProcessId"), process.get("CreationDate"), ntpath.normcase(executable))
            matching_samples = [sample for sample in launcher.get("monitor_samples", [])
                if 5 <= sample.get("elapsed_seconds", -1) < 150 and sample.get("cmd_exit_code") == 0
                and any((row.get("ProcessId"), row.get("CreationDate"), ntpath.normcase(row.get("ExecutablePath", ""))) == identity
                        and row.get("ParentProcessId") == launcher.get("launcher_pid")
                        and type(row.get("MainWindowHandle")) is int and row["MainWindowHandle"] != 0
                        for row in sample.get("visible_owned_gui", []))
                and any(row.get("ready") is True and row.get("path") == launcher.get("route_log")
                        and row.get("sha256") == launcher.get("route_log_sha256") for row in sample.get("route_logs", []))]
            self.check(bool(matching_samples), "extracted:retained_simultaneous_launch_predicates_within_original_bound")
            route_path = prefix + str(Path(launch_ref["path"]).parent).replace("\\", "/") + "/" + launcher["route_log"]
            route = self.raw(route_path, launcher["route_log_sha256"])
            self.check(b"SHARED_WORKBENCH_LAUNCH_READY" in route
                       and not any(token in route for token in (b"SCRIPT ERROR:", b"Parse Error:", b"Failed to load script")),
                       "extracted:actual_route_log_marker")
        else: launcher = {}
        summary = {"qualification_sha256":self.files[prefix+"qualification.json"],"processes":len(rows),
                   "process_labels":labels,"native_binary_sha256":native,"godot_executable_sha256":report["godot_executable_sha256"],
                   "custody_sha256":self.files[base+"custody.json"],"counts":custody["counts"],
                   "original_pilot":{"attempts":len(attempts),"evaluable":len(evaluable),"statuses":histogram},
                   "actor_trials":actor_trials,
                   "fresh_actor_reopens":len(reopened["attempts"]),
                   "hierarchy_partial_checked_cells":hierarchy["result"]["partial_checked_cells"],
                   "launcher":launcher}
        return {"summary":summary,"report":report,"batch":attempts,"catalogue":catalogue,"detail":detail,
                "comparison":comparison,"flagships":flagships,"hierarchy":hierarchy,"legacy":legacy,"original_examples":original_examples}

    def run(self) -> dict:
        phases = {name:self.phase(name) for name in self.prefixes}
        source, extracted = phases["application"], phases["extracted-evaluator"]
        self.check(source["report"]["source_files_sha256"] == extracted["report"]["source_files_sha256"], "same_qualified_application_bytes")
        self.check(source["summary"]["godot_executable_sha256"] == extracted["summary"]["godot_executable_sha256"], "same_Godot_console_bytes")
        pairs = [
            ("original_30_architecture_outcomes", lambda phase:{r["id"]:(r["before"]["sha256"],r["after"]["sha256"],r["status"]) for r in phase["legacy"]["cases"]}),
            ("original_nine_native_examples", lambda phase:{r["id"]:r["sha256"] for r in phase["original_examples"]}),
            ("catalogue_native_planes", lambda phase:{(r["id"],r["phase"],r["transform"]):r["material_sha256"] for r in phase["catalogue"]["observations"]}),
            ("module_geometry", lambda phase:{r["id"]:r["geometry_sha256"] for r in phase["catalogue"]["modules"]}),
            ("detail_native_planes", lambda phase:{r["id"]:(r["before"]["sha256"],r["after"]["sha256"],r["status"]) for r in phase["detail"]["cases"]}),
            ("comparison_native_outcomes", lambda phase:{r["case_id"]:(r["source_sha256"],r["result_sha256"],r["status"],r["native_attempted"]) for r in phase["comparison"]["cases"]}),
            ("full_flagship_planes", lambda phase:{r["id"]:r["sha256"] for r in phase["flagships"]["examples"]}),
        ]
        paired = {}
        for label, select in pairs:
            left, right = select(source), select(extracted)
            self.check(left == right, "source_extracted:" + label)
            paired[label] = {"members":len(left),"identical":left == right}
        self.check(source["hierarchy"]["result"]["plane_sha256"] == extracted["hierarchy"]["result"]["plane_sha256"], "source_extracted:final_hierarchy_plane")
        partial_differences = []
        for index, (left,right) in enumerate(zip(source["batch"],extracted["batch"])):
            self.check(left["state"] == right["state"], "original_pilot_state:"+str(index))
            if left["state"] == "completed":
                self.check(left["material_sha256"] == right["material_sha256"], "original_completed_plane:"+str(index))
            elif left["state"] == "partial" and left["material_sha256"] != right["material_sha256"]:
                partial_differences.append(index)
        return {"format":"cybersand-m67-independent-windows-outcomes-review-c-v1","source_revision":self.source,
                "status":"PASS" if not self.errors else "FAIL","checks":self.checks,"errors":self.errors,
                "artifact_sha256":self.actual,"artifact_bytes":self.path.stat().st_size,
                "independently_custodied_native_sha256":self.expected_native,
                "phases":{name:value["summary"] for name,value in phases.items()},"paired_native_outcomes":paired,
                "original_partial_plane_differences":partial_differences,"consumed_files_sha256":self.files,
                "scope":"Read-only artifact/source/runtime custody and exact completed native-material comparisons. Route, actor, partial and graphical results retain their producer scopes.",
                "model_quality":"not-qualified; no genuine inference", "physical_owner_acceptance":"pending"}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("zip",type=Path);parser.add_argument("--source",required=True)
    parser.add_argument("--archive-sha256",required=True);parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--native-sha256",help="Expected DLL digest from the independent exact-source runtime artifact audit")
    args=parser.parse_args();audit=Audit(args.zip,args.source,args.archive_sha256,args.native_sha256)
    result=audit.run();args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(json.dumps({"status":result["status"],"checks":result["checks"],"errors":result["errors"],
                      "phases":{name:{"processes":value["processes"],"qualification_sha256":value["qualification_sha256"]} for name,value in result["phases"].items()}},indent=2))
    return 0 if result["status"]=="PASS" else 1


if __name__=="__main__":raise SystemExit(main())
